# Terraform - ECS Infrastructure

Este módulo Terraform provisiona toda a infraestrutura ECS necessária para os microserviços.

---

## 📦 O Que Este Módulo Cria

- ✅ **ECR Repositories** (cliente-core, vendas-core)
- ✅ **ECS Fargate Cluster** com Container Insights
- ✅ **Application Load Balancer** com Target Groups
- ✅ **Security Groups** (ALB, ECS Tasks)
- ✅ **IAM Roles** (Task Execution Role, Task Role)
- ✅ **CloudWatch Log Groups** (30 dias retention)
- ✅ **ECS Services** com health checks
- ✅ **Auto Scaling** (CPU e Memory based)

---

## 🚀 Quick Start

### Pré-requisitos

1. **Terraform instalado** (>= 1.0)
   ```bash
   brew install terraform  # macOS
   # ou
   sudo apt install terraform  # Linux
   ```

2. **AWS CLI configurado**
   ```bash
   aws configure
   # Fornecer: AWS Access Key ID, Secret Access Key, Region (sa-east-1)
   ```

3. **VPC já criada** (ou usar VPC default)
   ```bash
   # Listar VPCs
   aws ec2 describe-vpcs --region sa-east-1

   # Criar VPC (se necessário)
   # Use o módulo terraform/networking ou crie manualmente
   ```

### Passo 1: Configurar Variáveis

```bash
# Copiar exemplo
cp terraform.tfvars.example terraform.tfvars

# Editar com seus valores
vim terraform.tfvars
```

**Obter valores necessários:**

```bash
# VPC ID
aws ec2 describe-vpcs --region sa-east-1 \
  --query 'Vpcs[0].VpcId' --output text

# Subnet IDs (private)
aws ec2 describe-subnets --region sa-east-1 \
  --filters "Name=tag:Name,Values=*private*" \
  --query 'Subnets[*].SubnetId' --output text

# Subnet IDs (public)
aws ec2 describe-subnets --region sa-east-1 \
  --filters "Name=tag:Name,Values=*public*" \
  --query 'Subnets[*].SubnetId' --output text

# RDS Endpoint
aws rds describe-db-instances --region sa-east-1 \
  --query 'DBInstances[0].Endpoint.Address' --output text
```

### Passo 2: Criar Secret no Secrets Manager

```bash
# Criar secret para senha do RDS
aws secretsmanager create-secret \
  --name vanessa/db-password \
  --description "Database password for VaNessa Mudança" \
  --secret-string "YOUR_STRONG_PASSWORD_HERE" \
  --region sa-east-1

# Obter ARN do secret
aws secretsmanager describe-secret \
  --secret-id vanessa/db-password \
  --region sa-east-1 \
  --query 'ARN' --output text
```

### Passo 3: Inicializar Terraform

```bash
cd terraform/ecs

# Inicializar
terraform init

# Validar configuração
terraform validate

# Ver plano de execução
terraform plan
```

### Passo 4: Aplicar Mudanças

```bash
# Aplicar (criar recursos)
terraform apply

# Confirmar com 'yes'
```

**Tempo estimado:** 5-10 minutos

---

## 📊 Outputs

Após `terraform apply`, você verá:

```
Outputs:

alb_dns_name = "vanessa-mudanca-alb-1234567890.sa-east-1.elb.amazonaws.com"
cliente_core_service_name = "cliente-core-service"
ecr_repository_url_cliente_core = "123456789012.dkr.ecr.sa-east-1.amazonaws.com/cliente-core"
ecr_repository_url_vendas_core = "123456789012.dkr.ecr.sa-east-1.amazonaws.com/vendas-core"
ecs_cluster_name = "vanessa-mudanca-cluster"
```

**Testar ALB:**

```bash
# Obter DNS do ALB
ALB_DNS=$(terraform output -raw alb_dns_name)

# Testar (aguarde 2-3 minutos após deploy)
curl http://$ALB_DNS/api/clientes/actuator/health
```

---

## 🔧 Customizações

### Alterar Quantidade de Tasks

Edite `main.tf`:

```hcl
resource "aws_ecs_service" "cliente_core" {
  # ...
  desired_count = 4  # Altere aqui (padrão: 2)
}
```

Aplique:

```bash
terraform apply
```

---

### Alterar Limites de Auto Scaling

