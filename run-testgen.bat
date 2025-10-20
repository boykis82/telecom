@echo off
setlocal enabledelayedexpansion

REM testgen 실행 스크립트 (Windows 메모리 최적화 버전)

REM 기본값 설정
set DEFAULT_MEMORY=4g

REM 사용법 출력 함수
:usage
echo 사용법: %~nx0 [옵션] ^<계약_개수^>
echo.
echo 옵션:
echo   -m, --memory ^<크기^>    JVM 최대 메모리 크기 (기본값: %DEFAULT_MEMORY%)
echo   -h, --help            도움말 출력
echo.
echo 예시:
echo   %~nx0 100000                    # 10만 건 생성 (기본 메모리)
echo   %~nx0 -m 8g 1000000            # 100만 건 생성 (8GB 메모리)
echo   %~nx0 --memory 2g 50000        # 5만 건 생성 (2GB 메모리)
exit /b 1

REM 파라미터 파싱
set MEMORY=%DEFAULT_MEMORY%
set CONTRACT_COUNT=

:parse_args
if "%~1"=="" goto validate_args
if "%~1"=="-m" goto set_memory
if "%~1"=="--memory" goto set_memory
if "%~1"=="-h" goto usage
if "%~1"=="--help" goto usage
if "%~1:~0,1%"=="-" (
    echo 알 수 없는 옵션: %~1
    goto usage
)
if "%CONTRACT_COUNT%"=="" (
    set CONTRACT_COUNT=%~1
    shift
    goto parse_args
) else (
    echo 계약 개수는 하나만 지정할 수 있습니다: %~1
    goto usage
)

:set_memory
set MEMORY=%~2
shift
shift
goto parse_args

:validate_args
REM 계약 개수 검증
if "%CONTRACT_COUNT%"=="" (
    echo 계약 개수를 입력해주세요.
    goto usage
)

REM 숫자인지 검증
echo %CONTRACT_COUNT%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo 계약 개수는 숫자여야 합니다: %CONTRACT_COUNT%
    exit /b 1
)

REM 계약 개수 범위 검증
if %CONTRACT_COUNT% LSS 1 (
    echo 계약 개수는 1 이상이어야 합니다: %CONTRACT_COUNT%
    exit /b 1
)

if %CONTRACT_COUNT% GTR 10000000 (
    echo 계약 개수가 너무 큽니다. 1000만 건 이하로 설정해주세요: %CONTRACT_COUNT%
    exit /b 1
)

REM JAR 파일 경로
set JAR_FILE=testgen\build\libs\testgen-0.0.1-SNAPSHOT.jar

REM JAR 파일 존재 확인
if not exist "%JAR_FILE%" (
    echo JAR 파일이 존재하지 않습니다: %JAR_FILE%
    echo gradle 빌드를 먼저 실행해주세요: gradlew.bat :testgen:bootJar
    exit /b 1
)

REM 메모리 크기에 따른 권장 사항 출력
if %CONTRACT_COUNT% GEQ 1000000 (
    echo ⚠️  대용량 데이터 생성 모드 (100만 건 이상^)
    echo    권장 메모리: 8GB 이상
    echo    예상 소요 시간: 30분 이상
    echo.
    set /p REPLY="계속 진행하시겠습니까? (y/N): "
    if /i not "!REPLY!"=="y" (
        echo 실행이 취소되었습니다.
        exit /b 1
    )
) else if %CONTRACT_COUNT% GEQ 100000 (
    echo 📊 중간 규모 데이터 생성 모드 (10만~100만 건^)
    echo    권장 메모리: 4GB 이상
    echo    예상 소요 시간: 5~30분
) else (
    echo 🚀 소규모 데이터 생성 모드 (10만 건 미만^)
    echo    권장 메모리: 2GB
    echo    예상 소요 시간: 5분 이내
)

echo.
echo === TestGen 실행 준비 ===
echo 계약 개수: %CONTRACT_COUNT% 건
echo JVM 메모리: %MEMORY%
echo JAR 파일: %JAR_FILE%
echo.

REM 실행 시작 시간
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set START_TIME=%%I
set START_TIMESTAMP=%START_TIME:~0,14%

echo === TestGen 실행 시작 ===
echo 시작 시간: %START_TIME:~0,4%-%START_TIME:~4,2%-%START_TIME:~6,2% %START_TIME:~8,2%:%START_TIME:~10,2%:%START_TIME:~12,2%
echo.

REM Java 실행 (극도의 메모리 최적화)
java ^
    -Xms256m ^
    -Xmx%MEMORY% ^
    -XX:+UseG1GC ^
    -XX:MaxGCPauseMillis=100 ^
    -XX:G1HeapRegionSize=16m ^
    -XX:+UseStringDeduplication ^
    -Xlog:gc*:gc.log ^
    -XX:NewRatio=2 ^
    -XX:SurvivorRatio=8 ^
    -XX:MaxTenuringThreshold=1 ^
    -Dspring.main.keep-alive=false ^
    -jar "%JAR_FILE%" ^
    %CONTRACT_COUNT%

set EXIT_CODE=%errorlevel%

REM 실행 완료 후 결과 출력
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set END_TIME=%%I
set END_TIMESTAMP=%END_TIME:~0,14%

echo.
echo === TestGen 실행 완료 ===
echo 종료 시간: %END_TIME:~0,4%-%END_TIME:~4,2%-%END_TIME:~6,2% %END_TIME:~8,2%:%END_TIME:~10,2%:%END_TIME:~12,2%

if %EXIT_CODE% EQU 0 (
    echo ✅ 테스트 데이터 생성이 성공적으로 완료되었습니다!
    echo 📊 생성된 계약 수: %CONTRACT_COUNT% 건
) else (
    echo ❌ 테스트 데이터 생성 중 오류가 발생했습니다. (종료 코드: %EXIT_CODE%^)
    exit /b %EXIT_CODE%
)

endlocal
