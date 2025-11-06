# Troubleshooting OAuth2 - Erro 405 Method Not Allowed

## 🔴 Erro: 405 Method Not Allowed

Este erro acontece quando a requisição OAuth2 não está configurada corretamente no Postman.

---

## ✅ Solução: Configuração Correta no Postman

### Problema Comum:

Você **NÃO** deve fazer um POST manual com body JSON. O Postman tem uma configuração especial para OAuth2.

### Configuração Correta (Passo a Passo):

#### 1️⃣ Abra a Collection ou Request

1. Clique na **Collection** "Cliente Core API - OAuth2"
2. Ou clique em qualquer **request** dentro da Collection

#### 2️⃣ Vá na Aba "Authorization"

1. Selecione a aba **"Authorization"**
2. Em **"Type"**, selecione **"OAuth 2.0"**
3. Em **"Add auth data to"**, selecione **"Request Headers"**

#### 3️⃣ Configure os Campos EXATAMENTE Assim:

**⚠️ IMPORTANTE: Não confunda os campos!**

```
Configuration Options:
├─ Token Name: Cognito Access Token
├─ Grant Type: Client Credentials
├─ Access Token URL: https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token
├─ Client ID: 41u8or3q6id9nm8395qvl214j
├─ Client Secret: ei44vao0m1mfhf9rb8064vo56mdf5m2ig9q0tu0ur6lsdb1tius
├─ Scope: cliente-core/read cliente-core/write
├─ Client Authentication: Send as Basic Auth header ⭐ CRÍTICO!
```

**Screenshot de referência:**
```
┌─────────────────────────────────────────────────────────┐
│ Type: OAuth 2.0                            [Configure New Token] │
├─────────────────────────────────────────────────────────┤
│ Token Name:             Cognito Access Token            │
│ Grant Type:             Client Credentials              │
│ Access Token URL:       https://vanessa-mudanca-auth... │
│ Client ID:              41u8or3q6id9nm8395qvl214j       │
│ Client Secret:          ei44vao0m1mfhf9rb8064vo56m...   │
│ Scope:                  cliente-core/read cliente-co... │
│ Client Authentication:  Send as Basic Auth header ⭐    │
└─────────────────────────────────────────────────────────┘
                    [Get New Access Token]
```

#### 4️⃣ Clique em "Get New Access Token"

1. Botão laranja no final da seção de configuração
2. Uma janela vai aparecer mostrando o processo
3. Se der certo, você verá:

```
✅ Authentication complete

Token Details:
- Access Token: eyJraWQiOiJ...
- Token Type: Bearer
- Expires In: 3600
```

#### 5️⃣ Clique em "Use Token"

1. Botão azul na janela de sucesso
2. O token será adicionado automaticamente aos requests

---

## ❌ Erros Comuns e Soluções

### Erro 1: "Client Authentication" Errado

**❌ ERRADO:**
```
Client Authentication: Send client credentials in body
```

**✅ CORRETO:**
```
Client Authentication: Send as Basic Auth header
```

**Por quê?**
O AWS Cognito **exige** que as credenciais sejam enviadas via **Basic Authentication** no header, não no body.

---

### Erro 2: Scope Incorreto

**❌ ERRADO:**
```
Scope: (vazio)
Scope: read write
Scope: cliente-core
```

**✅ CORRETO:**
```
Scope: cliente-core/read cliente-core/write
```

**Por quê?**
Os scopes devem estar **exatamente** como configurado no Cognito Resource Server:
- `cliente-core/read`
- `cliente-core/write`

Separados por **espaço** (não vírgula).

---

### Erro 3: URL Incorreta

**❌ ERRADO:**
```
https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/
https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2
https://cognito-idp.sa-east-1.amazonaws.com/oauth2/token
```

**✅ CORRETO:**
```
https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token
```

**Por quê?**
A URL precisa:
- Terminar com `/oauth2/token`
- Usar o domínio Cognito (não `cognito-idp`)
- Não ter barra final

