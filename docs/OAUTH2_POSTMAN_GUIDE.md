# Guia Completo: Autenticação OAuth2 com Postman

Este guia mostra como obter um JWT do AWS Cognito usando Client Credentials Flow e fazer requests autenticados no `cliente-core`.

---

## 📋 Pré-requisitos

Antes de começar, você precisa ter:

1. **Postman** instalado (versão desktop recomendada)
2. **Credenciais do Cognito** (fornecidas pelo admin AWS):
   - `CLIENT_ID` (App Client ID)
   - `CLIENT_SECRET` (App Client Secret)
   - `COGNITO_DOMAIN` (ex: `yukam-auth.auth.sa-east-1.amazoncognito.com`)
   - `REGION` (ex: `sa-east-1`)

3. **URL do serviço cliente-core**:
   - **Produção**: `https://your-alb.sa-east-1.elb.amazonaws.com/api/clientes`
   - **Local**: `http://localhost:8081/api/clientes`

---

## 🔐 Passo 1: Obter o Access Token (JWT)

### Opção A: Usando Postman Collection Runner (Recomendado)

1. **Crie uma nova Collection** no Postman
   - Nome: `Cliente Core - OAuth2`

2. **Configure a autorização da Collection:**
   - Click direito na Collection → **Edit**
   - Aba **Authorization**
   - Type: **OAuth 2.0**
   - Add auth data to: **Request Headers**

3. **Configure o Token:**

   ```
   Token Name: Cognito Client Credentials
   Grant Type: Client Credentials
   Access Token URL: https://{COGNITO_DOMAIN}/oauth2/token
   Client ID: {seu CLIENT_ID}
   Client Secret: {seu CLIENT_SECRET}
   Scope: cliente-core/read cliente-core/write
   Client Authentication: Send as Basic Auth header
   ```

   **Exemplo real:**
   ```
   Access Token URL: https://yukam-auth.auth.sa-east-1.amazoncognito.com/oauth2/token
   Client ID: 3q2r5s6t7u8v9w0x1y2z
   Client Secret: abc123def456ghi789jkl012mno345pqr678stu901vwx234
   Scope: cliente-core/read cliente-core/write
   ```

4. **Clique em "Get New Access Token"**

5. **Copie o token gerado** (será algo como):
   ```
   eyJraWQiOiJ4eHgiLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIzc...
   ```

### Opção B: Usando cURL (para testar rapidamente)

```bash
curl -X POST https://{COGNITO_DOMAIN}/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "{CLIENT_ID}:{CLIENT_SECRET}" \
  -d "grant_type=client_credentials&scope=cliente-core/read cliente-core/write"
```

**Exemplo real:**
```bash
curl -X POST https://yukam-auth.auth.sa-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "3q2r5s6t7u8v9w0x1y2z:abc123def456ghi789jkl012mno345pqr678stu901vwx234" \
  -d "grant_type=client_credentials&scope=cliente-core/read cliente-core/write"
```

**Response esperado:**
```json
{
  "access_token": "eyJraWQiOiJ4eHgiLCJhbGciOiJSUzI1NiJ9...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

---

## 🚀 Passo 2: Fazer Requests Autenticados

### 2.1. Criar Cliente Pessoa Física (POST)

**Endpoint:** `POST /v1/clientes/pf`

**Headers:**
```
Authorization: Bearer eyJraWQiOiJ4eHgiLCJhbGciOiJSUzI1NiJ9...
Content-Type: application/json
```

**Body (JSON):**
```json
{
  "primeiroNome": "João",
  "nomeDoMeio": "da",
  "sobrenome": "Silva",
  "cpf": "12345678910",
  "rg": "MG-12.345.678",
  "dataNascimento": "1990-01-15",
  "sexo": "MASCULINO",
  "email": "joao.silva@email.com",
  "nomeMae": "Maria da Silva",
  "nomePai": "José da Silva",
  "estadoCivil": "Casado",
  "profissao": "Engenheiro",
  "nacionalidade": "Brasileira",
  "naturalidade": "Belo Horizonte",
  "tipoCliente": "COMPRADOR",
  "observacoes": "Cliente VIP"
}
```

**cURL completo:**
```bash
curl -X POST https://your-alb.sa-east-1.elb.amazonaws.com/api/clientes/v1/clientes/pf \
  -H "Authorization: Bearer eyJraWQiOiJ4eHgiLCJhbGciOiJSUzI1NiJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "primeiroNome": "João",
    "sobrenome": "Silva",
    "cpf": "12345678910",
    "email": "joao.silva@email.com",
    "dataNascimento": "1990-01-15",
    "sexo": "MASCULINO",
    "tipoCliente": "COMPRADOR"
  }'
