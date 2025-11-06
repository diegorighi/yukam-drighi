# Yukam/VaNessa Mudança - Project Context

> **Purpose**: This document provides comprehensive technical context for LLMs working on this codebase.
> **Last Updated**: 2025-11-06

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Infrastructure (Terraform)](#infrastructure-terraform)
3. [Services](#services)
4. [Authentication & Security (OAuth2)](#authentication--security-oauth2)
5. [CI/CD Pipeline](#cicd-pipeline)
6. [Development Workflow](#development-workflow)
7. [Testing Strategy](#testing-strategy)
8. [Deployment](#deployment)
9. [Cost Optimization](#cost-optimization)

---

## Architecture Overview

### System Architecture

Microservices architecture on AWS ECS Fargate with shared infrastructure pattern:

```
Internet Gateway
    ↓
Application Load Balancer (shared)
├─ /api/clientes/* → cliente-core (port 8081)
├─ /api/vendas/*   → venda-core (port 8082)
└─ /api/storage/*  → storage-core (port 8083)
    ↓
ECS Cluster: vanessa-mudanca-prod
├─ cliente-core-service (1-3 Fargate Spot tasks)
├─ venda-core-service (1-3 Fargate Spot tasks)
└─ storage-core-service (1-3 Fargate Spot tasks)
    ↓
RDS PostgreSQL 16 (Multi-Schema)
├─ Schema: cliente_core
├─ Schema: venda_core
└─ Schema: storage_core
```

### Key Principles

1. **Shared Infrastructure, Independent Deployments** - VPC, RDS, ALB shared; services deployed independently
2. **Cost Optimization First** - Fargate Spot (70% discount), scale-to-zero, ARM Graviton
3. **Security by Design** - VPC Endpoints (no NAT Gateway), OAuth2 JWT, secret management
4. **Observability** - Structured JSON logs, CloudWatch metrics, correlation IDs

### Network Architecture

**VPC**: `172.31.0.0/16` (Default VPC - will migrate to custom VPC in production)

**Subnets**:
- Public (ALB): `172.31.0.0/20`, `172.31.16.0/20`, `172.31.32.0/20` (3 AZs)
- Private (ECS): `172.31.48.0/20`, `172.31.64.0/20`, `172.31.80.0/20` (3 AZs)
- Database (RDS): `172.31.96.0/20`, `172.31.112.0/20` (2 AZs)

**VPC Endpoints** (saves $32/month NAT Gateway cost):
- Interface: Secrets Manager, ECR API, ECR DKR, CloudWatch Logs
- Gateway: S3

---

## Infrastructure (Terraform)

### Repository Structure

```
terraform/
├── main.tf                    # Root module - orchestrates all infrastructure
├── variables.tf               # Root variables
├── outputs.tf                 # Root outputs
├── terraform.tfvars          # Environment-specific values (gitignored)
├── shared/                    # Shared infrastructure module
│   ├── main.tf               # VPC, RDS, ALB, Cognito
│   ├── vpc.tf                # VPC and subnets
│   ├── rds.tf                # PostgreSQL Multi-Schema
│   ├── alb.tf                # Application Load Balancer
│   ├── cognito.tf            # User Pool + Resource Server
│   ├── cloudwatch.tf         # Log groups
│   └── outputs.tf
└── modules/
    └── ecs-service/          # Reusable ECS service module
        ├── main.tf           # ECS Service + Task Definition
        ├── ecr.tf            # ECR repository
        ├── autoscaling.tf    # CPU-based + Schedule-based scaling
        ├── iam.tf            # Task execution role + task role
        ├── variables.tf
        └── outputs.tf
```

### Module Usage Pattern

**Root module** (`terraform/main.tf`):
```hcl
module "shared" {
  source = "./shared"
  # Provisions VPC, RDS, ALB, Cognito once
}

module "cliente_core" {
  source = "./modules/ecs-service"
  service_name = "cliente-core"
  alb_arn = module.shared.alb_arn
  db_host = module.shared.rds_endpoint
  # Creates ECR, ECS Service, Target Group, ALB listener rule
}

module "venda_core" {
  source = "./modules/ecs-service"
  service_name = "venda-core"
  # Same pattern - new service in 5 minutes
}
```

### Terraform Commands

**Development (local state)**:
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

**Production (S3 backend)**:
```bash
terraform init \
  -backend-config="bucket=yukam-terraform-state" \
  -backend-config="key=prod/terraform.tfstate" \
  -backend-config="region=sa-east-1"
```

### Key Resources

**ECS Service**:
- Cluster: `vanessa-mudanca-prod`
- Capacity Provider: `FARGATE_SPOT` (100% weight, 70% discount)
- Auto-scaling: 0-3 tasks (scale-to-zero off-hours)

**RDS**:
- Engine: PostgreSQL 16.7
- Instance: `db.t4g.micro` (ARM Graviton2, 2 vCPU, 1 GB RAM)
- Storage: 20 GB gp3 SSD (autoscaling to 100 GB)
- Multi-Schema: One database, separate schemas per service

**ALB**:
- Type: Application Load Balancer
- Scheme: Internet-facing
- Path-based routing to Target Groups
- Health checks: `/api/{service}/actuator/health`

**Cognito**:
- User Pool: `yukam-user-pool`
- Domain: `yukam-auth.auth.sa-east-1.amazoncognito.com`
- Resource Server: `cliente-core` with scopes `cliente-core/read`, `cliente-core/write`
- App Client: `cliente-core-app` (Client Credentials flow)

---

## Services

### cliente-core

**Purpose**: Customer management microservice (PF and PJ)

**Technology Stack**:
- Java 21 (LTS)
- Spring Boot 3.4.0
- Spring Security 6.4 (OAuth2 Resource Server)
- Spring Data JPA + Hibernate
- PostgreSQL 16
- Liquibase (database migrations)
- Docker multi-stage build

**Package Structure**:
```
br.com.vanessa_mudanca.cliente_core/
├── application/
│   ├── dto/              # Request/Response DTOs
│   ├── service/          # Business logic
│   └── usecase/          # Use case orchestration
├── domain/
│   ├── model/            # Domain entities (Cliente PF/PJ)
│   ├── repository/       # JPA repositories
│   └── validator/        # Business rules validation
├── infrastructure/
│   ├── config/           # Spring configuration
│   ├── security/         # OAuth2 + JWT validation
│   └── web/
│       ├── controller/   # REST controllers
│       ├── exception/    # Exception handlers
│       └── filter/       # Request/Response filters
└── ClienteCoreApplication.java
```

**Key Endpoints**:
- `GET /actuator/health` - Health check (public)
- `POST /api/clientes/v1/clientes/pf` - Create Cliente PF (requires `cliente-core/write`)
- `GET /api/clientes/v1/clientes/pf/{id}` - Get Cliente PF (requires `cliente-core/read`)
- `PUT /api/clientes/v1/clientes/pf/{id}` - Update Cliente PF
- `DELETE /api/clientes/v1/clientes/pf/{id}` - Soft delete Cliente PF
- Similar endpoints for Cliente PJ

**Database Schema**:
```sql
-- PostgreSQL schema: cliente_core
CREATE TABLE cliente_pf (
    id BIGSERIAL PRIMARY KEY,
    public_id UUID UNIQUE NOT NULL,
    nome VARCHAR(255) NOT NULL,
    cpf VARCHAR(11) UNIQUE NOT NULL,
    email VARCHAR(255),
    telefone VARCHAR(20),
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP
);

CREATE TABLE cliente_pj (
    id BIGSERIAL PRIMARY KEY,
    public_id UUID UNIQUE NOT NULL,
    razao_social VARCHAR(255) NOT NULL,
    cnpj VARCHAR(14) UNIQUE NOT NULL,
    nome_fantasia VARCHAR(255),
    email VARCHAR(255),
    telefone VARCHAR(20),
    ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP
);
```

**Environment Variables**:
```bash
# Database
DB_HOST=vanessa-mudanca-rds.xyz.sa-east-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=vanessa_mudanca
DB_SCHEMA=cliente_core
DB_USERNAME=cliente_core_user
DB_PASSWORD=<from-secrets-or-env>

# OAuth2
SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI=https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_XXXXX
COGNITO_USER_POOL_ID=sa-east-1_XXXXX
COGNITO_REGION=sa-east-1

# Application
SERVER_PORT=8081
SPRING_PROFILES_ACTIVE=prod
JAVA_OPTS=-XX:+UseZGC -Xmx384m
```

**Build & Run**:
```bash
# Local development
cd services/cliente-core
mvn clean install
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# Docker build
docker build -t cliente-core:latest .
docker run -p 8081:8081 \
  -e DB_HOST=localhost \
  -e DB_PASSWORD=secret \
  cliente-core:latest

# Maven tests
mvn test                    # Unit tests only
mvn verify                  # Unit tests + integration tests (if enabled)
mvn test jacoco:report      # Coverage report at target/site/jacoco/index.html
```

---

## Authentication & Security (OAuth2)

### OAuth2 Client Credentials Flow

**Flow**:
```
1. Client (Postman/Service) → POST /oauth2/token
   Headers: Authorization: Basic base64(client_id:client_secret)
   Body: grant_type=client_credentials&scope=cliente-core/read cliente-core/write

2. AWS Cognito → Validates credentials → Returns JWT

3. Client → Request to API
   Headers: Authorization: Bearer <jwt>

4. API (cliente-core) → Validates JWT signature and claims → Allows/Denies
```

### Cognito Configuration

**User Pool**: `yukam-user-pool`
**Resource Server**: `cliente-core`
**Scopes**:
- `cliente-core/read` - Read-only access
- `cliente-core/write` - Write access

**App Client**: `cliente-core-app`
- Type: Confidential client
- Authentication flow: Client Credentials
- OAuth scopes: `cliente-core/read`, `cliente-core/write`
- OAuth flows enabled: Yes
- Callback URLs: N/A (machine-to-machine)

### JWT Token Structure

```json
{
  "sub": "41u8or3q6id9nm8395qvl214j",
  "token_use": "access",
  "scope": "cliente-core/read cliente-core/write",
  "auth_time": 1699999999,
  "iss": "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_XXXXX",
  "exp": 1699999999,
  "iat": 1699999999,
  "version": 2,
  "jti": "uuid",
  "client_id": "41u8or3q6id9nm8395qvl214j"
}
```

### Spring Security Configuration

**SecurityConfig.java**:
```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health").permitAll()
                .requestMatchers("/api/clientes/**").authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt.decoder(jwtDecoder()))
            );
        return http.build();
    }

    @Bean
    public JwtDecoder jwtDecoder() {
        return JwtDecoders.fromIssuerLocation(issuerUri);
    }
}
```

**Method-level security**:
```java
@PreAuthorize("hasAuthority('SCOPE_cliente-core/write')")
public ClientePFResponseDTO create(ClientePFRequestDTO dto) {
    // Only allowed with cliente-core/write scope
}
```

### Getting Credentials

**Via AWS CLI**:
```bash
# Run automated script
./scripts/get-cognito-credentials.sh

# Manual commands
aws cognito-idp list-user-pools --max-results 10
aws cognito-idp list-user-pool-clients --user-pool-id <pool-id>
aws cognito-idp describe-user-pool-client \
  --user-pool-id <pool-id> \
  --client-id <client-id>
```

**Testing with cURL**:
```bash
# Get token
curl -X POST https://yukam-auth.auth.sa-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "CLIENT_ID:CLIENT_SECRET" \
  -d "grant_type=client_credentials&scope=cliente-core/read cliente-core/write"

# Use token
TOKEN="<jwt-from-above>"
curl -X GET http://localhost:8081/api/clientes/v1/clientes/pf \
  -H "Authorization: Bearer $TOKEN"
```

---

## CI/CD Pipeline

### GitHub Actions Workflows

**Location**: `.github/workflows/`

**Workflows**:
1. `ci.yml` - Continuous Integration (on PR, develop)
2. `deploy-production.yml` - Production deployment (on push to main)

### CI Workflow (`ci.yml`)

**Triggers**:
- Pull requests to `main` or `develop`
- Push to `develop` branch
- Path filter: `services/cliente-core/**`

**Steps**:
```yaml
1. Checkout code
2. Set up JDK 21
3. Cache Maven dependencies
4. Run tests: mvn clean test
5. Generate coverage: jacoco:report
6. Upload coverage to Codecov (optional)
7. Build Docker image (no push)
8. Report status
```

**Duration**: ~2 minutes

### Deploy Production Workflow (`deploy-production.yml`)

**Triggers**:
- Push to `main` branch
- Path filter: `services/cliente-core/**`

**Steps**:
```yaml
1. Checkout code
2. Configure AWS credentials
3. Login to Amazon ECR
4. Set up JDK 21
5. Build JAR: mvn clean package -DskipTests
6. Build Docker image
7. Tag image:
   - <ecr-repo>:latest
   - <ecr-repo>:<commit-sha>
8. Push to ECR
9. Update ECS task definition (new image URI)
10. Deploy to ECS: force new deployment
11. Wait for deployment stability
```

**Duration**: ~5-8 minutes

### GitHub Secrets Required

```bash
AWS_ACCESS_KEY_ID          # IAM user access key
AWS_SECRET_ACCESS_KEY      # IAM user secret key
AWS_ACCOUNT_ID             # AWS account ID (12 digits)
AWS_REGION                 # sa-east-1
```

### Deployment Strategy

**Pattern**: Blue/Green deployment via ECS rolling update
- Desired count: 1
- New task starts → Health check passes → Old task drains → Old task terminates
- Rollback: Automatic if health checks fail

**Path-based filtering** (monorepo):
```yaml
on:
  push:
    paths:
      - 'services/cliente-core/**'
      - '.github/workflows/deploy-production.yml'
```
Only `cliente-core` changes trigger `cliente-core` deployment.

---

## Development Workflow

### Local Development

**Prerequisites**:
- Java 21 (Temurin or OpenJDK)
- Maven 3.9+
- Docker Desktop
- PostgreSQL 16 (or use Docker)

**Setup**:
```bash
# Clone repository
git clone <repo-url>
cd yukam-drighi

# Start PostgreSQL (Docker)
docker run -d \
  --name postgres-dev \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=vanessa_mudanca \
  -p 5432:5432 \
  postgres:16

# Create schema
psql -h localhost -U postgres -d vanessa_mudanca -c "CREATE SCHEMA cliente_core;"

# Run service
cd services/cliente-core
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

**Environment profiles**:
- `dev` - Local development (localhost PostgreSQL, disabled OAuth2)
- `test` - Automated tests (H2 in-memory)
- `prod` - Production (AWS RDS, OAuth2 enabled)

### Code Standards

**Java**:
- Google Java Style Guide
- Lombok for boilerplate reduction
- SLF4J for logging
- @Transactional for database operations

**REST API**:
- Versioning: `/v1/clientes/pf`
- DTOs for request/response (never expose entities)
- UUID for public IDs (never expose database IDs)
- Soft deletes (set `ativo=false`, `deleted_at`)

**Logging**:
```java
// Use structured logging
log.info("Creating cliente PF: cpf={}, name={}", cpf, nome);

// Use correlation IDs
MDC.put("correlationId", UUID.randomUUID().toString());
```

**Error Handling**:
```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(NotFoundException.class)
    public ResponseEntity<ErrorResponse> handleNotFound(NotFoundException ex) {
        return ResponseEntity.status(404).body(new ErrorResponse(ex.getMessage()));
    }
}
```

---

## Testing Strategy

### Current Strategy (MVP)

**Unit Tests Only** (245 tests, 80%+ coverage):
- `*Test.java` - JUnit 5 + Mockito
- Fast execution (~30 seconds)
- Mock all external dependencies
- Focus on business logic coverage

**Integration Tests** (REMOVED for MVP velocity):
- TestContainers PostgreSQL
- Full Spring context
- HTTP requests via RestAssured
- Removed to reduce complexity and CI time

### Running Tests

```bash
# All unit tests
mvn test

# Specific test class
mvn test -Dtest=CreateClientePFServiceTest

# With coverage report
mvn test jacoco:report
open target/site/jacoco/index.html

# Skip tests (for fast builds)
mvn package -DskipTests
```

### Test Structure

```java
@ExtendWith(MockitoExtension.class)
class CreateClientePFServiceTest {

    @Mock
    private ClientePFRepository repository;

    @InjectMocks
    private CreateClientePFService service;

    @Test
    void shouldCreateClientePF_WhenValidData() {
        // Given
        ClientePFRequestDTO request = new ClientePFRequestDTO("João", "12345678900");
        when(repository.save(any())).thenAnswer(i -> i.getArgument(0));

        // When
        ClientePFResponseDTO response = service.create(request);

        // Then
        assertThat(response.nome()).isEqualTo("João");
        verify(repository).save(any());
    }
}
```

---

## Deployment

### Environments

**Development** (local):
- Database: localhost:5432
- OAuth2: Disabled or local Keycloak
- Logs: Console

**Production** (AWS):
- Database: RDS PostgreSQL Multi-AZ (future)
- OAuth2: AWS Cognito
- Logs: CloudWatch Logs
- URL: `https://<alb-dns>/api/clientes`

### Manual Deployment

**Build JAR**:
```bash
cd services/cliente-core
mvn clean package -DskipTests
# JAR at: target/cliente-core-1.0.0.jar
```

**Build Docker Image**:
```bash
docker build -t cliente-core:latest .
```

**Push to ECR**:
```bash
aws ecr get-login-password --region sa-east-1 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.sa-east-1.amazonaws.com

docker tag cliente-core:latest \
  <account-id>.dkr.ecr.sa-east-1.amazonaws.com/cliente-core:latest

docker push <account-id>.dkr.ecr.sa-east-1.amazonaws.com/cliente-core:latest
```

**Deploy to ECS**:
```bash
aws ecs update-service \
  --cluster vanessa-mudanca-prod \
  --service cliente-core-service \
  --force-new-deployment \
  --region sa-east-1
```

### Rollback

**Option 1: Deploy previous image tag**:
```bash
# Update task definition to use previous image
aws ecs register-task-definition --cli-input-json file://previous-task-def.json
aws ecs update-service --task-definition <previous-revision>
```

**Option 2: GitHub Actions re-run**:
- Go to Actions tab
- Find successful previous deployment
- Click "Re-run jobs"

---

## Cost Optimization

### Current Costs (MVP - Estimated)

| Resource | Configuration | Monthly Cost |
|----------|--------------|--------------|
| ECS Fargate Spot | 3 services × 1 task × 0.25 vCPU × 0.5 GB | $30 |
| RDS db.t4g.micro | ARM Graviton, 20 GB gp3 | $15 |
| ALB | 1 shared ALB | $20 |
| VPC Endpoints | 4 Interface + 1 Gateway | $0 |
| CloudWatch Logs | 5 GB, 7-day retention | $2 |
| **TOTAL** | | **~$67/month** |

### Optimizations Applied

1. **Fargate Spot** - 70% discount vs on-demand
2. **ARM Graviton (db.t4g.micro)** - 20% cheaper than x86
3. **Shared ALB** - $20/month vs $60/month (3 ALBs)
4. **Shared RDS** - $15/month vs $45/month (3 RDS)
5. **VPC Endpoints** - $0 vs $32/month (NAT Gateway)
6. **Scale-to-zero** - 0 tasks off-hours (future)

### Auto-Scaling Schedule (Future)

```hcl
# Business hours: Mon-Fri 6am-10pm
resource "aws_appautoscaling_scheduled_action" "scale_up" {
  schedule             = "cron(0 6 ? * MON-FRI *)"
  scalable_dimension   = "ecs:service:DesiredCount"
  min_capacity         = 1
  max_capacity         = 3
}

# Off-hours: Mon-Fri 10pm-6am + Weekends
resource "aws_appautoscaling_scheduled_action" "scale_down" {
  schedule             = "cron(0 22 ? * MON-FRI *)"
  min_capacity         = 0  # Scale to zero
  max_capacity         = 1
}
```

**Savings**: Additional 40-60% reduction (~$40/month → ~$20/month)

---

## Quick Reference

### Common Commands

```bash
# Terraform
cd terraform && terraform plan
terraform apply -auto-approve

# Maven
mvn clean test                    # Run tests
mvn clean package -DskipTests     # Build JAR
mvn spring-boot:run              # Run locally

# Docker
docker build -t cliente-core .
docker run -p 8081:8081 cliente-core

# AWS CLI
aws ecs list-services --cluster vanessa-mudanca-prod
aws ecs describe-services --cluster <cluster> --services <service>
aws logs tail /ecs/cliente-core-prod --follow

# Git
git checkout -b feature/new-feature
git add . && git commit -m "feat: add new feature"
git push origin feature/new-feature
```

### Key Files

```
PROJECT_CONTEXT.md                                    # This file
README.md                                             # Project overview
terraform/main.tf                                     # Infrastructure root
services/cliente-core/src/main/resources/application.yml  # Spring config
.github/workflows/deploy-production.yml               # CI/CD pipeline
services/cliente-core/pom.xml                        # Maven dependencies
```

### URLs

- **ECS Console**: https://console.aws.amazon.com/ecs/v2/clusters
- **RDS Console**: https://console.aws.amazon.com/rds
- **CloudWatch Logs**: https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups
- **Cognito Console**: https://console.aws.amazon.com/cognito/v2/idp/user-pools

---

**Document Version**: 1.0
**Last Updated**: 2025-11-06
**Maintained By**: DevOps Team
