  #!/bin/bash

  set -e

  GREEN='\033[0;32m'
  BLUE='\033[0;34m'
  NC='\033[0m'

  echo -e "${BLUE}🚀 Iniciando Todos os Microserviços${NC}"
  echo ""

  # Iniciar infraestrutura compartilhada
  echo -e "${GREEN}🗄️  Iniciando infraestrutura (PostgreSQL, Kafka, Redis)...${NC}"
  docker-compose up -d

  # Aguardar infraestrutura ficar pronta
  sleep 10

  # Iniciar cada microserviço
  for service in services/*/; do
      service_name=$(basename "$service")
      echo -e "${GREEN}🚀 Iniciando: $service_name${NC}"

      cd "$service"
      if [ -f "pom.xml" ]; then
          mvn spring-boot:run > "/tmp/$service_name.log" 2>&1 &
          echo "$!" > "/tmp/$service_name.pid"
      fi
      cd ../..
  done

  echo ""
  echo -e "${GREEN}✅ Todos os microserviços iniciados!${NC}"
  echo ""
  echo "📊 Status:"
  echo "  - cliente-core:    http://localhost:8081"
  echo "  - vendas-core:     http://localhost:8082"
  echo "  - storage-core:    http://localhost:8083"
  echo ""
  echo "📝 Logs: /tmp/*.log"
  echo "🛑 Parar: ./scripts/stop-all.sh"
