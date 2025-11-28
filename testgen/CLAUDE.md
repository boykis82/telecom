# CLAUDE.md - Test Data Generation

> **상위 문서**: [Root CLAUDE.md](../CLAUDE.md)

## 모듈 개요

TestGen 모듈은 개발 및 성능 테스트를 위한 현실적인 테스트 데이터를 생성하는 유틸리티 애플리케이션입니다. JavaFaker 라이브러리를 사용하여 계약, 상품, 정지, 설치, 할부 데이터를 생성합니다.

**패키지**: `me.realimpact.telecom.testgen`
**위치**: `/testgen` (Spring Boot 애플리케이션, bootJar 활성화)

### 의존성

- Spring Boot Starter
- MyBatis Spring Boot Starter
- MySQL Connector J
- JavaFaker (현실적인 데이터 생성)
- Lombok (보일러플레이트 감소)

### 주요 컴포넌트

```
testgen/
├── entity/          # 데이터 생성을 위한 엔티티 클래스
├── mapper/          # MyBatis mapper
└── service/         # 데이터 생성 로직
```

## 실행 명령어

### Unix/Linux/macOS

```bash
# 기본 실행 (100,000개 계약 생성)
./run-testgen.sh 100000

# 메모리 설정과 함께 실행
./run-testgen.sh -m 8g 1000000

# 도움말 보기
./run-testgen.sh -h
```

### Windows

```batch
REM 기본 실행 (100,000개 계약 생성)
run-testgen.bat 100000

REM 메모리 설정과 함께 실행
run-testgen.bat -m 8g 1000000

REM 도움말 보기
run-testgen.bat -h
```

### 명령줄 옵션

- **count** (필수): 생성할 계약 수
- **-m, --memory**: JVM 힙 메모리 크기 (예: 2g, 4g, 8g)
- **-b, --batch-size**: 배치 삽입 크기 (기본값: 1000)
- **-h, --help**: 도움말 메시지 표시

### 사용 예시

```bash
# 10만개 계약 생성
./run-testgen.sh 100000

# 100만개 계약, 8GB 메모리로 생성
./run-testgen.sh -m 8g 1000000

# 커스텀 배치 크기로 생성
./run-testgen.sh -b 5000 50000
```

## 생성되는 데이터

### 엔티티 구조

**ContractEntity**:
- `contractId`: 순차 ID
- `customerId`: JavaFaker로 생성된 고객 ID
- `contractStartDate`: 랜덤 시작일
- `contractEndDate`: 시작일 + 1~2년
- `contractStatus`: ACTIVE, SUSPENDED, TERMINATED

**ProductEntity**:
- 계약당 1~3개의 상품
- `productOfferingId`: 상품 제공 ID
- `effectiveStartDateTime`: 유효 시작일시
- `effectiveEndDateTime`: 유효 종료일시
- 상품별 요금 정보

**SuspensionEntity**:
- 계약의 20%에 정지 이력 추가
- `suspensionTypeCode`: 정지 유형
- `effectiveStartDateTime`: 정지 시작
- `effectiveEndDateTime`: 정지 종료
- `billingRate`: 정지 중 청구 비율 (0%, 50%, 100%)

**InstallationHistoryEntity**:
- 계약의 30%에 설치 이력 추가
- `installationDate`: 설치일
- `installationFee`: 설치비 (50,000 ~ 200,000원)

**DeviceInstallmentMasterEntity 및 DeviceInstallmentDetailEntity**:
- 계약의 40%에 단말기 할부 추가
- 12개월 또는 24개월 할부
- 월 할부금 자동 계산
- 상세 할부 내역 자동 생성

**ContractDiscountEntity**:
- 계약의 50%에 할인 추가
- 요율 기반 할인 (5%, 10%, 15%)
- 금액 기반 할인 (5,000원, 10,000원)
- 할인 적용 기간

## 데이터 생성 로직

### TestDataGeneratorService

주요 데이터 생성 서비스:

