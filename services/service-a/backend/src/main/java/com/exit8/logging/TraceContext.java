package com.exit8.logging;

import org.slf4j.MDC;

/**
 * MDC 기반 trace_id 조회 전용 유틸
 *
 * - trace_id 생성/제거 책임 없음
 * - HTTP 요청 컨텍스트 조회 목적
 */
public final class TraceContext {

    public static final String TRACE_ID_KEY = "trace_id";

    private TraceContext() {
    }

    public static String getTraceId() {
        return MDC.get(TRACE_ID_KEY);
    }
}
