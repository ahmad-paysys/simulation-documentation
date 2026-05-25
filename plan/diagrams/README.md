# Diagrams — Simulation Studio Architecture & Data Flow

This directory contains all visual reference diagrams for Simulation Studio system design, data relationships, and request/response flows. All diagrams use **Mermaid syntax** for GitHub-native rendering and maximum portability.

---

## Diagram Index

### erd.md — Entity Relationship Diagram
**Format**: Mermaid `erDiagram`  
**Scope**: PostgreSQL `simulation_studio` database schema (16 tables, all relationships)  
**Purpose**: Single source of truth for data structure; reference when designing queries, writing migrations, or debugging data integrity issues.  
**Key Relationships**: Suite → Generations → Context/Trigger/Enrichment configs → Generated messages/rows; Suite → Runs → Results; Results → Context links.  
**Color**: N/A (diagram elements not color-coded)  
**Last Updated**: 2026-05-24  
**Reference**: See [../database-migration.sql](../database-migration.sql) for DDL; [../implementation_report.md](../implementation_report.md) §3 for schema decisions.

---

### architecture.md — High-Level System Architecture
**Format**: Mermaid `flowchart TB` (top-to-bottom)  
**Scope**: Logical deployment view across browser, identity, rule-studio backend, admin-service, databases, Docker engine, and Docker Hub.  
**Purpose**: Shared mental model for system design; used in onboarding, design reviews, and cross-team coordination.  
**Color Coding**:
- **Blue**: New components for this initiative (SimulationStudioModule, RegistryService, OrchestratorService, ContextGenerationService, admin-service simulation-studio layer, new FE pages, new DB).
- **Yellow**: Reused existing components (TazamaAuthGuard, AdminServiceClient, tcs-config layer, existing repos, Keycloak, Docker Hub).
- **Gray**: Untouched legacy modules (existing simulation, rules, rerun-simulation services).

**Trust Boundaries**: (1) Browser → RS Backend (JWT bearer). (2) RS Backend → Admin-Service (JWT forwarded). (3) RS Backend → Docker (out-of-band socket/mTLS). (4) RS Backend → Docker Hub (service-account JWT, 50-min TTL cache).  
**Key Flows**: Frontend requests → Controller → Service → RegistryService / ContextGenerationService / OrchestratorService; all persistence via AdminServiceClient to admin-service repositories; Docker Orchestrator provisions sim-run networks and manages containers.  
**Last Updated**: 2026-05-24  
**Reference**: See [../implementation_report.md](../implementation_report.md) §2 for architecture decisions.

---

### dfd.md — Data Flow Diagram (Two Views)
**Format**: Mermaid `flowchart` (LR and TB layouts)  
**Scope**: Request/response paths and state transitions across the full feature lifecycle.  

#### View 1: Wizard Authoring — DRAFT to Saved Iteration
**Purpose**: Show how user input flows through the six-screen wizard, persisted incrementally as drafts, then saved as a final iteration.  
**Data Items**: Screen 1–5 form fields accumulate in `trs_simulation_suites.metadata` (JSONB); `wizard_progress` tracks resume cursor; generated context payloads live in client state until saved.  
**Key Endpoints**: POST /suites → PUT /suites/:id/draft → POST /suites/:id/generate/context → POST /suites/:id/run.  
**Actors**: User, Frontend, rule-studio backend (SimulationStudioService), admin-service (simulation-studio.logic), databases.  
**Color Coding**:
- **Blue**: Frontend / wizard screens
- **Yellow**: API endpoints
- **Green**: Backend services and logic layers
- **Gray**: Infrastructure (databases, external services)

#### View 2: Run Execution — POST /run → Results
**Purpose**: Show how a run is provisioned, executed, and results are streamed back to the UI in real-time.  
**Critical Sequencing**:
1. Service verifies image + returns digest → DB
2. Orchestrator dispatches (fire-and-forget) → 200 response with `runId`
3. Orchestrator provisions Docker network + containers (parallel)
4. ODS populates ephemeral Postgres with context/enrichment
5. TransactionLoopService submits sim pairs to NATS
6. rule-processor consumes, reads ODS, produces result
7. Results streamed back via NATS → saved to DB immediately (not batched)
8. UI polls status endpoint every 2s, receives `partialResults`
9. On terminal status, query results endpoint for full set

