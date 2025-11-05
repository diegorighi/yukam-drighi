#!/bin/bash
# Script para gerar JWT Token do Cognito rapidamente
# Uso: ./get-jwt-token.sh

USER_POOL_ID="sa-east-1_hXX8OVC7K"
CLIENT_ID="4lt5o3071l37jh4s18liilsp4m"
USERNAME="admin@vanessamudanca.com.br"
PASSWORD="Admin@Test123"

echo "🔐 Gerando JWT Token do AWS Cognito..."
echo ""

# Obter tokens
RESPONSE=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "$CLIENT_ID" \
  --auth-parameters "USERNAME=$USERNAME,PASSWORD=$PASSWORD" \
  --region sa-east-1 \
  --output json)

# Extrair Access Token
ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.AuthenticationResult.AccessToken')
ID_TOKEN=$(echo "$RESPONSE" | jq -r '.AuthenticationResult.IdToken')
EXPIRES_IN=$(echo "$RESPONSE" | jq -r '.AuthenticationResult.ExpiresIn')

echo "✅ Token gerado com sucesso!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 ACCESS TOKEN (Use este no Postman):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$ACCESS_TOKEN"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 ID TOKEN (Contém custom:role = ADMIN):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$ID_TOKEN"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏱️  Expira em: $EXPIRES_IN segundos ($(($EXPIRES_IN / 60)) minutos)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Como usar no Postman:"
echo ""
echo "1. Criar nova Request"
echo "2. Aba 'Authorization'"
echo "3. Type: Bearer Token"
echo "4. Token: (cole o ACCESS TOKEN acima)"
echo ""
echo "🧪 Endpoints para testar:"
echo ""
echo "Health Check (não protegido):"
echo "GET http://cliente-core-prod-alb-530184476864.sa-east-1.elb.amazonaws.com/api/clientes/actuator/health"
echo ""
echo "Listar Clientes PF (protegido - requer ADMIN):"
echo "GET http://cliente-core-prod-alb-530184476864.sa-east-1.elb.amazonaws.com/v1/clientes/pf"
echo "Authorization: Bearer <ACCESS_TOKEN>"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Dica: Decodifique o token em https://jwt.io para ver os claims"
echo ""
