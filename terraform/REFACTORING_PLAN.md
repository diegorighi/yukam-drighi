# 🔄 Terraform Refactoring Plan - Shared vs Services

## 📋 Objetivo

Reorganizar a infraestrutura Terraform para separar:
- **Recursos compartilhados** (VPC, ALB, IAM base, Cognito) → `terraform/shared/`
- **Recursos por microserviço** (ECS, RDS, Target Groups) → `terraform/services/cliente-core/`

Isso facilita governança futura quando tivermos múltiplos squads gerenciando seus próprios microserviços.

---

## 🎯 Arquitetura Alvo

```
terraform/
├── shared/                          # Infraestrutura compartilhada (DevOps)
│   ├── vpc.tf                       # VPC + Subnets + NAT Gateway
│   ├── alb.tf                       # ALB + HTTP/HTTPS Listener
│   ├── iam.tf                       # ecsTaskExecutionRole base
│   ├── cognito.tf                   # ✅ Cognito (já existe)
│   ├── ecs_cluster.tf              # ECS Cluster compartilhado
│   ├── provider.tf
│   ├── variables.tf
│   ├── backend.tf                   # S3 state: terraform-state-shared
│   └── outputs.tf                   # vpc_id, alb_arn, subnet_ids, etc
│
└── services/                        # Infraestrutura por MS (Squads)
    └── cliente-core/
        ├── data.tf                  # Data sources (referencia outputs do shared)
        ├── target_group.tf          # Target Group cliente-core
        ├── listener_rules.tf        # ALB path rules /api/clientes/*
        ├── ecs.tf                   # Task Definition + Service + Auto Scaling
        ├── rds.tf                   # PostgreSQL RDS
        ├── secrets.tf               # Secrets Manager (DB credentials)
        ├── security_groups.tf       # Security Group ECS tasks
        ├── iam_task_role.tf         # IAM Task Role com permissões específicas
        ├── cloudwatch.tf            # CloudWatch Logs + Alarms
        ├── provider.tf
        ├── variables.tf
        ├── backend.tf               # S3 state: terraform-state-cliente-core
        └── outputs.tf
```

---

## 📦 Mapeamento de Recursos

### ✅ `terraform/shared/` (Infraestrutura Base)

| Recurso Atual (terraform/ecs/main.tf) | Novo Local | Status |
|----------------------------------------|------------|--------|
| `aws_vpc.*` (não existe ainda) | `shared/vpc.tf` | ⏳ Criar novo |
| `aws_subnet.*` (referenciado via var) | `shared/vpc.tf` | ⏳ Import existente |
| `aws_internet_gateway.*` | `shared/vpc.tf` | ⏳ Import existente |
| `aws_nat_gateway.*` | `shared/vpc.tf` | ⏳ Import existente |
| `aws_lb.main` | `shared/alb.tf` | ⏳ Mover + Import |
| `aws_security_group.alb` | `shared/alb.tf` | ⏳ Mover + Import |
| `aws_lb_listener.http` | `shared/alb.tf` | ⏳ Mover + Import |
| `aws_iam_role.ecs_task_execution` | `shared/iam.tf` | ⏳ Criar novo |
| `aws_iam_role_policy.ecs_task_execution_secrets` | `shared/iam.tf` | ⏳ Mover + Import |
| `aws_ecs_cluster.main` | `shared/ecs_cluster.tf` | ⏳ Mover + Import |
| `aws_cognito_*` | `shared/cognito.tf` | ✅ **Já existe!** |

### ✅ `terraform/services/cliente-core/` (Recursos do MS)

| Recurso Atual (terraform/ecs/main.tf) | Novo Local | Status |
|----------------------------------------|------------|--------|
| `aws_lb_target_group.cliente_core` | `services/cliente-core/target_group.tf` | ⏳ Mover |
| `aws_lb_listener_rule.*` (não existe) | `services/cliente-core/listener_rules.tf` | ⏳ Criar |
| `aws_ecs_task_definition.cliente_core` | `services/cliente-core/ecs.tf` | ⏳ Mover |
| `aws_ecs_service.cliente_core` | `services/cliente-core/ecs.tf` | ⏳ Mover |
| `aws_appautoscaling_*` | `services/cliente-core/ecs.tf` | ⏳ Mover |
| `aws_security_group.ecs_tasks` | `services/cliente-core/security_groups.tf` | ⏳ Mover |
| `aws_iam_role.cliente_core_task` | `services/cliente-core/iam_task_role.tf` | ⏳ Mover |
| `aws_iam_role_policy.cliente_core_task` | `services/cliente-core/iam_task_role.tf` | ⏳ Mover |
| `aws_db_instance.*` (não existe no TF) | `services/cliente-core/rds.tf` | ⏳ Import existente |
| `aws_secretsmanager_secret.db_password` | `services/cliente-core/secrets.tf` | ⏳ Import existente |
| `aws_cloudwatch_log_group.cliente_core` | `services/cliente-core/cloudwatch.tf` | ⏳ Mover |

---

## 🔗 Comunicação Entre Módulos

### Shared → Services (via Data Source)

```hcl
# services/cliente-core/data.tf
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "va-nessa-mudanca-terraform-state"
    key    = "shared/terraform.tfstate"
    region = "sa-east-1"
  }
}

# Uso nos resources:
resource "aws_ecs_service" "cliente_core" {
  load_balancer {
    target_group_arn = aws_lb_target_group.cliente_core.arn
    # ALB vem do shared via data source
  }

  network_configuration {
    subnets = data.terraform_remote_state.shared.outputs.private_subnet_ids
    security_groups = [aws_security_group.ecs_tasks.id]
  }
}
```

