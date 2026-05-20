# Rate limiter(token bucket) prototype with k6 test and aws cloud

## Components

All in docker:
```
k6 tests/curl -> Spring boot(api gateway) -> nodejs backend
                    ^
                    |
                  redis
```

## dev test command:

Copy .env.example to .env first, then run:
```
docker compose up -d
docker compose --profile k6 run --rm k6 run /scripts/rate-limit-test.js
```