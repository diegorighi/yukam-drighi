# Postman OAuth2 - Passo a Passo CORRETO

## 🚫 O que NÃO fazer

**ERRADO**: Usar "Basic Auth" na aba Authorization
```
Auth Type: Basic Auth
Username: 41u8or3q6id9nm8395qvl214j
Password: i64vo56mdf5m2ig9q0tu0ur6lsdb1tius
```

**Por quê está errado?**
- Basic Auth envia credenciais DIRETAMENTE no header de cada request
- OAuth2 usa credenciais para OBTER um token JWT primeiro
- AWS Cognito **não aceita** Basic Auth no endpoint `/oauth2/token`

---

## ✅ Configuração CORRETA - Passo a Passo

### Passo 1: Criar uma Nova Request (ou Collection)

1. Abra o Postman
2. Crie uma nova request ou vá na Collection existente
3. Clique na aba **"Authorization"**

### Passo 2: Selecionar OAuth 2.0

```
┌─────────────────────────────────────────┐
│ Type: [OAuth 2.0         ▼]             │  ← IMPORTANTE: OAuth 2.0, NÃO Basic Auth!
└─────────────────────────────────────────┘
```

### Passo 3: Configurar Token

Você verá uma seção com botões. Clique em **"Configure New Token"** ou role para baixo e preencha:

```
┌──────────────────────────────────────────────────────────────┐
│ Token Name:                                                  │
│ ┌────────────────────────────────────────────────┐           │
│ │ Cognito Access Token                           │           │
│ └────────────────────────────────────────────────┘           │
│                                                              │
│ Grant Type: [Client Credentials              ▼]             │
│                                                              │
│ Access Token URL:                                            │
│ ┌────────────────────────────────────────────────┐           │
│ │ https://vanessa-mudanca-auth-prod.auth.sa-east-│           │
│ │ 1.amazoncognito.com/oauth2/token               │           │
│ └────────────────────────────────────────────────┘           │
│                                                              │
│ Client ID:                                                   │
│ ┌────────────────────────────────────────────────┐           │
│ │ 41u8or3q6id9nm8395qvl214j                      │           │
│ └────────────────────────────────────────────────┘           │
│                                                              │
│ Client Secret:                                               │
│ ┌────────────────────────────────────────────────┐           │
│ │ i64vo56mdf5m2ig9q0tu0ur6lsdb1tius              │ [Show]    │
│ └────────────────────────────────────────────────┘           │
│                                                              │
│ Scope:                                                       │
│ ┌────────────────────────────────────────────────┐           │
│ │ cliente-core/read cliente-core/write           │           │
│ └────────────────────────────────────────────────┘           │
│                                                              │
│ Client Authentication:                                       │
│ [Send as Basic Auth header                    ▼]  ⭐ CRÍTICO│
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Passo 4: ⭐ CAMPO MAIS IMPORTANTE ⭐

**Client Authentication: Send as Basic Auth header**

```
┌─────────────────────────────────────────────────────────┐
│ Client Authentication:                                  │
│                                                         │
│ ○ Send client credentials in body                      │  ← NÃO!
│ ● Send as Basic Auth header                            │  ← SIM! ✅
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Por quê?**
- AWS Cognito **exige** que o client_id e client_secret sejam enviados via **Basic Auth header** na requisição para `/oauth2/token`
- Mas isso é diferente de usar "Auth Type: Basic Auth" na request!
- O Postman vai:
  1. Criar um header `Authorization: Basic base64(client_id:client_secret)`
  2. Fazer POST para `/oauth2/token` com `grant_type=client_credentials`
  3. Receber um JWT de volta
  4. **Usar esse JWT** nos seus requests para a API

### Passo 5: Obter o Token

1. **Clique no botão laranja** no final da configuração:

```
┌──────────────────────────────────────┐
│                                      │
│    [Get New Access Token]            │  ← CLIQUE AQUI
│                                      │
└──────────────────────────────────────┘
```

2. Aguarde alguns segundos

3. Você verá uma janela de sucesso:

```
┌─────────────────────────────────────────────┐
│  ✅ Authentication complete                  │
│                                             │
│  Token Details:                             │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  Access Token: eyJraWQiOiJxc1wvXC8rNjBk...  │
│  Token Type: Bearer                         │
│  Expires In: 3600                           │
│                                             │
│           [Use Token]  [Cancel]             │  ← CLIQUE EM "Use Token"
│                                             │
└─────────────────────────────────────────────┘
```

### Passo 6: Usar o Token nas Requests

Depois de clicar em **"Use Token"**:

1. O token JWT será **automaticamente** adicionado aos seus requests
2. Você verá no dropdown de tokens:

```
┌─────────────────────────────────────────┐
│ Current Token: [Cognito Access Token ▼] │  ← Token ativo
└─────────────────────────────────────────┘
```

3. Quando fizer um request, o Postman adiciona automaticamente:

```
Headers:
Authorization: Bearer eyJraWQiOiJxc1wvXC8rNjBkQ0dGK0lqN3R...
```

---

## 🧪 Testando

### Request 1: Health Check (sem autenticação)

```
GET http://localhost:8081/api/clientes/actuator/health
```

**Response esperado:**
```json
{
  "status": "UP"
}
```

### Request 2: Criar Cliente PF (com autenticação)

