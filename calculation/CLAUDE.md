# CLAUDE.md - Calculation Framework

> **상위 문서**: 전체 프로젝트 컨텍스트는 [Root CLAUDE.md](../CLAUDE.md) 참조
> **관련 모듈**: [batch](../batch/CLAUDE.md), [monthlyfee](../calculation-policy-monthlyfee/CLAUDE.md), [onetimecharge](../calculation-policy-onetimecharge/CLAUDE.md)
> **아키텍처 가이드**: [ARCHITECTURE.md](../docs/ARCHITECTURE.md)

## 모듈 개요

Calculation 프레임워크는 헥사고날 아키텍처를 따르는 핵심 계산 시스템입니다. 5개의 서브모듈로 구성되어 있으며 도메인 주도 설계 원칙을 따릅니다.

### 서브모듈 구조

```
calculation/
├── calculation-domain/          # 도메인 엔티티 및 비즈니스 로직
├── calculation-api/             # 인바운드 포트 (유스케이스 인터페이스)
├── calculation-port/            # 아웃바운드 포트 (리포지토리 인터페이스)
├── calculation-application/     # 애플리케이션 서비스 레이어
└── calculation-infrastructure/  # 인프라 어댑터 (MyBatis, 리포지토리 구현)
```

## Hexagonal Architecture

### Core Layers

**calculation-domain (도메인 계층)**
- Spring Validation 외 Spring 의존성 없음
- 순수 도메인 로직과 비즈니스 규칙
- 핵심 엔티티: `CalculationResult`, `CalculationContext`, `CalculationTarget`

**calculation-api (인바운드 포트)**
- 유스케이스 인터페이스 정의
- `CalculationCommandUseCase`: 메인 유스케이스 인터페이스
- 요청/응답 모델: `CalculationResultGroup`

**calculation-port (아웃바운드 포트)**
- 리포지토리 및 외부 서비스 포트 인터페이스
- `CalculationResultSavePort`, `ContractDiscountQueryPort`, `RevenueMasterDataQueryPort`

**calculation-application (애플리케이션 계층)**
- 유스케이스 구현: `CalculationCommandService`
- Calculator 오케스트레이션 및 조정
- 할인 및 VAT 계산 서비스
- 수익 마스터 데이터 캐싱: `RevenueMasterDataCacheService`

**calculation-infrastructure (인프라 계층)**
- MyBatis를 사용한 리포지토리 구현
- DTO 변환기 및 데이터 변환 로직
- 아웃바운드 포트 어댑터 구현

## Unified Calculator Pattern

모든 계산기는 표준화된 `Calculator<I>` 인터페이스 패턴을 따릅니다:

### Calculator 인터페이스

```java
public interface Calculator<I> {
    List<I> read(CalculationContext context);
    List<CalculationResult<?>> process(CalculationContext context, I input);
    void write(List<CalculationResult<?>> results);
    void post(CalculationContext context);

    default List<CalculationResult<?>> execute(CalculationContext context) {
        return read(context).stream()
            .flatMap(input -> process(context, input).stream())
            .peek(this::write)
            .toList();
    }
}
```

### 주요 Calculator 구현체

1. **BaseFeeCalculator**: 월정액 계산 (`Calculator<ContractWithProductsAndSuspensions>`)
2. **InstallationFeeCalculator**: 설치비 계산 (`Calculator<InstallationHistory>`)
3. **DeviceInstallmentCalculator**: 단말기 할부 계산 (`Calculator<DeviceInstallmentMaster>`)
4. **DiscountCalculator**: 계약 할인 계산 (특수 할인 처리)
5. **VatCalculator**: VAT 계산 (기존 CalculationResult 및 RevenueMasterData 기반)

### Calculator Pattern 구현 원칙

- **인터페이스 준수**: 완전한 `Calculator<I>` 인터페이스 구현
- **실행 순서 관리**: `@Order` 어노테이션으로 제어된 실행 순서
- **기본 메서드 활용**: 커스텀 로직이 필요없으면 기본 `execute` 메서드 사용
- **Stream 기반 처리**: 명령형 루프보다 함수형 접근 선호
- **컨텍스트 전달**: 일관된 파라미터 접근을 위해 항상 `CalculationContext` 전달

