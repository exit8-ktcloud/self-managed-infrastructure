package com.exit8.service;

import com.exit8.dto.SystemHealthStatus;
import com.zaxxer.hikari.HikariDataSource;
import com.zaxxer.hikari.HikariPoolMXBean;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import javax.sql.DataSource;

@Service
@RequiredArgsConstructor
public class SystemHealthService {

    private final CircuitBreakerRegistry circuitBreakerRegistry;
    private final DataSource dataSource;   // HikariDataSource

    public SystemHealthStatus getCurrentStatus() {

        CircuitBreaker circuitBreaker =
                circuitBreakerRegistry.circuitBreaker("testCircuit");

        String cbState = circuitBreaker.getState().name();

        // 기본값
        String status = "UP";
        String reason = null;

        // CircuitBreaker 기준
        if ("OPEN".equals(cbState)) {
            status = "DOWN";
            reason = "CIRCUIT_BREAKER_OPEN";
        } else if ("HALF_OPEN".equals(cbState)) {
            status = "DEGRADED";
            reason = "CIRCUIT_BREAKER_HALF_OPEN";
        }

        // DB 커넥션 풀 상태 확인
        if (dataSource instanceof HikariDataSource hikari) {
            HikariPoolMXBean pool = hikari.getHikariPoolMXBean();

            if (pool != null) {
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
