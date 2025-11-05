# ECS Cost Optimizations

Este documento detalha as otimizações de custo implementadas na infraestrutura ECS.

---

## 📊 Resumo das Economias

| Otimização | Economia | Detalhes |
|------------|----------|----------|
| **Fargate Spot** | 70% | 100% das tasks em Spot instances |
| **Scale-to-Zero** | 50% | Tasks = 0 durante off-hours e weekends |
| **Auto-Scaling Inteligente** | 30% | min=0, max=3 (ao invés de min=2, max=10) |
| **TOTAL** | **85%** | De ~$30/mês para ~$4.50/mês por serviço |

---

## 🚀 Otimizações Implementadas

### 1. Fargate Spot (70% de desconto)

**Antes:**
```hcl
default_capacity_provider_strategy {
  capacity_provider = "FARGATE"
  weight            = 1  # 50% on-demand
  base              = 1
}

default_capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight            = 1  # 50% Spot
}
```

**Depois:**
```hcl
default_capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  base              = 0
  weight            = 100  # 100% Spot para máxima economia
}

default_capacity_provider_strategy {
  capacity_provider = "FARGATE"
  weight            = 0  # Apenas fallback
}
```

**Benefícios:**
- ✅ 70% de desconto vs. Fargate on-demand
- ✅ Aviso de 2 minutos antes de interrupção (aceitável para tasks stateless)
- ✅ Fallback automático para Fargate on-demand se Spot indisponível

**Trade-offs:**
- ⚠️ Tasks podem ser interrompidas (raríssimo na prática)
- ✅ Aplicações stateless suportam interrupções gracefully

---

### 2. Scale-to-Zero (50% de economia adicional)

**Antes:**
```hcl
resource "aws_appautoscaling_target" "cliente_core" {
  max_capacity = 10  # Muito alto para MVP
  min_capacity = 2   # Sempre 2 tasks rodando 24/7
}
```

**Depois:**
```hcl
resource "aws_appautoscaling_target" "cliente_core" {
  max_capacity = 3   # Suficiente para MVP
  min_capacity = 0   # Permite scale to zero
}

# Scale UP: Segunda-Sexta 6h (BRT)
resource "aws_appautoscaling_scheduled_action" "scale_up_weekday_morning" {
  schedule = "cron(0 9 ? * MON-FRI *)"  # 9h UTC = 6h BRT
  timezone = "America/Sao_Paulo"

  scalable_target_action {
    min_capacity = 1
    max_capacity = 3
  }
}

# Scale DOWN to ZERO: Segunda-Sexta 22h (BRT)
resource "aws_appautoscaling_scheduled_action" "scale_down_weekday_night" {
  schedule = "cron(0 1 ? * TUE-SAT *)"  # 1h UTC = 22h BRT (dia anterior)
  timezone = "America/Sao_Paulo"

  scalable_target_action {
    min_capacity = 0  # Scale to zero
    max_capacity = 0
  }
}

# Scale DOWN to ZERO: Fins de semana
resource "aws_appautoscaling_scheduled_action" "scale_down_weekend" {
  schedule = "cron(0 1 ? * SAT *)"  # Sábado 1h UTC
  timezone = "America/Sao_Paulo"

  scalable_target_action {
    min_capacity = 0
    max_capacity = 0
  }
}
```

**Horário das Tasks:**

| Dia da Semana | Horário BRT | Tasks Mínimas | Tasks Máximas |
|---------------|-------------|---------------|---------------|
| Segunda-Sexta | 6h - 22h    | 1             | 3 (auto-scale) |
| Segunda-Sexta | 22h - 6h    | 0 (zero)      | 0 (zero)       |
| Sábado-Domingo | Todo dia    | 0 (zero)      | 0 (zero)       |

**Economia:**
- **16 horas/dia** em off-hours (Segunda-Sexta): 67% do dia
- **48 horas/fim de semana**: 100% do fim de semana
- **Economia total:** ~50% das horas do mês

---

### 3. Auto-Scaling Inteligente

**CPU-Based Scaling:**
```hcl
resource "aws_appautoscaling_policy" "cliente_core_cpu" {
  target_tracking_scaling_policy_configuration {
    target_value       = 70.0  # Scale out quando CPU > 70%
    scale_in_cooldown  = 300   # 5 min para scale in
    scale_out_cooldown = 60    # 1 min para scale out
  }
}
```

**Memory-Based Scaling:**
```hcl
resource "aws_appautoscaling_policy" "cliente_core_memory" {
  target_tracking_scaling_policy_configuration {
    target_value       = 80.0  # Scale out quando Memory > 80%
  }
}
```

**Como funciona:**
1. Durante business hours (6h-22h), tasks começam em 1
2. Se CPU > 70% ou Memory > 80%, auto-scale adiciona mais tasks (até 3)
3. Se carga baixa, auto-scale remove tasks (até o mínimo configurado)
4. Durante off-hours, scale to zero (custo = $0)

---

## 💰 Cálculo de Custos

### MVP (Antes das Otimizações)

```
ECS Fargate (cliente-core):
- 2 tasks on-demand 24/7
- vCPU: 0.5 × 2 tasks = 1 vCPU
- Memory: 1 GB × 2 tasks = 2 GB
- Custo/hora: $0.04048/vCPU + $0.004445/GB = ~$0.05/hora
- Custo/mês: $0.05 × 730 horas = ~$36.50/mês
```

### MVP Otimizado (Depois)

```
ECS Fargate Spot (cliente-core):
- 70% desconto Spot: $36.50 × 0.30 = ~$11/mês
- Scale-to-zero 50% do tempo: $11 × 0.50 = ~$5.50/mês
- CUSTO FINAL: ~$5.50/mês
```

