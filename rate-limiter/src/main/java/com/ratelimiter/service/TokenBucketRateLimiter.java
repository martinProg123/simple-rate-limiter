package com.ratelimiter.service;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.data.redis.core.ReactiveStringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Service;

import com.ratelimiter.model.RateLimitResult;

import reactor.core.publisher.Mono;

@Service
public class TokenBucketRateLimiter implements RateLimiter {

    private final ReactiveStringRedisTemplate redisTemplate;
    private final DefaultRedisScript<String> script;
    @Value("${rate-limiter.max-tokens}")
    private String maxTokens;
    @Value("${rate-limiter.refill-rate}")
    private String refillRate;

    @Autowired
    public TokenBucketRateLimiter(ReactiveStringRedisTemplate r) {
        this.redisTemplate = r;
        this.script = new DefaultRedisScript<String>();
        script.setLocation(new ClassPathResource("lua/token_bucket.lua"));
        script.setResultType(String.class);
    }

    public Mono<RateLimitResult> allowRequest(String apiKey) {
        var now = System.currentTimeMillis() / 1000;

        return redisTemplate.execute(script,
                List.of("bucket:" + apiKey),
                maxTokens, refillRate, String.valueOf(now))
                .next()
                .map(raw -> {
                    var parts = raw.split(",");
                    int allowed = Integer.parseInt(parts[0]);
                    int remaining = Integer.parseInt(parts[1]);

                    return new RateLimitResult(allowed == 1, remaining, 1);
                });
    }

}
