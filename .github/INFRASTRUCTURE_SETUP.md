# Infraestrutura AWS - Setup para CI/CD

Guia completo para provisionar a infraestrutura AWS necessária para os deploys automatizados.

---

## 🏗️ Arquitetura Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      GitHub Actions                          │
│  (Push to main → Trigger Deploy Workflow)                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  Amazon ECR (Container Registry)             │
│  • cliente-core:latest                                       │
│  • vendas-core:latest                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  Amazon ECS (Fargate)                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Cluster: vanessa-mudanca-cluster                     │  │
│  │                                                        │  │
│  │  ┌────────────────────┐  ┌────────────────────┐      │  │
│  │  │ Service:           │  │ Service:           │      │  │
│  │  │ cliente-core       │  │ vendas-core        │      │  │
│  │  │ - 2 tasks (min)    │  │ - 2 tasks (min)    │      │  │
│  │  │ - Auto-scaling     │  │ - Auto-scaling     │      │  │
│  │  └────────────────────┘  └────────────────────┘      │  │
│  └───────────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│          Application Load Balancer (ALB)                     │
│  • Health checks: /actuator/health                           │
│  • Target Groups por serviço                                 │
│  • SSL/TLS termination (ACM)                                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  Route 53 (DNS)                              │
│  • api.vanessamudanca.com.br → ALB                           │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Recursos AWS Necessários

### Core Resources

| Recurso | Quantidade | Propósito |
|---------|-----------|-----------|
| VPC | 1 | Rede isolada |
| Subnets (Public) | 2 | Multi-AZ para alta disponibilidade |
| Subnets (Private) | 2 | Tasks ECS isoladas |
| Internet Gateway | 1 | Acesso internet para ALB |
| NAT Gateway | 2 | Acesso internet para tasks privadas |
| Security Groups | 3 | Firewall (ALB, ECS, RDS) |
| ECR Repositories | 2+ | Registro de imagens Docker |
| ECS Cluster | 1 | Cluster Fargate |
| ECS Services | 2+ | Um por microserviço |
| Application Load Balancer | 1 | Distribuição de tráfego |
| Target Groups | 2+ | Um por microserviço |
| CloudWatch Log Groups | 2+ | Logs estruturados |
| RDS PostgreSQL | 1 | Banco de dados compartilhado |

### Custos Estimados (sa-east-1)

| Recurso | Tipo | Custo Mensal (USD) |
|---------|------|-------------------|
| ECS Fargate (2 tasks) | 0.5 vCPU, 1GB RAM | ~$30 |
| ALB | Standard | ~$25 |
| NAT Gateway (2) | Standard | ~$90 |
| RDS PostgreSQL | db.t4g.micro | ~$20 |
| ECR Storage | < 1GB | ~$1 |
| CloudWatch Logs | < 5GB | ~$3 |
| **TOTAL ESTIMADO** | | **~$170/mês** |

**Otimizações:**
- 💡 Use 1 NAT Gateway (single AZ) para dev: economize ~$45/mês
- 💡 Use RDS Aurora Serverless para dev: pague apenas quando usar
- 💡 Configure auto-scaling para escalar para 0 tasks fora do horário comercial

---

## 🚀 Setup Rápido com Terraform

### Opção 1: Terraform Modules (Recomendado)

Vou criar módulos Terraform reutilizáveis para provisionar toda a infra:

```bash
cd terraform/shared

# Inicializar Terraform
terraform init

# Ver o que será criado
terraform plan

# Aplicar mudanças
terraform apply
```

### Opção 2: Console AWS (Manual)

Se preferir criar manualmente via console (não recomendado para produção):

---

## 📦 Passo 1: Criar ECR Repositories

```bash
# Configurar AWS CLI
aws configure

# Criar repositório para cliente-core
aws ecr create-repository \
  --repository-name cliente-core \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --region sa-east-1

# Criar repositório para vendas-core
aws ecr create-repository \
  --repository-name vendas-core \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --region sa-east-1

# Ver repositórios criados
aws ecr describe-repositories --region sa-east-1
```

**Resultado esperado:**
```json
{
  "repositoryUri": "123456789012.dkr.ecr.sa-east-1.amazonaws.com/cliente-core",
  "registryId": "123456789012",
  "repositoryName": "cliente-core"
}
```

---

## 🌐 Passo 2: Criar VPC e Networking

### Via Terraform (recomendado)

```hcl
# terraform/modules/networking/main.tf
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"

  name = "vanessa-mudanca-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["sa-east-1a", "sa-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false  # true para dev (economizar)
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "production"
    Project     = "va-nessa-mudanca"
  }
}
```

### Via Console AWS

1. VPC Dashboard → **Create VPC**
2. **VPC settings:**
   - Name: `vanessa-mudanca-vpc`
   - IPv4 CIDR: `10.0.0.0/16`
   - Tenancy: Default
