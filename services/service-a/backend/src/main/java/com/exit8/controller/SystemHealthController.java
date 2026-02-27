package com.exit8.controller;

import com.exit8.dto.DefaultResponse;
import com.exit8.dto.SystemHealthStatus;
import com.exit8.dto.SystemSnapshot;
import com.exit8.dto.ToggleResponse;
import com.exit8.observability.RequestEvent;
import com.exit8.service.SystemHealthService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/system")
@RequiredArgsConstructor
public class SystemHealthController {

    private final SystemHealthService systemHealthService;

    /**
     * 운영 상태 판단용 Health API
     * - DOWN인 경우 503 반환
     */
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

    /**
     * Health & Observability 전용 Snapshot API
     *
     * - 시스템 상태를 판단하지 않음
     * - Raw 계측값만 반환
     * - UI / 실험 분석 / 모니터링 용도
     */
    @GetMapping("/snapshot")
    public ResponseEntity<DefaultResponse<SystemSnapshot>> snapshot() {

        SystemSnapshot snapshot = systemHealthService.getSnapshot();

        return ResponseEntity.ok(
                DefaultResponse.success(
                        HttpStatus.OK.value(),
                        snapshot
                )
        );
    }

    /**
     * Rate Limit ON/OFF 토글 API
     *
     * - 현재 활성화 상태를 반전
     * - 서버 재시작 없이 실험 중 동적 전환 가능
     * - Snapshot API에서 동일 상태 확인 가능
     */
    @PostMapping("/rate-limit/toggle")
    public ResponseEntity<DefaultResponse<ToggleResponse>> toggleRateLimit() {

        ToggleResponse response = systemHealthService.toggleRateLimit();

        return ResponseEntity.ok(
                DefaultResponse.success(
                        HttpStatus.OK.value(),
                        response
                )
        );
    }

    /**
     * 최근 요청 이벤트 조회 API
     *
     * - 인메모리 RequestEventBuffer 기반
     * - 최근 N건 요청 이벤트 반환
     * - 기본값: 100
     */
    @GetMapping("/recent-requests")
    public ResponseEntity<DefaultResponse<List<RequestEvent>>> recentRequests(
            @RequestParam(defaultValue = "100") int limit
    ) {
        List<RequestEvent> events =
                systemHealthService.getRecentRequests(limit);

        return ResponseEntity.ok(
                DefaultResponse.success(
                        HttpStatus.OK.value(),
                        events
                )
        );
    }

    /**
     * Redis Cache ON/OFF 토글 API
     *
     * - 현재 활성화 상태를 반전
     * - 서버 재시작 없이 동적 전환 가능
     * - Snapshot API에서 동일 상태 확인 가능
     */
    @PostMapping("/redis-cache/toggle")
    public ResponseEntity<DefaultResponse<ToggleResponse>> toggleRedisCache() {

        ToggleResponse response = systemHealthService.toggleRedisCache();

        return ResponseEntity.ok(
                DefaultResponse.success(
                        HttpStatus.OK.value(),
                        response
                )
        );
    }


}