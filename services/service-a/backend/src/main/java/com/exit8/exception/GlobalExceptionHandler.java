package com.exit8.exception;

import com.exit8.dto.DefaultResponse;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

    /**
     * 비즈니스 예외
     */
    @ExceptionHandler(ApiException.class)
    public DefaultResponse<Void> handleApiException(ApiException e) {
        return DefaultResponse.failure(
                e.getCode(),
                e.getMessage()
        );
    }

    /**
     * 예상하지 못한 예외
     */
    @ExceptionHandler(Exception.class)
    public DefaultResponse<Void> handleException(Exception e) {
        return DefaultResponse.failure(
                "INTERNAL_SERVER_ERROR",
                "서버 내부 오류가 발생했습니다"
        );
    }
}
