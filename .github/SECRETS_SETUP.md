# Configuração de Secrets - GitHub Actions

Guia passo a passo para configurar todos os secrets necessários para os workflows de CI/CD.

---

## 📋 Checklist de Secrets

- [ ] `AWS_ACCESS_KEY_ID` - Credencial AWS para deploy
- [ ] `AWS_SECRET_ACCESS_KEY` - Credencial AWS para deploy
- [ ] `AWS_ACCOUNT_ID` - ID da conta AWS (12 dígitos)
- [ ] `CODECOV_TOKEN` (opcional) - Upload de coverage
- [ ] `SLACK_WEBHOOK` (opcional) - Notificações Slack

---

## 1️⃣ Criar Usuário IAM para CI/CD

### Passo 1: Acessar IAM Console

1. Acesse [AWS Console](https://console.aws.amazon.com/)
2. Vá em **IAM** → **Users** → **Add users**

### Passo 2: Configurar Usuário

- **User name:** `github-actions-cicd`
- **Access type:** ✅ Access key - Programmatic access
- **Permissions:** Attach existing policies directly
  - Criar policy customizada (JSON abaixo)

### Passo 3: Criar Policy Customizada

**Nome da Policy:** `GitHubActionsECSDeployPolicy`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAccess",
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
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSAccess",
      "Effect": "Allow",
      "Action": [
        "ecs:RegisterTaskDefinition",
        "ecs:DeregisterTaskDefinition",
        "ecs:DescribeTaskDefinition",
        "ecs:DescribeServices",
        "ecs:UpdateService",
        "ecs:ListServices",
        "ecs:ListTasks",
        "ecs:DescribeTasks",
        "ecs:DescribeClusters",
        "ecs:ListClusters"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LoadBalancerAccess",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeRules"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::*:role/ecsTaskExecutionRole",
        "arn:aws:iam::*:role/*-task-role"
      ]
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/ecs/*"
    }
  ]
}
```

### Passo 4: Criar Access Key

1. Após criar o usuário, vá em **Security credentials**
2. Clique em **Create access key**
3. **Use case:** Application running outside AWS
4. Clique em **Next** → **Create access key**
5. ⚠️ **IMPORTANTE:** Copie `Access key ID` e `Secret access key` (você só verá uma vez!)

---

## 2️⃣ Configurar Secrets no GitHub

### Passo 1: Acessar Settings

1. Vá no repositório: `https://github.com/seu-usuario/yukam-drighi`
2. **Settings** → **Secrets and variables** → **Actions**
3. Clique em **New repository secret**

### Passo 2: Adicionar AWS Secrets

#### Secret 1: AWS_ACCESS_KEY_ID

- **Name:** `AWS_ACCESS_KEY_ID`
- **Secret:** Cole o Access Key ID copiado do IAM
- Clique em **Add secret**

#### Secret 2: AWS_SECRET_ACCESS_KEY

- **Name:** `AWS_SECRET_ACCESS_KEY`
- **Secret:** Cole o Secret Access Key copiado do IAM
- Clique em **Add secret**

#### Secret 3: AWS_ACCOUNT_ID

- **Name:** `AWS_ACCOUNT_ID`
- **Secret:** ID da sua conta AWS (12 dígitos)
  - Encontre em: AWS Console → Account → Account ID
  - Exemplo: `123456789012`
- Clique em **Add secret**

---

## 3️⃣ Obter Account ID da AWS

### Método 1: AWS Console

1. Clique no seu nome no canto superior direito
2. Veja o **Account ID** (12 dígitos)

### Método 2: AWS CLI

```bash
aws sts get-caller-identity --query Account --output text
```

### Método 3: CloudShell

1. Abra AWS CloudShell (ícone no topo da console)
2. Execute:
   ```bash
   aws sts get-caller-identity --query Account --output text
   ```

---

## 4️⃣ Codecov Token (Opcional)

Se você quer tracking de coverage no Codecov:

### Passo 1: Criar Conta no Codecov

1. Acesse [codecov.io](https://codecov.io/)
2. Faça login com GitHub
3. Clique em **Add repository**
4. Selecione `yukam-drighi`

### Passo 2: Obter Token

1. Vá em **Settings** do repositório no Codecov
2. Copie o **Upload Token**

### Passo 3: Adicionar no GitHub

- **Name:** `CODECOV_TOKEN`
- **Secret:** Cole o Upload Token do Codecov
- Clique em **Add secret**

---

## 5️⃣ Slack Webhook (Opcional)

Se você quer notificações no Slack:

### Passo 1: Criar Webhook no Slack

1. Acesse [Slack API Apps](https://api.slack.com/apps)
2. Clique em **Create New App** → **From scratch**
3. **App Name:** `GitHub Actions CI/CD`
4. Selecione o workspace
5. Vá em **Incoming Webhooks** → **Activate Incoming Webhooks**
6. Clique em **Add New Webhook to Workspace**
7. Selecione o canal (ex: `#deployments`)
8. Copie a **Webhook URL**

### Passo 2: Adicionar no GitHub

- **Name:** `SLACK_WEBHOOK`
- **Secret:** Cole a Webhook URL do Slack
- Clique em **Add secret**

### Passo 3: Descomentar Notificações no Workflow

Edite `.github/workflows/deploy-production.yml`:

```yaml
# Remova os comentários desta seção
- name: Send Slack notification
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "Deployment completed"
      }
```

---

## 6️⃣ Verificar Configuração

### Teste 1: Verificar Secrets Configurados

1. Vá em **Settings** → **Secrets and variables** → **Actions**
2. Você deve ver:
   - ✅ `AWS_ACCESS_KEY_ID`
   - ✅ `AWS_SECRET_ACCESS_KEY`
   - ✅ `AWS_ACCOUNT_ID`
   - ⏭️ `CODECOV_TOKEN` (opcional)
   - ⏭️ `SLACK_WEBHOOK` (opcional)

### Teste 2: Testar AWS Credentials Localmente (opcional)

```bash
# Configurar credenciais temporariamente
export AWS_ACCESS_KEY_ID="seu-access-key"
export AWS_SECRET_ACCESS_KEY="seu-secret-key"
export AWS_DEFAULT_REGION="sa-east-1"

# Testar autenticação
aws sts get-caller-identity

# Resposta esperada:
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/github-actions-cicd"
}
```

### Teste 3: Trigger Workflow Manualmente

```bash
# Usar GitHub CLI para trigger manual
gh workflow run deploy-production.yml -f service=cliente-core

# Ou via interface web:
# Actions → Deploy to Production (ECS) → Run workflow
```

---

## 🔒 Segurança Best Practices

### Rotação de Credentials

**Recomendação:** Rotacionar Access Keys a cada 90 dias

```bash
# Criar nova Access Key para o usuário
aws iam create-access-key --user-name github-actions-cicd

# Atualizar secrets no GitHub

# Deletar Access Key antiga
aws iam delete-access-key \
  --user-name github-actions-cicd \
  --access-key-id AKIAIOSFODNN7EXAMPLE
```

### Princípio do Menor Privilégio

- ✅ Use policy customizada com apenas as permissões necessárias
- ❌ Nunca use `AdministratorAccess` ou `PowerUserAccess`

### Audit Logs

Monitore uso das credenciais:

```bash
# CloudTrail - Ver ações do usuário CI/CD
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=github-actions-cicd \
  --region sa-east-1 \
  --max-results 50
```

### Secrets Encryption

- ✅ GitHub encripta todos os secrets automaticamente (AES-256)
- ✅ Secrets nunca aparecem nos logs (são mascarados: `***`)
- ✅ Apenas workflows podem acessar secrets

---

## 🛠️ Troubleshooting

### Erro: "AccessDenied: User is not authorized to perform: ecr:GetAuthorizationToken"

**Causa:** Policy IAM não tem permissão ECR

**Solução:**
1. Vá em IAM → Users → github-actions-cicd → Permissions
2. Verifique se a policy `GitHubActionsECSDeployPolicy` está attachada
3. Verifique se o JSON da policy inclui `ecr:GetAuthorizationToken`

---

### Erro: "InvalidClientTokenId: The security token included in the request is invalid"

**Causa:** Access Key ID inválido ou expirado

**Solução:**
1. Gere nova Access Key no IAM
2. Atualize o secret `AWS_ACCESS_KEY_ID` no GitHub
3. Aguarde alguns minutos para propagação

---

### Erro: "No such object: AWS_ACCOUNT_ID"

**Causa:** Secret `AWS_ACCOUNT_ID` não foi configurado

**Solução:**
1. Obtenha o Account ID: `aws sts get-caller-identity --query Account --output text`
2. Adicione como secret no GitHub com o nome exato: `AWS_ACCOUNT_ID`

---

### Erro: "User is not authorized to perform: iam:PassRole"

**Causa:** Falta permissão para passar roles para ECS tasks

**Solução:**
Adicione à policy IAM:
```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": [
    "arn:aws:iam::*:role/ecsTaskExecutionRole",
    "arn:aws:iam::*:role/*-task-role"
  ]
}
```

---

## 📚 Referências

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [AWS ECS IAM Roles](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html)
- [Codecov Documentation](https://docs.codecov.com/docs)
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)

---

**Última atualização:** 2025-11-05
**Versão:** 1.0.0
