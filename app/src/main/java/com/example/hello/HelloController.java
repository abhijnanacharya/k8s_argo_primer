package com.example.hello;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class HelloController {

    @Value("${app.environment:local}")
    private String environment;

    @Value("${app.message:Hello from Spring Boot!}")
    private String message;

    @GetMapping("/")
    public Map<String, String> hello() {
        return Map.of(
                "message", message,
                "environment", environment);
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "UP");
    }

    @GetMapping("/info")
    public Map<String, String> info() {
        return Map.of(
                "app", "hello-spring",
                "version", "0.0.3",
                "environment", environment);
    }
}
