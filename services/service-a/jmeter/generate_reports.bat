@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:CHOOSE_TYPE
echo ===========================================
echo   JMeter 리포트 생성 유형 선택
echo ===========================================
echo  1. Read  (read_*_result.jtl 스캔)
echo  2. Write (write_*_result.jtl 스캔)
set /p TYPE_CHOICE="번호를 선택하세요 (1 또는 2): "

if "%TYPE_CHOICE%"=="1" (
    set "MODE=read"
) else if "%TYPE_CHOICE%"=="2" (
    set "MODE=write"
) else (
    echo [오류] 잘못된 선택입니다. 다시 입력해주세요.
    timeout /t 2 >nul
    cls
    goto CHOOSE_TYPE
)

set "TARGET_DIR=results"
set "FOUND=0"

echo.
echo [알림] %TARGET_DIR% 폴더에서 "!MODE!_*_result.jtl" 파일을 스캔합니다...
echo ---------------------------------------

if not exist "%TARGET_DIR%" (
  echo [오류] results 폴더가 없습니다: %cd%\%TARGET_DIR%
  pause
  exit /b 1
)


REM =========================
REM Summary output init
REM =========================
set "SUMMARY_CSV=%TARGET_DIR%\summary_!MODE!.csv"
if not exist "!SUMMARY_CSV!" (
  echo run_id,mode,normal_p95_ms,normal_timeout_pct,normal_5xx_pct,normal_503_pct,normal_total,timeout_count,err5xx_count,err503_count,hikari_timeout_start,hikari_timeout_end,hikari_timeout_delta,snapshot_cb_state_end > "!SUMMARY_CSV!"
)

REM =========================
REM Scan & generate report + metrics
REM =========================
for %%f in ("%TARGET_DIR%\!MODE!_*_result.jtl") do (
    set "FOUND=1"
    set "BASE=%%~nf"
    set "JTL_WIN=%%~ff"
    set "JTL_IN=/jmeter/results/%%~nxf"
    set "OUT_DIR=/jmeter/results/report_!BASE!"

    echo [작업 시작] !BASE!
    echo [대상 파일] %%~ff
    echo [출력 폴더] %TARGET_DIR%\report_!BASE!

    REM 1) HTML report
    docker run --rm ^
      -v "%cd%:/jmeter" ^
      spring-jmeter ^
      jmeter -g "!JTL_IN!" -o "!OUT_DIR!"

    if errorlevel 1 (
        echo [오류] !BASE! 보고서 생성 실패
        echo ---------------------------------------
        REM 보고서 실패면 metrics도 스킵
        goto :CONTINUE_LOOP
    ) else (
        echo [완료] !BASE! 보고서 생성 성공
    )

    REM 2) Compute metrics from JTL + Snapshots (PowerShell)
    set "JTL_HOST=%%f"
    set "RUN_KEY=!BASE:_result=!"
    set "SNAP_START=%cd%\%TARGET_DIR%\!RUN_KEY!_snapshot_start.json"
    set "SNAP_END=%cd%\%TARGET_DIR%\!RUN_KEY!_snapshot_end.json"
    set "TIMEOUT_MS=5000"
    if /i "!MODE!"=="read" set "TIMEOUT_MS=3000"

    powershell -NoProfile -ExecutionPolicy Bypass ^
    -Command ^
    "$jtl = '%cd%\!JTL_HOST:'=''!';" ^
    "$mode = '!MODE!';" ^
    "$run  = '!RUN_ID!';" ^
    "$timeoutMs = [int]'!TIMEOUT_MS!';" ^
    "$rows = Import-Csv $jtl;" ^
    "if(-not $rows){ throw 'Empty JTL'; }" ^
    "$cols = $rows[0].PSObject.Properties.Name;" ^
    "if(-not ($cols -contains 'label') -or -not ($cols -contains 'elapsed')){ throw 'Missing required columns(label/elapsed)'; }" ^
    "$normal = $rows | Where-Object { $_.label -match 'Normal' };" ^
    "if(-not $normal){ throw 'No Normal samples (label contains Normal)'; }" ^
    "$nCount = ($normal | Measure-Object).Count;" ^
    "$elapsed = $normal | ForEach-Object { [int]$_.elapsed } | Sort-Object;" ^
    "$idx = [int]([math]::Ceiling($elapsed.Count*0.95)-1);" ^
    "if($idx -lt 0){ $idx = 0 }" ^
    "$p95 = $elapsed[$idx];" ^
    "$hasCode = $cols -contains 'responseCode';" ^
    "$hasMsg  = $cols -contains 'responseMessage';" ^
    "$timeout = $normal | Where-Object { ([int]$_.elapsed -ge $timeoutMs) -and ( ($hasCode -and [string]::IsNullOrWhiteSpace($_.responseCode)) -or ($hasMsg -and ($_.responseMessage -match 'timeout')) ) };" ^
    "$tCount = ($timeout | Measure-Object).Count;" ^
    "$tPct = if($nCount -eq 0){ 0 } else { [math]::Round(($tCount/$nCount)*100, 4) };" ^
    "$err5xx = @();" ^
    "$err503 = @();" ^
    "if($hasCode){" ^
    "  $err5xx = $normal | Where-Object { $_.responseCode -match '^\d+$' -and ([int]$_.responseCode -ge 500) };" ^
    "  $err503 = $normal | Where-Object { $_.responseCode -eq '503' };" ^
    "}" ^
    "$c5xx = ($err5xx | Measure-Object).Count;" ^
    "$c503 = ($err503 | Measure-Object).Count;" ^
    "$p5xx = if($nCount -eq 0){ 0 } else { [math]::Round(($c5xx/$nCount)*100, 4) };" ^
    "$p503 = if($nCount -eq 0){ 0 } else { [math]::Round(($c503/$nCount)*100, 4) };" ^
    "$snapStartPath = '!SNAP_START!';" ^
    "$snapEndPath   = '!SNAP_END!';" ^
    "$hStart = 0; $hEnd = 0; $cbEnd = '';" ^
    "if(Test-Path $snapStartPath){" ^
    "  try{ $js = (Get-Content $snapStartPath -Raw) | ConvertFrom-Json; $hStart = [double]$js.data.hikariTimeoutCount } catch{}" ^
    "}" ^
    "if(Test-Path $snapEndPath){" ^
    "  try{ $je = (Get-Content $snapEndPath -Raw) | ConvertFrom-Json; $hEnd = [double]$je.data.hikariTimeoutCount; $cbEnd = [string]$je.data.circuitBreakerState } catch{}" ^
    "}" ^
    "$hDelta = [math]::Round(($hEnd - $hStart), 4);" ^
    "$line = '{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13}' -f $run,$mode,$p95,$tPct,$p5xx,$p503,$nCount,$tCount,$c5xx,$c503,$hStart,$hEnd,$hDelta,$cbEnd;" ^
    "Add-Content -Path '!SUMMARY_CSV!' -Value $line;" ^
    "Write-Host ('[METRIC] ' + $line);"

    if errorlevel 1 (
        echo [오류] !BASE! metrics 계산 실패 (JTL 컬럼/label 확인 필요)
    )

    :CONTINUE_LOOP
    echo ---------------------------------------
)

if "!FOUND!"=="0" (
    echo [경고] %TARGET_DIR% 폴더에 "!MODE!_*_result.jtl" 파일이 없습니다.
    echo 현재 위치: %cd%\%TARGET_DIR%
)

echo.
echo [완료] 요약 CSV: !SUMMARY_CSV!
echo 모든 작업이 완료되었습니다.
pause