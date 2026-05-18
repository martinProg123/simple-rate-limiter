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
    console.log(`The apiKey is: ${apiKey}`);

    check(genRes, {
        'api Key extracted': (r) => r.json().apiKey,
    });

    if (apiKey) {
        const params = {
            headers: {
                'X-API-Key': apiKey,
            },
        };
        const res = http.get(`${url}/api/data`, params)
        console.log(`The backend result is: ${JSON.stringify(res.json())}`);
        check(res, {
            'is status 20x': (r) => r.status >= 200 && r.status < 300,
        });
    }

}