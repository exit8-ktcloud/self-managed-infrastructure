package com.exit8.logging;

public final class LogEvent {

    private LogEvent() {
        // 인스턴스 생성 방지
    }

    /** 부하 시나리오 요청 시작 */
    public static final String LOAD_START = "LOAD_START";

    /** 부하 시나리오 정상 종료 */
    public static final String LOAD_END = "LOAD_END";

    /** 부하 시나리오 중 예외 발생 */
    public static final String LOAD_FAIL = "LOAD_FAIL";

    /** 치명적 오류로 인한 요청 실패 */
    public static final String LOAD_ERROR = "LOAD_ERROR";

    /** CircuitBreaker fallback 실행 */
    public static final String FALLBACK = "FALLBACK";

    /** CircuitBreaker 상태가 OPEN으로 전환됨 */
    public static final String CIRCUIT_OPEN = "CIRCUIT_OPEN";

    /** 비즈니스 예외(ApiException) 발생 */
    public static final String BUSINESS_EXCEPTION = "BUSINESS_EXCEPTION";

    /** 예상하지 못한 시스템 예외 */
    public static final String UNHANDLED_EXCEPTION = "UNHANDLED_EXCEPTION";
}