```
POST http://localhost:8081/api/clientes/v1/clientes/pf
Authorization: Bearer eyJraWQiOiJxc1wvXC8rNjBkQ0dGK0lqN...  ← Adicionado automaticamente!

{
  "nome": "João Silva",
  "cpf": "12345678900",
  "email": "joao@example.com",
  "telefone": "11999999999"
}
```

**Response esperado: 201 Created**
```json
{
  "publicId": "uuid-aqui",
  "nome": "João Silva",
  "cpf": "12345678900",
  "email": "joao@example.com",
  "telefone": "11999999999",
  "ativo": true,
  "createdAt": "2025-11-06T10:00:00Z"
}
```

---

## 📊 Comparação: Basic Auth vs OAuth2 Client Credentials

| Aspecto | Basic Auth (ERRADO) | OAuth2 Client Credentials (CORRETO) |
|---------|---------------------|-------------------------------------|
| **Como funciona** | Envia `user:pass` em base64 em CADA request | Usa credenciais para OBTER um token JWT, depois usa o token |
| **Header enviado** | `Authorization: Basic <base64>` | `Authorization: Bearer <jwt>` |
| **Segurança** | Credenciais trafegam em todo request | Credenciais usadas apenas para obter token |
| **Expiração** | Não expira (sempre as mesmas credenciais) | Token expira (1h), Postman renova automaticamente |
| **Compatível com Cognito?** | ❌ NÃO | ✅ SIM |
| **O que o Sensedia usa?** | - | OAuth2 Client Credentials |

---

## 🔍 Como Verificar se Está Correto

### ✅ Checklist ANTES de clicar "Get New Access Token":

- [ ] **Type**: OAuth 2.0 (NÃO Basic Auth)
- [ ] **Grant Type**: Client Credentials
- [ ] **Access Token URL**: Termina com `/oauth2/token`
- [ ] **Client Authentication**: **Send as Basic Auth header** ⭐
- [ ] **Scope**: `cliente-core/read cliente-core/write` (com espaço)

### ✅ Depois de obter o token:

1. Abra o **Postman Console** (View → Show Postman Console)
2. Clique em "Get New Access Token"
3. Verifique no console:

```
Request to https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token

Request Headers:
Authorization: Basic NDF1OG9yM3E2aWQ5bm04Mzk1cXZsMjE0ajppNjR2bzU2bWRmNW0yaWc5cTB0dTBvcjZsc2RiMXRpdXM=
Content-Type: application/x-www-form-urlencoded

Request Body:
grant_type=client_credentials&scope=cliente-core/read%20cliente-core/write

Response:
{
  "access_token": "eyJraWQiOiJ...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

Se você ver isso ☝️ está CORRETO! ✅

---

## 🚨 Erros Comuns

### Erro: "Could not send request"

**Causa**: Você está tentando fazer um POST manual para `/oauth2/token`

**Solução**:
- NÃO crie uma request separada para `/oauth2/token`
- Use a aba **Authorization** → **OAuth 2.0** → **Get New Access Token**

### Erro: 405 Method Not Allowed

**Causa**:
1. Você está usando "Basic Auth" ao invés de "OAuth 2.0"
2. Ou "Client Authentication" está em "Send client credentials in body"

**Solução**:
- Type: **OAuth 2.0**
- Client Authentication: **Send as Basic Auth header**

### Erro: "error": "invalid_client"

**Causa**: Client ID ou Client Secret incorretos

**Solução**: Verifique as credenciais via AWS CLI:
```bash
./scripts/get-cognito-credentials.sh
```

---

## 🎬 Resumo Visual do Fluxo

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Você configura OAuth 2.0 no Postman                         │
│    ├─ Grant Type: Client Credentials                           │
│    ├─ Client ID: 41u8or3q6id9nm8395qvl214j                     │
│    ├─ Client Secret: i64vo56mdf5m2ig9q0tu0ur6lsdb1tius         │
│    └─ Client Authentication: Send as Basic Auth header ⭐      │
│                                                                 │
│ 2. Você clica "Get New Access Token"                           │
│    ├─ Postman faz POST /oauth2/token                           │
│    ├─ Envia Basic Auth header com client_id:client_secret      │
│    └─ Cognito retorna JWT                                      │
│                                                                 │
│ 3. Você clica "Use Token"                                      │
│    └─ Postman salva o JWT                                      │
│                                                                 │
│ 4. Você faz requests para sua API                              │
│    ├─ GET /v1/clientes/pf                                      │
│    ├─ POST /v1/clientes/pf                                     │
│    └─ Postman adiciona automaticamente:                        │
│        Authorization: Bearer <jwt>                             │
│                                                                 │
│ 5. Token expira após 1h                                        │
│    └─ Postman automaticamente pega um novo! 🎉                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## ✅ Próximos Passos

1. **Deletar** qualquer request manual que você criou para `/oauth2/token`
2. **Configurar OAuth 2.0** na Collection ou em cada request
3. **Clicar "Get New Access Token"**
4. **Clicar "Use Token"**
5. **Testar** fazendo um POST para criar um cliente

---

**Última atualização:** 2025-11-06
**Testado com:** Postman v10.x, AWS Cognito
**Ambiente:** vanessa-mudanca-auth-prod
