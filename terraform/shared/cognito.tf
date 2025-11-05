# ==============================================================================
# AWS Cognito User Pool - Shared Authentication
# ==============================================================================

resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-users-${var.environment}"

  # Username configuration
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Schema attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 5
      max_length = 255
    }
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 255
    }
  }

  # Custom attribute: role
  schema {
    name                     = "role"
    attribute_data_type      = "String"
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  # Tags
  tags = {
    Name = "${var.project_name}-user-pool-${var.environment}"
  }
}

# ==============================================================================
# Cognito User Pool Groups (Roles)
# ==============================================================================

resource "aws_cognito_user_group" "admin" {
  name         = "ADMIN"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Administradores do sistema - Full access"
  precedence   = 1
}

resource "aws_cognito_user_group" "employee" {
  name         = "EMPLOYEE"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Funcionários - CRUD clientes"
  precedence   = 5
}

resource "aws_cognito_user_group" "customer" {
  name         = "CUSTOMER"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Clientes - Ver apenas próprio cadastro"
  precedence   = 10
}

# ==============================================================================
# Cognito User Pool Client (Application)
# ==============================================================================

resource "aws_cognito_user_pool_client" "web_client" {
  name         = "${var.project_name}-web-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Token validity
  access_token_validity  = 60   # 1 hour
  id_token_validity      = 60   # 1 hour
  refresh_token_validity = 30   # 30 days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Auth flows
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # Read/Write attributes
  read_attributes = [
    "email",
    "email_verified",
    "name",
    "custom:role"
  ]

  write_attributes = [
    "email",
    "name",
    "custom:role"
  ]
}

# ==============================================================================
# Cognito User Pool Domain (for Hosted UI - optional)
# ==============================================================================

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-auth-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id
}
