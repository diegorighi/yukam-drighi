# 🔒 Security Best Practices - Yukam Project

**Última atualização:** 2025-11-06
**Status de Segurança:** ✅ SECURE (Auditado)

---

## 📋 Índice

1. [Status da Auditoria](#status-da-auditoria)
2. [Proteção de Credenciais](#proteção-de-credenciais)
3. [AWS Cognito Security](#aws-cognito-security)
4. [Terraform State Protection](#terraform-state-protection)
5. [CI/CD Security](#cicd-security)
6. [Monitoring & Alerting](#monitoring--alerting)
7. [Incident Response](#incident-response)

---

## ✅ Status da Auditoria

**Data:** 2025-11-06
**Auditor:** Sistema Automatizado
**Resultado:** APROVADO ✅

### Checklist de Segurança

- ✅ **Nenhuma credencial real commitada no Git**
- ✅ `.gitignore` configurado corretamente
- ✅ Secrets em AWS Secrets Manager
- ✅ IAM Roles com least privilege
- ✅ Terraform state em S3 com encryption
- ✅ CI/CD usando GitHub Secrets
- ✅ Cognito com OAuth2 Client Credentials
- ✅ HTTPS enforced em produção
- ✅ Logs estruturados sem PII

### Arquivos Verificados

| Arquivo | Status | Observação |
|---------|--------|------------|
| `docs/AWS_CLI_COGNITO_CREDENTIALS.md` | ✅ Seguro | Apenas placeholders |
| `.gitignore` | ✅ Completo | Protege secrets |
| `scripts/get-cognito-credentials.sh` | ✅ Seguro | Usa AWS CLI local |
| `.github/workflows/*.yml` | ✅ Seguro | Usa GitHub Secrets |
| `terraform/**/*.tf` | ✅ Seguro | Usa AWS Secrets Manager |

---

## 🔐 Proteção de Credenciais

### Princípios Fundamentais

1. **NUNCA commitar credenciais no Git**
2. **Usar AWS Secrets Manager em produção**
3. **Usar variáveis de ambiente localmente**
4. **Rotacionar secrets periodicamente**
5. **Aplicar least privilege (IAM)**

### Hierarquia de Armazenamento

```
┌─────────────────────────────────────┐
│ 1. AWS Secrets Manager (PRODUÇÃO)  │ ← Melhor opção
├─────────────────────────────────────┤
│ 2. GitHub Secrets (CI/CD)          │ ← Para workflows
├─────────────────────────────────────┤
│ 3. .env files (LOCAL)              │ ← Desenvolvimento
└─────────────────────────────────────┘
```

### Arquivos Protegidos pelo .gitignore

```gitignore
# Secrets gerais
*.env
.env.*
secrets/
credentials/

# Cognito específico
.env.cognito
COGNITO_CREDENTIALS.md

# Terraform sensitive
*.tfstate
*.tfstate.*
terraform.tfvars
*.auto.tfvars

# AWS CLI
.aws/
```

### Como Gerenciar Credenciais Localmente

**CORRETO ✅:**
```bash
# 1. Criar arquivo .env (já está no .gitignore)
cat > .env.local << EOF
CLIENT_ID=seu-client-id-aqui
CLIENT_SECRET=seu-client-secret-aqui
EOF

# 2. Usar no código
source .env.local
export CLIENT_ID
export CLIENT_SECRET
```

**INCORRETO ❌:**
```bash
# NUNCA faça isso!
export CLIENT_SECRET="abc123..." >> ~/.bashrc  # Persiste no shell
echo "CLIENT_SECRET=abc123" >> application.yml # Commita no Git
```

---

## 🛡️ AWS Cognito Security

### Client Credentials Flow

**Configuração Atual (Segura):**
- ✅ Client Secret **NÃO** está no código
- ✅ Obtido via AWS CLI (`get-cognito-credentials.sh`)
- ✅ Armazenado em AWS Secrets Manager (produção)
- ✅ Scopes restritos: `cliente-core/read`, `cliente-core/write`
- ✅ Token expira em 1 hora (3600s)

### Permissões AWS CLI (Seu Acesso)

Suas credenciais em `~/.aws/credentials` têm permissões específicas:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cognito-idp:ListUserPools",
        "cognito-idp:DescribeUserPool",
        "cognito-idp:ListUserPoolClients",
        "cognito-idp:DescribeUserPoolClient"
      ],
      "Resource": "*"
    }
  ]
}
```

**✅ O que você PODE fazer:**
- Listar User Pools
- Ver configurações do Cognito
- Obter Client ID e Secret (somente leitura)

**❌ O que você NÃO PODE fazer:**
- Criar/deletar User Pools
- Modificar configurações de segurança
- Deletar usuários
- Acessar outros serviços AWS (S3, RDS, etc.)

### Rotação de Client Secret

**Frequência recomendada:** A cada 90 dias

```bash
# 1. Criar novo Client Secret (via Console ou CLI)
aws cognito-idp update-user-pool-client \
  --user-pool-id sa-east-1_XXXXXXXXX \
  --client-id 3q2r5s6t7u8v9w0x1y2z \
  --generate-secret

# 2. Atualizar no Secrets Manager
aws secretsmanager update-secret \
  --secret-id prod/cliente-core/cognito-credentials \
  --secret-string '{"client_id":"...","client_secret":"..."}'

# 3. Restart do serviço (ECS fará automaticamente)
```

---

## 🔧 Terraform State Protection

### Configuração Atual (Segura)

**Backend S3:**
```hcl
terraform {
  backend "s3" {
    bucket         = "yukam-terraform-state"
    key            = "cliente-core/terraform.tfstate"
    region         = "sa-east-1"
    encrypt        = true              # ✅ State criptografado
    dynamodb_table = "terraform-lock"  # ✅ Previne concorrência
  }
}
```

### Por que é Seguro?

1. **Encryption at Rest:**
   - State file criptografado com KMS
   - Ninguém pode ler o arquivo direto do S3

2. **Access Control:**
   - Apenas IAM Role `terraform-executor` tem acesso
   - Bucket S3 tem bucket policy restritiva

3. **State Locking:**
   - DynamoDB previne modificações concorrentes
   - Evita corruption do state

### ⚠️ NUNCA Faça Isso

```bash
# ❌ NUNCA commite o state no Git!
git add terraform.tfstate  # PERIGOSO!

# ❌ NUNCA compartilhe o state por Slack/Email
cat terraform.tfstate | mail joao@empresa.com  # PERIGOSO!
```

---

## 🚀 CI/CD Security

### GitHub Secrets (Atual)

**Secrets configurados:**
```
AWS_ACCESS_KEY_ID        # IAM User github-actions-cicd
AWS_SECRET_ACCESS_KEY    # Gerado pelo IAM
AWS_REGION               # sa-east-1
ECR_REPOSITORY           # cliente-core
```

### Least Privilege Policy (github-actions-cicd)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecs:UpdateService",
        "ecs:DescribeServices"
      ],
      "Resource": [
        "arn:aws:ecr:sa-east-1:*:repository/cliente-core",
        "arn:aws:ecs:sa-east-1:*:service/cliente-core-cluster/cliente-core-service"
      ]
    }
  ]
}
```

**✅ O que o CI/CD PODE fazer:**
- Build e push de Docker images no ECR
- Deploy no ECS (UpdateService)

**❌ O que o CI/CD NÃO PODE fazer:**
- Acessar RDS diretamente
- Modificar IAM Roles
- Acessar S3 fora do ECR
- Deletar recursos

### Rotação de Access Keys (CI/CD)

**Frequência recomendada:** A cada 90 dias

```bash
# 1. Criar nova Access Key
aws iam create-access-key --user-name github-actions-cicd

# 2. Atualizar GitHub Secrets
# (Via interface do GitHub: Settings > Secrets > Actions)

# 3. Deletar Access Key antiga
aws iam delete-access-key \
  --user-name github-actions-cicd \
  --access-key-id AKIAIOSFODNN7EXAMPLE
```

---

## 📊 Monitoring & Alerting

### CloudWatch Logs (Atual)

**Logs sensíveis mascarados:**
```java
// ✅ CORRETO
log.info("Cliente criado - CPF: {}", MaskingUtil.maskCpf("12345678910"));
// Output: Cliente criado - CPF: ***.***.789-10

// ❌ INCORRETO
log.info("Cliente criado - CPF: {}", clientePF.getCpf());
// Output: Cliente criado - CPF: 123.456.789-10 (EXPOSTO!)
```

### Alertas Configurados

1. **Falhas de autenticação:** > 10 em 5 minutos
2. **Erro 500:** > 5 em 1 minuto
3. **Latência:** P99 > 2 segundos
4. **CPU/Memory:** > 80% por 5 minutos

### CloudTrail (Auditoria)

**Eventos rastreados:**
- ✅ Criação/modificação de Secrets Manager
- ✅ Mudanças em IAM Roles/Policies
- ✅ Acesso a User Pools do Cognito
- ✅ Modificações no Terraform state (S3)

---

## 🚨 Incident Response

### Cenário 1: Credencial Vazada no Git

**Ações Imediatas:**

1. **Revogar credencial comprometida:**
   ```bash
   aws cognito-idp delete-user-pool-client \
     --user-pool-id sa-east-1_XXXXXXXXX \
     --client-id CLIENT_ID_COMPROMETIDO
   ```

2. **Criar novo Client + Secret:**
   ```bash
   aws cognito-idp create-user-pool-client \
     --user-pool-id sa-east-1_XXXXXXXXX \
     --client-name cliente-core-app-NEW \
     --generate-secret
   ```

3. **Remover do histórico do Git:**
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch ARQUIVO_COM_SECRET" \
     --prune-empty --tag-name-filter cat -- --all

   git push origin --force --all
   ```

4. **Notificar equipe:**
   - Enviar email para tech@yukam.com
   - Documentar no Incident Report

### Cenário 2: Acesso Não Autorizado

**Ações Imediatas:**

1. **Revisar CloudTrail:**
   ```bash
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=Username,AttributeValue=SUSPICIOUS_USER \
     --start-time 2025-11-06T00:00:00Z
   ```

2. **Desabilitar Access Keys suspeitas:**
   ```bash
   aws iam update-access-key \
     --access-key-id AKIAIOSFODNN7EXAMPLE \
     --status Inactive
   ```

3. **Forçar MFA:**
   ```bash
   aws iam attach-user-policy \
     --user-name SUSPICIOUS_USER \
     --policy-arn arn:aws:iam::aws:policy/RequireMFA
   ```

### Cenário 3: Token JWT Comprometido

**Ações Imediatas:**

1. **Revogar token específico:**
   - Cognito invalida automaticamente após expiração (1h)
   - Não há revogação manual necessária

2. **Se necessário revogar TODOS os tokens:**
   ```bash
   aws cognito-idp admin-user-global-sign-out \
     --user-pool-id sa-east-1_XXXXXXXXX \
     --username USERNAME
   ```

3. **Adicionar IP suspeito ao WAF:**
   ```bash
   aws wafv2 update-ip-set \
     --scope REGIONAL \
     --id SUSPICIOUS_IP_SET_ID \
     --addresses 203.0.113.10/32
   ```

---

## 📚 Recursos e Ferramentas

### Ferramentas de Segurança

1. **git-secrets** (previne commit de secrets)
   ```bash
   brew install git-secrets
   git secrets --install
   git secrets --register-aws
   ```

2. **trufflehog** (scan histórico do Git)
   ```bash
   trufflehog git https://github.com/yukam-drighi/cliente-core --only-verified
   ```

3. **checkov** (scan Terraform por vulnerabilidades)
   ```bash
   brew install checkov
   checkov -d terraform/
   ```

### Referências

- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)

---

## ✅ Checklist Mensal de Segurança

**Execute todo dia 1º de cada mês:**

- [ ] Revisar CloudTrail logs dos últimos 30 dias
- [ ] Verificar Access Keys inativas (> 90 dias)
- [ ] Atualizar dependências do projeto (npm audit, mvn versions:display-dependency-updates)
- [ ] Revisar IAM Policies (remover permissões não usadas)
- [ ] Testar backup e restore do RDS
- [ ] Executar scan de vulnerabilidades (checkov, trivy)
- [ ] Revisar logs de autenticação falhada no Cognito
- [ ] Verificar alertas do CloudWatch

---

**Contato de Segurança:**
📧 security@yukam.com
🔐 PGP Key: [Link para chave pública]

**Última revisão:** 2025-11-06
**Próxima revisão:** 2025-12-06
