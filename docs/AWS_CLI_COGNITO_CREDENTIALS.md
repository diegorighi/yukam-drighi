# Como Obter Credenciais do Cognito via AWS CLI

Este guia mostra como obter o `CLIENT_ID` e `CLIENT_SECRET` do AWS Cognito usando o AWS CLI.

---

## 📋 Pré-requisitos

1. **AWS CLI instalado e configurado:**
   ```bash
   aws --version
   # Deve retornar: aws-cli/2.x.x Python/3.x.x ...
   ```

2. **Credenciais AWS configuradas:**
   ```bash
   aws configure list
   # Deve mostrar suas credenciais
   ```

3. **Região correta configurada:**
   ```bash
   aws configure get region
   # Deve retornar: sa-east-1
   ```

   Se não estiver configurado:
   ```bash
   aws configure set region sa-east-1
   ```

---

## 🔍 Passo 1: Encontrar o User Pool ID

### Opção A: Listar todos os User Pools

```bash
aws cognito-idp list-user-pools --max-results 10
```

**Você verá algo como:**
```json
{
  "UserPools": [
    {
      "Id": "sa-east-1_XXXXXXXXX",
      "Name": "yukam-user-pool",
      "CreationDate": "2025-11-05T10:00:00.000Z",
      "LastModifiedDate": "2025-11-06T15:00:00.000Z"
    }
  ]
}
```

**Copie o `Id`:** `sa-east-1_XXXXXXXXX`

### Opção B: Buscar pelo nome (mais rápido)

```bash
aws cognito-idp list-user-pools --max-results 10 \
  | jq -r '.UserPools[] | select(.Name=="yukam-user-pool") | .Id'
```

**Output esperado:**
```
sa-east-1_XXXXXXXXX
```

---

## 🔑 Passo 2: Listar App Clients do User Pool

### Comando:

```bash
USER_POOL_ID="sa-east-1_XXXXXXXXX"  # Substitua pelo ID obtido no Passo 1

aws cognito-idp list-user-pool-clients --user-pool-id $USER_POOL_ID
```

**Output:**
```json
{
  "UserPoolClients": [
    {
      "ClientId": "3q2r5s6t7u8v9w0x1y2z",
      "ClientName": "cliente-core-app",
      "UserPoolId": "sa-east-1_XXXXXXXXX"
    }
  ]
}
```

**Copie o `ClientId`:** `3q2r5s6t7u8v9w0x1y2z`

### Comando Simplificado (com jq):

```bash
aws cognito-idp list-user-pool-clients --user-pool-id $USER_POOL_ID \
  | jq -r '.UserPoolClients[] | "ClientId: \(.ClientId) | Name: \(.ClientName)"'
```

**Output:**
```
ClientId: 3q2r5s6t7u8v9w0x1y2z | Name: cliente-core-app
```

---

## 🔐 Passo 3: Obter o Client Secret

### Comando:

```bash
CLIENT_ID="3q2r5s6t7u8v9w0x1y2z"  # Substitua pelo ClientId obtido no Passo 2

aws cognito-idp describe-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID
```

**Output (muito longo, vou filtrar o importante):**
```json
{
  "UserPoolClient": {
    "UserPoolId": "sa-east-1_XXXXXXXXX",
    "ClientName": "cliente-core-app",
    "ClientId": "3q2r5s6t7u8v9w0x1y2z",
    "ClientSecret": "abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567",
    "AllowedOAuthFlows": ["client_credentials"],
    "AllowedOAuthScopes": ["cliente-core/read", "cliente-core/write"],
    "AllowedOAuthFlowsUserPoolClient": true,
    ...
  }
}
```

**Copie o `ClientSecret`:** `abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567`

### Comando Simplificado (apenas o secret):

```bash
aws cognito-idp describe-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  | jq -r '.UserPoolClient.ClientSecret'
```

**Output:**
```
abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567
```

---

## 🎯 Passo 4: Script Completo (Automático)

Salve este script como `get-cognito-credentials.sh`:

