#!/bin/bash
# ============================================================================
# CI/CD Status Checker
# ============================================================================
# Este script verifica o status da implementação CI/CD
# ============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║         CI/CD Status Check - VaNessa Mudança                       ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# 1. Verificar Pré-requisitos
# ============================================================================
echo "📋 Verificando pré-requisitos..."
echo ""

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✅${NC} $1 instalado: $(command -v $1)"
    else
        echo -e "${RED}❌${NC} $1 NÃO instalado"
        return 1
    fi
}

check_command "aws"
check_command "terraform"
check_command "docker"
check_command "git"
check_command "gh" || echo -e "${YELLOW}⚠️${NC}  GitHub CLI (gh) não instalado (opcional)"

echo ""

# ============================================================================
# 2. Verificar AWS Credentials
# ============================================================================
echo "🔑 Verificando credenciais AWS..."
echo ""

if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    REGION=$(aws configure get region)
    echo -e "${GREEN}✅${NC} AWS Credentials válidas"
    echo "   Account ID: $ACCOUNT_ID"
    echo "   Region: ${REGION:-sa-east-1}"
else
    echo -e "${RED}❌${NC} AWS Credentials inválidas ou não configuradas"
    echo "   Execute: aws configure"
fi

echo ""

# ============================================================================
# 3. Verificar GitHub Workflows
# ============================================================================
echo "📄 Verificando GitHub Workflows..."
echo ""

if [ -f ".github/workflows/ci.yml" ]; then
    echo -e "${GREEN}✅${NC} CI Workflow encontrado: .github/workflows/ci.yml"
else
    echo -e "${RED}❌${NC} CI Workflow NÃO encontrado"
fi

if [ -f ".github/workflows/deploy-production.yml" ]; then
    echo -e "${GREEN}✅${NC} Deploy Workflow encontrado: .github/workflows/deploy-production.yml"
else
    echo -e "${RED}❌${NC} Deploy Workflow NÃO encontrado"
fi

echo ""

# ============================================================================
# 4. Verificar Terraform
# ============================================================================
echo "🏗️  Verificando Terraform..."
echo ""

if [ -f "terraform/ecs/main.tf" ]; then
    echo -e "${GREEN}✅${NC} Terraform module encontrado: terraform/ecs/main.tf"

    if [ -f "terraform/ecs/terraform.tfvars" ]; then
        echo -e "${GREEN}✅${NC} Variáveis configuradas: terraform/ecs/terraform.tfvars"
    else
        echo -e "${YELLOW}⚠️${NC}  terraform.tfvars NÃO configurado"
        echo "   Execute: cd terraform/ecs && cp terraform.tfvars.example terraform.tfvars"
    fi

    # Verificar se Terraform foi inicializado
    if [ -d "terraform/ecs/.terraform" ]; then
        echo -e "${GREEN}✅${NC} Terraform inicializado"
    else
        echo -e "${YELLOW}⚠️${NC}  Terraform NÃO inicializado"
        echo "   Execute: cd terraform/ecs && terraform init"
    fi

    # Verificar state
    if [ -f "terraform/ecs/terraform.tfstate" ]; then
        echo -e "${GREEN}✅${NC} Terraform state encontrado (infraestrutura provisionada)"
    else
        echo -e "${YELLOW}⚠️${NC}  Terraform state NÃO encontrado (infraestrutura não provisionada)"
        echo "   Execute: cd terraform/ecs && terraform apply"
    fi
else
    echo -e "${RED}❌${NC} Terraform module NÃO encontrado"
fi

echo ""

