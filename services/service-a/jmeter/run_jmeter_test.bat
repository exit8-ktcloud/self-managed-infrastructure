@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM =========================
REM Config
REM =========================
set "TZ=Asia/Seoul"
set "SNAPSHOT_PATH=/api/system/snapshot"
set "MID_SNAPSHOT_DELAY_SEC=15"

REM results 폴더 보장
if not exist "results" (
  mkdir "results"
)

:CHOOSE_TYPE
echo ===========================================
echo   JMeter 부하 테스트 실행 설정
echo ===========================================
echo  1. Read 부하 테스트 (DB 조회)
echo  2. Write 부하 테스트 (DB 쓰기)
set /p TYPE_CHOICE="실행할 테스트 유형을 선택하세요 (1 또는 2): "

if "%TYPE_CHOICE%"=="1" (
    set "MODE=read"
    set "DELAY=150"
) else if "%TYPE_CHOICE%"=="2" (
    set "MODE=write"
    set "DELAY=250"
) else (
    echo [오류] 1 또는 2만 입력 가능합니다.
    goto CHOOSE_TYPE
)

:CHOOSE_TARGET
echo.
echo ===========================================
echo   Target 설정 (1: 로컬 / 2: 서버)
echo ===========================================

set /p TARGET_CHOICE="접속 대상을 선택하세요 (1 또는 2): "

if "%TARGET_CHOICE%"=="1" (
    set "HOST=host.docker.internal"
    set "PORT=8080"
    set "TARGET_NAME=로컬(Local)"
) else if "%TARGET_CHOICE%"=="2" (
    set "HOST=127.0.0.1"
    set "PORT=8081"
    set "TARGET_NAME=서버(Server)"
) else (
    echo [오류] 1 또는 2만 입력 가능합니다.
    goto CHOOSE_TARGET
)

echo.
set /p THREADS="공격 트래픽 동시 실행 스레드 수(ATTACK_THREADS)를 입력하세요: "
if "%THREADS%"=="" (
    echo [오류] 스레드 수를 반드시 입력해야 합니다.
    pause
    exit /b 1
)

echo.
set /p POOL_MODE="풀 고갈 실험 모드를 활성화하시겠습니까? (y/n): "
set "POOL_MODE=!POOL_MODE: =!"

if /i "!POOL_MODE!"=="y" (
    set "HIKARI_OVERRIDE=-Dspring.datasource.hikari.maximum-pool-size=5 -Dspring.datasource.hikari.connection-timeout=1000"
    set "ATTACK_REPEAT=1000"
    set "NORMAL_REPEAT=1"
    set "RAMP=1"
    set "LOOPS=500"
    set "DELAY=0"
    echo [풀 고갈 모드 활성화]
    echo   maximum-pool-size=5
    echo   repeatCount=1000 ^(attack^)
) else (
    set "HIKARI_OVERRIDE="
    :: Read 모드일 경우 반복 횟수를 1로, Write 모드는 20으로 설정
    if "!MODE!"=="read" (
        set "ATTACK_REPEAT=2"
    ) else (
        set "ATTACK_REPEAT=20"
    )
    set "NORMAL_REPEAT=1"
    set "RAMP=30"
    set "LOOPS=50"
    echo [기본 풀 설정 사용]
)

REM =========================
REM Run Metadata / Filenames
REM =========================
for /f "tokens=1-3 delims=:." %%a in ("%TIME%") do (
  set "HH=%%a"
  set "MM=%%b"
  set "SS=%%c"
)
REM Windows DATE 포맷 로케일 이슈를 피하려고, 단순히 원문 기록 + run_id 랜덤 포함
set "RUN_START=%DATE% %TIME%"
set "RAND=%RANDOM%"
set "RUN_ID=!MODE!_!THREADS!_!RAND!"

set "JTL_FILE=results/!RUN_ID!_result.jtl"
set "META_FILE=results/!RUN_ID!_meta.json"
set "SNAP_START_FILE=results/!RUN_ID!_snapshot_start.json"
set "SNAP_MID_FILE=results/!RUN_ID!_snapshot_mid.json"
set "SNAP_END_FILE=results/!RUN_ID!_snapshot_end.json"

echo.
echo ---------------------------------------
echo [실행 설정]
echo   - RUN_ID      : !RUN_ID!
echo   - 테스트 유형 : !MODE!
echo   - Target      : http://!HOST!:!PORT!
echo   - 공격 스레드 : !THREADS!
echo   - Attack Repeat : !ATTACK_REPEAT!
echo   - Attack Delay  : !DELAY! ms
echo   - Attack Ramp   : !RAMP! s
echo   - Attack Loops  : !LOOPS!
echo   - 결과파일     : !JTL_FILE!
echo ---------------------------------------
echo.

