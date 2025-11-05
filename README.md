# 🚚 Yukam DRighi - Plataforma VaNessa Mudança

  Monorepo contendo todos os microserviços da plataforma VaNessa Mudança.

  ## 📦 Microserviços

  - **cliente-core** - Gestão de clientes (PF/PJ)
  - **vendas-core** - Gestão de vendas e propostas
  - **storage-core** - Gestão de estoque e armazenagem
  - **financeiro-core** - Pagamentos e garantias
  - **logistica-core** - Coletas, entregas e tracking
  - **produto-core** - Catálogo e avaliação técnica

  ## 🏗️ Arquitetura

  Ver [docs/architecture/SYSTEM_ARCHITECTURE.md](docs/architecture/SYSTEM_ARCHITECTURE.md)

  ## 🚀 Quick Start

  ```bash
  # Setup completo (todos os microserviços)
  ./scripts/setup-all.sh

  # Iniciar todos os serviços
  ./scripts/start-all.sh

  # Parar todos os serviços
  ./scripts/stop-all.sh

  📚 Documentação

  - docs/development/GETTING_STARTED.md
  - docs/development/LOCAL_DEVELOPMENT.md
  - docs/api/API_CONTRACTS.md
  - docs/architecture/DEPLOYMENT.md

  🔧 Estrutura

  yukam-drighi-vn-mudanca/
  ├── services/          # Microserviços (Git Submodules)
  ├── infrastructure/    # IaC (Terraform, K8s)
  ├── shared/           # Bibliotecas compartilhadas
  ├── scripts/          # Automação
  └── docs/             # Documentação

  📋 Convenções

  - Java 21 + Spring Boot 3.5+
  - PostgreSQL 16 (1 DB por microserviço)
  - Kafka para eventos assíncronos
  - Redis para cache distribuído
  - Docker + Kubernetes para deploy

  🤝 Contributing

  Ver CONTRIBUTING.md

  ---
  Última atualização: 2025-11-05
  Versão: 1.0.0