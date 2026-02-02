package com.exit8.repository;

import com.exit8.domain.SystemLog;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SystemLogRepository
        extends JpaRepository<SystemLog, Long> {
    // level, message 기준 조회는 필요 시 추가
}
