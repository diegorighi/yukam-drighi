# 🚀 Guia de Implementação CI/CD - VaNessa Mudança

Este documento fornece um roadmap completo para implementar a pipeline CI/CD do zero.

---

## 📋 Visão Geral

### O Que Foi Criado

✅ **GitHub Actions Workflows:**
- `.github/workflows/ci.yml` - Pipeline de CI para PRs e develop
- `.github/workflows/deploy-production.yml` - Deploy automático para ECS

✅ **Infraestrutura como Código:**
- `terraform/ecs/main.tf` - Módulo completo para ECS + ECR + ALB
- `terraform/ecs/terraform.tfvars.example` - Template de variáveis

✅ **Documentação:**
- `.github/README.md` - Overview dos workflows
- `.github/SECRETS_SETUP.md` - Configuração de secrets do GitHub
- `.github/INFRASTRUCTURE_SETUP.md` - Setup manual da infra AWS
- `terraform/ecs/README.md` - Guia do Terraform

### Arquitetura CI/CD

```
┌─────────────────────────────────────────────────────────────────┐
│                    Developer Workflow                            │
└─────────────────────────┬───────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
   [Feature PR]      [Push develop]   [Push main]
        │                 │                 │
        ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   CI Tests   │  │   CI Tests   │  │  Production  │
│   - Build    │  │   - Build    │  │    Deploy    │
│   - Tests    │  │   - Tests    │  │   (ECS)      │
│   - Coverage │  │   - Docker   │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
```

---

## 🎯 Implementação - Roadmap Completo

### Fase 1: Preparação (1-2 horas)

#### ✅ 1.1 Criar Usuário IAM para CI/CD

```bash
# 1. Acessar AWS Console → IAM → Users → Create user
# Nome: github-actions-cicd
# Access type: Programmatic access

# 2. Criar policy customizada
# Ver JSON completo em: .github/SECRETS_SETUP.md

# 3. Criar Access Key e COPIAR as credenciais
```

**📄 Documentação:** `.github/SECRETS_SETUP.md` (seção 1)

---

#### ✅ 1.2 Configurar Secrets no GitHub

```bash
# 1. Ir em: Settings → Secrets and variables → Actions
# 2. Adicionar secrets:
#    - AWS_ACCESS_KEY_ID
#    - AWS_SECRET_ACCESS_KEY
#    - AWS_ACCOUNT_ID

# 3. (Opcional) Adicionar:
#    - CODECOV_TOKEN
#    - SLACK_WEBHOOK
```

**📄 Documentação:** `.github/SECRETS_SETUP.md` (seção 2-5)

---

### Fase 2: Infraestrutura AWS (2-4 horas)

#### Opção A: Terraform (Recomendado - Automatizado)

```bash
cd terraform/ecs

# 1. Criar VPC primeiro (se não tiver)
# Opção: usar Console AWS ou módulo terraform-aws-modules/vpc

# 2. Configurar variáveis
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Preencher com seus valores

# 3. Criar secret do banco de dados
aws secretsmanager create-secret \
  --name vanessa/db-password \
  --secret-string "YOUR_STRONG_PASSWORD" \
  --region sa-east-1

# 4. Aplicar Terraform
terraform init
terraform plan
terraform apply  # Confirmar com 'yes'

# 5. Anotar outputs (ALB DNS, ECR URLs, etc.)
terraform output
```

**Tempo:** ~10 minutos para Terraform criar recursos

**📄 Documentação:** `terraform/ecs/README.md`

---

#### Opção B: Console AWS (Manual - Não Recomendado)

Se preferir criar recursos manualmente via console:

**📄 Documentação:** `.github/INFRASTRUCTURE_SETUP.md`

**Tempo:** ~2-4 horas (muitos cliques!)

---

### Fase 3: Primeiro Deploy Manual (30 minutos)

Antes de automatizar, vamos fazer um deploy manual para validar:

#### ✅ 3.1 Build e Push da Imagem Docker

```bash
cd services/cliente-core

# 1. Build do JAR
mvn clean package -DskipTests

# 2. Login no ECR
aws ecr get-login-password --region sa-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.sa-east-1.amazonaws.com

# 3. Build da imagem Docker
docker build -t cliente-core:latest .

# 4. Tag da imagem
ECR_URL="123456789012.dkr.ecr.sa-east-1.amazonaws.com/cliente-core"
docker tag cliente-core:latest $ECR_URL:latest
docker tag cliente-core:latest $ECR_URL:v1.0.0

# 5. Push para ECR
docker push $ECR_URL:latest
docker push $ECR_URL:v1.0.0
```

