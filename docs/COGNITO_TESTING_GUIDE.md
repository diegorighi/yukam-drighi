# 🔐 Guia de Testes OAuth2 com Cognito + Postman

Este guia mostra como gerar JWT tokens do AWS Cognito e testar a autenticação OAuth2 da aplicação cliente-core em produção usando Postman.

---

## 📋 Informações do Cognito (Produção)

**User Pool:**
- **Nome:** `vanessa-mudanca-users-prod`
- **ID:** `sa-east-1_hXX8OVC7K`
- **Região:** `sa-east-1`
- **Domínio:** `vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com`

**App Client Existente (Web - SPA):**
- **Nome:** `vanessa-mudanca-web-client`
- **Client ID:** `4lt5o3071l37jh4s18liilsp4m`
- **Tipo:** Público (sem secret)
- **OAuth Flows:** ❌ Desabilitado (não serve para Postman)

---

## 🎯 Opções de Teste

### Opção 1: Usar o App Client Existente (SPA - Sem Secret)

**Prós:**
- Não precisa criar nada novo
- Usa o que já está configurado

**Contras:**
- Requer fluxo `USER_PASSWORD_AUTH` (menos seguro)
- Não usa OAuth2 Client Credentials
- Precisa criar usuário no User Pool

**Como fazer:**

#### 1.1. Criar Usuário de Teste

```bash
# Criar usuário admin de teste
aws cognito-idp admin-create-user \
  --user-pool-id sa-east-1_hXX8OVC7K \
  --username admin@vanessamudanca.com.br \
  --user-attributes \
    Name=email,Value=admin@vanessamudanca.com.br \
    Name=email_verified,Value=true \
    Name=name,Value="Admin Tester" \
    Name=custom:role,Value=ADMIN \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS \
  --region sa-east-1

# Definir senha permanente (pula verificação de email)
aws cognito-idp admin-set-user-password \
  --user-pool-id sa-east-1_hXX8OVC7K \
  --username admin@vanessamudanca.com.br \
  --password "AdminPass123!@#" \
  --permanent \
  --region sa-east-1
```

#### 1.2. Obter JWT Token (via AWS CLI)

```bash
# Autenticar e obter tokens
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id 4lt5o3071l37jh4s18liilsp4m \
  --auth-parameters \
    USERNAME=admin@vanessamudanca.com.br,PASSWORD='AdminPass123!@#' \
  --region sa-east-1 \
  --output json | jq -r '.AuthenticationResult'
```

**Resposta esperada:**
```json
{
  "AccessToken": "eyJraWQiOiJxxx...",
  "ExpiresIn": 3600,
  "TokenType": "Bearer",
  "RefreshToken": "eyJjdHk...",
  "IdToken": "eyJraWQiOiJyyy..."
}
```

**Use o `AccessToken` no Postman!**

#### 1.3. Testar no Postman

**Request:**
```http
GET https://cliente-core-prod-alb-123456789.sa-east-1.elb.amazonaws.com/api/clientes/actuator/health
Authorization: Bearer eyJraWQiOiJxxx...
```

**Ou para endpoint protegido:**
```http
GET https://cliente-core-prod-alb-123456789.sa-east-1.elb.amazonaws.com/v1/clientes/pf
Authorization: Bearer eyJraWQiOiJxxx...
```

---

### Opção 2: Criar App Client com Secret (M2M - Recomendado)

**Prós:**
- Fluxo OAuth2 Client Credentials (padrão da indústria)
- Não precisa criar usuários
- Ideal para testes automatizados
- Mais seguro para aplicações backend

**Contras:**
- Precisa criar novo App Client
- Precisa configurar Resource Server + Scopes

**Como fazer:**

#### 2.1. Criar Resource Server (API)

```bash
aws cognito-idp create-resource-server \
  --user-pool-id sa-east-1_hXX8OVC7K \
  --identifier "https://api.vanessamudanca.com.br" \
  --name "Cliente Core API" \
  --scopes \
    ScopeName=clientes.read,ScopeDescription="Read cliente data" \
    ScopeName=clientes.write,ScopeDescription="Write cliente data" \
  --region sa-east-1
```

#### 2.2. Criar App Client com Secret

```bash
aws cognito-idp create-user-pool-client \
  --user-pool-id sa-east-1_hXX8OVC7K \
  --client-name "vanessa-mudanca-backend-m2m" \
  --generate-secret \
  --allowed-o-auth-flows client_credentials \
  --allowed-o-auth-scopes \
    "https://api.vanessamudanca.com.br/clientes.read" \
    "https://api.vanessamudanca.com.br/clientes.write" \
  --allowed-o-auth-flows-user-pool-client \
  --supported-identity-providers COGNITO \
  --region sa-east-1 \
  --output json
```

