# Arquitetura Va Nessa Mudança - Microserviços na AWS

## Visão Geral

Arquitetura de microserviços otimizada para custo e escalabilidade, seguindo padrões de Cloud Native e AWS Well-Architected Framework.

## Princípios Arquiteturais

1. **Shared Infrastructure, Independent Deployments** - Recursos compartilhados (VPC, RDS, ALB) mas deploys independentes
2. **Cost Optimization First** - Escalonamento automático, Fargate Spot, recursos compartilhados
3. **Security by Design** - VPC Endpoints, OAuth2, segmentação de rede, secrets management
4. **Observability Built-in** - Logs estruturados, métricas, tracing distribuído

---

## Diagrama de Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet Gateway                         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              Application Load Balancer (Shared)              │
│  Rules:                                                      │
│  • /api/clientes/*  → Target Group: cliente-core            │
│  • /api/vendas/*    → Target Group: venda-core              │
│  • /api/storage/*   → Target Group: storage-core            │
│  • /health          → 200 OK (ALB healthcheck)              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│           ECS Cluster: vanessa-mudanca-prod                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ cliente-core │  │  venda-core  │  │ storage-core │      │
│  │   service    │  │   service    │  │   service    │      │
│  │  (1-3 tasks) │  │  (1-3 tasks) │  │  (1-3 tasks) │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         ↓                 ↓                 ↓                │
│  ┌──────────────────────────────────────────────────┐      │
│  │        Fargate Capacity Provider                  │      │
│  │  • Strategy: FARGATE_SPOT (70% discount)         │      │
│  │  • Fallback: FARGATE (on-demand)                 │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│        RDS PostgreSQL 16 (Multi-Schema Shared)               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Schema:    │  │   Schema:    │  │   Schema:    │      │
│  │ cliente_core │  │  venda_core  │  │ storage_core │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  Instance: db.t4g.micro (ARM Graviton, 20GB SSD)            │
└─────────────────────────────────────────────────────────────┘
```

---

## Componentes Principais

### 1. Networking (VPC)

**VPC CIDR:** `172.31.0.0/16` (Default VPC - MVP)
**Futuro:** Migrar para VPC customizada `10.0.0.0/16` (production)

**Subnets:**
- **Public Subnets** (ALB): `172.31.0.0/20`, `172.31.16.0/20`, `172.31.32.0/20` (3 AZs)
- **Private Subnets** (ECS): `172.31.48.0/20`, `172.31.64.0/20`, `172.31.80.0/20` (3 AZs)
- **Database Subnets** (RDS): `172.31.96.0/20`, `172.31.112.0/20` (2 AZs)

**VPC Endpoints (Interface):**
- `vpce-05f676b915814c313` - Secrets Manager
- `vpce-0b02970199c525ef3` - ECR API
- `vpce-07b6358984996c03e` - ECR DKR
- `vpce-0a5465721ba280feb` - CloudWatch Logs

**VPC Endpoints (Gateway):**
- `vpce-0cc1dfb50853fa4e7` - S3

**Benefício:** $0/mês (vs $32/mês NAT Gateway)

---

### 2. Compute (ECS Fargate)

**Cluster:** `cliente-core-prod-cluster` → `vanessa-mudanca-prod` (futuro)

**Services:**

| Service | vCPU | RAM | Min Tasks | Max Tasks | Auto-Scale Metric |
|---------|------|-----|-----------|-----------|-------------------|
| cliente-core | 0.25 | 0.5 GB | 0 | 3 | CPU > 70% |
| venda-core | 0.25 | 0.5 GB | 0 | 3 | CPU > 70% |
| storage-core | 0.25 | 0.5 GB | 0 | 3 | CPU > 70% |

**Capacity Provider Strategy:**
```terraform
capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  base              = 0
  weight            = 100  # 100% Spot (70% discount)
}

capacity_provider_strategy {
  capacity_provider = "FARGATE"
  base              = 0
  weight            = 0    # Fallback on-demand
}
```

**Auto-Scaling Schedule:**
- **Business Hours** (Segunda-Sexta 6h-22h): 1-3 tasks
- **Off-Hours** (Segunda-Sexta 22h-6h): 0 tasks (scale to zero)
- **Weekends**: 0 tasks (scale to zero)

**Economia:** 60% ($50/mês → $20/mês)

---

### 3. Load Balancer (ALB)

**ALB:** `vanessa-mudanca-alb` (shared)
**Listeners:**
- **HTTP:80** → Redirect to HTTPS
- **HTTPS:443** → Path-based routing

**Path-Based Routing Rules:**

```hcl
# Rule 1: Cliente Core
Path: /api/clientes/*
Target Group: cliente-core-tg (port 8081)
Health Check: GET /api/clientes/actuator/health

# Rule 2: Venda Core
Path: /api/vendas/*
Target Group: venda-core-tg (port 8082)
Health Check: GET /api/vendas/actuator/health

# Rule 3: Storage Core
Path: /api/storage/*
Target Group: storage-core-tg (port 8083)
Health Check: GET /api/storage/actuator/health

# Default Rule
Path: /*
Fixed Response: 404 Not Found
```

**Custo:** $20/mês (vs $60/mês com 3 ALBs separados)

---

### 4. Database (RDS PostgreSQL)

**Instance:** `vanessa-mudanca-rds`
**Engine:** PostgreSQL 16.7
**Class:** `db.t4g.micro` (ARM Graviton2 - 20% cheaper)
**Storage:** 20 GB gp3 SSD (autoscaling até 100 GB)
**Multi-AZ:** Disabled (MVP) → Enabled (Production)

**Multi-Schema Strategy:**

```sql
-- Schema per microservice
CREATE SCHEMA cliente_core AUTHORIZATION app_user;
CREATE SCHEMA venda_core AUTHORIZATION app_user;
CREATE SCHEMA storage_core AUTHORIZATION app_user;

-- User permissions (least privilege)
GRANT USAGE ON SCHEMA cliente_core TO cliente_core_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cliente_core TO cliente_core_user;
```

**Connection Strings:**
```properties
# cliente-core
spring.datasource.url=jdbc:postgresql://vanessa-mudanca-rds:5432/vanessa_mudanca?currentSchema=cliente_core

# venda-core
spring.datasource.url=jdbc:postgresql://vanessa-mudanca-rds:5432/vanessa_mudanca?currentSchema=venda_core
```

**Custo:** $15/mês (vs $45/mês com 3 RDS separados)

---

### 5. Security

**Authentication:** AWS Cognito User Pool
**Authorization:** OAuth2 + JWT
**Roles:**
- `ADMIN` - Full access
- `EMPLOYEE` - Read/Write operations
- `CUSTOMER` - Own data only (enforced by CustomerAccessValidator)
- `SERVICE` - Inter-service communication

**Secrets Management:** AWS Secrets Manager
- `vanessa/db-password` - RDS master password
- `vanessa/cognito-client-secret` - OAuth2 client credentials

**Network Security:**
- ALB Security Group: Allow 80/443 from 0.0.0.0/0
- ECS Security Group: Allow 8080-8099 from ALB SG only
- RDS Security Group: Allow 5432 from ECS SG only
- VPC Endpoints SG: Allow 443 from VPC CIDR

---

### 6. Observability

**Logs:** CloudWatch Logs
- `/ecs/cliente-core-prod` - Application logs (JSON structured)
- `/ecs/venda-core-prod` - Application logs
- `/aws/rds/vanessa-mudanca` - Database logs

**Metrics:** CloudWatch Metrics + Micrometer
- ECS CPU/Memory utilization
- ALB request count, latency, error rate
- RDS connections, CPU, storage

**Tracing:** AWS X-Ray (future)
- Distributed tracing across microservices
- Correlation ID propagation via headers

---

## CI/CD Strategy

### Monorepo com Deploy Independente

**Repository:** `va-nessa-mudanca/`

```
va-nessa-mudanca/
├── .github/workflows/
│   ├── deploy-cliente-core.yml      # Triggered on services/cliente-core/**
│   ├── deploy-venda-core.yml        # Triggered on services/venda-core/**
│   └── deploy-storage-core.yml      # Triggered on services/storage-core/**
├── services/
│   ├── cliente-core/
│   │   ├── Dockerfile
│   │   ├── pom.xml
│   │   └── src/
│   ├── venda-core/
│   └── storage-core/
└── infrastructure/
    └── terraform/
```

**GitHub Actions Path Filter:**

```yaml
name: Deploy Cliente Core

on:
  push:
    branches: [main]
    paths:
      - 'services/cliente-core/**'
      - '.github/workflows/deploy-cliente-core.yml'

jobs:
  deploy:
    steps:
      - Build JAR: mvn package -DskipTests
      - Build Docker: docker build -t cliente-core:${{ github.sha }}
      - Push to ECR: 530184476864.dkr.ecr.sa-east-1.amazonaws.com/cliente-core
      - Deploy to ECS: aws ecs update-service --force-new-deployment
```

**Benefício:** Deploy de 1 MS não rebuida/redeploya os outros

---

## Estimativa de Custos (Mensal)

### MVP (Current)

| Recurso | Configuração | Custo/mês |
|---------|-------------|-----------|
| **ECS Fargate** | 3 services × 1 task × 0.25 vCPU × 0.5 GB RAM | $30 |
| **RDS PostgreSQL** | db.t4g.micro (ARM) + 20 GB gp3 | $15 |
| **ALB** | 1 ALB compartilhado | $20 |
| **VPC Endpoints** | 4 Interface + 1 Gateway | $0 |
| **CloudWatch Logs** | 5 GB retention 7 days | $2 |
| **Secrets Manager** | 2 secrets | $1 |
| **ECR** | 3 repositórios × 500 MB | $0.15 |
| **Data Transfer** | 10 GB OUT | $1 |
| **TOTAL** | | **~$69/mês** |

### Otimizado (Com Auto-Scaling + Spot)

| Recurso | Configuração | Custo/mês |
|---------|-------------|-----------|
| **ECS Fargate Spot** | 3 services × 0.6 tasks avg (scale-to-zero) × Spot 70% off | $9 |
| **RDS PostgreSQL** | db.t4g.micro (ARM) + 20 GB gp3 | $15 |
| **ALB** | 1 ALB compartilhado | $20 |
| **VPC Endpoints** | 4 Interface + 1 Gateway | $0 |
| **CloudWatch Logs** | 5 GB retention 7 days | $2 |
| **Secrets Manager** | 2 secrets | $1 |
| **ECR** | 3 repositórios × 500 MB | $0.15 |
| **Data Transfer** | 10 GB OUT | $1 |
| **TOTAL** | | **~$48/mês** |

**Economia:** 30% ($69 → $48)

### Production (Futuro)

| Recurso | Configuração | Custo/mês |
|---------|-------------|-----------|
| **ECS Fargate** | 5 services × 2 tasks × 0.5 vCPU × 1 GB RAM (HA) | $120 |
| **RDS Multi-AZ** | db.t4g.small × 2 AZs + 100 GB gp3 | $60 |
| **ALB** | 1 ALB compartilhado | $20 |
| **NAT Gateway** | 2 AZs (HA) | $64 |
| **CloudWatch Logs** | 20 GB retention 30 days | $10 |
| **Secrets Manager** | 5 secrets | $2 |
| **ECR** | 5 repositórios × 1 GB | $0.50 |
| **Data Transfer** | 100 GB OUT | $9 |
| **TOTAL** | | **~$285/mês** |

---

## Migração para Produção

### Checklist

- [ ] **VPC Customizada** - Migrar de Default VPC para VPC dedicada (10.0.0.0/16)
- [ ] **Multi-AZ RDS** - Habilitar standby replica (HA)
- [ ] **ECS Auto-Scaling** - CPU/Memory-based scaling (não apenas schedule)
- [ ] **ALB SSL Certificate** - ACM certificate para HTTPS
- [ ] **Route 53** - DNS customizado (api.vanessamudanca.com.br)
- [ ] **WAF** - Web Application Firewall (proteção DDoS, SQL injection)
- [ ] **CloudFront** - CDN para assets estáticos
- [ ] **Backup Strategy** - RDS automated backups + snapshots
- [ ] **Disaster Recovery** - Cross-region replication (opcional)

---

## Links Úteis

- **AWS Console ECS:** https://console.aws.amazon.com/ecs/v2/clusters
- **AWS Console RDS:** https://console.aws.amazon.com/rds
- **AWS Cost Explorer:** https://console.aws.amazon.com/cost-management
- **Terraform Registry:** https://registry.terraform.io/providers/hashicorp/aws

---

**Última atualização:** 2025-11-05
**Versão:** 1.0
**Autor:** Va Nessa Mudança DevOps Team
