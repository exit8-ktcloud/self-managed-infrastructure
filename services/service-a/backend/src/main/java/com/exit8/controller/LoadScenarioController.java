package com.exit8.controller;

import com.exit8.dto.DefaultResponse;
import com.exit8.service.LoadScenarioService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/load")
@RequiredArgsConstructor
public class LoadScenarioController {

    private final LoadScenarioService loadScenarioService;

    @PostMapping("/cpu")
    public DefaultResponse<Void> cpuLoad(@RequestParam long durationMs) {
        loadScenarioService.generateCpuLoad(durationMs);
        return DefaultResponse.success(200);
    }

    @PostMapping("/db-read")
    public DefaultResponse<Void> dbReadLoad(@RequestParam int repeatCount) {
        loadScenarioService.simulateDbReadLoad(repeatCount);
        return DefaultResponse.success(200);
    }

    @PostMapping("/db-write")
    public DefaultResponse<Void> dbWrite(@RequestParam int repeatCount) {
        loadScenarioService.simulateDbWriteLoad(repeatCount);
        return DefaultResponse.success(200);
    }
}