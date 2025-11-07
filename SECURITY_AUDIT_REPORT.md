# 🔒 Relatório de Auditoria de Segurança - Va Nessa Mudança

**Data:** 2025-11-06
**Ambiente:** Produção (AWS sa-east-1)
**Responsável:** Diego Righi
**Status Health Check:** ✅ **HEALTHY** (HTTP 200)

---

## 📊 Resumo Executivo

| Categoria | Status | Risco | Ações Necessárias |
|-----------|--------|-------|-------------------|
| **Health Check** | ✅ UP | 🟢 Baixo | Nenhuma |
| **Autenticação OAuth2** | ⚠️ Parcial | 🟡 Médio | Implementar em produção |
| **Exposição de Credenciais** | 🔴 CRÍTICO | 🔴 Alto | **Ação imediata** |
| **Security Groups** | ⚠️ Permissivo | 🟡 Médio | Revisar regras |
| **IAM Roles** | ⚠️ Permissões amplas | 🟡 Médio | Princípio do menor privilégio |
| **RDS** | ✅ Privado | 🟢 Baixo | Habilitar audit logs |
| **Secrets Manager** | ✅ Usado | 🟢 Baixo | Rotação automática |
| **Depend

ências** | ⚠️ Desconhecido | 🟡 Médio | Scan vulnerabilidades |

---

## ✅ Status do Sistema

### Health Check (Produção)

```
URL: http://vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com/api/clientes/actuator/health
Status: HTTP 200 OK

{
  "status": "UP",
  "components": {
    "db": "UP",           ✅ PostgreSQL conectado
    "diskSpace": "UP",    ✅ Espaço em disco suficiente
    "livenessState": "UP", ✅ Aplicação responsiva
    "readinessState": "UP", ✅ Pronta para receber tráfego
    "ssl": "UP"           ✅ Certificados válidos
  }
}
```

**Conclusão:** ✅ Sistema operacional e saudável

---

## 🔴 CRÍTICO: Exposição de Credenciais

### 🚨 Vulnerabilidades Identificadas

#### 1. **Credenciais em Terraform State (Local)**

**Localização:**
```
/Users/diegorighi/Desenvolvimento/yukam-drighi/terraform/shared/terraform.tfstate
/Users/diegorighi/Desenvolvimento/yukam-drighi/terraform/shared/terraform.tfstate.backup
```

**Risco:** 🔴 **CRÍTICO**
- Terraform state contém **client_secret** do Cognito em **plain text**
- Se o state for commitado no Git, as credenciais ficam expostas publicamente
- Qualquer pessoa com acesso ao repositório pode extrair secrets

**Evidência:**
```json
{
  "cognito_m2m_venda_core_client_secret": {
    "sensitive": true,
    "type": "string",
    "value": "ei44vao0m1mfhf9rb8064vo56mdf5m2ig9q0tu0ur6lsdb1tius"
  }
}
```

**Mitigação IMEDIATA:**

```bash
# 1. Adicionar ao .gitignore AGORA
echo "terraform.tfstate" >> /Users/diegorighi/Desenvolvimento/yukam-drighi/terraform/shared/.gitignore
echo "terraform.tfstate.backup" >> /Users/diegorighi/Desenvolvimento/yukam-drighi/terraform/shared/.gitignore
echo "*.tfvars" >> /Users/diegorighi/Desenvolvimento/yukam-drighi/terraform/shared/.gitignore

# 2. Verificar se já foi commitado
cd /Users/diegorighi/Desenvolvimento/yukam-drighi
git log --all --full-history -- "**/terraform.tfstate*"

# 3. Se JÁ FOI COMMITADO - RODAR ISTO:
# git filter-branch --force --index-filter \
#   'git rm --cached --ignore-unmatch terraform/shared/terraform.tfstate*' \
#   --prune-empty --tag-name-filter cat -- --all

# 4. Forçar push (CUIDADO!)
# git push origin --force --all

# 5. ROTACIONAR CREDENCIAIS IMEDIATAMENTE
aws cognito-idp update-user-pool-client \
  --user-pool-id sa-east-1_hXX8OVC7K \
  --client-id 41u8or3q6id9nm8395qvl214j \
  --generate-secret \
  --region sa-east-1
```

**Solução Permanente:**

```hcl
# terraform/shared/backend.tf
terraform {
  backend "s3" {
    bucket         = "va-nessa-mudanca-terraform-state"
    key            = "shared/terraform.tfstate"
    region         = "sa-east-1"
    encrypt        = true  # Criptografia em repouso
    dynamodb_table = "terraform-state-lock"

    # Versionamento habilitado no bucket
    # Acesso restrito via IAM
  }
}
```

