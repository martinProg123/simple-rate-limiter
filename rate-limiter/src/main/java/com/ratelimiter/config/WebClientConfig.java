package com.ratelimiter.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

@Configuration
public class WebClientConfig {

    @Value("${backend.base-url}")
    private String backendBaseUrl;

    @Bean
    public WebClient backendWebClient(WebClient.Builder builder) {
        return builder.baseUrl(backendBaseUrl).build();
    }
}
