package com.ratelimiter.controller;

import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ratelimiter.service.ApiKeyService;

import reactor.core.publisher.Mono;

@RestController
@RequestMapping("/api/keys")
public class ApiKeyController {
    private final ApiKeyService aKeyService;

    @Autowired
    public ApiKeyController(
            ApiKeyService aKeyService

    ) {
        this.aKeyService = aKeyService;
    }

    @PostMapping
    public ResponseEntity<Mono<Map>> newKey() {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(
                        aKeyService.genApiKey().map(key -> Map.of("apiKey", key)));
    }
}
