package com.exit8.service;

import com.exit8.dto.SystemHealthStatus;
import com.exit8.exception.ApiException;
import com.zaxxer.hikari.HikariDataSource;
import com.zaxxer.hikari.HikariPoolMXBean;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import javax.sql.DataSource;
import java.sql.Connection;

@Service
@RequiredArgsConstructor
public class SystemHealthService {

    private static final String CIRCUIT_NAME = "testCircuit";

    private final CircuitBreakerRegistry circuitBreakerRegistry;
    private final DataSource dataSource;   // HikariDataSource

    public SystemHealthStatus getCurrentStatus() {

        CircuitBreaker circuitBreaker =
                circuitBreakerRegistry.find(CIRCUIT_NAME)
                        .orElseThrow(() -> new ApiException(
                                "CIRCUIT_NOT_FOUND",
                                "circuit breaker not registered: " + CIRCUIT_NAME,
                                HttpStatus.INTERNAL_SERVER_ERROR
                        ));

        String cbState = circuitBreaker.getState().name();

        // 기본값
        String status = "UP";
        String reason = null;

        /* CircuitBreaker 상태가 최우선 */
        if (circuitBreaker.getState() == CircuitBreaker.State.OPEN) {
            return new SystemHealthStatus(
                    "DOWN",
                    cbState,
                    120,
                    "CIRCUIT_BREAKER_OPEN"
            );
        }

        if (circuitBreaker.getState() == CircuitBreaker.State.HALF_OPEN) {
            return new SystemHealthStatus(
                    "DEGRADED",
                    cbState,
                    120,
                    "CIRCUIT_BREAKER_HALF_OPEN"
            );
        }

        /* DB liveness 체크 (DOWN 아님, DEGRADED 판단용) */
        boolean dbAlive = true;

        try (Connection conn = dataSource.getConnection()) {
            dbAlive = conn.isValid(1);
        } catch (Exception e) {
            dbAlive = false;
        }

        if (!dbAlive) {
            status = "DEGRADED";
            reason = "DB_CONNECTION_ISSUE";
        }

        /* DB 상태는 CLOSED 일 때만 평가 */
        if (dataSource instanceof HikariDataSource hikari) {
            HikariPoolMXBean pool = hikari.getHikariPoolMXBean();

            if (pool == null) {
                throw new ApiException(
                        "DB_POOL_UNAVAILABLE",
                        "hikari pool mbean not available",
                        HttpStatus.INTERNAL_SERVER_ERROR
                );
            }

            int active = pool.getActiveConnections();
            int idle = pool.getIdleConnections();
            int waiting = pool.getThreadsAwaitingConnection();

            // 커넥션 대기 발생 = 이미 병목
            if (waiting > 0) {
                status = "DEGRADED";
                reason = "DB_CONNECTION_POOL_WAITING";
            }

            // idle 0 + active 과다 → 위험 신호
            if (idle == 0 && active > 0) {
                status = "DEGRADED";
                reason = "DB_CONNECTION_POOL_EXHAUSTED";
            }
        }

        // 임시 평균 응답 시간 (실험 단계)
        long avgResponseTimeMs = 120;

        return new SystemHealthStatus(
                status,
                cbState,
                avgResponseTimeMs,
                reason
        );
    }
}