## 핵심 도메인 엔티티

### CalculationTarget
모든 계산 입력을 포함하는 통합 데이터 구조:

```java
public record CalculationTarget(
    Long contractId,
    List<ContractWithProductsAndSuspensions> contractWithProductsAndSuspensions,
    Map<Class<? extends OneTimeChargeDomain>, List<? extends OneTimeChargeDomain>> oneTimeChargeData,
    List<Discount> discounts
) {}
```

### CalculationContext
계산 파라미터 및 컨텍스트를 캡슐화하는 도메인 객체:
- 청구 기간 (billingStartDate, billingEndDate)
- 계산 유형 (billingCalculationType)
- 계산 주기 (billingCalculationPeriod)

### CalculationResult
모든 계산 유형에 대한 통합 결과 객체:
- **Prorate 기능**: 기간 분할 및 비례 계산
- **잔액 추적**: `addBalance()` 및 `subtractBalance()` 메서드
- **PostProcessor 통합**: 함수형 인터페이스를 통한 임베디드 후처리 로직

### ContractWithProductsAndSuspensions
메인 도메인 엔티티 (이전 `Contract`에서 진화):
- 상품 및 정지 관계
- 계약 이력 관리

### Revenue Tracking

**RevenueMasterData**: 수익 항목 마스터 데이터
```java
public record RevenueMasterData(
    String revenueItemId,
    String revenueItemName,
    String revenueTypeCode
) {}
```

**RevenueMasterDataCacheService**:
- `@PostConstruct`로 초기화되는 인메모리 캐싱 서비스
- 애플리케이션 시작 시 모든 수익 마스터 데이터를 메모리에 로드
- 성능을 위한 빠른 조회

## 도메인 모델 진화

### ChargeItem 진화 (주요 리팩토링)
MonthlyChargeItem에서 ChargeItem으로 수익 추적 기능 추가:

- **ChargeItem**: 모든 요금 유형 지원 (월정액 + 일회성)
- **Revenue 통합**: 종합적인 수익 추적을 위한 `revenueItemId` 필드 추가
- **데이터베이스 스키마**: `monthly_charge_item` → `charge_item` 테이블명 변경
- **도메인 일관성**: 월정액 및 일회성 요금에 걸쳐 통합된 요금 항목 표현

### CalculationResult Prorate 기능

정교한 기간 분할 및 잔액 추적:

```java
public List<CalculationResult<?>> prorate(List<DefaultPeriod> periods) {
    return periods.stream()
        .map(period -> {
            // 청구 기간과 할인 기간 간의 교집합 계산
            LocalDate intersectionStart = billingPeriod.getStartDate().isAfter(period.getStartDate())
                ? billingPeriod.getStartDate() : period.getStartDate();
            LocalDate intersectionEnd = billingPeriod.getEndDate().isBefore(period.getEndDate())
                ? billingPeriod.getEndDate() : period.getEndDate();

            // 비례 계산 로직
            long totalDays = ChronoUnit.DAYS.between(billingPeriod.getStartDate(), billingPeriod.getEndDate());
            long intersectionDays = ChronoUnit.DAYS.between(intersectionStart, intersectionEnd);
            BigDecimal prorationRatio = BigDecimal.valueOf(intersectionDays)
                .divide(BigDecimal.valueOf(totalDays), 10, RoundingMode.HALF_UP);

            // 비례 배분된 CalculationResult 생성
        })
        .filter(Objects::nonNull)
        .toList();
}
```

**사용 패턴**:
- DiscountCalculator가 기존 CalculationResult에 할인 적용
- VAT 계산에서 비례 세금 적용
- 여러 겹치는 기간이 있는 복잡한 청구 시나리오 지원

## 개발 패턴 및 Best Practices

### Stream API 사용 패턴

**함수형 처리**:
```java
private <T> void processAndAddResults(
    Collection<T> items,
    BiFunction<CalculationContext, T, List<CalculationResult>> processor,
    CalculationContext context,
    List<CalculationResult> results
) {
    results.addAll(
        items.stream()
            .flatMap(item -> processor.apply(context, item).stream())
            .toList()
    );
}
```

