# Guia de Otimização de Custos AWS - Va Nessa Mudança

## 💰 Resumo Executivo

**Custo Atual (MVP):** ~$69/mês
**Custo Otimizado:** ~$48/mês (30% economia)
**Custo Produção (Futuro):** ~$285/mês

---

## 1. ECS Fargate - Auto-Scaling com Schedule

### Problema
- Tasks rodando 24/7 mesmo sem tráfego = $30/mês
- Fora do horário comercial (22h-6h) = 33% do mês desperdiçado
- Fins de semana = 29% do mês desperdiçado
- **Total desperdiço:** 62% do mês sem uso

### Solução: Scale-to-Zero com Scheduled Actions

**Implementação Terraform:**

```terraform
# modules/ecs/auto-scaling.tf

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 3
  min_capacity       = 0  # IMPORTANTE: permite scale to zero
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# CPU-based scaling (dentro do horário comercial)
resource "aws_appautoscaling_policy" "ecs_cpu_scaling" {
  name               = "${var.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300  # 5 min
    scale_out_cooldown = 60   # 1 min
  }
}

# Scheduled Action: SCALE UP às 6h (Segunda-Sexta)
resource "aws_appautoscaling_scheduled_action" "scale_up_weekday_morning" {
  name               = "${var.service_name}-scale-up-weekday-morning"
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  schedule           = "cron(0 9 ? * MON-FRI *)"  # 6h BRT = 9h UTC
  timezone           = "America/Sao_Paulo"

  scalable_target_action {
    min_capacity = 1
    max_capacity = 3
  }
}

# Scheduled Action: SCALE DOWN às 22h (Segunda-Sexta)
resource "aws_appautoscaling_scheduled_action" "scale_down_weekday_night" {
  name               = "${var.service_name}-scale-down-weekday-night"
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  schedule           = "cron(0 1 ? * TUE-SAT *)"  # 22h BRT = 1h UTC (próximo dia)
  timezone           = "America/Sao_Paulo"

  scalable_target_action {
    min_capacity = 0  # Scale to zero
    max_capacity = 0  # Force zero tasks
  }
}

# Scheduled Action: SCALE DOWN fim de semana (Sábado 00h)
resource "aws_appautoscaling_scheduled_action" "scale_down_weekend" {
  name               = "${var.service_name}-scale-down-weekend"
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  schedule           = "cron(0 3 ? * SAT *)"  # Sábado 00h BRT = 3h UTC
  timezone           = "America/Sao_Paulo"

  scalable_target_action {
    min_capacity = 0
    max_capacity = 0
  }
}
```

**Economia:**
- **Antes:** 3 tasks × 24h/dia × 30 dias = 2160 task-hours/mês
- **Depois:** 3 tasks × 16h/dia × 22 dias úteis = 1056 task-hours/mês
- **Redução:** 51% (-1104 task-hours)
- **Valor:** $30/mês → **$15/mês**

---

## 2. Fargate Spot - 70% de Desconto

### Problema
- Fargate On-Demand cobra preço cheio
- $0.04048/vCPU/hora + $0.004445/GB/hora

### Solução: Fargate Spot

**Tradeoff:**
- ✅ **70% desconto** no compute
- ⚠️ **Interrupção:** AWS pode reclamar tasks com 2min de aviso
- ✅ **Resiliente:** ECS recria tasks automaticamente em outra AZ

**Quando usar:**
- ✅ Stateless applications (microserviços REST)
- ✅ Workloads tolerantes a interrupção
- ❌ Long-running batch jobs (use Fargate On-Demand)
- ❌ Databases (use RDS, não containers)

**Implementação Terraform:**

```terraform
# modules/ecs/main.tf

resource "aws_ecs_cluster_capacity_providers" "fargate_spot" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 1     # Primeira task em Spot
    weight            = 100   # 100% das tasks restantes em Spot
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 0
    weight            = 0     # Fallback apenas se Spot indisponível
  }
}

resource "aws_ecs_service" "microservice" {
  # ... outras configurações

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 1
    weight            = 100
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 0
    weight            = 0
  }

  # IMPORTANTE: Habilitar deployment circuit breaker
  deployment_circuit_breaker {
    enable   = true
    rollback = true  # Rollback automático se deployment falhar
  }
}
```

**Economia:**
- **Antes:** $15/mês (após scale-to-zero)
- **Depois:** $15/mês × 30% = **$4.50/mês**
- **Economia adicional:** $10.50/mês

---

## 3. RDS Multi-Schema (Shared Database)

### Problema
- 1 RDS por microserviço = 5 × $15/mês = **$75/mês**
- RDS tem overhead fixo (storage, backups, logs)

