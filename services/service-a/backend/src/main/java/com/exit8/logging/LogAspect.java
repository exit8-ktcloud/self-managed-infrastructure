package com.exit8.logging;

import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.slf4j.event.Level;
import org.springframework.stereotype.Component;

@Aspect
@Component
@Slf4j
public class LogAspect {

    /**
     * 부하 시나리오 / 서킷 테스트 공통 로깅
     */
    @Around(
            "execution(* com.exit8.service.LoadScenarioService.*(..)) || " +
                    "execution(* com.exit8.service.CircuitBreakerTestService.*(..))"
    )
    public Object logLoadAndCircuit(ProceedingJoinPoint joinPoint) throws Throwable {

        long start = System.currentTimeMillis();
        String method = joinPoint.getSignature().getName();

        // trace_id 생성 or 재사용
        String traceId = TraceIdGenerator.getOrCreate();

        log.info(
                "LOAD_START traceId={} method={}",
                traceId,
                method
        );

        try {
            Object result = joinPoint.proceed();

            long duration = System.currentTimeMillis() - start;

            log.info(
                    "LOAD_END traceId={} method={} durationMs={}",
                    traceId,
                    method,
                    duration
            );

            return result;

        } catch (Exception e) {
            long duration = System.currentTimeMillis() - start;

            Level level = LogLevelPolicy.decideByException(e);

            if (level == Level.WARN) {
                log.warn(
                        "LOAD_FAIL traceId={} method={} durationMs={} message={}",
                        traceId,
                        method,
                        duration,
                        e.getMessage()
                );
            } else {
                log.error(
                        "LOAD_ERROR traceId={} method={} durationMs={} message={}",
                        traceId,
                        method,
                        duration,
                        e.getMessage(),
                        e
                );
            }

            throw e;

        } finally {
            // 요청 종료 시 trace_id 제거 (중요)
            TraceIdGenerator.clear();
        }
    }
}
