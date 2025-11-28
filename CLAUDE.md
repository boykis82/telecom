# CLAUDE.md

이 파일은 이 저장소의 코드 작업 시 Claude Code(claude.ai/code)를 위한 가이드를 제공합니다.

## 개요

이 시스템은 한국 통신 서비스를 위한 헥사고날 아키텍처를 구현한 Spring Boot 3 기반 통신 청구 계산 시스템입니다. TMForum 사양을 따르는 복잡한 일할 계산 로직으로 월정액을 계산합니다.

**프로젝트 이름**: `telecom-billing`
**그룹 ID**: `me.realimpact.telecom.billing`
**버전**: `0.0.1-SNAPSHOT`
**자바 버전**: 25
**스프링 부트 버전**: 3.5.8

## 문서 구조

자세한 정보는 다음을 참조하세요:
- **[Architecture Guide](./docs/ARCHITECTURE.md)**: 기술 아키텍처, 모듈 구조, Spring Batch, MyBatis 구성
- **[Business Domain Guide](./docs/BUSINESS_DOMAIN.md)**: 비즈니스 로직, 도메인 모델, calculator 패턴, 한국 통신 청구 규칙

### 모듈별 문서

각 모듈에는 모듈별 가이드가 포함된 자체 CLAUDE.md 파일이 있습니다:
- **[Calculation Framework](./calculation/CLAUDE.md)**: 핵심 계산 프레임워크, 헥사고날 아키텍처, calculator 패턴
- **[Monthly Fee Policy](./calculation-policy-monthlyfee/CLAUDE.md)**: 월정액 계산, 가격 정책, 일할 계산
- **[One-Time Charge Policy](./calculation-policy-onetimecharge/CLAUDE.md)**: 설치비, 단말기 할부, 확장성 패턴
- **[Batch Processing](./batch/CLAUDE.md)**: Spring Batch 아키텍처, 이중 처리 모드, 문제 해결
- **[Web Service](./web-service/CLAUDE.md)**: REST API, 검증, 예외 처리, Swagger
- **[Test Data Generation](./testgen/CLAUDE.md)**: 테스트 데이터 생성 유틸리티

## 개발 명령어

### 빌드 및 테스트

**Unix/Linux/macOS:**
```bash
# 모든 모듈 빌드
./gradlew build

# 테스트 실행
./gradlew test

# 특정 모듈 테스트 실행
./gradlew :calculation:calculation-domain:test
./gradlew :calculation-policy-monthlyfee:test
./gradlew :web-service:test
./gradlew :batch:test

# 단일 테스트 클래스 실행
./gradlew :calculation-policy-monthlyfee:test --tests "MonthlyFeeCalculationIntegrationTest"

# 클린 빌드
./gradlew clean build
```

**Windows:**
```batch
REM 모든 모듈 빌드
gradlew.bat build

REM 테스트 실행
gradlew.bat test

REM 특정 모듈 테스트 실행
gradlew.bat :calculation:calculation-domain:test
gradlew.bat :calculation-policy-monthlyfee:test
gradlew.bat :web-service:test
gradlew.bat :batch:test

REM 단일 테스트 클래스 실행
gradlew.bat :calculation-policy-monthlyfee:test --tests "MonthlyFeeCalculationIntegrationTest"

REM 클린 빌드
gradlew.bat clean build
```

### 애플리케이션 실행

**웹 서비스:**
```bash
# Unix/Linux/macOS
./gradlew :web-service:bootRun

# Windows
gradlew.bat :web-service:bootRun
```

**배치 처리:**
```bash
# Unix/Linux/macOS
./run-batch-jar.sh                    # Thread pool 실행
./run-partitioned-batch-jar.sh        # Partitioner 실행

# Windows
run-batch-jar.bat                     # Thread pool 실행
run-partitioned-batch-jar.bat         # Partitioner 실행
```

**테스트 데이터 생성:**
```bash
# Unix/Linux/macOS
./run-testgen.sh 100000               # 10만개 계약 생성

# Windows
run-testgen.bat 100000                # 10만개 계약 생성
```

