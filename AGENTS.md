# Rate Limiter Project

## Architecture

```
k6 (load tests)
    │
    ▼
Spring Boot Rate Limiter (:3051)
  ├── Token Bucket (Redis Lua script)
  ├── Sliding Window (todo)
  ├── Fixed Window (todo)
  ├── API Key management
  └── WebClient proxy → Node.js
          │
          ▼
Node.js Express Backend (:3050, internal)
          │
          ▼
Redis (:6379) — API keys + rate limit state
```

## Tech Stack

| Component | Choice |
|---|---|
| Build tool | Maven |
| Java | 21 LTS (virtual threads) |
| Spring Boot | 3.x |
| Proxy | WebClient (reactive, non-blocking) |
| Registry | GHCR (ghcr.io/<user>/rate-limiter) |
| Node.js | Express |
| Redis | Containerized (docker-compose) |
| Rate limit scope | Global (env config) |
| CI/CD | GitHub Actions + Terraform |
| EC2 | t3.small (2 vCPU, 2 GiB) |

## Project Structure

```
ratelimiter/
├── rate-limiter/              # Spring Boot 3.x + Java 21
│   ├── src/main/java/...
│   │   ├── RateLimiterApplication.java
│   │   ├── config/
│   │   │   ├── RedisConfig.java
│   │   │   └── WebClientConfig.java
│   │   ├── model/
│   │   │   ├── ApiKey.java
│   │   │   └── RateLimitResult.java
│   │   ├── repository/
│   │   │   └── ApiKeyRepository.java
│   │   ├── service/
│   │   │   ├── RateLimiter.java              # Interface
│   │   │   ├── TokenBucketRateLimiter.java   # Lua-script atomic
│   │   │   ├── SlidingWindowRateLimiter.java # Stub (todo)
│   │   │   └── ApiKeyService.java
│   │   ├── controller/
│   │   │   ├── ApiKeyController.java         # POST /api/keys
│   │   │   └── ProxyController.java          # /* → WebClient → Node
│   │   └── filter/
│   │       └── RateLimitFilter.java
│   ├── Dockerfile             # Multi-stage build
│   └── pom.xml
├── node-backend/
│   ├── src/index.js
│   ├── package.json
│   └── Dockerfile
├── k6-tests/
│   ├── smoke-test.js
│   ├── spike-test.js
│   ├── stress-test.js
│   ├── soak-test.js
│   └── rate-limit-test.js
├── terraform/
│   ├── main.tf                # EC2 + SG + user_data
│   ├── variables.tf
│   └── outputs.tf
├── .github/workflows/
│   └── ci-cd.yml
├── docker-compose.yml
└── docker-compose.prod.yml
```

## API Design

| Endpoint | Method | Description |
|---|---|---|
| `/api/keys` | POST | Generate API key (no body). Format: `rl_{apiVer}_{env}_{base64(32 random bytes)}` |
| `/api/data` | ALL | Proxied to Node.js. Requires `X-API-Key` header. Returns `401` if key invalid, `429` if throttled. |

## Redis Data Model

```
bucket:{fullApiKey} → {tokens, lastRefillTs}
```

- One hash per API key, keyed by the full key string as stored
- `tokens` = current available tokens, `lastRefillTs` = epoch seconds of last refill
- `maxTokens` and `refillRate` come from env vars (not stored in Redis), passed as ARGV to Lua script
- No separate api-key metadata store

## Rate Limit Configuration (Env Vars)

```yaml
rate-limiter:
  max-tokens: 50
  refill-rate: 10    # tokens per second
```

These are injected into `TokenBucketRateLimiter` via `@Value` and passed as `ARGV[1]` and `ARGV[2]` to the Lua script at runtime.

## Request Flow

1. Client sends request with `X-API-Key` header to Spring Boot (:3051)
2. `RateLimitFilter` extracts API key, passes to `TokenBucketRateLimiter`
3. `TokenBucketRateLimiter` runs Redis Lua script on `bucket:{apiKey}`:
   - Key doesn't exist → `401 Unauthorized`
   - Tokens < 1 → `429 Too Many Requests` with `X-RateLimit-Retry-After`
   - Tokens >= 1 → consume one → proceed
4. `ProxyController` forwards valid requests via `WebClient` to Node.js (:3050)
5. Node.js Express responds with request metadata

## CI/CD Pipeline

| Step | Action |
|---|---|
| `push: main` | Trigger workflow |
| Build SB | `mvn package` |
| Build Node | `npm ci` |
| Unit tests | `mvn test` |
| Docker | Build & push to GHCR |
| k6 | `docker-compose up` → run k6 tests against local stack |
| Terraform | `terraform apply` (provision/update EC2) |
| Deploy | SSH → `docker-compose pull && docker-compose up -d` |

## Extensibility

`RateLimiter` interface allows plugging in new algorithms:
- `TokenBucketRateLimiter` (done)
- `SlidingWindowRateLimiter` (todo)
- `FixedWindowRateLimiter` (todo)
