package com.exit8.controller;

import com.exit8.dto.DefaultResponse;
import com.exit8.service.CircuitBreakerTestService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/circuit")
@RequiredArgsConstructor
public class CircuitBreakerTestController {

    private final CircuitBreakerTestService circuitBreakerTestService;

    @GetMapping("/test")
    public DefaultResponse<String> test() {
        String result = circuitBreakerTestService.callWithDelay();
        return DefaultResponse.success(200, result);
    }
}
