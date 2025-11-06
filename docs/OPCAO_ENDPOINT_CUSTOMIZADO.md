# Opção: Endpoint Customizado de Auth (Estilo Sensedia)

## 🎯 Objetivo

Criar um endpoint `/api/auth/token` no seu backend que:
- Aceita **Basic Auth** (client_id:client_secret)
- Chama o AWS Cognito internamente
- Retorna o JWT para o cliente

**Vantagem:** Postman fica igual ao Sensedia (usa Basic Auth direto)

**Desvantagem:** Você mantém código adicional e adiciona latência extra

---

## 🏗️ Arquitetura Atual vs Nova

### Atual (Direto no Cognito):

```
┌─────────┐  OAuth2    ┌──────────────┐  Bearer JWT  ┌─────────────┐
│ Postman │ ────────> │ AWS Cognito  │ ───────────> │ Cliente API │
└─────────┘            └──────────────┘              └─────────────┘
    │                                                       │
    └─── 1. Get JWT via OAuth2                             │
         2. Use JWT nos requests ──────────────────────────┘
```

**Configuração Postman:**
- Type: OAuth 2.0
- Grant Type: Client Credentials
- Client Authentication: Send as Basic Auth header

---

### Proposta (Endpoint Customizado tipo Sensedia):

```
┌─────────┐ Basic Auth ┌─────────────┐ OAuth2 ┌──────────────┐
│ Postman │ ─────────> │ Auth        │ ─────> │ AWS Cognito  │
└─────────┘            │ Controller  │        └──────────────┘
    │                  └─────────────┘               │
    │                         │                      │
    │                         └─── Get JWT ──────────┘
    │                         │
    │                    Return JWT
    │                         │
    └─── Use JWT ─────────────┘
         nos requests      │
              │            ▼
              │     ┌─────────────┐
              └───> │ Cliente API │
                    └─────────────┘
```

**Configuração Postman (igual Sensedia):**
- Type: Basic Auth
- Username: client_id
- Password: client_secret
- POST /api/auth/token

---

## 📝 Implementação

### 1. Criar Controller de Auth

**Arquivo:** `services/cliente-core/src/main/java/br/com/vanessa_mudanca/cliente_core/infrastructure/web/controller/AuthController.java`

```java
package br.com.vanessa_mudanca.cliente_core.infrastructure.web.controller;

import br.com.vanessa_mudanca.cliente_core.application.service.CognitoAuthService;
import br.com.vanessa_mudanca.cliente_core.infrastructure.web.dto.TokenResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Base64;

/**
 * Controller para autenticação OAuth2 Client Credentials.
 *
 * Similar ao endpoint de auth do Sensedia API Platform.
 * Aceita Basic Auth e retorna JWT do AWS Cognito.
 */
@Slf4j
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Tag(name = "Authentication", description = "Endpoints de autenticação OAuth2")
public class AuthController {

    private final CognitoAuthService cognitoAuthService;

    /**
     * Obtém um JWT do AWS Cognito usando Client Credentials.
     *
     * Similar ao endpoint do Sensedia - aceita Basic Auth e retorna JWT.
     *
     * @param authorization Header Authorization com Basic Auth (client_id:client_secret em base64)
     * @return TokenResponse com access_token, token_type e expires_in
     */
    @Operation(
        summary = "Obter Access Token JWT",
        description = "Obtém um JWT do AWS Cognito usando Client Credentials flow. " +
                      "Envie o client_id e client_secret via Basic Auth header.",
        security = @SecurityRequirement(name = "basicAuth")
    )
    @ApiResponse(
        responseCode = "200",
        description = "Token JWT obtido com sucesso",
        content = @Content(schema = @Schema(implementation = TokenResponse.class))
    )
    @ApiResponse(responseCode = "401", description = "Credenciais inválidas")
    @ApiResponse(responseCode = "400", description = "Requisição inválida")
    @PostMapping("/token")
    public ResponseEntity<TokenResponse> getToken(
            @RequestHeader("Authorization") String authorization) {

        log.info("📥 Recebida requisição para obter token JWT");

        // 1. Validar header Authorization
        if (authorization == null || !authorization.startsWith("Basic ")) {
            log.error("❌ Header Authorization inválido ou ausente");
            return ResponseEntity.status(401).build();
        }

        try {
            // 2. Decodificar Basic Auth (client_id:client_secret)
            String base64Credentials = authorization.substring(6); // Remove "Basic "
            String credentials = new String(Base64.getDecoder().decode(base64Credentials));
            String[] parts = credentials.split(":", 2);

            if (parts.length != 2) {
                log.error("❌ Formato de credenciais inválido");
                return ResponseEntity.status(401).build();
            }

            String clientId = parts[0];
            String clientSecret = parts[1];

            log.info("🔑 Client ID: {}...", clientId.substring(0, Math.min(10, clientId.length())));

            // 3. Chamar Cognito para obter JWT
            TokenResponse token = cognitoAuthService.getToken(clientId, clientSecret);

            log.info("✅ Token JWT obtido com sucesso. Expira em: {} segundos", token.getExpiresIn());

            return ResponseEntity.ok(token);

        } catch (IllegalArgumentException e) {
            log.error("❌ Erro ao decodificar credenciais: {}", e.getMessage());
            return ResponseEntity.status(401).build();
        } catch (Exception e) {
            log.error("❌ Erro ao obter token do Cognito: {}", e.getMessage(), e);
            return ResponseEntity.status(500).build();
        }
    }
}
```

