package com.exit8.exception;

import com.exit8.dto.DefaultResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice(basePackages = "com.exit8.controller")
public class GlobalExceptionHandler {

    /**
     * 비즈니스 예외
     */
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<DefaultResponse<Void>> handleApiException(ApiException e) {
        return ResponseEntity
                .status(e.getStatus())
                .body(DefaultResponse.failure(
                        e.getStatus().value(),
                        e.getCode(),
                        e.getMessage()
                ));
    }

    /**
     * 예상하지 못한 예외
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<DefaultResponse<Void>> handleException(Exception e) {
        return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(DefaultResponse.failure(
                        HttpStatus.INTERNAL_SERVER_ERROR.value(),
                        "INTERNAL_SERVER_ERROR",
                        "서버 내부 오류가 발생했습니다"
                ));
    }
}