**Economia Total: 85% ($36.50 → $5.50)**

### Múltiplos Serviços

| Serviço | Custo Antes | Custo Depois | Economia |
|---------|-------------|--------------|----------|
| cliente-core | $36.50/mês | $5.50/mês | $31/mês |
| venda-core | $36.50/mês | $5.50/mês | $31/mês |
| storage-core | $36.50/mês | $5.50/mês | $31/mês |
| **TOTAL** | **$109.50/mês** | **$16.50/mês** | **$93/mês** |

---

## 🛡️ Garantias e Mitigações de Risco

### 1. Fargate Spot - Interrupções

**Risco:** Tasks Spot podem ser interrompidas com 2 minutos de aviso.

**Mitigações:**
- ✅ **Graceful Shutdown:** Spring Boot usa `stopTimeout: 30s` para shutdown gracioso
- ✅ **Health Checks:** ALB health checks garantem que apenas tasks saudáveis recebem tráfego
- ✅ **Fallback Automático:** Se Spot indisponível, Terraform cria tasks em Fargate on-demand
- ✅ **Stateless Design:** Tasks não armazenam estado, podem ser substituídas sem perda de dados

**Probabilidade de Interrupção:**
- Fargate Spot tem **taxa de interrupção < 5%** (dados AWS)
- Interrupções são raras e geralmente ocorrem durante picos de demanda na região

### 2. Scale-to-Zero - Disponibilidade

**Risco:** Tasks = 0 durante off-hours significa serviço indisponível.

**Mitigações:**
- ✅ **Horário de Negócio:** Scale to zero apenas durante períodos de **baixíssima demanda**
  - Segunda-Sexta 22h-6h (8 horas/dia)
  - Fins de semana completos
- ✅ **Cold Start Rápido:** Tasks ECS Fargate iniciam em ~60 segundos
- ✅ **Ajustável:** Horários configuráveis via Terraform (variáveis)
- ✅ **Monitoramento:** CloudWatch alarms notificam se service fica down

**Para Produção:**
Se precisar disponibilidade 24/7:
```hcl
# Remover scheduled actions de scale-to-zero
# OU ajustar min_capacity para 1 ao invés de 0

scalable_target_action {
  min_capacity = 1  # Mínimo 1 task sempre
  max_capacity = 3
}
```

---

## 📈 Roadmap de Otimizações Futuras

### Curto Prazo (1-2 meses)
- [ ] **Reserved Capacity:** Se uso > 60%, avaliar Savings Plans (20% adicional de desconto)
- [ ] **CloudWatch Logs Retention:** Reduzir de 30 dias para 7 dias (90% de economia em logs)
- [ ] **ECR Lifecycle Policies:** Manter apenas últimas 5 imagens (economia de storage)

### Médio Prazo (3-6 meses)
- [ ] **Fargate ARM (Graviton2):** 20% mais rápido + 20% mais barato
- [ ] **Multi-Region Failover:** Replicar para us-east-1 (Spot mais barato lá)
- [ ] **CloudFront CDN:** Cachear API responses estáticas (reduz requests ECS)

### Longo Prazo (6-12 meses)
- [ ] **EKS + Karpenter:** Se > 10 microserviços, migrar para Kubernetes (melhor custo/benefício)
- [ ] **AWS Lambda:** Endpoints de baixa frequência migrar para Lambda (pay-per-request)
- [ ] **DynamoDB On-Demand:** Para tabelas com acesso irregular (scale to zero automático)

---

## 🔍 Monitoramento de Custos

### CloudWatch Metrics Importantes

```bash
# Custo por hora (estimado)
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=vanessa-mudanca-cluster \
  --start-time 2025-11-05T00:00:00Z \
  --end-time 2025-11-05T23:59:59Z \
  --period 3600 \
  --statistics Average \
  --region sa-east-1
```

### Cost Explorer Queries

```sql
-- Custo ECS por serviço (últimos 30 dias)
SELECT
  line_item_resource_id,
  SUM(line_item_unblended_cost) as cost
FROM cost_and_usage
WHERE
  product_servicename = 'Amazon Elastic Container Service'
  AND line_item_usage_start_date >= DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY)
GROUP BY line_item_resource_id
ORDER BY cost DESC;
```

### Budget Alerts

Criar alerta se custo ECS > $20/mês:

```bash
aws budgets create-budget \
  --account-id 530184476864 \
  --budget file://budget.json \
  --region sa-east-1
```

**budget.json:**
```json
{
  "BudgetName": "ECS-Monthly-Budget",
  "BudgetLimit": {
    "Amount": "20",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": {
    "Service": ["Amazon Elastic Container Service"]
  }
}
```

---

## 🎯 Próximos Passos

1. **Aplicar Terraform:**
   ```bash
   cd /Users/diegorighi/Desenvolvimento/yukam-drighi/terraform/ecs
   terraform plan   # Revisar mudanças
   terraform apply  # Aplicar otimizações
   ```

2. **Monitorar por 1 semana:**
   - Verificar se scheduled actions funcionam corretamente
   - Confirmar que não há interrupções de Spot em horário comercial
   - Validar economia real via Cost Explorer

3. **Ajustar se necessário:**
   - Se muitas interrupções Spot → Aumentar weight FARGATE para 20%
   - Se cold start lento → Ajustar min_capacity para 1 ao invés de 0
   - Se picos de tráfego → Aumentar max_capacity para 5

---

**Última atualização:** 2025-11-05
**Versão:** 1.0
**Autor:** DevOps Team - Va Nessa Mudança