REM =========================
REM Snapshot: START
REM =========================
echo [Snapshot] START 수집: http://!HOST!:!PORT!!SNAPSHOT_PATH!
curl -s "http://!HOST!:!PORT!!SNAPSHOT_PATH!" -o "!SNAP_START_FILE!"
if errorlevel 1 echo [WARNING] START snapshot collection failed. Check URL.

REM =========================
REM Snapshot: MID (parallel, after delay)
REM =========================
echo [Snapshot] MID 예약 (!MID_SNAPSHOT_DELAY_SEC!초 후)
start "" cmd /v:on /c "timeout /t !MID_SNAPSHOT_DELAY_SEC! >nul & curl -s http://!HOST!:!PORT!!SNAPSHOT_PATH! -o ""!SNAP_MID_FILE!"""

REM =========================
REM Run JMeter (Docker)
REM =========================

docker run --rm ^
  -e TZ=!TZ! ^
  -e JVM_ARGS="-Duser.timezone=!TZ! !HIKARI_OVERRIDE!" ^
  -v "%cd%:/jmeter" ^
  spring-jmeter ^
  jmeter -n ^
  -t /jmeter/scenarios/attack_!MODE!_vs_normal.jmx ^
  -l /jmeter/!JTL_FILE! ^
  -Jjmeter.save.saveservice.output_format=csv ^
  -Jjmeter.save.saveservice.response_data=false ^
  -Jjmeter.save.saveservice.response_headers=false ^
  -Jjmeter.save.saveservice.requestHeaders=false ^
  -Jjmeter.save.saveservice.samplerData=true ^
  -Jjmeter.save.saveservice.assertion_results=none ^
  -Jjmeter.save.saveservice.bytes=true ^
  -Jjmeter.save.saveservice.latency=true ^
  -Jjmeter.save.saveservice.connect_time=true ^
  -JHOST=!HOST! ^
  -JPORT=!PORT! ^
  -JATTACK_THREADS=!THREADS! ^
  -JATTACK_RAMP=!RAMP! ^
  -JATTACK_DELAY=!DELAY! ^
  -JATTACK_LOOPS=!LOOPS! ^
  -JATTACK_REPEAT=!ATTACK_REPEAT! ^
  -JNORMAL_REPEAT=!NORMAL_REPEAT! ^
  -JNORMAL_THREADS=3 ^
  -JNORMAL_DELAY=1000 ^
  -JNORMAL_LOOPS=50

set "JMETER_EXIT=!ERRORLEVEL!"

REM =========================
REM Snapshot: END
REM =========================
set "RUN_END=%DATE% %TIME%"
echo [Snapshot] END 수집: http://!HOST!:!PORT!!SNAPSHOT_PATH!
curl -s "http://!HOST!:!PORT!!SNAPSHOT_PATH!" -o "!SNAP_END_FILE!"
if errorlevel 1 echo [WARNING] END snapshot collection failed. Check URL.

REM =========================
REM Meta JSON write (no external tools)
REM =========================
(
  echo {
  echo   "run_id": "!RUN_ID!",
  echo   "run_start": "!RUN_START!",
  echo   "run_end": "!RUN_END!",
  echo   "mode": "!MODE!",
  echo   "pool_mode": "!POOL_MODE!",
  echo   "target": { "host": "!HOST!", "port": !PORT!, "protocol": "http" },
  echo   "attack": {
  echo     "threads": !THREADS!,
  echo     "repeat": !ATTACK_REPEAT!,
  echo     "delay_ms": !DELAY!,
  echo     "ramp_s": !RAMP!,
  echo     "loops": !LOOPS!
  echo   },
  echo   "normal": {
  echo     "threads": 3,
  echo     "repeat": !NORMAL_REPEAT!,
  echo     "delay_ms": 1000,
  echo     "loops": 50
  echo   },
  echo   "files": {
  echo     "jtl": "!JTL_FILE!",
  echo     "snapshot_start": "!SNAP_START_FILE!",
  echo     "snapshot_mid": "!SNAP_MID_FILE!",
  echo     "snapshot_end": "!SNAP_END_FILE!"
  echo   },
  echo   "jmeter_exit_code": !JMETER_EXIT!
  echo }
) > "!META_FILE!"

echo.
echo ===========================================
echo [완료] 실행 결과
echo   - JTL       : !JTL_FILE!
echo   - META      : !META_FILE!
echo   - SNAP start: !SNAP_START_FILE!
echo   - SNAP mid  : !SNAP_MID_FILE!
echo   - SNAP end  : !SNAP_END_FILE!
echo   - exit code : !JMETER_EXIT!
echo ===========================================
echo.

pause
exit /b !JMETER_EXIT!