3. **Create subnets:**
   - Public Subnet 1: `10.0.101.0/24` (sa-east-1a)
   - Public Subnet 2: `10.0.102.0/24` (sa-east-1b)
   - Private Subnet 1: `10.0.1.0/24` (sa-east-1a)
   - Private Subnet 2: `10.0.2.0/24` (sa-east-1b)
4. **Create Internet Gateway** e attach à VPC
5. **Create NAT Gateways** (1 por AZ) nas subnets públicas
6. **Configure Route Tables:**
   - Public: `0.0.0.0/0` → Internet Gateway
   - Private: `0.0.0.0/0` → NAT Gateway

---

## 🛡️ Passo 3: Criar Security Groups

```bash
# Security Group para ALB (público)
aws ec2 create-security-group \
  --group-name vanessa-alb-sg \
  --description "Security group for ALB" \
  --vpc-id vpc-xxxxxxxx \
  --region sa-east-1

ALB_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=vanessa-alb-sg" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

# Permitir HTTP e HTTPS de qualquer lugar
aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# Security Group para ECS Tasks
aws ec2 create-security-group \
  --group-name vanessa-ecs-tasks-sg \
  --description "Security group for ECS tasks" \
  --vpc-id vpc-xxxxxxxx \
  --region sa-east-1

ECS_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=vanessa-ecs-tasks-sg" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

# Permitir tráfego do ALB
aws ec2 authorize-security-group-ingress \
  --group-id $ECS_SG_ID \
  --protocol tcp \
  --port 8081 \
  --source-group $ALB_SG_ID

aws ec2 authorize-security-group-ingress \
  --group-id $ECS_SG_ID \
  --protocol tcp \
  --port 8082 \
  --source-group $ALB_SG_ID
```

---

## 🐳 Passo 4: Criar ECS Cluster

```bash
# Criar cluster Fargate
aws ecs create-cluster \
  --cluster-name vanessa-mudanca-cluster \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy \
    capacityProvider=FARGATE,weight=1,base=1 \
    capacityProvider=FARGATE_SPOT,weight=1 \
  --region sa-east-1

# Habilitar Container Insights (monitoramento)
aws ecs put-cluster-capacity-providers \
  --cluster vanessa-mudanca-cluster \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy \
    capacityProvider=FARGATE,weight=1,base=1 \
    capacityProvider=FARGATE_SPOT,weight=1
```

---

## 📝 Passo 5: Criar IAM Roles

### Task Execution Role (para ECS puxar imagens e logs)

```bash
# Criar role
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'

# Attach managed policy
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Adicionar permissões ECR
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

### Task Role (para aplicação acessar AWS services)

```bash
# Criar role
aws iam create-role \
  --role-name clienteCoreTaskRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'

# Criar policy customizada (S3, Secrets Manager, etc.)
aws iam put-role-policy \
  --role-name clienteCoreTaskRole \
  --policy-name ClienteCoreAppPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue",
          "s3:GetObject",
          "s3:PutObject"
        ],
        "Resource": [
          "arn:aws:secretsmanager:sa-east-1:*:secret:vanessa/*",
          "arn:aws:s3:::vanessa-mudanca-documents/*"
        ]
      }
    ]
  }'
```

---

## 🎯 Passo 6: Criar Application Load Balancer

```bash
# Criar ALB
aws elbv2 create-load-balancer \
  --name vanessa-mudanca-alb \
  --subnets subnet-public1 subnet-public2 \
  --security-groups $ALB_SG_ID \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --region sa-east-1

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names vanessa-mudanca-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

# Criar Target Group para cliente-core
aws elbv2 create-target-group \
  --name cliente-core-tg \
  --protocol HTTP \
  --port 8081 \
  --vpc-id vpc-xxxxxxxx \
  --target-type ip \
  --health-check-enabled \
  --health-check-protocol HTTP \
  --health-check-path /api/clientes/actuator/health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --matcher HttpCode=200 \
  --region sa-east-1