```bash
#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Buscando credenciais do Cognito...${NC}\n"

# 1. Buscar User Pool ID
echo -e "${YELLOW}1. Buscando User Pool...${NC}"
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 10 \
  | jq -r '.UserPools[] | select(.Name=="yukam-user-pool") | .Id')

if [ -z "$USER_POOL_ID" ]; then
  echo "❌ Erro: User Pool 'yukam-user-pool' não encontrado"
  exit 1
fi

echo -e "${GREEN}   ✓ User Pool ID: $USER_POOL_ID${NC}\n"

# 2. Buscar Client ID
echo -e "${YELLOW}2. Buscando App Client...${NC}"
CLIENT_INFO=$(aws cognito-idp list-user-pool-clients --user-pool-id $USER_POOL_ID \
  | jq -r '.UserPoolClients[] | select(.ClientName=="cliente-core-app")')

CLIENT_ID=$(echo $CLIENT_INFO | jq -r '.ClientId')

if [ -z "$CLIENT_ID" ]; then
  echo "❌ Erro: App Client 'cliente-core-app' não encontrado"
  exit 1
fi

echo -e "${GREEN}   ✓ Client ID: $CLIENT_ID${NC}\n"

# 3. Buscar Client Secret
echo -e "${YELLOW}3. Buscando Client Secret...${NC}"
CLIENT_SECRET=$(aws cognito-idp describe-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  | jq -r '.UserPoolClient.ClientSecret')

if [ -z "$CLIENT_SECRET" ]; then
  echo "❌ Erro: Client Secret não encontrado"
  exit 1
fi

echo -e "${GREEN}   ✓ Client Secret: ${CLIENT_SECRET:0:10}...${NC}\n"

# 4. Buscar Cognito Domain
echo -e "${YELLOW}4. Buscando Cognito Domain...${NC}"
DOMAIN=$(aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID \
  | jq -r '.UserPool.Domain // empty')

if [ -z "$DOMAIN" ]; then
  # Buscar custom domain
  DOMAIN=$(aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID \
    | jq -r '.UserPool.CustomDomain // "yukam-auth"')
fi

COGNITO_DOMAIN="${DOMAIN}.auth.sa-east-1.amazoncognito.com"
echo -e "${GREEN}   ✓ Cognito Domain: $COGNITO_DOMAIN${NC}\n"

# 5. Mostrar resumo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Credenciais do Cognito obtidas com sucesso!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo "📋 Use estas credenciais no Postman:"
echo ""
echo "USER_POOL_ID:    $USER_POOL_ID"
echo "CLIENT_ID:       $CLIENT_ID"
echo "CLIENT_SECRET:   $CLIENT_SECRET"
echo "COGNITO_DOMAIN:  $COGNITO_DOMAIN"
echo ""

# 6. Gerar .env file (opcional)
echo -e "${YELLOW}Deseja criar um arquivo .env com essas credenciais? (s/n)${NC}"
read -r CREATE_ENV

if [ "$CREATE_ENV" = "s" ] || [ "$CREATE_ENV" = "S" ]; then
  cat > .env.cognito << EOF
# AWS Cognito Credentials
# Gerado em: $(date)

USER_POOL_ID=$USER_POOL_ID
CLIENT_ID=$CLIENT_ID
CLIENT_SECRET=$CLIENT_SECRET
COGNITO_DOMAIN=$COGNITO_DOMAIN

# Token URL
TOKEN_URL=https://${COGNITO_DOMAIN}/oauth2/token

# Scopes
SCOPES=cliente-core/read cliente-core/write
EOF

  echo -e "${GREEN}✓ Arquivo .env.cognito criado!${NC}"
  echo -e "${YELLOW}⚠️  Não commite este arquivo! Adicione ao .gitignore${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
```

### Como usar o script:

```bash
# 1. Dar permissão de execução
chmod +x get-cognito-credentials.sh

# 2. Executar
./get-cognito-credentials.sh
```

