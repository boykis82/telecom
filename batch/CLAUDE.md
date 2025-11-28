# CLAUDE.md - Batch Processing

> **상위 문서**: [Root CLAUDE.md](../CLAUDE.md)
> **관련 모듈**: [calculation](../calculation/CLAUDE.md), [monthlyfee](../calculation-policy-monthlyfee/CLAUDE.md), [onetimecharge](../calculation-policy-onetimecharge/CLAUDE.md)
> **배치 실행 가이드**: [BATCH_EXECUTION_GUIDE.md](../BATCH_EXECUTION_GUIDE.md)

## 모듈 개요

Batch 모듈은 대규모 다중 스레드 배치 처리를 위한 Spring Batch 기반 애플리케이션입니다. 두 가지 병렬 처리 아키텍처를 지원하여 성능 비교 및 최적화가 가능합니다.

**패키지**: `me.realimpact.telecom.billing.batch`
**위치**: `/batch` (Spring Boot 애플리케이션, bootJar 활성화)

### 의존성

- 모든 calculation 모듈
- 모든 policy 모듈
- Spring Batch Starter
- MyBatis Spring Boot Starter
- MySQL Connector J

## Dual Batch Processing Architecture (2025)

시스템은 성능 비교 및 최적화를 위해 두 가지 병렬 배치 처리 접근 방식을 지원합니다:

### 1. Thread Pool Architecture (원본)

**Job 이름**: `monthlyFeeCalculationJob`
**실행 스크립트**: `./run-batch-jar.sh`

**특징**:
- **Reader**: `ChunkedContractReader` (스레드 안전성을 위해 `SynchronizedItemStreamReader`로 래핑)
- **작업 분배**: 동적 작업 분배
- **메모리**: 스레드 간 메모리 공유
- **Thread Pool**: 구성 가능한 core/max pool 크기와 큐 용량을 가진 `ThreadPoolTaskExecutor`

**장점**:
- 런타임 작업 스틸링
- 유연한 동적 로드 밸런싱

**단점**:
- 동기화 오버헤드로 확장성 제한
- 혼합된 계약 처리로 데이터 지역성 낮음

### 2. Partitioner Architecture (신규)

**Job 이름**: `partitionedMonthlyFeeCalculationJob`
**실행 스크립트**: `./run-partitioned-batch-jar.sh`

**특징**:
- **Reader**: `PartitionedContractReader` (파티션별 데이터 로딩)
- **작업 분배**: `contractId % threadCount = partitionKey`를 사용한 정적 분배
- **메모리**: 독립적인 파티션 메모리
- **패턴**: `partitionedMasterStep`이 `partitionedWorkerStep` 실행을 오케스트레이션

**장점**:
- 파티션당 선형 확장
- 파티션별 처리로 데이터 지역성 높음
- 동기화 없음 (각 파티션 독립 동작)

**단점**:
- 미리 결정된 데이터 분배
- 비순차 contractId의 경우 불균등 분배 가능성

### 성능 비교

| 측면 | Thread Pool | Partitioner |
|------|-------------|-------------|
| **작업 분배** | 동적 (SynchronizedItemStreamReader) | 정적 (Modulo 기반) |
| **메모리 사용** | 스레드 간 공유 메모리 | 독립 파티션 메모리 |
| **로드 밸런싱** | 런타임 작업 스틸링 | 미리 결정된 데이터 분배 |
| **확장성** | 동기화 오버헤드로 제한 | 파티션당 선형 확장 |
| **데이터 지역성** | 혼합 계약 처리 | 파티션별 처리 |

## 배치 실행 명령어

### Unix/Linux/macOS

```bash
# Thread Pool 실행
./run-batch-jar.sh

# Partitioner 실행
./run-partitioned-batch-jar.sh

# 수동 JAR 실행 (작업 선택)
java -jar batch/build/libs/batch-0.0.1-SNAPSHOT.jar \
  --spring.batch.job.names=partitionedMonthlyFeeCalculationJob \
  --billingStartDate=2025-03-01 --billingEndDate=2025-03-31 --threadCount=8
```

### Windows

```batch
REM Thread Pool 실행
run-batch-jar.bat

REM Partitioner 실행
run-partitioned-batch-jar.bat
```

