# CLAUDE.md - One-Time Charge Policy

> **상위 문서**: [Root CLAUDE.md](../CLAUDE.md) | [Calculation Framework](../calculation/CLAUDE.md)
> **관련 모듈**: [monthlyfee](../calculation-policy-monthlyfee/CLAUDE.md), [batch](../batch/CLAUDE.md)
> **확장성 설계**: [EXTENSIBLE_CALCULATION_DESIGN.md](../EXTENSIBLE_CALCULATION_DESIGN.md)

## 모듈 개요

One-Time Charge Policy 모듈은 일회성 요금 계산 정책 구현을 담당하는 독립적인 모듈입니다. 설치비, 단말기 할부 등의 일회성 요금을 처리하며, 뛰어난 확장성 아키텍처를 제공합니다.

**패키지**: `me.realimpact.telecom.calculation.policy.onetimecharge`
**위치**: `/calculation-policy-onetimecharge` (최상위 독립 모듈)

### 의존성

- calculation-domain
- calculation-application
- MyBatis Spring Boot Starter
- MySQL Connector J
- Spring Context and Jakarta Annotations

### 주요 컴포넌트

```
calculation-policy-onetimecharge/
├── dto/                  # OneTimeCharge DTOs
├── calculator/           # Calculator 구현체
├── loader/              # 데이터 로더
├── converter/           # 도메인 변환기
├── adapter/             # 리포지토리 어댑터
│   └── mybatis/         # MyBatis 매퍼
└── port/                # 포트 정의
```

## OneTimeCharge Spring Bean 자동 주입 아키텍처

### 핵심 아키텍처 컴포넌트

이 모듈의 가장 중요한 특징은 조건부 로직을 완전히 제거하고 Spring DI 패턴으로 완벽한 확장성을 달성한 것입니다.

#### 1. OneTimeChargeDomain 마커 인터페이스
모든 OneTimeCharge 도메인 객체를 위한 마커:

```java
public interface OneTimeChargeDomain {
    Long getContractId();
}
```

#### 2. OneTimeChargeCalculator 인터페이스
통합 calculator 인터페이스:

```java
public interface OneTimeChargeCalculator<T extends OneTimeChargeDomain>
    extends Calculator<T> {

    Class<T> getInputType();
}
```

#### 3. OneTimeChargeDataLoader 인터페이스
데이터 로딩 추상화:

```java
public interface OneTimeChargeDataLoader<T extends OneTimeChargeDomain> {
    List<T> loadData(CalculationContext context, Long contractId);
    Class<T> getDataType();
}
```

#### 4. Map 기반 자동 의존성 주입
모든 유형 기반 조건문 제거:

```java
// CalculationTarget에서 Map 구조로 진화
public record CalculationTarget(
    Long contractId,
    List<ContractWithProductsAndSuspensions> contractWithProductsAndSuspensions,
    Map<Class<? extends OneTimeChargeDomain>, List<? extends OneTimeChargeDomain>> oneTimeChargeData,
    List<Discount> discounts
) {}

// 서비스에서 자동 Map 기반 처리
private final Map<Class<? extends OneTimeChargeDomain>, OneTimeChargeCalculator<? extends OneTimeChargeDomain>>
        calculatorMap;
private final Map<Class<? extends OneTimeChargeDomain>, OneTimeChargeDataLoader<? extends OneTimeChargeDomain>>
        dataLoaderMap;
```

### 아키텍처 이점

1. **조건부 로직 완전 제거**: ChunkedContractReader나 CalculationCommandService에 타입 기반 if/else 문 불필요
2. **제로 코드 확장성**: 새로운 OneTimeCharge 타입 추가 시 `@Component` 어노테이션이 있는 2-3개의 클래스만 생성
3. **자동 Spring DI 통합**: Stream collector를 사용하여 등록된 빈에서 Map이 자동 채워짐
4. **타입 안전성**: 마커 인터페이스와 제네릭으로 컴파일 타임 타입 검증 보장
5. **하위 호환성**: 기존 테스트 및 API가 호환성 메서드로 계속 작동

## 구현된 OneTimeCharge 타입

### 1. InstallationHistory (설치비)

**도메인 객체**:
```java
public class InstallationHistory implements OneTimeChargeDomain {
    private Long contractId;
    private LocalDate installationDate;
    private BigDecimal installationFee;
    // ...
}
```

**데이터 로더**:
```java
@Component
public class InstallationHistoryDataLoader
    implements OneTimeChargeDataLoader<InstallationHistory> {

    @Override
    public List<InstallationHistory> loadData(
        CalculationContext context,
        Long contractId
    ) {
        // InstallationHistoryMapper를 통해 데이터 로드
    }

    @Override
    public Class<InstallationHistory> getDataType() {
        return InstallationHistory.class;
    }
}
```