---

### Erro 4: Tentando Fazer POST Manual

**❌ ERRADO: Criar um request manual tipo:**
```
Method: POST
URL: https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token
Body:
{
  "client_id": "41u8or3q6id9nm8395qvl214j",
  "client_secret": "ei44vao0m1mfhf9rb8064vo56mdf5m2ig9q0tu0ur6lsdb1tius",
  "grant_type": "client_credentials"
}
```

**✅ CORRETO:**
Usar a aba **"Authorization"** → **"OAuth 2.0"** → **"Get New Access Token"**

---

## 🧪 Teste Manual via cURL (para debug)

Se quiser testar as credenciais fora do Postman:

```bash
curl -X POST https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "41u8or3q6id9nm8395qvl214j:ei44vao0m1mfhf9rb8064vo56mdf5m2ig9q0tu0ur6lsdb1tius" \
  -d "grant_type=client_credentials&scope=cliente-core/read cliente-core/write"
```

**Explicação do cURL:**
- `-u "client_id:client_secret"` → Cria o **Basic Auth header** automaticamente
- `-H "Content-Type: application/x-www-form-urlencoded"` → Tipo do body
- `-d "grant_type=..."` → Body em formato URL-encoded (não JSON!)

**Response esperado (sucesso):**
```json
{
  "access_token": "eyJraWQiOiJxc1wvXC8rNjBkQ0dGK0lqN...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

**Response de erro (credenciais inválidas):**
```json
{
  "error": "invalid_client"
}
```

---

## 🔍 Verificar se o App Client está Configurado Corretamente

### Via AWS CLI:

```bash
aws cognito-idp describe-user-pool-client \
  --user-pool-id sa-east-1_XXXXXXXXX \
  --client-id 41u8or3q6id9nm8395qvl214j \
  | jq '{
      ClientName: .UserPoolClient.ClientName,
      ClientId: .UserPoolClient.ClientId,
      HasSecret: (.UserPoolClient.ClientSecret != null),
      AllowedFlows: .UserPoolClient.AllowedOAuthFlows,
      AllowedScopes: .UserPoolClient.AllowedOAuthScopes,
      Enabled: .UserPoolClient.AllowedOAuthFlowsUserPoolClient
    }'
```

**Output esperado:**
```json
{
  "ClientName": "cliente-core-app",
  "ClientId": "41u8or3q6id9nm8395qvl214j",
  "HasSecret": true,
  "AllowedFlows": ["client_credentials"],
  "AllowedScopes": ["cliente-core/read", "cliente-core/write"],
  "Enabled": true
}
```

**Problemas comuns:**

1. **`HasSecret: false`**
   - **Solução:** Recriar App Client com "Generate client secret" habilitado

2. **`AllowedFlows` não contém `"client_credentials"`**
   - **Solução:** Editar App Client → Marcar "Client credentials"

3. **`Enabled: false`**
   - **Solução:** Editar App Client → Marcar "Enable OAuth 2.0 flows"

4. **`AllowedScopes` está vazio ou diferente**
   - **Solução:** Editar App Client → Adicionar scopes do Resource Server

---

## 📝 Checklist de Troubleshooting

Antes de tentar novamente, verifique:

- [ ] **URL completa e correta** (com `/oauth2/token`)
- [ ] **Grant Type** = `Client Credentials`
- [ ] **Client Authentication** = `Send as Basic Auth header` ⭐
- [ ] **Scope** = `cliente-core/read cliente-core/write` (com espaço, não vírgula)
- [ ] **Client ID** está correto (41u8or3q6id9nm8395qvl214j)
- [ ] **Client Secret** está correto
- [ ] **Não está** tentando fazer POST manual no body
- [ ] **Está usando** a aba Authorization → OAuth 2.0

---

## 🎬 Passo a Passo com Screenshots

### 1. Abra a Collection

![Postman Collection](https://via.placeholder.com/600x100/0066cc/ffffff?text=Cliente+Core+API+-+OAuth2)

### 2. Aba Authorization

```
┌──────────────────────────────────────┐
│  Variables  Authorization  Pre-req  │  ← Clique aqui
├──────────────────────────────────────┤
│                                      │
│  Type: OAuth 2.0 ▼                   │
│                                      │
│  Add auth data to: Request Headers  │
│                                      │
│  [Configure New Token]               │
│                                      │
```

### 3. Preencha os Campos

```
Token Name:
┌──────────────────────────────────────┐
│ Cognito Access Token                 │
└──────────────────────────────────────┘

