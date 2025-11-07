# 📚 Documentação do Projeto Va Nessa Mudança

**Última atualização:** 2025-11-06

Este diretório contém toda a documentação técnica e operacional do projeto.

---

## 📖 Índice Geral

### 🏗️ Infraestrutura AWS

| Documento | Descrição | Quando Usar |
|-----------|-----------|-------------|
| [**INFRASTRUCTURE_RESTORE.md**](INFRASTRUCTURE_RESTORE.md) | Guia completo para restaurar ALB e arquitetura completa | Quando precisar adicionar ALB de volta (HTTPS, Auto Scaling, produção) |
| [**CREDENTIALS_REMEDIATION_REPORT.md**](../CREDENTIALS_REMEDIATION_REPORT.md) | Relatório de remediação de credenciais expostas | Referência histórica de incidente de segurança (2025-11-06) |

### 🔧 Scripts Operacionais

| Script | Descrição | Quando Usar |
|--------|-----------|-------------|
| [**scripts/toggle-infra.sh**](../scripts/toggle-infra.sh) | Liga/desliga infraestrutura AWS (economia de custos) | Todo dia: `./scripts/toggle-infra.sh off` (fim do dia), `./scripts/toggle-infra.sh on` (início do dia) |
| [**scripts/README.md**](../scripts/README.md) | Documentação completa do toggle-infra.sh | Para entender como economizar ~$60-100/mês |

### 🔐 Segurança e OAuth2

| Documento | Descrição | Status |
|-----------|-----------|--------|
| OAuth2 Configuration | Configuração Cognito M2M (venda-core → cliente-core) | ✅ ATIVO (production profile) |
| Secrets Manager | Credenciais armazenadas em `venda-core/prod/cognito-m2m` | ✅ SEGURO |

### 🎯 Observabilidade

| Documento | Descrição | Quando Usar |
|-----------|-----------|-------------|
| [**OBSERVABILITY_ANALYSIS.md**](OBSERVABILITY_ANALYSIS.md) | Análise completa de observabilidade | Referência para implementar melhorias |
| [**OBSERVABILITY_P0_IMPLEMENTATION.md**](OBSERVABILITY_P0_IMPLEMENTATION.md) | Implementação de melhorias P0 | Guia de implementação |

---

## 🚀 Guias de Início Rápido

### Para Desenvolvedores (LOCAL)

```bash
# 1. Clonar repositório
git clone <repo-url>

# 2. Subir banco local
cd cliente-core
./setup-local.sh

# 3. Rodar aplicação
mvn spring-boot:run

# 4. Acessar
curl http://localhost:8081/api/clientes/actuator/health
```

### Para Testes em AWS (MVP Simplificado - SEM ALB)

```bash
# 1. Ligar infraestrutura
./scripts/toggle-infra.sh on

# 2. Aguardar ~5-7 minutos

# 3. Pegar IP público da task ECS
TASK_IP=$(aws ecs describe-tasks \
  --cluster cliente-core-prod-cluster \
  --tasks $(aws ecs list-tasks --cluster cliente-core-prod-cluster --service-name cliente-core-prod-service --query 'taskArns[0]' --output text) \
  --region sa-east-1 \
  --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' \
  --output text)

# 4. Testar
curl http://$TASK_IP:8081/api/clientes/actuator/health

# 5. Desligar no fim do dia
./scripts/toggle-infra.sh off
```

### Para Produção (COM ALB + HTTPS)

Siga o guia completo: [INFRASTRUCTURE_RESTORE.md](INFRASTRUCTURE_RESTORE.md)

---

## 🏛️ Arquitetura Atual

### MVP Simplificado (Sem ALB)

```
┌─────────────┐
│  Internet   │
└──────┬──────┘
       │
       ↓ (IP público direto)
┌───────────────────────┐
│  ECS Fargate Task     │
│  (Spring Boot 8081)   │
│  IP: 18.231.xxx.xxx   │
└───────────┬───────────┘
            │
            ↓ (conexão privada)
┌───────────────────────┐
│  RDS PostgreSQL       │
│  (db.t3.micro)        │
└───────────────────────┘
```

**Custo:** ~$45/mês

**Limitações:**
- ❌ Sem HTTPS/SSL
- ❌ Sem load balancing
- ❌ IP muda a cada deploy
- ❌ Sem domain customizado

### Arquitetura Completa (Com ALB) - FUTURO

```
┌─────────────┐
│  Internet   │
└──────┬──────┘
       │
       ↓ (HTTP/HTTPS)
┌────────────────────────────────┐
│  Application Load Balancer     │
│  vanessa-mudanca-alb-xxx.elb   │
└────────┬───────────────────────┘
         │
         ↓ (Target Group)
┌─────────────────────────────────┐
│  ECS Fargate Tasks (múltiplas)  │
│  (IPs privados)                 │
└────────┬────────────────────────┘
         │
         ↓
┌────────────────────────────────┐
│  RDS PostgreSQL Multi-AZ       │
└────────────────────────────────┘
```

**Custo:** ~$70-150/mês

**Vantagens:**
- ✅ HTTPS com certificado SSL
- ✅ Load balancing automático
- ✅ DNS estável
- ✅ Health checks
- ✅ Auto Scaling
- ✅ Blue/Green deployments

