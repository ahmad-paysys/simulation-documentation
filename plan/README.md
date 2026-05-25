# Plan Directory — Simulation Studio Implementation

Welcome to the planning hub for the Simulation Studio initiative. This directory contains all authoritative documentation, schemas, and architectural guidance for the commercial development of Simulation Studio across `rule-studio` and `admin-service`.

**Quick Links:**
- **Start here**: [summary-of-report.md](#summary-of-reportmd) (75 lines, answers key questions)
- **Full details**: [implementation_report.md](#implementation_reportmd)
- **Development setup**: [branch-plan.md](#branch-planmd)
- **Architecture**: [diagrams/](#diagrams)
- **Database**: [database-migration.sql](#database-migrationsql)
- **Work breakdown**: [trs_simulation_gantt.md](#trs_simulation_ganttmd) + [User-Stories](#user-storiesmd)

---

## Documents

### summary-of-report.md
**Purpose**: Quick reference for stakeholders and developers entering the project.  
Distills the 75-line executive summary covering code locations, API surface, database scope, reused patterns, critical path order, resolved decisions, and open questions.  
Read this first if you have 5 minutes; it answers "where does code live?" and "what's new vs. reused?"

### implementation_report.md
**Purpose**: Authoritative single source of truth for all technical decisions, code structure, and migration path.  
Comprehensive 400+ line document covering codebase baseline, architecture decisions, database design with rationale, shared contracts, API specification, key services, and deferred work.  
Read this when you need to understand *why* a decision was made or when implementing a specific module.

### branch-plan.md
**Purpose**: Git workflow strategy and team collaboration guidelines for multi-developer, multi-repository commercial development.  
Detailed strategy document with phase-based workflow (setup, development, integration, QA), protection rules, parallel development across two repos, role assignments, and incident response.  
Share with your team before development starts; reference when opening PRs or making branch decisions.

### database-migration.sql
**Purpose**: PostgreSQL schema initialization script for a blank database.  
First-time setup of all 17 tables covering suite aggregates, generation iterations, context/trigger/enrichment configurations, data payloads, simulation runs, and result tracking.  
Apply to the `simulation_studio` database before any code runs; run only once (not idempotent — use a clean database).

### trs_simulation_gantt.md
**Purpose**: Visual 8-day timeline mapping stories to developer effort and interdependencies.  
Mermaid Gantt chart showing housekeeping stories (HK-01–HK-05), wizard stories (SM-01–SM-05, S1-01–S5-01), and run/result/rerun/transaction stories (SR-01–SR-03, RR-01–RR-02, T-01–T-05), plus critical path dependencies.  
Used during sprint planning and for tracking milestone completion (e.g., "wizard backbone complete by Day 3").

### User-Stories-20260520-EOD.md
**Purpose**: Detailed acceptance criteria and test scenarios for each user story.  
21 functional and non-functional stories covering suite creation, listing, drafting, context generation, run execution, result analysis, and advanced features (clone, quick-rerun, integration testing excluded).  
Each story includes type, user narrative, AC, assumptions, and task breakdown; used for development task assignment and QA sign-off.

### trs_story_implementation_report.original.md
**Purpose**: Legacy reference document from Release 4, Rev 2.2.  
Earlier iteration of implementation guidance; superseded by `implementation_report.md` where they differ.  
Keep for historical record; do not use for new decisions.

---

## Diagrams Directory

All diagrams use Mermaid syntax (GitHub-native rendering) for maximum portability.

### diagrams/erd.md
**Purpose**: Entity-relationship diagram for the PostgreSQL `simulation_studio` database schema.  
Visual representation of 16 tables, their relationships (one-to-many, many-to-many), and key columns (PK, FK, timestamps, status enums).  
Reference when designing queries, joins, or understanding data flow during run execution.

### diagrams/architecture.md
**Purpose**: High-level system architecture showing all components, trust boundaries, and integration points.  
Logical deployment view covering browser (frontend), identity (Keycloak), rule-studio backend (NestJS), admin-service (Fastify), PostgreSQL, Docker engine, and Docker Hub.  
Shows which components are new (blue), reused (yellow), and untouched (gray); essential for onboarding engineers and system design discussions.

### diagrams/dfd.md
**Purpose**: Data flow diagram showing request/response paths and state transitions across the wizard and run execution lifecycle.  
Two views: (1) wizard authoring (draft → generated → saved iteration) and (2) run execution (dispatch → Docker provisioning → transaction loop → results).  
Use when debugging integration issues or understanding how data moves through the system during suite creation or test execution.

---

## How to Use This Directory

### I'm a developer starting on a feature

1. Read [summary-of-report.md](#summary-of-reportmd) (5 min) to know where code lives
2. Read the relevant story in [User-Stories-20260520-EOD.md](#user-storiesmd) (your task breakdown)
3. Consult [implementation_report.md](#implementation_reportmd) §4–7 for API contracts and service interfaces
4. Check [diagrams/architecture.md](#diagramsarchitecturemd) to see how your service fits into the system
5. Follow [branch-plan.md](#branch-planmd) for PR/branch workflow

### I'm a QA engineer writing test cases

1. Study [User-Stories-20260520-EOD.md](#user-storiesmd) to extract acceptance criteria
2. Review [diagrams/dfd.md](#diagramsdfdmd) to understand end-to-end data flow
3. Reference [implementation_report.md](#implementation_reportmd) §4 (API contracts) for request/response shapes
4. Consult [branch-plan.md](#branch-planmd) "Module Integration & QA" section for sign-off checklist

### I'm a tech lead reviewing a PR

1. Check [branch-plan.md](#branch-planmd) "Code review on feature/dev branch" for review checklist
2. Validate PR against [implementation_report.md](#implementation_reportmd) architecture decisions
3. If database changes, verify against [database-migration.sql](#database-migrationsql) schema
4. Use [diagrams/](#diagrams) to confirm integration points match design

### I'm setting up the development environment

1. Apply [database-migration.sql](#database-migrationsql) to the `simulation_studio` database
2. Create `feat-paysys-simulation-studio` branch in both repos per [branch-plan.md](#branch-planmd) Phase 1
3. Set up branch protections per [branch-plan.md](#branch-planmd) Protection Rules section
4. Assign roles (Tech Lead, Module Leads, QA) per [branch-plan.md](#branch-planmd) Role Assignments

### I'm a stakeholder asking "when will this be done?"

1. Check [trs_simulation_gantt.md](#trs_simulation_ganttmd) for 8-day timeline and critical milestones
2. See [branch-plan.md](#branch-planmd) Module Integration & QA for testing gates between milestones
3. Read [summary-of-report.md](#summary-of-reportmd) "Still open" section for external blockers

---

## Document Maintenance

### When to Update

| Document | Update When |
|----------|-------------|
| `summary-of-report.md` | New decision made or assumption changes |
| `implementation_report.md` | Architecture decision finalized or code path changes |
| `branch-plan.md` | Team structure, approval rules, or branching policy changes |
| `database-migration.sql` | (Do not update; use migration files for schema changes after v1) |
| `trs_simulation_gantt.md` | Story scope changes or task dependencies discovered |
| `User-Stories-*.md` | AC refinement during sprint or new story added |
| `diagrams/*.md` | Components added, removed, or integration flow changes |

### Review Checklist Before Merging

Before any change to this directory:
- [ ] Does it align with decisions in `implementation_report.md`?
- [ ] Are diagrams (Mermaid) still accurate and render on GitHub?
- [ ] Are relative links correct (e.g., `[file.md](../file.md)`)?
- [ ] Is terminology consistent with other documents?
- [ ] Has the document been reviewed by at least one person not on the implementation team?

---

## Versioning

| Document | Version | Last Updated |
|----------|---------|--------------|
| implementation_report.md | 2.2 | 2026-05-24 |
| summary-of-report.md | 1.0 | 2026-05-24 |
| branch-plan.md | 1.0 | 2026-05-24 |
| database-migration.sql | v2.2 | 2026-05-24 |
| trs_simulation_gantt.md | 2.2 | 2026-05-20 |
| User-Stories-20260520-EOD.md | Release 4 | 2026-05-20 |
| diagrams/* | 1.0 | 2026-05-24 |

---

## Contacts

**Document Owner**: Tech Lead - Simulation Studio Initiative  
**Questions About**:
- Architecture / decisions → See implementation_report.md §1–2, or ask Tech Lead
- Database / schema → See database-migration.sql + diagrams/erd.md, or ask Database Architect
- Development workflow → See branch-plan.md, or ask Tech Lead
- Stories / acceptance → See User-Stories-*.md, or ask Product Owner
- Diagrams / system flows → See diagrams/*, or ask Solutions Architect

---

## Quick Sanity Checks

✓ All `.md` files render natively on GitHub (Mermaid, tables, links)  
✓ `database-migration.sql` is first-time init only (not idempotent — use a clean database)  
✓ Diagram boxes are color-coded: blue = new, yellow = reused, gray = untouched  
✓ All relative links (`[file](path)`) resolve correctly  
✓ Terminology (suite, generation, run, tenant, txtp, etc.) is consistent across all docs  
✓ User story IDs (SM-01, S1-01, etc.) map to implementation stories in the report  
✓ Branch plan aligns with two-repository (rule-studio + admin-service) structure  

---

**Last Reviewed**: 2026-05-24  
**Ready for Development**: YES ✓
