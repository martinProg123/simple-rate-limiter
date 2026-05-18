import http from 'k6/http';
import { check } from 'k6';

export let options = {
    vus: 1,
    iterations: 1,
};

export default function () {
    const url = __ENV.BASE_URL;

    // send a post request and save response as a variable
    const genRes = http.post(`${url}/api/keys`);
    const data = genRes.json();
    const apiKey = data.apiKey

    if (apiKey) {
        const params = {
            headers: {
                'X-API-Key': apiKey,
            },
        };

        const batchReqs = new Array(60).fill(['GET', `${url}/api/data`, null, params])
        const batchResponse = http.batch(batchReqs)
        // batchResponse.map((r, i)=>{
        //     console.log(`${i+1} ${r.status} ${JSON.stringify(r.headers)}`)
        // })
        const rateLimited = batchResponse.filter(r => r.status === 429);
        const withRetryAfter = rateLimited.filter(r => r.headers['X-Ratelimit-Retry-After']);

        check(rateLimited, {
            '10-15 requests are rate limited': (r) => r.length >= 10 && r.length <= 15,
        });
        check(withRetryAfter, {
            'all 429s have X-RateLimit-Retry-After header': (r) => r.length === rateLimited.length,
        });
    }

}
