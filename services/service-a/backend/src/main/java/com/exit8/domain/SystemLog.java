package com.exit8.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Entity
@Table(name = "spring_logs")
@Getter
@NoArgsConstructor
public class SystemLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * 요청 단위 추적용 ID
     * - 요청 시작 시 생성
     * - 로그 상관관계 분석용
     */
    @Column(name = "trace_id", nullable = false, length = 64)
    private String traceId;

    /**
     * 인증된 사용자 ID
     * - 인증 전 요청은 NULL
     */
    @Column(name = "user_id", length = 64)
    private String userId;

    /**
     * 로그 레벨
     * INFO / WARNING / ERROR / CRITICAL
     */
    @Column(nullable = false, length = 16)
    private String level;

    /**
     * 코드성 메시지 (자유 텍스트 금지)
     * 예: DB_CONNECTION_FAILED, CIRCUIT_BREAKER_OPEN
     */
    @Column(nullable = false, length = 255)
    private String message;

    /**
     * 로그 발생 시각 (UTC)
     */
    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public SystemLog(String traceId, String userId, String level, String message) {
        this.traceId = traceId;
        this.userId = userId;
        this.level = level;
        this.message = message;
    }
}
