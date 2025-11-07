#!/bin/bash

# ============================================================================
# AWS Infrastructure Toggle Script (ON/OFF)
# ============================================================================
# Gerencia TODA a infraestrutura AWS para economizar custos durante desenvolvimento
#
# Uso:
#   ./toggle-infra.sh off    # Desliga TUDO (economia máxima)
#   ./toggle-infra.sh on     # Liga TUDO (produção ready)
#   ./toggle-infra.sh status # Mostra status atual
#
# Recursos gerenciados:
#   1. ECS Fargate Tasks (cliente-core-prod-service)
#   2. Application Load Balancer (vanessa-mudanca-alb)
#   3. RDS PostgreSQL (cliente-core-prod)
#   4. NAT Gateway (se existir)
#
# Economia esperada (OFF): ~$60-100/mês → ~$0/mês (apenas storage)
# ============================================================================

set -euo pipefail

# Configurações
AWS_REGION="sa-east-1"
ECS_CLUSTER="cliente-core-prod-cluster"
ECS_SERVICE="cliente-core-prod-service"
RDS_INSTANCE="cliente-core-prod"
ALB_NAME="vanessa-mudanca-alb"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Funções Auxiliares
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================================================
# Status Functions
# ============================================================================

check_ecs_status() {
    log_info "Verificando ECS Service..."

    local service_info=$(aws ecs describe-services \
        --cluster "$ECS_CLUSTER" \
        --services "$ECS_SERVICE" \
        --region "$AWS_REGION" \
        --query 'services[0].{desiredCount:desiredCount,runningCount:runningCount,status:status}' \
        --output json 2>/dev/null || echo "{}")

    local desired=$(echo "$service_info" | jq -r '.desiredCount // 0')
    local running=$(echo "$service_info" | jq -r '.runningCount // 0')

    if [ "$desired" -eq 0 ]; then
        log_warning "ECS Service: OFF (desiredCount=0)"
        return 1
    else
        log_success "ECS Service: ON (desiredCount=$desired, runningCount=$running)"
        return 0
    fi
}

check_alb_status() {
    log_info "Verificando Application Load Balancer..."

    local alb_arn=$(aws elbv2 describe-load-balancers \
        --region "$AWS_REGION" \
        --query "LoadBalancers[?LoadBalancerName=='$ALB_NAME'].LoadBalancerArn" \
        --output text 2>/dev/null || echo "")

    if [ -z "$alb_arn" ]; then
        log_warning "ALB: OFF (deletado)"
        return 1
    else
        log_success "ALB: ON ($ALB_NAME)"
        return 0
    fi
}

check_rds_status() {
    log_info "Verificando RDS Instance..."

    local rds_status=$(aws rds describe-db-instances \
        --db-instance-identifier "$RDS_INSTANCE" \
        --region "$AWS_REGION" \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text 2>/dev/null || echo "not-found")

    case "$rds_status" in
        "available")
            log_success "RDS: ON (available)"
            return 0
            ;;
        "stopped")
            log_warning "RDS: OFF (stopped)"
            return 1
            ;;
        "stopping"|"starting")
            log_warning "RDS: TRANSITIONING ($rds_status)"
            return 2
            ;;
        "not-found")
            log_warning "RDS: NOT FOUND"
            return 1
            ;;
        *)
            log_warning "RDS: $rds_status"
            return 1
            ;;
    esac
}

show_status() {
    separator
    echo -e "${BLUE}📊 STATUS DA INFRAESTRUTURA AWS${NC}"
    separator

    check_ecs_status
    ecs_status=$?

    check_alb_status
    alb_status=$?

    check_rds_status
    rds_status=$?

    separator

    # Calcular custo estimado
    local cost=0

    if [ $ecs_status -eq 0 ]; then
        cost=$((cost + 30))
    fi

    if [ $alb_status -eq 0 ]; then
        cost=$((cost + 25))
    fi

    if [ $rds_status -eq 0 ]; then
        cost=$((cost + 15))
    fi

    if [ $cost -gt 0 ]; then
        log_info "💰 Custo Estimado: ~\$${cost}/mês (+ storage e data transfer)"
    else
        log_success "💰 Custo Estimado: ~\$0/mês (apenas storage)"
    fi

    separator
}

# ============================================================================
# Shutdown Functions
# ============================================================================

shutdown_ecs() {
    log_info "Desligando ECS Service (desiredCount=0)..."

    aws ecs update-service \
        --cluster "$ECS_CLUSTER" \
        --service "$ECS_SERVICE" \
        --desired-count 0 \
        --region "$AWS_REGION" \
        --query 'service.{serviceName:serviceName,desiredCount:desiredCount}' \
        --output table > /dev/null

    # Aguardar tasks pararem
    log_info "Aguardando tasks pararem..."
    sleep 10

    local task_count=$(aws ecs list-tasks \
        --cluster "$ECS_CLUSTER" \
        --service-name "$ECS_SERVICE" \
        --region "$AWS_REGION" \
        --query 'length(taskArns)' \
        --output text)

    if [ "$task_count" -eq 0 ]; then
        log_success "ECS Service desligado (0 tasks rodando)"
    else
        log_warning "Ainda existem $task_count tasks (aguarde alguns segundos)"
    fi
}

