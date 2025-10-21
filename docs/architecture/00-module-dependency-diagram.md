# Telecom Billing System - Module & Package Dependency

전체 시스템의 모듈 구조와 패키지 간 의존성 관계를 보여주는 다이어그램입니다.

## Module Architecture

```mermaid
graph TB
    subgraph "Application Modules"
        WEB[web-service<br/>REST API Layer]
        BATCH[batch<br/>Spring Batch Layer]
        TESTGEN[testgen<br/>Test Data Generator]
    end

    subgraph "Policy Modules (Independent)"
        POLICY_MONTHLY[calculation-policy-monthlyfee<br/>Monthly Fee Policies]
        POLICY_ONETIME[calculation-policy-onetimecharge<br/>OneTime Charge Policies]
    end

    subgraph "Core Calculation Framework"
        CALC_INFRA[calculation-infrastructure<br/>Infrastructure Adapters]
        CALC_APP[calculation-application<br/>Application Services]
        CALC_PORT[calculation-port<br/>Outbound Ports]
        CALC_API[calculation-api<br/>Inbound Ports]
        CALC_DOMAIN[calculation-domain<br/>Domain Entities]
    end

    %% Application Module Dependencies
    WEB --> CALC_INFRA
    WEB --> CALC_APP
    WEB --> CALC_API
    WEB --> POLICY_MONTHLY
    WEB --> POLICY_ONETIME

    BATCH --> CALC_INFRA
    BATCH --> CALC_APP
    BATCH --> CALC_API
    BATCH --> POLICY_MONTHLY
    BATCH --> POLICY_ONETIME

    %% Policy Module Dependencies
    POLICY_MONTHLY --> CALC_APP
    POLICY_MONTHLY --> CALC_DOMAIN

    POLICY_ONETIME --> CALC_APP
    POLICY_ONETIME --> CALC_DOMAIN

    %% Core Framework Dependencies
    CALC_INFRA --> CALC_PORT
    CALC_INFRA --> CALC_DOMAIN

    CALC_APP --> CALC_API
    CALC_APP --> CALC_PORT
    CALC_APP --> CALC_DOMAIN

    CALC_PORT --> CALC_DOMAIN
    CALC_API --> CALC_DOMAIN

    %% Styling
    classDef appModule fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef policyModule fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef coreModule fill:#f3e5f5,stroke:#4a148c,stroke-width:2px

    class WEB,BATCH,TESTGEN appModule
    class POLICY_MONTHLY,POLICY_ONETIME policyModule
    class CALC_DOMAIN,CALC_API,CALC_PORT,CALC_APP,CALC_INFRA coreModule
```

## Package Structure & Dependencies

