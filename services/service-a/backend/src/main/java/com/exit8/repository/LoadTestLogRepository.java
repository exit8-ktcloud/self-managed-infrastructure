package com.exit8.repository;

import com.exit8.domain.LoadTestLog;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LoadTestLogRepository
        extends JpaRepository<LoadTestLog, Long> {
    // 기본 CRUD만 사용
}
