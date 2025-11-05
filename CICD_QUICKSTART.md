# 🚀 CI/CD QuickStart - Checklist de Implementação

Guia rápido para colocar a pipeline CI/CD no ar em **menos de 1 hora**.

---

## ⏱️ Tempo Total Estimado: 45-60 minutos

---

## ✅ Fase 1: Setup GitHub (10 min)

### 1.1 Criar Usuário IAM na AWS

```bash
# AWS Console → IAM → Users → Create user
# Nome: github-actions-cicd
# Access type: Programmatic access
# Policy: Criar customizada (copiar de .github/SECRETS_SETUP.md seção 1)
```

- [ ] Usuário IAM criado
- [ ] Access Key copiada
- [ ] Secret Key copiada

---

### 1.2 Configurar Secrets no GitHub

```bash
# GitHub → Settings → Secrets and variables → Actions → New secret
```

Adicionar 3 secrets:

- [ ] `AWS_ACCESS_KEY_ID` = sua access key
- [ ] `AWS_SECRET_ACCESS_KEY` = sua secret key
- [ ] `AWS_ACCOUNT_ID` = ID da conta (12 dígitos)

**Como obter Account ID:**
```bash
aws sts get-caller-identity --query Account --output text
```

---

## ✅ Fase 2: Infraestrutura AWS (25 min)

### Opção A: Terraform (Recomendado - 10 min)

```bash
cd terraform/ecs

# 1. Copiar exemplo de variáveis
cp terraform.tfvars.example terraform.tfvars

# 2. Editar com seus valores (VPC, subnets, RDS)
vim terraform.tfvars

# 3. Criar secret do DB
aws secretsmanager create-secret \
  --name vanessa/db-password \
  --secret-string "SuaSenhaForteAqui123!" \
  --region sa-east-1

# 4. Aplicar Terraform
terraform init
terraform plan
terraform apply  # Confirmar com 'yes'

# 5. Anotar output (ALB DNS)
terraform output
```

Checklist:
- [ ] `terraform.tfvars` configurado
- [ ] Secret do DB criado no Secrets Manager
- [ ] `terraform apply` executado com sucesso
- [ ] ALB DNS anotado

---

### Opção B: Manual (Não Recomendado - 2-4 horas)

Se não quiser usar Terraform, siga o guia manual:

📄 **Documentação:** `.github/INFRASTRUCTURE_SETUP.md`

---

## ✅ Fase 3: Primeiro Deploy Manual (15 min)

Validar que tudo funciona antes de automatizar:

```bash
cd services/cliente-core

# 1. Build JAR
mvn clean package -DskipTests

# 2. Login ECR
AWS_ACCOUNT_ID="123456789012"  # Seu account ID
aws ecr get-login-password --region sa-east-1 | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.sa-east-1.amazonaws.com

# 3. Build Docker
docker build -t cliente-core:latest .

# 4. Tag e Push
ECR_URL="$AWS_ACCOUNT_ID.dkr.ecr.sa-east-1.amazonaws.com/cliente-core"
docker tag cliente-core:latest $ECR_URL:latest
docker push $ECR_URL:latest

# 5. Aguardar ECS atualizar (2-3 min)
aws ecs wait services-stable \
  --cluster vanessa-mudanca-cluster \
  --services cliente-core-service \
  --region sa-east-1

# 6. Testar
ALB_DNS="seu-alb-dns.sa-east-1.elb.amazonaws.com"
curl http://$ALB_DNS/api/clientes/actuator/health
```

Checklist:
- [ ] JAR buildado
- [ ] Imagem no ECR
- [ ] ECS Service rodando (2 tasks)
- [ ] Health check retorna `{"status":"UP"}`

---

## ✅ Fase 4: Testar CI/CD (10 min)

### 4.1 Testar CI (Pull Request)

```bash
# 1. Criar branch
git checkout -b feature/test-ci

# 2. Fazer mudança
echo "// CI test" >> services/cliente-core/README.md

# 3. Push
git add .
git commit -m "test: CI pipeline"
git push origin feature/test-ci

# 4. Criar PR
gh pr create --title "Test CI" --body "Testing CI pipeline"
```

