# 🔄 Infrastructure Restore Guide

**Propósito:** Documentação completa para **religar a infraestrutura AWS** com ALB, Security Groups, e todos os componentes necessários para produção.

**Contexto:** A infraestrutura foi **simplificada para MVP** (sem ALB) para economizar custos. Este guia permite restaurar a arquitetura completa quando necessário.

---

## 📋 Índice

1. [Arquitetura Atual vs. Completa](#arquitetura-atual-vs-completa)
2. [Quando Restaurar ALB](#quando-restaurar-alb)
3. [Pré-requisitos](#pré-requisitos)
4. [Passo 1: Verificar Recursos Existentes](#passo-1-verificar-recursos-existentes)
5. [Passo 2: Criar/Verificar Security Groups](#passo-2-criarverificar-security-groups)
6. [Passo 3: Restaurar ALB via Terraform](#passo-3-restaurar-alb-via-terraform)
7. [Passo 4: Atualizar ECS Service](#passo-4-atualizar-ecs-service)
8. [Passo 5: Verificar Health Checks](#passo-5-verificar-health-checks)
9. [Passo 6: Testar Conectividade](#passo-6-testar-conectividade)
10. [Troubleshooting](#troubleshooting)

---

## Arquitetura Atual vs. Completa

### ❌ Arquitetura Atual (MVP Simplificado)

```
Internet
   ↓
ECS Fargate Task (IP público: 18.231.xxx.xxx:8081)
   ↓
RDS PostgreSQL (private)
```

**Custo:** ~$45/mês (ECS + RDS)

**Limitações:**
- Sem HTTPS/SSL
- Sem load balancing (apenas 1 task)
- IP público muda a cada deploy
- Sem domain customizado
- Sem health checks do ALB

---

### ✅ Arquitetura Completa (Com ALB)

```
Internet
   ↓
Application Load Balancer (DNS: vanessa-mudanca-alb-xxx.elb.amazonaws.com)
   ↓ (via Target Group)
ECS Fargate Tasks (private IPs, múltiplas tasks possível)
   ↓
RDS PostgreSQL (private)
```

**Custo:** ~$70/mês (ECS + RDS + ALB)

**Vantagens:**
- ✅ HTTPS com ACM (AWS Certificate Manager)
- ✅ Load balancing entre múltiplas tasks
- ✅ DNS estável (não muda)
- ✅ Health checks automáticos
- ✅ Domain customizado (Route53)
- ✅ Auto Scaling Group support
- ✅ WAF support (proteção DDoS)

---

## Quando Restaurar ALB

**✅ RESTAURE quando:**
- Tiver múltiplos microserviços (roteamento por path)
- Precisar de Auto Scaling (> 1 task)
- Precisar de HTTPS com certificado SSL
- Preparar para produção com usuários reais
- Precisar de domain customizado
- Implementar Blue/Green deployments

**❌ NÃO RESTAURE se:**
- Ainda está em desenvolvimento/testes
- Tem apenas 1 task rodando
- Não tem usuários externos
- Quer economizar custos

---

## Pré-requisitos

### 1. Ferramentas Instaladas

```bash
# Verificar Terraform
terraform version
# Esperado: Terraform v1.x.x

# Verificar AWS CLI
aws --version
# Esperado: aws-cli/2.x.x

# Verificar credenciais AWS
aws sts get-caller-identity
# Esperado: Account ID 530184476864
```

### 2. Variáveis de Ambiente

```bash
export AWS_REGION="sa-east-1"
export AWS_ACCOUNT_ID="530184476864"
export VPC_ID="vpc-0b338b69a3ddac5da"
```

### 3. Estado Atual da Infraestrutura

```bash
# Ligar infraestrutura básica (ECS + RDS)
cd /Users/diegorighi/Desenvolvimento/yukam-drighi
./scripts/toggle-infra.sh on

# Verificar status
./scripts/toggle-infra.sh status

# Resultado esperado:
# ✅ ECS Service: ON (desiredCount=1, runningCount=1)
# ⚠️  ALB: OFF (deletado)
# ✅ RDS: ON (available)
```

---

## Passo 1: Verificar Recursos Existentes

### 1.1 Verificar VPC e Subnets

```bash
# VPC ID
aws ec2 describe-vpcs \
  --vpc-ids vpc-0b338b69a3ddac5da \
  --region sa-east-1 \
  --query 'Vpcs[0].{VpcId:VpcId,CidrBlock:CidrBlock,IsDefault:IsDefault}' \
  --output table

# Subnets públicas (para ALB)
aws ec2 describe-subnets \
  --subnet-ids subnet-02fa56b41afd95fbc subnet-09294063c722eea99 \
  --region sa-east-1 \
  --query 'Subnets[*].{SubnetId:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock,Public:MapPublicIpOnLaunch}' \
  --output table
```

**Resultado esperado:**
```
VPC: vpc-0b338b69a3ddac5da (172.31.0.0/16)
Subnets:
  - subnet-02fa56b41afd95fbc (sa-east-1a) - 172.31.0.0/20
  - subnet-09294063c722eea99 (sa-east-1b) - 172.31.16.0/20
```

### 1.2 Verificar ECS Cluster e Service

```bash
# Cluster
aws ecs describe-clusters \
  --clusters cliente-core-prod-cluster \
  --region sa-east-1 \
  --query 'clusters[0].{Name:clusterName,Status:status,TaskCount:registeredContainerInstancesCount}' \
  --output table

# Service
aws ecs describe-services \
  --cluster cliente-core-prod-cluster \
  --services cliente-core-prod-service \
  --region sa-east-1 \
  --query 'services[0].{Name:serviceName,Status:status,DesiredCount:desiredCount,RunningCount:runningCount}' \
  --output table
```

### 1.3 Verificar RDS

```bash
aws rds describe-db-instances \
  --db-instance-identifier cliente-core-prod \
  --region sa-east-1 \
  --query 'DBInstances[0].{Endpoint:Endpoint.Address,Status:DBInstanceStatus,Engine:Engine,Size:DBInstanceClass}' \
  --output table
```

---

## Passo 2: Criar/Verificar Security Groups

### 2.1 Security Group para ALB

**Arquivo:** `terraform/ecs/security_groups.tf` (criar se não existir)

```hcl
# Security Group para Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "vanessa-mudanca-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTP (porta 80)
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS (porta 443) - para futuro
  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - permitir todo tráfego de saída
  egress {
    description = "All traffic outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "vanessa-mudanca-alb-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Security Group para ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "vanessa-mudanca-ecs-tasks-sg"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = var.vpc_id

  # Permitir tráfego do ALB na porta 8081 (Spring Boot)
  ingress {
    description     = "HTTP from ALB"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Egress - permitir todo tráfego de saída (para acessar RDS, ECR, Secrets Manager)
  egress {
    description = "All traffic outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "vanessa-mudanca-ecs-tasks-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Security Group para RDS (se não existir)
resource "aws_security_group" "rds" {
  name        = "vanessa-mudanca-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  # Permitir PostgreSQL apenas das ECS tasks
  ingress {
    description     = "PostgreSQL from ECS Tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  # Sem egress (RDS não precisa conectar para fora)

  tags = {
    Name        = "vanessa-mudanca-rds-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

### 2.2 Aplicar Security Groups

```bash
cd /Users/diegorighi/Desenvolvimento/yukam-drighi/terraform/ecs

# Verificar o que será criado
terraform plan

# Aplicar
terraform apply -target=aws_security_group.alb -target=aws_security_group.ecs_tasks
```

---

## Passo 3: Restaurar ALB via Terraform

### 3.1 Arquivo ALB Principal

**Arquivo:** `terraform/ecs/alb.tf`

```hcl
# ==============================================================================
# Application Load Balancer
# ==============================================================================

resource "aws_lb" "main" {
  name               = "vanessa-mudanca-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false  # true em produção!
  enable_http2               = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "vanessa-mudanca-alb"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ==============================================================================
# Target Group (para ECS Tasks)
# ==============================================================================

resource "aws_lb_target_group" "cliente_core" {
  name        = "cliente-core-tg"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # Importante para Fargate!

  # Health Check Configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/api/clientes/actuator/health"
    protocol            = "HTTP"
    matcher             = "200"  # Código HTTP esperado
  }

  # Deregistration Delay (tempo para drenar conexões antes de remover task)
  deregistration_delay = 30

  tags = {
    Name        = "cliente-core-target-group"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# Listener HTTP (porta 80)
# ==============================================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Roteamento padrão para cliente-core
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cliente_core.arn
  }

  tags = {
    Name        = "http-listener"
    Environment = var.environment
  }
}

# ==============================================================================
# Listener HTTPS (porta 443) - FUTURO
# ==============================================================================

# Descomentar quando tiver certificado SSL no ACM
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
#   certificate_arn   = var.acm_certificate_arn  # ARN do certificado ACM
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.cliente_core.arn
#   }
# }

# ==============================================================================
# Outputs
# ==============================================================================

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.cliente_core.arn
}
```

### 3.2 Atualizar Variables

**Arquivo:** `terraform/ecs/variables.tf`

Adicionar se não existir:

```hcl
variable "enable_alb" {
  description = "Enable Application Load Balancer (costs ~$25/month)"
  type        = bool
  default     = false  # Mude para true quando quiser ALB
}
```

### 3.3 Aplicar ALB

```bash
cd /Users/diegorighi/Desenvolvimento/yukam-drighi/terraform/ecs

# 1. Habilitar ALB no terraform.tfvars
echo 'enable_alb = true' >> terraform.tfvars

# 2. Verificar o que será criado
terraform plan

# Esperado:
#   + aws_lb.main
#   + aws_lb_target_group.cliente_core
#   + aws_lb_listener.http

# 3. Aplicar
terraform apply -auto-approve

# 4. Aguardar ~5 minutos para ALB provisionar

# 5. Obter DNS do ALB
terraform output alb_dns_name
# Output: vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com
```

---

## Passo 4: Atualizar ECS Service

### 4.1 Modificar ECS Service para usar ALB

**Arquivo:** `terraform/ecs/ecs_service.tf`

```hcl
resource "aws_ecs_service" "cliente_core" {
  name            = "cliente-core-prod-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.cliente_core.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = var.enable_alb ? false : true  # Público apenas sem ALB
  }

  # Configuração ALB (condicional)
  dynamic "load_balancer" {
    for_each = var.enable_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.cliente_core.arn
      container_name   = "cliente-core"
      container_port   = 8081
    }
  }

  # Health Check Grace Period (tempo para app iniciar antes de verificar saúde)
  health_check_grace_period_seconds = var.enable_alb ? 120 : null

  # Deployment Configuration
  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  # Dependências
  depends_on = [
    aws_lb_listener.http  # Garantir que listener existe antes de criar service
  ]

  tags = {
    Name        = "cliente-core-service"
    Environment = var.environment
  }
}
```

### 4.2 Aplicar Atualização do Service

```bash
cd /Users/diegorighi/Desenvolvimento/yukam-drighi/terraform/ecs

# Aplicar mudanças no ECS Service
terraform apply -target=aws_ecs_service.cliente_core -auto-approve

# IMPORTANTE: ECS vai fazer rolling update
# - Cria nova task com configuração ALB
# - Aguarda nova task ficar HEALTHY
# - Remove task antiga
# Tempo total: ~5 minutos
```

---

## Passo 5: Verificar Health Checks

### 5.1 Verificar Target Group Health

```bash
# Listar targets registrados
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region sa-east-1 \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}' \
  --output table
```

**Estado esperado:**
```
Target: 172.31.x.x (IP privado da task)
Port: 8081
State: healthy
Reason: -
```

**Estados possíveis:**
- `initial` - Health check ainda não executado (primeiros 30s)
- `healthy` - Task está saudável ✅
- `unhealthy` - Task não responde ao health check ❌
- `draining` - Task sendo removida
- `unavailable` - Target não registrado

### 5.2 Verificar Logs do Health Check

```bash
# Ver logs da task para ver health check requests
aws logs tail /ecs/cliente-core-prod \
  --follow \
  --since 2m \
  --region sa-east-1 \
  --filter-pattern "actuator/health"
```

**Output esperado:**
```
GET /api/clientes/actuator/health HTTP/1.1" 200
```

---

## Passo 6: Testar Conectividade

### 6.1 Testar ALB DNS

```bash
# Obter DNS do ALB
ALB_DNS=$(terraform output -raw alb_dns_name)

# Testar health check
curl -i http://$ALB_DNS/api/clientes/actuator/health

# Resultado esperado:
# HTTP/1.1 200 OK
# {"status":"UP"}

# Testar endpoint protegido (deve retornar 401)
curl -i http://$ALB_DNS/api/clientes/v1/clientes/pf

# Resultado esperado:
# HTTP/1.1 401 Unauthorized
# WWW-Authenticate: Bearer
```

### 6.2 Testar com JWT Token (Opcional)

```bash
# 1. Obter token do Cognito
TOKEN=$(curl -X POST https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=<CLIENT_ID>" \
  -d "client_secret=<CLIENT_SECRET>" \
  -d "scope=cliente-core/read" \
  | jq -r '.access_token')

# 2. Testar endpoint com token
curl -i http://$ALB_DNS/api/clientes/v1/clientes/pf \
  -H "Authorization: Bearer $TOKEN"

# Resultado esperado:
# HTTP/1.1 200 OK
# [{"publicId":"...","nomeCompleto":"..."}]
```

### 6.3 Verificar Métricas do ALB

```bash
# Ver métricas no CloudWatch
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=$(terraform output -raw alb_dns_name | cut -d'-' -f3-) \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region sa-east-1
```

---

## Troubleshooting

### Problema 1: Target Group Unhealthy

**Sintoma:**
```bash
aws elbv2 describe-target-health ...
State: unhealthy
Reason: Target.ResponseCodeMismatch
```

**Causa:** Health check path não retorna 200 OK

**Solução:**
```bash
# 1. Verificar path do health check
aws elbv2 describe-target-groups \
  --target-group-arns $(terraform output -raw target_group_arn) \
  --query 'TargetGroups[0].HealthCheckPath'

# 2. Testar endpoint diretamente na task
TASK_IP=$(aws ecs describe-tasks \
  --cluster cliente-core-prod-cluster \
  --tasks $(aws ecs list-tasks --cluster cliente-core-prod-cluster --service-name cliente-core-prod-service --query 'taskArns[0]' --output text) \
  --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' \
  --output text)

curl -i http://$TASK_IP:8081/api/clientes/actuator/health

# 3. Se não retornar 200, corrigir aplicação
```

### Problema 2: ALB Retorna 503 Service Unavailable

**Sintoma:**
```bash
curl http://<ALB_DNS>/api/clientes/actuator/health
# HTTP/1.1 503 Service Unavailable
```

**Causa:** Nenhum target healthy no target group

**Solução:**
```bash
# 1. Verificar se tasks estão rodando
aws ecs list-tasks \
  --cluster cliente-core-prod-cluster \
  --service-name cliente-core-prod-service \
  --desired-status RUNNING

# 2. Verificar logs das tasks
aws logs tail /ecs/cliente-core-prod --follow --since 5m --region sa-east-1

# 3. Se task não está iniciando, verificar:
# - Task definition está correta?
# - Security group permite tráfego?
# - RDS está acessível?
```

### Problema 3: ECS Task Não Registra no Target Group

**Sintoma:** Task está RUNNING mas não aparece no target group

**Causa:** Configuração incorreta do load_balancer no ECS Service

**Solução:**
```bash
# 1. Verificar configuração do service
aws ecs describe-services \
  --cluster cliente-core-prod-cluster \
  --services cliente-core-prod-service \
  --query 'services[0].loadBalancers'

# Esperado:
# [
#   {
#     "targetGroupArn": "arn:aws:elasticloadbalancing:...",
#     "containerName": "cliente-core",
#     "containerPort": 8081
#   }
# ]

# 2. Se vazio, recriar service:
terraform taint aws_ecs_service.cliente_core
terraform apply -target=aws_ecs_service.cliente_core
```

### Problema 4: Security Group Bloqueando Tráfego

**Sintoma:** Timeout ao acessar ALB ou health check unhealthy

**Solução:**
```bash
# 1. Verificar security groups
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw alb_security_group_id) \
  --query 'SecurityGroups[0].IpPermissions'

# 2. Verificar se:
# - ALB SG permite entrada nas portas 80/443 de 0.0.0.0/0
# - ECS SG permite entrada na porta 8081 do ALB SG
# - RDS SG permite entrada na porta 5432 do ECS SG

# 3. Corrigir no Terraform e aplicar
terraform apply
```

---

## Custo Estimado

| Componente | Sem ALB (MVP) | Com ALB (Completo) |
|------------|---------------|-------------------|
| ECS Fargate (1 task) | $30/mês | $30/mês |
| RDS db.t3.micro | $15/mês | $15/mês |
| ALB | - | $25/mês |
| Data Transfer | $1/mês | $3/mês |
| **TOTAL** | **~$46/mês** | **~$73/mês** |

**Diferença:** +$27/mês (~59% de aumento)

---

## Checklist de Restauração

- [ ] Infraestrutura básica ligada (ECS + RDS)
- [ ] Security Groups criados via Terraform
- [ ] ALB criado via Terraform
- [ ] Target Group configurado
- [ ] Listener HTTP criado
- [ ] ECS Service atualizado com load_balancer
- [ ] Health checks passando (target healthy)
- [ ] ALB retorna 200 OK no health check endpoint
- [ ] ALB retorna 401 Unauthorized em endpoints protegidos
- [ ] DNS do ALB anotado para referência
- [ ] Atualizar `toggle-infra.sh` para incluir ALB (opcional)

---

## Rollback (Voltar para MVP sem ALB)

Se quiser economizar custos novamente:

```bash
cd /Users/diegorighi/Desenvolvimento/yukam-drighi/terraform/ecs

# 1. Desabilitar ALB
sed -i '' 's/enable_alb = true/enable_alb = false/' terraform.tfvars

# 2. Destruir recursos do ALB
terraform destroy -target=aws_lb_listener.http -target=aws_lb_target_group.cliente_core -target=aws_lb.main

# 3. Atualizar ECS Service (vai voltar para IP público)
terraform apply -target=aws_ecs_service.cliente_core

# 4. Economia: ~$27/mês
```

---

## Próximos Passos (Produção Avançada)

Quando a aplicação crescer, considere:

1. **HTTPS com ACM:** Certificado SSL gratuito
2. **Route53:** Domain customizado (ex: api.vanessamudanca.com.br)
3. **Auto Scaling:** 2-4 tasks com scaling policies
4. **CloudFront CDN:** Cache e proteção DDoS
5. **WAF:** Web Application Firewall
6. **Multi-AZ RDS:** Alta disponibilidade do banco
7. **Blue/Green Deployment:** Zero-downtime deploys

---

**Última atualização:** 2025-11-06
**Responsável:** Diego Righi
**Versão:** 1.0
