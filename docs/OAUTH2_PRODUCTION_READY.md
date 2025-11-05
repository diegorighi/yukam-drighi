# 🔐 OAuth2 Client Credentials - Production Ready

Guia simplificado para usar OAuth2 com client_id e client_secret no Postman.

---

## ✅ Configuração Completa

### Cognito Resource Server
- **Identifier:** `https://api.vanessamudanca.com.br/cliente-core`
- **Scopes:**
  - `clientes.read` - Read cliente data
  - `clientes.write` - Write cliente data
  - `clientes.delete` - Delete cliente data
  - `clientes.admin` - Full admin access

### App Client M2M
- **Name:** `cliente-core-m2m-backend`
- **Client ID:** `46cfgoegvctki8lfibv2nl4c8f`
- **Client Secret:** `8kp3skqnq175h8l220km8qrqtdaj82boo75plabsf28glivcsj8` ⚠️ **GUARDAR COM SEGURANÇA!**
- **Flow:** Client Credentials (M2M)
- **Secret Storage:** AWS Secrets Manager (`vanessa-mudanca/cliente-core/cognito-client-secret`)

---

## 🚀 Passo a Passo - Postman

### Passo 1: Obter JWT Token

**Dispare esta URL:**
```
POST https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token
```

**Headers:**
```
Content-Type: application/x-www-form-urlencoded
Authorization: Basic NDZjZmdvZWd2Y3RraThsZmlidjJubDRjOGY6OGtwM3NrcW5xMTc1aDhsMjIwa204cXJxdGRhajgyYm9vNzVwbGFic2YyOGdsaXZjc2o4
```

**(O valor do Authorization é `client_id:client_secret` em Base64)**

**Body (x-www-form-urlencoded):**
```
grant_type=client_credentials
scope=https://api.vanessamudanca.com.br/cliente-core/clientes.read
```

**Response:**
```json
{
  "access_token": "eyJraWQiOiJETWNhbWNtdHdZd2p0Kz...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

**Copie o `access_token`!**

---

### Passo 2: Usar o Token na API

**URL do serviço:**
```
GET http://vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com/v1/clientes/pf
```

**Headers:**
```
Authorization: Bearer eyJraWQiOiJETWNhbWNtdHdZd2p0Kz... (cole o access_token aqui)
```

**Send → BINGO!** ✅

---

## 📋 Configuração Rápida no Postman

### Método 1: OAuth 2.0 (Automático - Recomendado)

1. **Nova Request**
2. **Aba Authorization:**
   - Type: `OAuth 2.0`
   - Add auth data to: `Request Headers`

3. **Configure New Token:**
   - **Token Name:** `Cliente Core M2M`
   - **Grant Type:** `Client Credentials`
   - **Access Token URL:** `https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token`
   - **Client ID:** `46cfgoegvctki8lfibv2nl4c8f`
   - **Client Secret:** `8kp3skqnq175h8l220km8qrqtdaj82boo75plabsf28glivcsj8`
   - **Scope:** `https://api.vanessamudanca.com.br/cliente-core/clientes.read`
   - **Client Authentication:** `Send as Basic Auth header`

4. **Get New Access Token** → **Use Token** → **Send**

---

### Método 2: Bearer Token (Manual)

1. Rode o script: `./scripts/test-oauth2-client-credentials.sh`
2. Copie o `access_token`
3. No Postman:
   - Aba **Authorization**
   - Type: **Bearer Token**
   - Token: **(cole aqui)**
4. **Send**

---

## 🔄 Renovar Token (Expira em 60 minutos)

**Opção 1: Script**
```bash
cd /Users/diegorighi/Desenvolvimento/yukam-drighi
./scripts/test-oauth2-client-credentials.sh
```

