package com.ratelimiter.model;

public record RateLimitResult(boolean allowed, int remainingTokens, long retryAfterSeconds) {

}
