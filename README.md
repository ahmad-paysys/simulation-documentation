# Simulation Studio — Implementation Planning & Documentation

Complete planning documentation, architectural diagrams, database schema, and development workflow for the commercial Simulation Studio initiative (Single-Rule Simulation, Release 4).

## What's In This Repository

All materials needed to understand, architect, and execute the Simulation Studio implementation across two codebases:
- `rule-studio/backend` (NestJS) — Simulation Studio service module
- `rule-studio/frontend` (React + Vite) — UI and wizard
- `admin-service` (Fastify) — Persistence layer

## Quick Navigation

| Document | Purpose | Read Time |
|----------|---------|-----------|
| [plan/summary-of-report.md](plan/summary-of-report.md) | 75-line executive summary | 5 min |
| [plan/implementation_report.md](plan/implementation_report.md) | Authoritative technical decisions | 20 min |
| [plan/branch-plan.md](plan/branch-plan.md) | Git workflow & team collaboration | 15 min |
| [plan/database-migration.sql](plan/database-migration.sql) | PostgreSQL schema (16 tables) | Reference |
| [plan/trs_simulation_gantt.md](plan/trs_simulation_gantt.md) | 8-day timeline with milestones | Visual |
| [plan/User-Stories-20260520-EOD.md](plan/User-Stories-20260520-EOD.md) | 16 user stories + acceptance criteria | Reference |

## Architecture Diagrams

All diagrams use Mermaid syntax (GitHub-native rendering). See [plan/diagrams/README.md](plan/diagrams/README.md) for detailed guide.

- **[ERD](plan/diagrams/erd.md)** — 16-table database schema with relationships
- **[Architecture](plan/diagrams/architecture.md)** — System topology (components, trust boundaries, flows)
- **[Data Flow Diagram](plan/diagrams/dfd.md)** — Two views: wizard authoring + run execution

## For Developers

**Starting a feature?**
1. Read [plan/summary-of-report.md](plan/summary-of-report.md) (where does code live?)
2. Find your user story in [plan/User-Stories-20260520-EOD.md](plan/User-Stories-20260520-EOD.md)
3. Check [plan/implementation_report.md](plan/implementation_report.md) §4–7 for API contracts
4. Follow [plan/branch-plan.md](plan/branch-plan.md) for PR workflow

**Questions?** See [plan/README.md](plan/README.md) for role-based quick-start paths.

## For Tech Leads

- **Architecture decisions**: [plan/implementation_report.md](plan/implementation_report.md) §1–2
- **Database schema**: [plan/database-migration.sql](plan/database-migration.sql) + [plan/diagrams/erd.md](plan/diagrams/erd.md)
- **Code locations**: [plan/summary-of-report.md](plan/summary-of-report.md) "Where the code lives"
- **Git workflow**: [plan/branch-plan.md](plan/branch-plan.md)
- **QA gates**: [plan/branch-plan.md](plan/branch-plan.md) "Module Integration & QA"

## For Stakeholders

- **When will this be done?** → [plan/trs_simulation_gantt.md](plan/trs_simulation_gantt.md)
- **What's the scope?** → [plan/User-Stories-20260520-EOD.md](plan/User-Stories-20260520-EOD.md)
- **What's the 30-second version?** → [plan/summary-of-report.md](plan/summary-of-report.md)
- **What's open/blocked?** → [plan/summary-of-report.md](plan/summary-of-report.md) "Still open"

## Key Facts

**Scope**: Single-Rule Simulation only. Integration Testing deferred.

**Timeline**: 8 working days (21 May — 4 June 2026) with 3 developers.

**Repositories**: Two codebases, one feature branch per repo.
- Feature branch: `feat-paysys-simulation-studio` (in both rule-studio and admin-service)
- Dev branch: `dev` (protected; PRs only)
- Main branch: `main` (production releases)

**Database**: New PostgreSQL `simulation_studio` DB with 16 tables (suites, generations, contexts, triggers, enrichment, runs, results).

**New Components**: 
- Backend: SimulationStudioModule (rule-studio), simulation-studio.logic.service.ts (admin-service)
- Frontend: SimulationStudio pages, simulationStudioApi RTK slice
- Diagrams: ERD, architecture, data flow

**Reused (not duplicated)**:
- TazamaAuthGuard, AdminServiceClient, AJV (parsing), StatusCard, Table, DropDown, etc.

**Connection-studio**: Frozen for this initiative (read-only only, no new files).

## Architecture Highlights

```
Browser (React)
    ↓ (Bearer JWT)
rule-studio/backend (NestJS) — NEW: SimulationStudioModule
    ↓ (JWT forwarded)
admin-service (Fastify) — NEW: simulation-studio.logic.service.ts
    ↓
PostgreSQL (NEW: simulation_studio database)

+ Docker orchestration for run execution
+ Docker Hub for rule-processor images
+ Keycloak for identity
```

See [plan/diagrams/architecture.md](plan/diagrams/architecture.md) for the full diagram.

## Development Workflow

1. **Per-Developer**: Create task branch off `feat-paysys-simulation-studio`, do work, open PR
2. **Per-Module** (at Gantt milestone): 
   - Pull `dev` into feature branch
   - Run full QA
   - Create PR from feature branch → `dev`
3. **Per-Release**: Merge `dev` → `main`

See [plan/branch-plan.md](plan/branch-plan.md) for detailed workflow, protection rules, and role definitions.

## Database

PostgreSQL `simulation_studio` database with:
- **Suite aggregate**: `trs_simulation_suites`, `trs_suite_generations`
- **Context configs**: `trs_suite_context_txtp_configs`, field strategies, generated messages
- **Trigger configs**: `trs_suite_trigger_txtp_configs`, field overrides, generated messages
- **Enrichment configs**: `trs_suite_enrichment_tables`, field strategies, generated rows
- **Pairing**: `trs_suite_context_sim_pairs` (with inline payloads)
- **Run lifecycle**: `trs_simulation_runs`, events, results, artifacts, context links

Initialize with [plan/database-migration.sql](plan/database-migration.sql) (idempotent, first-time only).

## Document Versions

| Document | Version | Last Updated |
|----------|---------|--------------|
| implementation_report.md | 2.2 | 2026-05-24 |
| summary-of-report.md | 1.0 | 2026-05-24 |
| branch-plan.md | 1.0 | 2026-05-24 |
| database-migration.sql | v2.2 | 2026-05-24 |
| trs_simulation_gantt.md | 2.2 | 2026-05-20 |
| User-Stories-20260520-EOD.md | Release 4 | 2026-05-20 |
| diagrams/* | 1.0 | 2026-05-24 |

## Status

✓ Architecture finalized  
✓ Database schema designed  
✓ API contracts specified  
✓ Development workflow documented  
✓ All diagrams reviewed  
✓ Ready for development  

## Need Help?

- **Architecture questions** → See [plan/implementation_report.md](plan/implementation_report.md)
- **Where to start** → See [plan/summary-of-report.md](plan/summary-of-report.md)
- **How to work** → See [plan/branch-plan.md](plan/branch-plan.md)
- **All document guides** → See [plan/README.md](plan/README.md)
- **Diagram guides** → See [plan/diagrams/README.md](plan/diagrams/README.md)

---

**Last Updated**: 2026-05-24  
**Ready for Development**: YES ✓