```

**Response esperado (201 Created):**
```json
{
  "publicId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "primeiroNome": "João",
  "sobrenome": "Silva",
  "nomeCompleto": "João Silva",
  "cpf": "123.456.789-10",
  "email": "joao.silva@email.com",
  "idade": 35,
  "ativo": true,
  "dataCriacao": "2025-11-06T17:30:00",
  ...
}
```

### 2.2. Buscar Cliente por Public ID (GET)

**Endpoint:** `GET /v1/clientes/pf/{publicId}`

**Headers:**
```
Authorization: Bearer eyJraWQiOiJ4eHgiLCJhbGciOiJSUzI1NiJ9...
```

**Exemplo:**
```bash
curl -X GET https://your-alb.sa-east-1.elb.amazonaws.com/api/clientes/v1/clientes/pf/a1b2c3d4-e5f6-7890-abcd-ef1234567890 \
  -H "Authorization: Bearer eyJraWQiOiJ4eHgiLCJhbGciOiJSUzI1NiJ9..."
```

**Response esperado (200 OK):**
```json
{
  "publicId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "primeiroNome": "João",
  "sobrenome": "Silva",
  "nomeCompleto": "João Silva",
  ...
}
```

### 2.3. Buscar Cliente por CPF (GET)

**Endpoint:** `GET /v1/clientes/pf/cpf/{cpf}`

**Exemplo:**
```bash
curl -X GET https://your-alb.sa-east-1.elb.amazonaws.com/api/clientes/v1/clientes/pf/cpf/12345678910 \
  -H "Authorization: Bearer eyJraWQiOiJ4eHgiLCJhbGciOiJSUzI1NiJ9..."
```

### 2.4. Listar Clientes (GET com paginação)

**Endpoint:** `GET /v1/clientes/pf?page=0&size=10&sort=dataCriacao,desc`

**Query Parameters:**
- `page`: Número da página (default: 0)
- `size`: Tamanho da página (default: 20)
- `sort`: Campo de ordenação (ex: `dataCriacao,desc`)

**Exemplo:**
```bash
curl -X GET "https://your-alb.sa-east-1.elb.amazonaws.com/api/clientes/v1/clientes/pf?page=0&size=10&sort=dataCriacao,desc" \
  -H "Authorization: Bearer eyJraWQiOiJ4eHgiLCJhbGciOiJSUzI1NiJ9..."
```

**Response esperado (200 OK):**
```json
{
  "content": [
    {
      "publicId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "primeiroNome": "João",
      "sobrenome": "Silva",
      ...
    }
  ],
  "page": 0,
  "size": 10,
  "totalElements": 150,
  "totalPages": 15,
  "first": true,
  "last": false
}
```

### 2.5. Atualizar Cliente (PUT)

**Endpoint:** `PUT /v1/clientes/pf/{publicId}`

**Body (JSON - selective update):**
```json
{
  "publicId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "profissao": "Médico",
  "estadoCivil": "Divorciado"
}
```

**Exemplo:**
```bash
curl -X PUT https://your-alb.sa-east-1.elb.amazonaws.com/api/clientes/v1/clientes/pf/a1b2c3d4-e5f6-7890-abcd-ef1234567890 \
  -H "Authorization: Bearer eyJraWQiOiJ4eHgiLCJhbGciOiJSUzI1NiJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "publicId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "profissao": "Médico"
  }'
