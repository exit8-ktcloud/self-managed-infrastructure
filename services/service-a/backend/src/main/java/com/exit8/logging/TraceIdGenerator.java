package com.exit8.logging;

import org.slf4j.MDC;

import java.util.UUID;

/**
 * 요청 단위 trace_id 관리
 */
public final class TraceIdGenerator {

    public static final String TRACE_ID_KEY = "trace_id";

    private TraceIdGenerator() {
    }

    /**
     * trace_id 조회 (없으면 생성)
     */
    public static String getOrCreate() {
        String traceId = MDC.get(TRACE_ID_KEY);

        if (traceId == null) {
            traceId = generate();
            MDC.put(TRACE_ID_KEY, traceId);
        }

        return traceId;
    }

    /**
     * trace_id 제거 (요청 종료 시)
     */
    public static void clear() {
        MDC.remove(TRACE_ID_KEY);
    }

    private static String generate() {
        return UUID.randomUUID().toString().replace("-", "");
    }
}