---

## 📊 Comparação de Custos

| Recurso | MVP (Atual) | Com ALB | Produção Avançada |
|---------|-------------|---------|-------------------|
| ECS Fargate (1-2 tasks) | $30/mês | $30/mês | $60/mês |
| RDS db.t3.micro | $15/mês | $15/mês | - |
| RDS Multi-AZ | - | - | $50/mês |
| ALB | - | $25/mês | $25/mês |
| CloudFront CDN | - | - | $10/mês |
| Route53 | - | - | $1/mês |
| Data Transfer | $1/mês | $3/mês | $10/mês |
| **TOTAL** | **~$46/mês** | **~$73/mês** | **~$156/mês** |

**Economias com toggle-infra.sh:**
- Ligar apenas 8h/dia útil: **~$10/mês** (86% economia)
- Desligar fins de semana: **~$24/mês** economizados

---

## 🔍 Status dos Recursos (2025-11-06)

| Recurso | Status | Comando para Verificar |
|---------|--------|------------------------|
| ECS Service | ❌ OFF (desiredCount=0) | `./scripts/toggle-infra.sh status` |
| RDS PostgreSQL | ❌ STOPPED | `aws rds describe-db-instances --db-instance-identifier cliente-core-prod` |
| ALB | ❌ DELETED | `aws elbv2 describe-load-balancers` |
| OAuth2 Cognito | ✅ CONFIGURADO | Client ID: `5m8d41gbo4r8sehjjbc8hdkppv` |
| Secrets Manager | ✅ ATIVO | `venda-core/prod/cognito-m2m` |
| Terraform State | ✅ S3 REMOTO | `s3://va-nessa-mudanca-terraform-state/shared/` |

---

## 🛠️ Comandos Úteis

### Infraestrutura

```bash
# Ligar tudo
./scripts/toggle-infra.sh on

# Desligar tudo
./scripts/toggle-infra.sh off

# Ver status
./scripts/toggle-infra.sh status
```

### Logs

```bash
# Logs em tempo real
aws logs tail /ecs/cliente-core-prod --follow --region sa-east-1

# Logs com filtro
aws logs tail /ecs/cliente-core-prod --follow --filter-pattern "ERROR" --region sa-east-1
```

### ECS

```bash
# Listar tasks
aws ecs list-tasks --cluster cliente-core-prod-cluster --region sa-east-1

# Descrever task
aws ecs describe-tasks --cluster cliente-core-prod-cluster --tasks <TASK_ARN> --region sa-east-1

# Escalar service
aws ecs update-service --cluster cliente-core-prod-cluster --service cliente-core-prod-service --desired-count 2 --region sa-east-1
```

### RDS

```bash
# Status
aws rds describe-db-instances --db-instance-identifier cliente-core-prod --region sa-east-1

# Parar
aws rds stop-db-instance --db-instance-identifier cliente-core-prod --region sa-east-1

# Iniciar
aws rds start-db-instance --db-instance-identifier cliente-core-prod --region sa-east-1
```

### Terraform

```bash
cd terraform/ecs

# Ver estado atual
terraform show

# Planejar mudanças
terraform plan

# Aplicar mudanças
terraform apply

# Outputs
terraform output
```

---

## 📝 Checklist de Deploys

### Deploy LOCAL → AWS (Primeira Vez)

- [ ] Código testado localmente com `mvn test`
- [ ] Coverage ≥ 80%
- [ ] Build sem erros `mvn clean package`
- [ ] Docker build funcionando
- [ ] Push para ECR
- [ ] Terraform plan revisado
- [ ] Backup do banco de dados (se necessário)
- [ ] Infraestrutura ligada (`./scripts/toggle-infra.sh on`)
- [ ] Deploy testado
- [ ] Health checks passando
- [ ] Rollback plan definido

### Deploy de Hotfix

- [ ] Branch criada a partir de `main`
- [ ] Fix implementado e testado
- [ ] PR revisado
- [ ] Merged to main
- [ ] Tag criada (ex: `v1.0.1-hotfix`)
- [ ] Build automático via CI/CD
- [ ] Deploy em staging
- [ ] Testes de smoke em staging
- [ ] Deploy em produção
- [ ] Monitoramento por 30 minutos

---

## 🚨 Troubleshooting Rápido

| Problema | Solução Rápida |
|----------|----------------|
| Task não inicia | Ver logs: `aws logs tail /ecs/cliente-core-prod` |
| 503 Service Unavailable | Verificar health check: `aws elbv2 describe-target-health` |
| RDS connection refused | Verificar security group e RDS status |
| 401 Unauthorized | Verificar token JWT e profile ativo |
| High latency | Verificar métricas CloudWatch e query performance |

---

## 📞 Contatos

**Responsável Técnico:** Diego Righi
**Repositório:** yukam-drighi (privado)
**Última atualização:** 2025-11-06

---

## 🔗 Links Úteis

- [Terraform Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECS Fargate](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Spring Boot Actuator](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [AWS Cognito OAuth2](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-userpools-server-contract-reference.html)

---

**Dica:** Sempre consulte `INFRASTRUCTURE_RESTORE.md` antes de modificar infraestrutura!
