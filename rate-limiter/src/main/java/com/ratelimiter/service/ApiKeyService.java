package com.ratelimiter.service;

import java.security.SecureRandom;
import java.util.Base64;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.ReactiveStringRedisTemplate;
import org.springframework.stereotype.Service;

import reactor.core.publisher.Mono;

@Service
public class ApiKeyService {
    private final SecureRandom secureRandom = new SecureRandom();
    private final Base64.Encoder encoder = Base64.getUrlEncoder().withoutPadding();
    private final ReactiveStringRedisTemplate redisTemplate;

    @Value("${server.api-ver}")
    private String apiVer;
    @Value("${server.environment}")
    private String serverEnv;
    @Value("${server.secret-length}")
    private int byteLen;
    @Value("${rate-limiter.max-tokens}")
    private int maxTokens;

    @Autowired
    public ApiKeyService(ReactiveStringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public Mono<String> genApiKey() {
        byte[] randBytes = new byte[byteLen];
        secureRandom.nextBytes(randBytes);
        String apiKey = String.join(
                "_",
                "rl",
                apiVer,
                serverEnv,
                encoder.encodeToString(randBytes));

        var now = System.currentTimeMillis() / 1000;
        return redisTemplate.opsForHash()
                .putAll("bucket:" + apiKey, Map.of(
                        "tokens", String.valueOf(maxTokens),
                        "lastRefillTs", String.valueOf(now)))
                .thenReturn(apiKey);
    }
}
