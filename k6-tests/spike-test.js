import http from 'k6/http';
import { check, sleep } from 'k6';
import exec from 'k6/execution';

export let options = {
    stages: [
        { duration: '5s', target: 20 },   // Baseline traffic (20 separate users/keys)
        { duration: '5s', target: 500 },  // SPIKE: 500 separate users attack concurrently!
        { duration: '30s', target: 500 },  // Hold spike 
        { duration: '5s', target: 20 },   // Ramp down
        { duration: '5s', target: 0 },    // Scale down to zero
    ],
    thresholds: {
        // Track the overall error rate across the spike timeline
        'checks': ['rate>0.90'],
    },
};

// Each VU maintains its own isolated memory space. 
// This variable will hold the key *only* for the specific VU running the code.
let vuApiKey = null;

export default function () {
    const url = __ENV.BASE_URL;

    // 1. DYNAMIC REGISTRATION: Fetch a unique API key if this VU doesn't have one yet
    if (!vuApiKey) {
        // exec.vu.idInTest is a unique global ID (e.g., User 1, User 2... User 500)
        console.log(`VU ${exec.vu.idInTest} initializing and requesting unique key...`);

        const genRes = http.post(`${url}/api/keys`);

        if (check(genRes, { 'api Key extracted': (r) => r.json().apiKey })) {
            vuApiKey = genRes.json().apiKey;
        } else {
            console.error(`VU ${exec.vu.idInTest} failed to provision a key.`);
            return;
        }
    }

    // 2. RATE LIMITER TESTING: Hit the endpoint with the unique key
    const params = {
        headers: {
            'X-API-Key': vuApiKey,
        },
    };

    const batchReqs = new Array(60).fill(['GET', `${url}/api/data`, null, params]);
    const batchResponse = http.batch(batchReqs);

    // Filter responses
    const successful = batchResponse.filter(r => r.status >= 200 && r.status < 300);
    const rateLimited = batchResponse.filter(r => r.status === 429);
    const withRetryAfter = rateLimited.filter(r => r.headers['X-Ratelimit-Retry-After']);

    // 3. Smart Mathematical Checks
    check(batchResponse, {
        // Assert 1: Total requests handled always equals our batch size
        'batch size is exactly 60': (responses) => responses.length === 60,

        // Assert 2: Rate limited + Successful requests must account for 100% of responses
        'no unexpected status codes': () => (successful.length + rateLimited.length) === 60,

        // Assert 3: At no point can a single burst allow more than the max token capacity (50)
        'never exceeds max bucket capacity': () => successful.length <= 50,

        // Assert 4: If requests are blocked, the remaining must be 429s (60 total - up to 50 allowed = at least 10 blocked)
        'at least 10 requests dropped on fresh burst': () => rateLimited.length >= 10,

        // Assert 5: Compliance check for headers on rate-limited responses
        'all 429s contain retry headers': () => withRetryAfter.length === rateLimited.length,
    });

    // Pacing: Sleep for 2 seconds. 
    // At 10 tok/s replenishment, a 2-second sleep restores exactly 20 tokens to this user's bucket.
    // On the next loop, successful.length should be exactly 20, and rateLimited.length should be 40!
    sleep(2);
}
