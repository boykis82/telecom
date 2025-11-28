# CLAUDE.md - Web Service

> **상위 문서**: [Root CLAUDE.md](../CLAUDE.md)
> **관련 모듈**: [calculation](../calculation/CLAUDE.md), [batch](../batch/CLAUDE.md)

## 모듈 개요

Web Service 모듈은 청구 계산을 위한 REST API 레이어를 제공하는 Spring Boot 애플리케이션입니다. Swagger 문서화, 전역 예외 처리, 요청 검증을 포함합니다.

**패키지**: `me.realimpact.telecom.billing.web`
**위치**: `/web-service` (Spring Boot 애플리케이션, bootJar 활성화)
**포트**: 8080
**Swagger UI**: `http://localhost:8080/swagger-ui.html`

### 의존성

- 모든 calculation 모듈 (domain, api, port, application, infrastructure)
- 모든 policy 모듈 (monthlyfee, onetimecharge)
- Spring Web, Spring Validation
- MyBatis Spring Boot Starter
- SpringDoc OpenAPI (Swagger)
- H2 database (개발/테스트)
- MySQL (프로덕션)

### 주요 컴포넌트

```
web-service/
├── controller/          # REST 컨트롤러
├── config/             # Swagger/OpenAPI 구성
└── exception/          # 예외 핸들러
```

## 개발 명령어

### 애플리케이션 실행

```bash
# Unix/Linux/macOS
./gradlew :web-service:bootRun

# Windows
gradlew.bat :web-service:bootRun
```

애플리케이션이 시작되면 다음에서 접근 가능:
- API 엔드포인트: `http://localhost:8080/api/*`
- Swagger UI: `http://localhost:8080/swagger-ui.html`
- OpenAPI 스펙: `http://localhost:8080/v3/api-docs`

### 데이터베이스 구성

**개발/테스트**:
- H2 in-memory 데이터베이스
- 자동 스키마 생성
- 빠른 테스트 및 개발

**프로덕션**:
- MySQL 데이터베이스
- HikariCP 연결 풀링으로 최적화
- 영구 데이터 저장소

## Controller 개발 패턴

### 표준 Controller 템플릿

```java
@Tag(name = "API Name", description = "API Description")
@RestController
@RequestMapping("/api/endpoint")
@RequiredArgsConstructor
@Validated
@Slf4j
public class ExampleController {

    @Operation(summary = "Operation summary", description = "Detailed description")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Success"),
        @ApiResponse(responseCode = "400", description = "Bad Request"),
        @ApiResponse(responseCode = "500", description = "Internal Server Error")
    })
    @PostMapping
    public ResponseEntity<ResponseType> methodName(
        @Parameter(description = "Parameter description", required = true)
        @Valid @RequestBody RequestType request) {
        // 구현
        return ResponseEntity.ok(response);
    }
}
```

### CalculationController 예제

```java
@Tag(name = "Calculation API", description = "청구 계산 API")
@RestController
@RequestMapping("/api/calculations")
@RequiredArgsConstructor
@Validated
@Slf4j
public class CalculationController {

    private final CalculationCommandUseCase calculationCommandUseCase;

    @Operation(summary = "청구 계산", description = "계약 ID 목록에 대한 청구 계산 수행")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "계산 성공"),
        @ApiResponse(responseCode = "400", description = "잘못된 요청"),
        @ApiResponse(responseCode = "500", description = "서버 오류")
    })
    @PostMapping
    public ResponseEntity<CalculationResultGroup> calculate(
        @Parameter(description = "계산 요청", required = true)
        @Valid @RequestBody CalculationRequest request) {

        log.info("청구 계산 요청: {}", request);

        CalculationResultGroup result = calculationCommandUseCase.calculate(
            request.contractIds(),
            request.billingStartDate(),
            request.billingEndDate()
        );

        return ResponseEntity.ok(result);
    }
}
```

## Request/Response 설계 패턴

### Request Record 패턴

Jakarta Validation 어노테이션을 사용한 검증:

```java
public record CalculationRequest(
    @NotEmpty(message = "계약 ID 목록은 비어있을 수 없습니다")
    List<Long> contractIds,

    @NotNull(message = "청구 시작일은 필수입니다")
    LocalDate billingStartDate,

    @NotNull(message = "청구 종료일은 필수입니다")
    LocalDate billingEndDate,

    String billingCalculationType,

    String billingCalculationPeriod
) {}
```

### Response Wrapper 패턴

일관된 응답 구조:

```java
public record CalculationResultGroup(
    List<CalculationResult<?>> calculationResults
) {}
```

### 검증 Best Practices

