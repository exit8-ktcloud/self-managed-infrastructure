package com.exit8.service;

import com.exit8.exception.ApiException;
import com.exit8.logging.LogEvent;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
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
            // 인터럽트 상태 복원
            Thread.currentThread().interrupt();

            throw new ApiException(
                    "THREAD_INTERRUPTED",
                    "thread was interrupted during processing",
                    HttpStatus.INTERNAL_SERVER_ERROR
            );
        }
    }

    /**
     * Circuit OPEN 시 호출
     */
    private String fallback(Throwable t) {
        log.warn(
                "event={} circuit={} trace_id={} message={}",
                LogEvent.CIRCUIT_OPEN,
                CIRCUIT_NAME,
                MDC.get("trace_id"),
                t.getMessage()
        );

        throw new ApiException(
                "CIRCUIT_OPEN",
                "circuit breaker is open",
                HttpStatus.SERVICE_UNAVAILABLE
        );
    }
}