### Solução: 1 RDS com Múltiplos Schemas

**Trade-offs:**
- ✅ **Economia:** 67% ($75 → $25)
- ✅ **Simplicidade:** 1 endpoint, 1 backup, 1 monitoramento
- ⚠️ **Acoplamento:** Todos os MS dependem do mesmo RDS
- ⚠️ **Scaling:** Não pode escalar storage/IOPS por MS
- ❌ **Multi-Tenancy:** Se cliente quer dados em região/país diferente

**Quando usar:**
- ✅ **MVP/Startup** (1-5 microserviços)
- ✅ **Same Region/Compliance**
- ✅ **Low-Medium Traffic** (<1000 req/s total)

**Quando NÃO usar:**
- ❌ **Escala massiva** (>10 microserviços)
- ❌ **Multi-Region** (dados em US, EU, BR)
- ❌ **Compliance strict** (PCI-DSS Level 1, SOC 2 Type II)

**Implementação:**

```sql
-- Setup inicial (executar 1 vez)
CREATE DATABASE vanessa_mudanca;

\c vanessa_mudanca;

-- Schema per microservice
CREATE SCHEMA cliente_core;
CREATE SCHEMA venda_core;
CREATE SCHEMA storage_core;
CREATE SCHEMA financeiro_core;
CREATE SCHEMA logistica_core;

-- User per microservice (least privilege)
CREATE USER cliente_core_user WITH PASSWORD 'secret1';
CREATE USER venda_core_user WITH PASSWORD 'secret2';
CREATE USER storage_core_user WITH PASSWORD 'secret3';

-- Permissions
GRANT USAGE ON SCHEMA cliente_core TO cliente_core_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cliente_core TO cliente_core_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA cliente_core TO cliente_core_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA cliente_core GRANT ALL ON TABLES TO cliente_core_user;

-- Revoke cross-schema access (security)
REVOKE ALL ON SCHEMA venda_core FROM cliente_core_user;
REVOKE ALL ON SCHEMA storage_core FROM cliente_core_user;
```

**Spring Boot application.yml:**

```yaml
spring:
  datasource:
    url: jdbc:postgresql://vanessa-mudanca-rds:5432/vanessa_mudanca?currentSchema=cliente_core
    username: cliente_core_user
    password: ${DB_PASSWORD}  # From Secrets Manager

  jpa:
    hibernate:
      ddl-auto: validate  # NEVER use 'update' in production
    properties:
      hibernate:
        default_schema: cliente_core  # Fallback
```

**Liquibase changelog:**

```xml
<databaseChangeLog>
  <changeSet id="001" author="devops">
    <sql>SET search_path TO cliente_core;</sql>
    <createTable tableName="clientes">
      <!-- tables criadas em cliente_core schema -->
    </createTable>
  </changeSet>
</databaseChangeLog>
```

---

## 4. ALB Compartilhado (Path-Based Routing)

### Problema
- 1 ALB por microserviço = 5 × $20/mês = **$100/mês**

### Solução: 1 ALB com Múltiplas Regras

**Terraform:**

```terraform
# modules/alb/main.tf

resource "aws_lb" "shared" {
  name               = "vanessa-mudanca-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = true  # Produção
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "vanessa-mudanca-shared-alb"
  }
}

# Listener HTTP → HTTPS Redirect
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.shared.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Listener HTTPS
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.shared.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  # Default action: 404
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({
        error   = "Not Found"
        message = "The requested resource does not exist"
      })
      status_code = "404"
    }
  }
}

# Rule 1: /api/clientes/* → cliente-core
resource "aws_lb_listener_rule" "cliente_core" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cliente_core.arn
  }

  condition {
    path_pattern {
      values = ["/api/clientes/*"]
    }
  }
}

# Rule 2: /api/vendas/* → venda-core
resource "aws_lb_listener_rule" "venda_core" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.venda_core.arn
  }

  condition {
    path_pattern {
      values = ["/api/vendas/*"]
    }
  }
}

# Target Group: cliente-core
resource "aws_lb_target_group" "cliente_core" {
  name        = "cliente-core-tg"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # Fargate usa IP target

  health_check {
    enabled             = true
    path                = "/api/clientes/actuator/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 30  # Graceful shutdown

  tags = {
    Name = "cliente-core-tg"
  }
}
```

**Economia:**
- **Antes:** 5 ALBs × $20/mês = $100/mês
- **Depois:** 1 ALB × $20/mês = **$20/mês**
- **Economia:** 80% ($80/mês)

---

## 5. CloudWatch Logs - Retenção Otimizada

### Problema
- Logs infinitos = crescimento exponencial de custos
- $0.50/GB ingested + $0.03/GB stored