---

### 2. Criar DTO de Response

**Arquivo:** `services/cliente-core/src/main/java/br/com/vanessa_mudanca/cliente_core/infrastructure/web/dto/TokenResponse.java`

```java
package br.com.vanessa_mudanca.cliente_core.infrastructure.web.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Response DTO para o endpoint /api/auth/token.
 *
 * Formato compatível com OAuth2 Client Credentials flow.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "Response com Access Token JWT")
public class TokenResponse {

    @Schema(
        description = "JWT Access Token para usar nas requisições",
        example = "eyJraWQiOiJxc1wvXC8rNjBkQ0dGK0lqN3R..."
    )
    @JsonProperty("access_token")
    private String accessToken;

    @Schema(
        description = "Tipo do token (sempre Bearer)",
        example = "Bearer"
    )
    @JsonProperty("token_type")
    private String tokenType;

    @Schema(
        description = "Tempo em segundos até o token expirar",
        example = "3600"
    )
    @JsonProperty("expires_in")
    private Integer expiresIn;

    @Schema(
        description = "Scopes concedidos para este token",
        example = "cliente-core/read cliente-core/write"
    )
    @JsonProperty("scope")
    private String scope;
}
```

---

### 3. Criar Service para chamar Cognito

**Arquivo:** `services/cliente-core/src/main/java/br/com/vanessa_mudanca/cliente_core/application/service/CognitoAuthService.java`

```java
package br.com.vanessa_mudanca.cliente_core.application.service;

import br.com.vanessa_mudanca.cliente_core.infrastructure.web.dto.TokenResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

import java.util.Base64;

/**
 * Service para obter tokens JWT do AWS Cognito.
 *
 * Faz a chamada OAuth2 Client Credentials para o Cognito.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CognitoAuthService {

    private final RestTemplate restTemplate;

    @Value("${aws.cognito.domain}")
    private String cognitoDomain;

    @Value("${aws.cognito.scope:cliente-core/read cliente-core/write}")
    private String scope;

    /**
     * Obtém um JWT do AWS Cognito usando Client Credentials flow.
     *
     * @param clientId Client ID do App Client Cognito
     * @param clientSecret Client Secret do App Client Cognito
     * @return TokenResponse com JWT e metadata
     * @throws RuntimeException se falhar ao obter token
     */
    public TokenResponse getToken(String clientId, String clientSecret) {

        String tokenUrl = String.format("https://%s/oauth2/token", cognitoDomain);

        log.info("🔄 Obtendo token do Cognito: {}", tokenUrl);

        try {
            // 1. Criar Basic Auth header
            String credentials = clientId + ":" + clientSecret;
            String base64Credentials = Base64.getEncoder().encodeToString(credentials.getBytes());

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
            headers.set("Authorization", "Basic " + base64Credentials);

            // 2. Criar body (grant_type=client_credentials)
            MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
            body.add("grant_type", "client_credentials");
            body.add("scope", scope);

            HttpEntity<MultiValueMap<String, String>> request = new HttpEntity<>(body, headers);

            // 3. Fazer requisição para Cognito
            ResponseEntity<CognitoTokenResponse> response = restTemplate.exchange(
                tokenUrl,
                HttpMethod.POST,
                request,
                CognitoTokenResponse.class
            );

            if (response.getStatusCode() != HttpStatus.OK || response.getBody() == null) {
                log.error("❌ Erro ao obter token do Cognito: Status {}", response.getStatusCode());
                throw new RuntimeException("Failed to get token from Cognito");
            }

            CognitoTokenResponse cognitoToken = response.getBody();

            log.info("✅ Token obtido com sucesso do Cognito");

            // 4. Converter para TokenResponse
            return TokenResponse.builder()
                .accessToken(cognitoToken.getAccessToken())
                .tokenType(cognitoToken.getTokenType())
                .expiresIn(cognitoToken.getExpiresIn())
                .scope(scope)
                .build();

        } catch (Exception e) {
            log.error("❌ Erro ao obter token do Cognito: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to get token from Cognito", e);
        }
    }

    /**
     * DTO interno para deserializar response do Cognito.
     */
    @lombok.Data
    private static class CognitoTokenResponse {
        @com.fasterxml.jackson.annotation.JsonProperty("access_token")
        private String accessToken;

        @com.fasterxml.jackson.annotation.JsonProperty("token_type")
        private String tokenType;

        @com.fasterxml.jackson.annotation.JsonProperty("expires_in")
        private Integer expiresIn;
    }
}
```

