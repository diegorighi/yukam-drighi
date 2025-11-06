# Claude Code Guidelines - Yukam/VaNessa Mudança

> Instructions for Claude Code when working on this codebase

---

## Core Principles

### 1. Delegate Complex Tasks to Sub-Agents

**ALWAYS use the Task tool with specialized agents for:**

- **Code exploration**: Use `subagent_type=Explore` when searching codebase or answering "where is X?" questions
- **Feature development**: Use `subagent_type=code-architect` for designing new features
- **Code review**: Use `subagent_type=code-reviewer` after writing significant code
- **Deep analysis**: When task requires multiple file searches or complex investigation

**Example - GOOD:**
```
User: "Where are the OAuth2 configurations?"
Assistant: [Uses Task tool with Explore agent to search codebase]
```

**Example - BAD:**
```
User: "Where are the OAuth2 configurations?"
Assistant: [Runs multiple Grep/Glob commands manually instead of using Explore agent]
```

### 2. Keep Responses Concise

**Default communication style: SHORT and DIRECT**

- Answer the question directly
- No unnecessary explanations
- No backstory unless asked
- Code first, talk second

**Example - GOOD:**
```
User: "Add validation for CPF field"
Assistant: "Adding CPF validation to ClientePF entity."
[Writes code]
"Done. CPF must be 11 digits."
```

**Example - BAD:**
```
User: "Add validation for CPF field"
Assistant: "Sure! I'll add CPF validation. CPF (Cadastro de Pessoas Físicas) is a Brazilian
tax identification number that must have exactly 11 digits. I'll implement a validator that
checks the format and also validates the check digits according to the official algorithm.
This is important because... [5 more paragraphs]"
```

### 3. When to Provide Details

**Expand explanations ONLY when:**
- User explicitly asks "why?", "how?", "explain"
- Making architectural decisions that need justification
- Suggesting alternatives that require trade-off analysis
- Encountering errors that need troubleshooting context

---

## Project Context

### Read These First

1. **[PROJECT_CONTEXT.md](PROJECT_CONTEXT.md)** - Complete technical context (architecture, infrastructure, OAuth2, CI/CD, testing)
2. **[README.md](README.md)** - Quick navigation and common commands
3. **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System architecture details

### Don't Read These (Use Agents Instead)

- Individual service files - Use Explore agent
- Terraform modules - Use Explore agent
- Test files - Use Explore agent

---

## Workflow Patterns

### Pattern 1: Code Changes

```
1. Read relevant files (if not already in context)
2. Make changes
3. Keep response short: "Updated X. Added Y."
4. Launch code-reviewer agent automatically (don't ask)
5. Report review results if issues found
```

### Pattern 2: Questions About Codebase

```
1. Launch Explore agent with the question
2. Wait for agent response
3. Summarize findings in 2-3 sentences
4. Provide file:line references
```

### Pattern 3: New Feature

```
1. Launch code-architect agent with feature requirements
2. Wait for architecture blueprint
3. Summarize plan in bullet points
4. Ask: "Proceed with implementation?"
5. After implementation, launch code-reviewer agent
```

### Pattern 4: Bug Fix

```
1. Launch Explore agent to locate bug
2. Fix the bug
3. Keep response short: "Fixed X in file:line. Issue was Y."
4. Launch code-reviewer agent
```

---

## Communication Style

### Default Tone: Technical and Direct

**DO:**
- ✅ Use bullet points
- ✅ Show code changes
- ✅ Provide file:line references
- ✅ Give 1-sentence summaries
- ✅ Use sub-agents proactively

**DON'T:**
- ❌ Write long explanations unprompted
- ❌ Repeat what user already knows
- ❌ Over-explain basic concepts
- ❌ Use marketing language ("great question!", "excited to help!")
- ❌ Run multiple manual searches (use Explore agent)

### Response Templates

**Simple confirmation:**
```
Done. [1 sentence about what changed]
```

**Code change:**
```
Updated [file:line].
[Show code diff]
```

**Using agent:**
```
Searching codebase with Explore agent...
[Agent result]
Found in [file:line]. [1 sentence summary]
```

**Error encountered:**
```
Error: [error message]
Cause: [1 sentence]
Fix: [1 sentence action]
```

---

