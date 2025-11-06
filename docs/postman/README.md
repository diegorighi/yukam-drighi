# Postman Collection - Cliente Core API

Esta pasta contém a Collection e Environments do Postman prontos para testar o `cliente-core` com autenticação OAuth2.

---

## 📦 Arquivos Incluídos

- **`Cliente_Core_API.postman_collection.json`** - Collection completa com todos os endpoints
- **`Development.postman_environment.json`** - Environment para ambiente local
- **`Production.postman_environment.json`** - Environment para produção (AWS)

---

## 🚀 Como Importar no Postman

### Passo 1: Importar a Collection

1. Abra o Postman
2. Clique em **Import** (canto superior esquerdo)
3. Selecione o arquivo `Cliente_Core_API.postman_collection.json`
4. Clique em **Import**

### Passo 2: Importar os Environments

1. Clique em **Import** novamente
2. Selecione os arquivos:
   - `Development.postman_environment.json`
   - `Production.postman_environment.json`
3. Clique em **Import**

### Passo 3: Configurar o Environment

1. Clique no dropdown de **Environments** (canto superior direito)
2. Selecione **Development (Local)** ou **Production (AWS)**
3. Clique no ícone de **olho** (👁️) para ver as variáveis
4. Clique em **Edit** (ícone de lápis)

5. **Preencha as variáveis:**

   **Para Development:**
   ```
   base_url: http://localhost:8081/api/clientes (já preenchido)
   cognito_domain: your-cognito-domain.auth.sa-east-1.amazoncognito.com
   client_id: SEU_CLIENT_ID_AQUI
   client_secret: SEU_CLIENT_SECRET_AQUI
   ```

   **Para Production:**
   ```
   base_url: https://your-alb.sa-east-1.elb.amazonaws.com/api/clientes
   cognito_domain: your-cognito-domain.auth.sa-east-1.amazoncognito.com
   client_id: SEU_CLIENT_ID_PROD_AQUI
   client_secret: SEU_CLIENT_SECRET_PROD_AQUI
   ```

6. Clique em **Save**

---

## 🔐 Passo 4: Configurar OAuth2

A Collection já vem configurada com OAuth2, mas você precisa obter o primeiro token:

1. Clique na Collection **Cliente Core API - OAuth2**
2. Vá na aba **Authorization**
3. Verifique se as configurações estão corretas:
   - Type: `OAuth 2.0`
   - Grant Type: `Client Credentials`
   - Access Token URL: `https://{{cognito_domain}}/oauth2/token`
   - Client ID: `{{client_id}}`
   - Client Secret: `{{client_secret}}`
   - Scope: `cliente-core/read cliente-core/write`
   - Client Authentication: `Send as Basic Auth header`

4. **Clique em "Get New Access Token"**
5. Você verá uma tela com o token gerado
6. Clique em **"Use Token"**
7. O token será adicionado automaticamente a todos os requests da Collection! 🎉

---

## 🧪 Passo 5: Testar os Endpoints

### 5.1. Health Check (sem autenticação)

1. Expanda a Collection
2. Clique em **Health Check**
3. Clique em **Send**
4. Você deve receber: `{"status": "UP"}`

### 5.2. Criar Cliente PF

1. Expanda **Cliente PF**
2. Clique em **1. Criar Cliente PF**
3. Verifique o body JSON (já vem preenchido)
4. Clique em **Send**
5. Response esperado: **201 Created**

**O que acontece automaticamente:**
- O `publicId` do cliente criado é salvo na variável `{{last_created_pf_id}}`
- Você pode usar essa variável nos próximos requests!

### 5.3. Buscar Cliente Criado

1. Clique em **2. Buscar Cliente PF por ID**
2. Note que a URL usa `{{last_created_pf_id}}` (preenchido automaticamente!)
3. Clique em **Send**
4. Response esperado: **200 OK** com os dados do cliente

### 5.4. Atualizar Cliente

1. Clique em **5. Atualizar Cliente PF**
2. Modifique o body JSON conforme necessário
3. Clique em **Send**
4. Response esperado: **200 OK** com os dados atualizados

---

## 🔄 Auto-Refresh do Token

O Postman **renova o token automaticamente** quando ele expira!

- **Validade do token:** 1 hora (3600 segundos)
- **Quando expira:** O Postman pede um novo automaticamente
- **Você não precisa fazer nada!** 🎉

---

## 📊 Variáveis de Environment Explicadas

### Variáveis Fixas (você configura):

| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| `base_url` | URL base do serviço | `http://localhost:8081/api/clientes` |
| `cognito_domain` | Domínio do Cognito | `yukam-auth.auth.sa-east-1.amazoncognito.com` |
| `client_id` | Client ID do Cognito | `3q2r5s6t7u8v9w0x1y2z` |
| `client_secret` | Client Secret do Cognito | `abc123def...` |

### Variáveis Dinâmicas (preenchidas automaticamente):

| Variável | Quando é preenchida | Usada em |
|----------|---------------------|----------|
| `last_created_pf_id` | Após criar Cliente PF | Buscar, Atualizar, Deletar PF |
| `last_created_cpf` | Após criar Cliente PF | Buscar por CPF |
| `last_created_pj_id` | Após criar Cliente PJ | Buscar, Atualizar, Deletar PJ |
| `last_created_cnpj` | Após criar Cliente PJ | Buscar por CNPJ |

---

## 🎯 Fluxo de Teste Sugerido

### Teste Completo - Cliente PF:

1. ✅ **Health Check** - Verifica se serviço está rodando
2. ✅ **Criar Cliente PF** - Cria novo cliente (salva `publicId` automaticamente)
3. ✅ **Buscar por ID** - Valida que foi criado corretamente
4. ✅ **Buscar por CPF** - Testa busca alternativa
5. ✅ **Listar Clientes** - Vê todos os clientes paginados
6. ✅ **Atualizar Cliente** - Modifica alguns campos
7. ✅ **Buscar por ID novamente** - Valida que foi atualizado
8. ✅ **Deletar Cliente** (Soft Delete) - Marca como inativo
9. ✅ **Buscar por ID** - Deve retornar 404
10. ✅ **Restaurar Cliente** - Reativa o cliente
11. ✅ **Buscar por ID** - Cliente voltou!

### Teste Rápido - Cliente PJ:

1. ✅ **Criar Cliente PJ**
2. ✅ **Buscar por CNPJ**
3. ✅ **Atualizar Cliente PJ**

---

## 🛠️ Troubleshooting

### ❌ Erro: "Could not get any response"

**Causa:** Serviço não está rodando

**Solução:**
```bash
# Se local:
cd services/cliente-core
mvn spring-boot:run

# Se produção:
# Verifique se o ECS está rodando
```

### ❌ Erro: "401 Unauthorized"

**Causa:** Token inválido ou expirado

**Solução:**
1. Vá na aba **Authorization** da Collection
2. Clique em **"Get New Access Token"**
3. Clique em **"Use Token"**

### ❌ Erro: "Error getting access token"

**Causa:** Credenciais do Cognito inválidas

**Soluções:**
1. Verifique o `client_id` no Environment
2. Verifique o `client_secret` no Environment
3. Verifique o `cognito_domain` no Environment
4. Confirme que o Client tem os scopes `cliente-core/read` e `cliente-core/write`

### ❌ Erro: "404 Not Found"

**Causa:** URL incorreta

**Soluções:**
1. Verifique se `base_url` está correto no Environment
2. Verifique se o path está correto: `/v1/clientes/pf` (não `/clientes/pf`)
3. Se for buscar por ID, certifique-se que `{{last_created_pf_id}}` foi preenchido

### ❌ Variável `{{last_created_pf_id}}` está vazia

**Causa:** O script de teste não executou

**Solução:**
1. Crie um Cliente PF primeiro (request **1. Criar Cliente PF**)
2. Verifique se recebeu **201 Created**
3. Vá no **Console** do Postman (View → Show Postman Console)
4. Procure por: `"Cliente PF criado: uuid-aqui"`
5. Se não aparecer, execute o request novamente

---

## 📚 Recursos Adicionais

### Swagger UI (quando disponível)

```
http://localhost:8081/api/clientes/swagger-ui/index.html
```

### CloudWatch Logs (Produção)

**Log Group:** `/ecs/cliente-core-prod`

**Query útil:**
```sql
fields @timestamp, @message, correlationId
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```

### Métricas (Produção)

**Health Check:**
```
https://your-alb.elb.amazonaws.com/api/clientes/actuator/health
```

**Metrics:**
```
https://your-alb.elb.amazonaws.com/api/clientes/actuator/metrics
```

---

## 🎉 Próximos Passos

Após validar que tudo funciona:

1. **Adicione seus próprios requests** na Collection
2. **Crie testes automatizados** nos requests (aba Tests)
3. **Configure Newman** para rodar testes via CLI
4. **Integre com CI/CD** (opcional)

---

**Última atualização:** 2025-11-06
**Versão:** 1.0
**Contato:** Se tiver dúvidas, abra uma issue no repositório