**Jakarta Validation 어노테이션**:
- `@NotNull`: null 값 허용 안함
- `@NotEmpty`: 빈 컬렉션/문자열 허용 안함
- `@Valid`: 중첩된 객체 검증
- `@Size`: 크기/길이 제약
- `@Pattern`: 정규식 패턴 매칭

**커스텀 검증 메시지**:
```java
@NotEmpty(message = "계약 ID 목록은 비어있을 수 없습니다")
```

**필드 레벨 검증**:
- Request record에 포괄적인 필드 검증 구현
- 한글로 의미 있는 검증 메시지 제공
- GlobalExceptionHandler에서 검증 예외 처리

## Exception Handling Architecture

### GlobalExceptionHandler

중앙 집중식 예외 처리를 위한 `@ControllerAdvice`:

```java
@ControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationException(
        MethodArgumentNotValidException ex,
        HttpServletRequest request
    ) {
        log.warn("검증 오류: {}", ex.getMessage());

        Map<String, String> fieldErrors = ex.getBindingResult()
            .getFieldErrors()
            .stream()
            .collect(Collectors.toMap(
                FieldError::getField,
                error -> error.getDefaultMessage() != null
                    ? error.getDefaultMessage()
                    : "검증 실패"
            ));

        ErrorResponse errorResponse = new ErrorResponse(
            "VALIDATION_ERROR",
            "요청 검증 실패",
            fieldErrors,
            request.getRequestURI(),
            LocalDateTime.now()
        );

        return ResponseEntity.badRequest().body(errorResponse);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleException(
        Exception ex,
        HttpServletRequest request
    ) {
        log.error("예상치 못한 오류: ", ex);

        ErrorResponse errorResponse = new ErrorResponse(
            "INTERNAL_ERROR",
            "서버 내부 오류가 발생했습니다",
            null,
            request.getRequestURI(),
            LocalDateTime.now()
        );

        return ResponseEntity.internalServerError().body(errorResponse);
    }
}
```

### 구조화된 Error Response

```java
public record ErrorResponse(
    String errorCode,
    String message,
    Map<String, String> fieldErrors,
    String path,
    LocalDateTime timestamp
) {}
```

**특징**:
- 일관된 오류 형식
- 필드 레벨 검증 오류 상세 보고
- 요청 경로 및 타임스탬프 포함
- 클라이언트 친화적 오류 메시지

### 예외 처리 전략

**특정 핸들러**:
- `MethodArgumentNotValidException`: 검증 오류 (400 Bad Request)
- `BindException`: 바인딩 오류 (400 Bad Request)
- `HttpMessageNotReadableException`: JSON 파싱 오류 (400 Bad Request)
- `Exception`: 일반 서버 오류 (500 Internal Server Error)

**로깅 전략**:
- 클라이언트 오류 (4xx)에 대해 WARN 레벨
- 서버 오류 (5xx)에 대해 ERROR 레벨
- 디버깅을 위한 상세 스택 트레이스

## Swagger/OpenAPI 구성

### SwaggerConfig

```java
@Configuration
public class SwaggerConfig {

    @Bean
    public OpenAPI openAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("Telecom Billing API")
                .description("통신사 청구 계산 시스템 API")
                .version("0.0.1-SNAPSHOT")
                .contact(new Contact()
                    .name("개발팀")
                    .email("dev@example.com")));
    }
}
```

### API 문서화 어노테이션

**Controller 레벨**:
```java
@Tag(name = "Calculation API", description = "청구 계산 관련 API")
```

**Method 레벨**:
```java
@Operation(summary = "청구 계산", description = "상세 설명...")
@ApiResponses(value = {
    @ApiResponse(responseCode = "200", description = "성공"),
    @ApiResponse(responseCode = "400", description = "잘못된 요청")
})
```

**Parameter 레벨**:
```java
@Parameter(description = "파라미터 설명", required = true)
```

### Swagger UI 접근

개발 서버 실행 후:
1. 브라우저에서 `http://localhost:8080/swagger-ui.html` 접속
2. API 엔드포인트 탐색
3. "Try it out"으로 직접 API 테스트
4. Request/Response 스키마 확인

## MyBatis 구성

### Multi-Module MyBatis 설정

MyBatis mapper가 여러 모듈에 분산되어 있음:

**Infrastructure 모듈**:
- `src/main/resources/mapper/`에 핵심 MyBatis mapper
- 공통 인프라 DTO 및 converter
- 계산 결과 영속성

**Policy 모듈**:
- **monthlyfee**: 계약/상품 쿼리 mapper
- **onetimecharge**: 일회성 요금 데이터 mapper