**Aguardar 3-5 min e verificar:**
- [ ] CI workflow rodou automaticamente
- [ ] Testes passaram
- [ ] Build Docker passou
- [ ] Status check ✅ no PR

---

### 4.2 Testar Deploy (Push to Main)

```bash
# 1. Fazer merge
gh pr merge --merge

# 2. Verificar Actions tab
# GitHub → Actions → Deploy to Production (ECS)
```

**Aguardar 5-7 min e verificar:**
- [ ] Build rodou
- [ ] Push para ECR
- [ ] ECS Service atualizado
- [ ] Health check passou
- [ ] Nova versão no ar ✅

---

## ✅ Validação Final (5 min)

### Teste End-to-End

```bash
# 1. Verificar tasks rodando
aws ecs list-tasks \
  --cluster vanessa-mudanca-cluster \
  --service-name cliente-core-service \
  --region sa-east-1

# 2. Ver logs
aws logs tail /ecs/cliente-core --follow --region sa-east-1

# 3. Testar API
curl http://seu-alb-dns/api/clientes/actuator/health
curl http://seu-alb-dns/api/clientes/actuator/info

# 4. Ver métricas no CloudWatch
# AWS Console → CloudWatch → Container Insights → vanessa-mudanca-cluster
```

Checklist final:
- [ ] 2+ tasks rodando no ECS
- [ ] Logs aparecem no CloudWatch
- [ ] Health check retorna 200 OK
- [ ] Metrics visíveis no Container Insights

---

## 🎉 Pronto! CI/CD Funcionando

### O que você conseguiu em menos de 1 hora:

✅ **CI Pipeline:** Testes automáticos em PRs
✅ **CD Pipeline:** Deploy automático para ECS
✅ **Infraestrutura:** ECS + ECR + ALB + Auto Scaling
✅ **Observability:** CloudWatch Logs + Metrics
✅ **Health Checks:** Validação automática de deploys

---

## 🔄 Workflow Diário (pós-setup)

```bash
# 1. Nova feature
git checkout -b feature/minha-feature

# 2. Desenvolver
# ... código ...

# 3. Commit e push
git push origin feature/minha-feature

# 4. PR (CI roda automaticamente)
gh pr create

# 5. Merge (Deploy automático)
gh pr merge

# 6. ✅ Nova versão no ar em 5-7 min!
```

---

## 📚 Documentação Completa

Para detalhes, consulte:

1. **Overview:** `.github/README.md`
2. **Secrets:** `.github/SECRETS_SETUP.md`
3. **Infraestrutura:** `.github/INFRASTRUCTURE_SETUP.md`
4. **Terraform:** `terraform/ecs/README.md`
5. **Guia Completo:** `docs/CI_CD_IMPLEMENTATION_GUIDE.md`

---

## 🆘 Problemas Comuns

### CI não detecta mudanças

```bash
# Usar workflow manual
gh workflow run ci.yml
```

---

### Deploy falha no health check

```bash
# Ver logs do container
aws logs tail /ecs/cliente-core --follow --region sa-east-1

# Ver eventos do serviço
aws ecs describe-services \
  --cluster vanessa-mudanca-cluster \
  --services cliente-core-service \
  --query 'services[0].events[0:5]' \
  --region sa-east-1
```

---

### Terraform apply falha

```bash
# Ver plano detalhado
terraform plan -out=tfplan

# Aplicar step-by-step
terraform apply -target=aws_ecr_repository.cliente_core
terraform apply -target=aws_ecs_cluster.main
# ...
```

---

## 💡 Dicas

1. **Use Terraform** - 10x mais rápido que console AWS
2. **Teste local primeiro** - `mvn spring-boot:run` antes de fazer PR
3. **Monitore logs** - `aws logs tail` durante deploys
4. **Valide secrets** - Teste IAM credentials antes de configurar

---

## 🎯 Próximos Passos (Opcional)

Depois que tudo estiver funcionando:

1. [ ] Configurar SSL/TLS (ACM certificate)
2. [ ] Adicionar Route 53 DNS
3. [ ] Configurar notificações Slack
4. [ ] Adicionar CloudWatch Alarms
5. [ ] Implementar Blue/Green deployment

---

**Última atualização:** 2025-11-05
**Tempo de implementação:** < 1 hora
**Dificuldade:** ⭐⭐⭐ Intermediário
