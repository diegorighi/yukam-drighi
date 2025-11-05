  #!/bin/bash

  set -e

  GREEN='\033[0;32m'
  RED='\033[0;31m'
  NC='\033[0m'

  echo -e "${RED}🛑 Parando Todos os Microserviços${NC}"
  echo ""

  # Parar cada microserviço
  for pid_file in /tmp/*.pid; do
      if [ -f "$pid_file" ]; then
          service_name=$(basename "$pid_file" .pid)
          pid=$(cat "$pid_file")

          if kill -0 "$pid" 2>/dev/null; then
              echo -e "${GREEN}🛑 Parando: $service_name (PID: $pid)${NC}"
              kill "$pid"
          fi

          rm "$pid_file"
      fi
  done

  # Parar infraestrutura
  echo -e "${GREEN}🗄️  Parando infraestrutura...${NC}"
  docker-compose down

  echo ""
  echo -e "${GREEN}✅ Todos os serviços parados!${NC}"
