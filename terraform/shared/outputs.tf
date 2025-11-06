# ==============================================================================
# Outputs - Valores para serem usados pelos microserviços
# ==============================================================================

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID (compartilhado entre todos os MS)"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_user_pool_endpoint" {
  description = "Cognito User Pool Endpoint"
  value       = aws_cognito_user_pool.main.endpoint
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.web_client.id
}

output "cognito_client_secret" {
  description = "Cognito App Client Secret"
  value       = aws_cognito_user_pool_client.web_client.client_secret
  sensitive   = true
}

output "cognito_issuer_url" {
  description = "Cognito Issuer URL (para Spring Security JWT validation)"
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
}

output "cognito_jwks_uri" {
  description = "Cognito JWKS URI (para validar assinatura JWT)"
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}/.well-known/jwks.json"
}

output "cognito_domain" {
  description = "Cognito Hosted UI Domain"
  value       = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

# ==============================================================================
# Outputs - M2M (Machine-to-Machine) Authentication
# ==============================================================================

output "cognito_resource_server_cliente_core_identifier" {
  description = "Cliente Core Resource Server identifier"
  value       = aws_cognito_resource_server.cliente_core.identifier
}

output "cognito_resource_server_cliente_core_scopes" {
  description = "Cliente Core Resource Server available scopes"
  value       = [for scope in aws_cognito_resource_server.cliente_core.scope : "${aws_cognito_resource_server.cliente_core.identifier}/${scope.scope_name}"]
}

output "cognito_m2m_venda_core_client_id" {
  description = "Venda Core M2M App Client ID"
  value       = aws_cognito_user_pool_client.venda_core_m2m.id
}

output "cognito_m2m_venda_core_client_secret" {
  description = "Venda Core M2M App Client Secret (sensitive)"
  value       = aws_cognito_user_pool_client.venda_core_m2m.client_secret
  sensitive   = true
}

output "cognito_token_uri" {
  description = "OAuth2 Token endpoint for Client Credentials Flow"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/token"
}

output "secrets_manager_venda_core_m2m_arn" {
  description = "ARN of Secrets Manager secret containing venda-core M2M credentials"
  value       = aws_secretsmanager_secret.venda_core_m2m_credentials.arn
}

output "secrets_manager_venda_core_m2m_name" {
  description = "Name of Secrets Manager secret containing venda-core M2M credentials"
  value       = aws_secretsmanager_secret.venda_core_m2m_credentials.name
}