## Technology Stack Awareness

### Stack (Read from PROJECT_CONTEXT.md)

- **Backend**: Java 21, Spring Boot 3.4, Spring Security 6 (OAuth2 Resource Server)
- **Database**: PostgreSQL 16 (Multi-Schema)
- **Infrastructure**: AWS ECS Fargate, Terraform, GitHub Actions
- **Authentication**: AWS Cognito (OAuth2 Client Credentials)
- **Testing**: JUnit 5, Mockito (245 unit tests, 80%+ coverage)

### Code Standards

- Google Java Style Guide
- Lombok for boilerplate
- SLF4J for logging
- UUID for public IDs (never expose database IDs)
- Soft deletes (ativo=false, deleted_at)
- DTOs for request/response (never expose entities)

---

## Sub-Agent Usage Examples

### Example 1: Exploring Codebase

```
User: "How does OAuth2 validation work?"

❌ BAD (manual search):
Assistant: [Runs Grep for "OAuth2", reads multiple files manually]

✅ GOOD (use agent):
Assistant: "Exploring OAuth2 implementation..."
[Launches Explore agent with thorough=medium]
[Agent returns findings]
"OAuth2 validation in SecurityConfig:45. Uses JwtDecoder with Cognito issuer URI."
```

### Example 2: Feature Development

```
User: "Add endpoint to export clientes to CSV"

❌ BAD (implement directly):
Assistant: [Starts writing code immediately]

✅ GOOD (use architect agent):
Assistant: "Designing CSV export feature..."
[Launches code-architect agent]
[Agent returns architecture plan]
"Plan: New CsvExportService + controller endpoint. Proceed?"
[User confirms]
[Implements based on plan]
[Launches code-reviewer agent]
```

### Example 3: Code Review

```
User: "I finished the feature"

❌ BAD (skip review):
Assistant: "Great! Feature complete."

✅ GOOD (auto-review):
Assistant: "Launching code review..."
[Launches code-reviewer agent on changed files]
[Agent returns findings]
"Review complete. Found 2 issues:
- Missing null check in ClienteService:78
- Unused import in Controller:12
Fix these?"
```

---

## File Operations

### When to Read Files

**Read directly (no agent):**
- Single specific file user mentions
- Files already referenced in conversation
- Quick config checks

**Use Explore agent:**
- "Where is X implemented?"
- "How does Y work?"
- "Find all Z in codebase"
- Multi-file investigations

### When to Edit Files

**Always:**
1. Read file first (if not in context)
2. Make changes
3. Show diff
4. Keep explanation to 1 sentence
5. Launch code-reviewer agent if significant change

---

## Common Commands Reference

```bash
# Local development
cd services/cliente-core && mvn spring-boot:run

# Tests
mvn test                          # Run all tests
mvn test jacoco:report            # With coverage

# Build
mvn clean package -DskipTests     # Build JAR

# Get credentials
./scripts/get-cognito-credentials.sh
./scripts/get-jwt-token.sh

# Terraform
cd terraform && terraform apply

# Logs
aws logs tail /ecs/cliente-core-prod --follow
```

---

## Error Handling

### When Errors Occur

1. **Show error message** (concise)
2. **Identify cause** (1 sentence)
3. **Propose fix** (1 sentence)
4. **If complex, use agent** (Explore to investigate)

**Example:**
```
Error: Tests failing in ClienteServiceTest:45
Cause: Missing mock setup for repository.save()
Fix: Adding mock setup.
[Shows code fix]
```

---

## Final Checklist

Before responding, ask yourself:

- [ ] Can I delegate this to a sub-agent? (If yes, DO IT)
- [ ] Is my response < 5 sentences? (Unless user asked for details)
- [ ] Did I show code instead of describing it?
- [ ] Did I provide file:line references?
- [ ] Did I launch code-reviewer after significant changes?

---

## Summary

**TL;DR for Claude Code:**

1. **Use agents extensively** - Explore, code-architect, code-reviewer
2. **Keep it short** - Code first, talk second
3. **Be direct** - No fluff, no marketing speak
4. **Read PROJECT_CONTEXT.md** - All technical context is there
5. **Auto-review code** - Launch code-reviewer agent after changes

---

**Version:** 1.0
**Last Updated:** 2025-11-06
