# 🏗️ Terraform Infrastructure - Va Nessa Mudança

## 📁 Estrutura de Diretórios

```
terraform/
├── shared/                    # Infraestrutura compartilhada entre TODOS os MS
│   ├── cognito.tf             # ✅ Cognito User Pool + M2M Auth
│   ├── vpc.tf                 # ⏳ VPC + Subnets + NAT (TODO)
│   ├── alb.tf                 # ⏳ ALB compartilhado (TODO)
│   ├── iam.tf                 # ⏳ IAM Roles base (TODO)
│   └── outputs.tf             # Outputs para uso pelos MS
│
├── ecs/                       # ⚠️ DEPRECATED - Será migrado para services/cliente-core/
│   └── main.tf                # Contém TUDO do cliente-core (monolítico)
│
└── services/                  # ⏳ TODO - Infraestrutura por MS (separada)
    └── cliente-core/          # Recursos específicos do cliente-core
```

---

## 🎯 Estado Atual vs Estado Desejado

### ✅ Estado Atual (Funcional)

```
terraform/
├── shared/
│   └── cognito.tf             # ✅ Apenas Cognito
│
└── ecs/
    └── main.tf                # ✅ TODO cliente-core (ALB, ECS, RDS, IAM)
```

**Problema:**
- `terraform/ecs/` contém recursos compartilhados (ALB, VPC refs) misturados com recursos do cliente-core
- Dificulta governança quando tivermos múltiplos squads
- State management complexo (tudo em um único state)

---

### 🎯 Estado Desejado (Arquitetura Alvo)

```
terraform/
├── shared/                    # Gerenciado por DevOps
│   ├── vpc.tf                 # VPC compartilhada
│   ├── alb.tf                 # ALB único para todos MS
│   ├── iam.tf                 # Roles base (ecsTaskExecutionRole)
│   ├── cognito.tf             # Auth compartilhado
│   └── outputs.tf             # Exporta IDs para uso pelos MS
│
└── services/                  # Gerenciado por Squads
    ├── cliente-core/
    │   ├── ecs.tf             # Task + Service + Auto Scaling
    │   ├── rds.tf             # PostgreSQL do cliente-core
    │   ├── target_group.tf    # TG + Listener Rules
    │   └── iam_task_role.tf   # Permissões específicas
    │
    └── venda-core/            # Futuro MS
        └── ...
```

**Benefícios:**
- Squads têm autonomia nos seus MS
- Mudanças em shared requerem aprovação rigorosa
- State isolado por contexto (blast radius menor)
- Reutilização de recursos compartilhados

---

## 📝 Plano de Migração

**Status:** 📝 Planejamento

Ver detalhes completos em: [`REFACTORING_PLAN.md`](./REFACTORING_PLAN.md)

**Fases:**
1. ✅ Inventário de recursos AWS existentes
2. ⏳ Criar `terraform/shared/` com recursos compartilhados
3. ⏳ Importar recursos existentes para `shared/`
4. ⏳ Criar `terraform/services/cliente-core/`
5. ⏳ Importar recursos existentes para `services/cliente-core/`
6. ⏳ Validar e testar
7. ⏳ Deprecar `terraform/ecs/`

---

## 🚀 Como Usar (Estado Atual)

### Infraestrutura Compartilhada (Cognito)

```bash
cd terraform/shared
terraform init
terraform plan
terraform apply
```

### Cliente-Core (Tudo junto - monolítico)

```bash
cd terraform/ecs
terraform init
terraform plan
terraform apply
```

---

## 🚀 Como Usar (Após Migração)

### Infraestrutura Compartilhada

```bash
cd terraform/shared
terraform init
terraform plan
terraform apply  # Requer aprovação rigorosa
```

### Microserviço Cliente-Core

```bash
cd terraform/services/cliente-core
terraform init
terraform plan
terraform apply  # Self-service para squad
```

---

## 🔐 Remote State (TODO)

**Bucket S3:** `va-nessa-mudanca-terraform-state`
**DynamoDB Lock:** `terraform-state-lock`

### Shared State

```hcl
terraform {
  backend "s3" {
    bucket         = "va-nessa-mudanca-terraform-state"
    key            = "shared/terraform.tfstate"
    region         = "sa-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### Cliente-Core State

```hcl
terraform {
  backend "s3" {
    bucket         = "va-nessa-mudanca-terraform-state"
    key            = "services/cliente-core/terraform.tfstate"
    region         = "sa-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

---

## 📚 Documentação

- **Plano de Refatoração:** [REFACTORING_PLAN.md](./REFACTORING_PLAN.md)
- **Documentação Cliente-Core ECS:** [ecs/README.md](./ecs/README.md)
- **Documentação Shared:** [shared/README.md](./shared/README.md) (TODO)

---

## 👥 Governança (Futuro)

| Diretório | Responsável | Aprovação | Deploy |
|-----------|-------------|-----------|--------|
| `shared/` | Time DevOps | 2+ aprovações | Manual |
| `services/cliente-core/` | Squad Cliente | 1 aprovação | CI/CD automático |
| `services/venda-core/` | Squad Vendas | 1 aprovação | CI/CD automático |

**Nota:** Por enquanto, Diego Righi (admin) tem acesso total a tudo.

---

**Última atualização:** 2025-11-06
**Responsável:** Diego Righi
**Status:** 📝 Em planejamento