---

#### ✅ 3.2 Verificar Deploy no ECS

```bash
# 1. Ver tasks rodando
aws ecs list-tasks \
  --cluster vanessa-mudanca-cluster \
  --service-name cliente-core-service \
  --region sa-east-1

# 2. Ver logs
aws logs tail /ecs/cliente-core --follow --region sa-east-1

# 3. Obter DNS do ALB
aws elbv2 describe-load-balancers \
  --names vanessa-mudanca-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text

# 4. Testar health check
curl http://vanessa-mudanca-alb-xxx.sa-east-1.elb.amazonaws.com/api/clientes/actuator/health

# Resposta esperada:
# {"status":"UP"}
```

---

### Fase 4: Habilitar CI/CD Automatizado (15 minutos)

#### ✅ 4.1 Testar CI Pipeline (Pull Request)

```bash
# 1. Criar branch de feature
git checkout -b feature/test-ci-pipeline

# 2. Fazer uma mudança simples
echo "// Test CI" >> services/cliente-core/src/main/java/README.md

# 3. Commit e push
git add .
git commit -m "test: validate CI pipeline"
git push origin feature/test-ci-pipeline

# 4. Abrir Pull Request no GitHub
gh pr create --title "Test CI Pipeline" --body "Testing automated CI"

# 5. Ver pipeline rodando em: Actions tab
```

**Resultado esperado:**
- ✅ `detect-changes` job detecta mudança em `cliente-core`
- ✅ `test-cliente-core` roda testes e build
- ✅ `validate-docker-builds` valida imagem Docker
- ✅ `ci-summary` mostra resumo

---

#### ✅ 4.2 Testar Deploy Automático (Push to Main)

```bash
# 1. Fazer merge do PR
gh pr merge --merge

# 2. Ver deploy automático em: Actions → Deploy to Production (ECS)

# 3. Acompanhar deployment
# - Build JAR
# - Build Docker image
# - Push para ECR
# - Update ECS Service
# - Health check

# 4. Verificar se nova versão está no ar
curl http://vanessa-mudanca-alb-xxx.sa-east-1.elb.amazonaws.com/api/clientes/actuator/health
```

**Tempo do deploy:** ~5-7 minutos

---

### Fase 5: Validação e Monitoramento (30 minutos)

#### ✅ 5.1 Configurar Alarmes CloudWatch

```bash
# 1. Alarme para Health Check failures
aws cloudwatch put-metric-alarm \
  --alarm-name cliente-core-unhealthy-targets \
  --alarm-description "Cliente-core has unhealthy targets" \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 60 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --region sa-east-1

# 2. Alarme para High CPU
aws cloudwatch put-metric-alarm \
  --alarm-name cliente-core-high-cpu \
  --alarm-description "Cliente-core CPU > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --region sa-east-1
```

---

#### ✅ 5.2 Testar Rollback

```bash
# Simular deploy problemático
git checkout main
echo "BREAKING_CHANGE=true" >> services/cliente-core/application.yml
git commit -am "test: simulate broken deploy"
git push origin main

# Aguardar health check falhar
# GitHub Actions vai detectar e falhar o deployment

# Fazer rollback via ECS Console:
# 1. ECS → Clusters → vanessa-mudanca-cluster
# 2. Services → cliente-core-service → Update
# 3. Task Definition → Selecionar revisão anterior
# 4. Update Service

# Ou via CLI:
aws ecs update-service \
  --cluster vanessa-mudanca-cluster \
  --service cliente-core-service \
  --task-definition cliente-core:5 \
  --region sa-east-1
```

---

## 📊 Checklist Final

### Infraestrutura AWS
- [ ] VPC criada com subnets públicas e privadas
- [ ] NAT Gateway configurado
- [ ] Security Groups criados
- [ ] ECR Repositories criados
- [ ] ECS Cluster criado
- [ ] Application Load Balancer configurado
- [ ] RDS PostgreSQL criado
- [ ] CloudWatch Log Groups criados
- [ ] IAM Roles criados (Task Execution, Task Role)