```

### 2.6. Deletar Cliente (Soft Delete) (DELETE)

**Endpoint:** `DELETE /v1/clientes/pf/{publicId}`

**Query Parameters (opcionais):**
- `motivoDelecao`: Motivo da exclusão
- `usuarioDelecao`: Usuário que está deletando

**Exemplo:**
```bash
curl -X DELETE "https://your-alb.sa-east-1.elb.amazonaws.com/api/clientes/v1/clientes/pf/a1b2c3d4-e5f6-7890-abcd-ef1234567890?motivoDelecao=Cliente%20solicitou&usuarioDelecao=admin@yukam.com" \
  -H "Authorization: Bearer eyJraWQiOiJ4eHgiLCJhbGciOiJSUzI1NiJ9..."
```

### 2.7. Restaurar Cliente (POST)

**Endpoint:** `POST /v1/clientes/{publicId}/restaurar`

**Exemplo:**
```bash
curl -X POST https://your-alb.sa-east-1.elb.amazonaws.com/api/clientes/a1b2c3d4-e5f6-7890-abcd-ef1234567890/restaurar \
  -H "Authorization: Bearer eyJraWQiOiJ4eHgiLCJhbGciOiJSUzI1NiJ9..."
```

---

## 🔍 Passo 3: Validar o Token JWT

### 3.1. Decodificar o Token (jwt.io)

1. Acesse https://jwt.io
2. Cole o token no campo "Encoded"
3. Verifique o **Payload**:

```json
{
  "sub": "3q2r5s6t7u8v9w0x1y2z",
  "token_use": "access",
  "scope": "cliente-core/read cliente-core/write",
  "auth_time": 1699300000,
  "iss": "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_XXXXXX",
  "exp": 1699303600,
  "iat": 1699300000,
  "version": 2,
  "jti": "abc-123-def-456",
  "client_id": "3q2r5s6t7u8v9w0x1y2z"
}
```

### 3.2. Campos Importantes

- **`scope`**: Permissões do token (`cliente-core/read` e `cliente-core/write`)
- **`exp`**: Timestamp de expiração (3600 segundos = 1 hora)
- **`iss`**: Issuer (Cognito User Pool)
- **`client_id`**: ID da aplicação cliente

---

## 🛠️ Passo 4: Configurar Postman Collection (Automação)

### 4.1. Criar Collection com Auto-refresh do Token

1. **Crie uma Collection** chamada "Cliente Core API"

2. **Configure Authorization na Collection:**
   - Type: `OAuth 2.0`
   - Add auth data to: `Request Headers`
   - Configure conforme Passo 1, Opção A

3. **Crie as Requests dentro da Collection:**

   **Estrutura sugerida:**
   ```
   📁 Cliente Core API
   ├── 🔐 Auth
   │   └── Get Access Token (apenas para referência)
   ├── 👤 Cliente PF
   │   ├── POST - Criar Cliente PF
   │   ├── GET - Buscar por ID
   │   ├── GET - Buscar por CPF
   │   ├── GET - Listar Clientes
   │   ├── PUT - Atualizar Cliente
   │   ├── DELETE - Soft Delete
   │   └── POST - Restaurar Cliente
   └── 🏢 Cliente PJ
       ├── POST - Criar Cliente PJ
       ├── GET - Buscar por ID
       └── ...
   ```

4. **Configure cada request:**
   - Authorization: `Inherit auth from parent` (herda da Collection)
   - Headers: `Content-Type: application/json` (apenas para POST/PUT)

5. **O token será renovado automaticamente** quando expirar!

### 4.2. Criar Environment (Dev, Staging, Prod)

**Environment: Development**
```json
{
  "base_url": "http://localhost:8081/api/clientes",
  "cognito_domain": "yukam-auth.auth.sa-east-1.amazoncognito.com",
  "client_id": "{{seu_client_id}}",
  "client_secret": "{{seu_client_secret}}"
}
```

**Environment: Production**
```json
{
  "base_url": "https://your-alb.sa-east-1.elb.amazonaws.com/api/clientes",
  "cognito_domain": "yukam-auth.auth.sa-east-1.amazoncognito.com",
  "client_id": "{{seu_client_id}}",
  "client_secret": "{{seu_client_secret}}"
}
```

**Uso nas requests:**
```
URL: {{base_url}}/v1/clientes/pf
```

---

## ⚠️ Troubleshooting

### Erro: `401 Unauthorized`

**Causa:** Token inválido, expirado ou ausente

**Soluções:**
1. Verifique se o header `Authorization: Bearer {token}` está presente
2. Verifique se o token não expirou (válido por 1 hora)
3. Obtenha um novo token (Passo 1)
4. Verifique se o `scope` está correto

### Erro: `403 Forbidden`

**Causa:** Token válido mas sem permissões suficientes

**Soluções:**
1. Verifique o `scope` do token: deve ter `cliente-core/read` e/ou `cliente-core/write`
2. Verifique se o Resource Server está configurado no Cognito
3. Verifique se o App Client tem acesso aos scopes

### Erro: `400 Bad Request` no `/oauth2/token`

**Causa:** Credenciais inválidas ou parâmetros incorretos

**Soluções:**
1. Verifique `CLIENT_ID` e `CLIENT_SECRET`
2. Verifique se está usando `grant_type=client_credentials`
3. Verifique se o `scope` existe no Resource Server
4. Verifique se o Client Authentication está como "Basic Auth header"

### Erro: `404 Not Found`

**Causa:** Endpoint não existe ou URL incorreta

**Soluções:**
1. Verifique a URL base: `/api/clientes` (não `/clientes`)
2. Verifique a versão: `/v1/clientes/pf`
3. Verifique se o serviço está rodando (health check: `/actuator/health`)

### Erro: `500 Internal Server Error`

**Causa:** Erro no servidor

**Soluções:**
1. Verifique os logs do CloudWatch
2. Verifique se o banco de dados está acessível
3. Verifique se as variáveis de ambiente estão configuradas no ECS
4. Contate o time de infra

---

## 📚 Recursos Adicionais

### Documentação da API (Swagger)

Quando disponível, acesse:
```
http://localhost:8081/api/clientes/swagger-ui/index.html
```

### Health Check

Verifique se o serviço está rodando:
```bash
curl https://your-alb.sa-east-1.elb.amazonaws.com/api/clientes/actuator/health
```

**Response esperado:**
```json
{
  "status": "UP"
}
```

### Logs do CloudWatch

**Log Group:** `/ecs/cliente-core-prod`

**Query útil (CloudWatch Insights):**
```sql
fields @timestamp, @message, correlationId, operationType
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```

---

## 🎯 Exemplo Completo: Fluxo End-to-End

```bash
# 1. Obter token
TOKEN=$(curl -s -X POST https://yukam-auth.auth.sa-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "YOUR_CLIENT_ID:YOUR_CLIENT_SECRET" \
  -d "grant_type=client_credentials&scope=cliente-core/read cliente-core/write" \
  | jq -r '.access_token')

echo "Token obtido: $TOKEN"

# 2. Criar cliente
CLIENT_ID=$(curl -s -X POST https://your-alb.elb.amazonaws.com/api/clientes/v1/clientes/pf \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "primeiroNome": "João",
    "sobrenome": "Silva",
    "cpf": "12345678910",
    "email": "joao@email.com",
    "dataNascimento": "1990-01-15",
    "sexo": "MASCULINO",
    "tipoCliente": "COMPRADOR"
  }' | jq -r '.publicId')

echo "Cliente criado com ID: $CLIENT_ID"

# 3. Buscar cliente criado
curl -s -X GET "https://your-alb.elb.amazonaws.com/api/clientes/v1/clientes/pf/$CLIENT_ID" \
  -H "Authorization: Bearer $TOKEN" | jq .

# 4. Atualizar cliente
curl -s -X PUT "https://your-alb.elb.amazonaws.com/api/clientes/v1/clientes/pf/$CLIENT_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"publicId\": \"$CLIENT_ID\",
    \"profissao\": \"Médico\"
  }" | jq .
```

---

**Última atualização:** 2025-11-06
**Versão da API:** v1
**Ambiente:** AWS ECS (sa-east-1)