**Calculator**:
```java
@Component
@Order(200)
public class InstallationFeeCalculator
    implements OneTimeChargeCalculator<InstallationHistory> {

    @Override
    public List<InstallationHistory> read(CalculationContext context) {
        // CalculationTarget에서 데이터 읽기
    }

    @Override
    public List<CalculationResult<?>> process(
        CalculationContext context,
        InstallationHistory input
    ) {
        // 설치비 계산 로직
    }

    @Override
    public Class<InstallationHistory> getInputType() {
        return InstallationHistory.class;
    }
}
```

### 2. DeviceInstallmentMaster (단말기 할부)

**도메인 객체**:
```java
public class DeviceInstallmentMaster implements OneTimeChargeDomain {
    private Long contractId;
    private Long deviceInstallmentId;
    private List<DeviceInstallmentDetail> installmentDetails;
    // ...
}
```

**데이터 로더**:
```java
@Component
public class DeviceInstallmentMasterDataLoader
    implements OneTimeChargeDataLoader<DeviceInstallmentMaster> {

    @Override
    public List<DeviceInstallmentMaster> loadData(
        CalculationContext context,
        Long contractId
    ) {
        // DeviceInstallmentMapper를 통해 마스터 및 상세 데이터 로드
    }

    @Override
    public Class<DeviceInstallmentMaster> getDataType() {
        return DeviceInstallmentMaster.class;
    }
}
```

**Calculator**:
```java
@Component
@Order(250)
public class DeviceInstallmentCalculator
    implements OneTimeChargeCalculator<DeviceInstallmentMaster> {

    @Override
    public List<CalculationResult<?>> process(
        CalculationContext context,
        DeviceInstallmentMaster input
    ) {
        // 청구 기간 내 할부 상세 내역 계산
        return input.getInstallmentDetails().stream()
            .filter(detail -> isInBillingPeriod(detail, context))
            .map(detail -> createCalculationResult(detail))
            .toList();
    }

    @Override
    public Class<DeviceInstallmentMaster> getInputType() {
        return DeviceInstallmentMaster.class;
    }
}
```

## 확장 패턴 (새로운 OneTimeCharge 타입 추가)

새로운 일회성 요금 타입을 추가하는 것은 매우 간단합니다:

### 단계 1: 도메인 객체 생성

```java
public class MaintenanceFee implements OneTimeChargeDomain {
    private Long contractId;
    private LocalDate maintenanceDate;
    private BigDecimal fee;
    // getters, setters, etc.

    @Override
    public Long getContractId() {
        return contractId;
    }
}
```

### 단계 2: 데이터 로더 생성

```java
@Component
public class MaintenanceFeeDataLoader
    implements OneTimeChargeDataLoader<MaintenanceFee> {

    private final MaintenanceFeeMapper mapper;

    @Override
    public List<MaintenanceFee> loadData(
        CalculationContext context,
        Long contractId
    ) {
        return mapper.findMaintenanceFees(contractId, context);
    }

    @Override
    public Class<MaintenanceFee> getDataType() {
        return MaintenanceFee.class;
    }
}
```

### 단계 3: Calculator 생성

```java
@Component
@Order(300)
public class MaintenanceFeeCalculator
    implements OneTimeChargeCalculator<MaintenanceFee> {

    @Override
    public List<CalculationResult<?>> process(
        CalculationContext context,
        MaintenanceFee input
    ) {
        // 유지보수비 계산 로직
    }

    @Override
    public Class<MaintenanceFee> getInputType() {
        return MaintenanceFee.class;
    }
}
```

### 결과
**제로 코드 수정**: 기존 ChunkedContractReader, CalculationCommandService, CalculationTarget 수정 불필요!

Spring이 자동으로:
- 새로운 DataLoader를 감지하고 등록
- 새로운 Calculator를 감지하고 등록
- Map에 자동으로 추가
- `@Order`에 따라 실행 순서 조정

## MyBatis 매퍼 패턴

### InstallationHistoryMapper
설치 이력 데이터 조회:

**주요 쿼리**:
- `findInstallationHistories`: 계약 ID와 청구 기간으로 설치 이력 조회
- 조건부 WHERE 절로 웹 서비스와 배치 모두 지원

**복합 키**:
- Installation History key: `contractId`, `installationDate`

### DeviceInstallmentMapper
단말기 할부 데이터 조회:

**주요 쿼리**:
- `findDeviceInstallmentMasters`: 마스터 및 상세 내역 통합 조회
- 복합 ResultMap으로 마스터-상세 계층 구조 매핑