TG_ARN=$(aws elbv2 describe-target-groups \
  --names cliente-core-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Criar Listener HTTP
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --region sa-east-1
```

---

## 🗄️ Passo 7: Criar RDS PostgreSQL

```bash
# Criar DB Subnet Group
aws rds create-db-subnet-group \
  --db-subnet-group-name vanessa-db-subnet-group \
  --db-subnet-group-description "Subnet group for RDS" \
  --subnet-ids subnet-private1 subnet-private2 \
  --region sa-east-1

# Security Group para RDS
aws ec2 create-security-group \
  --group-name vanessa-rds-sg \
  --description "Security group for RDS" \
  --vpc-id vpc-xxxxxxxx

RDS_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=vanessa-rds-sg" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

# Permitir PostgreSQL do ECS
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID \
  --protocol tcp \
  --port 5432 \
  --source-group $ECS_SG_ID

# Criar RDS Instance
aws rds create-db-instance \
  --db-instance-identifier vanessa-mudanca-db \
  --db-instance-class db.t4g.micro \
  --engine postgres \
  --engine-version 15.4 \
  --master-username postgres \
  --master-user-password 'CHANGE_ME_STRONG_PASSWORD' \
  --allocated-storage 20 \
  --storage-type gp3 \
  --vpc-security-group-ids $RDS_SG_ID \
  --db-subnet-group-name vanessa-db-subnet-group \
  --backup-retention-period 7 \
  --preferred-backup-window "03:00-04:00" \
  --preferred-maintenance-window "mon:04:00-mon:05:00" \
  --multi-az \
  --publicly-accessible false \
  --region sa-east-1
```

---

## 📊 Passo 8: Criar CloudWatch Log Groups

```bash
# Log group para cliente-core
aws logs create-log-group \
  --log-group-name /ecs/cliente-core \
  --region sa-east-1

# Configurar retention (30 dias)
aws logs put-retention-policy \
  --log-group-name /ecs/cliente-core \
  --retention-in-days 30

# Log group para vendas-core
aws logs create-log-group \
  --log-group-name /ecs/vendas-core \
  --region sa-east-1

aws logs put-retention-policy \
  --log-group-name /ecs/vendas-core \
  --retention-in-days 30
```

---

## 🚀 Passo 9: Criar ECS Task Definition

Salve este JSON em `task-definition-cliente-core.json`:

```json
{
  "family": "cliente-core",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::ACCOUNT_ID:role/clienteCoreTaskRole",
  "containerDefinitions": [
    {
      "name": "cliente-core",
      "image": "ACCOUNT_ID.dkr.ecr.sa-east-1.amazonaws.com/cliente-core:latest",
      "cpu": 512,
      "memory": 1024,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8081,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "SPRING_PROFILES_ACTIVE",
          "value": "prod"
        },
        {
          "name": "SPRING_DATASOURCE_URL",
          "value": "jdbc:postgresql://vanessa-mudanca-db.xxxxxxxxxx.sa-east-1.rds.amazonaws.com:5432/clientes"
        }
      ],
      "secrets": [
        {
          "name": "SPRING_DATASOURCE_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:sa-east-1:ACCOUNT_ID:secret:vanessa/db-password"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/cliente-core",
          "awslogs-region": "sa-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:8081/api/clientes/actuator/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

Registrar task definition:

```bash
aws ecs register-task-definition \
  --cli-input-json file://task-definition-cliente-core.json \
  --region sa-east-1
```

---

## 🎯 Passo 10: Criar ECS Service

```bash
aws ecs create-service \
  --cluster vanessa-mudanca-cluster \
  --service-name cliente-core-service \
  --task-definition cliente-core \
  --desired-count 2 \
  --launch-type FARGATE \
  --platform-version LATEST \
  --network-configuration "awsvpcConfiguration={
    subnets=[subnet-private1,subnet-private2],
    securityGroups=[$ECS_SG_ID],
    assignPublicIp=DISABLED
  }" \
  --load-balancers "targetGroupArn=$TG_ARN,containerName=cliente-core,containerPort=8081" \
  --health-check-grace-period-seconds 60 \
  --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
  --region sa-east-1
```

---

## ✅ Passo 11: Verificar Deployment

```bash
# Ver status do serviço
aws ecs describe-services \
  --cluster vanessa-mudanca-cluster \
  --services cliente-core-service \
  --region sa-east-1

# Ver tasks rodando
aws ecs list-tasks \
  --cluster vanessa-mudanca-cluster \
  --service-name cliente-core-service \
  --region sa-east-1

# Ver Target Health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region sa-east-1

# Obter DNS do ALB
aws elbv2 describe-load-balancers \
  --names vanessa-mudanca-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

**Testar endpoint:**

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names vanessa-mudanca-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

curl http://$ALB_DNS/api/clientes/actuator/health
```

---

## 🔧 Próximos Passos

1. **Configurar Auto Scaling:**
   - Target Tracking (CPU/Memory)
   - Step Scaling (para picos de tráfego)

2. **Configurar SSL/TLS:**
   - Request certificate no ACM
   - Adicionar Listener HTTPS no ALB
   - Redirect HTTP → HTTPS

3. **Configurar Route 53:**
   - Criar Hosted Zone
   - Criar Record `api.vanessamudanca.com.br` → ALB

4. **Configurar Secrets Manager:**
   - Migrar senhas do RDS para Secrets Manager
   - Rotação automática de credentials

5. **Configurar CloudWatch Alarms:**
   - High CPU/Memory
   - Target Health
   - ECS Service failures

---

## 📚 Referências

- [ECS Fargate Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [ALB Target Groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
- [RDS PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [Terraform AWS Modules](https://registry.terraform.io/modules/terraform-aws-modules/)

---

**Última atualização:** 2025-11-05
**Versão:** 1.0.0
