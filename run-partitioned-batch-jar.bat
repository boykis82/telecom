@echo off
setlocal enabledelayedexpansion

REM Partitioner 기반 배치 JAR 실행 스크립트 (Windows)

echo === Partitioner 기반 배치 JAR 실행 스크립트 ===
echo.

REM 기본 파라미터 설정
set DEFAULT_START_DATE=2025-03-01
set DEFAULT_END_DATE=2025-03-31
set DEFAULT_THREAD_COUNT=8
set DEFAULT_BILLING_CALCULATION_TYPE=B0
set DEFAULT_BILLING_CALCULATION_PERIOD=0
set JOB_NAME=partitionedMonthlyFeeCalculationJob

REM 파라미터 입력 받기
set /p START_DATE="청구 시작일을 입력하세요 (기본값: %DEFAULT_START_DATE%): "
if "%START_DATE%"=="" set START_DATE=%DEFAULT_START_DATE%

set /p END_DATE="청구 종료일을 입력하세요 (기본값: %DEFAULT_END_DATE%): "
if "%END_DATE%"=="" set END_DATE=%DEFAULT_END_DATE%

set /p THREAD_COUNT="파티션 수 (쓰레드 수)를 입력하세요 (기본값: %DEFAULT_THREAD_COUNT%, application property 오버라이드): "
if "%THREAD_COUNT%"=="" set THREAD_COUNT=%DEFAULT_THREAD_COUNT%

set /p BILLING_CALCULATION_TYPE="청구 계산 유형을 입력하세요 (기본값: %DEFAULT_BILLING_CALCULATION_TYPE%): "
if "%BILLING_CALCULATION_TYPE%"=="" set BILLING_CALCULATION_TYPE=%DEFAULT_BILLING_CALCULATION_TYPE%

set /p BILLING_CALCULATION_PERIOD="청구 계산 기간을 입력하세요 (기본값: %DEFAULT_BILLING_CALCULATION_PERIOD%): "
if "%BILLING_CALCULATION_PERIOD%"=="" set BILLING_CALCULATION_PERIOD=%DEFAULT_BILLING_CALCULATION_PERIOD%

set /p CONTRACT_IDS="계약 ID를 입력하세요 (선택사항, 전체 조회하려면 엔터. 여러 계약 처리하려면 ,로 구분): "

echo.
echo === Partitioner 배치 파라미터 ===
echo Job 이름: %JOB_NAME%
echo 청구 시작일: %START_DATE%
echo 청구 종료일: %END_DATE%
echo 파티션 수 (쓰레드 수): %THREAD_COUNT% (application property 오버라이드)
echo 청구 계산 유형: %BILLING_CALCULATION_TYPE% (application property 오버라이드)
echo 청구 계산 기간: %BILLING_CALCULATION_PERIOD% (application property 오버라이드)
if "%CONTRACT_IDS%"=="" (
    echo 계약 ID: 전체
) else (
    echo 계약 ID: %CONTRACT_IDS%
)
echo.
echo 파티션 로직: contractId %% %THREAD_COUNT% = partitionKey
echo.

REM JAR 파일 빌드
echo JAR 파일을 빌드합니다...
call gradlew.bat :batch:bootJar

if errorlevel 1 (
    echo JAR 빌드에 실패했습니다.
    exit /b 1
)

REM JAR 파일 위치
set JAR_FILE=batch\build\libs\batch-0.0.1-SNAPSHOT.jar

if not exist "%JAR_FILE%" (
    echo JAR 파일을 찾을 수 없습니다: %JAR_FILE%
    exit /b 1
)

REM 중복 실행 방지를 위한 현재 시각 타임스탬프
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set TIMESTAMP=%datetime:~0,14%

REM 배치 실행 명령어 생성
if "%CONTRACT_IDS%"=="" (
    set BATCH_COMMAND=java -jar %JAR_FILE% --spring.batch.job.names=%JOB_NAME% timestamp=%TIMESTAMP% --billingStartDate=%START_DATE% --billingEndDate=%END_DATE% --batch.thread-count=%THREAD_COUNT% --billingCalculationType=%BILLING_CALCULATION_TYPE% --billingCalculationPeriod=%BILLING_CALCULATION_PERIOD%
) else (
    set BATCH_COMMAND=java -jar %JAR_FILE% --spring.batch.job.names=%JOB_NAME% timestamp=%TIMESTAMP% --billingStartDate=%START_DATE% --billingEndDate=%END_DATE% --contractIds=%CONTRACT_IDS% --batch.thread-count=%THREAD_COUNT% --billingCalculationType=%BILLING_CALCULATION_TYPE% --billingCalculationPeriod=%BILLING_CALCULATION_PERIOD%
)

echo 실행 명령어: !BATCH_COMMAND!
echo.

REM 배치 실행
echo === Partitioner 배치 실행 시작 ===
echo 각 파티션이 독립적으로 처리됩니다...
echo.

!BATCH_COMMAND!

echo.
echo === Partitioner 배치 실행 완료 ===

endlocal
