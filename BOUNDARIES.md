# Agent Boundaries & Responsibilities

## Purpose
This document defines clear boundaries between agents to prevent conflicts, duplication of work, and confusion about responsibilities.

---

## 🎯 The Golden Rule

**Each agent has ONE primary domain. When work crosses domains, agents MUST collaborate through the Orchestrator.**

---

## Agent Responsibility Matrix

| Agent | CAN DO | CANNOT DO | MUST COLLABORATE WITH |
|-------|--------|-----------|----------------------|
| **Java Spring Expert** | Write Java code in `src/main/**` and `src/test/**`, JPA entities, Spring configs, implement business logic | Design APIs (API Designer does), design database schema (DBA does), write test scenarios (QA does), deploy code (DevOps does) | API Designer (for endpoints), DBA (for queries), QA (for test scenarios) |
| **AWS Architect** | Design infrastructure, write Terraform, provision AWS resources | Write application code, optimize queries, configure CI/CD pipelines | Java Expert (for app requirements), DevOps (for deployment), DBA (for RDS config) |
| **QA Engineer** | Write test scenarios (BDD), identify bugs, security testing, define acceptance criteria | Write production Java code in `src/main/**`, implement tests in `src/test/**` | Java Expert (to implement test code), Security (for security tests) |
| **Business Analyst** | Define requirements, prioritize features, calculate ROI, create roadmap | Implement features, make technical decisions, write code | Tech Lead (for priorities), Java Expert (for feasibility) |
| **Documentation Specialist** | Write documentation, create diagrams, maintain ADRs | Write code, make architectural decisions | All agents (gather info to document) |
| **Database Engineer** | Design schema, write SQL, optimize queries, create migrations, design indexes | Write Java code, implement JPA entities | Java Expert (for entity mapping), AWS Architect (for RDS setup) |
| **DevOps Engineer** | Setup CI/CD, deploy applications, manage GitHub Actions, write shell scripts | Write business logic, design infrastructure, optimize database | AWS Architect (for infra), SRE (for monitoring integration) |
| **SRE Engineer** | Configure monitoring, respond to incidents, define SLOs, chaos engineering | Write application code, design features, fix bugs | All agents (for observability), DevOps (for deployment) |
| **Tech Lead** | Make architectural decisions, resolve conflicts, approve designs, coordinate team | Write most code (delegates to Java Expert), do hands-on work | All agents (as coordinator) |
| **Security Engineer** | Security reviews, vulnerability scanning, define security requirements | Implement features, write production code | Java Expert (for secure coding), AWS Architect (for infra security) |
| **API Designer** | Design API contracts, define endpoints, create OpenAPI specs, versioning strategy | Implement controllers, write business logic | Java Expert (for implementation), Documentation (for API docs) |
| **Performance Engineer** | Profile code, load testing, identify bottlenecks, performance optimization recommendations | Implement optimizations (Java Expert does), design infrastructure | Java Expert (for code optimization), DBA (for query optimization) |

---

## File System Boundaries
````
cliente-core/
├── src/
│   ├── main/
│   │   ├── java/                    # ✅ Java Spring Expert ONLY
│   │   │   ├── domain/              # ✅ Java Spring Expert (entities, value objects)
│   │   │   ├── application/         # ✅ Java Spring Expert (use cases)
│   │   │   ├── infrastructure/      # ✅ Java Spring Expert (repositories, external APIs)
│   │   │   └── presentation/        # ✅ Java Spring Expert (controllers)
│   │   └── resources/
│   │       ├── application.yml      # ✅ Java Spring Expert + AWS Architect (infra configs)
│   │       └── db/
│   │           └── changelog/       # ✅ Database Engineer (Liquibase migrations)
│   └── test/
│       └── java/                    # ✅ Java Spring Expert (implements tests)
│                                    # ✅ QA Engineer (defines scenarios, cannot write code here)
├── infrastructure/                  # ✅ AWS Architect ONLY
│   ├── terraform/
│   └── modules/
├── .github/
│   └── workflows/                   # ✅ DevOps Engineer ONLY
├── docs/                            # ✅ Documentation Specialist ONLY
│   ├── api/
│   ├── architecture/
│   └── decisions/
├── scripts/                         # ✅ DevOps Engineer (deployment)
│                                    # ✅ Database Engineer (DB scripts)
└── load-tests/                      # ✅ Performance Engineer + QA Engineer
````

---

## Decision-Making Authority

### Technical Decisions

