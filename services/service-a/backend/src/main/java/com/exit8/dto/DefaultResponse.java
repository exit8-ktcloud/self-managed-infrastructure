package com.exit8.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class DefaultResponse<T> {

    private boolean success;
    private T data;
    private ErrorResponse error;

    public static <T> DefaultResponse<T> success(T data) {
        return new DefaultResponse<>(true, data, null);
    }

    public static DefaultResponse<Void> success() {
        return new DefaultResponse<>(true, null, null);
    }

    public static DefaultResponse<Void> failure(String code, String message) {
        return new DefaultResponse<>(
                false,
                null,
                new ErrorResponse(code, message)
        );
    }
}
