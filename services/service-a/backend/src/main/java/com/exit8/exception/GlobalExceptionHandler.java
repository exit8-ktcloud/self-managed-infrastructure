package com.exit8.exception;

import com.exit8.dto.DefaultResponse;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@Slf4j
@RestControllerAdvice(basePackages = "com.exit8.controller")
public class GlobalExceptionHandler {

    /**
     * 비즈니스 예외 처리
     * - 정상 흐름 내에서 발생 가능한 예외
     * - ERROR가 아닌 WARN 수준으로 기록
     * - trace_id 기준으로 요청 추적 가능
     */
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<DefaultResponse<Void>> handleApiException(ApiException e) {
        log.warn(
                "event=BUSINESS_EXCEPTION code={} trace_id={}",
                e.getCode(),
                MDC.get("trace_id")
        );

        return ResponseEntity
                .status(e.getStatus())
                .body(DefaultResponse.failure(
                        e.getStatus().value(),
                        e.getCode(),
                        e.getMessage()
                ));
    }

    /**
     * 예상하지 못한 예외 처리
     * - trace_id 기반으로 장애 요청 로그 추적 가능
     * - 반드시 로그를 남겨 "로그 없는 장애"를 방지
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<DefaultResponse<Void>> handleException(Exception e) {
        log.error(
                "event=UNHANDLED_EXCEPTION trace_id={}",
                MDC.get("trace_id"),
                e
        );

        return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(DefaultResponse.failure(
                        HttpStatus.INTERNAL_SERVER_ERROR.value(),
                        "INTERNAL_SERVER_ERROR",
                        "서버 내부 오류가 발생했습니다"
                ));
    }
}