```java
@Service
@RequiredArgsConstructor
public class TestDataGeneratorService {

    private final TestDataMapper testDataMapper;
    private final Faker faker = new Faker(new Locale("ko"));

    public void generateTestData(int count, int batchSize) {
        log.info("{}개의 테스트 계약 생성 시작...", count);

        for (int i = 0; i < count; i += batchSize) {
            int currentBatchSize = Math.min(batchSize, count - i);
            List<ContractEntity> contracts = generateContracts(currentBatchSize, i);

            // 배치 삽입
            testDataMapper.insertContracts(contracts);
            testDataMapper.insertProducts(extractProducts(contracts));
            testDataMapper.insertSuspensions(extractSuspensions(contracts));
            testDataMapper.insertInstallations(extractInstallations(contracts));
            testDataMapper.insertDeviceInstallments(extractDeviceInstallments(contracts));
            testDataMapper.insertDiscounts(extractDiscounts(contracts));

            log.info("진행률: {}%", (i + currentBatchSize) * 100 / count);
        }

        log.info("테스트 데이터 생성 완료!");
    }
}
```

### JavaFaker 활용

현실적인 데이터 생성:

```java
private ContractEntity generateContract(long contractId) {
    ContractEntity contract = new ContractEntity();
    contract.setContractId(contractId);
    contract.setCustomerId(faker.number().randomNumber(8, true));

    // 랜덤 계약 시작일 (최근 2년 내)
    LocalDate startDate = LocalDate.now()
        .minusDays(faker.number().numberBetween(1, 730));
    contract.setContractStartDate(startDate);

    // 계약 종료일 (시작일 + 1~2년)
    LocalDate endDate = startDate
        .plusDays(faker.number().numberBetween(365, 730));
    contract.setContractEndDate(endDate);

    // 계약 상태
    contract.setContractStatus(
        faker.options().option("ACTIVE", "ACTIVE", "ACTIVE", "SUSPENDED", "TERMINATED")
    );

    return contract;
}
```

## MyBatis 벌크 삽입 패턴

### TestDataMapper

효율적인 배치 삽입:

```xml
<!-- TestDataMapper.xml -->
<mapper namespace="me.realimpact.telecom.testgen.mapper.TestDataMapper">

    <insert id="insertContracts" parameterType="java.util.List">
        INSERT INTO contract (
            contract_id, customer_id, contract_start_date,
            contract_end_date, contract_status
        ) VALUES
        <foreach collection="list" item="item" separator=",">
            (
                #{item.contractId},
                #{item.customerId},
                #{item.contractStartDate},
                #{item.contractEndDate},
                #{item.contractStatus}
            )
        </foreach>
    </insert>

    <insert id="insertProducts" parameterType="java.util.List">
        INSERT INTO product (
            contract_id, product_offering_id,
            effective_start_date_time, effective_end_date_time
        ) VALUES
        <foreach collection="list" item="item" separator=",">
            (
                #{item.contractId},
                #{item.productOfferingId},
                #{item.effectiveStartDateTime},
                #{item.effectiveEndDateTime}
            )
        </foreach>
    </insert>

    <!-- 다른 엔티티에 대한 유사한 벌크 삽입 -->

</mapper>
```

### 성능 최적화

**배치 삽입**:
- 기본 배치 크기: 1,000건
- 대규모 데이터셋을 위한 커스터마이징 가능
- 트랜잭션 관리로 데이터 일관성 보장

**메모리 관리**:
- 청크 단위 처리로 메모리 오버플로우 방지
- 대규모 데이터 생성을 위한 구성 가능한 JVM 힙 크기
- 진행률 로깅으로 모니터링

## 구성

### application.yml

```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/telecom_billing
    username: root
    password: password
    driver-class-name: com.mysql.cj.jdbc.Driver

  mybatis:
    mapper-locations: classpath:mapper/*.xml
    configuration:
      map-underscore-to-camel-case: true

logging:
  level:
    me.realimpact.telecom.testgen: INFO
```

### application-docker.yml

Docker 환경을 위한 구성:

```yaml
spring:
  datasource:
    url: jdbc:mysql://mysql:3306/telecom_billing
    # Docker 컨테이너 내부에서 mysql 호스트 사용
```

## 개발 패턴

### 엔티티 일관성
도메인 모듈의 엔티티 구조와 일관성 유지:

```java
@Data
@Builder
public class ContractEntity {
    private Long contractId;
    private Long customerId;
    private LocalDate contractStartDate;
    private LocalDate contractEndDate;
    private String contractStatus;

    // 관계 엔티티
    private List<ProductEntity> products;
    private List<SuspensionEntity> suspensions;
    private List<InstallationHistoryEntity> installations;
    // ...
}
```

### 데이터 품질
현실적인 비즈니스 시나리오:

- **계약 상태 분포**: ACTIVE 75%, SUSPENDED 15%, TERMINATED 10%
- **상품 수**: 계약당 1~3개
- **정지 발생률**: 전체 계약의 20%
- **설치비**: 30% 계약
- **단말기 할부**: 40% 계약
- **할인**: 50% 계약

### 날짜 범위
테스트 시나리오를 위한 적절한 날짜 범위:

- 계약 시작일: 현재부터 2년 전까지
- 계약 기간: 1~2년
- 정지 기간: 계약 기간 내 랜덤
- 할인 기간: 계약 기간과 중첩

## 사용 시나리오

### 개발 환경 설정
새로운 개발자를 위한 로컬 데이터베이스 초기화:

```bash
# 소규모 개발 데이터셋
./run-testgen.sh 1000
```

### 통합 테스트
통합 테스트를 위한 중간 규모 데이터셋:

```bash
# 중간 규모 데이터셋
./run-testgen.sh 10000
```

### 성능 테스트
배치 처리 성능 테스트를 위한 대규모 데이터셋:

```bash
# 대규모 데이터셋 (충분한 메모리 필요)
./run-testgen.sh -m 8g 1000000
```

### 부하 테스트
시스템 부하 테스트:

```bash
# 매우 대규모 데이터셋
./run-testgen.sh -m 16g 5000000
```

## 일반적인 문제 해결

### 메모리 부족 오류
**증상**: `OutOfMemoryError: Java heap space`

**해결책**:
```bash
# 힙 메모리 크기 증가
./run-testgen.sh -m 8g 1000000
```

### 데이터베이스 연결 실패
**증상**: `Could not connect to database`

**해결책**:
- MySQL 서버 실행 확인
- application.yml의 데이터베이스 자격 증명 확인
- Docker 환경인 경우 `application-docker.yml` 사용

### 느린 삽입 성능
**증상**: 데이터 생성이 너무 오래 걸림

**해결책**:
```bash
# 배치 크기 증가
./run-testgen.sh -b 5000 100000

# 데이터베이스 인덱스 임시 비활성화 (주의해서 사용)
# 대량 삽입 후 재생성
```

### 중복 키 오류
**증상**: `Duplicate entry for key 'PRIMARY'`

**해결책**:
- 기존 데이터 정리 후 재실행
- 또는 `contractId` 시작 오프셋 조정

## Best Practices

### 데이터 정리
테스트 데이터 재생성 전 기존 데이터 정리:

```sql
-- 외래 키 제약 조건 순서 고려
TRUNCATE TABLE device_installment_detail;
TRUNCATE TABLE device_installment_master;
TRUNCATE TABLE installation_history;
TRUNCATE TABLE contract_discount;
TRUNCATE TABLE suspension;
TRUNCATE TABLE charge_item;
TRUNCATE TABLE product;
TRUNCATE TABLE contract;
```

### 배치 크기 조정
데이터 볼륨에 따른 최적 배치 크기:

- **소규모 (< 10,000)**: 배치 크기 1,000
- **중규모 (10,000 ~ 100,000)**: 배치 크기 2,000
- **대규모 (> 100,000)**: 배치 크기 5,000

### 진행률 모니터링
로그 출력으로 진행 상황 추적:

```
2025-01-15 10:00:00 INFO  - 100000개의 테스트 계약 생성 시작...
2025-01-15 10:00:05 INFO  - 진행률: 10%
2025-01-15 10:00:10 INFO  - 진행률: 20%
...
2025-01-15 10:01:00 INFO  - 테스트 데이터 생성 완료!
```

## 확장 가이드

### 새로운 엔티티 타입 추가

1. **엔티티 클래스 생성**:
```java
@Data
@Builder
public class NewEntityType {
    private Long id;
    private Long contractId;
    // 필드 정의
}
```

2. **Mapper 메서드 추가**:
```xml
<insert id="insertNewEntities" parameterType="java.util.List">
    INSERT INTO new_entity (id, contract_id, ...) VALUES
    <foreach collection="list" item="item" separator=",">
        (#{item.id}, #{item.contractId}, ...)
    </foreach>
</insert>
```

3. **생성 로직 구현**:
```java
private NewEntityType generateNewEntity(ContractEntity contract) {
    return NewEntityType.builder()
        .id(faker.number().randomNumber())
        .contractId(contract.getContractId())
        .build();
}
```

4. **서비스에 통합**:
```java
testDataMapper.insertNewEntities(extractNewEntities(contracts));
```