**Resposta esperada:**
```json
{
  "UserPoolClient": {
    "ClientId": "abc123def456...",
    "ClientSecret": "secret-aqui-guardar-seguro",
    "ClientName": "vanessa-mudanca-backend-m2m"
  }
}
```

**⚠️ IMPORTANTE:** Guarde o `ClientSecret` imediatamente! Ele não pode ser recuperado depois.

#### 2.3. Obter JWT Token via Client Credentials

**Via cURL:**
```bash
# Encode client_id:client_secret em Base64
CLIENT_ID="abc123def456..."
CLIENT_SECRET="secret-aqui-guardar-seguro"
CREDENTIALS=$(echo -n "${CLIENT_ID}:${CLIENT_SECRET}" | base64)

# Obter token
curl -X POST \
  https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Basic ${CREDENTIALS}" \
  -d "grant_type=client_credentials&scope=https://api.vanessamudanca.com.br/clientes.read"
```

**Resposta esperada:**
```json
{
  "access_token": "eyJraWQiOiJxxx...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

#### 2.4. Configurar Postman (Client Credentials Flow)

**Passo a passo no Postman:**

1. **Criar nova Request**
2. **Aba Authorization:**
   - Type: `OAuth 2.0`
   - Add auth data to: `Request Headers`

3. **Configure New Token:**
   - Token Name: `Cognito M2M Token`
   - Grant Type: `Client Credentials`
   - Access Token URL: `https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token`
   - Client ID: `abc123def456...` (do passo 2.2)
   - Client Secret: `secret-aqui-guardar-seguro` (do passo 2.2)
   - Scope: `https://api.vanessamudanca.com.br/clientes.read`
   - Client Authentication: `Send as Basic Auth header`

4. **Get New Access Token**
5. **Use Token**

**Request de teste:**
```http
GET https://cliente-core-prod-alb-123456789.sa-east-1.elb.amazonaws.com/v1/clientes/pf
Authorization: Bearer {{token}}
```

---

## 🧪 Testes Recomendados com JWT

### 1. Health Check (Não protegido)

```http
GET /api/clientes/actuator/health
```

**Resposta esperada:** `200 OK` (mesmo sem token)

### 2. Listar Clientes PF (Protegido - requer ADMIN ou EMPLOYEE)

```http
GET /v1/clientes/pf
Authorization: Bearer {{jwt_token}}
```

**Resposta esperada:** `200 OK` com lista de clientes (se role = ADMIN/EMPLOYEE)

### 3. Buscar Cliente por ID (Protegido)

```http
GET /v1/clientes/pf/{publicId}
Authorization: Bearer {{jwt_token}}
```

**Casos de teste:**
- ✅ Com token válido e role ADMIN → `200 OK`
- ❌ Sem token → `401 Unauthorized`
- ❌ Token expirado → `401 Unauthorized`
- ❌ Token inválido → `401 Unauthorized`
- ❌ Role insuficiente (CUSTOMER tentando acessar outro cliente) → `403 Forbidden`

### 4. Criar Cliente PF (Protegido - requer ADMIN ou EMPLOYEE)

```http
POST /v1/clientes/pf
Authorization: Bearer {{jwt_token}}
Content-Type: application/json

{
  "nomeCompleto": "João Silva Teste",
  "cpf": "12345678910",
  "dataNascimento": "1990-05-15",
  "sexo": "MASCULINO"
}
```

**Resposta esperada:** `201 Created` com o cliente criado

---

## 🔍 Validar JWT Token

### Decodificar JWT (jwt.io)

1. Copie o token
2. Acesse https://jwt.io
3. Cole no campo "Encoded"
4. Verifique os claims:

**Access Token (Client Credentials):**
```json
{
  "sub": "abc123def456...",
  "token_use": "access",
  "scope": "https://api.vanessamudanca.com.br/clientes.read",
  "auth_time": 1730851234,
  "iss": "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_hXX8OVC7K",
  "exp": 1730854834,
  "iat": 1730851234,
  "client_id": "abc123def456..."
}
```

