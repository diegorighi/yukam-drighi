# 🚀 Quick Start - Testar OAuth2 no Postman (3 passos)

## Passo 1: Gerar JWT Token

**Dispare esta URL no Postman:**

```
POST https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token
```

**Headers:**
```
Content-Type: application/x-www-form-urlencoded
Authorization: Basic NGx0NW8zMDcxbDM3amg0czE4bGlpbHNwNG06
```

**Body (x-www-form-urlencoded):**
```
grant_type=client_credentials
scope=https://api.vanessamudanca.com.br/clientes.read
```

**⚠️ PROBLEMA:** O App Client atual NÃO tem secret configurado!

---

## ✅ Solução Rápida (Usar USER_PASSWORD_AUTH)

### Passo 1: Obter JWT Token via cURL

```bash
curl -X POST https://cognito-idp.sa-east-1.amazonaws.com/ \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth" \
  -d '{
    "AuthFlow": "USER_PASSWORD_AUTH",
    "ClientId": "4lt5o3071l37jh4s18liilsp4m",
    "AuthParameters": {
      "USERNAME": "admin@vanessamudanca.com.br",
      "PASSWORD": "Admin@Test123"
    }
  }'
```

**Ou use o script que criei:**
```bash
cd /Users/diegorighi/Desenvolvimento/yukam-drighi
./scripts/get-jwt-token.sh
```

**Você receberá:**
```json
{
  "AuthenticationResult": {
    "AccessToken": "eyJraWQiOiJETWNhbWNtdHdZd2p0Kz...",
    "ExpiresIn": 3600,
    "TokenType": "Bearer"
  }
}
```

**Copie o `AccessToken`!**

---

### Passo 2: Testar no Postman

**URL do Serviço:**
```
GET http://vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com/api/clientes/actuator/health
```

**Headers:**
```
Authorization: Bearer eyJraWQiOiJETWNhbWNtdHdZd2p0Kz... (cole o AccessToken aqui)
```

**Clique em Send** → **BINGO!** ✅

---

## 🎯 Endpoints para Testar

### 1. Health Check (Não protegido)
```
GET http://vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com/api/clientes/actuator/health
```
**Sem autenticação necessária**

---

### 2. Listar Clientes PF (Protegido - requer ADMIN)
```
GET http://vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com/v1/clientes/pf
```
**Headers:**
```
Authorization: Bearer {{seu-access-token}}
```

---

### 3. Buscar Cliente por ID (Protegido)
```
GET http://vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com/v1/clientes/pf/{publicId}
```
**Headers:**
```
Authorization: Bearer {{seu-access-token}}
```

---

### 4. Criar Cliente PF (Protegido - requer ADMIN)
```
POST http://vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com/v1/clientes/pf
```
**Headers:**
```
Authorization: Bearer {{seu-access-token}}
Content-Type: application/json
```
**Body:**
```json
{
  "nomeCompleto": "João Silva Teste",
  "cpf": "12345678910",
  "dataNascimento": "1990-05-15",
  "sexo": "MASCULINO"
}
```

---

## 📋 Configuração Rápida no Postman

### Método 1: Manual (Copiar/Colar)

1. Rode o script: `./scripts/get-jwt-token.sh`
2. Copie o ACCESS TOKEN
3. No Postman:
   - Aba **Authorization**
   - Type: **Bearer Token**
   - Token: **(cole aqui)**
4. **Send** → Pronto!

---

### Método 2: Variáveis de Ambiente (Recomendado)

**Criar Environment no Postman:**

1. **Environments** → **Add**
2. Nome: `Cliente-Core Production`
3. Adicionar variáveis:

| Variable | Initial Value | Current Value |
|----------|--------------|---------------|
| `base_url` | `http://vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com` | (mesmo) |
| `access_token` | (vazio - preencher após obter token) | (seu token) |

4. Usar nas requests:
   ```
   GET {{base_url}}/v1/clientes/pf
   Authorization: Bearer {{access_token}}
   ```

---

## 🔄 Renovar Token (Expira em 60 minutos)

Quando o token expirar:

```bash
./scripts/get-jwt-token.sh
```

Copie o novo `AccessToken` e atualize no Postman (Environment variable `access_token`).

---

## 🐛 Troubleshooting

### ❌ Erro: 401 Unauthorized
**Causa:** Token expirado ou inválido
**Solução:** Gere novo token com `./scripts/get-jwt-token.sh`

### ❌ Erro: 403 Forbidden
**Causa:** Role insuficiente (token válido mas sem permissão)
**Solução:** Verifique se `custom:role = ADMIN` no token (jwt.io)

### ❌ Erro: Connection refused
**Causa:** ALB ou ECS service não está rodando
**Solução:** Verifique status do ECS:
```bash
aws ecs describe-services \
  --cluster cliente-core-prod-cluster \
  --services cliente-core-prod-service \
  --region sa-east-1
```

### ❌ Erro: Invalid grant
**Causa:** Credenciais incorretas ou usuário não existe
**Solução:** Verifique username/password no script

---

## 🎬 Exemplo Completo (Copy & Paste)

### 1. Terminal: Gerar Token
```bash
cd /Users/diegorighi/Desenvolvimento/yukam-drighi
./scripts/get-jwt-token.sh
```

### 2. Copiar ACCESS_TOKEN
```
eyJraWQiOiJETWNhbWNtdHdZd2p0Kz9VRHdvTkJ0cENZTTlCRDhKZWVrKzRxWjJHekhRPSIsImFsZyI6IlJTMjU2In0...
```

### 3. Postman: Nova Request
```
GET http://vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com/v1/clientes/pf
```

### 4. Authorization Tab
```
Type: Bearer Token
Token: eyJraWQiOiJETWNhbWNtdHdZd2p0Kz9VRHdvTkJ0cENZTTlCRDhKZWVrKzRxWjJHekhRPSIsImFsZyI6IlJTMjU2In0...
```

### 5. Send → BINGO! 🎉
```json
{
  "content": [
    {
      "publicId": "uuid-do-cliente",
      "nomeCompleto": "João Silva",
      "cpf": "***.***.789-10",
      "email": "jo***@example.com"
    }
  ],
  "totalElements": 10
}
```

---

## ⚡ One-Liner para Testar

```bash
# Obter token e testar endpoint em um comando só
TOKEN=$(./scripts/get-jwt-token.sh | grep -A 1 "ACCESS TOKEN" | tail -1 | xargs) && \
curl -H "Authorization: Bearer $TOKEN" \
  http://vanessa-mudanca-alb-1421055708.sa-east-1.elb.amazonaws.com/v1/clientes/pf | jq
```

---

**Última atualização:** 2025-11-05
**Criado por:** DevOps Team - Va Nessa Mudança