**Key Services**: SimulationStudioService, RegistryService, OrchestratorService, SingleRuleEnvBuilder, OdsInitService, TransactionLoopService, EnvRegistryService.  
**Docker Components**: sim-run-<runId> network, ephemeral Postgres ODS, NATS, nats-utilities, rule-processor (pinned by SHA256).  
**Timing**: Async orchestration; run status updates via AdminServiceClient; crash recovery on backend startup.  
**Last Updated**: 2026-05-24  
**Reference**: See [../implementation_report.md](../implementation_report.md) §5–6 for service contracts; §8 for transaction handling.

---

## When to Use Each Diagram

| Scenario | Diagram(s) |
|----------|-----------|
| **I'm designing a new endpoint** | architecture.md (show where it fits), dfd.md View 2 (if it affects run execution) |
| **I'm writing a database query** | erd.md (understand relationships, FK constraints) |
| **I'm debugging a data flow issue** | dfd.md (trace the request path), erd.md (check schema assumptions) |
| **I'm onboarding a new engineer** | architecture.md (big picture), then dfd.md View 1 or 2 (depending on their task) |
| **I'm explaining the system to a stakeholder** | architecture.md (10-minute overview) |
| **I'm reviewing a PR that touches run execution** | dfd.md View 2 (verify orchestration flow is unchanged) |
| **I'm troubleshooting data persistence** | erd.md + dfd.md View 2 (trace who writes what, when) |
| **I'm setting up integration tests** | dfd.md (both views; understand expected state transitions) |

---

## How to Read Mermaid Diagrams

### Mermaid Syntax Quick Reference

**Entity Relationship Diagram** (`erDiagram`):
- `Table1 ||--o{ Table2` = 1:many relationship (one Table1 to many Table2)
- `Table1 }o--o{ Table2` = many:many relationship
- `Table1 }o--|| Table2` = many to one (many Table1 to one Table2)
- `{ ... }` = entity attributes (column names, types)

**Flowchart** (`flowchart`):
- `["Box"]` = rectangle (component/step)
- `("Rounded")` = rounded box (process)
- `subgraph NAME["Label"] ... end` = grouping (subsystem)
- `A --> B` = directed arrow (flow, message, dependency)
- `A -. "Label" .-> B` = dashed arrow (conditional or async)
- `classDef new fill:#cdeaff,stroke:#0b62a4; class A new;` = styling (color)

### Rendering on GitHub