**ID Token (User Password Auth):**
```json
{
  "sub": "uuid-do-usuario",
  "cognito:username": "admin@vanessamudanca.com.br",
  "email_verified": true,
  "custom:role": "ADMIN",
  "iss": "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_hXX8OVC7K",
  "cognito:username": "admin@vanessamudanca.com.br",
  "aud": "4lt5o3071l37jh4s18liilsp4m",
  "token_use": "id",
  "exp": 1730854834,
  "iat": 1730851234,
  "email": "admin@vanessamudanca.com.br",
  "name": "Admin Tester"
}
```

### Verificar Signature (Automaticamente validada pelo Spring Security)

O Spring Security valida automaticamente:
- ✅ Token não expirado (`exp` claim)
- ✅ Issuer correto (`iss` claim)
- ✅ Audience correto (`aud` claim para ID token)
- ✅ Assinatura RSA válida (public keys do Cognito)

---

## 🛠️ Scripts Úteis

### Gerar Token Rapidamente (Opção 1 - User Password)

```bash
#!/bin/bash
# Script: get-jwt-token.sh

USER_POOL_ID="sa-east-1_hXX8OVC7K"
CLIENT_ID="4lt5o3071l37jh4s18liilsp4m"
USERNAME="admin@vanessamudanca.com.br"
PASSWORD="AdminPass123!@#"

ACCESS_TOKEN=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "$CLIENT_ID" \
  --auth-parameters \
    USERNAME="$USERNAME",PASSWORD="$PASSWORD" \
  --region sa-east-1 \
  --query 'AuthenticationResult.AccessToken' \
  --output text)

echo "Access Token:"
echo "$ACCESS_TOKEN"
echo ""
echo "Copie para usar no Postman:"
echo "Authorization: Bearer $ACCESS_TOKEN"
```

### Testar Endpoint com Token (cURL)

```bash
#!/bin/bash
# Script: test-api.sh

TOKEN="seu-token-aqui"
ALB_URL="https://cliente-core-prod-alb-123456789.sa-east-1.elb.amazonaws.com"

# Health check
curl -s "$ALB_URL/api/clientes/actuator/health" | jq

# Listar clientes (com autenticação)
curl -s \
  -H "Authorization: Bearer $TOKEN" \
  "$ALB_URL/v1/clientes/pf" | jq
```

---

## 🔐 Segurança

**⚠️ NUNCA commitar tokens ou secrets no Git!**

**Boas práticas:**
- Use variáveis de ambiente no Postman: `{{COGNITO_TOKEN}}`
- Tokens expiram em 60 minutos (Access Token) ou 30 dias (Refresh Token)
- Renove tokens antes de expirar usando Refresh Token
- Em produção, use HTTPS SEMPRE
- Revogue tokens comprometidos via AWS Console

**Revogar token:**
```bash
aws cognito-idp revoke-token \
  --token "$REFRESH_TOKEN" \
  --client-id "$CLIENT_ID" \
  --region sa-east-1
```

---

## 📊 Troubleshooting

### Erro: "User pool client does not have secret"

**Causa:** Tentando usar Client Credentials com app client público

**Solução:** Use Opção 2 (criar app client com secret)

### Erro: "invalid_client"

**Causa:** ClientId ou ClientSecret incorreto

**Solução:** Verifique credenciais do app client

### Erro: "invalid_scope"

**Causa:** Scope não configurado no Resource Server

**Solução:** Crie Resource Server com scopes (Opção 2.1)

### Erro: "401 Unauthorized" na API

**Causa:** Token inválido, expirado ou Spring Security não configurado

**Solução:**
1. Verifique se token está no header `Authorization: Bearer ...`
2. Verifique se token não expirou (jwt.io)
3. Verifique logs da aplicação: `/aws/logs/ecs/cliente-core-prod`

### Erro: "403 Forbidden" na API

**Causa:** Token válido mas role insuficiente

**Solução:** Verifique custom:role no token (deve ser ADMIN ou EMPLOYEE)

---

## 🎯 Qual Opção Usar?

| Cenário | Opção Recomendada |
|---------|-------------------|
| **Teste rápido manual (Postman)** | Opção 1 (User Password) - Mais simples |
| **Testes automatizados (CI/CD)** | Opção 2 (Client Credentials) - Mais seguro |
| **Integração M2M (microserviços)** | Opção 2 (Client Credentials) - Padrão OAuth2 |
| **Frontend SPA (React/Angular)** | Opção 1 (Authorization Code + PKCE) |

**Recomendação:** Comece com **Opção 1** para testes manuais rápidos, depois migre para **Opção 2** quando for automatizar.

---

**Última atualização:** 2025-11-05
**Versão:** 1.0
**Autor:** Va Nessa Mudança DevOps Team
