# ==============================================================================
# Terraform Remote Backend Configuration
# ==============================================================================
#
# CRITICAL SECURITY: Este arquivo configura o backend remoto S3 para armazenar
# o Terraform state de forma SEGURA e CRIPTOGRAFADA, longe do Git.
#
# Por que S3 backend é obrigatório para produção:
# 1. State local contém CREDENCIAIS EM PLAIN TEXT (client_secret, passwords)
# 2. Git preserva histórico completo - deletar arquivo não remove credenciais
# 3. S3 com criptografia AES256 + versionamento = seguro e auditável
# 4. DynamoDB lock previne race conditions em deploys concorrentes
#
# ==============================================================================

terraform {
  backend "s3" {
    bucket         = "va-nessa-mudanca-terraform-state"
    key            = "shared/terraform.tfstate"
    region         = "sa-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

# ==============================================================================
# Requisitos para este backend funcionar:
# ==============================================================================
#
# 1. Bucket S3 já criado (via AWS CLI):
#    aws s3 mb s3://va-nessa-mudanca-terraform-state --region sa-east-1
#
# 2. Versionamento habilitado:
#    aws s3api put-bucket-versioning \
#      --bucket va-nessa-mudanca-terraform-state \
#      --versioning-configuration Status=Enabled
#
# 3. Criptografia AES256 habilitada:
#    aws s3api put-bucket-encryption \
#      --bucket va-nessa-mudanca-terraform-state \
#      --server-side-encryption-configuration \
#      '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
#
# 4. Tabela DynamoDB criada para lock:
#    aws dynamodb create-table \
#      --table-name terraform-state-lock \
#      --attribute-definitions AttributeName=LockID,AttributeType=S \
#      --key-schema AttributeName=LockID,KeyType=HASH \
#      --billing-mode PAY_PER_REQUEST
#
# ==============================================================================
# Como migrar do state local para remoto:
# ==============================================================================
#
# 1. Criar este arquivo backend.tf
# 2. Executar: terraform init -migrate-state
# 3. Confirmar migração quando perguntado
# 4. Verificar state foi movido: aws s3 ls s3://va-nessa-mudanca-terraform-state/shared/
# 5. DELETAR terraform.tfstate LOCAL permanentemente
# 6. Adicionar *.tfstate ao .gitignore
# 7. Commitar backend.tf ao Git
#
# ==============================================================================
# IMPORTANTE: Após migração, ROTACIONE TODAS AS CREDENCIAIS expostas no Git
# ==============================================================================
