package com.exit8.controller;

import com.exit8.dto.DefaultResponse;
import com.exit8.service.SystemHealthService;
import com.exit8.dto.SystemHealthStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/system")
@RequiredArgsConstructor
public class SystemHealthController {

    private final SystemHealthService systemHealthService;

    @GetMapping("/health")
    public ResponseEntity<DefaultResponse<SystemHealthStatus>> health() {
        SystemHealthStatus status = systemHealthService.getCurrentStatus();

        HttpStatus httpStatus =
                "DOWN".equals(status.getStatus())
                        ? HttpStatus.SERVICE_UNAVAILABLE
                        : HttpStatus.OK;

        return ResponseEntity
                .status(httpStatus)
                .body(DefaultResponse.success(
                        httpStatus.value(),
                        status
                ));
    }
}