### GitHub Actions
- [ ] Secrets configurados (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ACCOUNT_ID)
- [ ] CI workflow testado (PR)
- [ ] Deploy workflow testado (push main)
- [ ] Health checks funcionando
- [ ] Logs visíveis no CloudWatch

### Documentação
- [ ] README.md atualizado com URLs do ALB
- [ ] Time treinado em workflows
- [ ] Procedimento de rollback documentado

---

## 🎓 Próximos Passos (Melhorias Futuras)

### Curto Prazo (1-2 semanas)

1. **SSL/TLS no ALB:**
   ```bash
   # Request certificate no ACM
   aws acm request-certificate \
     --domain-name api.vanessamudanca.com.br \
     --validation-method DNS \
     --region sa-east-1

   # Adicionar Listener HTTPS no ALB
   ```

2. **Route 53 DNS:**
   ```bash
   # Criar Hosted Zone
   # Criar Record api.vanessamudanca.com.br → ALB
   ```

3. **Notificações Slack:**
   - Descomentar seção no `deploy-production.yml`
   - Configurar webhook

---

### Médio Prazo (1 mês)

1. **Blue/Green Deployment:**
   - Usar CodeDeploy para zero-downtime deploys
   - Rollback automático em caso de falha

2. **Canary Deployments:**
   - Liberar nova versão para 10% do tráfego
   - Aumentar gradualmente

3. **Multi-Region:**
   - Replicar infra em `us-east-1`
   - CloudFront para geo-routing

---

### Longo Prazo (3-6 meses)

1. **Observability Stack:**
   - Prometheus + Grafana
   - Distributed Tracing (Jaeger)
   - Alerting avançado

2. **Cost Optimization:**
   - Fargate Spot para ambientes não-prod
   - Schedule para desligar tasks fora do horário
   - Reserved Instances para RDS

3. **Disaster Recovery:**
   - Backup automático de RDS para S3
   - Cross-region replication
   - Testes de DR trimestrais

---

## 🆘 Suporte e Troubleshooting

### Problema: CI Pipeline falha com "No changes detected"

**Causa:** Mudanças não estão em `services/cliente-core/**`

**Solução:** Verificar paths no workflow ou usar `workflow_dispatch` manual

---

### Problema: Deploy falha com "Task failed to start"

**Causa:** Imagem Docker não existe ou Task Definition incorreta

**Debug:**
```bash
# Ver eventos do serviço
aws ecs describe-services \
  --cluster vanessa-mudanca-cluster \
  --services cliente-core-service \
  --region sa-east-1 \
  --query 'services[0].events[0:5]'

# Ver logs do container
aws logs tail /ecs/cliente-core --follow --region sa-east-1
```

---

### Problema: Health check sempre falha

**Causa:** Security Group bloqueando tráfego do ALB para ECS

**Solução:**
```bash
# Verificar Security Group do ECS Tasks
# Deve permitir tráfego da porta 8081 vindo do SG do ALB
```

---

## 📚 Documentação Relacionada

- [README Principal](.github/README.md)
- [Configuração de Secrets](.github/SECRETS_SETUP.md)
- [Setup de Infraestrutura](.github/INFRASTRUCTURE_SETUP.md)
- [Guia Terraform](terraform/ecs/README.md)

---

## 🎉 Conclusão

Parabéns! Você agora tem uma pipeline CI/CD completa e automatizada para os microserviços do VaNessa Mudança.

**O que conquistamos:**
- ✅ Deploy automático em cada push para `main`
- ✅ CI completo em PRs com testes e coverage
- ✅ Infraestrutura como código com Terraform
- ✅ Observabilidade com CloudWatch Logs
- ✅ Auto-scaling baseado em CPU/Memory
- ✅ Health checks e deployment safety

**Próximos deploys serão assim:**

```bash
# 1. Desenvolver feature
git checkout -b feature/nova-funcionalidade

# 2. Desenvolver e testar localmente
mvn spring-boot:run

# 3. Push e PR
git push origin feature/nova-funcionalidade
gh pr create

# 4. CI roda automaticamente ✅

# 5. Merge para main
gh pr merge

# 6. Deploy automático para produção 🚀

# 7. Health checks validam deployment ✅

# 8. Nova versão no ar! 🎉
```

---

**Última atualização:** 2025-11-05
**Versão:** 1.0.0
**Autor:** Claude Code
