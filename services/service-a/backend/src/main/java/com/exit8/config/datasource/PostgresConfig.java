package com.exit8.config.datasource;

import org.springframework.context.annotation.Configuration;

/**
 * PostgreSQL DataSource 설정
 *
 * - 현재는 application.yml 기반 기본 설정 사용
 * - 추후 커넥션 풀(HikariCP) 튜닝 시 이 클래스에서 확장 예정
 */
@Configuration
public class PostgresConfig {
    // intentionally empty
}
