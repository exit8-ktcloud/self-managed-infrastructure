package com.exit8.repository;

import com.exit8.domain.DummyDataRecord;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DummyDataRepository
        extends JpaRepository<DummyDataRecord, Long> {
    // findAll(), save() 반복 호출용
}