```mermaid
graph LR
    subgraph "calculation-policy-monthlyfee"
        PM_CALC[calculator<br/>BasicPolicyMonthlyFeeCalculator]
        PM_LOADER[loader<br/>ContractWithProducts...DataLoader]
        PM_DOMAIN[domain<br/>Pricing Policies]
        PM_ADAPTER[adapter<br/>Product Repositories]
        PM_PORT[port<br/>ProductQueryPort]
    end

    subgraph "calculation-policy-onetimecharge"
        PO_CALC[calculator<br/>InstallationFee<br/>DeviceInstallment]
        PO_LOADER[loader<br/>Installation/Installment<br/>DataLoaders]
        PO_DOMAIN[domain<br/>InstallationHistory<br/>DeviceInstallmentMaster]
        PO_ADAPTER[adapter<br/>Repositories]
        PO_PORT[port<br/>Query/Command Ports]
    end

    subgraph "calculation-application"
        APP_SERVICE[CalculationCommandService]
        APP_CALCULATOR[Calculator Interface]
        APP_DISCOUNT[DiscountCalculator]
        APP_VAT[VatCalculator]
        APP_PRORATER[CalculationResultProrater]
    end

    subgraph "calculation-infrastructure"
        INFRA_REPO[Repositories<br/>CalculationResult<br/>Discount<br/>RevenueMasterData]
        INFRA_MYBATIS[MyBatis Mappers]
        INFRA_CONVERTER[DTO Converters]
    end

    subgraph "calculation-domain"
        DOM_RESULT[CalculationResult]
        DOM_CONTEXT[CalculationContext]
        DOM_MARKER[Marker Interfaces<br/>MonthlyChargeDomain<br/>OneTimeChargeDomain]
    end

    subgraph "calculation-api"
        API_USECASE[CalculationCommandUseCase]
        API_REQUEST[Request/Response DTOs]
    end

    subgraph "calculation-port"
        PORT_SAVE[CalculationResultSavePort]
        PORT_QUERY[Query Ports]
        PORT_COMMAND[Command Ports]
    end

    %% Policy Module Dependencies
    PM_CALC --> APP_CALCULATOR
    PM_LOADER --> APP_CALCULATOR
    PM_DOMAIN --> DOM_MARKER
    PM_ADAPTER --> PM_PORT
    PM_PORT --> DOM_MARKER

    PO_CALC --> APP_CALCULATOR
    PO_LOADER --> APP_CALCULATOR
    PO_DOMAIN --> DOM_MARKER
    PO_ADAPTER --> PO_PORT
    PO_PORT --> DOM_MARKER

    %% Application Dependencies
    APP_SERVICE --> API_USECASE
    APP_SERVICE --> APP_CALCULATOR
    APP_SERVICE --> DOM_RESULT
    APP_SERVICE --> DOM_CONTEXT
    APP_DISCOUNT --> DOM_RESULT
    APP_VAT --> DOM_RESULT
    APP_PRORATER --> DOM_RESULT

    %% Infrastructure Dependencies
    INFRA_REPO --> PORT_SAVE
    INFRA_REPO --> PORT_QUERY
    INFRA_MYBATIS --> INFRA_CONVERTER
    INFRA_CONVERTER --> DOM_RESULT

    %% Styling
    classDef policyClass fill:#fff3e0,stroke:#e65100
    classDef appClass fill:#e8f5e9,stroke:#2e7d32
    classDef infraClass fill:#fce4ec,stroke:#c2185b
    classDef domainClass fill:#f3e5f5,stroke:#4a148c
    classDef apiClass fill:#e3f2fd,stroke:#1565c0
    classDef portClass fill:#fff9c4,stroke:#f57f17

    class PM_CALC,PM_LOADER,PM_DOMAIN,PM_ADAPTER,PM_PORT policyClass
    class PO_CALC,PO_LOADER,PO_DOMAIN,PO_ADAPTER,PO_PORT policyClass
    class APP_SERVICE,APP_CALCULATOR,APP_DISCOUNT,APP_VAT,APP_PRORATER appClass
    class INFRA_REPO,INFRA_MYBATIS,INFRA_CONVERTER infraClass
    class DOM_RESULT,DOM_CONTEXT,DOM_MARKER domainClass
    class API_USECASE,API_REQUEST apiClass
    class PORT_SAVE,PORT_QUERY,PORT_COMMAND portClass
```

## Layer-based View

```mermaid
graph TD
    subgraph "Presentation Layer"
        REST[REST Controllers<br/>web-service]
        BATCH_RUNNER[Batch Jobs<br/>batch]
    end

    subgraph "Application Layer"
        APP_CORE[calculation-application<br/>Orchestration Services]
        APP_POLICY_M[calculation-policy-monthlyfee<br/>Monthly Fee Logic]
        APP_POLICY_O[calculation-policy-onetimecharge<br/>OneTime Charge Logic]
    end

    subgraph "Domain Layer"
        DOMAIN_CORE[calculation-domain<br/>Core Entities & Rules]
        DOMAIN_API[calculation-api<br/>Use Case Interfaces]
    end

    subgraph "Infrastructure Layer"
        INFRA[calculation-infrastructure<br/>Repositories & Adapters]
        INFRA_POLICY_M[calculation-policy-monthlyfee<br/>MyBatis Mappers]
        INFRA_POLICY_O[calculation-policy-onetimecharge<br/>MyBatis Mappers]
    end

    subgraph "Port Layer"
        PORTS[calculation-port<br/>Repository Interfaces]
    end

    REST --> APP_CORE
    REST --> DOMAIN_API
    BATCH_RUNNER --> APP_CORE
    BATCH_RUNNER --> DOMAIN_API

    APP_CORE --> DOMAIN_API
    APP_CORE --> DOMAIN_CORE
    APP_CORE --> PORTS

    APP_POLICY_M --> APP_CORE
    APP_POLICY_M --> DOMAIN_CORE

    APP_POLICY_O --> APP_CORE
    APP_POLICY_O --> DOMAIN_CORE

    INFRA --> PORTS
    INFRA --> DOMAIN_CORE

    INFRA_POLICY_M --> PORTS
    INFRA_POLICY_O --> PORTS

    DOMAIN_API --> DOMAIN_CORE
    PORTS --> DOMAIN_CORE

    classDef presentation fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef application fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    classDef domain fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef infrastructure fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef port fill:#fff9c4,stroke:#f57f17,stroke-width:2px

    class REST,BATCH_RUNNER presentation
    class APP_CORE,APP_POLICY_M,APP_POLICY_O application
    class DOMAIN_CORE,DOMAIN_API domain
    class INFRA,INFRA_POLICY_M,INFRA_POLICY_O infrastructure
    class PORTS port
```

