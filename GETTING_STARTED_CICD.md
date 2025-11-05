# 🚀 Getting Started - CI/CD em 30 Minutos

Este guia vai te levar do zero ao primeiro deploy automático em **menos de 30 minutos**.

---

## ✅ Pré-requisitos

Antes de começar, você precisa ter:

- [ ] Conta AWS com acesso de administrador
- [ ] AWS CLI instalado e configurado (`aws configure`)
- [ ] Terraform instalado (`terraform --version`)
- [ ] Acesso de admin ao repositório GitHub
- [ ] Git configurado (`git config --list`)

---

## 📋 Passo 1: Configurar AWS IAM User (5 min)

### 1.1 Criar usuário IAM via AWS CLI

```bash
# Criar usuário
aws iam create-user --user-name github-actions-cicd

# Criar policy customizada
cat > /tmp/github-actions-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:*",
        "ecs:*",
        "elasticloadbalancing:Describe*",
        "iam:PassRole",
        "logs:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Criar policy
aws iam create-policy \
  --policy-name GitHubActionsECSDeployPolicy \
  --policy-document file:///tmp/github-actions-policy.json

# Attach policy ao usuário
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam attach-user-policy \
  --user-name github-actions-cicd \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/GitHubActionsECSDeployPolicy

# Criar access key
aws iam create-access-key --user-name github-actions-cicd
```

**⚠️ IMPORTANTE:** Copie o `AccessKeyId` e `SecretAccessKey` que apareceram!

---

### 1.2 Adicionar Secrets no GitHub

Vá em: **Settings → Secrets and variables → Actions → New repository secret**

Adicione 3 secrets:

```bash
# Secret 1
Name: AWS_ACCESS_KEY_ID
Value: <copie o AccessKeyId>

# Secret 2
Name: AWS_SECRET_ACCESS_KEY
Value: <copie o SecretAccessKey>

# Secret 3
Name: AWS_ACCOUNT_ID
Value: <seu account ID - obtido acima>
```

**Verificar Account ID:**
```bash
aws sts get-caller-identity --query Account --output text
```

✅ **Checkpoint:** Você deve ter 3 secrets configurados no GitHub.

---

## 📋 Passo 2: Provisionar Infraestrutura (10 min)

### 2.1 Obter informações da sua VPC

```bash
# Listar VPCs
aws ec2 describe-vpcs --region sa-east-1

# Se não tiver VPC, criar uma (OPCIONAL - usar VPC default é OK para teste)
# Você pode usar a VPC default que todo account AWS tem
```

### 2.2 Configurar Terraform

```bash
cd terraform/ecs

# Copiar template
cp terraform.tfvars.example terraform.tfvars

# OPÇÃO 1: Usar VPC Default (mais rápido para teste)
# Obter VPC ID default
DEFAULT_VPC=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query 'Vpcs[0].VpcId' \
  --output text \
  --region sa-east-1)

# Obter subnets da VPC default
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$DEFAULT_VPC" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,MapPublicIpOnLaunch]' \
  --output table \
  --region sa-east-1

# Editar terraform.tfvars com os valores
# Use subnets públicas (MapPublicIpOnLaunch = True) para public_subnet_ids
# Use as mesmas para private_subnet_ids (simplificado para teste)
```

**Exemplo de `terraform.tfvars` simplificado:**

```hcl
aws_region  = "sa-east-1"
environment = "dev"

vpc_id = "vpc-xxxxxxxxxx"  # Sua VPC default

# Use 2 subnets públicas da VPC default
public_subnet_ids = [
  "subnet-xxxxxxxxxx",
  "subnet-yyyyyyyyyy"
]

# Por enquanto, use as mesmas (simplificado)
private_subnet_ids = [
  "subnet-xxxxxxxxxx",
  "subnet-yyyyyyyyyy"
]

# Por enquanto, deixe vazio (vamos criar depois)
db_endpoint = "localhost"
db_password_secret_arn = "arn:aws:secretsmanager:sa-east-1:123456789012:secret:dummy"
```