### 기능
- 전체 계약 처리 및 `contractId` 파라미터를 통한 단일 계약 처리
- 설치비 및 단말기 할부를 위한 일회성 요금 처리
- 기본값이 있는 대화형 파라미터 입력
- 병렬 처리를 위한 구성 가능한 스레드 수

## 배치 작업 파라미터

- **billingStartDate** (필수): 청구 기간 시작일 (YYYY-MM-DD 형식)
- **billingEndDate** (필수): 청구 기간 종료일 (YYYY-MM-DD 형식)
- **contractId** (선택): 단일 계약 처리를 위한 특정 계약 ID
- **billingCalculationType** (필수): 청구 계산 유형 (예: MONTHLY_FEE)
- **billingCalculationPeriod** (필수): 계산 주기 (예: MONTHLY)
- **threadCount** (선택): 병렬 처리를 위한 스레드 수 (기본값: 8)

## 공통 컴포넌트

### CalculationProcessor
`CalculationTarget`을 여러 calculator로 처리:

```java
@Component
public class CalculationProcessor implements ItemProcessor<CalculationTarget, List<CalculationResult<?>>> {

    private final CalculationCommandUseCase calculationCommandUseCase;

    @Override
    public List<CalculationResult<?>> process(CalculationTarget target) {
        CalculationResultGroup group = calculationCommandUseCase.calculate(
            target.contractId(),
            target.contractWithProductsAndSuspensions(),
            target.oneTimeChargeData(),
            target.discounts(),
            context
        );
        return group.calculationResults();
    }
}
```

### CalculationWriter
`@Transactional`을 사용한 스레드 안전 배치 쓰기:

```java
@Component
public class CalculationWriter implements ItemWriter<List<CalculationResult<?>>> {

    @Override
    @Transactional
    public void write(Chunk<? extends List<CalculationResult<?>>> chunk) {
        chunk.getItems().stream()
            .flatMap(List::stream)
            .forEach(calculationResultSavePort::save);
    }
}
```

### 청크 크기
`BatchConstants.CHUNK_SIZE`로 구성, 일반적으로 최적 성능을 위해 100

### Calculator 오케스트레이션
`@Order` 어노테이션에 따라 순서대로 실행되는 여러 calculator

## MyBatis 배치 처리 구성

### 이중 사용 패턴
MyBatis 쿼리는 조건부 WHERE 절로 유연한 사용 지원:
- **웹 서비스**: `contractId` 파라미터로 단일 계약 쿼리
- **배치 처리**: `contractId = null`로 전체 데이터셋 쿼리

### 향상된 배치 처리 아키텍처
`CalculationTarget`을 사용한 통합 데이터 처리:

- **ChunkedContractReader**: 청크 단위로 계약 ID 읽기, 할인 포함 모든 관련 데이터 타입 로드
- **CalculationTarget**: `contractWithProductsAndSuspensions`, `installationHistories`, `deviceInstallmentMasters`, `discounts` 포함
- **통합 처리 흐름**: 할인 및 VAT 계산을 포함한 여러 calculator를 통한 순차 처리
- **ProductQueryMapper**: `ContractQueryMapper`에서 이름 변경, 복잡한 계약 및 상품 데이터 처리
- **전문 Mapper**: 일회성 요금을 위한 `InstallationHistoryMapper`, `DeviceInstallmentMapper`
- **통합 처리**: 단일 `CalculationProcessor`가 여러 계산 유형 처리
- **CalculationParameters**: `toCalculationContext()` 메서드가 있는 배치 작업 파라미터를 캡슐화하는 record
- **BatchConstants**: 청크 크기 및 처리 파라미터를 위한 중앙 집중식 구성

### 적절한 데이터 그룹화를 위한 주요 복합 키
- **Contract key**: `contractId`
- **Product key**: `contractId`, `productOfferingId`, `effectiveStartDateTime`, `effectiveEndDateTime`
- **Suspension key**: `contractId`, `suspensionType`, `effectiveStartDateTime`, `effectiveEndDateTime`
- **ProductOffering key**: `productId`, `chargeItemId`
- **Device Installment key**: `contractId`, `deviceInstallmentId`
- **Installation History key**: `contractId`, `installationDate`

### 중요한 ORDER BY 요구사항
적절한 페이징 및 MyBatis ResultMap 그룹화를 위해 ORDER BY 절이 일관된 정렬을 유지해야 함:

```sql
ORDER BY c.contract_id, po.product_offering_id, p.effective_start_date_time,
         p.effective_end_date_time, ci.charge_item_id, s.suspension_type_code,
         s.effective_start_date_time, s.effective_end_date_time
```

참고: MonthlyChargeItem → ChargeItem 리팩토링에 따라 `mci.charge_item_id`에서 `ci.charge_item_id`로 업데이트됨

## Partitioner 아키텍처 세부사항

### ContractPartitioner 구현
균등한 데이터 분배를 위한 파티션 로직:

```java
@Component
public class ContractPartitioner implements Partitioner {

    @Override
    public Map<String, ExecutionContext> partition(int gridSize) {
        Map<String, ExecutionContext> partitions = new HashMap<>();

        for (int i = 0; i < gridSize; i++) {
            ExecutionContext context = new ExecutionContext();
            context.putInt("partitionKey", i);
            context.putInt("partitionCount", gridSize);
            partitions.put("partition" + i, context);
        }

        return partitions;
    }
}
```

**특징**:
- **파티션 로직**: 균등한 데이터 분배를 위한 `contractId % threadCount = partitionKey`
- **동적 크기 조정**: 작업 파라미터를 통해 구성 가능한 스레드 수
- **ExecutionContext**: 각 파티션이 `partitionKey` 및 `partitionCount` 파라미터를 받음
- **로드 밸런싱**: Modulo 산술로 순차 계약 ID에 대한 균등 분배 보장

### PartitionedContractReader 기능

```java
@Component
@StepScope
public class PartitionedContractReader extends AbstractItemStreamItemReader<CalculationTarget> {

    @Value("#{stepExecutionContext['partitionKey']}")
    private Integer partitionKey;

    @Value("#{stepExecutionContext['partitionCount']}")
    private Integer partitionCount;

    @Override
    public CalculationTarget read() {
        // 파티션별 계약 ID 읽기
        List<Long> contractIds = productQueryMapper
            .findContractIdsWithPartition(partitionKey, partitionCount, context);
        // ...
    }
}
```

**특징**:
- **파티션 인식 읽기**: 파티션 컨텍스트를 위해 `@Value("#{stepExecutionContext['partitionKey']}")` 사용
- **독립적 데이터 로딩**: 각 파티션이 할당된 계약 ID만 처리
- **청크 관리**: 원본과 동일한 청크 기반 처리 유지 (CHUNK_SIZE = 100)
- **폴백 처리**: 일치하는 계약이 없는 파티션에 대한 빈 결과 쿼리

### MyBatis 파티션 확장

`ContractQueryMapper.xml`에 추가:

```xml
<!-- 파티션 기반 계약 ID 검색 -->
<select id="findContractIdsWithPartition" resultType="Long">
    SELECT DISTINCT c.contract_id
    FROM contract c
    WHERE c.contract_id % #{partitionCount} = #{partitionKey}
    AND <!-- 표준 날짜 필터링 조건 -->
</select>
```

## 배치 처리 고려사항

### Reader 설계
- **Thread Pool**: 스레드 안전성을 위해 `SynchronizedItemStreamReader`와 함께 `ChunkedContractReader` 사용
- **Partitioner**: 파티션별 데이터 로딩을 사용하는 `PartitionedContractReader`

### 트랜잭션 관리
양쪽 접근 방식 모두 Writer에서 Spring의 선언적 `@Transactional` 사용

### 메모리 관리
제어된 배치 크기로 청크 기반 처리하여 메모리 문제 방지

### 연결 풀링
다중 스레드 배치 처리를 위해 최적화된 HikariCP 구성:
- 최대 풀 크기: 20
- 최소 유휴: 8
- 연결 타임아웃: 60초

### 데이터 로딩 전략
관련 데이터의 벌크 로딩 (상품, 정지, 설치, 할부)

### Calculator 통합
통합 인터페이스 패턴을 통한 여러 calculator의 원활한 통합

## Spring Batch 문제 해결

### 일반적인 다중 스레딩 문제

**ExecutorType 충돌**:
```
TransientDataAccessResourceException: Cannot change the ExecutorType when there is an existing transaction
```
- **원인**: MyBatisPagingItemReader가 기존 트랜잭션 내에서 ExecutorType을 BATCH로 변경 시도
- **해결책**: MyBatisCursorItemReader 사용 또는 커스텀 페이징 로직 구현