## Module Characteristics

### 📦 Core Calculation Framework (Under `calculation/`)

| Module | Type | Dependencies | Responsibility |
|--------|------|--------------|----------------|
| **calculation-domain** | Library JAR | None | Core domain entities, value objects, business rules |
| **calculation-api** | Library JAR | calculation-domain | Use case interfaces, request/response DTOs |
| **calculation-port** | Library JAR | calculation-domain | Repository interfaces (outbound ports) |
| **calculation-application** | Library JAR | api, port, domain | Application services, orchestration, calculators |
| **calculation-infrastructure** | Library JAR | port, domain, MyBatis | Repository implementations, adapters |

### 🎯 Policy Modules (Top-level, Independent)

| Module | Type | Dependencies | Responsibility |
|--------|------|--------------|----------------|
| **calculation-policy-monthlyfee** | Library JAR | application, domain | Monthly fee calculators, pricing policies, data loaders, MyBatis mappers |
| **calculation-policy-onetimecharge** | Library JAR | application, domain | OneTime charge calculators, data loaders, MyBatis mappers |

### 🚀 Application Modules

| Module | Type | Dependencies | Responsibility |
|--------|------|--------------|----------------|
| **web-service** | Boot JAR | All calculation + policy modules | REST API endpoints, Swagger, exception handling |
| **batch** | Boot JAR | All calculation + policy modules | Spring Batch processing, multi-threading |
| **testgen** | Boot JAR | MyBatis, MySQL | Test data generation with JavaFaker |

## Dependency Rules

### ✅ Allowed Dependencies
- Application modules → Core framework modules
- Application modules → Policy modules
- Policy modules → Application core (calculator interfaces)
- Policy modules → Domain (marker interfaces, entities)
- Infrastructure → Port interfaces
- All layers → Domain

### ❌ Forbidden Dependencies
- Domain → Infrastructure
- Domain → Application
- Core framework → Policy modules
- Policy modules → Application modules
- Lower layers → Higher layers

## Key Architectural Patterns

### 1. Hexagonal Architecture (Ports & Adapters)
- **Inbound Ports**: `calculation-api` (use case interfaces)
- **Outbound Ports**: `calculation-port` (repository interfaces)
- **Adapters**: `calculation-infrastructure`, policy module adapters

### 2. Dependency Inversion Principle
- Core domain has no dependencies
- Application depends on abstractions (ports)
- Infrastructure implements ports

### 3. Plugin Architecture
- Policy modules are independent plugins
- Auto-discovery via Spring `@Component` scanning
- Zero-code extensibility

### 4. Layer Isolation
- Clear separation between layers
- Dependencies flow inward (toward domain)
- Policy modules bridge application and domain

## Package Naming Convention

```
me.realimpact.telecom.calculation/
├── api/                                    # Use case interfaces
├── domain/                                 # Core domain entities
├── port/                                   # Repository interfaces
├── application/                            # Application services
├── infrastructure/                         # Infrastructure adapters
│   ├── adapter/
│   │   └── mybatis/
│   ├── dto/
│   └── converter/
└── policy/
    ├── monthlyfee/                        # Monthly fee policy
    │   ├── calculator/
    │   ├── loader/
    │   ├── domain/
    │   ├── adapter/
    │   │   └── mybatis/
    │   └── port/
    └── onetimecharge/                     # OneTime charge policy
        ├── calculator/
        ├── loader/
        ├── domain/
        ├── adapter/
        │   └── mybatis/
        └── port/
```

## 🎨 Design Benefits

### Separation of Concerns
- **Core Framework**: Provides calculation infrastructure
- **Policy Modules**: Implement specific business policies
- **Application Modules**: Consume framework + policies

### Independent Deployment
- Policy modules can be versioned independently
- Easy to add new policy modules
- Core framework updates don't affect policy implementations

### Testability
- Each module can be tested independently
- Policy modules have clear boundaries
- Mock-free domain testing

### Extensibility
- Add new calculators by implementing interfaces
- Spring auto-discovers `@Component` beans
- No modification to existing code required
