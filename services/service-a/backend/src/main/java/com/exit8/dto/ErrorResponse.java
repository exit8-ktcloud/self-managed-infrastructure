package com.exit8.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class ErrorResponse {

    /**
     * 에러 코드 (시스템/비즈니스 식별용)
     * 예: CIRCUIT_OPEN, DB_CONNECTION_FAILED
     */
    private String code;

    /**
     * 사용자 또는 UI에 노출되는 메시지
     */
    private String message;
}
