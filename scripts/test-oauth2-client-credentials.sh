#!/bin/bash
# Test OAuth2 Client Credentials Flow

CLIENT_ID="46cfgoegvctki8lfibv2nl4c8f"
CLIENT_SECRET="8kp3skqnq175h8l220km8qrqtdaj82boo75plabsf28glivcsj8"

# Encode credentials in Base64
CREDENTIALS=$(echo -n "${CLIENT_ID}:${CLIENT_SECRET}" | base64)

echo "🔐 Testing OAuth2 Client Credentials Flow"
echo ""
echo "Client ID: $CLIENT_ID"
echo "Credentials (Base64): $CREDENTIALS"
echo ""
echo "Requesting token from Cognito..."
echo ""

# Request token
RESPONSE=$(curl -s -X POST \
  "https://vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Basic ${CREDENTIALS}" \
  -d "grant_type=client_credentials&scope=https://api.vanessamudanca.com.br/cliente-core/clientes.read")

echo "$RESPONSE" | jq

# Extract access token
ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" != "null" ] && [ -n "$ACCESS_TOKEN" ]; then
    echo ""
    echo "✅ SUCCESS! Token obtained:"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "ACCESS TOKEN:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$ACCESS_TOKEN"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 Use this in Postman:"
    echo "Authorization: Bearer $ACCESS_TOKEN"
    echo ""
else
    echo ""
    echo "❌ FAILED! Could not obtain token."
    echo ""
fi