Edite `main.tf`:

```hcl
resource "aws_appautoscaling_target" "cliente_core" {
  max_capacity = 20  # Altere aqui (padrão: 10)
  min_capacity = 4   # Altere aqui (padrão: 2)
  # ...
}
```

---

### Alterar CPU/Memory

Edite `main.tf`:

```hcl
resource "aws_ecs_task_definition" "cliente_core" {
  cpu    = "1024"  # Altere aqui (padrão: 512)
  memory = "2048"  # Altere aqui (padrão: 1024)
  # ...
}
```

---

## 🔍 Monitoramento

### Ver Tasks Rodando

```bash
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)

aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --region sa-east-1
```

### Ver Logs

```bash
# Tail logs em tempo real
aws logs tail /ecs/cliente-core --follow --region sa-east-1

# Filtrar erros
aws logs tail /ecs/cliente-core --follow \
  --filter-pattern "ERROR" \
  --region sa-east-1
```

### Ver Target Health

```bash
# Listar Target Groups
aws elbv2 describe-target-groups \
  --region sa-east-1

# Ver health de targets específicos
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:... \
  --region sa-east-1
```

---

## 🧹 Limpeza

Para deletar TODOS os recursos criados:

```bash
# ATENÇÃO: Isso vai deletar tudo!
terraform destroy

# Confirmar com 'yes'
```

**Recursos que NÃO serão deletados:**
- VPC (criada separadamente)
- Subnets
- RDS Database
- Secrets Manager secrets

---

## 📚 Estrutura de Arquivos

```
terraform/ecs/
├── main.tf                      # Configuração principal
├── terraform.tfvars.example     # Exemplo de variáveis
├── terraform.tfvars             # Suas variáveis (git ignored)
├── .terraform/                  # Providers (auto-gerado)
├── terraform.tfstate            # State file (local)
└── README.md                    # Este arquivo
```

---

## 🔐 State Management

### Local State (Atual)

O state está armazenado localmente em `terraform.tfstate`.

**⚠️ CUIDADO:**
- Não commitar `terraform.tfstate` no git (já está em `.gitignore`)
- Fazer backup manual do state file

### Remote State (Recomendado para Produção)

Configure S3 backend para state remoto e compartilhado:

```hcl
# Uncomment no main.tf:
backend "s3" {
  bucket = "vanessa-mudanca-terraform-state"
  key    = "ecs/terraform.tfstate"
  region = "sa-east-1"

  # Opcional: DynamoDB para state locking
  dynamodb_table = "terraform-state-lock"
  encrypt        = true
}
```

Criar bucket S3:

```bash
aws s3api create-bucket \
  --bucket vanessa-mudanca-terraform-state \
  --region sa-east-1 \
  --create-bucket-configuration LocationConstraint=sa-east-1

# Habilitar versionamento
aws s3api put-bucket-versioning \
  --bucket vanessa-mudanca-terraform-state \
  --versioning-configuration Status=Enabled
```

---

## 🛠️ Troubleshooting

### Erro: "Error creating ECS Service: InvalidParameterException"

**Causa:** Subnets não têm acesso à internet (falta NAT Gateway)

**Solução:**
1. Criar NAT Gateway nas subnets públicas
2. Atualizar route tables das subnets privadas para usar NAT Gateway

---

### Erro: "Error creating Load Balancer: SubnetNotFound"

**Causa:** Subnet IDs inválidos no `terraform.tfvars`

**Solução:**
```bash
# Verificar subnets existentes
aws ec2 describe-subnets --region sa-east-1
```

---

### Erro: "UnauthorizedOperation: You are not authorized to perform this operation"

**Causa:** IAM user não tem permissões suficientes

**Solução:** Adicionar policy ao usuário IAM (ver `.github/SECRETS_SETUP.md`)

---

### Tasks ficam em "PENDING" state

**Causa:** Falta permissões IAM ou problema de rede

**Debug:**
```bash
# Ver eventos do serviço
aws ecs describe-services \
  --cluster vanessa-mudanca-cluster \
  --services cliente-core-service \
  --region sa-east-1 \
  --query 'services[0].events[0:5]'
```

---

## 📚 Referências

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [ECS Task Definitions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html)
- [ECS Services](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html)
- [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)

---

**Última atualização:** 2025-11-05
**Versão:** 1.0.0
