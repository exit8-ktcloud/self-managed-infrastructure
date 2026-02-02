package com.exit8.logging;

import org.slf4j.event.Level;

/**
 * 로그 레벨 판단 정책
 */
public final class LogLevelPolicy {

    private LogLevelPolicy() {
    }

    /**
     * 예외 기반 로그 레벨 결정
     */
    public static Level decideByException(Throwable t) {

        if (t == null) {
            return Level.INFO;
        }

        String message = t.getMessage();

        if (message == null) {
            return Level.ERROR;
        }

        // CircuitBreaker OPEN
        if (message.contains("CIRCUIT_OPEN")) {
            return Level.WARN;
        }

        // 부하 과도 / timeout 직전
        if (message.contains("TIMEOUT") || message.contains("SLOW")) {
            return Level.WARN;
        }

        // DB / I/O 계열
        if (message.contains("DB")
                || message.contains("SQL")
                || message.contains("REDIS")) {
            return Level.ERROR;
        }

        // 보안 / 비정상 호출
        if (message.contains("UNAUTHORIZED")
                || message.contains("FORBIDDEN")
                || message.contains("ATTACK")) {
            return Level.ERROR;
        }

        return Level.ERROR;
    }
}
