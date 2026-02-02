package com.exit8.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
public class DefaultRequest<T> {

    private T data;

    public DefaultRequest(T data) {
        this.data = data;
    }
}