**메서드 참조 활용**:
- `Calculator::process`, `List::stream` 등으로 깔끔한 코드
- Null 안전 연산: `Optional` 및 null 안전 스트림 연산 사용

### Record 사용 가이드라인

- **불변 데이터**: 불변 데이터 구조에 record 사용
- **파라미터 객체**: 관련 파라미터를 record로 그룹화하여 메서드 시그니처 간소화
- **변환 메서드**: `toCalculationContext()`와 같은 변환 메서드 추가
- **빌더 패턴 대안**: 간단한 데이터 구조의 경우 복잡한 빌더 대체 가능

### 비즈니스 규칙 구현

- **일할 계산**: 계약 시작일 포함, 종료일 제외
- **정지 기간**: 상품별 정의된 정지 청구 요율 적용
- **기간 분할**: 정확한 청구를 위해 계약 이력과 서비스 상태 이력 중첩
- **OCP 원칙**: 기존 코드 수정 없이 새로운 B2B 상품 추가 가능
- **계산 기간**: 최대 1개월 (1일 ~ 월말)

### 테스트 가이드라인

**도메인 테스트**:
- 모킹 피하기, 비즈니스 로직 테스트에 집중
- 다양한 계산 시나리오 테스트

**Calculator 테스트**:
- 통합 패턴을 따르는 각 calculator에 대한 개별 테스트 클래스
- `read`, `process`, `write`, `post` 메서드 각각 테스트

**Converter 테스트**:
- `ContractDtoToDomainConverter`, `OneTimeChargeDtoConverter` 데이터 변환 로직 테스트
- DTO와 도메인 간 매핑 정확성 검증

**BigDecimal 테스트**:
- `isCloseTo()` 메서드와 허용 오차를 사용하여 BigDecimal 단언
- 재무 계산의 적절한 스케일 및 반올림 모드 사용

## MyBatis 패턴

### 일관된 명명
- 비즈니스 의도를 반영하는 설명적인 메서드 이름 사용
- 예: `findContractIdsWithPartition`, `findContractWithProductsAndSuspensions`

### 벌크 연산
- 단일 항목 및 벌크 처리를 모두 지원하도록 쿼리 설계
- 조건부 WHERE 절: 웹 서비스와 배치 처리 모두 지원

### ResultMap 구성
- 데이터 그룹화를 위한 적절한 키 정의로 복잡한 ResultMap 구조화
- 복합 키 사용: contractId, productOfferingId, effectiveStartDateTime 등

### SQL 프래그먼트 재사용
- 재사용 가능한 쿼리 부분에 `<sql>` 프래그먼트 사용
- SELECT, WHERE, ORDER BY 절 공유

## 개발 가이드라인

### Jakarta EE 마이그레이션
- Spring Boot 3 호환성을 위해 `jakarta.annotation.PostConstruct` 사용
- `javax.annotation.PostConstruct` 대신 Jakarta 패키지 사용

### Revenue 통합
- 모든 요금 항목에 유효한 수익 항목 ID 포함 필수
- 인메모리 수익 데이터 조회를 위해 `RevenueMasterDataCacheService` 사용

### 캐싱 Best Practices
- 애플리케이션 시작 시 데이터 로딩을 위해 `@PostConstruct` 사용
- 자주 접근하는 마스터 데이터에 대해 인메모리 캐싱 구현

### 복합 키
- 데이터 무결성을 위한 적절한 복합 키로 데이터베이스 스키마 설계
- 예: (contractId, productOfferingId, effectiveStartDateTime, effectiveEndDateTime)

### 함수형 인터페이스
- 계산 결과의 임베디드 비즈니스 로직을 위해 `PostProcessor` 활용
- 람다 및 메서드 참조로 간결한 후처리 로직 구현

### 조건부 로직 제거
- 유형 기반 조건문 피하기
- Map 기반 자동 타입 해결 패턴 사용
- 마커 인터페이스와 제네릭으로 컴파일 타임 타입 검증