### 2.3 Criar Secret Manager para DB (temporário)

```bash
# Criar secret temporário
aws secretsmanager create-secret \
  --name vanessa/db-password \
  --description "Database password" \
  --secret-string "ChangeMe123!" \
  --region sa-east-1

# Obter ARN
aws secretsmanager describe-secret \
  --secret-id vanessa/db-password \
  --region sa-east-1 \
  --query 'ARN' \
  --output text
```

Atualize `terraform.tfvars` com o ARN do secret.

### 2.4 Aplicar Terraform

```bash
# Inicializar
terraform init

# Ver o que será criado
terraform plan

# Aplicar (confirmar com 'yes')
terraform apply
```

**⏱️ Tempo:** ~5-8 minutos para criar todos os recursos.

**Anotar outputs:**
```bash
terraform output
```

Você verá:
- `alb_dns_name` - DNS do Load Balancer
- `ecr_repository_url_cliente_core` - URL do ECR
- `ecs_cluster_name` - Nome do cluster

✅ **Checkpoint:** Terraform aplicado com sucesso, recursos criados na AWS.

---

## 📋 Passo 3: Primeiro Deploy Manual (10 min)

Antes de automatizar, vamos fazer um deploy manual para validar:

```bash
cd ../../services/cliente-core

# 1. Build do JAR
mvn clean package -DskipTests

# 2. Login no ECR
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region sa-east-1 | \
  docker login --username AWS --password-stdin \
  ${ACCOUNT_ID}.dkr.ecr.sa-east-1.amazonaws.com

# 3. Build Docker image
docker build -t cliente-core:latest .

# 4. Tag da imagem
ECR_URL="${ACCOUNT_ID}.dkr.ecr.sa-east-1.amazonaws.com/cliente-core"
docker tag cliente-core:latest ${ECR_URL}:latest
docker tag cliente-core:latest ${ECR_URL}:v1.0.0

# 5. Push para ECR
docker push ${ECR_URL}:latest
docker push ${ECR_URL}:v1.0.0

echo "✅ Imagem enviada para ECR!"
echo "ECR URL: ${ECR_URL}:latest"
```

### 3.1 Verificar Deploy no ECS

```bash
# Ver tasks rodando
aws ecs list-tasks \
  --cluster vanessa-mudanca-cluster \
  --service-name cliente-core-service \
  --region sa-east-1

# Ver logs (aguarde 1-2 min para task iniciar)
aws logs tail /ecs/cliente-core --follow --region sa-east-1
```

### 3.2 Testar Health Check

```bash
# Obter DNS do ALB
cd ../../terraform/ecs
ALB_DNS=$(terraform output -raw alb_dns_name)

echo "ALB DNS: http://${ALB_DNS}"

# Aguardar 2-3 minutos para tasks ficarem healthy

# Testar health check
curl http://${ALB_DNS}/api/clientes/actuator/health

# Resposta esperada: {"status":"UP"}
```

✅ **Checkpoint:** Health check retornando 200 OK com `{"status":"UP"}`

---

## 📋 Passo 4: Testar CI/CD Automático (5 min)

Agora que validamos manualmente, vamos testar a automação:

### 4.1 Testar CI Pipeline

```bash
cd ../..

# Criar branch de teste
git checkout -b feature/test-cicd-pipeline

# Fazer uma mudança simples
echo "" >> services/cliente-core/README.md
echo "<!-- CI/CD Test -->" >> services/cliente-core/README.md

# Commit e push
git add .
git commit -m "test: validate CI/CD pipeline"
git push origin feature/test-cicd-pipeline

# Criar Pull Request
gh pr create \
  --title "Test: CI/CD Pipeline" \
  --body "Testing automated CI/CD workflows"
```

**Verificar no GitHub:**
1. Vá em **Actions** tab
2. Veja o workflow **CI Pipeline (Monorepo)** rodando
3. Aguarde ~3-5 minutos