## 아키텍처 개요

### 모듈 구조

```
telecom/
├── calculation/                          # 핵심 헥사고날 아키텍처 프레임워크
│   ├── calculation-domain/              # 도메인 엔티티 및 비즈니스 로직
│   ├── calculation-api/                 # 인바운드 포트 인터페이스 (유스케이스)
│   ├── calculation-port/                # 아웃바운드 포트 인터페이스
│   ├── calculation-application/         # 애플리케이션 서비스 레이어
│   └── calculation-infrastructure/      # 인프라 어댑터 및 리포지토리
├── calculation-policy-monthlyfee/       # 월정액 정책 구현 (독립 모듈)
├── calculation-policy-onetimecharge/    # 일회성 요금 정책 구현 (독립 모듈)
├── web-service/                         # REST API 레이어
├── batch/                               # Spring Batch 처리
└── testgen/                             # 테스트 데이터 생성 유틸리티
```

### 주요 기술

- **Spring Boot 3.5.8** with **Java 25**
- **헥사고날 아키텍처** - 명확한 관심사 분리
- **MyBatis 3.0.3** - 복잡한 SQL 쿼리 및 배치 처리
- **Spring Batch** - 대규모 다중 스레드 데이터 처리
- **JPA with QueryDSL 5.0.0** - 도메인 엔티티 쿼리
- **SpringDoc OpenAPI 3** - API 문서화
- **MySQL** - HikariCP 연결 풀링을 사용하는 주 데이터베이스
- **H2** - 웹 서비스 개발/테스트용
- **JUnit 5** - 테스트

## 공통 개발 규칙

### 코드 스타일
- DTO 및 파라미터 객체에 **record** 사용 (`CalculationTarget`, `CalculationParameters`)
- 보일러플레이트 코드를 최소화하기 위해 **Lombok** 어노테이션 사용 (`@RequiredArgsConstructor`, `@Getter` 등)
- 명확한 변수 및 메서드 이름으로 클린 코드 원칙 준수
- JPA 엔티티는 이름 충돌을 피하기 위해 'JpaEntity' 접미사 사용
- JpaRepository 인터페이스는 'JpaRepository' 접미사 사용
- 컬렉션 처리 및 함수형 변환에 **Stream API** 선호

### 테스트 가이드라인
- **도메인 테스트**: 모킹 피하기, 비즈니스 로직 테스트에 집중
- **통합 테스트**: 완전한 워크플로우를 위한 엔드투엔드 시나리오
- **테스트 이름**: 비즈니스 시나리오를 반영하는 설명적인 메서드 이름 사용
- **커버리지**: 다양한 조합, 상호작용 및 엣지 케이스 테스트
- 모듈별 테스트 가이드라인은 각 모듈의 CLAUDE.md 참조

### Record 사용 가이드라인
- **불변 데이터**: 불변 데이터 구조에 record 사용
- **파라미터 객체**: 관련 파라미터를 record로 그룹화하여 메서드 시그니처 간소화
- **변환 메서드**: `toCalculationContext()`와 같은 변환 메서드 추가하여 원활한 변환
- **빌더 패턴 대안**: 간단한 데이터 구조의 경우 record가 복잡한 빌더를 대체 가능

## 최근 주요 변경사항 (2024-2025)

### 모듈 구조 리팩토링 (2025년 10월)
관심사 분리 및 정책 독립성 개선을 위한 모듈 재구성 완료:

**이전:**
- 정책 모듈이 `calculation/` 아래에 중첩

**이후:**
- 정책 모듈이 이제 최상위 독립 모듈
- 핵심 계산 프레임워크는 `calculation/` 아래 유지
- 핵심 계산 구조를 건드리지 않고 새 정책 모듈 추가 용이

**영향:**
- 패키지 구조 변경 없음 (여전히 `me.realimpact.telecom.calculation.policy.*`)
- 소스 코드 수정 불필요
- 의존성 관리 간소화

### ChargeItem 리팩토링
수익 추적 기능을 포함한 MonthlyChargeItem에서 ChargeItem으로의 주요 리팩토링 완료:

**변경사항:**
- `MonthlyChargeItem` → `ChargeItem` 클래스명 변경
- 종합적인 수익 추적을 위한 `revenueItemId` 필드 추가
- 데이터베이스 테이블명 변경: `monthly_charge_item` → `charge_item`
- 월정액 및 일회성 요금 전반에 걸친 통합 요금 항목 표현

### OneTimeCharge Spring Bean 자동 주입 아키텍처 (2025)
조건부 로직을 제거하고 완전한 확장성을 달성하기 위한 주요 리팩토링 완료:

**주요 기능:**
- 모든 OneTimeCharge 도메인 객체를 위한 `OneTimeChargeDomain` 마커 인터페이스
- 타입 기반 조건문을 제거하는 Map 기반 자동 의존성 주입
- 제로 코드 확장성: `@Component` 어노테이션이 있는 2-3개 클래스만 생성하여 새 요금 타입 추가
- 실행 순서를 위한 `@Order`와 자동 Spring DI 통합

**확장 패턴:**
```java
// 새로운 OneTimeCharge 타입 - 필요한 클래스만
@Component
public class MaintenanceFeeDataLoader implements OneTimeChargeDataLoader<MaintenanceFee> {
    // 구현이 자동으로 처리 파이프라인에 통합됨
}

@Component
@Order(300)
public class MaintenanceFeeCalculator implements OneTimeChargeCalculator<MaintenanceFee> {
    // 다른 calculator와 함께 순서대로 자동 실행됨
}
```

## 개발 가이드라인

### Jakarta EE 마이그레이션
- Spring Boot 3 호환성을 위해 `javax.annotation.PostConstruct` 대신 `jakarta.annotation.PostConstruct` 사용

### Revenue 통합
- 모든 요금 항목에 유효한 수익 항목 ID 포함 필수
- 인메모리 수익 데이터 조회를 위해 `RevenueMasterDataCacheService` 사용

### 캐싱 Best Practices
- 애플리케이션 시작 시 데이터 로딩을 위해 `@PostConstruct` 사용
- 자주 접근하는 마스터 데이터에 대해 인메모리 캐싱 구현

### BigDecimal 정밀도
- 재무 계산을 위해 적절한 스케일 및 반올림 모드 사용
- BigDecimal 단언을 위해 허용 오차가 있는 `isCloseTo()` 테스트

### Stream API 사용
- **함수형 처리**: 컬렉션 처리를 위해 `flatMap`과 함께 Stream API 선호
- **메서드 참조**: 깔끔한 코드를 위해 메서드 참조 사용
- **Null 안전 연산**: `Optional` 및 null 안전 스트림 연산 사용

## 주요 비즈니스 컨텍스트

이 시스템은 다음과 같은 특정 요구사항으로 한국 통신 청구를 구현합니다:
- **월정액 계산** - 복잡한 일할 계산 규칙 및 정지 처리
- **일회성 요금** - 설치비 및 단말기 할부 처리 포함
- **계약 할인** - 요율 기반 및 금액 기반 할인 계산
- **VAT 계산** - 기존 결과 및 수익 마스터 데이터 매핑 기반
- **서비스 정지** - 구성 가능한 청구 요율 및 기간 기반 계산
- **B2B 상품** - 여러 가격 전략 및 동적 정책 선택
- **TMForum 사양** - 확장 가능한 아키텍처 준수

핵심 복잡성:
1. **기간 분할**: 계약, 상품, 서비스 상태 변경 시 청구 기간을 정확하게 분할
2. **정책 적용**: 각 계산 세그먼트에 올바른 가격 정책 적용
3. **데이터 오케스트레이션**: 여러 데이터 소스 조정 (계약, 상품, 정지, 설치, 할부, 할인)
4. **계산 통합**: 통합 calculator 패턴을 통해 다양한 요금 타입 처리
5. **할인 적용**: 잔액 추적으로 기존 계산 결과에 할인 적용
6. **VAT 처리**: 자동 수익 매핑으로 해당 수익 항목에 VAT 계산
