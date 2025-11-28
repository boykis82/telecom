# CLAUDE.md - Monthly Fee Policy

> **상위 문서**: [Root CLAUDE.md](../CLAUDE.md) | [Calculation Framework](../calculation/CLAUDE.md)
> **관련 모듈**: [onetimecharge](../calculation-policy-onetimecharge/CLAUDE.md), [batch](../batch/CLAUDE.md)
> **비즈니스 도메인 가이드**: [BUSINESS_DOMAIN.md](../docs/BUSINESS_DOMAIN.md)

## 모듈 개요

Monthly Fee Policy 모듈은 월정액 계산 정책 구현을 담당하는 독립적인 모듈입니다. 다양한 가격 정책과 복잡한 일할 계산 로직을 제공합니다.

**패키지**: `me.realimpact.telecom.calculation.policy.monthlyfee`
**위치**: `/calculation-policy-monthlyfee` (최상위 독립 모듈)

### 의존성

- calculation-domain
- calculation-application
- calculation-port
- MyBatis Spring Boot Starter
- MySQL Connector J

### 주요 컴포넌트

```
calculation-policy-monthlyfee/
├── dto/                  # 월정액 DTOs
├── calculator/           # Calculator 구현체
├── policy/              # 가격 정책 전략
├── converter/           # 도메인 변환기
├── adapter/mybatis/     # MyBatis 매퍼
└── loader/              # 데이터 로더
```

## 월정액 계산 흐름

### 1. 데이터 로딩
`ContractWithProductsAndSuspensionsDataLoader`가 계약, 상품, 정지 정보를 로드합니다:

```java
@Component
public class ContractWithProductsAndSuspensionsDataLoader
    implements MonthlyFeeDataLoader<ContractWithProductsAndSuspensions> {

    @Override
    public List<ContractWithProductsAndSuspensions> loadData(
        CalculationContext context,
        Long contractId
    ) {
        // ProductQueryMapper를 통해 복잡한 계약/상품 데이터 조회
    }
}
```

### 2. 기간 분할 (Proration)
`ProratedPeriodBuilder`가 계약 변경, 정지, 상품 변경을 기반으로 청구 기간을 분할합니다:

- 계약 이력 기간
- 서비스 정지 기간
- 상품 변경 기간
- 교집합 계산으로 정확한 청구 기간 생성

### 3. 가격 정책 적용
`DefaultMonthlyChargingPolicyFactory`가 상품 유형에 따라 적절한 가격 정책을 선택합니다.

### 4. Calculator 실행
`BasicPolicyMonthlyFeeCalculator`가 통합 Calculator 패턴을 사용하여 계산을 실행합니다:

```java
@Component
@Order(100)
public class BasicPolicyMonthlyFeeCalculator
    implements Calculator<ContractWithProductsAndSuspensions> {

    @Override
    public List<CalculationResult<?>> execute(CalculationContext context) {
        // 기본 execute 메서드 활용
    }
}
```

## 가격 정책 전략 패턴

`DefaultMonthlyChargingPolicyFactory`가 제공하는 다양한 가격 정책:

### 1. FlatRatePolicy
표준 정액제 청구:
- 고정 요금
- 일할 계산 적용
- 가장 일반적인 B2C 상품

### 2. TierFactorPolicy
계층 기반 가격:
- 사용량 또는 조건에 따른 계층
- 각 계층별 다른 요율
- 예: 데이터 요금제 (1GB 미만, 1-5GB, 5GB 초과)

### 3. RangeFactorPolicy
범위 기반 가격:
- 특정 범위 내 단일 요율 적용
- 예: 특정 시간대 요금

### 4. StepFactorPolicy
단계별 가격:
- 단계별로 증가하는 요율
- 누적 계산 방식

### 5. MatchingFactorPolicy
B2B 상품 매칭 기준:
- 특정 조건 매칭
- 복잡한 계약 조건 지원

### 6. UnitPriceFactorPolicy
단가 곱셈:
- 단가 × 수량
- 사용량 기반 청구

## 비즈니스 규칙

### 일할 계산 (Pro-rated Calculation)
- **계약 시작일**: 포함 (inclusive)
- **계약 종료일**: 제외 (exclusive)
- **공식**: (실제 사용일수 / 총 청구일수) × 월 요금

### 정지 기간 처리
- 상품별 정의된 정지 청구 요율 적용
- 정지 기간 동안 다른 요금 적용 가능
- 예: 100% 청구, 50% 청구, 0% 청구

### 기간 분할 (Period Segmentation)
정확한 청구를 위해 계약 이력과 서비스 상태 이력 중첩:

```java
// ProratedPeriodBuilder 사용 예
List<ProratedPeriod> periods = ProratedPeriodBuilder.build(
    contractHistory,
    suspensionHistory,
    productChangeHistory,
    billingPeriod
);
```

### OCP 원칙
새로운 B2B 상품은 기존 코드 수정 없이 추가 가능:
- 새로운 정책 클래스 생성
- `MonthlyChargingPolicy` 인터페이스 구현
- Spring의 `@Component`로 자동 등록

## CalculationResult Prorate 기능

할인 적용 시 CalculationResult의 prorate 메서드 활용:

```java
// 기존 CalculationResult를 할인 기간에 따라 분할
List<CalculationResult<?>> proratedResults = originalResult.prorate(discountPeriods);

// 각 분할된 결과에 할인 적용
proratedResults.forEach(result -> {
    BigDecimal discountAmount = calculateDiscount(result);
    result.subtractBalance(discountAmount);
});
```

