# ✅ Configuração do CI/CD - STATUS

## 🎉 Infraestrutura Provisionada com Sucesso!

Data: 2025-11-05  
Região: sa-east-1  
Ambiente: dev

---

## 📦 Recursos Criados na AWS

### 1. ECS Cluster
- **Nome**: vanessa-mudanca-cluster
- **Status**: ✅ ACTIVE
- **Container Insights**: Habilitado
- **Capacity Providers**: FARGATE + FARGATE_SPOT

### 2. Application Load Balancer (ALB)
- **DNS**: vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com
- **Status**: ✅ ACTIVE
- **Listener HTTP**: Porta 80
- **Target Group**: cliente-core-tg

### 3. ECR Repository
- **URL**: 530184476864.dkr.ecr.sa-east-1.amazonaws.com/cliente-core
- **Status**: ✅ Existente (compartilhado com terraform/shared)
- **Lifecycle Policy**: Mantém últimas 10 imagens

### 4. ECS Service
- **Nome**: cliente-core-service
- **Status**: ✅ ACTIVE
- **Desired Count**: 2 tasks
- **Running Count**: 0 (aguardando imagem Docker)
- **Auto Scaling**: 2-10 tasks (CPU 70%, Memory 80%)

### 5. IAM Roles
- **Task Execution Role**: ecsTaskExecutionRole (compartilhado)
- **Task Role**: clienteCoreTaskRole
- **Permissões**: ECR pull, CloudWatch Logs, Secrets Manager, S3

### 6. CloudWatch Logs
- **Log Group**: /ecs/cliente-core
- **Retention**: 30 dias

### 7. Security Groups
- **ALB SG**: sg-00953765bd3c215ff (HTTP/HTTPS from 0.0.0.0/0)
- **ECS Tasks SG**: sg-099cef1de1a838c2a (8081-8082 from ALB)

---

## ⚠️ Próximo Passo Obrigatório: Build e Push da Imagem Docker

O serviço ECS está configurado, mas as tasks não podem iniciar porque **não existe imagem no ECR**:

```bash
cd /Users/diegorighi/Desenvolvimento/yukam-drighi/services/cliente-core

# 1. Build da aplicação
mvn clean package -DskipTests

# 2. Login no ECR
aws ecr get-login-password --region sa-east-1 | \
  docker login --username AWS --password-stdin \
  530184476864.dkr.ecr.sa-east-1.amazonaws.com

# 3. Build da imagem Docker
docker build -t cliente-core .

# 4. Tag da imagem
docker tag cliente-core:latest \
  530184476864.dkr.ecr.sa-east-1.amazonaws.com/cliente-core:latest

# 5. Push para ECR
docker push 530184476864.dkr.ecr.sa-east-1.amazonaws.com/cliente-core:latest

# 6. Aguardar ECS iniciar tasks automaticamente (2-3 minutos)
aws ecs describe-services \
  --cluster vanessa-mudanca-cluster \
  --services cliente-core-service \
  --region sa-east-1 \
  --query 'services[0].runningCount'
```

---

## 🧪 Testar a Aplicação

Após as tasks estarem rodando:

```bash
# DNS do ALB
ALB_DNS="vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com"

# Testar health check
curl http://$ALB_DNS/api/clientes/actuator/health

# Testar endpoint
curl http://$ALB_DNS/api/clientes
```

---

## 🚀 CI/CD Automático Já Está Ativo!

Após o primeiro deploy manual, o CI/CD automático já está configurado:

### GitHub Actions Workflows

1. **CI Pipeline** (`.github/workflows/ci.yml`)
   - Trigger: Pull Requests para `main` ou `develop`
   - Executa: Testes, build, Docker scan

2. **Deploy to Production** (`.github/workflows/deploy-production.yml`)
   - Trigger: Push para `main`
   - Executa: Build → Push ECR → Update ECS → Health Check

### Workflow de Desenvolvimento

```bash
# Criar branch de feature
git checkout -b feature/nova-funcionalidade

# Desenvolver e fazer commit
git add .
git commit -m "feat: adiciona nova funcionalidade"

# Push e criar PR
git push origin feature/nova-funcionalidade
gh pr create

# CI roda automaticamente ✅
# Após merge, deploy automático para ECS ✅
```

---

## 📊 Outputs do Terraform

```
alb_dns_name = "vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com"
cliente_core_service_name = "cliente-core-service"
ecr_repository_url_cliente_core = "530184476864.dkr.ecr.sa-east-1.amazonaws.com/cliente-core"
ecr_repository_url_vendas_core = "530184476864.dkr.ecr.sa-east-1.amazonaws.com/vendas-core"
ecs_cluster_name = "vanessa-mudanca-cluster"
```

---

## 🔍 Monitoramento

### CloudWatch Logs
```bash
aws logs tail /ecs/cliente-core --follow --region sa-east-1
```

### ECS Service Events
```bash
aws ecs describe-services \
  --cluster vanessa-mudanca-cluster \
  --services cliente-core-service \
  --region sa-east-1 \
  --query 'services[0].events[0:5]'
```

### Task Status
```bash
aws ecs list-tasks \
  --cluster vanessa-mudanca-cluster \
  --service-name cliente-core-service \
  --region sa-east-1
```

---

## 💰 Custos Estimados (Dev)

```
ECS Fargate (2 tasks)       ~$30/mês
Application Load Balancer   ~$25/mês
CloudWatch Logs             ~$3/mês
ECR Storage                 ~$1/mês
GitHub Actions              ~$0/mês (dentro do free tier)
─────────────────────────────────────
TOTAL                       ~$60/mês
```

---

## ✅ Checklist de Validação

- [x] Terraform infrastructure provisionada
- [x] ECS Cluster criado
- [x] ALB configurado
- [x] Security Groups configurados
- [x] IAM Roles criados
- [x] CloudWatch Logs configurados
- [x] Auto Scaling configurado
- [x] GitHub Actions workflows criados
- [x] GitHub Secrets configurados
- [ ] **Imagem Docker no ECR** ← PRÓXIMO PASSO
- [ ] ECS Tasks rodando
- [ ] Health check ALB funcionando
- [ ] CI/CD automático testado

---

## 🆘 Troubleshooting

### Tasks não estão iniciando?
```bash
# Verificar eventos do serviço
aws ecs describe-services \
  --cluster vanessa-mudanca-cluster \
  --services cliente-core-service \
  --region sa-east-1 \
  --query 'services[0].events[0:5]'

# Verificar status das tasks
aws ecs list-tasks \
  --cluster vanessa-mudanca-cluster \
  --service-name cliente-core-service \
  --region sa-east-1

# Ver logs de uma task específica
aws logs tail /ecs/cliente-core --follow --region sa-east-1
```

### ALB retornando 503?
- Tasks ainda não estão healthy
- Aguardar 2-3 minutos após deploy
- Verificar se health check endpoint está correto

---

**Status Atual**: ✅ Infraestrutura Pronta | ⏳ Aguardando Primeira Imagem Docker

**Próximo Comando**:
```bash
cd services/cliente-core && mvn clean package -DskipTests && \
aws ecr get-login-password --region sa-east-1 | docker login --username AWS --password-stdin 530184476864.dkr.ecr.sa-east-1.amazonaws.com && \
docker build -t cliente-core . && \
docker tag cliente-core:latest 530184476864.dkr.ecr.sa-east-1.amazonaws.com/cliente-core:latest && \
docker push 530184476864.dkr.ecr.sa-east-1.amazonaws.com/cliente-core:latest
```
