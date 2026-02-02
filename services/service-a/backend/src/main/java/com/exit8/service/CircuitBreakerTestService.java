package com.exit8.service;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class CircuitBreakerTestService {

    private static final String CIRCUIT_NAME = "testCircuit";

    @CircuitBreaker(
            name = CIRCUIT_NAME,
            fallbackMethod = "fallback"
    )
    public String callWithDelay() {
        try {
            // 일부러 timeout 유도
            Thread.sleep(3000);
            return "OK";

        } catch (InterruptedException e) {
            // 인터럽트 상태 복원 (중요)
            Thread.currentThread().interrupt();
            throw new RuntimeException("THREAD_INTERRUPTED");
        }
    }

    /**
     * Circuit OPEN 시 호출
     */
    private String fallback(Throwable t) {
        log.warn(
                "CIRCUIT_OPEN name={} message={}",
                CIRCUIT_NAME,
                t.getMessage()
        );

        throw new RuntimeException("CIRCUIT_OPEN");
    }
}
