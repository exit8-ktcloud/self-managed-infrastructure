package com.exit8.service;

import com.exit8.domain.DummyDataRecord;
import com.exit8.domain.LoadTestLog;
import com.exit8.exception.ApiException;
import com.exit8.repository.DummyDataRepository;
import com.exit8.repository.LoadTestLogRepository;
import io.micrometer.core.annotation.Timed;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class LoadScenarioService {

    private final DummyDataRepository dummyDataRepository;
    private final LoadTestLogRepository loadTestLogRepository;

    private static final int MAX_REPEAT = 10_000;
    private static final long MAX_DURATION_MS = 10_000;

    /**
     * CPU 재귀 부하
     * CPU 부하 → CircuitBreaker OPEN까지 연결 (추후)
     */
    @Timed(
            value = "load.scenario",
            extraTags = {"type", "cpu"},
            histogram = true
    )
    public void generateCpuLoad(long durationMs) {
        if (durationMs <= 0 || durationMs > MAX_DURATION_MS) {
            throw new ApiException(
                    "INVALID_PARAM",
                    "durationMs must be between 1 and 10000 ms",
                    HttpStatus.BAD_REQUEST
            );
        }


        long start = System.currentTimeMillis();
        long end = start + durationMs;

        while (System.currentTimeMillis() < end) {
            Math.sqrt(System.nanoTime());
        }

        long duration = System.currentTimeMillis() - start;

        loadTestLogRepository.save(
                new LoadTestLog("CPU", duration)
        );
    }


    /**
     * DB READ 부하
     */
    @Timed(
            value = "load.scenario",
            extraTags = {"type", "db_read"},
            histogram = true
    )
    public void simulateDbReadLoad(int repeatCount) {
        if (repeatCount <= 0 || repeatCount > MAX_REPEAT) {
            throw new ApiException(
                    "INVALID_PARAM",
                    "repeatCount must be between 1 and 10000",
                    HttpStatus.BAD_REQUEST
            );
        }

        long start = System.currentTimeMillis();

        for (int i = 0; i < repeatCount; i++) {
            List<DummyDataRecord> records =
                    dummyDataRepository.findAll();
        }

        long duration = System.currentTimeMillis() - start;

        loadTestLogRepository.save(
                new LoadTestLog("DB_READ", duration)
        );
    }

    /**
     * DB write 부하
     */
    @Timed(
            value = "load.scenario",
            extraTags = {"type", "db_write"},
            histogram = true
    )
    public void simulateDbWriteLoad(int repeatCount) {
        if (repeatCount <= 0 || repeatCount > MAX_REPEAT) {
            throw new ApiException(
                    "INVALID_PARAM",
                    "repeatCount must be between 1 and 10000",
                    HttpStatus.BAD_REQUEST
            );
        }

        long start = System.currentTimeMillis();

        for (int i = 0; i < repeatCount; i++) {
            dummyDataRepository.save(
                    new DummyDataRecord("payload-" + i)
            );
        }

        long duration = System.currentTimeMillis() - start;

        loadTestLogRepository.save(
                new LoadTestLog("DB_WRITE", duration)
        );
    }
}
