# GitHub Actions - Workflows do Monorepo

Este diretório contém os workflows de CI/CD para o monorepo **yukam-drighi**.

---

## 📋 Workflows Disponíveis

### 1. CI Pipeline (`ci.yml`)

**Trigger:** Pull Requests e Push para `develop`

**O que faz:**
- ✅ Detecta automaticamente quais serviços foram modificados
- ✅ Roda testes apenas dos serviços alterados (otimiza tempo de CI)
- ✅ Build e coverage para cada microserviço
- ✅ Lint de código Terraform/Infra
- ✅ Validação de builds Docker
- ✅ Scan de vulnerabilidades com Trivy

**Jobs:**
1. `detect-changes` - Detecta quais paths foram modificados
2. `test-cliente-core` - Testes do cliente-core (se modificado)
3. `test-vendas-core` - Testes do vendas-core (se modificado)
4. `lint-infrastructure` - Lint de Terraform (se infra modificada)
5. `validate-docker-builds` - Build e scan Docker
6. `ci-summary` - Resumo de todos os jobs

---

### 2. Deploy to Production (`deploy-production.yml`)

**Trigger:** Push para `main` ou workflow manual

**O que faz:**
- 🚀 Deploy automático para ECS na AWS
- 🔍 Detecta quais serviços mudaram e faz deploy incremental
- 🐳 Build da imagem Docker e push para ECR
- 📦 Atualiza Task Definition do ECS
- ✅ Health checks automáticos após deploy
- 📊 Resumo do deployment no GitHub Actions

**Jobs:**
1. `detect-changes` - Detecta serviços modificados
2. `deploy-cliente-core` - Deploy do cliente-core para ECS
3. `deploy-vendas-core` - Deploy do vendas-core para ECS (futuro)
4. `notify` - Notificações de status (opcional: Slack/Discord)

**Ambientes:**
- `production` - Requer aprovação manual no GitHub (configurável)

---

## 🔐 Secrets Necessários

Configure os seguintes secrets em **Settings → Secrets and variables → Actions → New repository secret**:

### AWS Credentials

| Secret | Descrição | Como Obter |
|--------|-----------|------------|
| `AWS_ACCESS_KEY_ID` | Access Key do usuário IAM para deploy | AWS Console → IAM → Users → Security credentials |
| `AWS_SECRET_ACCESS_KEY` | Secret Key do usuário IAM | AWS Console → IAM → Users → Security credentials |
| `AWS_ACCOUNT_ID` | ID da conta AWS (12 dígitos) | AWS Console → Account → Account ID |

**Permissões IAM necessárias:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecs:RegisterTaskDefinition",
        "ecs:DescribeTaskDefinition",
        "ecs:DescribeServices",
        "ecs:UpdateService",
        "elbv2:DescribeTargetGroups",
        "elbv2:DescribeLoadBalancers",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