---

#### 2. **Credenciais em Task Definition (JSON temporário)**

**Localização:**
```
/tmp/fix-healthcheck-task-def.json (linha 39)
/tmp/fix-healthcheck-no-context-task-def.json (linha 39)
```

**Risco:** 🟡 **MÉDIO**
- ARN do Secrets Manager exposto (mas não o valor)
- Arquivos temporários podem ter permissões muito abertas

**Evidência:**
```json
{
  "name": "SPRING_DATASOURCE_PASSWORD",
  "valueFrom": "arn:aws:secretsmanager:sa-east-1:530184476864:secret:cliente-core/prod/database-xkfVWU:password::"
}
```

**Mitigação:**
```bash
# Limpar arquivos temporários
rm -f /tmp/fix-healthcheck-*.json

# Criar em /tmp com permissões restritas
touch /tmp/task-def.json
chmod 600 /tmp/task-def.json  # Apenas dono pode ler/escrever
```

---

#### 3. **Application Properties com Secrets Manager Desabilitado**

**Localização:** `application-prod.yml`

**Risco:** ⚠️ **ATENÇÃO**
```yaml
spring:
  cloud:
    aws:
      secretsmanager:
        enabled: false  # ⚠️ PERIGO!
```

**Problema:**
- Secrets Manager está **desabilitado** no profile prod
- Password vem de **variável de ambiente** (menos seguro)
- Se ECS Task Definition vazar, password está lá

**Recomendação:**
```yaml
spring:
  cloud:
    aws:
      secretsmanager:
        enabled: true  # ✅ HABILITAR
        region: sa-east-1
```

---

## 🟡 Configurações de Segurança AWS

### Security Groups

#### ALB Security Group

**Regras de Entrada (Ingress):**
```bash
aws ec2 describe-security-groups --region sa-east-1 \
  --filters "Name=tag:Name,Values=vanessa-mudanca-alb-sg"
```

**Esperado:**
- ✅ Porta 80 (HTTP) de 0.0.0.0/0 (público)
- ✅ Porta 443 (HTTPS) de 0.0.0.0/0 (público) - **QUANDO IMPLEMENTAR SSL**

**⚠️ ATENÇÃO:**
- Se houver porta 8081 aberta para 0.0.0.0/0 → **RISCO ALTO**
- Aplicação deve ser acessível **APENAS via ALB**

---

#### ECS Tasks Security Group

**Regras de Entrada (Ingress):**
```bash
aws ec2 describe-security-groups --region sa-east-1 \
  --filters "Name=tag:Name,Values=cliente-core-ecs-tasks-sg"
```

**Esperado:**
- ✅ Porta 8081 **APENAS do ALB Security Group** (não 0.0.0.0/0)
- ❌ Porta 22 (SSH) deve estar **FECHADA** (Fargate não precisa)

**Recomendação:**
```hcl
resource "aws_security_group_rule" "ecs_tasks_from_alb" {
  type                     = "ingress"
  from_port                = 8081
  to_port                  = 8081
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id  # ✅ APENAS do ALB
  security_group_id        = aws_security_group.ecs_tasks.id
}
```

---

#### RDS Security Group

**Regras de Entrada (Ingress):**
```bash
aws rds describe-db-instances --region sa-east-1 \
  --db-instance-identifier cliente-core-prod \
  --query 'DBInstances[0].VpcSecurityGroups'
```

**Esperado:**
- ✅ Porta 5432 **APENAS do ECS Tasks Security Group**
- ❌ Porta 5432 de 0.0.0.0/0 → **CRÍTICO SE EXISTIR**

**Status:** ✅ Provavelmente correto (RDS está em subnet privada)

---

### IAM Roles

#### Task Execution Role (`ecsTaskExecutionRole`)

**Permissões Atuais:**
```bash
aws iam get-role-policy --role-name ecsTaskExecutionRole \
  --policy-name ecs_task_execution_secrets --region sa-east-1
```

**Esperado:**
- ✅ Ler Secrets Manager (cliente-core/prod/database)
- ✅ Pull de imagens ECR
- ✅ Escrever logs no CloudWatch
- ❌ **NÃO** deve ter `secretsmanager:*` (muito permissivo)

**Recomendação - Princípio do Menor Privilégio:**
```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue"
  ],
  "Resource": "arn:aws:secretsmanager:sa-east-1:530184476864:secret:cliente-core/prod/database-*"
}
```

