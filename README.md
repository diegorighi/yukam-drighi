# 🏗️ Yukam Drighi - Monorepo VaNessa Mudança

Monorepo contendo todos os microserviços e infraestrutura compartilhada do ecossistema **VaNessa Mudança**.

---

## ⚠️ FILOSOFIA: Microserviços INDEPENDENTES

Este monorepo segue a filosofia **"desenvolvimento isolado por padrão, integração quando necessário"**.

### 95% do Tempo: Trabalhando em 1 Microserviço

**Você trabalha DENTRO do microserviço:**

```bash
# 1. Entre no microserviço
cd services/cliente-core

# 2. Valide o ambiente
./validate-dev-environment.sh

# 3. Desenvolva normalmente
```

**Por quê?**
- ✅ **Rápido:** Setup em 3 minutos
- ✅ **Focado:** Trabalhe em 1 MS sem distrações
- ✅ **Leve:** Apenas 1 PostgreSQL rodando
- ✅ **Independente:** MS pode ser clonado separadamente

### 5% do Tempo: Testando Integrações

```bash
# Raiz do monorepo
docker-compose up -d kafka

# Inicie MSs manualmente
cd services/cliente-core && mvn spring-boot:run &
cd services/vendas-core && mvn spring-boot:run &
```

---

## 📦 Microserviços

| Microserviço | Porta | Database | Status | Descrição |
|-------------|-------|----------|--------|-----------|
| **[cliente-core](services/cliente-core/)** | 8081 | PostgreSQL:5432 | ✅ Ativo | Gestão de clientes (PF/PJ) |
| **vendas-core** | 8082 | PostgreSQL:5433 | 🚧 Planejado | Gestão de vendas e propostas |
| **storage-core** | 8083 | PostgreSQL:5434 | 🚧 Planejado | Gestão de estoque |

---

## 🚀 Quick Start

```bash
# 1. Clonar com submodules
git clone --recurse-submodules https://github.com/diegorighi/yukam-drighi.git
cd yukam-drighi

# 2. Escolha seu microserviço
cd services/cliente-core

# 3. Execute o wizard
./validate-dev-environment.sh
```

---

## 🏗️ Estrutura

```
yukam-drighi/
├── README.md                          # Este arquivo
├── docker-compose.yml                 # Infra compartilhada OPCIONAL
├── services/                          # Git Submodules
│   └── cliente-core/
│       ├── validate-dev-environment.sh # Wizard do MS
│       └── docker-compose.yml          # APENAS PostgreSQL do MS
├── docs/                              # Documentação centralizada
├── infrastructure/                    # Terraform + K8s
└── shared/                            # Prometheus + Grafana configs
```

---

## 📚 Documentação

- [Getting Started](docs/development/GETTING_STARTED.md)
- [Monorepo Workflow](docs/development/MONOREPO_WORKFLOW.md)
- [Integration Map](docs/architecture/INTEGRATION_MAP.md)

---

## 🚫 O Que NÃO Fazer

❌ **NUNCA use `docker-compose up` na raiz para desenvolvimento diário**
❌ **NUNCA coloque PostgreSQL no docker-compose.yml da raiz**
❌ **NUNCA rode wizard da raiz** - Use o wizard do MS

---

**Última atualização:** 2025-11-05
**Versão:** 1.0.0 (Monorepo Minimalista)