---

## 📝 Plano de Execução (Fase 1 - Descoberta)

### ✅ Etapa 1: Inventariar Recursos AWS Existentes

```bash
# VPC e Networking
aws ec2 describe-vpcs --region sa-east-1 --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]'
aws ec2 describe-subnets --region sa-east-1 --filters "Name=tag:Project,Values=va-nessa-mudanca"
aws ec2 describe-internet-gateways --region sa-east-1
aws ec2 describe-nat-gateways --region sa-east-1

# ALB (já sabemos que existe: vanessa-mudanca-alb)
aws elbv2 describe-load-balancers --region sa-east-1 --names vanessa-mudanca-alb

# IAM Roles
aws iam get-role --role-name ecsTaskExecutionRole
aws iam get-role --role-name clienteCoreTaskRole

# RDS
aws rds describe-db-instances --region sa-east-1 --db-instance-identifier cliente-core-prod

# Secrets Manager
aws secretsmanager list-secrets --region sa-east-1 --filters Key=name,Values=cliente-core/prod/database
```

### ✅ Etapa 2: Criar Estrutura de Diretórios

```bash
cd /Users/diegorighi/Desenvolvimento/yukam-drighi/terraform

# Criar nova estrutura
mkdir -p services/cliente-core

# Mover ecs/ para services/cliente-core/ (backup primeiro)
cp -r ecs/ ecs-backup/
```

### ✅ Etapa 3: Extrair Recursos Compartilhados

1. Ler `terraform/ecs/main.tf` e identificar recursos compartilhados
2. Criar arquivos em `shared/`:
   - `vpc.tf` - Definir VPC baseado no que existe na AWS
   - `alb.tf` - Mover ALB + Listener do main.tf
   - `iam.tf` - Criar ecsTaskExecutionRole base
   - `ecs_cluster.tf` - Mover ECS Cluster

### ✅ Etapa 4: Mover Recursos do Cliente-Core

1. Mover do `ecs/main.tf` para `services/cliente-core/`:
   - Target Group → `target_group.tf`
   - Task Definition + Service → `ecs.tf`
   - Auto Scaling → `ecs.tf`
   - Security Groups → `security_groups.tf`
   - IAM Task Role → `iam_task_role.tf`
   - CloudWatch Logs → `cloudwatch.tf`

2. Criar novos recursos:
   - `rds.tf` - Importar RDS existente
   - `secrets.tf` - Importar Secrets Manager
   - `listener_rules.tf` - Criar path rules para /api/clientes/*

### ✅ Etapa 5: Configurar Remote State S3

```bash
# Criar buckets S3 para state
aws s3 mb s3://va-nessa-mudanca-terraform-state --region sa-east-1

# Habilitar versionamento
aws s3api put-bucket-versioning \
  --bucket va-nessa-mudanca-terraform-state \
  --versioning-configuration Status=Enabled

# Criar DynamoDB table para lock
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region sa-east-1
```

### ✅ Etapa 6: Import de Recursos Existentes

```bash
cd terraform/shared
terraform init
terraform import aws_lb.main <alb-arn>
terraform import aws_security_group.alb <sg-id>
# ... (continuar para todos os recursos)

cd ../services/cliente-core
terraform init
terraform import aws_ecs_service.cliente_core cliente-core-prod-cluster/cliente-core-prod-service
# ... (continuar para todos os recursos)
```

### ✅ Etapa 7: Validação

```bash
cd terraform/shared
terraform plan  # Deve mostrar "No changes"

cd ../services/cliente-core
terraform plan  # Deve mostrar "No changes"
```

---

## ⚠️ Riscos e Mitigações

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| Quebrar produção durante migração | 🔴 Alto | Fazer imports sem destroy, validar plan antes de apply |
| Perder estado do Terraform | 🔴 Alto | Backup do .tfstate antes de migrar |
| Dependências circulares entre módulos | 🟡 Médio | Usar data sources e outputs, não references diretas |
| Conflito de nomes de recursos | 🟡 Médio | Manter nomes idênticos durante import |
| Drift entre Terraform e AWS | 🟡 Médio | Rodar terraform refresh antes de import |

---

## 📅 Cronograma Sugerido

| Fase | Descrição | Duração | Status |
|------|-----------|---------|--------|
| 1 | Inventário e planejamento | 2h | ⏳ Em andamento |
| 2 | Criar estrutura shared/ | 1h | ⏳ Pendente |
| 3 | Import recursos compartilhados | 2h | ⏳ Pendente |
| 4 | Criar estrutura services/cliente-core/ | 1h | ⏳ Pendente |
| 5 | Import recursos cliente-core | 2h | ⏳ Pendente |
| 6 | Testes e validação | 2h | ⏳ Pendente |
| 7 | Migrar state para S3 remote | 1h | ⏳ Pendente |
| 8 | Documentação final | 1h | ⏳ Pendente |

**Total estimado:** ~12 horas

---

## 📚 Referências

- [Terraform Import](https://developer.hashicorp.com/terraform/cli/import)
- [Terraform Remote State](https://developer.hashicorp.com/terraform/language/state/remote)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [Terraform Module Composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition)

---

**Última atualização:** 2025-11-06
**Responsável:** Diego Righi (Admin)
**Status:** 📝 Planejamento