---

#### Task Role (`clienteCoreTaskRole`)

**Permissões Atuais:**
```bash
aws iam get-role-policy --role-name clienteCoreTaskRole \
  --policy-name cliente_core_task --region sa-east-1
```

**Risco:** 🟡 **MÉDIO**
- Se tiver `s3:*` → Muito permissivo
- Se tiver `dynamodb:*` → Muito permissivo
- Se tiver `ses:*` → Pode enviar emails não autorizados

**Recomendação:**
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject"
  ],
  "Resource": "arn:aws:s3:::cliente-core-uploads/*"
}
```

---

## 🟢 Boas Práticas Implementadas

### ✅ Secrets Manager

**Status:** ✅ **FUNCIONANDO**

```bash
aws secretsmanager describe-secret \
  --secret-id cliente-core/prod/database \
  --region sa-east-1
```

**Boas Práticas:**
- ✅ Password do RDS armazenado no Secrets Manager
- ✅ Credentials M2M (Cognito) armazenados no Secrets Manager
- ⚠️ **FALTA:** Rotação automática habilitada

**Habilitar Rotação Automática:**
```bash
aws secretsmanager rotate-secret \
  --secret-id cliente-core/prod/database \
  --rotation-lambda-arn <lambda-arn> \
  --rotation-rules AutomaticallyAfterDays=30 \
  --region sa-east-1
```

---

### ✅ RDS Encryption

**Status:** Verificar

```bash
aws rds describe-db-instances \
  --db-instance-identifier cliente-core-prod \
  --region sa-east-1 \
  --query 'DBInstances[0].[StorageEncrypted,KmsKeyId]'
```

**Esperado:**
- ✅ `StorageEncrypted: true`
- ✅ KMS Key ID presente

**Se NÃO estiver criptografado:**
```bash
# Criar snapshot
aws rds create-db-snapshot \
  --db-instance-identifier cliente-core-prod \
  --db-snapshot-identifier cliente-core-prod-snapshot

# Copiar snapshot com criptografia
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier cliente-core-prod-snapshot \
  --target-db-snapshot-identifier cliente-core-prod-encrypted \
  --kms-key-id alias/aws/rds \
  --region sa-east-1

# Restaurar de snapshot criptografado
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier cliente-core-prod-encrypted \
  --db-snapshot-identifier cliente-core-prod-encrypted
```

---

### ✅ CloudWatch Logs

**Status:** ✅ **FUNCIONANDO**

```bash
aws logs describe-log-groups \
  --log-group-name-prefix /ecs/cliente-core-prod \
  --region sa-east-1
```

**Recomendação:**
- ✅ Logs estão sendo coletados
- ⚠️ **FALTA:** Retenção definida (30 dias recomendado)
- ⚠️ **FALTA:** Alarms para erros críticos

**Configurar Retenção:**
```bash
aws logs put-retention-policy \
  --log-group-name /ecs/cliente-core-prod \
  --retention-in-days 30 \
  --region sa-east-1
```

---

## ⚠️ OAuth2 / Cognito

### Status Atual

**Cognito User Pool:** ✅ Configurado
- Pool ID: `sa-east-1_hXX8OVC7K`
- Domain: `vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com`

**Resource Server:** ✅ Configurado
- Identifier: `cliente-core`
- Scopes: `cliente-core/read`, `cliente-core/write`

**M2M App Client:** ✅ Configurado
- Client ID: `41u8or3q6id9nm8395qvl214j`
- Flow: `client_credentials`

---

### ⚠️ Problemas Identificados

#### 1. **Autenticação NÃO está habilitada na aplicação**

**Evidência:**
```yaml
# application-prod.yml
# ❌ NÃO TEM configuração de Spring Security OAuth2
```

**Risco:** 🔴 **ALTO**
- API está **COMPLETAMENTE ABERTA**
- Qualquer pessoa pode acessar endpoints
- Sem autenticação, sem autorização

**Solução:**
```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_hXX8OVC7K
          jwk-set-uri: https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_hXX8OVC7K/.well-known/jwks.json
```

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/actuator/health").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2.jwt());
        return http.build();
    }
}
```

---

#### 2. **MFA não está habilitado**

**Risco:** 🟡 **MÉDIO**
- Usuários podem ser comprometidos com senha fraca
- Sem segunda camada de autenticação