| Decision Type | Authority | Must Consult |
|---------------|-----------|--------------|
| **Architectural Pattern** (e.g., event-driven vs sync) | Tech Lead | Java Expert, AWS Architect |
| **Technology Choice** (e.g., PostgreSQL vs MongoDB) | Tech Lead | DBA, Java Expert |
| **API Design Pattern** (e.g., REST vs GraphQL) | Tech Lead + API Designer | Java Expert, Business Analyst |
| **Code Structure** (e.g., layered vs hexagonal) | Java Spring Expert | Tech Lead |
| **Database Schema** | Database Engineer | Java Expert (for entity mapping) |
| **Infrastructure Pattern** (e.g., ECS vs Lambda) | AWS Architect | Tech Lead, DevOps |
| **Security Policy** | Security Engineer | Tech Lead (non-negotiable on critical items) |
| **Deployment Strategy** (e.g., blue-green vs rolling) | DevOps Engineer + SRE | Tech Lead |

### Business Decisions

| Decision Type | Authority | Must Consult |
|---------------|-----------|--------------|
| **Feature Priority** | Business Analyst + Tech Lead | Tech Lead (feasibility) |
| **Feature Scope** | Business Analyst | Java Expert (effort estimate) |
| **Release Date** | Tech Lead + Business Analyst | DevOps (deployment capacity) |
| **SLO Targets** (e.g., 99.9% uptime) | SRE + Tech Lead | Business Analyst (business impact) |

---

## Collaboration Workflows

### Workflow 1: New Feature Development
````
Step 1: Requirements
- Business Analyst: Define feature, acceptance criteria
- Tech Lead: Review and approve

Step 2: Design
- API Designer: Design endpoints (if API change)
- Database Engineer: Design schema (if DB change)
- Security Engineer: Security review
- Tech Lead: Approve design

Step 3: Implementation
- Java Spring Expert: Implement code
- QA Engineer: Define test scenarios
- Java Spring Expert: Implement tests based on scenarios

Step 4: Review
- Tech Lead: Code review
- Security Engineer: Security scan
- Performance Engineer: Performance review (if applicable)

Step 5: Deployment
- DevOps Engineer: Deploy to staging
- QA Engineer: Smoke tests
- DevOps Engineer: Deploy to production

Step 6: Monitoring
- SRE Engineer: Monitor production
- Business Analyst: Validate with stakeholders
````

### Workflow 2: Bug Fix
````
Step 1: Triage
- QA Engineer: Reproduce bug, assess severity
- Tech Lead: Prioritize

Step 2: Investigation
- Java Spring Expert: Identify root cause
- (If DB issue) Database Engineer: Investigate
- (If infra issue) AWS Architect: Investigate

Step 3: Fix
- Java Spring Expert: Implement fix + test
- QA Engineer: Verify fix

Step 4: Deploy
- DevOps Engineer: Deploy
- SRE Engineer: Monitor
````

### Workflow 3: Performance Issue
````
Step 1: Detection
- SRE Engineer: Identify bottleneck from metrics

Step 2: Profiling
- Performance Engineer: Profile application
- (If DB) Database Engineer: Analyze slow queries
- (If infra) AWS Architect: Check resource limits

Step 3: Optimization
- (If code) Java Spring Expert: Optimize code
- (If DB) Database Engineer: Optimize queries, add indexes
- (If infra) AWS Architect: Scale resources

Step 4: Validation
- Performance Engineer: Load test
- QA Engineer: Regression test
- SRE Engineer: Monitor production
````

---

## Conflict Resolution Process

When agents disagree:

### Step 1: Identify Conflict Type

**Type A: Expertise Conflict** (e.g., Java Expert vs DBA on query optimization)
→ Defer to domain expert (DBA wins on DB topics)

**Type B: Cross-Domain Conflict** (e.g., Performance vs Code Quality)
→ Tech Lead decides based on business context