**스레드 안전성**:
- **Thread Pool**: 모든 ItemReader가 SynchronizedItemStreamReader로 래핑되었는지 확인
- **Partitioner**: 각 파티션이 독립적으로 동작, 동기화 불필요

**트랜잭션 경계**:
다중 스레드 처리는 각 스레드가 자체 트랜잭션 범위를 관리함을 의미

### Partitioner 특정 문제 해결

**Bean 충돌**:
여러 배치 구성이 존재할 때 올바른 Job을 지정하기 위해 `@Qualifier` 사용:

```java
@Qualifier("monthlyFeeCalculationJob")
Job calculationJob
```

**SpEL 표현식 문제**:
파티션 인식 파라미터 주입을 위해 `@StepScope` 사용:

```java
@Value("#{stepExecutionContext['partitionKey']}")
```

**빈 파티션**:
`contractId % threadCount` 결과가 일치하지 않는 경우 처리

**불균등 분배**:
비순차 계약 ID에 대한 파티션 로드 밸런스 모니터링

### 의존성 주입 Best Practices

- Bean 구분을 위해 `@RequiredArgsConstructor` 대신 `@Qualifier`가 있는 명시적 생성자 사용
- 적절한 파라미터 주입을 위해 모든 배치 컴포넌트가 `@StepScope` 또는 `@JobScope`인지 확인
- 작업 파라미터는 SpEL 표현식을 통해 런타임에 주입: `@Value("#{jobParameters['paramName']}"`
- Partitioner 컴포넌트는 ExecutionContext 접근을 위해 `@StepScope` 필요

## 오류 처리 및 모니터링

### 배치 실행 모니터링
Spring Batch는 다음 테이블에 실행 메타데이터 저장:
- `BATCH_JOB_INSTANCE`: 작업 인스턴스 정보
- `BATCH_JOB_EXECUTION`: 실행 세부사항 및 상태
- `BATCH_STEP_EXECUTION`: 스텝 레벨 실행 메트릭

### 성능 최적화

**공통 설정**:
- **청크 크기**: `BatchConstants.CHUNK_SIZE`로 구성, 최적 성능을 위해 일반적으로 100
- **스레드 수**: `threadCount` 작업 파라미터로 구성 가능 (기본값: 8 스레드)
- **MyBatis 구성**:
  - 기본 페치 크기: 100
  - 문 타임아웃: 0 (배치에 대해 무제한)
  - 배치 처리를 위해 캐시 비활성화
- **JVM 메모리**: 대규모 데이터셋 처리를 위해 `-Xmx2g` 권장

## 개발 가이드라인

### CalculationParameters Record
배치 작업 파라미터 캡슐화:

```java
public record CalculationParameters(
    LocalDate billingStartDate,
    LocalDate billingEndDate,
    String billingCalculationType,
    String billingCalculationPeriod,
    Long contractId
) {
    public CalculationContext toCalculationContext() {
        return new CalculationContext(
            billingStartDate,
            billingEndDate,
            billingCalculationType,
            billingCalculationPeriod
        );
    }
}
```

### BatchConstants
중앙 집중식 구성:

```java
public class BatchConstants {
    public static final int CHUNK_SIZE = 100;
    public static final int DEFAULT_THREAD_COUNT = 8;
    // ...
}
```

### 테스트
- **CalculationTarget 처리** 테스트
- **배치 작업 파라미터 처리** 테스트
- 다양한 스레드 수로 성능 테스트
- 단일 계약 처리 및 전체 계약 처리 검증

## 인프라 레이어 업데이트

- **MyBatis Mapper 구성**: 모든 mapper가 `infrastructure.adapter.mybatis` 서브패키지로 이동
- **ProductQueryMapper**: `ContractQueryMapper`에서 이름 변경, 계약 및 상품 데이터를 위한 향상된 복잡한 SQL 쿼리
- **전문 Mapper**: 일회성 요금 데이터를 위한 `InstallationHistoryMapper`, `DeviceInstallmentMapper`
- **Converter 클래스**: 깔끔한 DTO-도메인 변환을 위한 `ContractDtoToDomainConverter`, `OneTimeChargeDtoConverter`
- **리포지토리 적응**: 새로운 포트 인터페이스와 작동하도록 리포지토리 구현 업데이트

자세한 MyBatis 페이징 사용법은 `MYBATIS_PAGING_USAGE.md` 참조