### Web Service 모듈 구성

**@MapperScan**으로 모든 mapper 패키지 스캔:

```java
@Configuration
@MapperScan({
    "me.realimpact.telecom.calculation.infrastructure.adapter.mybatis",
    "me.realimpact.telecom.calculation.policy.monthlyfee.adapter.mybatis",
    "me.realimpact.telecom.calculation.policy.onetimecharge.adapter.mybatis"
})
public class MyBatisConfig {
    // 추가 구성
}
```

**데이터베이스 연결**:
- 프로덕션을 위한 HikariCP 최적화로 MySQL 연결
- 개발/테스트를 위한 H2 in-memory 데이터베이스

## 개발 Best Practices

### Controller 설계
- **단일 책임**: 각 controller는 단일 리소스 처리
- **RESTful 설계**: HTTP 메서드 및 상태 코드의 적절한 사용
- **일관된 URL**: `/api/{resource}` 패턴 따르기
- **버전 관리**: 필요시 API 버전 관리 고려

### 검증
- **조기 검증**: Controller에서 입력 검증
- **비즈니스 검증**: 서비스 레이어에서 비즈니스 규칙 검증
- **명확한 메시지**: 사용자 친화적 오류 메시지 (한글)

### 로깅
```java
@Slf4j
public class CalculationController {

    @PostMapping
    public ResponseEntity<CalculationResultGroup> calculate(
        @Valid @RequestBody CalculationRequest request) {

        log.info("청구 계산 요청: contractIds={}, period={} to {}",
            request.contractIds(),
            request.billingStartDate(),
            request.billingEndDate());

        try {
            CalculationResultGroup result = calculationCommandUseCase.calculate(request);
            log.info("청구 계산 완료: {} 건의 결과", result.calculationResults().size());
            return ResponseEntity.ok(result);

        } catch (Exception e) {
            log.error("청구 계산 실패: ", e);
            throw e;
        }
    }
}
```

### 응답 형식
- **성공**: `ResponseEntity.ok(data)` (200)
- **생성**: `ResponseEntity.created(location).body(data)` (201)
- **잘못된 요청**: `ResponseEntity.badRequest().body(error)` (400)
- **서버 오류**: `ResponseEntity.internalServerError().body(error)` (500)

## 테스트

### Controller 테스트

```java
@WebMvcTest(CalculationController.class)
class CalculationControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private CalculationCommandUseCase calculationCommandUseCase;

    @Test
    void 청구_계산_성공() throws Exception {
        // Given
        CalculationRequest request = new CalculationRequest(
            List.of(1L, 2L),
            LocalDate.of(2025, 1, 1),
            LocalDate.of(2025, 1, 31),
            "MONTHLY_FEE",
            "MONTHLY"
        );

        // When & Then
        mockMvc.perform(post("/api/calculations")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.calculationResults").isArray());
    }

    @Test
    void 검증_실패_빈_계약ID() throws Exception {
        // Given
        CalculationRequest request = new CalculationRequest(
            List.of(),  // 빈 리스트
            LocalDate.of(2025, 1, 1),
            LocalDate.of(2025, 1, 31),
            "MONTHLY_FEE",
            "MONTHLY"
        );

        // When & Then
        mockMvc.perform(post("/api/calculations")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));
    }
}
```

### 통합 테스트

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class CalculationIntegrationTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void 전체_청구_계산_흐름() {
        // Given
        CalculationRequest request = createValidRequest();

        // When
        ResponseEntity<CalculationResultGroup> response =
            restTemplate.postForEntity(
                "/api/calculations",
                request,
                CalculationResultGroup.class
            );

        // Then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().calculationResults()).isNotEmpty();
    }
}
```

## 일반적인 문제 해결

### CORS 문제
프론트엔드 통합 시 CORS 구성 추가:

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
            .allowedOrigins("http://localhost:3000")
            .allowedMethods("GET", "POST", "PUT", "DELETE")
            .allowCredentials(true);
    }
}
```

### H2 Console 접근
개발 중 H2 console 활성화:

```yaml
# application.yml
spring:
  h2:
    console:
      enabled: true
      path: /h2-console
```

접근: `http://localhost:8080/h2-console`

### 검증 실패
- Request record에 `@Valid` 어노테이션 확인
- Controller에 `@Validated` 어노테이션 확인
- 검증 메시지가 한글로 올바르게 설정되었는지 확인

### MyBatis Mapper 감지 안됨
- `@MapperScan` 패키지 경로 확인
- Mapper XML 파일이 올바른 위치에 있는지 확인 (`src/main/resources/mapper/`)
- Mapper interface와 XML namespace 일치 확인
