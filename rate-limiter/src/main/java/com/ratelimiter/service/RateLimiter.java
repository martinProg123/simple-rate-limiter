package com.ratelimiter.service;

import com.ratelimiter.model.RateLimitResult;
import reactor.core.publisher.Mono;

public interface RateLimiter {

    Mono<RateLimitResult> allowRequest(String apiKey);
}