```

### Optional Secrets (Codecov, Slack, etc.)

| Secret | Descrição | Usado Por |
|--------|-----------|-----------|
| `CODECOV_TOKEN` | Token para upload de coverage | CI Pipeline |
| `SLACK_WEBHOOK` | Webhook para notificações Slack | Deploy Pipeline |

---

## 🏗️ Infraestrutura AWS Necessária

Antes de rodar o workflow de deploy, você precisa provisionar:

### 1. ECR Repositories

```bash
# Criar repositórios ECR
aws ecr create-repository --repository-name cliente-core --region sa-east-1
aws ecr create-repository --repository-name vendas-core --region sa-east-1
```

### 2. ECS Cluster

```bash
# Criar cluster ECS
aws ecs create-cluster --cluster-name vanessa-mudanca-cluster --region sa-east-1
```

### 3. ECS Task Definition (exemplo para cliente-core)

```json
{
  "family": "cliente-core",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [
    {
      "name": "cliente-core",
      "image": "<AWS_ACCOUNT_ID>.dkr.ecr.sa-east-1.amazonaws.com/cliente-core:latest",
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
        "command": ["CMD-SHELL", "curl -f http://localhost:8081/api/clientes/actuator/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

### 4. ECS Service

```bash
# Criar serviço ECS
aws ecs create-service \
  --cluster vanessa-mudanca-cluster \
  --service-name cliente-core-service \
  --task-definition cliente-core \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx,subnet-yyy],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:sa-east-1:xxx:targetgroup/cliente-core-tg/xxx,containerName=cliente-core,containerPort=8081"
```

**Ou use Terraform** (recomendado):
- Os arquivos Terraform estão em `terraform/shared/`
- Execute: `terraform init && terraform plan && terraform apply`

---

## 🚀 Como Usar

### Deploy Manual (workflow_dispatch)

1. Vá em **Actions** → **Deploy to Production (ECS)**
2. Clique em **Run workflow**
3. Escolha qual serviço deployar:
   - `all` - Deploy de todos os serviços
   - `cliente-core` - Deploy apenas do cliente-core
   - `vendas-core` - Deploy apenas do vendas-core
4. Clique em **Run workflow**

### Deploy Automático (push to main)

```bash
# Fazer merge de uma feature branch
git checkout main
git pull origin main
git merge feature/nova-feature
git push origin main

# O workflow será acionado automaticamente
# Apenas os serviços modificados serão deployed
```

### Testar CI em Pull Request

```bash
# Criar PR para main ou develop
git checkout -b feature/minha-feature
git add .
git commit -m "feat: minha feature"
git push origin feature/minha-feature

# Abrir PR no GitHub
# O workflow CI rodará automaticamente
```

---

## 🔍 Detecção Inteligente de Mudanças

Os workflows detectam automaticamente quais serviços foram modificados:

### Paths Monitorados

| Path | Serviço | Ação |
|------|---------|------|
| `services/cliente-core/**` | cliente-core | Build + Test + Deploy |
| `services/vendas-core/**` | vendas-core | Build + Test + Deploy |
| `infrastructure/**` | Infra | Lint Terraform |
| `terraform/**` | Infra | Lint Terraform + Deploy All |
| `docker-compose.yml` | All | Deploy All Services |

### Exemplo

```bash
# Mudança apenas no cliente-core
git diff HEAD~1 HEAD
# diff services/cliente-core/src/main/java/...

# Resultado: Apenas cliente-core será testado e deployed
```

---

## 📊 Monitoramento e Logs

### GitHub Actions

- **Actions Tab:** Histórico completo de todos os workflows
- **Summary:** Cada workflow gera um resumo visual com status
- **Artifacts:** JARs e test reports ficam disponíveis por 7 dias

### AWS CloudWatch

```bash
# Ver logs do ECS
aws logs tail /ecs/cliente-core --follow --region sa-east-1

# Query estruturada (JSON logs)
aws logs filter-log-events \
  --log-group-name /ecs/cliente-core \
  --filter-pattern '{ $.severity = "ERROR" }' \
  --region sa-east-1
```

### Health Checks

```bash
# Health check manual
curl https://seu-alb.sa-east-1.elb.amazonaws.com/api/clientes/actuator/health

# Resposta esperada
{
  "status": "UP",
  "components": {
    "db": { "status": "UP" },
    "diskSpace": { "status": "UP" }
  }
}
```

---

## 🛠️ Troubleshooting

### Erro: "No changes detected, skipping deployment"

**Causa:** Nenhum arquivo dos serviços foi modificado no último commit.

**Solução:** Use workflow manual (`workflow_dispatch`) para forçar deploy:
```bash
gh workflow run deploy-production.yml -f service=all
```

---

### Erro: "Task failed with error: ResourceInitializationError"

**Causa:** Task Definition com imagem inválida ou falta de permissões IAM.

**Solução:**
1. Verifique se a imagem existe no ECR:
   ```bash
   aws ecr describe-images --repository-name cliente-core --region sa-east-1
   ```
2. Verifique permissões IAM do ECS Task Execution Role

---

### Erro: "Health check failed after 5 attempts"

**Causa:** Aplicação não subiu corretamente ou ALB não está roteando para as tasks.

**Solução:**
1. Verifique logs do ECS:
   ```bash
   aws logs tail /ecs/cliente-core --follow --region sa-east-1
   ```
2. Verifique se o Target Group está healthy:
   ```bash
   aws elbv2 describe-target-health --target-group-arn <ARN>
   ```

---

### Erro: "Docker build failed: no such file or directory"

**Causa:** JAR não foi buildado antes do Docker build.

**Solução:** O workflow já garante que o Maven build aconteça antes. Se ocorrer, verifique se o `pom.xml` está correto:
```bash
cd services/cliente-core
mvn clean package -DskipTests
ls -la target/*.jar
```

---

## 🔄 Rollback

Se o deploy falhar ou introduzir bugs:

### Rollback via AWS Console

1. ECS → Clusters → vanessa-mudanca-cluster
2. Services → cliente-core-service → Update
3. Task Definition → Selecione revisão anterior
4. Update Service

### Rollback via CLI

```bash
# Listar revisões anteriores
aws ecs list-task-definitions --family-prefix cliente-core --region sa-east-1

# Fazer rollback para revisão anterior
aws ecs update-service \
  --cluster vanessa-mudanca-cluster \
  --service cliente-core-service \
  --task-definition cliente-core:5 \
  --region sa-east-1
```

### Rollback via Git Revert

```bash
# Reverter commit problemático
git revert <commit-sha>
git push origin main

# O workflow fará deploy da versão anterior automaticamente
```

---

## 📚 Referências

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

**Última atualização:** 2025-11-05
**Versão:** 1.0.0