# ============================================================================
# 5. Verificar Infraestrutura AWS (se state existir)
# ============================================================================
if [ -f "terraform/ecs/terraform.tfstate" ]; then
    echo "☁️  Verificando infraestrutura AWS..."
    echo ""

    # ECR
    if aws ecr describe-repositories --repository-names cliente-core --region sa-east-1 &> /dev/null; then
        echo -e "${GREEN}✅${NC} ECR Repository: cliente-core"

        # Verificar se tem imagens
        IMAGE_COUNT=$(aws ecr describe-images --repository-name cliente-core --region sa-east-1 --query 'length(imageDetails)' --output text 2> /dev/null || echo "0")
        if [ "$IMAGE_COUNT" -gt 0 ]; then
            echo "   Imagens: $IMAGE_COUNT"
        else
            echo -e "${YELLOW}   ⚠️  Nenhuma imagem no ECR${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️${NC}  ECR Repository não encontrado"
    fi

    # ECS Cluster
    if aws ecs describe-clusters --clusters vanessa-mudanca-cluster --region sa-east-1 --query 'clusters[0].status' --output text 2> /dev/null | grep -q "ACTIVE"; then
        echo -e "${GREEN}✅${NC} ECS Cluster: vanessa-mudanca-cluster"

        # Verificar service
        if aws ecs describe-services --cluster vanessa-mudanca-cluster --services cliente-core-service --region sa-east-1 &> /dev/null; then
            echo -e "${GREEN}✅${NC} ECS Service: cliente-core-service"

            # Ver running tasks
            RUNNING_TASKS=$(aws ecs describe-services --cluster vanessa-mudanca-cluster --services cliente-core-service --region sa-east-1 --query 'services[0].runningCount' --output text)
            DESIRED_TASKS=$(aws ecs describe-services --cluster vanessa-mudanca-cluster --services cliente-core-service --region sa-east-1 --query 'services[0].desiredCount' --output text)

            if [ "$RUNNING_TASKS" -eq "$DESIRED_TASKS" ]; then
                echo -e "${GREEN}   ✅ Tasks: $RUNNING_TASKS/$DESIRED_TASKS (healthy)${NC}"
            else
                echo -e "${YELLOW}   ⚠️  Tasks: $RUNNING_TASKS/$DESIRED_TASKS (não healthy)${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️${NC}  ECS Service não encontrado"
        fi
    else
        echo -e "${YELLOW}⚠️${NC}  ECS Cluster não encontrado"
    fi

    # ALB
    ALB_ARN=$(aws elbv2 describe-load-balancers --names vanessa-mudanca-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text --region sa-east-1 2> /dev/null || echo "")
    if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
        ALB_DNS=$(aws elbv2 describe-load-balancers --names vanessa-mudanca-alb --query 'LoadBalancers[0].DNSName' --output text --region sa-east-1)
        echo -e "${GREEN}✅${NC} Application Load Balancer"
        echo "   DNS: http://$ALB_DNS"
        echo "   Health Check: http://$ALB_DNS/api/clientes/actuator/health"
    else
        echo -e "${YELLOW}⚠️${NC}  Application Load Balancer não encontrado"
    fi

    echo ""
fi

# ============================================================================
# 6. Resumo e Próximos Passos
# ============================================================================
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                         RESUMO                                     ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

if [ -f "terraform/ecs/terraform.tfstate" ] && [ -n "$ALB_DNS" ]; then
    echo -e "${GREEN}✅ CI/CD IMPLEMENTADO E FUNCIONANDO!${NC}"
    echo ""
    echo "🎉 Próximos passos:"
    echo "   1. Testar CI: Criar PR e ver workflow rodar"
    echo "   2. Testar CD: Fazer merge e ver deploy automático"
    echo "   3. Acessar aplicação: http://$ALB_DNS/api/clientes/actuator/health"
else
    echo -e "${YELLOW}⚠️  CI/CD PARCIALMENTE IMPLEMENTADO${NC}"
    echo ""
    echo "📋 Próximos passos:"

    if [ ! -f "terraform/ecs/terraform.tfvars" ]; then
        echo "   1. Configurar Terraform:"
        echo "      cd terraform/ecs"
        echo "      cp terraform.tfvars.example terraform.tfvars"
        echo "      vim terraform.tfvars  # Preencher valores"
    fi

    if [ ! -f "terraform/ecs/terraform.tfstate" ]; then
        echo "   2. Provisionar infraestrutura:"
        echo "      cd terraform/ecs"
        echo "      terraform init"
        echo "      terraform apply"
    fi

    echo "   3. Seguir guia: GETTING_STARTED_CICD.md"
fi

echo ""
echo "📚 Documentação:"
echo "   - Quick Start: GETTING_STARTED_CICD.md"
echo "   - Checklist: CICD_QUICKSTART.md"
echo "   - Completo: docs/CI_CD_IMPLEMENTATION_GUIDE.md"
echo ""