**Esperado:**
- ✅ `detect-changes` detecta mudança em `cliente-core`
- ✅ `test-cliente-core` roda testes
- ✅ `validate-docker-builds` valida Docker build
- ✅ Status check verde no PR

### 4.2 Testar CD Pipeline (Deploy Automático)

```bash
# Fazer merge do PR
gh pr merge --merge

# Verificar deploy automático
# GitHub → Actions → Deploy to Production (ECS)
```

**Aguardar ~5-7 minutos**

**Esperado:**
- ✅ Build JAR
- ✅ Build Docker image
- ✅ Push para ECR
- ✅ Update ECS Service
- ✅ Health check passa
- ✅ Deployment summary mostra sucesso

### 4.3 Validar Nova Versão no Ar

```bash
# Verificar tasks atualizadas
aws ecs describe-services \
  --cluster vanessa-mudanca-cluster \
  --services cliente-core-service \
  --region sa-east-1 \
  --query 'services[0].deployments'

# Testar novamente
curl http://${ALB_DNS}/api/clientes/actuator/health

# Ver logs da nova versão
aws logs tail /ecs/cliente-core --follow --region sa-east-1 | grep "Started ClienteCoreApplication"
```

✅ **Checkpoint:** Deploy automático funcionou! Nova versão está no ar.

---

## 🎉 Sucesso! CI/CD Funcionando

### O que você conseguiu:

✅ **Infraestrutura AWS provisionada**
  - ECR para imagens Docker
  - ECS Fargate com 2 tasks
  - Application Load Balancer
  - Auto Scaling configurado

✅ **CI Pipeline funcionando**
  - Testes automáticos em PRs
  - Build Docker validation
  - Security scan com Trivy

✅ **CD Pipeline funcionando**
  - Deploy automático em push to main
  - Health checks pós-deploy
  - Zero downtime deployments

---

## 🔄 Workflow Diário (Daqui pra Frente)

```bash
# 1. Criar feature branch
git checkout -b feature/minha-feature

# 2. Desenvolver
# ... código ...

# 3. Commit e push
git add .
git commit -m "feat: minha feature"
git push origin feature/minha-feature

# 4. Criar PR (CI roda automaticamente)
gh pr create

# 5. Merge (Deploy automático)
gh pr merge --merge

# 6. ✅ Nova versão no ar em 5-7 minutos!
```

---

## 🐛 Troubleshooting Rápido

### Problema: Health check falha

```bash
# Ver logs do container
aws logs tail /ecs/cliente-core --follow --region sa-east-1

# Ver eventos do serviço
aws ecs describe-services \
  --cluster vanessa-mudanca-cluster \
  --services cliente-core-service \
  --region sa-east-1 \
  --query 'services[0].events[0:5]'
```

### Problema: Terraform apply falha

```bash
# Ver detalhes do erro
terraform plan -out=tfplan
terraform show tfplan

# Aplicar step-by-step
terraform apply -target=aws_ecr_repository.cliente_core
```

### Problema: GitHub Actions não roda

- Verificar se secrets estão configurados
- Verificar se workflows têm permissão de execução

---

## 📚 Próximos Passos

Agora que está funcionando:

1. **Ler documentação completa**: `docs/CI_CD_IMPLEMENTATION_GUIDE.md`
2. **Adicionar RDS real**: Provisionar PostgreSQL
3. **Configurar SSL**: Request certificate no ACM
4. **Adicionar Route 53**: DNS customizado
5. **Configurar alarmes**: CloudWatch Alarms

---

## 💡 Dicas

- Use `terraform output` para ver informações dos recursos
- Use `aws logs tail` para debug em tempo real
- GitHub Actions logs mostram cada passo do deploy
- ECS Console mostra tasks, events e deployment history

---

**Tempo total:** ~30 minutos
**Próximo deploy:** ~5 minutos (automático)

🎉 **Parabéns! Você tem CI/CD funcionando!**