**Output esperado:**
```
🔍 Buscando credenciais do Cognito...

1. Buscando User Pool...
   ✓ User Pool ID: sa-east-1_XXXXXXXXX

2. Buscando App Client...
   ✓ Client ID: 3q2r5s6t7u8v9w0x1y2z

3. Buscando Client Secret...
   ✓ Client Secret: abc123def4...

4. Buscando Cognito Domain...
   ✓ Cognito Domain: yukam-auth.auth.sa-east-1.amazoncognito.com

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Credenciais do Cognito obtidas com sucesso!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Use estas credenciais no Postman:

USER_POOL_ID:    sa-east-1_XXXXXXXXX
CLIENT_ID:       3q2r5s6t7u8v9w0x1y2z
CLIENT_SECRET:   abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567
COGNITO_DOMAIN:  yukam-auth.auth.sa-east-1.amazoncognito.com
```

---

## 🧪 Passo 5: Testar as Credenciais

Teste se as credenciais funcionam obtendo um token:

```bash
CLIENT_ID="3q2r5s6t7u8v9w0x1y2z"
CLIENT_SECRET="abc123def456..."
COGNITO_DOMAIN="yukam-auth.auth.sa-east-1.amazoncognito.com"

curl -X POST https://$COGNITO_DOMAIN/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
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

Se receber esse JSON, **está tudo OK!** ✅

---

## 📝 Passo 6: Usar no Postman

Agora é só preencher no Postman Environment:

1. Abra o Postman
2. Selecione o Environment (Development ou Production)
3. Clique no ícone de olho 👁️
4. Clique em **Edit**
5. Preencha:
   - `cognito_domain` → `yukam-auth.auth.sa-east-1.amazoncognito.com`
   - `client_id` → `3q2r5s6t7u8v9w0x1y2z`
   - `client_secret` → `abc123def456...`
6. Clique em **Save**

---

## ⚠️ Troubleshooting

### Erro: "Unable to locate credentials"

**Causa:** AWS CLI não configurado

**Solução:**
```bash
aws configure
# Preencha:
# AWS Access Key ID: AKIA...
# AWS Secret Access Key: ...
# Default region name: sa-east-1
# Default output format: json
```

### Erro: "User Pool not found"

**Causa:** Nome do User Pool está diferente

**Solução:** Liste todos os User Pools:
```bash
aws cognito-idp list-user-pools --max-results 10 | jq -r '.UserPools[].Name'
```

Copie o nome exato e substitua `yukam-user-pool` no script.

### Erro: "Access denied"

**Causa:** Suas credenciais AWS não têm permissão para acessar Cognito

**Solução:** Peça ao admin para adicionar a policy `AmazonCognitoPowerUser` ou:
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

### Client Secret não aparece (vazio)

**Causa:** O App Client foi criado sem Client Secret

**Solução:**
1. Acesse o Console AWS → Cognito
2. Edite o App Client
3. Marque **"Generate client secret"**
4. Salve e obtenha o novo Client ID + Secret

---

## 🔒 Segurança

**⚠️ IMPORTANTE:**

1. **NUNCA commite** o Client Secret no Git
2. **Adicione ao .gitignore:**
   ```bash
   echo ".env.cognito" >> .gitignore
   echo "get-cognito-credentials.sh" >> .gitignore  # Se contiver credenciais hardcoded
   ```
3. **Use variáveis de ambiente** em produção
4. **Rotacione** o Client Secret periodicamente
5. **Use AWS Secrets Manager** para armazenar em produção

---

## 📚 Recursos Adicionais

### Comandos úteis:

**Ver todos os detalhes do User Pool:**
```bash
aws cognito-idp describe-user-pool --user-pool-id sa-east-1_XXXXXXXXX
```

**Ver scopes permitidos:**
```bash
aws cognito-idp describe-user-pool-client \
  --user-pool-id sa-east-1_XXXXXXXXX \
  --client-id 3q2r5s6t7u8v9w0x1y2z \
  | jq -r '.UserPoolClient.AllowedOAuthScopes[]'
```

**Ver Resource Servers:**
```bash
aws cognito-idp list-resource-servers --user-pool-id sa-east-1_XXXXXXXXX
```

---

**Última atualização:** 2025-11-06
**Região:** sa-east-1
**Contato:** Se tiver dúvidas, abra uma issue