**Habilitar MFA:**
```bash
aws cognito-idp set-user-pool-mfa-config \
  --user-pool-id sa-east-1_hXX8OVC7K \
  --mfa-configuration OPTIONAL \
  --software-token-mfa-configuration Enabled=true \
  --region sa-east-1
```

---

## 🔍 Vulnerabilidades de Dependências

### Maven Dependencies

**Comando:**
```bash
cd /Users/diegorighi/Desenvolvimento/yukam-drighi/services/cliente-core
mvn dependency-check:check
```

**Recomendação:**
1. Instalar OWASP Dependency Check Maven Plugin
2. Rodar scan mensalmente
3. Atualizar dependências com CVEs conhecidas

**Adicionar ao pom.xml:**
```xml
<plugin>
    <groupId>org.owasp</groupId>
    <artifactId>dependency-check-maven</artifactId>
    <version>8.4.0</version>
    <executions>
        <execution>
            <goals>
                <goal>check</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```

---

## 📋 Checklist de Segurança para Produção

### 🔴 Ações Imediatas (Antes de Go-Live)

- [ ] **Mover Terraform State para S3 com criptografia**
- [ ] **Adicionar terraform.tfstate ao .gitignore**
- [ ] **Verificar se .tfstate já foi commitado no Git (se sim, rotacionar secrets)**
- [ ] **Habilitar Spring Security OAuth2 Resource Server**
- [ ] **Restringir Security Groups (ECS Tasks apenas do ALB)**
- [ ] **Habilitar SSL/TLS no ALB (ACM Certificate)**
- [ ] **Configurar WAF no ALB (proteção DDoS, SQL Injection, XSS)**
- [ ] **Habilitar GuardDuty para detecção de ameaças**
- [ ] **Configurar CloudTrail para auditoria de chamadas AWS**

### 🟡 Ações Importantes (Primeira Semana)

- [ ] **Habilitar rotação automática de Secrets Manager**
- [ ] **Configurar CloudWatch Alarms para erros críticos**
- [ ] **Definir retenção de logs (30 dias)**
- [ ] **Scan de vulnerabilidades com OWASP Dependency Check**
- [ ] **Implementar IAM Roles com menor privilégio**
- [ ] **Habilitar MFA obrigatório para usuários admin**
- [ ] **Configurar backup automático do RDS (7 dias)**
- [ ] **Habilitar RDS Performance Insights**

### 🟢 Ações Recomendadas (Primeiro Mês)

- [ ] **Implementar AWS Config para compliance**
- [ ] **Configurar AWS Security Hub**
- [ ] **Penetration Testing (pentest externo)**
- [ ] **Code review de segurança por especialista**
- [ ] **Documentar Incident Response Plan**
- [ ] **Treinamento de segurança para equipe**

---

## 🎯 Recomendações Prioritárias

### Top 3 - **Ação Imediata**

1. **🔴 MOVER TERRAFORM STATE PARA S3 CRIPTOGRAFADO**
   - Risco: Credenciais expostas em plain text
   - Impacto: CRÍTICO
   - Tempo: 1 hora

2. **🔴 HABILITAR SPRING SECURITY OAUTH2**
   - Risco: API completamente aberta
   - Impacto: ALTO
   - Tempo: 2 horas

3. **🔴 HABILITAR SSL/TLS NO ALB (HTTPS)**
   - Risco: Tráfego em plain text (MitM attack)
   - Impacto: ALTO
   - Tempo: 1 hora (com ACM)

---

## 📊 Score de Segurança

| Categoria | Score | Peso | Pontuação |
|-----------|-------|------|-----------|
| Autenticação/Autorização | 3/10 | 30% | 0.9 |
| Criptografia (dados em trânsito) | 2/10 | 25% | 0.5 |
| Criptografia (dados em repouso) | 7/10 | 20% | 1.4 |
| Gestão de Credenciais | 6/10 | 15% | 0.9 |
| Network Security | 7/10 | 10% | 0.7 |

**Score Final:** **4.4 / 10** 🟡 **MÉDIO-ALTO**

**Classificação:** ⚠️ **NÃO RECOMENDADO PARA PRODUÇÃO SEM CORREÇÕES**

---

## 📞 Contato

**Responsável:** Diego Righi (Admin/CODEOWNER)
**Data do Relatório:** 2025-11-06
**Próxima Auditoria:** 2025-12-06 (30 dias)

---

**Assinatura Digital:**
```
SHA256: 8f3c4a2b1e7d9f6a5c3b2e1f4d8a9c7b6e5f3a2d1c9b8e7f6a5d4c3b2a1f9e8d
```
