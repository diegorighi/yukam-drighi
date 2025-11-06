#!/bin/bash

# Script para obter credenciais do AWS Cognito
# Uso: ./get-cognito-credentials.sh

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Buscando credenciais do Cognito...${NC}\n"

# 1. Buscar User Pool ID
echo -e "${YELLOW}1. Buscando User Pool...${NC}"
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 10 \
  | jq -r '.UserPools[] | select(.Name=="yukam-user-pool") | .Id')

if [ -z "$USER_POOL_ID" ]; then
  echo -e "${RED}❌ Erro: User Pool 'yukam-user-pool' não encontrado${NC}"
  echo -e "${YELLOW}💡 Dica: Liste todos os User Pools:${NC}"
  echo "   aws cognito-idp list-user-pools --max-results 10 | jq -r '.UserPools[].Name'"
  exit 1
fi

echo -e "${GREEN}   ✓ User Pool ID: $USER_POOL_ID${NC}\n"

# 2. Buscar Client ID
echo -e "${YELLOW}2. Buscando App Client...${NC}"
CLIENT_INFO=$(aws cognito-idp list-user-pool-clients --user-pool-id $USER_POOL_ID \
  | jq -r '.UserPoolClients[] | select(.ClientName=="cliente-core-app")')

CLIENT_ID=$(echo $CLIENT_INFO | jq -r '.ClientId')

if [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" = "null" ]; then
  echo -e "${RED}❌ Erro: App Client 'cliente-core-app' não encontrado${NC}"
  echo -e "${YELLOW}💡 Dica: Liste todos os App Clients:${NC}"
  echo "   aws cognito-idp list-user-pool-clients --user-pool-id $USER_POOL_ID | jq -r '.UserPoolClients[].ClientName'"
  exit 1
fi

echo -e "${GREEN}   ✓ Client ID: $CLIENT_ID${NC}\n"

# 3. Buscar Client Secret
echo -e "${YELLOW}3. Buscando Client Secret...${NC}"
CLIENT_SECRET=$(aws cognito-idp describe-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  | jq -r '.UserPoolClient.ClientSecret // empty')

if [ -z "$CLIENT_SECRET" ]; then
  echo -e "${RED}❌ Erro: Client Secret não encontrado${NC}"
  echo -e "${YELLOW}⚠️  Este App Client pode não ter Client Secret habilitado${NC}"
  echo -e "${YELLOW}💡 Solução: Acesse o Console AWS → Cognito → App Client → Edite e habilite 'Generate client secret'${NC}"
  exit 1
fi

echo -e "${GREEN}   ✓ Client Secret: ${CLIENT_SECRET:0:10}...${NC}\n"

# 4. Buscar Cognito Domain
echo -e "${YELLOW}4. Buscando Cognito Domain...${NC}"
DOMAIN=$(aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID \
  | jq -r '.UserPool.Domain // empty')

if [ -z "$DOMAIN" ]; then
  # Tentar buscar custom domain
  CUSTOM_DOMAIN=$(aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID \
    | jq -r '.UserPool.CustomDomain // empty')

  if [ -z "$CUSTOM_DOMAIN" ]; then
    # Usar default baseado no nome do User Pool
    DOMAIN="yukam-auth"
  else
    DOMAIN="$CUSTOM_DOMAIN"
  fi
fi

REGION=$(aws configure get region || echo "sa-east-1")
COGNITO_DOMAIN="${DOMAIN}.auth.${REGION}.amazoncognito.com"
echo -e "${GREEN}   ✓ Cognito Domain: $COGNITO_DOMAIN${NC}\n"

# 5. Buscar scopes permitidos
echo -e "${YELLOW}5. Buscando scopes permitidos...${NC}"
SCOPES=$(aws cognito-idp describe-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  | jq -r '.UserPoolClient.AllowedOAuthScopes | join(" ")')

echo -e "${GREEN}   ✓ Scopes: $SCOPES${NC}\n"

# 6. Mostrar resumo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Credenciais do Cognito obtidas com sucesso!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo "📋 Use estas credenciais no Postman Environment:"
echo ""
echo "cognito_domain:  $COGNITO_DOMAIN"
echo "client_id:       $CLIENT_ID"
echo "client_secret:   $CLIENT_SECRET"
echo ""

echo "📋 Variáveis completas:"
echo ""
echo "USER_POOL_ID=$USER_POOL_ID"
echo "CLIENT_ID=$CLIENT_ID"
echo "CLIENT_SECRET=$CLIENT_SECRET"
echo "COGNITO_DOMAIN=$COGNITO_DOMAIN"
echo "SCOPES=$SCOPES"
echo ""

# 7. Testar obtendo um token
echo -e "${YELLOW}Deseja testar obtendo um token? (s/n)${NC}"
read -r TEST_TOKEN

if [ "$TEST_TOKEN" = "s" ] || [ "$TEST_TOKEN" = "S" ]; then
  echo -e "\n${YELLOW}🔄 Obtendo token...${NC}\n"

  TOKEN_RESPONSE=$(curl -s -X POST https://$COGNITO_DOMAIN/oauth2/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -u "$CLIENT_ID:$CLIENT_SECRET" \
    -d "grant_type=client_credentials&scope=$SCOPES")

  ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token // empty')

  if [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}❌ Erro ao obter token${NC}"
    echo -e "${YELLOW}Response:${NC}"
    echo "$TOKEN_RESPONSE" | jq .
  else
    echo -e "${GREEN}✅ Token obtido com sucesso!${NC}\n"
    echo "Access Token (primeiros 50 chars):"
    echo "${ACCESS_TOKEN:0:50}..."
    echo ""
    echo "Expires in: $(echo $TOKEN_RESPONSE | jq -r '.expires_in') seconds ($(echo $TOKEN_RESPONSE | jq -r '.expires_in/60') minutos)"
    echo "Token type: $(echo $TOKEN_RESPONSE | jq -r '.token_type')"
  fi
fi

# 8. Gerar .env file (opcional)
echo -e "\n${YELLOW}Deseja criar um arquivo .env com essas credenciais? (s/n)${NC}"
read -r CREATE_ENV

if [ "$CREATE_ENV" = "s" ] || [ "$CREATE_ENV" = "S" ]; then
  ENV_FILE="$(dirname "$0")/../.env.cognito"

  cat > "$ENV_FILE" << EOF
# AWS Cognito Credentials
# Gerado em: $(date)
# ⚠️  NÃO COMMITE ESTE ARQUIVO! Adicione ao .gitignore

# User Pool
USER_POOL_ID=$USER_POOL_ID

# App Client
CLIENT_ID=$CLIENT_ID
CLIENT_SECRET=$CLIENT_SECRET

# Endpoints
COGNITO_DOMAIN=$COGNITO_DOMAIN
TOKEN_URL=https://${COGNITO_DOMAIN}/oauth2/token

# Scopes
SCOPES=$SCOPES

# Região
AWS_REGION=$REGION
EOF

  echo -e "${GREEN}✓ Arquivo criado: $ENV_FILE${NC}"
  echo -e "${YELLOW}⚠️  Não commite este arquivo! Adicione ao .gitignore${NC}"

  # Verificar se já está no .gitignore
  GITIGNORE="$(dirname "$0")/../.gitignore"
  if [ -f "$GITIGNORE" ]; then
    if ! grep -q ".env.cognito" "$GITIGNORE"; then
      echo ".env.cognito" >> "$GITIGNORE"
      echo -e "${GREEN}✓ Adicionado .env.cognito ao .gitignore${NC}"
    fi
  fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Concluído! Agora você pode usar essas credenciais no Postman.${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