Grant Type: Client Credentials ▼

Access Token URL:
┌──────────────────────────────────────┐
│ https://vanessa-mudanca-auth-prod... │
└──────────────────────────────────────┘

Client ID:
┌──────────────────────────────────────┐
│ 41u8or3q6id9nm8395qvl214j           │
└──────────────────────────────────────┘

Client Secret:
┌──────────────────────────────────────┐
│ ei44vao0m1mfhf9rb8064vo56mdf5m2...  │ [Show]
└──────────────────────────────────────┘

Scope:
┌──────────────────────────────────────┐
│ cliente-core/read cliente-core/write │
└──────────────────────────────────────┘

Client Authentication:
Send as Basic Auth header ▼  ⭐ IMPORTANTE!
```

### 4. Get New Access Token

```
┌──────────────────────────────────────┐
│                                      │
│     [Get New Access Token]           │ ← Clique aqui
│                                      │
└──────────────────────────────────────┘
```

### 5. Sucesso!

```
┌─────────────────────────────────────┐
│  ✅ Authentication complete          │
│                                     │
│  Token Details:                     │
│  Access Token: eyJraWQiOiJ...       │
│  Token Type: Bearer                 │
│  Expires In: 3600                   │
│                                     │
│           [Use Token]               │ ← Clique aqui
└─────────────────────────────────────┘
```

---

## 🚨 Ainda com Erro?

### Se ainda estiver com erro 405:

1. **Copie EXATAMENTE** a configuração abaixo:

```
Type: OAuth 2.0
Grant Type: Client Credentials
Access Token URL: https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token
Client ID: 41u8or3q6id9nm8395qvl214j
Client Secret: ei44vao0m1mfhf9rb8064vo56mdf5m2ig9q0tu0ur6lsdb1tius
Scope: cliente-core/read cliente-core/write
Client Authentication: Send as Basic Auth header
```

2. **Teste via cURL** primeiro para confirmar que as credenciais funcionam:

```bash
curl -v -X POST https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "41u8or3q6id9nm8395qvl214j:ei44vao0m1mfhf9rb8064vo56mdf5m2ig9q0tu0ur6lsdb1tius" \
  -d "grant_type=client_credentials&scope=cliente-core/read cliente-core/write"
```

3. **Verifique o User Pool ID** correto:

```bash
aws cognito-idp list-user-pools --max-results 10 | jq -r '.UserPools[] | select(.Name=="vanessa-mudanca-user-pool-prod") | .Id'
```

4. **Verifique se o Resource Server existe:**

```bash
USER_POOL_ID="sa-east-1_XXXXXXXXX"  # Use o ID correto
aws cognito-idp list-resource-servers --user-pool-id $USER_POOL_ID | jq -r '.ResourceServers[] | select(.Identifier=="cliente-core")'
```

---

## 📞 Precisa de Ajuda?

Se ainda estiver com problemas:

1. **Rode o script de diagnóstico:**
   ```bash
   ./scripts/get-cognito-credentials.sh
   # Escolha "s" para testar o token
   ```

2. **Copie o erro completo** do Postman Console:
   - View → Show Postman Console
   - Copie a request completa e o response

3. **Verifique os logs do CloudWatch** (se aplicável):
   ```
   Log Group: /aws/cognito/userpools/sa-east-1_XXXXXXXXX
   ```

---

**Última atualização:** 2025-11-06
**Testado com:** Postman v10.x, AWS Cognito
