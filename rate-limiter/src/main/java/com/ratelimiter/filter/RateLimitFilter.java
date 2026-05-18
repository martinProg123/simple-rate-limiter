package com.ratelimiter.filter;

import org.springframework.http.HttpStatus;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.http.server.reactive.ServerHttpResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import org.springframework.web.server.WebFilter;
import org.springframework.web.server.WebFilterChain;

import com.ratelimiter.model.RateLimitResult;
import com.ratelimiter.service.RateLimiter;
import com.ratelimiter.service.TokenBucketRateLimiter;

import reactor.core.publisher.Mono;

@Component
public class RateLimitFilter implements WebFilter {
    private static final String API_KEY_HEADER = "X-API-KEY";
    private static final String RETRY_AFTER_HEADER = "X-RateLimit-Retry-After";
    private final RateLimiter tokenBucketLimiter;

    public RateLimitFilter(RateLimiter rl) {
        tokenBucketLimiter = rl;

    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        ServerHttpRequest request = exchange.getRequest();
        ServerHttpResponse response = exchange.getResponse();
        String path = request.getURI().getPath();
        if (path.startsWith("/api/keys")) {
            return chain.filter(exchange);
        }

        // 1. Extract the header value safely
        String apiKey = request.getHeaders().getFirst(API_KEY_HEADER);
        if (apiKey == null) {
            // Unauthenticated: Short-circuit the request and return 401 Unauthorized
            response.setStatusCode(HttpStatus.UNAUTHORIZED);

            // Set the response complete and stop processing
            return response.setComplete();
        }

        return tokenBucketLimiter.allowRequest(apiKey)
                .flatMap(result -> {
                    // Here, `result` is the actual RateLimitResult (unwrapped)
                    // Return Mono<Void> from filter
                    if (result.remainingTokens() == -1) {
                        response.setStatusCode(HttpStatus.UNAUTHORIZED);
                        return response.setComplete();
                    }
                    if (!result.allowed()) {
                        response.setStatusCode(HttpStatus.TOO_MANY_REQUESTS);
                        response.getHeaders().set(RETRY_AFTER_HEADER, String.valueOf(result.retryAfterSeconds()));
                        return response.setComplete();
                    }
                    return chain.filter(exchange);
                });
    }
}
