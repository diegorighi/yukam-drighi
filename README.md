# Yukam/VaNessa Mudança - Monorepo

Monorepo containing all microservices and shared infrastructure for the VaNessa Mudança platform.

---

## Quick Navigation

### For AI/LLM Context
→ **[PROJECT_CONTEXT.md](PROJECT_CONTEXT.md)** - Complete technical documentation for LLMs

### For Developers
→ **[services/cliente-core/](services/cliente-core/)** - Customer management microservice
→ **[docs/](docs/)** - Technical documentation
→ **[terraform/](terraform/)** - Infrastructure as Code
→ **[scripts/](scripts/)** - Utility scripts

---

## Architecture Overview

```
Microservices Platform on AWS ECS Fargate
├── cliente-core (port 8081) - Customer management (PF/PJ)
├── venda-core (port 8082) - Sales management [Planned]
└── storage-core (port 8083) - Inventory management [Planned]

Shared Infrastructure:
├── RDS PostgreSQL 16 (Multi-Schema)
├── Application Load Balancer (path-based routing)
├── AWS Cognito (OAuth2 authentication)
└── VPC with Endpoints (no NAT Gateway)
```

**Key principles:**
- Shared infrastructure, independent deployments
- Cost optimization first (Fargate Spot, ARM Graviton, scale-to-zero)
- OAuth2 JWT authentication
- Automated CI/CD via GitHub Actions

---

## Local Development

### Quick Start

```bash
# 1. Clone with submodules
git clone --recurse-submodules <repo-url>
cd yukam-drighi

# 2. Start working on a microservice
cd services/cliente-core

# 3. Run locally
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

### Prerequisites
- Java 21 (Temurin or OpenJDK)
- Maven 3.9+
- Docker Desktop
- PostgreSQL 16 (or use Docker)

---

## Infrastructure

### Terraform Structure

```
terraform/
├── main.tf              # Root module (orchestrates everything)
├── shared/              # VPC, RDS, ALB, Cognito (provisioned once)
└── modules/
    └── ecs-service/     # Reusable ECS service module
```

### Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Add New Microservice

```hcl
# In terraform/main.tf
module "new_service" {
  source = "./modules/ecs-service"
  service_name = "new-service"
  alb_arn = module.shared.alb_arn
  db_host = module.shared.rds_endpoint
}
```

---

## CI/CD

### Automated Deployment

Push to `main` branch triggers automated deployment to AWS ECS:

```yaml
1. Build JAR (mvn package)
2. Build Docker image
3. Push to Amazon ECR
4. Update ECS task definition
5. Deploy to ECS Fargate
6. Health check validation
```

**Workflows:**
- `.github/workflows/ci.yml` - PR validation (tests, coverage)
- `.github/workflows/deploy-production.yml` - Production deployment

**Path filtering:** Only changed services are deployed (monorepo pattern).

### Required GitHub Secrets

```bash
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_ACCOUNT_ID
AWS_REGION=sa-east-1
```

---

## Testing

### Run Tests

```bash
cd services/cliente-core

# Unit tests
mvn test

# With coverage
mvn test jacoco:report
open target/site/jacoco/index.html

# Build without tests
mvn package -DskipTests
```

**Current strategy (MVP):**
- 245 unit tests (80%+ coverage)
- Integration tests removed for velocity
- Fast CI builds (~2 minutes)

---

## Authentication (OAuth2)

### Get Credentials

```bash
# Automated script
./scripts/get-cognito-credentials.sh

# Manual via AWS CLI
aws cognito-idp list-user-pools --max-results 10
aws cognito-idp describe-user-pool-client --user-pool-id <id> --client-id <id>
```

### Get Access Token

```bash
# Using script
./scripts/get-jwt-token.sh

# Using cURL
curl -X POST https://<cognito-domain>/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "CLIENT_ID:CLIENT_SECRET" \
  -d "grant_type=client_credentials&scope=cliente-core/read cliente-core/write"
```

### Use Token

```bash
TOKEN="<jwt-from-above>"
curl -X GET <alb-url>/api/clientes/v1/clientes/pf \
  -H "Authorization: Bearer $TOKEN"
```

---

## Documentation

### Technical Documentation

- **[PROJECT_CONTEXT.md](PROJECT_CONTEXT.md)** - Complete project context for LLMs
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System architecture details
- **[docs/CI_CD_IMPLEMENTATION_GUIDE.md](docs/CI_CD_IMPLEMENTATION_GUIDE.md)** - CI/CD setup guide
- **[docs/COST_OPTIMIZATION.md](docs/COST_OPTIMIZATION.md)** - Cost optimization strategies

### Service Documentation

- **[services/cliente-core/README.md](services/cliente-core/README.md)** - Cliente Core service
- **[services/cliente-core/CLAUDE.md](services/cliente-core/CLAUDE.md)** - Development guidelines

---

## Cost Optimization

**Current monthly cost:** ~$67
**Optimized cost:** ~$48 (with scale-to-zero)

**Optimizations applied:**
- Fargate Spot (70% discount)
- ARM Graviton instances (20% cheaper)
- Shared ALB ($20 vs $60 for 3 ALBs)
- Shared RDS ($15 vs $45 for 3 RDS)
- VPC Endpoints ($0 vs $32 NAT Gateway)

---

## Project Structure

```
yukam-drighi/
├── PROJECT_CONTEXT.md                 # LLM context documentation
├── README.md                          # This file
├── .github/workflows/                 # CI/CD pipelines
├── services/                          # Microservices (git submodules)
│   └── cliente-core/                 # Customer management service
├── terraform/                         # Infrastructure as Code
│   ├── main.tf                       # Root module
│   ├── shared/                       # Shared resources (VPC, RDS, ALB)
│   └── modules/ecs-service/          # Reusable ECS service module
├── docs/                             # Technical documentation
└── scripts/                          # Utility scripts
```

---

## Common Commands

```bash
# Terraform
cd terraform && terraform apply

# Local development
cd services/cliente-core && mvn spring-boot:run

# Run tests
mvn test

# Deploy (automated via GitHub Actions)
git push origin main

# View logs
aws logs tail /ecs/cliente-core-prod --follow

# Get Cognito credentials
./scripts/get-cognito-credentials.sh
```

---

## Support

For questions or issues:
1. Check **[PROJECT_CONTEXT.md](PROJECT_CONTEXT.md)** for technical details
2. Review service-specific README in `services/<service-name>/`
3. Check CloudWatch Logs for runtime issues
4. Review GitHub Actions for deployment issues

---

**Last Updated:** 2025-11-06
**Version:** 2.0.0