**Opção 2: cURL**
```bash
curl -X POST \
  "https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Basic NDZjZmdvZWd2Y3RraThsZmlidjJubDRjOGY6OGtwM3NrcW5xMTc1aDhsMjIwa204cXJxdGRhajgyYm9vNzVwbGFic2YyOGdsaXZjc2o4" \
  -d "grant_type=client_credentials&scope=https://api.vanessamudanca.com.br/cliente-core/clientes.read" \
  | jq -r '.access_token'
```

**Opção 3: Postman (Automático)**
- Clique em "Get New Access Token" na aba Authorization
- Use Token

---

## 🧪 Endpoints para Testar

### 1. Health Check (Não protegido)
```
GET http://vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com/api/clientes/actuator/health
```
**Sem autenticação**

### 2. Listar Clientes PF (Protegido)
```
GET http://vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com/v1/clientes/pf
Authorization: Bearer {{token}}
```

### 3. Criar Cliente PF (Protegido)
```
POST http://vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com/v1/clientes/pf
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "nomeCompleto": "João Silva",
  "cpf": "12345678910",
  "dataNascimento": "1990-05-15",
  "sexo": "MASCULINO"
}
```

---

## 🔍 Validar JWT Token

Acesse **https://jwt.io** e cole o token para ver os claims:

```json
{
  "sub": "46cfgoegvctki8lfibv2nl4c8f",
  "token_use": "access",
  "scope": "https://api.vanessamudanca.com.br/cliente-core/clientes.read",
  "auth_time": 1762386230,
  "iss": "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_hXX8OVC7K",
  "exp": 1762389830,
  "iat": 1762386230,
  "version": 2,
  "jti": "d8496d0a-479b-4168-b63a-363bd84444c5",
  "client_id": "46cfgoegvctki8lfibv2nl4c8f"
}
```

**Campos importantes:**
- `scope` - Permissões do token
- `exp` - Timestamp de expiração (Unix)
- `client_id` - ID do app client

---

## ⚠️ Segurança

### ✅ Boas Práticas
- ✅ Client Secret guardado no AWS Secrets Manager
- ✅ NUNCA commit client_secret no Git
- ✅ Tokens expiram em 60 minutos
- ✅ Use HTTPS sempre (production)
- ✅ Rotacione secrets periodicamente

### ❌ NUNCA Fazer
- ❌ Compartilhar Client Secret em Slack/Email/WhatsApp
- ❌ Hardcode secret no código-fonte
- ❌ Commit .env com secrets
- ❌ Expor secrets em logs

---

## 🐛 Troubleshooting

### Erro: 401 Unauthorized
**Causa:** Token inválido ou expirado
**Solução:** Gere novo token com script ou Postman

### Erro: 403 Forbidden
**Causa:** Scope insuficiente
**Solução:** Inclua scope correto: `clientes.admin` para operações write

### Erro: invalid_client
**Causa:** Client ID ou Secret incorreto
**Solução:** Verifique credenciais no Secrets Manager

### Erro: invalid_scope
**Causa:** Scope não existe no Resource Server
**Solução:** Use scopes válidos:
- `https://api.vanessamudanca.com.br/cliente-core/clientes.read`
- `https://api.vanessamudanca.com.br/cliente-core/clientes.write`
- `https://api.vanessamudanca.com.br/cliente-core/clientes.delete`
- `https://api.vanessamudanca.com.br/cliente-core/clientes.admin`

---

## 📊 Resumo

| Item | Valor |
|------|-------|
| **OAuth2 Flow** | Client Credentials (M2M) |
| **Grant Type** | `client_credentials` |
| **Token URL** | `https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token` |
| **Client ID** | `46cfgoegvctki8lfibv2nl4c8f` |
| **Client Secret** | AWS Secrets Manager |
| **Token Expiry** | 60 minutos |
| **Scopes** | `clientes.read`, `clientes.write`, `clientes.delete`, `clientes.admin` |

---

**Última atualização:** 2025-11-05
**Versão:** 1.0
**Autor:** DevOps Team - Va Nessa Mudança
