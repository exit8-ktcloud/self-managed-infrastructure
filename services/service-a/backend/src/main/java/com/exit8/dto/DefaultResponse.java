package com.exit8.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
@AllArgsConstructor
public class DefaultResponse<T> {

    private int httpCode;
    private T data;
    private ErrorResponse error;

    public static <T> DefaultResponse<T> success(int httpCode, T data) {
        return new DefaultResponse<>(httpCode, data, null);
    }

    public static DefaultResponse<Void> success(int httpCode) {
        return new DefaultResponse<>(httpCode, null, null);
    }

    public static DefaultResponse<Void> failure(int httpCode, String code, String message) {
        return new DefaultResponse<>(
                httpCode,
                null,
                new ErrorResponse(code, message)
        );
    }
}
