package com.exit8.service;

import com.exit8.domain.DummyDataRecord;
import com.exit8.domain.LoadTestLog;
import com.exit8.exception.ApiException;
import com.exit8.repository.DummyDataRepository;
import com.exit8.repository.LoadTestLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class LoadScenarioService {

    private final DummyDataRepository dummyDataRepository;
    private final LoadTestLogRepository loadTestLogRepository;

    /**
     * CPU 재귀 부하
     * CPU 부하 → CircuitBreaker OPEN까지 연결 (추후)
     */
    public void generateCpuLoad(long durationMs) {
        if (durationMs > 10_000) {
            throw new ApiException("INVALID_PARAM", "durationMs max is 10000ms");
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
    public void simulateDbReadLoad(int repeatCount) {
        if (repeatCount > 10_000) {
            throw new ApiException("INVALID_PARAM", "repeatCount max is 10000");
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
    public void simulateDbWriteLoad(int repeatCount) {
        if (repeatCount > 10_000) {
            throw new ApiException("INVALID_PARAM", "repeatCount max is 10000");
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
