# Telecom Billing Calculation System

Spring Boot 3 기반 통신사 요금 계산 시스템 - 한국 통신 서비스를 위한 복잡한 일할 계산 로직과 TMForum 스펙 준수

## 🚀 Quick Start

### Prerequisites
- Java 21 or higher
- MySQL 8.0 or higher (optional: Docker)
- Git

### Build and Run

**Unix/Linux/macOS:**
```bash
# Clone the repository
git clone <repository-url>
cd telecom

# Build the project
./gradlew clean build

# Run web service
./gradlew :web-service:bootRun

# Run batch processing
./run-batch-jar.sh
```

**Windows:**
```batch
REM Clone the repository
git clone <repository-url>
cd telecom

REM Build the project
gradlew.bat clean build

REM Run web service
gradlew.bat :web-service:bootRun

REM Run batch processing
run-batch-jar.bat
```

## 📁 Project Structure

```
telecom/
├── calculation/                          # Core calculation framework
│   ├── calculation-domain               # Domain entities and business logic
│   ├── calculation-api                  # Use case interfaces
│   ├── calculation-port                 # Repository interfaces
│   ├── calculation-application          # Application services
│   └── calculation-infrastructure       # Infrastructure adapters
├── calculation-policy-monthlyfee        # Monthly fee calculation policies
├── calculation-policy-onetimecharge     # One-time charge policies
├── web-service                          # REST API layer
├── batch                                # Spring Batch processing
└── testgen                              # Test data generator
```

## 🛠️ Technology Stack

- **Java 21** - Modern Java features with records and pattern matching
- **Spring Boot 3.2.4** - Application framework
- **Spring Batch** - Large-scale batch processing
- **MyBatis 3.0.3** - SQL mapping framework
- **MySQL 8.0** - Primary database
- **Gradle 8.14.2** - Build automation
- **JUnit 5** - Testing framework

## 📖 Documentation

- **[CLAUDE.md](./CLAUDE.md)** - Comprehensive development guide for AI assistants and developers
- **[Architecture Guide](./docs/ARCHITECTURE.md)** - Technical architecture and module structure
- **[Business Domain Guide](./docs/BUSINESS_DOMAIN.md)** - Business logic and domain model
- **[Batch Execution Guide](./BATCH_EXECUTION_GUIDE.md)** - Batch processing guide

## 🔧 Key Features

### Calculation Engine
- ✅ **Monthly Fee Calculation** - Complex pro-rated billing with suspension handling
- ✅ **One-time Charges** - Installation fees and device installment processing
- ✅ **Discount Management** - Rate-based and amount-based discount calculations
- ✅ **VAT Calculation** - Automated tax calculation with revenue mapping
- ✅ **Multi-threading** - Thread pool and partitioner architectures for performance

### Architecture Highlights
- 🏗️ **Hexagonal Architecture** - Clean separation of concerns
- 🔌 **Policy Pattern** - Extensible pricing strategies
- 🔄 **Spring DI** - Auto-injection for calculator components
- 📊 **Batch Processing** - Dual architecture (Thread Pool vs Partitioner)

## 🚦 Running Tests

**Unix/Linux/macOS:**
```bash
# Run all tests
./gradlew test

# Run specific module tests
./gradlew :calculation-policy-monthlyfee:test
./gradlew :batch:test
```

**Windows:**
```batch
REM Run all tests
gradlew.bat test

REM Run specific module tests
gradlew.bat :calculation-policy-monthlyfee:test
gradlew.bat :batch:test
```

## 📊 Batch Processing

### Thread Pool Architecture
```bash
# Unix/Linux/macOS
./run-batch-jar.sh

# Windows
run-batch-jar.bat
```

### Partitioner Architecture
```bash
# Unix/Linux/macOS
./run-partitioned-batch-jar.sh

# Windows
run-partitioned-batch-jar.bat
```

### Test Data Generation
```bash
# Unix/Linux/macOS
./run-testgen.sh 100000          # Generate 100,000 contracts
./run-testgen.sh -m 8g 1000000   # Generate 1M contracts with 8GB memory

# Windows
run-testgen.bat 100000           # Generate 100,000 contracts
run-testgen.bat -m 8g 1000000    # Generate 1M contracts with 8GB memory
```

## 🌐 API Documentation

When running the web-service, access Swagger UI at:
```
http://localhost:8080/swagger-ui.html
```

## 🗄️ Database Setup

### Using Docker
```bash
docker-compose up -d
```

### Manual Setup
1. Create MySQL database: `telecom_billing`
2. Run DDL scripts from `ddl/` directory
3. Configure `application.yml` with your database credentials

## 🤝 Contributing

1. Follow the coding standards in CLAUDE.md
2. Write tests for new features
3. Update documentation as needed
4. Use meaningful commit messages

## 📝 License

[Your License Here]

## 🔗 Related Projects

- [TMForum Open APIs](https://www.tmforum.org/open-apis/)

---

**For detailed development guidance, refer to [CLAUDE.md](./CLAUDE.md)**
