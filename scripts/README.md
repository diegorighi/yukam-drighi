# 🎛️ AWS Infrastructure Toggle Scripts

Scripts para **ligar** e **desligar** a infraestrutura AWS completa, economizando custos durante desenvolvimento.

---

## 📋 Índice

- [toggle-infra.sh](#toggle-infrash) - Liga/desliga toda a infraestrutura AWS
- [Recursos gerenciados](#recursos-gerenciados)
- [Economia de custos](#economia-de-custos)
- [Exemplos de uso](#exemplos-de-uso)

---

## `toggle-infra.sh`

Script principal para gerenciar TODA a infraestrutura AWS com um único comando.

### Uso Básico

```bash
# Desligar tudo (fim do dia de trabalho / fim de semana)
./scripts/toggle-infra.sh off

# Ligar tudo (início do dia / volta do fim de semana)
./scripts/toggle-infra.sh on

# Ver status atual e custo estimado
./scripts/toggle-infra.sh status
```

### Recursos Gerenciados

| Recurso | Ação OFF | Ação ON | Economia Mensal |
|---------|----------|---------|-----------------|
| **ECS Fargate Tasks** | `desiredCount=0` (para todas as tasks) | `desiredCount=1` | ~$30/mês |
| **Application Load Balancer** | Deleta o ALB | ⚠️ Precisa recriar via Terraform | ~$25/mês |
| **RDS PostgreSQL** | `stop-db-instance` (para o banco) | `start-db-instance` | ~$15/mês |

**💰 Economia Total: ~$60-100/mês** (apenas com os recursos acima)

---

## 🔧 Detalhes Técnicos

### ECS Service

**OFF:**
- Define `desiredCount=0` no ECS Service
- ECS para todas as tasks automaticamente
- **Tempo:** ~10 segundos

**ON:**
- Define `desiredCount=1` no ECS Service
- ECS inicia nova task com a última task definition
- **Tempo:** ~2 minutos (incluindo health checks)

### Application Load Balancer

**OFF:**
- Deleta o ALB completamente
- **Tempo:** Imediato
- **⚠️ Importante:** Não pode ser religado automaticamente

**ON:**
- Precisa ser recriado via Terraform:
  ```bash
  cd terraform/ecs
  terraform apply
  ```
- **Tempo:** ~5 minutos

### RDS PostgreSQL

**OFF:**
- Executa `stop-db-instance`
- **Tempo:** ~2 minutos
- **⚠️ Importante:** AWS reinicia automaticamente após 7 dias

**ON:**
- Executa `start-db-instance`
- **Tempo:** ~5-7 minutos
- **Validação:** `aws rds describe-db-instances --db-instance-identifier cliente-core-prod`

---

## 📊 Economia de Custos

### Cenário 1: Desenvolvimento (40h/semana)

**Sem toggle:**
- ECS: $30/mês (24/7)
- ALB: $25/mês (24/7)
- RDS: $15/mês (24/7)
- **Total:** $70/mês

**Com toggle (ligado apenas 8h/dia útil):**
- ECS: ~$5/mês (8h * 5 dias * 4 semanas)
- ALB: $0 (deletado quando off)
- RDS: ~$5/mês (8h * 5 dias * 4 semanas)
- **Total:** $10/mês
- **💰 Economia: $60/mês (86%)**

### Cenário 2: Fim de Semana (2 dias off)

**Economia por fim de semana:**
- ECS: $4 (48h * $0.04/hora)
- RDS: $2 (48h)
- **Total:** ~$6/fim de semana
- **💰 Economia mensal (4 fins de semana): $24/mês**

---

## 💡 Exemplos de Uso

### Fluxo de Trabalho Diário

```bash
# Segunda-feira, 9:00 AM - Começar a trabalhar
cd /Users/diegorighi/Desenvolvimento/yukam-drighi
./scripts/toggle-infra.sh on

# Aguardar ~5-7 minutos (RDS + ECS)
# Verificar status
./scripts/toggle-infra.sh status

# Segunda-feira, 18:00 PM - Fim do expediente
./scripts/toggle-infra.sh off
```

### Antes de Sair de Férias

```bash
# Desligar TUDO antes de sair
./scripts/toggle-infra.sh off

# Verificar que tudo está OFF
./scripts/toggle-infra.sh status

# Resultado esperado:
# ⚠️  ECS Service: OFF (desiredCount=0)
# ⚠️  ALB: OFF (deletado)
# ⚠️  RDS: OFF (stopped)
# ✅ 💰 Custo Estimado: ~$0/mês (apenas storage)
```

### Religar Após Férias

```bash
# Ligar TUDO
./scripts/toggle-infra.sh on

# Aguardar ~7 minutos
sleep 420

# Verificar status
./scripts/toggle-infra.sh status

# Resultado esperado:
# ✅ ECS Service: ON (desiredCount=1, runningCount=1)
# ⚠️  ALB: OFF (precisa recriar via Terraform)
# ✅ RDS: ON (available)
```

### Recriar ALB (Após Desligamento)

O ALB precisa ser recriado via Terraform quando você liga a infraestrutura:

```bash
cd terraform/ecs

# Verificar o que será criado
terraform plan

# Aplicar (recriar ALB + target groups)
terraform apply -auto-approve

# Aguardar ~5 minutos
# Verificar ALB criado
aws elbv2 describe-load-balancers --region sa-east-1 | grep vanessa-mudanca-alb
```

---

## 🔍 Troubleshooting

### Problema: RDS não para

**Sintoma:**
```
RDS: TRANSITIONING (stopping)
```

**Solução:**
- Aguarde 2-3 minutos
- RDS leva tempo para parar
- Verifique status: `aws rds describe-db-instances --db-instance-identifier cliente-core-prod --region sa-east-1`

### Problema: ECS tasks não iniciam

**Sintoma:**
```
ECS Service: ON (desiredCount=1, runningCount=0)
```

**Solução:**
1. Verificar logs no CloudWatch:
   ```bash
   aws logs tail /ecs/cliente-core-prod --follow --region sa-east-1
   ```

2. Verificar health checks do ALB:
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn <TARGET_GROUP_ARN> \
     --region sa-east-1
   ```

3. Verificar RDS está rodando:
   ```bash
   ./scripts/toggle-infra.sh status
   ```

### Problema: ALB não existe após ligar

**Sintoma:**
```
⚠️  ALB: OFF (deletado)
```

**Solução:**
- ALB precisa ser recriado via Terraform
- Veja seção "Recriar ALB" acima

---

## ⏰ Automação com Cron

Você pode automatizar o desligamento noturno com cron:

```bash
# Editar crontab
crontab -e

# Adicionar desligamento às 19:00 (dias úteis)
0 19 * * 1-5 cd /Users/diegorighi/Desenvolvimento/yukam-drighi && ./scripts/toggle-infra.sh off

# Adicionar ligamento às 08:30 (dias úteis)
30 8 * * 1-5 cd /Users/diegorighi/Desenvolvimento/yukam-drighi && ./scripts/toggle-infra.sh on
```

**💡 Dica:** Use EventBridge + Lambda para automação na AWS (mais confiável que cron local).

---

## 📝 Notas Importantes

1. **ALB não é religado automaticamente**
   - Precisa ser recriado via Terraform
   - Use `terraform apply` no diretório `terraform/ecs/`

2. **RDS reinicia automaticamente após 7 dias**
   - AWS limita `stop-db-instance` a 7 dias
   - Se ficar mais de 7 dias parado, AWS reinicia automaticamente
   - Solução: Use snapshot + delete (para paradas longas)

3. **ECS tasks levam ~2 minutos para iniciar**
   - Inclui pull da imagem Docker do ECR
   - Health checks (startPeriod de 90 segundos)
   - Liquibase migrations

4. **Storage continua cobrando mesmo OFF**
   - ECR images: ~$0.10/GB-mês
   - RDS storage: ~$0.115/GB-mês (mesmo parado)
   - CloudWatch Logs: ~$0.03/GB-mês

5. **NAT Gateway não está gerenciado**
   - Se você tiver NAT Gateway, ele continuará cobrando
   - Custo: ~$32/mês (fixo)
   - Deletar manualmente se não usar

---

## 🚀 Roadmap Futuro

- [ ] Gerenciar NAT Gateway (se existir)
- [ ] Integração com Slack (notificações)
- [ ] Dashboard web com status visual
- [ ] Automação via EventBridge + Lambda
- [ ] Snapshot automático do RDS antes de desligar
- [ ] Suporte a múltiplos ambientes (dev, staging, prod)

---

## 📞 Contato

**Responsável:** Diego Righi
**Repositório:** yukam-drighi (privado)
**Última atualização:** 2025-11-06

---

## ✅ Checklist de Uso

Antes de desligar pela primeira vez:

- [ ] Fiz backup do banco de dados (se necessário)
- [ ] Não tenho usuários ativos na aplicação
- [ ] Não tenho processos críticos rodando
- [ ] Tenho o Terraform configurado para recriar ALB
- [ ] Sei que RDS reinicia automaticamente após 7 dias

Antes de religar:

- [ ] Tenho tempo para esperar ~7 minutos
- [ ] Vou recriar o ALB via Terraform (se necessário)
- [ ] Sei que precisarei validar aplicação após ligar