---

### 4. Adicionar configuração no application.yml

**Arquivo:** `services/cliente-core/src/main/resources/application.yml`

```yaml
aws:
  cognito:
    domain: ${COGNITO_DOMAIN:vanessa-mudanca-auth-prod.auth.sa-east-1.amazoncognito.com}
    scope: ${COGNITO_SCOPE:cliente-core/read cliente-core/write}
```

---

### 5. Criar Bean RestTemplate

**Arquivo:** `services/cliente-core/src/main/java/br/com/vanessa_mudanca/cliente_core/config/RestTemplateConfig.java`

```java
package br.com.vanessa_mudanca.cliente_core.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

@Configuration
public class RestTemplateConfig {

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}
```

---

### 6. Atualizar SecurityConfig para permitir /api/auth/token sem autenticação

**Arquivo:** `services/cliente-core/src/main/java/br/com/vanessa_mudanca/cliente_core/config/SecurityConfig.java`

```java
// Adicionar no método filterChain:
.requestMatchers("/api/auth/token").permitAll() // Endpoint de auth público
```

---

## 🧪 Como Testar no Postman (Igual Sensedia!)

### Request:

```
POST http://localhost:8081/api/auth/token
```

**Authorization Tab:**
- Type: **Basic Auth**
- Username: `41u8or3q6id9nm8395qvl214j`
- Password: `i64vo56mdf5m2ig9q0tu0ur6lsdb1tius`

**Headers:**
```
Content-Type: application/x-www-form-urlencoded
```

**Response esperado:**
```json
{
  "access_token": "eyJraWQiOiJxc1wvXC8rNjBkQ0dGK0lqN3R...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "cliente-core/read cliente-core/write"
}
```

---

## 📊 Comparação Final

| Aspecto | Direto no Cognito | Endpoint Customizado |
|---------|-------------------|---------------------|
| **Postman Config** | OAuth 2.0 (mais complexo) | Basic Auth (mais simples) |
| **Latência** | ~200ms | ~400ms (2x requests) |
| **Manutenção** | Zero (gerenciado AWS) | Médio (seu código) |
| **Segurança** | Enterprise-grade | Depende da sua impl |
| **Custo** | Grátis (free tier) | Grátis + tempo dev |
| **Escalabilidade** | Infinita | Limitado por seu backend |
| **Familiaridade** | Nova (OAuth2) | Alta (igual Sensedia) |

---

## 🎯 Minha Recomendação

### Para MVP: **Manter direto no Cognito** ✅

**Por quê?**
1. ⚡ **Velocidade de desenvolvimento**: Não precisa escrever/testar código adicional
2. 🛡️ **Segurança**: AWS Cognito é enterprise-grade, auditado, compliance
3. 💰 **Custo**: Zero manutenção, zero bugs para você resolver
4. 📈 **Escalabilidade**: Infinita, sem você fazer nada
5. 🔄 **Menos código**: Menos código = menos bugs

**Desvantagem:**
- ⚠️ Postman um pouco mais complexo (mas é só configurar uma vez)

### Para Produção: **Considerar endpoint customizado**

**Quando fizer sentido:**
- ✅ Você tem múltiplos serviços e quer centralizar auth
- ✅ Precisa adicionar lógica customizada (rate limiting, logging, etc)
- ✅ Quer abstrair o provider (trocar Cognito por Keycloak no futuro)
- ✅ Equipe já está familiarizada com padrão Sensedia

---

## ✅ Resumo

**Você pode fazer igual ao Sensedia?**
- ✅ SIM, tecnicamente é possível
- ⚠️ MAS adiciona complexidade e latência
- 💡 Para MVP, recomendo manter direto no Cognito
- 🔄 Quando escalar, considere criar o endpoint customizado

**O que fazer agora?**
1. Use direto o Cognito (OAuth 2.0 no Postman)
2. Se realmente quiser endpoint customizado, eu implemento para você
3. Documente qual foi a decisão

---

**Última atualização:** 2025-11-06
**Complexidade:** Média (2-3h implementação + testes)
