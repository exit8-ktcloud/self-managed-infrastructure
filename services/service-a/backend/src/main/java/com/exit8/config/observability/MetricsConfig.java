package com.exit8.config.observability;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Duration;

/**
 * 커스텀 메트릭 정의
 *
 * - 이름은 Prometheus 규칙 준수
 * - 단위 명시 필수
 */
@Configuration
public class MetricsConfig {

    /**
     * API 응답 시간 측정용 Timer
     */
    @Bean
    public Timer apiLatencyTimer(MeterRegistry registry) {
        return Timer.builder("api_request_latency_seconds")
                .description("API request latency")
                .publishPercentileHistogram()
                .minimumExpectedValue(Duration.ofMillis(10))
                .maximumExpectedValue(Duration.ofSeconds(10))
                .register(registry);
    }

    /**
     * 부하 시나리오 호출 횟수
     */
    @Bean
    public Counter loadScenarioCounter(MeterRegistry registry) {
        return Counter.builder("load_scenario_total")
                .description("Total load scenario executions")
                .register(registry);
    }
}
