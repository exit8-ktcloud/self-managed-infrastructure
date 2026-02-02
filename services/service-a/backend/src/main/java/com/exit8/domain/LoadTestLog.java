package com.exit8.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Entity
@Table(name = "spring_load_test_logs")
@Getter
@NoArgsConstructor
public class LoadTestLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * 부하 시나리오 타입
     * - CPU
     * - DB_READ
     * - DB_WRITE
     */
    @Column(name = "scenario_type", nullable = false, length = 32)
    private String scenarioType;

    /**
     * 부하 실행에 걸린 시간 (ms)
     */
    @Column(name = "duration_ms", nullable = false)
    private long durationMs;

    /**
     * 실행 시각 (UTC)
     */
    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public LoadTestLog(String scenarioType, long durationMs) {
        this.scenarioType = scenarioType;
        this.durationMs = durationMs;
    }
}
