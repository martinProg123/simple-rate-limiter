package com.ratelimiter.controller;

import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import org.springframework.web.server.ResponseStatusException;

import reactor.core.publisher.Mono;

@RestController
@RequestMapping("/api/data")
public class ProxyController {
    private final WebClient webClient;

    @Autowired
    public ProxyController(WebClient w) {
        this.webClient = w;
    }

    @GetMapping
    public Mono<Map<String, Object>> callExternal(){
        return this.webClient.get()
        .uri("/fake")
        .retrieve()
        .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {})
        .onErrorResume(WebClientResponseException.class, e ->
            Mono.error(new ResponseStatusException(
                HttpStatus.valueOf(e.getStatusCode().value()),
                "Upstream error: " + e.getStatusText()
            ))
        )
        .onErrorResume(e ->
            Mono.error(new ResponseStatusException(
                HttpStatus.BAD_GATEWAY,
                "Backend unreachable: " + e.getMessage()
            ))
        );
    }
}
