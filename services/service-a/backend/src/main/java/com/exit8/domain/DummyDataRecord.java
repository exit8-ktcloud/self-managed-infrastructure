package com.exit8.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "spring_dummy_data_records")
@Getter
@NoArgsConstructor
public class DummyDataRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * 의미 없는 페이로드
     * - 문자열 길이만으로도 DB 부하 조절 가능
     */
    @Column(nullable = false, length = 255)
    private String payload;

    public DummyDataRecord(String payload) {
        this.payload = payload;
    }
}