**복합 키**:
- Device Installment key: `contractId`, `deviceInstallmentId`
- Detail key: `deviceInstallmentId`, `installmentSequence`

### 이중 사용 패턴
```xml
<select id="findInstallationHistories" resultMap="InstallationHistoryResultMap">
    SELECT * FROM installation_history
    WHERE 1=1
    <if test="contractId != null">
        AND contract_id = #{contractId}
    </if>
    AND installation_date BETWEEN #{billingStartDate} AND #{billingEndDate}
</select>
```

## 테스트 가이드라인

### Calculator 테스트

```java
@Test
void 설치비_계산_테스트() {
    // Given
    InstallationHistory history = createInstallationHistory();
    CalculationContext context = createContext();

    // When
    List<CalculationResult<?>> results =
        calculator.process(context, history);

    // Then
    assertThat(results).hasSize(1);
    assertThat(results.get(0).getAmount())
        .isCloseTo(expectedAmount, within(BigDecimal.valueOf(0.01)));
}
```

### Data Loader 테스트

```java
@Test
void 설치_이력_로딩_테스트() {
    // Given
    Long contractId = 12345L;
    CalculationContext context = createContext();

    // When
    List<InstallationHistory> histories =
        dataLoader.loadData(context, contractId);

    // Then
    assertThat(histories).isNotEmpty();
    assertThat(histories.get(0).getContractId()).isEqualTo(contractId);
}
```

### 통합 테스트

```java
@Test
void 일회성요금_전체_흐름_테스트() {
    // Given: 설치비 및 할부 데이터 준비
    // When: CalculationCommandService 실행
    // Then: 설치비, 할부금 모두 정확히 계산됨
}
```

## 개발 Best Practices

### Spring DI 활용
- `@Component`와 `@Order` 어노테이션 사용 (커스텀 ordering 메서드 대신)
- 자동 List 주입 및 Map 변환 활용
- 타입 안전성을 위한 제네릭 사용

### 조건부 로직 제거
- 타입 기반 조건문 피하기
- Map 기반 자동 타입 해결 패턴 사용
- 마커 인터페이스로 컴파일 타임 검증

### 마커 인터페이스 설계
- 타입 안전성과 컴파일 타임 검증을 위한 마커 인터페이스 사용
- 제네릭 처리 파이프라인에서 공통 계약 제공

### 데이터 변환
`OneTimeChargeDtoConverter`를 사용한 깔끔한 DTO-도메인 변환:

```java
public class OneTimeChargeDtoConverter {
    public static InstallationHistory toInstallationHistory(
        InstallationHistoryDto dto
    ) {
        // DTO에서 도메인으로 변환
    }

    public static DeviceInstallmentMaster toDeviceInstallmentMaster(
        DeviceInstallmentMasterDto dto,
        List<DeviceInstallmentDetailDto> detailDtos
    ) {
        // 마스터 및 상세 내역 변환
    }
}
```

## 성능 및 유지보수 개선

### Map O(1) 조회
- if-else 체인의 순차 검색 제거
- 타입 해결을 위한 상수 시간 조회

### Spring @Order 통합
- 커스텀 getOrder() 메서드 대신 표준 Spring 순서 사용
- 선언적 실행 순서 관리

### 코드 중복 감소
- 단일 처리 로직이 모든 OneTimeCharge 타입 처리
- DRY 원칙 준수

### 향상된 테스트 가능성
- 각 calculator를 독립적으로 단위 테스트 가능
- 조건부 활성화/비활성화 가능

## 일반적인 문제 해결

### 새로운 타입이 인식되지 않음
- `@Component` 어노테이션 확인
- 패키지가 component scan에 포함되었는지 확인
- `getDataType()` 및 `getInputType()` 메서드가 올바른 클래스 반환하는지 확인

### 실행 순서 문제
- `@Order` 어노테이션 값 확인
- 낮은 값이 먼저 실행됨
- 다른 calculator와 순서 충돌 방지

### Map 주입 실패
- Spring Context에서 빈이 올바르게 등록되었는지 확인
- 제네릭 타입 정보가 올바른지 확인
- 생성자 주입 사용 (필드 주입 대신)

## 확장성 요약

이 아키텍처의 핵심 강점:
- **완전한 확장성**: 기존 코드 수정 없이 새로운 타입 추가
- **타입 안전성**: 컴파일 타임 검증
- **자동 통합**: Spring이 모든 연결 처리
- **간단한 테스트**: 각 컴포넌트 독립적으로 테스트 가능
- **명확한 패턴**: 일관된 구조로 이해 및 유지보수 용이