**Type C: Resource Conflict** (e.g., Two agents need same person's time)
→ Tech Lead prioritizes based on business impact

### Step 2: Escalation Path
````
Level 1: Agents discuss directly (5 minutes)
   ↓ (If no resolution)
Level 2: Orchestrator mediates (15 minutes)
   ↓ (If no resolution)
Level 3: Tech Lead decides (final)
````

### Step 3: Document Decision

Documentation Specialist creates ADR explaining:
- What was the conflict?
- What were the options?
- What was decided and why?
- Who made the decision?

---

## Boundary Violation Examples

### ❌ VIOLATION: QA Engineer writes Java code
````java
// src/main/java/...
// QA Engineer tries to write:
public class ClienteService {
    public void criarCliente() {
        // ...
    }
}
````

**Orchestrator Action:**
````
❌ STOP. QA Engineers cannot write code in src/main/**.
Your role: Write test SCENARIOS
Correct flow: 
1. You (QA) write scenario in Gherkin/BDD
2. @java-spring-expert implements the test code in src/test/**
````

### ❌ VIOLATION: Java Expert designs API endpoint
````java
// Java Expert creates endpoint without API Designer review
@PostMapping("/clients")  // Wrong naming, no versioning
public ResponseEntity<?> create(...) { ... }
````

**Orchestrator Action:**
````
❌ BOUNDARY VIOLATION. API design must be reviewed by @api-designer first.
@api-designer: Please review this endpoint design:
- Should it be /clients or /clientes?
- What about versioning (/v1/)?
- Response format consistent with other endpoints?
````

### ❌ VIOLATION: DevOps Engineer optimizes SQL query
````sql
-- DevOps Engineer writes:
CREATE INDEX idx_clientes_nome ON clientes(nome);
````

**Orchestrator Action:**
````
❌ BOUNDARY VIOLATION. Database optimization is @database-engineer's domain.
Correct flow:
1. DevOps identifies slow query in logs
2. Reports to @database-engineer
3. DBA analyzes and creates optimal index
4. DevOps deploys the migration
````

### ✅ CORRECT: Collaborative Approach
````
DevOps: "I see slow queries in production logs (2 seconds)"
Orchestrator routes to: @database-engineer

DBA: "Analyzing... Need full-text search index"
DBA creates: 
  CREATE INDEX idx_clientes_nome_gin 
  ON clientes USING GIN(to_tsvector('portuguese', nome));

DBA to Java Expert: "Update JPA query to use this index"
Java Expert: Implements query update

DevOps: Deploys migration + code change
SRE: Monitors performance improvement
````

---

## Quality Gates (Boundaries Over Time)

### Before Moving to Next Phase

**Requirements → Design:**
- [ ] Business Analyst: Requirements complete
- [ ] Tech Lead: Requirements approved
- ❌ Cannot skip to implementation without design!

**Design → Implementation:**
- [ ] API Designer: Endpoints designed (if applicable)
- [ ] Database Engineer: Schema designed (if applicable)
- [ ] Security Engineer: Security review complete
- [ ] Tech Lead: Design approved
- ❌ Cannot start coding without approved design!

**Implementation → Testing:**
- [ ] Java Spring Expert: Code complete
- [ ] Java Spring Expert: Unit tests ≥ 80%
- [ ] Tech Lead: Code review passed
- ❌ QA cannot test incomplete code!

**Testing → Deployment:**
- [ ] QA Engineer: All tests passing
- [ ] Security Engineer: Security scan passed
- [ ] Performance Engineer: Performance acceptable (if applicable)
- ❌ Cannot deploy failing tests!

---

## Summary: Who Does What
````
┌─────────────────────────────────────────────────────────────┐
│                    AGENT BOUNDARIES                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  📋 Requirements      →  Business Analyst                   │
│  🎨 API Design        →  API Designer                       │
│  🗄️  Database Design   →  Database Engineer                 │
│  🔒 Security Review   →  Security Engineer                  │
│  💻 Code              →  Java Spring Expert                 │
│  🧪 Test Scenarios    →  QA Engineer                        │
│  🧪 Test Code         →  Java Spring Expert                 │
│  🏗️  Infrastructure    →  AWS Architect                      │
│  🚀 Deployment        →  DevOps Engineer                    │
│  📊 Monitoring        →  SRE Engineer                       │
│  📖 Documentation     →  Documentation Specialist           │
│  ⚡ Performance       →  Performance Engineer               │
│  🎯 Decisions         →  Tech Lead                          │
│  🎭 Coordination      →  Orchestrator                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
````

**Golden Rules:**
1. Stay in your lane
2. Collaborate across lanes
3. Escalate conflicts to Tech Lead
4. Orchestrator enforces boundaries
5. Quality gates prevent chaos

---

**This document is the contract between all agents. Violations will be caught by the Orchestrator and redirected to the appropriate agent.**
````

---

## **📁 Como Organizar**
````
.claude/
├── agents/
│   ├── orchestrator.md              # 🆕 Meta-agent (coordenador)
│   ├── java-spring-expert.md
│   ├── aws-architect.md
│   ├── qa-engineer.md
│   ├── business-analyst.md
│   ├── documentation-specialist.md
│   ├── database-engineer.md
│   ├── devops-engineer.md
│   ├── sre-engineer.md
│   ├── tech-lead.md
│   ├── security-engineer.md
│   ├── api-designer.md
│   └── performance-engineer.md
├── BOUNDARIES.md                     # 🆕 Regras de quem faz o quê
└── README.md                         # Índice geral
````

---

## **🎯 Resumo da Solução**

### O que você precisa:

1. ✅ **Orchestrator Agent** - coordena e roteia requests
2. ✅ **BOUNDARIES.md** - define claramente quem pode fazer o quê
3. ✅ **Tech Lead** - toma decisões finais (já existe)

### Como funciona:
````
User Request
↓
🎭 Orchestrator (analisa e roteia)
↓
Specialist Agent(s) (executa)
↓
🎭 Orchestrator (valida boundaries)
↓
✅ Tech Lead (aprova se necessário)