All diagrams render natively in GitHub markdown—no external tools needed. If a diagram does not render:
1. Refresh the page (Mermaid JS may need to re-initialize)
2. Try viewing the raw `.md` file
3. Copy the Mermaid block into [mermaid.live](https://mermaid.live) to debug syntax

---

## Extending Diagrams

### Adding a New Component to architecture.md

1. Decide: blue (new), yellow (reused), or gray (untouched)
2. Add node: `COMP["Component Name<br/>Library/Framework"]`
3. Add relationship: `COMP --> OTHERSYSTEM`
4. Add to class list: `class COMP new;` (or ext, or untouched)
5. Update trust boundaries section if relevant
6. Test render on GitHub

Example:
```mermaid
NEWSVC["NewService<br/>NestJS"]
NEWSVC --> ADMIN
classDef new fill:#cdeaff,stroke:#0b62a4;
class NEWSVC new;
```

### Adding a New Data Flow to dfd.md

1. Decide: belongs to View 1 (wizard) or View 2 (run execution)?
2. Add process/actor: `ACTOR(["Actor<br/>Label"])`
3. Add arrow: `SOURCE --> DEST : "Label"`
4. Add colored subgraphs for swimlanes (e.g., `subgraph RSB["rule-studio/backend"] ... end`)
5. Update class definitions for color
6. Test render on GitHub

Example:
```mermaid
NEWSTEP["New Process<br/>Label"]
PREV --> NEWSTEP --> NEXT
classDef svc fill:#e6ffe6,stroke:#2a7a2a;
class NEWSTEP svc;
```

### Updating erd.md After Schema Changes

1. Apply changes to [../database-migration.sql](../database-migration.sql)
2. Add/remove table definitions in the `erDiagram` section
3. Update relationships (FK arrows)
4. Test render on GitHub
5. Update version number and date in the `.md` file header

---

## Diagram Maintenance Checklist

Before committing diagram changes:

- [ ] **Syntax Valid**: Mermaid block renders without errors on GitHub (and on mermaid.live if you're unsure)
- [ ] **Relationships Correct**: Every FK or integration point matches actual code/schema
- [ ] **Labels Clear**: Box labels, arrow labels, and subgraph titles are unambiguous
- [ ] **Colors Consistent**: Blue = new, yellow = reused, gray = untouched (where applicable)
- [ ] **Scope Clear**: Diagram title/header explains what system or flow is shown
- [ ] **References Updated**: If diagram shows a component or table, [../implementation_report.md](../implementation_report.md) or [../database-migration.sql](../database-migration.sql) should confirm it exists
- [ ] **Version/Date Updated**: Update header comment with latest modification date

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Diagram renders blank | Check Mermaid syntax (copy/paste into mermaid.live to debug) |
| Components are in wrong position | Adjust flowchart direction (TB=top-to-bottom, LR=left-to-right) or reorder subgraphs |
| Relationships are backwards | Swap arrow direction (A --> B) or change FK notation (||--o{ vs }o--||) |
| Color doesn't show | Ensure `classDef` name matches the `class` assignment; reload GitHub page |
| References to deleted tables/endpoints | Remove from diagram; do not leave stale references |
| Inconsistent terminology | Use exact names from implementation_report.md (e.g., `trs_simulation_suites` not `suites_table`) |

---

## Linking from Other Documents

When referencing a diagram from another plan document:

```markdown
See [diagrams/architecture.md](diagrams/architecture.md) for component overview.
```

When linking from outside the plan directory:

```markdown
See [plan/diagrams/erd.md](plan/diagrams/erd.md) for data schema.
```

---

## Tool Support

| Tool | Support |
|------|---------|
| GitHub Web UI | ✓ Native Mermaid rendering (no external tool needed) |
| GitHub Desktop / Git CLI | ✓ Renders when viewed on github.com |
| VS Code (with Mermaid plugin) | ✓ Preview `.md` files with Markdown Preview Mermaid Support extension |
| Markdown Editors (Typora, etc.) | ✓ Usually supported; some require plugin |
| mermaid.live | ✓ Online editor for testing/debugging |
| PlantUML / Lucidchart | ✗ Not compatible; Mermaid is GitHub-native standard |

---

## Version History

| File | Version | Date | Changes |
|------|---------|------|---------|
| erd.md | 1.0 | 2026-05-24 | Initial schema after §3.2 edits (dropped `trs_suite_txtp_configs`, `trs_suite_context_sim_payloads`) |
| architecture.md | 1.0 | 2026-05-24 | High-level system topology; clarified connection-studio is frozen |
| dfd.md | 1.0 | 2026-05-24 | Two-view data flow (wizard authoring + run execution); reflects fire-and-forget dispatch pattern |

---

## Questions?

- **Diagram not rendering?** Test on [mermaid.live](https://mermaid.live) and check syntax.
- **Diagram outdated?** Cross-check with [../implementation_report.md](../implementation_report.md); update version and date.
- **Need a new diagram?** Propose it in a GitHub issue; follow the format of existing diagrams.

---

**Last Reviewed**: 2026-05-24  
**All Diagrams Render**: ✓ YES  
**Aligned with Implementation Report**: ✓ YES
