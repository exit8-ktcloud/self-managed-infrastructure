package com.exit8.logging;

import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.slf4j.MDC;
import org.slf4j.event.Level;
import org.springframework.stereotype.Component;

@Aspect
@Component
@Slf4j
public class LogAspect {

    /**
     * 부하 시나리오 / 서킷 브레이커 테스트 서비스에만 적용
     */
    @Around(
            "execution(* com.exit8.service.LoadScenarioService.*(..)) || " +
                    "execution(* com.exit8.service.CircuitBreakerTestService.*(..))"
    )
    public Object logLoadAndCircuit(ProceedingJoinPoint joinPoint) throws Throwable {

        long start = System.currentTimeMillis();
        String method = joinPoint.getSignature().getName();

        // 요청 시작 이벤트
        log.info("event={} method={}", LogEvent.LOAD_START, method);

        try {
            Object result = joinPoint.proceed();

            long duration = System.currentTimeMillis() - start;

            // 정상 종료 이벤트
            log.info("event={} method={} durationMs={}", LogEvent.LOAD_END, method, duration);


            return result;

        } catch (Exception e) {
            long duration = System.currentTimeMillis() - start;

            // 예외 유형에 따라 로그 레벨 결정
            Level level = LogLevelPolicy.decideByException(e);

            if (level == Level.WARN) {
                // 재시도 / fallback 등 비치명적 실패
                log.warn(
                        "event={} method={} durationMs={} message={}",
                        LogEvent.LOAD_FAIL,
                        method,
                        duration,
                        e.getMessage()
                );

            } else {
                // 치명적 실패
                log.error(
                        "event={} method={} durationMs={} message={}",
                        LogEvent.LOAD_ERROR,
                        method,
                        duration,
                        e.getMessage(),
                        e
                );

            }

            throw e;
        }
        // trace_id clear 금지 (요청 종료 시 Filter에서 일괄 처리)
    }
}
