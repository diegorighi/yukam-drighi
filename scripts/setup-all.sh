  #!/bin/bash

  set -e

  GREEN='\033[0;32m'
  BLUE='\033[0;34m'
  NC='\033[0m'

  echo -e "${BLUE}🚀 Setup Completo - Mobilize VaNessa Mudança${NC}"
  echo ""

  # 1. Inicializar submodules
  echo -e "${GREEN}📦 Inicializando submodules...${NC}"
  git submodule update --init --recursive

  # 2. Setup de cada microserviço
  for service in services/*/; do
      if [ -f "$service/validate-dev-environment.sh" ]; then
          echo -e "${GREEN}🔧 Setup: $(basename $service)${NC}"
          cd "$service"
          ./validate-dev-environment.sh
          cd ../..
      fi
  done

  echo ""
  echo -e "${GREEN}✅ Setup completo! Todos os microserviços prontos.${NC}"