shutdown_alb() {
    log_info "Verificando se ALB existe..."

    local alb_arn=$(aws elbv2 describe-load-balancers \
        --region "$AWS_REGION" \
        --query "LoadBalancers[?LoadBalancerName=='$ALB_NAME'].LoadBalancerArn" \
        --output text 2>/dev/null || echo "")

    if [ -z "$alb_arn" ]; then
        log_warning "ALB já estava desligado"
        return 0
    fi

    log_info "Deletando ALB..."

    aws elbv2 delete-load-balancer \
        --load-balancer-arn "$alb_arn" \
        --region "$AWS_REGION"

    log_success "ALB deletado (economia: ~\$25/mês)"
}

shutdown_rds() {
    log_info "Parando RDS Instance..."

    local rds_status=$(aws rds describe-db-instances \
        --db-instance-identifier "$RDS_INSTANCE" \
        --region "$AWS_REGION" \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text 2>/dev/null || echo "not-found")

    if [ "$rds_status" == "stopped" ]; then
        log_warning "RDS já estava parado"
        return 0
    fi

    if [ "$rds_status" == "not-found" ]; then
        log_warning "RDS não encontrado"
        return 1
    fi

    aws rds stop-db-instance \
        --db-instance-identifier "$RDS_INSTANCE" \
        --region "$AWS_REGION" \
        --output table > /dev/null

    log_success "RDS parando... (economia: ~\$15/mês)"
    log_info "⏳ RDS levará ~2 minutos para parar completamente"
}

shutdown_all() {
    separator
    echo -e "${RED}🛑 DESLIGANDO TODA A INFRAESTRUTURA AWS${NC}"
    separator

    shutdown_ecs
    echo

    shutdown_alb
    echo

    shutdown_rds
    echo

    separator
    log_success "💰 Economia estimada: ~\$60-100/mês"
    log_info "ℹ️  Para religar: ./toggle-infra.sh on"
    separator
}

# ============================================================================
# Startup Functions
# ============================================================================

startup_ecs() {
    log_info "Ligando ECS Service (desiredCount=1)..."

    aws ecs update-service \
        --cluster "$ECS_CLUSTER" \
        --service "$ECS_SERVICE" \
        --desired-count 1 \
        --region "$AWS_REGION" \
        --query 'service.{serviceName:serviceName,desiredCount:desiredCount}' \
        --output table > /dev/null

    log_success "ECS Service ligado (aguarde ~2 minutos para task iniciar)"
}

startup_alb() {
    log_warning "ALB não pode ser religado automaticamente"
    log_info "📝 Para recriar o ALB, execute: terraform apply no diretório terraform/ecs/"
}

startup_rds() {
    log_info "Iniciando RDS Instance..."

    local rds_status=$(aws rds describe-db-instances \
        --db-instance-identifier "$RDS_INSTANCE" \
        --region "$AWS_REGION" \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text 2>/dev/null || echo "not-found")

    if [ "$rds_status" == "available" ]; then
        log_warning "RDS já estava rodando"
        return 0
    fi

    if [ "$rds_status" == "not-found" ]; then
        log_warning "RDS não encontrado"
        return 1
    fi

    aws rds start-db-instance \
        --db-instance-identifier "$RDS_INSTANCE" \
        --region "$AWS_REGION" \
        --output table > /dev/null

    log_success "RDS iniciando... (aguarde ~5 minutos)"
    log_info "⏳ Você pode monitorar com: aws rds describe-db-instances --db-instance-identifier $RDS_INSTANCE --region $AWS_REGION"
}

startup_all() {
    separator
    echo -e "${GREEN}▶️  LIGANDO TODA A INFRAESTRUTURA AWS${NC}"
    separator

    startup_rds
    echo

    log_info "⏳ Aguardando 30 segundos antes de ligar ECS (esperar RDS iniciar)..."
    sleep 30

    startup_ecs
    echo

    startup_alb
    echo

    separator
    log_info "⏳ Tempo total estimado: ~5-7 minutos"
    log_info "📊 Monitore status: ./toggle-infra.sh status"
    separator
}

# ============================================================================
# Main
# ============================================================================

main() {
    local command="${1:-}"

    case "$command" in
        "off"|"shutdown"|"down")
            shutdown_all
            ;;
        "on"|"startup"|"up")
            startup_all
            ;;
        "status"|"")
            show_status
            ;;
        *)
            echo "Uso: $0 {on|off|status}"
            echo ""
            echo "Comandos:"
            echo "  on      Liga toda a infraestrutura (ECS + RDS)"
            echo "  off     Desliga toda a infraestrutura (economia máxima)"
            echo "  status  Mostra status atual e custo estimado"
            echo ""
            echo "Exemplos:"
            echo "  $0 off     # Desliga tudo (fim do dia de trabalho)"
            echo "  $0 on      # Liga tudo (início do dia)"
            echo "  $0 status  # Verifica o que está rodando"
            exit 1
            ;;
    esac
}

# Executar
main "$@"