**주요 기능**:
- 기간 교집합 로직
- 비례 요금 계산 (BigDecimal 정밀도)
- 잔액 추적 (`addBalance()`, `subtractBalance()`)
- PostProcessor 통합

## MyBatis 매퍼 패턴

### ProductQueryMapper
계약 및 상품 데이터 조회를 위한 복잡한 SQL:

**주요 쿼리**:
- `findContractWithProductsAndSuspensions`: 계약, 상품, 정지 정보 통합 조회
- 복합 ResultMap으로 계층 구조 매핑
- 적절한 복합 키로 데이터 그룹화

**복합 키**:
- Contract key: `contractId`
- Product key: `contractId`, `productOfferingId`, `effectiveStartDateTime`, `effectiveEndDateTime`
- Suspension key: `contractId`, `suspensionType`, `effectiveStartDateTime`, `effectiveEndDateTime`
- ChargeItem key: `productId`, `chargeItemId`

**중요한 ORDER BY 요구사항**:
```sql
ORDER BY c.contract_id, po.product_offering_id, p.effective_start_date_time,
         p.effective_end_date_time, ci.charge_item_id, s.suspension_type_code,
         s.effective_start_date_time, s.effective_end_date_time
```

### PreviewProductQueryMapper
가격 정책 평가를 위한 미리보기 쿼리:
- 상품 가격 정보 조회
- 정책 선택을 위한 상품 메타데이터

### 이중 사용 패턴
MyBatis 쿼리는 조건부 WHERE 절로 유연한 사용 지원:
- 웹 서비스: `contractId` 파라미터로 단일 계약 쿼리
- 배치 처리: `contractId = null`로 전체 데이터셋 쿼리

## 테스트 가이드라인

### 통합 테스트
`MonthlyFeeCalculationIntegrationTest`: 엔드투엔드 시나리오

```java
@Test
void 월정액_계산_통합_테스트() {
    // Given: 계약, 상품, 정지 데이터 준비
    // When: Calculator 실행
    // Then: 기대하는 계산 결과 검증
}
```

### 정책 테스트
각 가격 정책에 대한 개별 테스트 클래스:

- `FlatRatePolicyTest`: 정액제 로직 검증
- `TierFactorPolicyTest`: 계층 계산 검증
- `RangeFactorPolicyTest`: 범위 계산 검증
- 등등...

**테스트 패턴**:
```java
@Test
void 계층_요금_계산_테스트() {
    // Given
    TierFactorPolicy policy = new TierFactorPolicy();
    ProductOffering product = createTierProduct();

    // When
    BigDecimal amount = policy.calculate(usage, product);

    // Then
    assertThat(amount).isCloseTo(expectedAmount, within(BigDecimal.valueOf(0.01)));
}
```

### Converter 테스트
`ContractDtoToDomainConverterTest`: 데이터 변환 로직 검증

- DTO에서 도메인으로 변환 정확성
- null 처리
- 복잡한 계층 구조 매핑

### BigDecimal 단언
재무 계산 테스트 시:
```java
assertThat(actualAmount)
    .isCloseTo(expectedAmount, within(BigDecimal.valueOf(0.01)));
```

## 개발 패턴

### 정책 추가 방법

새로운 가격 정책 추가:

```java
@Component
public class CustomPolicy implements MonthlyChargingPolicy {

    @Override
    public String getPolicyType() {
        return "CUSTOM_POLICY";
    }

    @Override
    public BigDecimal calculate(
        ProductOffering product,
        ProratedPeriod period,
        Map<String, Object> context
    ) {
        // 커스텀 계산 로직
        return calculatedAmount;
    }
}
```

Spring이 자동으로 감지하고 `DefaultMonthlyChargingPolicyFactory`에 등록합니다.

### Stream API 활용

```java
List<CalculationResult<?>> results = products.stream()
    .flatMap(product -> calculateForProduct(product).stream())
    .filter(result -> result.getAmount().compareTo(BigDecimal.ZERO) > 0)
    .toList();
```

### Record 활용

```java
public record ProratedPeriod(
    LocalDate startDate,
    LocalDate endDate,
    BigDecimal prorationRate,
    SuspensionInfo suspensionInfo
) {
    public long getDays() {
        return ChronoUnit.DAYS.between(startDate, endDate);
    }
}
```

## 계산 기간 제약

- **최대 기간**: 1개월 (1일 ~ 월말)
- **최소 기간**: 1일
- **기간 형식**: YYYY-MM-DD
- 월을 넘는 계산은 여러 배치로 분할

## 성능 고려사항

### 데이터 로딩 최적화
- 벌크 로딩으로 N+1 쿼리 문제 방지
- MyBatis ResultMap으로 단일 쿼리에서 복잡한 구조 구성
- 적절한 인덱스 활용 (contractId, productOfferingId, effectiveStartDateTime)

### 메모리 관리
- Stream API로 지연 평가
- 청크 기반 처리 (배치에서)
- 큰 결과셋의 경우 페이징 고려

## 일반적인 문제 해결

### 일할 계산 불일치
- 시작일/종료일 포함/제외 규칙 확인
- BigDecimal 정밀도 및 반올림 모드 검증
- 윤년, 월말 경계 조건 테스트

### 정지 기간 계산 오류
- 정지 이력과 계약 기간 교집합 확인
- 정지 청구 요율 설정 검증
- 여러 정지 기간 중첩 시나리오 테스트

### 정책 선택 문제
- 상품 메타데이터의 정책 유형 확인
- Factory 클래스의 정책 등록 검증
- 커스텀 정책의 `@Component` 어노테이션 확인