### Solução: Retention Policies

```terraform
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.service_name}"
  retention_in_days = 7  # MVP: 7 days ($2/mês)
                         # Production: 30 days ($5/mês)
                         # Compliance: 90 days ($12/mês)

  kms_key_id = var.kms_key_arn  # Encryption at rest (opcional)

  tags = {
    Name = "${var.service_name}-logs"
  }
}
```

**Economia:**
- **Antes:** Retention indefinida = $10/mês (crescimento contínuo)
- **Depois:** Retention 7 days = **$2/mês**
- **Economia:** 80% ($8/mês)

---

## 6. VPC Endpoints vs NAT Gateway

### Problema
- NAT Gateway = $0.045/hora + $0.045/GB = **$32/mês** (mínimo)
- Multi-AZ HA = 2 NAT Gateways = **$64/mês**

### Solução: VPC Endpoints

**Serviços suportados:**
- ✅ S3 (Gateway Endpoint - **FREE**)
- ✅ DynamoDB (Gateway Endpoint - **FREE**)
- ✅ ECR (Interface Endpoint - **$7/mês**)
- ✅ Secrets Manager (Interface Endpoint - **$7/mês**)
- ✅ CloudWatch Logs (Interface Endpoint - **$7/mês**)

**Total:** 3 Interface Endpoints × $7/mês = **$21/mês**

**Economia:**
- **NAT Gateway:** $32/mês
- **VPC Endpoints:** $21/mês
- **Economia:** 34% ($11/mês)

**Bonus:** Gateway Endpoints (S3, DynamoDB) são **GRÁTIS**!

---

## 7. ARM Graviton2 (RDS)

### Problema
- RDS Intel x86: db.t3.micro = $0.017/hora = $12/mês

### Solução: ARM Graviton2

```terraform
resource "aws_db_instance" "main" {
  instance_class = "db.t4g.micro"  # Graviton2 ARM
  # ... outras configurações
}
```

**Economia:**
- **Antes:** db.t3.micro (Intel) = $12/mês
- **Depois:** db.t4g.micro (ARM) = **$10/mês**
- **Economia:** 17% ($2/mês)

**Performance:** 20-40% melhor que equivalente Intel!

---

## 💰 Resumo de Economias

| Otimização | Antes | Depois | Economia |
|------------|-------|--------|----------|
| ECS Scale-to-Zero | $30/mês | $15/mês | 50% ($15) |
| Fargate Spot | $15/mês | $4.50/mês | 70% ($10.50) |
| RDS Multi-Schema | $75/mês | $25/mês | 67% ($50) |
| ALB Compartilhado | $100/mês | $20/mês | 80% ($80) |
| CloudWatch Logs Retention | $10/mês | $2/mês | 80% ($8) |
| VPC Endpoints vs NAT | $32/mês | $21/mês | 34% ($11) |
| RDS Graviton2 | $12/mês | $10/mês | 17% ($2) |
| **TOTAL** | **$274/mês** | **$97.50/mês** | **64% ($176.50)** |

---

## 🎯 Plano de Implementação

### Fase 1: Melhorias Rápidas (Hoje)
- [x] Deletar cluster órfão `vanessa-mudanca-cluster`
- [ ] Configurar VPC Endpoints (já feito)
- [ ] Documentar arquitetura otimizada

### Fase 2: Auto-Scaling (Esta Semana)
- [ ] Implementar Scheduled Scaling (scale-to-zero)
- [ ] Migrar para Fargate Spot
- [ ] Configurar Circuit Breaker

### Fase 3: Consolidação (Próximo Mês)
- [ ] Migrar RDS para multi-schema
- [ ] Configurar ALB compartilhado
- [ ] Path-based routing

### Fase 4: Observabilidade (MVP Launch)
- [ ] CloudWatch Dashboards
- [ ] CloudWatch Alarms (CPU, Memory, Errors)
- [ ] Cost Anomaly Detection

---

## 📊 Monitoramento de Custos

### AWS Cost Explorer Queries

```
# Custo diário por serviço
Service: ECS
Group by: Usage Type
Granularity: Daily

# Custo mensal por microserviço
Tag: service=cliente-core
Tag: service=venda-core
Granularity: Monthly
```

### Budget Alerts

```terraform
resource "aws_budgets_budget" "monthly" {
  name              = "vanessa-mudanca-monthly-budget"
  budget_type       = "COST"
  limit_amount      = "100"  # $100/mês
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80  # Alert at 80% ($80)
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["devops@vanessamudanca.com.br"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100  # Alert at 100% ($100)
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["cto@vanessamudanca.com.br"]
  }
}
```

---

**Última atualização:** 2025-11-05
**Versão:** 1.0
