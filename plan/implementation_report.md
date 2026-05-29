# Simulation Studio — Authoritative Implementation Report
<a id="top"></a>

> **Version:** 4.0 · 2026-05-29
> **Scope:** Single-Rule Simulation, Release 4. Integration Testing is out of scope.
> **Authority:** This document is the single authoritative implementation guide for the Simulation Studio initiative.
> **Cross-references:** [database-migration.sql](database-migration.sql), [trs_simulation_gantt.md](trs_simulation_gantt.md), [User-Stories-20260520-EOD.md](User-Stories-20260520-EOD.md), [diagrams/](diagrams/).

---

## How to Use This Document

Developers should treat the per-story section that matches their assignment as the primary work order: it lists the screen, API, service, and database touchpoints for that story, plus the day-by-day task division aligned to [trs_simulation_gantt.md](trs_simulation_gantt.md). Tech leads should use the architecture summary, the story index, and the cross-reference table at the bottom for review prioritisation. Stakeholders can use the overview blocks at the top of each story to confirm acceptance criteria coverage without reading the implementation detail.

## 1. Architecture at a Glance

All new Simulation Studio code lives in three repositories: the NestJS service module at `rule-studio/backend/src/services/simulation-studio/`, the React pages at `rule-studio/frontend/src/pages/SimulationStudio/` with a dedicated `simulationStudioApi` RTK Query slice, and the persistence layer in `admin-service/` (Fastify) with a new `simulation-studio.logic.service.ts` and a `repositories/simulation/` directory. `connection-studio/` is frozen for this initiative — zero new files. Persistence targets a new PostgreSQL database `simulation_studio` with 17 tables created by [database-migration.sql](database-migration.sql) as a first-time initialisation on a clean database. Run execution is orchestrated programmatically through Dockerode against a local or remote Docker Engine, with rule processor images pulled from Docker Hub and pinned to SHA256 digests. Identity is provided by Keycloak with Tazama claims (`editor`, `approver`). See [diagrams/architecture.md](diagrams/architecture.md) for the full component diagram, [diagrams/erd.md](diagrams/erd.md) for the schema, and [diagrams/dfd.md](diagrams/dfd.md) for the wizard and run data flows.

---

## 2. Codebase Baseline (Validated)

| Concern | Reality on disk | Notes |
|---|---|---|
| **Backend host for ALL new Simulation Studio code** | [rule-studio/backend/](../rule-studio/backend/) (NestJS) | Top-level module path: `rule-studio/backend/src/services/simulation-studio/`. Matches existing pattern (`services/simulation/`, `services/rules/`, etc. — see [app.module.ts](../rule-studio/backend/src/app.module.ts)). |
| **`connection-studio/`** | Frozen for this initiative | No new files. Only **read-only** consumer of any of its existing HTTP endpoints if required. |
| **Frontend** | [rule-studio/frontend/](../rule-studio/frontend/) (Vite + React + RTK Query) | New pages under `pages/SimulationStudio/`. |
| **Admin Service** | [admin-service/](../admin-service/) (Fastify) | Owns all Postgres persistence. Repository pattern: free functions in `repositories/*.repository.ts`, called from `services/*.logic.service.ts`, handlers in `app.controller.ts`, routes in `router.ts`. New work follows this exact layout. |
| **Auth** | `TazamaAuthGuard` + `RequireAnyClaims(...)` ([rule-studio/backend/src/guards/tazama-auth.guard.ts](../rule-studio/backend/src/guards/tazama-auth.guard.ts), [decorators/auth.decorator.ts](../rule-studio/backend/src/decorators/auth.decorator.ts)) | `AuthenticatedUser` exposes `tenantId`, `userId`, `actorEmail`, `token.tokenString`. |
| **Admin client** | [rule-studio/backend/src/services/admin-service-client.ts](../rule-studio/backend/src/services/admin-service-client.ts) | All RS Backend → Admin calls go through this. Token forwarded. Already has `getTransactionTypes`, `getPayloadByTransactionType`, `getVersionsOfTransactionType`. |
| **Existing TXTP endpoints in admin-service** | `/v1/admin/config/transaction-types`, `/v1/admin/config/payload/:txtp/:ver`, `/v1/admin/config/:txtp/:ver` | Confirmed in [admin-service/src/router.ts](../admin-service/src/router.ts) lines 257–267. Pass-through only — no new admin TXTP routes. |
| **`tcs_config` filter** | Column is `status`. `findAllTransactionTypes` filters `status IN ('STATUS_04_APPROVED','STATUS_06_EXPORTED')`. | Plan's "`activated`" column does not exist. |
| **`id` convention** | Existing TRS tables use `serial4` PK ([rule-studio/database/init/01-create-tables.sql](../rule-studio/database/init/01-create-tables.sql)). | Migration uses `BIGSERIAL`. Keep `BIGSERIAL` for sim tables (volume) — TS contracts treat as `number`. |
| **No legacy simulation suites in DB** | No `trs_simulation_*` tables exist. | Migration is **net-new**. |
| **AJV** | Already in `rule-studio/backend` ([services/parse-extract/parse-extract.service.ts](../rule-studio/backend/src/services/parse-extract/parse-extract.service.ts)) and in `package.json`. | `ContextGenerationService` AJV cache lives here. Admin-service has no AJV. |
| **Dockerode** | **Not** in `rule-studio/backend/package.json` | Must be added as a dependency for T-02. |
| **No websocket** | No NestJS gateway carries sim events. | All run-progress UX is polling. |
| **Frontend env** | [rule-studio/frontend/.env.example](../rule-studio/frontend/.env.example) already has `VITE_SANDBOX_API_URL` | Add `VITE_SIMULATION_STUDIO_API_URL`. The new RTK slice uses this. |

---

## 3. Top-Level Architecture Decisions

1. **All new APIs are under `/api/v1/simulation-studio/*` on `rule-studio/backend`.** Legacy `/simulation` and `/rerun-simulation` modules in rule-studio backend stay untouched.
2. **NestJS module path:** `rule-studio/backend/src/services/simulation-studio/` (top-level service module, mirroring `services/simulation/`, `services/rules/`, etc.).
3. **All persistence in admin-service.** RS Backend never queries `simulation_studio` DB directly; it calls admin-service via `AdminServiceClient`. New admin module: `admin-service/src/services/simulation-studio.logic.service.ts` + `admin-service/src/repositories/simulation/*.repository.ts`.
4. **Frontend:** new RTK Query slice `simulationStudioApi` at `rule-studio/frontend/src/redux/Api/SimulationStudio/index.ts`. New env var `VITE_SIMULATION_STUDIO_API_URL`.
5. **Reuse, don't duplicate, components:** `<Stepper />` and `<FieldConfigurator />` are the only new shared components. Reuse `StatusCard`, `Table`, `TableActions`, `DropDown`, `BoxWrapper`, `JsonFormatter`, `Input`, `AccordianSummary`.
6. **Run dispatch is fire-and-forget**; UI polls `runs/:runId/status` every 2 s.
7. **No code in `connection-studio/`.** Period.

---

## 4. Database (PostgreSQL `simulation_studio`)

[database-migration.sql](database-migration.sql) is a **first-time init** (`BEGIN; CREATE TABLE …; COMMIT;`). There are no existing tables to rename or alter.

### 4.1 Resolved Schema Decisions (Locked)

| Decision | Outcome | Rationale (short) |
|---|---|---|
| **`trs_suite_txtp_configs` (generic union table)** | **DROP from migration.** | Role-specific tables (`trs_suite_context_txtp_configs`, `trs_suite_trigger_txtp_configs`) are sufficient and have richer columns. The union table is dead schema — no consumer reads it. Carrying it doubles every TXTP write. See §13.1. |
| **`trs_suite_context_sim_payloads` (child table)** | **DROP from migration.** | `trs_suite_context_sim_pairs` already stores `context_payload_json` and `trigger_payload_json` inline. The child adds a redundant copy with no extra information. See §13.2. |
| **`run_number` concurrency** | **Advisory lock per `(suite_id, generation_id)` inside `saveIterationTransactional` / `quick-rerun`.** | Simpler than `SELECT FOR UPDATE` on a parent row, scoped exactly to the race, and Postgres-native (`pg_advisory_xact_lock`). See §13.3. |
| **Tenant scoping on children** | **Always join through `trs_simulation_suites` and filter `tenant_id = $1`.** Enforced as a SQL-review rule and codified in a single repo helper. | The schema deliberately keeps `tenant_id` only on the root aggregate — denormalising it everywhere would create drift risk. See §13.4. |
| **Docker daemon access** | **Dev: Unix socket (`/var/run/docker.sock`). Prod: remote TCP+TLS via `DOCKER_HOST` + cert paths.** Both are supported by Dockerode using the same env vars; `RegistryService` is unaffected. | Standard Dockerode pattern. The "decision" is just a deployment toggle. See §13.5. |
| **Suite-level `ENV_PROVISIONING`** | **Drop from the SM-02 status filter.** | The suite-level `status` enum is `DRAFT/RUNNING/COMPLETED/FAILED/ARCHIVED`. `ENV_PROVISIONING` is a *run-level* phase. See §13.6. |

### 4.2 Schema Edits Applied

The following edits have **already been applied** to [database-migration.sql](database-migration.sql) and reflect the resolved decisions in §4.1. Verify these are present before running the script; no further surgery is required.

1. **Removed:** the `trs_suite_txtp_configs` block (table + index + comment). A descriptive comment remains in the SQL explaining the omission.
2. **Removed:** the `trs_suite_context_sim_payloads` block (table + index). A descriptive comment remains in the SQL explaining the omission.
3. **Added:** the composite index for SM-02 list query:
   ```sql
   CREATE INDEX idx_sim_suites_tenant_status_updated
     ON public.trs_simulation_suites(tenant_id, status, updated_at DESC);
   ```
4. (Optional / nice-to-have, not in the SQL) Add a 256 KB cap on `metadata` enforced application-side in `PUT /draft`.

Everything else in the migration is sound.

### 4.3 Tables Required (17)

The migration creates 17 tables (after the §4.2 edits are applied — already reflected in the SQL):
- Aggregate: `trs_simulation_suites`, `trs_suite_generations`
- Context: `trs_suite_context_txtp_configs`, `trs_suite_context_field_strategies`, `trs_suite_context_generated_messages`
- Trigger: `trs_suite_trigger_txtp_configs`, `trs_suite_trigger_field_overrides`, `trs_suite_trigger_generated_messages`
- Enrichment: `trs_suite_enrichment_tables`, `trs_suite_enrichment_field_strategies`, `trs_suite_enrichment_generated_rows`
- Pairing: `trs_suite_context_sim_pairs` *(payloads inline)*
- Run lifecycle: `trs_simulation_runs`, `trs_simulation_run_events`, `trs_simulation_run_results`, `trs_simulation_run_result_context_links`, `trs_simulation_run_artifacts`

All primary keys use `BIGSERIAL`. The full DDL with constraints, indexes, comments, and the shared `trs_set_updated_at()` trigger function is in [database-migration.sql](database-migration.sql).

### 4.4 CHECK Constraint Enums

The migration encodes the canonical enums as DB-level `CHECK` constraints. Application code must keep its TypeScript types in lockstep with these.

| Table.column | Constraint values |
|---|---|
| `trs_simulation_suites.status` | `DRAFT`, `RUNNING`, `COMPLETED`, `FAILED`, `ARCHIVED` |
| `trs_suite_generations.status` | `DRAFT`, `READY`, `RUNNING`, `COMPLETED`, `FAILED`, `ARCHIVED` |
| `trs_simulation_runs.status` | `ENV_PROVISIONING`, `RUNNING`, `COMPLETED`, `FAILED`, `TIMED_OUT`, `CANCELLED` |
| `trs_simulation_runs.phase` | `ENV_PROVISIONING`, `NETWORK_CREATE`, `BASE_CONTAINERS_START`, `ODS_INIT`, `APP_CONTAINERS_START`, `TRANSACTION_LOOP`, `CLEANUP`, `COMPLETED`, `FAILED` |
| `trs_simulation_run_results.result_band` | `good`, `neutral`, `bad`, `error` |
| `trs_suite_context_field_strategies.strategy_code` | `keep_sample`, `static`, `range`, `generated`, `null`, `skip` |
| `trs_suite_trigger_field_overrides.override_type` | `static`, `range`, `generated`, `remove`, `null` |
| `trs_suite_enrichment_field_strategies.strategy_code` | `static`, `range`, `generated`, `null`, `copy` |
| `trs_simulation_run_artifacts.artifact_type` | `CONTAINER_LOG`, `ODS_SQL`, `NATS_REQUEST`, `NATS_RESPONSE`, `RULE_PROCESSOR_RAW`, `ERROR_STACK`, `METRICS`, `OTHER` |

### 4.5 Key Indexes

Beyond per-table single-column indexes, the migration creates a composite index that backs the SM-02 list query directly:

```sql
CREATE INDEX idx_sim_suites_tenant_status_updated
  ON public.trs_simulation_suites(tenant_id, status, updated_at DESC);
```

Other notable indexes: `idx_sim_suites_tenant`, `idx_sim_suites_status`, `idx_sim_suites_updated`, `idx_sim_suites_rule`, `idx_sim_suites_primary_txtp`, `idx_sim_suites_tenant_name`; `idx_trs_simulation_runs_suite_generation`, `idx_trs_simulation_runs_status`; `idx_trs_simulation_run_results_run_id`, `idx_trs_simulation_run_results_band`. Unique constraints enforce iteration immutability and run-number monotonicity: `uq_trs_suite_generations_suite_generation (suite_id, generation_number)` and `uq_trs_simulation_runs (suite_id, generation_id, run_number)`.

### 4.6 Migration Execution

```bash
psql "postgresql://.../simulation_studio" -f plan/database-migration.sql
```

The script opens a single transaction, creates 17 tables with their indexes and constraints, defines the `trs_set_updated_at()` trigger function, attaches the trigger to `trs_simulation_suites`, `trs_suite_generations`, and `trs_simulation_runs`, then commits. Because the script is not idempotent, the target database must be empty — no pre-existing `trs_*` objects.

### 4.7 Deferred (Do Not Deploy This Release)

`trs_suite_dems_function_records`, `trs_integration_run_results`, `trs_integration_evaluations` — Integration Testing scope.

---

## 5. Shared Contracts (Reusable)

Define once in `rule-studio/backend/src/services/simulation-studio/dto/` and re-import; never duplicate.

```ts
// dto/common.dto.ts
export type SuiteStatus    = 'DRAFT' | 'RUNNING' | 'COMPLETED' | 'FAILED' | 'ARCHIVED';
export type RunStatus      = 'ENV_PROVISIONING' | 'RUNNING' | 'COMPLETED' | 'FAILED' | 'TIMED_OUT' | 'CANCELLED';
export type RunPhase       = 'ENV_PROVISIONING' | 'NETWORK_CREATE' | 'BASE_CONTAINERS_START'
                           | 'ODS_INIT' | 'APP_CONTAINERS_START' | 'TRANSACTION_LOOP' | 'CLEANUP'
                           | 'COMPLETED' | 'FAILED';
export type ResultBand           = 'good' | 'neutral' | 'bad' | 'error';
// Three role-specific code sets — DO NOT merge; the DB CHECK constraints differ.
export type ContextFieldStrategy    = 'keep_sample' | 'static' | 'range' | 'generated' | 'null' | 'skip';
export type TriggerFieldOverride    = 'static' | 'range' | 'generated' | 'remove' | 'null';
export type EnrichmentFieldStrategy = 'static' | 'range' | 'generated' | 'null' | 'copy';

// dto/suite.dto.ts
export class CreateSuiteDto {
  @IsString() @MaxLength(120) name!: string;
  @IsOptional() @IsString() @MaxLength(500) description?: string;
  @IsString() rule_repo!: string;
  @IsString() rule_name!: string;
  @IsString() rule_version!: string;
  @IsString() primary_txtp!: string;
  @IsString() primary_txtp_version!: string;
  @IsOptional() @IsInt() clone_source_suite_id?: number;
}

export class UpdateDraftDto {
  @IsInt() @Min(1) @Max(5) screen!: 1|2|3|4|5;
  @IsObject() data!: Record<string, unknown>;
}

export interface SuiteListItemDto {
  id: number;
  name: string;
  rule_name: string;
  primary_txtp: string;
  status: SuiteStatus;
  iteration_count: number;
  last_run_at: string | null;
  updated_at: string;
  created_by: string;
  wizard_progress: Record<string, boolean>;
}

export interface RunStatusDto {
  status: RunStatus;
  phase: RunPhase;
  error_message?: string;
  partialResults?: ResultRowDto[];
}

export interface ResultRowDto {
  transaction_order: number;
  trigger_message_external_id: string | null;
  trigger_txtp: string | null;
  independent_variable: number | null;
  result_band: ResultBand;
  expected_independent_variable: number | null;
  expected_result_band: ResultBand | null;
  notes: string | null;
}

// Reuse PaginatedResult<T> from @tazama-lf/tcs-lib — already imported by AdminServiceClient.
```

### Endpoint matrix (canonical)

All on `rule-studio/backend` under `/api/v1/simulation-studio`.

| Method | Path | Story |
|---|---|---|
| POST   | `/suites`                                           | S1-01, SM-05 |
| GET    | `/suites`                                           | SM-02 |
| GET    | `/suites/:id`                                       | SM-01, SM-03, SM-04, SM-05 |
| PUT    | `/suites/:id/draft`                                 | HK-04 |
| POST   | `/suites/:id/generate/context`                      | SM-01 / S2-01 |
| POST   | `/suites/:id/run`                                   | T-01 |
| GET    | `/suites/:id/runs`                                  | SR-02, SR-03, SM-03 |
| GET    | `/suites/:id/runs/:runId/status`                    | SR-01, T-03 |
| GET    | `/suites/:id/runs/:runId/results`                   | SR-01, SR-02 |
| GET    | `/suites/:id/runs/summary`                          | SR-02 (stat cards) |
| POST   | `/suites/:id/generations/:gid/quick-rerun`          | RR-01, RR-02 |
| POST   | `/suites/:id/clone-results`                         | SM-05 |
| GET    | `/registry/repos`                                   | S1-01 |
| GET    | `/registry/repos/:repo/tags`                        | S1-01 |
| GET    | `/txtp-types`                                       | S1-01, S2-01 |
| GET    | `/txtp-types/:txtp/:version/schema`                 | S2-01 |
| GET    | `/txtp-types/:txtp/:version/sample`                 | S2-01, S3-01 |

Auth applied at controller level: `@UseGuards(TazamaAuthGuard)` + `@RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.APPROVER)`.
Standard errors: 400 / 401 / 403 / 404 / 409 / 422 / 500.

---

## 6. Working Day Calendar

| Day | Date |
|-----|------|
| 1 | 21 May 2026 (Thu) |
| 2 | 22 May 2026 (Fri) |
| 3 | 25 May 2026 (Mon) |
| 4 | 29 May 2026 (Thu) |
| 5 | 01 Jun 2026 (Mon) |
| 6 | 02 Jun 2026 (Tue) |
| 7 | 03 Jun 2026 (Wed) |
| 8 | 04 Jun 2026 (Thu) |

## 7. Story Index by Date

### By Start Date

| Start Date | Stories |
|------------|---------|
| 21 May | [HK-03 — Frontend Project Scaffolding](#hk-03--frontend-project-scaffolding)<br>[HK-02 — RS Backend NestJS Module Scaffolding](#hk-02--rs-backend-nestjs-module-scaffolding)<br>[HK-05 — Docker Hub Authentication](#hk-05--docker-hub-authentication)<br>[HK-01 — Database Schema Migration](#hk-01--database-schema-migration)<br>[HK-04 — Per-Screen Draft Persistence Infrastructure](#hk-04--per-screen-draft-persistence-infrastructure)<br>[SM-01 — Create a New Simulation Suite via Simulation Studio](#sm-01--create-a-new-simulation-suite-via-simulation-studio)<br>[SM-02 — View All Simulation Suites in a Searchable List](#sm-02--view-all-simulation-suites-in-a-searchable-list)<br>[S1-01 — Select a Rule and Transaction Version for the Suite](#s1-01--select-a-rule-and-transaction-version-for-the-suite)<br>[T-01 — Atomically Persist Wizard Data and Dispatch Orchestrator on Run](#t-01--atomically-persist-wizard-data-and-dispatch-orchestrator-on-run) |
| 22 May | [S1-02 — Define Suite Metadata](#s1-02--define-suite-metadata)<br>[S2-01 — Configure Context Data](#s2-01--configure-context-data) |
| 25 May | [S3-01 — Configure and Preview Simulation Trigger Transactions](#s3-01--configure-and-preview-simulation-trigger-transactions) |
| 29 May | [S4-01 — Define One or More Enrichment Tables](#s4-01--define-one-or-more-enrichment-tables)<br>[S5-01 — Review the Full Suite Summary Before Saving](#s5-01--review-the-full-suite-summary-before-saving) |
| 01 Jun | [SR-01 — Run a Simulation and Observe Results Upon Completion](#sr-01--run-a-simulation-and-observe-results-upon-completion)<br>[T-02 — Orchestrate an Isolated Docker Container Lifecycle Per Run](#t-02--orchestrate-an-isolated-docker-container-lifecycle-per-run) |
| 02 Jun | [T-03 — Persist One Result Row Per Sim Transaction](#t-03--persist-one-result-row-per-sim-transaction)<br>[SM-03 — View Suite Details and Iteration History](#sm-03--view-suite-details-and-iteration-history)<br>[SM-04 — Run a New Iteration in an Existing Suite](#sm-04--run-a-new-iteration-in-an-existing-suite) |
| 03 Jun | [SR-02 — View Simulation Results with Band-Coded Outcome Per Transaction](#sr-02--view-simulation-results-with-band-coded-outcome-per-transaction)<br>[SR-03 — Search and Filter Simulation History](#sr-03--search-and-filter-simulation-history)<br>[T-04 — Handle Container Startup Failures and Run Timeouts Gracefully](#t-04--handle-container-startup-failures-and-run-timeouts-gracefully) |
| 04 Jun | [SM-05 — Clone an Existing Suite](#sm-05--clone-an-existing-suite)<br>[RR-01 — Rerun a Past Iteration from Simulation Result Page](#rr-01--rerun-a-past-iteration-from-simulation-result-page)<br>[RR-02 — Rerun a Past Iteration from Simulation Suite History](#rr-02--rerun-a-past-iteration-from-simulation-suite-history) |

### By End Date

| End Date | Stories |
|----------|---------|
| 21 May | [HK-03 — Frontend Project Scaffolding](#hk-03--frontend-project-scaffolding)<br>[HK-02 — RS Backend NestJS Module Scaffolding](#hk-02--rs-backend-nestjs-module-scaffolding)<br>[HK-05 — Docker Hub Authentication](#hk-05--docker-hub-authentication)<br>[HK-01 — Database Schema Migration](#hk-01--database-schema-migration) |
| 22 May | [HK-04 — Per-Screen Draft Persistence Infrastructure](#hk-04--per-screen-draft-persistence-infrastructure)<br>[S1-01 — Select a Rule and Transaction Version for the Suite](#s1-01--select-a-rule-and-transaction-version-for-the-suite)<br>[S1-02 — Define Suite Metadata](#s1-02--define-suite-metadata)<br>[S2-01 — Configure Context Data](#s2-01--configure-context-data) |
| 25 May | [S3-01 — Configure and Preview Simulation Trigger Transactions](#s3-01--configure-and-preview-simulation-trigger-transactions) |
| 29 May | [SM-01 — Create a New Simulation Suite via Simulation Studio](#sm-01--create-a-new-simulation-suite-via-simulation-studio)<br>[S4-01 — Define One or More Enrichment Tables](#s4-01--define-one-or-more-enrichment-tables)<br>[S5-01 — Review the Full Suite Summary Before Saving](#s5-01--review-the-full-suite-summary-before-saving) |
| 01 Jun | [SM-02 — View All Simulation Suites in a Searchable List](#sm-02--view-all-simulation-suites-in-a-searchable-list)<br>[T-01 — Atomically Persist Wizard Data and Dispatch Orchestrator on Run](#t-01--atomically-persist-wizard-data-and-dispatch-orchestrator-on-run) |
| 02 Jun | [T-03 — Persist One Result Row Per Sim Transaction](#t-03--persist-one-result-row-per-sim-transaction)<br>[SM-03 — View Suite Details and Iteration History](#sm-03--view-suite-details-and-iteration-history)<br>[SM-04 — Run a New Iteration in an Existing Suite](#sm-04--run-a-new-iteration-in-an-existing-suite) |
| 03 Jun | [SR-01 — Run a Simulation and Observe Results Upon Completion](#sr-01--run-a-simulation-and-observe-results-upon-completion)<br>[SR-02 — View Simulation Results with Band-Coded Outcome Per Transaction](#sr-02--view-simulation-results-with-band-coded-outcome-per-transaction)<br>[SR-03 — Search and Filter Simulation History](#sr-03--search-and-filter-simulation-history) |
| 04 Jun | [T-02 — Orchestrate an Isolated Docker Container Lifecycle Per Run](#t-02--orchestrate-an-isolated-docker-container-lifecycle-per-run)<br>[T-04 — Handle Container Startup Failures and Run Timeouts Gracefully](#t-04--handle-container-startup-failures-and-run-timeouts-gracefully)<br>[SM-05 — Clone an Existing Suite](#sm-05--clone-an-existing-suite)<br>[RR-01 — Rerun a Past Iteration from Simulation Result Page](#rr-01--rerun-a-past-iteration-from-simulation-result-page)<br>[RR-02 — Rerun a Past Iteration from Simulation Suite History](#rr-02--rerun-a-past-iteration-from-simulation-suite-history) |

### Out-of-scope

| Story | Note |
|-------|------|
| [T-05 — Push Rule Processor Image to Registry on Deployment](#t-05--push-rule-processor-image-to-registry-on-deployment) | Out of scope for this release. No scheduled start/end date. Consumed by — not produced by — code in this plan. |

---

## 8. Cross-Cutting Implementation Order

Critical path before any story work:

1. **HK-01** — Apply [database-migration.sql](database-migration.sql) to a `simulation_studio` database (see §4).
2. **HK-02** — Backend `simulation-studio` module skeleton at `rule-studio/backend/src/services/simulation-studio/`. Register in `AppModule.imports`. Stub handlers throw `NotImplementedException`.
3. **HK-03** — Frontend scaffolding: routes, RTK slice, `<Stepper />`, `<FieldConfigurator />`, list/wizard skeletons. Extend `StatusCard` `getStatusStyles` with a `DRAFT` case.
4. **HK-04** — `PUT /suites/:id/draft` endpoint + admin handler (`jsonb_set` UPDATE).
5. **HK-05** — Docker Hub auth env vars + `RegistryService`.

Story work (SM-01 … SR-03, T-01 … T-04, RR-01/RR-02, SM-05) then proceeds per the schedule in §9.

---

## 9. Per-Story Implementation

## HK-03 — Frontend Project Scaffolding
[Back to Top](#top)

**Day:** 1 (21 May) · **Owner:** Dev A

### Overview

HK-03 lays the frontend foundation: route entries under `/simulation-studio`, the page directory, the wizard shell, the two new shared components (`<Stepper />`, `<FieldConfigurator />`), the RTK Query slice (`simulationStudioApi`), the additive `DRAFT` style for `<StatusCard />`, and the list-page skeleton. Both SM-01 and SM-02 depend on routing and shared component availability from the moment their Day 1 tasks start, so this scaffolding must land on Day 1 in parallel with backend housekeeping.

### Route Configuration

Six entries are added to [rule-studio/frontend/src/routes/index.tsx](../rule-studio/frontend/src/routes/index.tsx):

```
/simulation-studio                       → <SimulationStudioList />
/simulation-studio/create                → <SimulationStudioWizard />   (mode=create)
/simulation-studio/edit/:id              → <SimulationStudioWizard />   (mode=edit, new iteration / resume draft)
/simulation-studio/clone/:id             → <SimulationStudioWizard />   (mode=clone)
/simulation-studio/view/:id              → <SimulationStudioView />
/simulation-studio/view/:id/run/:runId   → <SimulationStudioView />     (deep-link to a specific run)
```

All entries use `private: true`, `layout: true`, and `roleGroup: 'trs' as const` to match the existing routing pattern.

### Page Directory Layout

```
rule-studio/frontend/src/pages/SimulationStudio/
├── List/        → <SimulationStudioList />
├── Wizard/      → <SimulationStudioWizard />  (Steps 1–5 + post-stepper Screen 6 child)
└── View/        → <SimulationStudioView />
```

### `<SimulationStudioWizard />` Shell

The wizard shell at `rule-studio/frontend/src/pages/SimulationStudio/Wizard/index.tsx` is the single component used by the create, edit, and clone routes; `mode: 'create' | 'edit' | 'clone'` is derived from the active route. Responsibilities of the shell:

- Screen index state: `currentScreen: 0..4` for the **five** Next/Back steps (Rule + TxTp · Context Data · Trigger Data · Enrichment · Summary). Screen 6 (Results) is rendered post-stepper by a `<Screen6Results />` child mounted after `POST /run` returns a `runId`. It is not part of the stepper count.
- `canProceed` flag per screen — the Next button is disabled until the active screen signals valid via a `validate()` callback exposed by each screen component.
- Back navigation: previous screen, or `/simulation-studio` when on Step 1.
- Mode detection from route params (`/create` vs `/edit/:id` vs `/clone/:id`).
- Renders the `<Stepper />` with the five labelled steps.

### `<Stepper />` Component

A new horizontal step indicator at `rule-studio/frontend/src/components/Stepper/index.tsx`. Receives `currentStep: number` and `steps: string[]` as props. The current step is highlighted and completed steps show a check mark. Purely presentational.

### Navigation Guard

`useBlocker` from React Router v7 (already a dependency in [rule-studio/frontend/package.json](../rule-studio/frontend/package.json)) is configured inside `<SimulationStudioWizard />` to intercept navigation away from the wizard when the current screen has uncommitted edits. `window.beforeunload` handles browser-tab close. These guards protect only the current screen's uncommitted changes — all previously completed screens are safe in `metadata.wizardDraft` server-side via HK-04.

### RTK Query API Slice

A new slice `simulationStudioApi` is created at `rule-studio/frontend/src/redux/Api/SimulationStudio/index.ts` and registered in `rule-studio/frontend/src/redux/Store/index.ts`. The legacy `simulationApi` at `rule-studio/frontend/src/redux/Api/Simulation/index.ts` is not modified.

```ts
export const simulationStudioApi = createApi({
  reducerPath: 'simulationStudioApi',
  baseQuery: fetchBaseQuery({
    baseUrl: import.meta.env.VITE_SIMULATION_STUDIO_API_URL as string,
    prepareHeaders: (headers) => {
      const token = getAuthToken();
      if (token) headers.set('authorization', `Bearer ${token}`);
      return headers;
    },
  }),
  tagTypes: ['Suite', 'SuiteList', 'Run', 'RunStatus', 'RunResults',
             'RegistryRepos', 'RegistryTags', 'TxtpTypes'],
  endpoints: (builder) => ({ /* added per-story */ }),
});
```

Day 1 also adds `VITE_SIMULATION_STUDIO_API_URL=` to [rule-studio/frontend/.env.example](../rule-studio/frontend/.env.example).

Cache invalidation rules:
- `POST /suites` invalidates `SuiteList`.
- `PUT /suites/:id/draft` invalidates `Suite` for that id.
- `POST /suites/:id/run` invalidates `Suite`, `SuiteList`, and `Run` lists.
- `POST /suites/:id/generations/:gid/quick-rerun` invalidates `Run` lists for that suite.

### `<FieldConfigurator />` Shared Component

Used by Step 2 (S2-01 Context Data) and Step 4 (S4-01 Enrichment). Built as a shared component at `rule-studio/frontend/src/components/FieldConfigurator/index.tsx`. It accepts a JSON schema and renders per-field rows, where each row shows the field name (left) and a strategy selector (right). The strategy options surface the `ContextFieldStrategy` enum on Step 2 and the `EnrichmentFieldStrategy` enum on Step 4, with the appropriate sub-options revealed per selection (numeric range, static value, generator type, etc.).

### `<StatusCard />` Reuse

The existing `<StatusCard />` at [rule-studio/frontend/src/components/Cards/StatusCard/index.tsx](../rule-studio/frontend/src/components/Cards/StatusCard/index.tsx) is reused directly. Its style map at [rule-studio/frontend/src/components/Cards/StatusCard/Status.styles.ts](../rule-studio/frontend/src/components/Cards/StatusCard/Status.styles.ts) already covers `RUNNING`, `COMPLETED`, `FAILED`. Day 1 adds a `DRAFT` case to `getStatusStyles`. No new badge component is created.

### `<SimulationStudioList />` Skeleton

A bare page shell at `rule-studio/frontend/src/pages/SimulationStudio/List/index.tsx`: `<BoxWrapper />`, page title "Simulation Studio", subtitle, "Create Simulation Suite" CTA wired to `/simulation-studio/create`, `<SuspenseLoader />` initial state, empty state, and a `<Table />` placeholder. The full controller — search, filter dropdowns, columns per SM-02 — is built on Day 5 inside SM-02. The skeleton must exist on Day 1 so routing tests do not break.

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 1 | All HK-03 deliverables: routes, page directory, wizard shell skeleton, `<Stepper />`, `<FieldConfigurator />`, `simulationStudioApi` slice + store registration, `VITE_SIMULATION_STUDIO_API_URL` env, `<StatusCard />` DRAFT case, `<SimulationStudioList />` skeleton page. |

---

## HK-02 — RS Backend NestJS Module Scaffolding
[Back to Top](#top)

**Day:** 1 (21 May) · **Owner:** Dev C

### Overview

HK-02 stands up the `SimulationStudioModule` so Nest's DI graph can resolve every provider needed by later stories. All controller methods are bound on Day 1 and stub with `throw new NotImplementedException()`; per-story work fills them in. The module registers as a top-level service module under `rule-studio/backend/src/services/simulation-studio/`, mirroring the convention used by `services/simulation/`, `services/rules/`, and other existing service folders.

### Directory and File Structure

```
rule-studio/backend/src/services/simulation-studio/
├── simulation-studio.module.ts          ← registers providers, controllers, imports
├── simulation-studio.controller.ts      ← all /api/v1/simulation-studio/* routes
├── simulation-studio.service.ts         ← orchestrates downstream service calls
├── registry/
│   └── registry.service.ts              ← Docker Hub API client + token cache (HK-05)
├── orchestrator/
│   ├── orchestrator.service.ts          ← Docker Engine lifecycle via dockerode
│   ├── single-rule-env.builder.ts       ← builds SingleRuleEnvSpec from suite + generation
│   ├── ods-init.service.ts              ← SQL render + execute against ephemeral ODS
│   ├── transaction-loop.service.ts      ← sequential sim pair submission
│   └── env-registry.service.ts          ← concurrency pool tracking
├── context/
│   └── context-generation.service.ts    ← AJV schema cache + payload generation
└── dto/
    ├── index.ts
    ├── common.dto.ts                    ← shared enum types
    ├── suite.dto.ts                     ← CreateSuiteDto, UpdateDraftDto, SuiteListItemDto
    └── list-suites-query.dto.ts         ← ListSuitesQueryDto for SM-02
```

### Module Definition

```typescript
// simulation-studio.module.ts
import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { SimulationStudioController } from './simulation-studio.controller';
import { SimulationStudioService } from './simulation-studio.service';
import { RegistryService } from './registry/registry.service';
import { OrchestratorService } from './orchestrator/orchestrator.service';
import { SingleRuleEnvBuilder } from './orchestrator/single-rule-env.builder';
import { OdsInitService } from './orchestrator/ods-init.service';
import { TransactionLoopService } from './orchestrator/transaction-loop.service';
import { EnvRegistryService } from './orchestrator/env-registry.service';
import { ContextGenerationService } from './context/context-generation.service';
import { AdminServiceClient } from '../admin-service-client';

@Module({
  imports: [HttpModule],
  controllers: [SimulationStudioController],
  providers: [
    SimulationStudioService,
    RegistryService,
    OrchestratorService,
    SingleRuleEnvBuilder,
    OdsInitService,
    TransactionLoopService,
    EnvRegistryService,
    ContextGenerationService,
    AdminServiceClient,
  ],
  exports: [SimulationStudioService],
})
export class SimulationStudioModule {}
```

### Registration in app.module.ts

`SimulationStudioModule` is added to the `imports` array of the existing `AppModule` at [rule-studio/backend/src/app.module.ts](../rule-studio/backend/src/app.module.ts). No existing imports are removed or reordered.

### Controller Skeleton

All 17 endpoint stubs are bound on Day 1 with `@UseGuards(TazamaAuthGuard)` and `@RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.APPROVER)`. Per-story work replaces each body. The full enumeration:

```typescript
@Controller('api/v1/simulation-studio')
@UseGuards(TazamaAuthGuard)
@RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.APPROVER)
export class SimulationStudioController {
  // 1.  POST   /suites
  // 2.  GET    /suites
  // 3.  GET    /suites/:id
  // 4.  PUT    /suites/:id/draft
  // 5.  POST   /suites/:id/generate/context
  // 6.  POST   /suites/:id/run
  // 7.  GET    /suites/:id/runs
  // 8.  GET    /suites/:id/runs/:runId/status
  // 9.  GET    /suites/:id/runs/:runId/results
  // 10. GET    /suites/:id/runs/summary
  // 11. POST   /suites/:id/generations/:gid/quick-rerun
  // 12. POST   /suites/:id/clone-results
  // 13. GET    /registry/repos
  // 14. GET    /registry/repos/:repo/tags
  // 15. GET    /txtp-types
  // 16. GET    /txtp-types/:txtp/:version/schema
  // 17. GET    /txtp-types/:txtp/:version/sample
}
```

Standard error responses across the controller: `400` (validation), `401` (missing/invalid token), `403` (RBAC fail), `404` (suite/txtp not found or wrong tenant), `409` (state conflict — e.g., suite already running), `422` (business validation), `500` (unexpected).

### DTOs Required Day 1

`rule-studio/backend/src/services/simulation-studio/dto/common.dto.ts` exports the seven enum types:

```typescript
export type SuiteStatus    = 'DRAFT' | 'RUNNING' | 'COMPLETED' | 'FAILED' | 'ARCHIVED';
export type RunStatus      = 'ENV_PROVISIONING' | 'RUNNING' | 'COMPLETED' | 'FAILED' | 'TIMED_OUT' | 'CANCELLED';
export type RunPhase       = 'ENV_PROVISIONING' | 'NETWORK_CREATE' | 'BASE_CONTAINERS_START'
                           | 'ODS_INIT' | 'APP_CONTAINERS_START' | 'TRANSACTION_LOOP' | 'CLEANUP'
                           | 'COMPLETED' | 'FAILED';
export type ResultBand              = 'good' | 'neutral' | 'bad' | 'error';
export type ContextFieldStrategy    = 'keep_sample' | 'static' | 'range' | 'generated' | 'null' | 'skip';
export type TriggerFieldOverride    = 'static' | 'range' | 'generated' | 'remove' | 'null';
export type EnrichmentFieldStrategy = 'static' | 'range' | 'generated' | 'null' | 'copy';
```

`dto/suite.dto.ts`:

```typescript
export class CreateSuiteDto {
  @IsString() @MaxLength(120) name!: string;
  @IsOptional() @IsString() @MaxLength(500) description?: string;
  @IsString() rule_repo!: string;
  @IsString() rule_name!: string;
  @IsString() rule_version!: string;
  @IsString() primary_txtp!: string;
  @IsString() primary_txtp_version!: string;
  @IsOptional() @IsInt() clone_source_suite_id?: number;
}

export class UpdateDraftDto {
  @IsInt() @Min(1) @Max(5) screen!: 1 | 2 | 3 | 4 | 5;
  @IsObject() data!: Record<string, unknown>;
}
```

`PaginatedResult<T>` is imported from `@tazama-lf/tcs-lib` and not redefined.

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 1 | Directory + module + controller + DTO files; AdminServiceClient injection wiring; all 17 routes stubbed; AppModule registration. |

---

## HK-05 — Docker Hub Authentication
[Back to Top](#top)

**Day:** 1 (21 May) · **Owner:** Dev C

### Overview

`RegistryService` at `rule-studio/backend/src/services/simulation-studio/registry/registry.service.ts` must authenticate against Docker Hub before S1-01 can populate its Rule and Version pickers. HK-05 lands the environment variables, the JWT token cache, and the tag-list cache infrastructure.

### Environment Variables

Added to the rule-studio backend env layer (and to `.env.example`):

```
DOCKER_HUB_USER=         # Docker Hub service account username
DOCKER_HUB_TOKEN=        # Docker Hub personal/service access token (read-only scope)
DOCKER_HUB_NAMESPACE=    # Docker Hub org/namespace containing rule-* repos
```

These are consumed via `ConfigService.get<string>(...)`. Marking them optional at module load lets the application boot in environments where Simulation Studio is not exercised; the service throws a clear error on first call if either credential is missing.

### RegistryService — getToken()

```typescript
@Injectable()
export class RegistryService {
  private readonly logger = new Logger(RegistryService.name);
  private cachedToken: string | null = null;
  private tokenExpiry = 0;

  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
  ) {}

  async getToken(): Promise<string> {
    if (this.cachedToken && Date.now() < this.tokenExpiry) {
      return this.cachedToken;
    }
    const user = this.configService.get<string>('DOCKER_HUB_USER');
    const token = this.configService.get<string>('DOCKER_HUB_TOKEN');
    if (!user || !token) {
      throw new Error('DOCKER_HUB_USER and DOCKER_HUB_TOKEN must be configured');
    }
    const { data } = await firstValueFrom(
      this.httpService.post('https://hub.docker.com/v2/users/login', {
        username: user,
        password: token,
      }),
    );
    this.cachedToken = data.token;
    this.tokenExpiry = Date.now() + 50 * 60 * 1000; // 50-min TTL (Docker Hub JWT expires after ~60 min)
    return this.cachedToken!;
  }
}
```

### Tag List Caching

Tag list responses are cached for 5 minutes with `Map<string, { tags: TagDto[]; expiresAt: number }>` keyed by `repo`. If `expiresAt > Date.now()`, the cached value is returned. This is mandatory to respect Docker Hub's 200-pulls-per-6h rate limit. The cache is in-memory on the singleton `RegistryService` instance.

### Open Questions

Three items must be confirmed with the platform team before the Day 1 merge:

1. The Docker Hub namespace that hosts `rule-*` repos.
2. Service account versus personal access token choice (drives rotation policy).
3. Confirmation that read-only scope is sufficient — `RegistryService` only calls list-repos, list-tags, and the manifest endpoint for digest resolution.

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 1 | `RegistryService` skeleton, `getToken()` with 50-min TTL, tag-list Map cache with 5-min TTL, env wiring, `.env.example` update. |

---

## HK-01 — Database Schema Migration
[Back to Top](#top)

**Day:** 1 (21 May) · **Owner:** Dev B

### Overview

HK-01 initialises the new `simulation_studio` PostgreSQL database by running [database-migration.sql](database-migration.sql) on a clean DB. This is a first-time create — there are no existing tables to rename or alter. The script is wrapped in a single `BEGIN; ... COMMIT;` and is not designed to be idempotent; reruns require a fresh schema.

### Tables Created (17)

The script creates exactly 17 tables, grouped by aggregate:

**Aggregate (2):**
- `trs_simulation_suites`
- `trs_suite_generations`

**Context (3):**
- `trs_suite_context_txtp_configs`
- `trs_suite_context_field_strategies`
- `trs_suite_context_generated_messages`

**Trigger (3):**
- `trs_suite_trigger_txtp_configs`
- `trs_suite_trigger_field_overrides`
- `trs_suite_trigger_generated_messages`

**Enrichment (3):**
- `trs_suite_enrichment_tables`
- `trs_suite_enrichment_field_strategies`
- `trs_suite_enrichment_generated_rows`

**Pairing (1):**
- `trs_suite_context_sim_pairs` — payloads stored inline as `context_payload_json` / `trigger_payload_json` (no child payload table).

**Run lifecycle (5):**
- `trs_simulation_runs`
- `trs_simulation_run_events`
- `trs_simulation_run_results`
- `trs_simulation_run_result_context_links`
- `trs_simulation_run_artifacts`

All primary keys use `BIGSERIAL`. The full DDL with constraints, indexes, comments, and the shared `trs_set_updated_at()` trigger function is in [database-migration.sql](database-migration.sql).

### CHECK Constraint Enums

The migration encodes the canonical enums as DB-level `CHECK` constraints. Application code must keep its TypeScript types in lockstep with these.

| Table.column | Constraint values |
|---|---|
| `trs_simulation_suites.status` | `DRAFT`, `RUNNING`, `COMPLETED`, `FAILED`, `ARCHIVED` |
| `trs_suite_generations.status` | `DRAFT`, `READY`, `RUNNING`, `COMPLETED`, `FAILED`, `ARCHIVED` |
| `trs_simulation_runs.status` | `ENV_PROVISIONING`, `RUNNING`, `COMPLETED`, `FAILED`, `TIMED_OUT`, `CANCELLED` |
| `trs_simulation_runs.phase` | `ENV_PROVISIONING`, `NETWORK_CREATE`, `BASE_CONTAINERS_START`, `ODS_INIT`, `APP_CONTAINERS_START`, `TRANSACTION_LOOP`, `CLEANUP`, `COMPLETED`, `FAILED` |
| `trs_simulation_run_results.result_band` | `good`, `neutral`, `bad`, `error` |
| `trs_suite_context_field_strategies.strategy_code` | `keep_sample`, `static`, `range`, `generated`, `null`, `skip` |
| `trs_suite_trigger_field_overrides.override_type` | `static`, `range`, `generated`, `remove`, `null` |
| `trs_suite_enrichment_field_strategies.strategy_code` | `static`, `range`, `generated`, `null`, `copy` |
| `trs_simulation_run_artifacts.artifact_type` | `CONTAINER_LOG`, `ODS_SQL`, `NATS_REQUEST`, `NATS_RESPONSE`, `RULE_PROCESSOR_RAW`, `ERROR_STACK`, `METRICS`, `OTHER` |

### Key Indexes

Beyond per-table single-column indexes, the migration creates a composite index that backs the SM-02 list query directly:

```sql
CREATE INDEX idx_sim_suites_tenant_status_updated
  ON public.trs_simulation_suites(tenant_id, status, updated_at DESC);
```

Other notable indexes: `idx_sim_suites_tenant`, `idx_sim_suites_status`, `idx_sim_suites_updated`, `idx_sim_suites_rule`, `idx_sim_suites_primary_txtp`, `idx_sim_suites_tenant_name`; `idx_trs_simulation_runs_suite_generation`, `idx_trs_simulation_runs_status`; `idx_trs_simulation_run_results_run_id`, `idx_trs_simulation_run_results_band`. Unique constraints enforce iteration immutability and run-number monotonicity: `uq_trs_suite_generations_suite_generation (suite_id, generation_number)` and `uq_trs_simulation_runs (suite_id, generation_id, run_number)`.

### Migration Execution

```bash
psql "postgresql://.../simulation_studio" -f plan/database-migration.sql
```

The script opens a single transaction, creates 17 tables with their indexes and constraints, defines the `trs_set_updated_at()` trigger function, attaches the trigger to `trs_simulation_suites`, `trs_suite_generations`, and `trs_simulation_runs`, then commits. Because the script is not idempotent, the target database must be empty — no pre-existing `trs_*` objects.

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 1 | Provision empty `simulation_studio` DB, apply [database-migration.sql](database-migration.sql), verify all 17 tables and the composite index exist, confirm `\d+ trs_simulation_suites` shows the trigger and CHECK constraints. |

---

## HK-04 — Per-Screen Draft Persistence Infrastructure
[Back to Top](#top)

**Day:** 1–2 (21–22 May) · **Owner:** Dev B (Day 1 endpoint) → Dev A (Day 2 frontend wiring)

### Overview

Every wizard step's Next action persists its screen data server-side before navigation advances. This cross-cutting infrastructure underpins S2-01, S3-01, S4-01, S5-01, and the SM-04 resume flow. HK-04 delivers the `PUT /suites/:id/draft` endpoint, the admin handler that uses `jsonb_set` to merge into `metadata.wizardDraft`, and the frontend wiring that calls it on each Next.

### API

`PUT /api/v1/simulation-studio/suites/:id/draft`:
- Body: `UpdateDraftDto` with `@IsInt() @Min(1) @Max(5) screen!: 1|2|3|4|5` and `@IsObject() data!: Record<string, unknown>`.
- Tenant scoped via `TazamaAuthGuard`.
- The handler caps incoming `data` at 256 KB at the boundary to prevent metadata bloat.
- Returns `200 { wizard_progress: Record<string, boolean> }`.

### Admin Handler

`handleUpdateDraft` in `admin-service/src/services/simulation-studio.logic.service.ts` invokes a single SQL UPDATE through the new `SimulationSuiteRepository`. The update uses `jsonb_set` with `create_missing = true` and is idempotent — submitting the same screen twice overwrites the prior draft for that screen.

```sql
UPDATE trs_simulation_suites
SET
  metadata        = jsonb_set(
                      metadata,
                      ARRAY['wizardDraft', 'screen' || $screen::text],
                      $data::jsonb,
                      true
                    ),
  wizard_progress = jsonb_set(
                      wizard_progress,
                      ARRAY['screen' || $screen::text],
                      'true'::jsonb,
                      true
                    ),
  updated_at      = NOW()
WHERE id = $id AND tenant_id = $tenantId
RETURNING wizard_progress;
```

Tenant scoping is enforced by joining through `trs_simulation_suites.tenant_id` via the shared helper `getSuiteOrThrow(id, tenantId)` before the update.

### Frontend Wiring

The `<SimulationStudioWizard />` Next handler is wrapped so that, on a validated step submission, it calls the draft mutation with `{ screen: currentScreen + 1, data }` and only advances `currentScreen` after a 2xx response. The resume flow on `/simulation-studio/edit/:id` fetches the suite, reads `metadata.wizardDraft`, dispatches per-screen data into wizard state, then reads `wizard_progress` to choose the highest completed screen and open the next one.

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 1 | `PUT /suites/:id/draft` endpoint + `UpdateDraftDto` validation; admin `handleUpdateDraft` + `SimulationSuiteRepository.updateDraft` with the `jsonb_set` SQL; 256 KB cap; router registration. |
| Dev A | Day 2 | Wire the draft call into the wizard's `onNext` handler; build the resume flow that rehydrates per-screen state from `metadata.wizardDraft` and jumps the stepper to the correct position. |

---

## SM-01 — Create a New Simulation Suite via Simulation Studio
[Back to Top](#top)

**Start:** 21 May · **End:** 29 May

### Overview

SM-01 owns the wizard container that hosts S1-01 through S5-01 and the Screen 6 (Results) child. From the user-stories acceptance criteria: clicking Create Simulation Suite from the list opens the wizard at Step 1; completing all mandatory fields and clicking Save Iteration on the summary screen creates the suite and redirects to the suite detail page; navigating back to a previous step retains all previously entered data; Back on Step 1 returns to the list page without creating a suite. SM-01 also owns the context generation call (`POST /suites/:id/generate/context`), which has no story of its own.

### Frontend — `<SimulationStudioWizard />` container

The container at `rule-studio/frontend/src/pages/SimulationStudio/Wizard/index.tsx` is built greenfield and does not touch any legacy simulation pages.

- Screen index management: `currentScreen: 0..4` advances on each validated Next and decrements on Back. Screen 6 (Results) is rendered post-stepper by a `<Screen6Results />` child mounted after `POST /run` returns a `runId`; it is not part of the stepper count.
- Per-screen validation gate: the Next button is disabled until the active screen emits a valid signal via the `validate()` callback contract.
- Mode detection: `mode: 'create' | 'edit' | 'clone'` inferred from route params.
- Resume mode: on load of `/simulation-studio/edit/:id`, the container calls `GET /suites/:id`, hydrates wizard state from `metadata.wizardDraft`, and uses `wizard_progress` to determine the opening step.
- Save as Draft (Step 5): persists the latest draft and returns to `/simulation-studio`.
- Save Iteration (Step 5): `POST /suites/:id/run`, then mount `<Screen6Results />` with the returned `runId`.
- Context generation: after Step 2 validated Next, the wizard calls `POST /suites/:id/generate/context` before transitioning to Step 3. The Preview Data button on Step 2 calls the same endpoint with `count=5` for inline 5-row preview.

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/simulation-studio/suites/:id` | Fetch suite + `metadata.wizardDraft` on resume, edit, or clone load. Returns suite row, `generations[]`, and `metadata`. |
| POST | `/api/v1/simulation-studio/suites/:id/generate/context` | Generate context rows from Step 2 field configs. Body: `GenerateContextDto`. Optional query `count` overrides per-txtp count (`count=5` for preview, omitted for full Next-flow count). Returns `{ rows: Array<{ txtp, version, payload }> }`. Does not persist — caller stores in `wizardDraft` via the draft mutation. |

Error responses follow the controller-wide convention. `422` returns row-level AJV errors in `errors[]` when a generated payload fails schema validation.

### RS Backend — ContextGenerationService (NEW)

Lives at `rule-studio/backend/src/services/simulation-studio/context/context-generation.service.ts`. Owns the schema cache and the generation algorithm. AJV is already a dependency of `rule-studio/backend` (used by `services/parse-extract/`).

```typescript
@Injectable()
export class ContextGenerationService {
  private readonly schemaCache = new Map<string, ValidateFunction>(); // key: `${txtp}:${version}`
  private readonly ajv = new Ajv({ allErrors: true, strict: false });

  constructor(private readonly adminClient: AdminServiceClient) {}

  async generateContext(
    suiteId: number,
    body: GenerateContextDto,
    tenantId: string,
    token: string,
    overrideCount?: number,
  ): Promise<{ rows: ContextRowDto[] }> { /* iterate per txtp, apply ContextFieldStrategy, validate, collect */ }

  private async getValidator(txtp: string, version: string, tenantId: string, token: string): Promise<ValidateFunction> {
    const key = `${txtp}:${version}`;
    const cached = this.schemaCache.get(key);
    if (cached) return cached;
    const { schema } = await this.adminClient.getConfigByTransactionType(txtp, version, tenantId, token);
    const validator = this.ajv.compile(schema);
    this.schemaCache.set(key, validator);
    return validator;
  }
}
```

Schema compilation can take 50–200 ms for complex ISO 20022 schemas. With up to several hundred context rows per TXTP per generation, the cache is required. The cache is process-local; eviction is not required for the expected catalogue size.

### Admin Service

No changes for SM-01 itself. The handler `handleGetConfigByTransactionType(txtp, version, tenantId)` at [admin-service/src/services/tcs-config.logic.service.ts](../admin-service/src/services/tcs-config.logic.service.ts) is reused as the schema and sample source via `AdminServiceClient.getConfigByTransactionType()`.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | `metadata.wizardDraft` updated per-step via `PUT /suites/:id/draft` (HK-04). `wizard_progress` updated. `status` transitions to `RUNNING` on `POST /suites/:id/run` (T-01). |
| `tcs_config` | SELECT only, via `handleGetConfigByTransactionType`. |

No child sim tables are written by SM-01 directly; persistence happens atomically inside T-01.

### Prerequisites

- HK-03 (wizard shell, routing, `<Stepper />`, `<FieldConfigurator />`, `simulationStudioApi`).
- HK-02 (controller + `AdminServiceClient.getConfigByTransactionType`).
- S1-01 (suite must exist — `POST /suites` is called on Step 1 Next so a suite id is available for `PUT /draft` and `POST /generate/context`).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 1 | `<SimulationStudioWizard />` shell at `pages/SimulationStudio/Wizard/index.tsx` — screen index state, Next/Back handlers, `<Stepper />` wiring, validation gate framework, navigation guard (`useBlocker` v7 + `beforeunload`), mode detection, load-from-draft on `/simulation-studio/edit/:id`. |
| Dev A | Day 3 | Wire `POST /suites/:id/generate/context` into the Step 2 → Step 3 transition. Preview Data button: call with `count=5` and render inline 5-row preview. Step 2 Next: call full count, store result in wizard state, then advance. |
| Dev B | Day 3 | `ContextGenerationService` implementation in `rule-studio/backend/src/services/simulation-studio/context/`; AJV cache; `GenerateContextDto` validation; 422 row-level errors. Add `getConfigByTransactionType` to `AdminServiceClient` if absent. |

---

## SM-02 — View All Simulation Suites in a Searchable List
[Back to Top](#top)

**Start:** 21 May · **End:** 01 Jun

### Overview

From the user-stories acceptance criteria: suites are displayed in a table with columns Suite Name, Associated Rule, TXTP, Status, Iterations, Last Updated, Created By, and Actions; the search input filters by Suite Name in real time; a Status dropdown filters by status; a Rule dropdown filters by associated rule. SM-02 builds the `<SimulationStudioList />` page, the `GET /suites` endpoint, and the admin handler that serves a paginated, tenant-scoped query.

### Frontend — `<SimulationStudioList />`

Built greenfield at `rule-studio/frontend/src/pages/SimulationStudio/List/index.tsx`. Follows the existing list-page conventions but does not modify any legacy page.

- Page shell: `<BoxWrapper />`, `<ScienceOutlinedIcon />` page header, title "Simulation Studio", subtitle, "Create Simulation Suite" CTA wired to `/simulation-studio/create`.
- Columns in order: Suite Name (`name`), Associated Rule (`rule_name`), TXTP (`primary_txtp`), Status (`<StatusCard status={row.status} bullet={false} />`), Iterations (`iteration_count`), Last Updated (`updated_at` as `'date'`), Created By (`created_by`), Actions.
- Search: real-time filter by Suite Name through `useFilters({ search_delay: 500 })` from [rule-studio/frontend/src/hooks/useFilters.ts](../rule-studio/frontend/src/hooks/useFilters.ts), which provides `search`, `debouncedSearch`, and `setSearch` with built-in 500 ms debounce. `debouncedSearch` is passed to the RTK Query arg.
- Status filter dropdown: `<DropDown />` with options `[All, DRAFT, RUNNING, COMPLETED, FAILED, ARCHIVED]`. Note that `ENV_PROVISIONING` is a run-level phase, not a suite-level status, so it is intentionally absent from this filter; a suite currently provisioning a run carries `status = 'RUNNING'`.
- Rule filter dropdown: `<DropDown />` populated from `GET /registry/repos`, including an "All" option.
- Reset filters icon (`<FilterAltOffIcon />`) clears search, status, and rule filter.
- Actions per row via the extended `<TableActions />`: View (always), Edit (DRAFT only), Clone (any non-DRAFT suite), and Resume for DRAFT suites with non-empty `wizard_progress`.
- Empty state, `<SuspenseLoader />` on initial load, `<CustomPagination />` via `<Table pagination={...} />`.

### `<TableActions />` Extension

The existing [rule-studio/frontend/src/components/TableActions/index.tsx](../rule-studio/frontend/src/components/TableActions/index.tsx) exposes `onView`, `onEdit`, `onDelete`, `onClone`, `onHold`, `onToggleStatus`. SM-02 adds an optional `onResume?: () => void` prop rendered with a `<PlayCircleOutlineIcon />` when supplied. The change is additive — no existing call sites are affected.

### API

`GET /api/v1/simulation-studio/suites?search=&status=&rule=&page=&limit=` returns `PaginatedResult<SuiteListItemDto>` matching the shape from `@tazama-lf/tcs-lib`:

```ts
interface SuiteListItemDto {
  id: number;
  name: string;
  rule_name: string;
  primary_txtp: string;
  status: SuiteStatus;
  iteration_count: number;
  last_run_at: string | null;
  updated_at: string;
  created_by: string;
  wizard_progress: Record<string, boolean>;
}
```

### RS Backend Controller

The controller validates query params via `ListSuitesQueryDto`:

```typescript
export class ListSuitesQueryDto {
  @IsOptional() @IsString() search?: string;
  @IsOptional() @IsIn(['DRAFT', 'RUNNING', 'COMPLETED', 'FAILED', 'ARCHIVED']) status?: SuiteStatus;
  @IsOptional() @IsString() rule?: string;
  @IsOptional() @IsInt() @Min(1) page?: number;
  @IsOptional() @IsInt() @Min(1) @Max(100) limit?: number;
}
```

The service calls `AdminServiceClient.listSimulationSuites(query, tenantId, token)`.

### Admin Service — listSimulationSuites

New handler in `admin-service/src/services/simulation-studio.logic.service.ts` backed by a new `SimulationSuiteRepository`. The repo builds a parameterised WHERE clause:

```sql
SELECT id, name, rule_name, primary_txtp, status, iteration_count, last_run_at,
       updated_at, created_by, wizard_progress
FROM trs_simulation_suites
WHERE tenant_id = $1
  [AND name ILIKE $2]
  [AND status = $3]
  [AND rule_name = $4]
ORDER BY updated_at DESC
LIMIT $N OFFSET $N;
```

A separate `SELECT COUNT(*)` query supplies the total. The handler returns `PaginatedResult<SuiteListItemDto>`.

### Database

The query is served by `idx_sim_suites_tenant_status_updated`, the composite index designed for this exact predicate ordering.

### Prerequisites

- HK-03 (skeleton list page, DRAFT status style).
- HK-01 (DB migration including composite index).
- HK-02 (controller route + DTO).
- S1-01 (Rule filter dropdown consumes `GET /registry/repos`).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 1 | `<SimulationStudioList />` skeleton at `pages/SimulationStudio/List/index.tsx`: route wired, page header, CTA, `<SuspenseLoader />`, empty state, `<Table />` placeholder with column definitions. |
| Dev A | Day 5 | Full list controller: extend `<TableActions />` with `onResume`; `useSimulationStudioListController` using `useFilters()` for search + pagination + `useLazyListSuitesQuery`; wire search input, status `<DropDown />`, rule `<DropDown />`, reset-filters icon; date formatting on Last Updated; Resume eligibility `status === 'DRAFT' && Object.values(wizard_progress).some(Boolean)`. |
| Dev B | Day 5 | `GET /suites` controller binding, `ListSuitesQueryDto` validation, service delegation, `handleListSimulationSuites` admin handler, new `SimulationSuiteRepository` with paginated SELECT and COUNT query, router registration. |

---

## S1-01 — Select a Rule and Transaction Version for the Suite
[Back to Top](#top)

**Start:** 21 May · **End:** 22 May

### Overview

From the user-stories acceptance criteria: the Rule dropdown lists all available rules from the registry; selecting a rule populates a Rule Version dropdown filtered to versions for that rule; selecting a rule + version populates a TxTp dropdown showing deployed TXTPs and their versions for use as the Primary Message Type; in edit mode, rule and transaction type are pre-selected and locked, only the version is editable. The rule plus the primary TxTp form the immutable identity of the suite. Rules are sourced exclusively from Docker Hub via `RegistryService`.

### Frontend — Step 1

Implemented inside `<SimulationStudioWizard />` under `pages/SimulationStudio/Wizard/Step1RuleAndTxtp/`.

- Rule picker — searchable dropdown from `GET /registry/repos`. Repo names like `rule-high-value` are parsed into friendly display names.
- Rule Version picker — populated from `GET /registry/repos/:repo/tags` on rule selection, sorted by `last_updated DESC`.
- Primary TxTp picker — populated from `GET /txtp-types`. Label: "Primary Message Type".
- Primary TxTp Version picker — populated from the selected TxTp row returned by `GET /txtp-types`.
- All four selectors required before Next is enabled.
- Edit mode (`/simulation-studio/edit/:id`): rule and primary TxTp render as read-only labels, only the rule version dropdown is editable.
- On validated Next: `POST /suites` creates a DRAFT suite and returns `{ id, status: 'DRAFT' }`; the wizard then has a suite id available for HK-04 draft saves and SM-01 context generation.

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/registry/repos` | Lists `rule-*` repos from Docker Hub for the configured namespace. Returns `[{ repo, friendlyName }]`. |
| GET | `/registry/repos/:repo/tags` | Lists tags for a repo sorted by `last_updated DESC`. Returns `[{ tag, digest, lastUpdated }]`. 5-min TTL cache. |
| GET | `/txtp-types` | Lists TXTP types and their versions. Pass-through to admin `/v1/admin/config/transaction-types` (filtered to `status IN ('STATUS_04_APPROVED', 'STATUS_06_EXPORTED')`). |
| POST | `/suites` | Creates a DRAFT suite. Body: `CreateSuiteDto`. Returns `{ id, status: 'DRAFT' }`. |

### RS Backend — RegistryService

| Method | External call |
|---|---|
| `listRepos(namespace)` | `GET https://hub.docker.com/v2/repositories/{namespace}/?page_size=100`, filtered to `rule-*` repos; paginates if more than 100. |
| `listTags(namespace, repo)` | `GET https://hub.docker.com/v2/repositories/{namespace}/{repo}/tags/?page_size=100` sorted by `last_updated DESC`; 5-min TTL cache per repo. |
| `verifyImage(namespace, repo, tag)` | Calls `listTags`, confirms tag exists, returns `{ exists, digest: string }`. Used by `POST /suites/:id/run` to pin the SHA256 digest into `trs_simulation_runs.rule_image_digest`. |
| `getToken()` | Per HK-05 — 50-min TTL JWT cache. |

### Admin Service

The existing TXTP endpoints `/v1/admin/config/transaction-types`, `/v1/admin/config/payload/:txtp/:ver`, and `/v1/admin/config/:txtp/:ver` are consumed via `AdminServiceClient`. No new admin routes are added.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | INSERT with `name`, `description`, `rule_repo`, `rule_name`, `rule_version`, `primary_txtp`, `primary_txtp_version`, `simulation_type='SINGLE_RULE'`, `status='DRAFT'`, `tenant_id`, `created_by`. |
| `tcs_config` | SELECT only, via admin TXTP handlers; filter column is `status`. |

### Prerequisites

- HK-02 (controller routes bound).
- HK-05 (Docker Hub token cache).
- HK-01 (`trs_simulation_suites` exists).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 1 | `RegistryService.listRepos`, `listTags`, `verifyImage` with the 50-min and 5-min caches in place. Wire `GET /registry/repos` and `GET /registry/repos/:repo/tags` controller methods. |
| Dev A | Day 2 | Step 1 frontend: rule picker, version picker (populated on rule change), Primary TxTp picker, TxTp version picker; edit-mode lock on rule + TxTp; required validation; RTK Query wiring; `POST /suites` on validated Next. |
| Dev B | Day 2 | `POST /suites` endpoint: `CreateSuiteDto` validation, insert DRAFT row through `AdminServiceClient.createSuite`, return `{ id, status }`. `GET /txtp-types` pass-through to admin's transaction-types handler. |

---

## S1-02 — Define Suite Metadata
[Back to Top](#top)

**Day:** 22 May

### Overview

From the user-stories acceptance criteria: a missing Suite Name on Step 1 Next blocks navigation with a required-field validation error; a valid name advances to Step 2 with the name in wizard state; in clone mode, the name is pre-filled as `Copy of [Original Name]`. S1-02 is logically part of Step 1 alongside S1-01 but is a discrete story to make validation rules explicit.

### Frontend

Inside the Step 1 component built by S1-01:

- Suite Name — required text input, max 120 chars, character counter, inline validation error on Next if empty.
- Suite Description — optional textarea, max 500 chars, character counter.
- Clone mode: Suite Name pre-filled as `Copy of [Original Name]` (editable). All other fields reflect the source suite.

### API

Same `POST /suites` endpoint as S1-01. `name` and `description` are part of the same `CreateSuiteDto`.

### Validation

`CreateSuiteDto` carries:

```typescript
@IsString() @MaxLength(120) name!: string;
@IsOptional() @IsString() @MaxLength(500) description?: string;
```

The server enforces both bounds. Frontend character counters mirror these limits visually.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | `name VARCHAR(120) NOT NULL`, `description VARCHAR(500)` — INSERT on Step 1 Next; further refinements via `PUT /suites/:id/draft`. |

### Prerequisites

- S1-01 (shared Step 1 component, shared `POST /suites` endpoint).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 2 | Name + description fields, counters, required validation on name (covered alongside S1-01 Day 2 frontend task). |
| Dev B | Day 2 | `@MaxLength(120)` on name, `@IsOptional() @MaxLength(500)` on description in `CreateSuiteDto` (covered alongside S1-01 Day 2 backend task). |

---

## S2-01 — Configure Context Data
[Back to Top](#top)

**Day:** 22 May

### Overview

From the user-stories acceptance criteria: on Step 2, selecting a TXTP type and version with a message count and clicking Add TXTP appends a row; clicking a TXTP row expands a configuration panel with schema fields on the left and the strategy configurator on the right; selecting a strategy reveals strategy-specific sub-options; the first TXTP row is the primary TXTP and is identified by an order number; Remove deletes a row; rows show Schema Loaded and Sample Available status badges; Preview Data renders a 5-row inline preview. S2-01 configures the field strategies that drive context generation in SM-01.

### Frontend — `<FieldConfigurator />`

Strategy options exposed in the per-field configurator match the `ContextFieldStrategy` enum exactly: `keep_sample`, `static`, `range`, `generated`, `null`, `skip`. Each strategy reveals the appropriate sub-options:

- `static`: a single value input typed against the schema field.
- `range`: numeric min/max inputs (server-validated as `range_min <= range_max`).
- `generated`: a generator type picker (e.g., `iso20022.bic`, `iban`, `iso8601`) plus optional generator options.
- `null`, `keep_sample`, `skip`: no sub-options.

Step 2 builds the TXTP table on top of `<FieldConfigurator />`:

- TXTP table seeded with row 1 = the primary TXTP from Step 1 (locked, cannot be removed).
- Add TXTP button appends rows for additional context TXTPs.
- Per row: TXTP type (locked for row 1, editable dropdown for additional rows from `GET /txtp-types`), TXTP version, No. of messages (integer, min 1), Schema Loaded badge once schema fetched, Sample Available badge if TCS has a sample.
- Preview Data per row calls `POST /suites/:id/generate/context?count=5` and renders an inline 5-row preview table.
- Expand opens the `<FieldConfigurator />` panel for that row.
- Remove available on additional rows only.
- On validated Next: `PUT /suites/:id/draft` with `{ screen: 2, data: { txtpConfigs, fieldConfigs, messageCounts } }`; then SM-01's container calls `POST /generate/context` for the full count before advancing to Step 3.

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/txtp-types/:txtp/:version/schema` | Returns `{ schema }` for the configurator. Sourced from admin `/v1/admin/config/:transactionType/:version`. |
| GET | `/txtp-types/:txtp/:version/sample` | Returns `{ payload }` for Sample Available and Trigger defaults. Sourced from admin `/v1/admin/config/payload/:txtp/:ver`. |
| POST | `/suites/:id/generate/context` | Generate context rows. `count=5` for preview; omit `count` for full. |
| PUT | `/suites/:id/draft` | Persists Step 2 draft (`screen=2`). |

### RS Backend — ContextGenerationService

The service (created in SM-01) returns `422` with a row-level error array when any generated payload fails AJV validation. The error envelope:

```json
{
  "statusCode": 422,
  "message": "Context generation validation failed",
  "errors": [{ "txtp": "...", "version": "...", "messageOrder": 1, "issues": [{ "instancePath": "...", "message": "..." }] }]
}
```

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | `metadata.wizardDraft.screen2` updated via the draft mutation. |
| `trs_suite_context_txtp_configs`, `trs_suite_context_field_strategies`, `trs_suite_context_generated_messages` | Not written here — written atomically inside T-01's `handleSaveIterationTransactional` on Save Iteration. |
| `tcs_config` | SELECT-only via admin TXTP handlers (filter `status IN ('STATUS_04_APPROVED','STATUS_06_EXPORTED')`). |

### Prerequisites

- S1-01 (suite exists; `POST /suites` already called).
- HK-03 (`<FieldConfigurator />`).
- HK-04 (`PUT /suites/:id/draft`).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 2 | Step 2 frontend under `pages/SimulationStudio/Wizard/Step2ContextData/` — TXTP table, pre-populated row 1 from wizard state, Add/Remove rows, type + version dropdowns, No. of messages input, Schema Loaded + Sample Available badges, Preview Data inline 5-row table, `<FieldConfigurator />` panel, `PUT /draft` on Next. |
| Dev B | Day 2 | `GET /txtp-types`, `GET /txtp-types/:txtp/:version/schema`, `GET /txtp-types/:txtp/:version/sample`; `AdminServiceClient` wrappers for the three existing admin TXTP endpoints. |
| Dev B | Day 3 | `POST /suites/:id/generate/context` implementation in `ContextGenerationService`; 422 row-level validation envelope used by both Preview and Next flows. |

---

## S3-01 — Configure and Preview Simulation Trigger Transactions
[Back to Top](#top)

**Day:** 25 May

### Overview

From the user-stories acceptance criteria: Step 3 renders one collapsible card per TXTP selected in Step 2, each pre-populated with the TCS sample payload; the JSON is editable per card; the user sets a No. of msgs per card; the total across cards must not exceed 15; a Link to context pairs checkbox links each trigger message to a context pair via EndtoEndID; on Next, all payload configurations are saved and the user advances to Step 4. The 15-transaction cap is enforced on both client and server.

### Frontend

Implemented under `pages/SimulationStudio/Wizard/Step3TriggerData/`.

- One collapsible card per TXTP from Step 2. The `<AccordianSummary />` component provides the card header.
- Per card: TXTP label (read-only), JSON editor pre-populated with the TCS sample (built on `<JsonFormatter />` for structured edit/add/delete), No. of msgs integer input, Link to context pairs checkbox enabled only when Step 2 generated context rows for this TXTP.
- Cross-card validator: sum of all No. of msgs values must be `<= 15`. Validation error blocks Next: "Total trigger messages across all TXTPs cannot exceed 15".
- Per-field overrides surface the `TriggerFieldOverride` enum (`static`, `range`, `generated`, `remove`, `null`) where the user opts into structured field control beyond raw JSON edits.
- On validated Next: `PUT /suites/:id/draft` with `{ screen: 3, data: { triggerConfigs: [{ txtp, version, payload, count, linkToContext, fieldOverrides? }] } }`.

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| PUT | `/suites/:id/draft` | Persists Step 3 draft (HK-04). |
| GET | `/txtp-types/:txtp/:version/sample` | Used on resume to rehydrate the sample payload if wizard state is cold. |

### RS Backend

The 15-message cap is enforced server-side inside `handleSaveIterationTransactional` (T-01) — the per-screen draft endpoint validates types and per-card shape; the run dispatch rejects with `422` if the summed count exceeds 15. This belt-and-braces approach handles any client bypass.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | `metadata.wizardDraft.screen3` updated via the draft mutation. |
| `trs_suite_trigger_txtp_configs`, `trs_suite_trigger_field_overrides`, `trs_suite_trigger_generated_messages` | Not written here — written atomically inside T-01's `handleSaveIterationTransactional`. |

### Prerequisites

- S2-01 (TXTP list and TCS samples in wizard state).
- SM-01 (wizard shell).
- HK-04 (`PUT /draft`).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 3 | Step 3 frontend: one collapsible card per TXTP, JSON editor pre-populated from sample payload, No. of msgs input with cross-card total validation (`<= 15`), Link to context pairs checkbox (enabled only when context exists for the TXTP), `PUT /draft` on validated Next. |
| Dev B | Day 3 | Server-side validation of the Step 3 draft contract (per-card shape, payload type, count bounds). Wire the 15-message cap into `handleSaveIterationTransactional` (T-01). |

---

## S4-01 — Define One or More Enrichment Tables
[Back to Top](#top)

**Day:** 29 May

### Overview

From the user-stories acceptance criteria: on Step 4 the user enters a table name and pastes a JSON payload, then clicks Save Record; the record appears in the Saved Enrichment Records table; repeat to add more tables; empty Target Table Name disables Save Record; Remove deletes a saved record; on Next, all saved tables are reflected in the Step 5 summary. Step 4 captures schema templates only — physical table creation and bulk INSERT happen during run orchestration (T-02).

### Frontend

Implemented under `pages/SimulationStudio/Wizard/Step4Enrichment/`.

- Target Table Name input (required, max 63 chars to match Postgres identifier limit; server-side `validateTableName` rejects reserved keywords and disallowed characters).
- JSON payload textarea (built on `<Input />` and optionally `<JsonFormatter />` for structured editing).
- Save Record appends `{ tableName, payload, fieldStrategies? }` to the Saved Enrichment Records list. Disabled until a non-empty table name and a valid JSON payload are present.
- Saved Enrichment Records table with columns Table Name, Payload (truncated), Remove. Remove deletes that record from local wizard state.
- `<FieldConfigurator />` is available per record for column-level strategies that match the `EnrichmentFieldStrategy` enum (`static`, `range`, `generated`, `null`, `copy`).
- On validated Next: `PUT /suites/:id/draft` with `{ screen: 4, data: { enrichmentRecords: [...] } }`.

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| PUT | `/suites/:id/draft` | Persists Step 4 draft. |

### Validation

The same `validateTableName` utility at [admin-service/src/utils/enrichment-utils.ts](../admin-service/src/utils/enrichment-utils.ts) is reused both at draft save and inside `handleSaveIterationTransactional` (T-01). Rules: non-empty, `<= 63` chars, regex `^[A-Z_]\w*$` (case-insensitive), not a reserved SQL keyword. Duplicate `tableName` entries in a single screen payload are rejected with `422`.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | `metadata.wizardDraft.screen4` updated via the draft mutation. |
| `trs_suite_enrichment_tables`, `trs_suite_enrichment_field_strategies`, `trs_suite_enrichment_generated_rows` | Not written here — written atomically inside T-01. |

### Prerequisites

- SM-01 (wizard shell).
- HK-04 (`PUT /draft`).
- S3-01 (Step 3 Next advances to here).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 4 | Step 4 frontend: table name input, JSON payload editor, Save Record (disabled when name empty or JSON invalid), Saved Enrichment Records table with Remove action, `<FieldConfigurator />` for column-level strategies, `PUT /draft` on Next. |
| Dev B | Day 4 | Draft-payload validation: enforce table-name regex and reserved-keyword block via `validateTableName`; reject duplicate names; verify shape compatibility with `handleSaveIterationTransactional` (T-01) and ODS init (T-02). |

---

## S5-01 — Review the Full Suite Summary Before Saving
[Back to Top](#top)

**Day:** 29 May

### Overview

From the user-stories acceptance criteria: Step 5 shows Suite Name, Associated Rule, Rule Version, TXTPs, Iteration Number, Enrichment Tables, Context count, Trigger count, and total Valid Payloads; Back returns to Step 4 with all data intact; in edit mode a warning banner states that saving will create a new iteration without overwriting previous ones; Save as Draft returns to the list with the suite in Draft status; Save Iteration redirects to the suite detail page after the new iteration appears in history.

### Frontend

Implemented under `pages/SimulationStudio/Wizard/Step5Summary/`.

- Read-only summary built from wizard state.
- Iteration label computed as `Iteration ${iteration_count + 1}` for new iterations.
- Edit Mode Warning Banner (when route is `/simulation-studio/edit/:id`): "Saving will create a new iteration and will not overwrite previous ones."
- Back returns to Step 4 with state intact.
- Save as Draft: `PUT /suites/:id/draft` with the final summary state, then navigate to `/simulation-studio`. Suite remains `DRAFT`.
- Save Iteration: `POST /suites/:id/run`. On `{ runId, status: 'ENV_PROVISIONING' }`, mount `<Screen6Results />`.

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/suites/:id` | Fetch suite + `metadata.wizardDraft` for summary display. |
| PUT | `/suites/:id/draft` | Persist final summary state on Save as Draft. |
| POST | `/suites/:id/run` | Triggers `handleSaveIterationTransactional` + orchestrator dispatch. Returns `{ runId, status: 'ENV_PROVISIONING' }`. |

### Edit Mode Warning Banner

Driven by the `mode === 'edit'` derivation from the route. The banner uses the existing alert styling — no new component.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | `metadata.wizardDraft.screen5` updated on Save as Draft. `status` transitions to `RUNNING` on Save Iteration. `iteration_count` is incremented inside `handleSaveIterationTransactional`. |

### Prerequisites

- S4-01 (enrichment data in `wizardDraft`).
- SM-01 (wizard container drives the post-stepper transition).
- T-01 (`POST /suites/:id/run`).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 4 | Step 5 frontend: read-only summary, computed iteration label, edit-mode warning banner, Back, Save as Draft (`PUT /draft` + redirect), Save Iteration (`POST /run` + Screen 6 transition). |
| Dev B | Day 4 | `GET /suites/:id` summary endpoint and `POST /suites/:id/run` dispatcher contract (stub-safe path for FE integration before T-01 lands). |

---

## T-01 — Atomically Persist Wizard Data and Dispatch Orchestrator on Run
[Back to Top](#top)

**Start:** 21 May · **End:** 01 Jun

### Overview

T-01 covers two responsibilities on Save Iteration: a single admin transaction that converts all wizard draft data into a persisted iteration, and the fire-and-forget orchestrator dispatch. The transaction takes an advisory lock keyed by `(suite_id, generation_id)` to serialise concurrent Save Iteration and quick-rerun attempts against the same generation. If the database write succeeds but dispatch fails, the run row is updated to `FAILED` and no containers start.

### API

`POST /api/v1/simulation-studio/suites/:id/run`:

1. Validate the suite exists, `simulation_type = 'SINGLE_RULE'`, and the caller has `EDITOR` or `APPROVER`.
2. Call `RegistryService.verifyImage(rule_repo, rule_version)` and capture the SHA256 digest. Return `422` if the image cannot be resolved.
3. Call `AdminServiceClient.saveIterationTransactional(suiteId, payload, token)` to persist the new generation, all snapshots, and the run row atomically. The digest is written to `trs_simulation_runs.rule_image_digest` inside the same transaction.
4. Dispatch the orchestrator fire-and-forget: `void this.orchestratorService.dispatch(runId)`.
5. On dispatch failure (e.g., synchronous throw), update the just-created run to `FAILED` with an error reason.
6. Return `{ runId, status: 'ENV_PROVISIONING' }` immediately.

### Admin Service — handleSaveIterationTransactional

A single `BEGIN ... COMMIT` transaction. Pseudocode:

```typescript
await client.query('BEGIN');
await client.query(
  "SELECT pg_advisory_xact_lock(hashtext($1::text || ':' || $2::text))",
  [suiteId, generationId],
);
// Compute next run_number:
//   const { rows } = await client.query('SELECT COALESCE(MAX(run_number),0)+1 AS next FROM trs_simulation_runs WHERE suite_id=$1 AND generation_id=$2 FOR UPDATE', [suiteId, generationId]);
// INSERT into trs_suite_generations, trs_suite_context_txtp_configs, trs_suite_context_field_strategies,
//   trs_suite_context_generated_messages, trs_suite_trigger_txtp_configs, trs_suite_trigger_field_overrides,
//   trs_suite_trigger_generated_messages, trs_suite_enrichment_tables, trs_suite_enrichment_field_strategies,
//   trs_suite_enrichment_generated_rows, trs_suite_context_sim_pairs, trs_simulation_runs.
// UPDATE trs_simulation_suites SET iteration_count = iteration_count + 1, run_count = run_count + 1,
//   status = 'RUNNING', last_run_at = NOW() WHERE id = $1 AND tenant_id = $2.
await client.query('COMMIT');
return { runId };
```

The advisory lock is exactly `pg_advisory_xact_lock(hashtext(suite_id::text || ':' || generation_id::text))` and is released automatically at commit. This is the canonical form used by both T-01 and the quick-rerun flow (RR-01 / RR-02).

All child writes JOIN through `trs_simulation_suites` on `tenant_id` via the shared helper `getSuiteOrThrow(id, tenantId)` before any mutation.

The 15-message trigger cap is enforced here: if the summed `triggerConfigs[].count` from `wizardDraft.screen3` exceeds 15, the transaction is rolled back and the controller returns `422`.

### RS Backend Dispatch

```typescript
const { runId } = await this.admin.saveIterationTransactional(suiteId, payload, token);
void this.orchestratorService.dispatch(runId);
return { runId, status: 'ENV_PROVISIONING' };
```

The `void` is deliberate — the controller does not await orchestration. UI tracks progress through the `GET /suites/:id/runs/:runId/status` polling endpoint.

### Database

All sim tables visible in [diagrams/erd.md](diagrams/erd.md) are written in this single transaction. The status flow on `trs_simulation_runs.status` is `ENV_PROVISIONING → RUNNING → COMPLETED | FAILED | TIMED_OUT | CANCELLED`. The status flow on `trs_simulation_suites.status` is `DRAFT → RUNNING → COMPLETED | FAILED | ARCHIVED`.

### Prerequisites

- HK-01 (schema in place).
- S5-01 (the call site).
- S1-01 (`RegistryService.verifyImage` available).
- T-02 (orchestrator dispatch consumer — may be stubbed early to unblock the persistence half).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 1 | First-time DB initialisation (HK-01 coordination); confirm `simulation_studio` is reachable by admin-service. |
| Dev B | Day 3 | `handleSaveIterationTransactional` covering generation + run + all snapshots in one transaction, advisory lock, run-number allocation, suite counter update, rollback semantics. |
| Dev B | Day 5 | RS Backend run endpoints: `POST /suites/:id/run` with `verifyImage` + async dispatch, `GET /suites/:id/runs/:runId/status` returning status/phase/error and the optional `partialResults` array. |

---

## SR-01 — Run a Simulation and Observe Results Upon Completion
[Back to Top](#top)

**Start:** 01 Jun · **End:** 03 Jun

### Overview

From the user-stories acceptance criteria: clicking Run Simulation on Step 5 transitions the button to a disabled loading state with a non-interactive waiting state; on terminal state (Completed or Failed) the user is automatically navigated to the Results screen without manual action; the Results screen displays one row per sim transaction with Trigger Message ID, Independent Variable, Result Band chip, Expected IV, Expected Band chip, and Notes; a failed run displays a clear failure state with a reason and no partial results; current run renders expanded at the top with previous runs collapsed below it.

### Frontend

Screen 6 mounts after `POST /run` succeeds on Step 5.

- Waiting state: non-interactive loading indicator "Simulation in progress…".
- Polling: RTK Query on `GET /suites/:id/runs/:runId/status` every 2 s until `status` is one of `COMPLETED`, `FAILED`, `TIMED_OUT`, `CANCELLED`. Polling stops on terminal state.
- On `COMPLETED`: fetch `GET /suites/:id/runs/:runId/results` and render the results table ordered by `transaction_order ASC`.
- On `FAILED`, `TIMED_OUT`, or `CANCELLED`: display the failure reason from `error_message`; no partial results shown.
- Current run rendered expanded at the top; prior runs for the same suite are listed collapsed below.

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/suites/:id/runs/:runId/status` | Polled every 2 s. Returns `{ status, phase, error_message?, partialResults? }`. |

### RS Backend

The status endpoint reads the run row from admin via `AdminServiceClient.getRunStatus(suiteId, runId, tenantId, token)`. The optional `partialResults` array is populated for clients that want to display partial progress; the SR-01 frontend deliberately ignores it and only renders the full set on terminal state, per the user-story assumption "no live logs or incremental result updates".

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_runs` | SELECT by `id` + tenant scope. |
| `trs_simulation_run_results` | Optional SELECT for `partialResults`. |

### Prerequisites

- S5-01 (the call site for Save Iteration).
- T-01 (run endpoint and status contracts).
- T-02 (orchestrator drives status transitions).
- T-03 (result rows persisted by the transaction loop).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 5 | `GET /suites/:id/runs/:runId/status` with phase, status, optional error message, and optional `partialResults`. |
| Dev A | Day 7 | Screen 6 frontend: polling lifecycle (start on Step 5 → Screen 6 transition, stop on terminal state), waiting state, FAILED/TIMED_OUT/CANCELLED display, COMPLETED → results fetch + table render, prior runs collapsed section. |

---

## T-02 — Orchestrate an Isolated Docker Container Lifecycle Per Run
[Back to Top](#top)

**Start:** 01 Jun · **End:** 04 Jun

### Overview

T-02 implements the full Docker orchestration engine for single-rule simulation runs, driven programmatically via Dockerode (no Docker Compose). Each run gets a dedicated bridge network `sim-run-<runId>` containing four containers: ephemeral Postgres (ODS), NATS, nats-utilities, and the rule processor. The rule processor image is pinned to the SHA256 digest returned by `RegistryService.verifyImage()` and written to `trs_simulation_runs.rule_image_digest` before the persistence transaction commits, guaranteeing byte-identical reruns.

### Dependencies

`dockerode` is added to [rule-studio/backend/package.json](../rule-studio/backend/package.json). It is not currently a dependency. No other new packages are required.

### RS Backend — OrchestratorService

The orchestrator drives a phase machine that mirrors `trs_simulation_runs.phase`:

```
ENV_PROVISIONING → NETWORK_CREATE → BASE_CONTAINERS_START → ODS_INIT
                 → APP_CONTAINERS_START → TRANSACTION_LOOP → CLEANUP
                 → COMPLETED | FAILED
```

Per-phase responsibility:

- `NETWORK_CREATE`: create the bridge network `sim-run-<runId>`. Label `run_id=<id>` is applied to the network and to every container created in subsequent phases for T-04 crash recovery.
- `BASE_CONTAINERS_START`: start ephemeral Postgres (ODS) and NATS in parallel; poll until both report healthy (`pg_isready`, NATS `/healthz`).
- `ODS_INIT`: render and execute SQL — CREATE TABLE for rule history; bulk INSERT context rows from `trs_suite_context_generated_messages`; CREATE TABLE + bulk INSERT for each enrichment table from `trs_suite_enrichment_tables` / `trs_suite_enrichment_generated_rows`. Owned by `OdsInitService`.
- `APP_CONTAINERS_START`: start nats-utilities and the rule processor sequentially; poll healthy.
- `TRANSACTION_LOOP`: submit each sim pair to nats-utilities sequentially with `await=true`. Owned by `TransactionLoopService`. Per-transaction timeout `TRANSACTION_TIMEOUT_MS` (default 30 s).
- `CLEANUP`: stop containers in reverse order; remove the network. Idempotent.

`single-rule-env.builder.ts` builds the `SingleRuleEnvSpec` from the persisted generation rows so reruns reproduce the same environment exactly. `env-registry.service.ts` enforces a concurrency cap (`MAX_CONCURRENT_SIM_ENVS`, default 4); a 5th concurrent run dispatch returns `429`.

### Image Pinning

`RegistryService.verifyImage(repo, tag)` is called from `POST /suites/:id/run` before `handleSaveIterationTransactional`. The returned `{ exists, digest }` is included in the iteration payload; admin-service writes `digest` into `trs_simulation_runs.rule_image_digest` inside the same transaction. The orchestrator pulls the image by `repo@sha256:<digest>` — not by tag — so reruns are byte-identical even if the upstream tag moves.

### Daemon Access

Dockerode chooses the transport from environment variables. Dev defaults to the Unix socket `/var/run/docker.sock`. Prod uses TCP+TLS through `DOCKER_HOST=tcp://...`, `DOCKER_TLS_VERIFY=1`, and `DOCKER_CERT_PATH=/etc/docker/certs`. No code branching is required.

Other orchestrator env vars:

| Variable | Default | Purpose |
|----------|---------|---------|
| `MAX_CONCURRENT_SIM_ENVS` | 4 | Concurrency cap on simultaneous runs. |
| `CONTAINER_HEALTH_TIMEOUT_MS` | 120000 | Max ms to wait for a container to report healthy (T-04). |
| `TRANSACTION_TIMEOUT_MS` | 30000 | Per-transaction timeout in the loop (T-04). |
| `RUN_TIMEOUT_MS` | 1800000 | Total run timeout (T-04). |

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_runs` | UPDATE status/phase transitions, `started_at`, `completed_at`, `error_code`, `error_message`, `docker_network_name`, `orchestrator_metadata`. |
| `trs_simulation_run_events` | INSERT per phase transition for forensic logs (`level`, `event_type`, `message`, `details_json`, `occurred_at`). |
| `trs_simulation_run_artifacts` | Optional INSERT of container logs (`artifact_type IN ('CONTAINER_LOG', 'ODS_SQL', 'NATS_REQUEST', 'NATS_RESPONSE', 'RULE_PROCESSOR_RAW', 'ERROR_STACK', 'METRICS', 'OTHER')`). |
| `trs_simulation_suites` | UPDATE `last_run_at` on completion (or via the central handler). |

### Prerequisites

- T-01 (`trs_simulation_runs` row exists before orchestrator begins).
- HK-02 (orchestrator providers wired in the module).
- HK-05 (Docker Hub auth for digest lookup).
- HK-01 (schema).
- Confirmation that Docker daemon access (socket in dev, mTLS in prod) is provisioned before Day 5.

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 5 | Orchestrator foundation: Dockerode client setup, network create/remove helpers, `SingleRuleEnvBuilder`, `EnvRegistryService` (concurrency pool), container start/stop helpers. |
| Dev B | Day 6 | `OdsInitService` SQL render for ODS history + context inserts + enrichment create/insert from generation snapshots. `TransactionLoopService` sequential sim pair POST to nats-utilities with await=true, per-transaction timeout, immediate per-transaction result write (T-03). |
| Dev C | Day 6 | `OrchestratorService` startup sequence: parallel Postgres + NATS start, health-check polling, sequential nats-utilities → rule processor start, ODS init invocation, transaction loop invocation, teardown. |
| Dev C | Day 8 | Crash recovery + idempotent teardown hardening (covered under T-04). |

---

## T-03 — Persist One Result Row Per Sim Transaction
[Back to Top](#top)

**Day:** 02 Jun

### Overview

From the user-stories acceptance criteria: when the rule processor returns a response, the system parses `independent_variable` and `result_band` and writes one row; on a per-transaction error, `result_band = 'error'` and the run continues; results are returned in transaction submission order; the polling endpoint includes incremental result data so the UI can display partial results as they arrive. T-03 is the per-transaction persistence hook on the orchestrator loop and the corresponding admin handler.

### Admin Service — appendRunResult

`handleAppendRunResult(runId, dto, tenantId)` inserts one row into `trs_simulation_run_results` and any associated rows into `trs_simulation_run_result_context_links`. The handler validates `result_band IN ('good','neutral','bad','error')`, enforces `UNIQUE (run_id, transaction_order)`, and joins through `trs_simulation_runs → trs_simulation_suites` for the tenant check via `getSuiteOrThrow`.

The `GET /suites/:id/runs/:runId/status` handler optionally augments its response with the most recent rows as `partialResults: ResultRowDto[]` for clients that want incremental display.

### RS Backend — TransactionLoopService

For each sim pair from `trs_suite_context_sim_pairs`:

1. Submit to nats-utilities with `await=true` and a `TRANSACTION_TIMEOUT_MS` watchdog.
2. Parse the response (`result_band`, `independent_variable`, `trigger_message_external_id`, `trigger_txtp`, raw `rule_processor_response`).
3. Immediately call `AdminServiceClient.appendRunResult(runId, dto, token)` — one INSERT per transaction, not batched.
4. On nats-utilities error or timeout: build a `result_band='error'` row, persist, continue the loop. Individual transaction errors do not abort the run.

After the loop completes, the orchestrator updates `trs_simulation_runs.status = 'COMPLETED'` and `completed_at = NOW()`.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_run_results` | INSERT per transaction (`run_id`, `transaction_order`, `trigger_message_id`, `trigger_message_external_id`, `trigger_txtp`, `independent_variable`, `result_band`, `expected_independent_variable`, `expected_result_band`, `notes`, `rule_processor_response`, `received_at`). |
| `trs_simulation_run_result_context_links` | INSERT per linked context message when `link_to_context_pairs = true`. |

### Prerequisites

- T-02 (transaction loop produces results).
- T-01 (run row exists).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 6 | `handleAppendRunResult` admin handler — DTO validation, INSERT into `trs_simulation_run_results`, optional `trs_simulation_run_result_context_links`, run completion update. Extend `GET /runs/:runId/status` response with optional `partialResults`. |
| Dev C | Day 6 | Wire per-transaction result write in `TransactionLoopService` — after each nats-utilities response, call `appendRunResult` before the next pair. Parse `result_band`, `independent_variable`, identifiers, and the raw response. |

---

## SM-03 — View Suite Details and Iteration History
[Back to Top](#top)

**Day:** 02 Jun

### Overview

From the user-stories acceptance criteria: clicking the View icon opens a detail page with suite metadata and the iteration history table; the table has one row per iteration with Gen label, Created Date, Context count, Trigger count, Status, Simulation Results link, Rule Version; on a Ready iteration, clicking Use navigates to the Rule Studio Simulation tab with the suite pre-selected; the back arrow returns to the list. SM-03 also drives the stat-card overview that SR-02 consumes.

### Frontend — `<SimulationStudioView />`

Implemented at `rule-studio/frontend/src/pages/SimulationStudio/View/index.tsx`.

- Route: `/simulation-studio/view/:id` (with deep-link `/simulation-studio/view/:id/run/:runId`).
- Overview section: Suite Name, Description, `<StatusCard />` for status, Associated Rule + version, Primary TxTp, Created By, Created At.
- Iteration History table — most recent first:
  - Gen label (e.g., "Iteration 1").
  - Created Date.
  - Context count, Trigger count (from `trs_suite_generations`).
  - `<StatusCard />` for generation status.
  - Simulation Results link to `/simulation-studio/view/:id/run/:runId`.
  - Rule Version.
  - Actions: Quick Rerun (RR-02), Rerun with New Data (SM-04), Use (only on completed iterations).
- Back arrow returns to `/simulation-studio`.

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/suites/:id` | Suite detail including `generations[]`. |
| GET | `/suites/:id/runs` | Run rows per generation for the history table. |
| GET | `/suites/:id/runs/summary` | Stat-card data (Total Iterations, Latest Success Rate, Total Messages Processed, Active Dataset). |

### Stat Cards

`/suites/:id/runs/summary` returns a dedicated DTO that the View page and SR-02's Screen 6 reuse:

```ts
interface RunsSummaryDto {
  total_iterations: number;
  latest_success_rate: number | null;   // null if no completed runs
  total_messages_processed: number;
  active_dataset: { suite_name: string; iteration_label: string };
}
```

A dedicated endpoint is cleaner for cache invalidation than overloading the list response, since the stats refresh on each completed run while the list does not.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | SELECT by id + tenant. |
| `trs_suite_generations` | SELECT WHERE `suite_id` ORDER BY `generation_number DESC`. |
| `trs_simulation_runs` | SELECT WHERE `generation_id IN (...)`. |
| `trs_simulation_run_results` | Aggregated read for `latest_success_rate` and `total_messages_processed`. |

### Prerequisites

- SM-02 (View action originates here).
- T-01 (at least one iteration exists).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 6 | Full `<SimulationStudioView />` — overview card, iteration history table with all columns, Quick Rerun + Rerun with New Data + Use buttons (Quick Rerun wired by RR-02, Rerun with New Data by SM-04, rendered here as stubs on Day 6). |

---

## SM-04 — Run a New Iteration in an Existing Suite
[Back to Top](#top)

**Day:** 02 Jun

### Overview

From the user-stories acceptance criteria: in edit mode the Step 5 warning banner explains that saving creates a new iteration without overwriting previous ones; saving a new iteration adds it to the top of the iteration history with an incremented version label; multiple iterations remain accessible and independently viewable or runnable; the Step 1 rule dropdown is pre-selected and locked, only the rule version dropdown is editable. SM-04 is the "Rerun with New Data" flow — the wizard opens pre-populated from the most recent iteration, the user changes the rule version and any other data, and a new iteration is saved.

### Frontend

- A "Rerun with New Data" button per iteration row in `<SimulationStudioView />` navigates to `/simulation-studio/edit/:id?generation={generationId}`.
- `<SimulationStudioWizard />` in edit mode: `GET /suites/:id` fetches suite + the specified generation's `wizardDraft`.
- Step 1: rule and primary TxTp render as locked labels; only the rule version dropdown is editable.
- Steps 2–4: pre-populated from stored configs, fully editable.
- Step 5: edit-mode warning banner visible.
- Save Iteration: `POST /suites/:id/run` creates a new `trs_suite_generations` row (`generation_number = max + 1`) and a new `trs_simulation_runs` row.

### API

Reuses the wizard endpoints: `GET /suites/:id`, `PUT /suites/:id/draft`, `POST /suites/:id/run`. No new endpoints.

### Database

| Table | Operation |
|-------|-----------|
| `trs_suite_generations` | INSERT new row with `generation_number = max + 1` (immutability of prior generations preserved). |
| `trs_simulation_runs` | INSERT new run row. |

### Prerequisites

- SM-03 ("Rerun with New Data" button on `<SimulationStudioView />`).
- SM-01 (wizard supports full pre-population from stored generation data).
- T-01 (`POST /suites/:id/run`).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 6 | Wire "Rerun with New Data" to `/simulation-studio/edit/:id?generation={generationId}`. Edit-mode pre-population from the specified generation. Rule + primary TxTp locked. Warning banner on Step 5. |

---

## SR-02 — View Simulation Results with Band-Coded Outcome Per Transaction
[Back to Top](#top)

**Day:** 03 Jun

### Overview

From the user-stories acceptance criteria: stat cards show Total Iterations, Latest Success Rate, Total Messages Processed, Active Dataset; the results table shows Trigger Message ID, Independent Variable, Result Band chip, Expected IV, Expected Band chip, Notes; band chip colours are green (good), grey (neutral), orange (bad), red (error); the most recent run is expanded at the top with prior runs collapsed below; clicking a collapsed row expands it for direct comparison. Expected IV and Expected Band are stored at sim transaction configuration time and do not change between runs.

### Frontend — Screen 6 Results

Screen 6 mounts in two places: the post-stepper wizard completion, and the deep-link `/simulation-studio/view/:id/run/:runId` under `<SimulationStudioView />`. Both render identical content.

- Stat cards from `GET /suites/:id/runs/summary` (see SM-03).
- Results table from `GET /suites/:id/runs/:runId/results` — paginated, ordered by `transaction_order ASC`. Columns: Trigger Message ID, Independent Variable, Result Band chip, Expected IV, Expected Band chip, Notes.
- Band chip: green/grey/orange/red mapping driven by the `ResultBand` enum.
- Comparison highlight: when `result_band !== expected_result_band`, the row is visually flagged.
- Prior runs from `GET /suites/:id/runs` rendered collapsed below the active run; clicking a row expands its full results table for comparison.

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/suites/:id/runs/:runId/results?page=&limit=` | Paginated result rows. |
| GET | `/suites/:id/runs` | List of runs for the suite (used for prior-runs section). |
| GET | `/suites/:id/runs/summary` | Stat-card aggregates. |

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_run_results` | SELECT WHERE `run_id = $1` ORDER BY `transaction_order ASC`. |
| `trs_simulation_runs` | SELECT WHERE `suite_id = $1`. |

### Prerequisites

- T-03 (result rows persisted).
- SR-01 (Screen 6 shell + polling).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 7 | Band chip component, stat cards, comparison column highlight, expandable prior-runs section (covered together with the SR-01 Day 7 frontend task). |
| Dev B | Day 7 | `GET /suites/:id/runs/:runId/results` paginated endpoint, `GET /suites/:id/runs` list endpoint, `GET /suites/:id/runs/summary` aggregates; corresponding admin queries. |

---

## SR-03 — Search and Filter Simulation History
[Back to Top](#top)

**Day:** 03 Jun

### Overview

From the user-stories acceptance criteria: typing in the search box filters the iteration list to rows whose ID or rule version contains the search string; a Rule ID/Version filter dropdown with Apply and Clear; a Date filter with Apply and Clear; Clear All resets every filter; Expand All and Collapse All toggle every iteration row. SR-03 adds query-string filters to the existing run-list endpoint.

### Frontend

In Screen 6 and `<SimulationStudioView />`:

- Search input — filters on run identifier and rule version.
- Rule Version filter — dropdown of distinct `rule_version` values for the suite. Apply / Clear.
- Date filter — calendar picker generating `dateFrom` / `dateTo` query params. Apply / Clear.
- Clear All button resets every filter and refetches.
- Expand All / Collapse All toggles every iteration row in the prior-runs section.

### API

`GET /api/v1/simulation-studio/suites/:id/runs?ruleVersion=&dateFrom=&dateTo=&search=&page=&limit=` is the same endpoint as SR-02 with additional optional query params. The admin handler builds a parameterised WHERE clause and reuses the existing pagination shape.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_runs` | SELECT with `ruleVersion`, `dateFrom`/`dateTo` (on `created_at`), `search` (on `id::text` and `rule_version`) predicates, paginated. |

### Prerequisites

- SR-02 (run list endpoint).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 7 | Add `ruleVersion`, `dateFrom`, `dateTo`, `search` query params to `GET /suites/:id/runs`; corresponding admin SQL filters. |

---

## T-04 — Handle Container Startup Failures and Run Timeouts Gracefully
[Back to Top](#top)

**Start:** 03 Jun · **End:** 04 Jun

### Overview

From the user-stories acceptance criteria: a container failing health check within the expected startup window marks the run FAILED with a descriptive reason identifying which container failed; a run not reaching a terminal state within the configured timeout is marked FAILED and torn down; the results page shows a clear failure message and reason; any unhandled exception during a run marks the run FAILED and triggers cleanup. T-04 layers two concerns onto the orchestrator: per-run failure handling, and crash recovery on backend restart.

### Failure Handling

Within each orchestration phase the service catches errors and runs a single failure handler:

1. Capture the current `phase` and a descriptive `error_message`.
2. UPDATE `trs_simulation_runs` SET `status = 'FAILED'`, `phase = 'FAILED'`, `error_message = ...`, `completed_at = NOW()`.
3. Append a `trs_simulation_run_events` row at level `ERROR`.
4. Invoke `cleanup(runId)` — idempotent teardown that handles already-stopped containers and removed networks gracefully.

Per-container health-check timeout uses `CONTAINER_HEALTH_TIMEOUT_MS` (default 120 s). If a container does not report healthy within that window, the failure handler runs with `error_message = 'Container <name> failed health check after <n>ms'`.

Per-transaction timeout uses `TRANSACTION_TIMEOUT_MS` (default 30 s). On timeout for a single nats-utilities call, the loop writes `result_band = 'error'` for that transaction and continues — individual transaction errors do not fail the run. Total run timeout uses `RUN_TIMEOUT_MS` (default 30 min); on expiry, the run transitions to `TIMED_OUT` and cleanup runs.

### Crash Recovery

On RS Backend startup, the orchestrator runs a recovery scan:

1. Query the Docker Engine for containers and networks labelled `run_id=*`.
2. For each, fetch the corresponding `trs_simulation_runs` row.
3. If the run's `status` is non-terminal (`ENV_PROVISIONING` or `RUNNING`), invoke cleanup and write `status = 'FAILED'`, `phase = 'FAILED'`, `error_message = 'Recovered: backend restarted while run was active'`.

Because every container created by the orchestrator carries the `run_id=<id>` label (set in T-02), the scan is deterministic and does not require external state.

### Timeouts

| Variable | Default | Purpose |
|----------|---------|---------|
| `CONTAINER_HEALTH_TIMEOUT_MS` | 120000 | Health-check window per container. |
| `TRANSACTION_TIMEOUT_MS` | 30000 | Per-transaction timeout in the loop. |
| `RUN_TIMEOUT_MS` | 1800000 | Total run timeout. |

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_runs` | UPDATE `status`, `phase`, `error_code`, `error_message`, `completed_at` on terminal failure. |
| `trs_simulation_run_events` | INSERT `ERROR`-level event with phase context. |

### Prerequisites

- T-02 (orchestrator core).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 7 | Per-container health-check timeout, halt-on-failure teardown trigger, structured FAILED write, per-transaction timeout handling (error result + continue) versus run timeout (halt + TIMED_OUT). |
| Dev C | Day 8 | Crash recovery sweep on backend startup — Docker label query, orphaned run detection, teardown + FAILED write. Teardown idempotency hardening. |

---

## SM-05 — Clone an Existing Suite
[Back to Top](#top)

**Day:** 04 Jun

### Overview

From the user-stories acceptance criteria: clicking Clone opens the wizard in clone mode with all fields pre-populated from the source; the Suite Name is pre-filled as `Copy of [Original Name]` and editable; saving creates a new independent suite at iteration v1 with no run history from the source initially (cloning also copies simulation run results per the assumptions); changing any field on the clone does not affect the original; the user cannot change the Rule and TXTP selected (version can be changed), and cannot add or remove TXTPs.

### Frontend

- Route: `/simulation-studio/clone/:id` mounts `<SimulationStudioWizard />` in clone mode.
- On load: `GET /suites/:id` fetches the source suite + most recent iteration's `wizardDraft`.
- Step 1: Suite Name pre-filled `Copy of [Original Name]` (editable). Rule locked. Primary TxTp locked. Rule version editable.
- Step 2: TXTPs pre-populated; Add TXTP and Remove TXTP buttons hidden.
- Steps 3–5: pre-populated, editable as normal.
- On Save Iteration: `POST /suites` with `clone_source_suite_id = sourceId` creates the new suite; then `POST /suites/:newSuiteId/clone-results` copies run history from the source. Save as Draft is also supported in clone mode and skips the clone-results call.

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/suites/:id` | Source suite + iteration configs for pre-population. |
| POST | `/suites` | New suite with `clone_source_suite_id`. |
| POST | `/suites/:id/clone-results` | Copies `trs_simulation_runs` + `trs_simulation_run_results` + `trs_simulation_run_result_context_links` from the source. Returns `{ copiedRunCount }`. |

### Admin Service

`handleCloneSuiteResults(srcSuiteId, dstSuiteId, tenantId)` runs a single transaction:

1. `getSuiteOrThrow(srcSuiteId, tenantId)` and `getSuiteOrThrow(dstSuiteId, tenantId)` — both must belong to the caller's tenant.
2. INSERT into `trs_simulation_runs` for each source run, mapping `source_run_id` to the new id for traceability.
3. INSERT into `trs_simulation_run_results` for every result row.
4. INSERT into `trs_simulation_run_result_context_links` for every link row.

The transaction is the smallest unit that preserves referential integrity across the three tables.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | INSERT with `clone_source_suite_id` populated. |
| `trs_simulation_runs`, `trs_simulation_run_results`, `trs_simulation_run_result_context_links` | INSERT copies from source. |

### Prerequisites

- All wizard steps complete (SM-01, S1-01, S2-01, S3-01, S4-01, S5-01).
- SM-02 (Clone icon on list page).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 8 | Clone-mode wizard behaviour: detect `/clone/:id`, fetch source, map to wizard state, lock rule + TxTp, hide Add/Remove TXTP on Step 2, "Copy of [Name]" pre-fill on Step 1, send `clone_source_suite_id` on `POST /suites`. |
| Dev B | Day 8 | `POST /suites/:id/clone-results` endpoint and `handleCloneSuiteResults` admin transaction. |

---

## RR-01 — Rerun a Past Iteration from Simulation Result Page
[Back to Top](#top)

**Day:** 04 Jun

### Overview

From the user-stories acceptance criteria: clicking Rerun against an iteration on the Results page dispatches the run immediately without opening the wizard; the user sees a non-interactive loading state while waiting; on completion the new run appears at the top with its own `started_at` and the previous run is pushed down; on failure the page shows the failure reason. RR-01 reuses the stored generation rows verbatim — no edits, no wizard.

### Frontend

- Rerun button on each iteration row in Screen 6.
- On click: `POST /suites/:id/generations/:generationId/quick-rerun` → receive `{ runId, status: 'ENV_PROVISIONING' }` → render the non-interactive loading state for the new run → poll status → display results when complete.

### API

`POST /api/v1/simulation-studio/suites/:id/generations/:generationId/quick-rerun`:

- No body.
- Fetches the existing generation data, inserts a new `trs_simulation_runs` row inside the same advisory-lock pattern as T-01, dispatches the orchestrator with the same `SingleRuleEnvSpec`.
- Returns `{ runId, status: 'ENV_PROVISIONING' }`.

### Admin Service

`handleQuickRerun(suiteId, generationId, tenantId, triggeredBy)`:

```typescript
await client.query('BEGIN');
await client.query(
  "SELECT pg_advisory_xact_lock(hashtext($1::text || ':' || $2::text))",
  [suiteId, generationId],
);
// SELECT COALESCE(MAX(run_number),0)+1 AS next FROM trs_simulation_runs WHERE suite_id=$1 AND generation_id=$2.
// INSERT INTO trs_simulation_runs (suite_id, generation_id, run_number, source_run_id, trigger_source,
//   status, phase, triggered_by, ...) VALUES (..., 'QUICK_RERUN', 'ENV_PROVISIONING', ...);
await client.query('COMMIT');
```

The orchestrator rebuilds the `SingleRuleEnvSpec` from the persisted generation rows — context configs, trigger configs, enrichment tables, sim pairs — so the rerun is byte-identical when the image digest is unchanged. The run row uses the same `rule_image_digest` as the source run.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_runs` | INSERT new row with `source_run_id` set (when triggered from a specific source run). |

### Prerequisites

- SR-01 (Screen 6 hosts the Rerun button).
- T-01 (run dispatch pattern).
- T-02 (orchestrator handles rerun via the same code path).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 8 | `POST /suites/:id/generations/:generationId/quick-rerun` — controller + service + `handleQuickRerun` admin handler with advisory lock, run insert, orchestrator dispatch. |

---

## RR-02 — Rerun a Past Iteration from Simulation Suite History
[Back to Top](#top)

**Day:** 04 Jun

### Overview

From the user-stories acceptance criteria: clicking Rerun against an iteration on the Suite History page dispatches the rerun immediately; the iteration row shows a non-interactive loading state while running; on completion a new run sub-row appears under the same iteration with its own `started_at` and `triggered_by`; on failure the new sub-row reflects a Failed status with a visible reason. RR-02 shares the RR-01 backend endpoint; only the entry point differs.

### Frontend

- Rerun button per iteration row in `<SimulationStudioView />` Iteration History (rendered as a stub by SM-03 on Day 6).
- On click: same `POST /suites/:id/generations/:generationId/quick-rerun` endpoint.
- Per-row loading state during dispatch.
- On completion: refresh the iteration history to show the new run sub-row with `started_at` and `triggered_by`.

### API

Same endpoint as RR-01.

### Database

Same effect as RR-01 — a new row in `trs_simulation_runs` with `source_run_id` referencing the prior run.

### Prerequisites

- SM-03 (button stub from Day 6).
- RR-01 (shared endpoint).

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 8 | Endpoint shared with RR-01. |
| Dev A | Day 8 | Wire the Rerun button on iteration rows in `<SimulationStudioView />`. Per-row loading state on click. Refresh history on completion to show the new run sub-row. |

---

## T-05 — Push Rule Processor Image to Registry on Deployment
[Back to Top](#top)

**Status:** Out of scope this release. No scheduled start/end.

### Brief

T-05 lives at the platform deployment layer: the CI/CD pipeline that builds and pushes versioned rule processor Docker images to the container registry on rule deployment from TRS. The Simulation Studio code in this release consumes those images — via `RegistryService.verifyImage` and the digest pinned into `trs_simulation_runs.rule_image_digest` — but does not produce them.

Action required before Day 5 (first orchestrated run): confirm with the platform team that at least one rule processor image is available in the configured Docker Hub namespace under the agreed naming convention (`{namespace}/rule-{name}:{version}`). T-02 smoke testing cannot complete without a pullable image whose digest is retrievable via `RegistryService.verifyImage()`.

## 10. Story-to-Task Cross-Reference

| Story | Day(s) | Dev(s) | Tasks |
|-------|--------|--------|-------|
| HK-03 | Day 1 | Dev A | Frontend scaffolding: routes, page directory, wizard shell skeleton, `<Stepper />`, `<FieldConfigurator />`, `simulationStudioApi` slice + store registration, `VITE_SIMULATION_STUDIO_API_URL` env, `<StatusCard />` DRAFT case, `<SimulationStudioList />` skeleton. |
| HK-02 | Day 1 | Dev C | RS Backend module scaffolding: directory + `SimulationStudioModule` + controller + DTOs; AdminServiceClient injection; all 17 routes stubbed; AppModule registration. |
| HK-05 | Day 1 | Dev C | Docker Hub auth: `RegistryService` skeleton, `getToken()` with 50-min TTL, tag-list Map cache (5-min TTL), env vars. |
| HK-01 | Day 1 | Dev B | DB schema migration: provision `simulation_studio`, apply [database-migration.sql](database-migration.sql), verify 17 tables + composite index. |
| HK-04 | Day 1–2 | Dev B → Dev A | Day 1 Dev B: `PUT /suites/:id/draft` endpoint + admin handler with `jsonb_set` UPDATE.<br>Day 2 Dev A: Wire draft save on wizard Next + resume flow rehydration. |
| SM-01 | Day 1, 3 | Dev A, B | Day 1 Dev A: `<SimulationStudioWizard />` shell, stepper, validation gate, blockers, mode detection, resume-load.<br>Day 3 Dev A: `generate/context` wiring for preview + Step 2 → Step 3 transition.<br>Day 3 Dev B: `ContextGenerationService` + DTO + 422 row-level errors. |
| SM-02 | Day 1, 5 | Dev A, B | Day 1 Dev A: List skeleton + routing + placeholder.<br>Day 5 Dev A: Full searchable / filterable list + Resume action.<br>Day 5 Dev B: `GET /suites` endpoint + admin paginated query. |
| S1-01 | Day 1–2 | Dev C, A, B | Day 1 Dev C: `RegistryService` listRepos / listTags / verifyImage + registry endpoints.<br>Day 2 Dev A: Step 1 frontend rule/version/TxTp selectors + edit-mode locks.<br>Day 2 Dev B: `POST /suites` create flow + `GET /txtp-types` pass-through. |
| S1-02 | Day 2 | Dev A, B | Day 2 Dev A: Name + description inputs with counters and required validation.<br>Day 2 Dev B: DTO validation (`name` required/max, `description` optional/max). |
| S2-01 | Day 2, 3 | Dev C, B | Day 2 Dev C: Step 2 frontend TXTP table + field config + preview + draft-save wiring.<br>Day 2 Dev B: RS backend TxTp/schema/sample endpoints + AdminServiceClient wrappers.<br>Day 3 Dev B: `POST /suites/:id/generate/context` + 422 row-level validation. |
| S3-01 | Day 3 | Dev C, B | Day 3 Dev C: Step 3 frontend trigger JSON cards + message count validation + draft-save wiring.<br>Day 3 Dev B: Server-side Step 3 validation + 15-message cap. |
| S4-01 | Day 4 | Dev A, B | Day 4 Dev A: Step 4 frontend enrichment editor + list + remove + draft-save wiring.<br>Day 4 Dev B: Draft-payload validation for table-name/payload constraints + downstream compatibility. |
| S5-01 | Day 4 | Dev C, B | Day 4 Dev C: Step 5 frontend summary + Save as Draft + Save Iteration navigation.<br>Day 4 Dev B: `GET /suites/:id` summary + `POST /suites/:id/run` dispatcher contract. |
| T-01 | Day 1, 3, 5 | Dev B | Day 1: First-run DB initialisation script.<br>Day 3: Admin `handleSaveIterationTransactional` for atomic generation/run persistence.<br>Day 5: RS run endpoints (`POST /run`, `GET /runs/:runId/status`) with async dispatch / status payload. |
| SR-01 | Day 5, 7 | Dev B, A | Day 5 Dev B: Run status endpoint with status/phase/error + partial results.<br>Day 7 Dev A: Screen 6 polling lifecycle + terminal state / result presentation. |
| SR-02 | Day 7 | Dev A, B | Day 7 Dev A: Band chips + stat cards + comparison UI components.<br>Day 7 Dev B: Results endpoint + run-list endpoint + admin paginated query. |
| T-02 | Day 5, 6, 8 | Dev C, B | Day 5 Dev C: Orchestrator foundation (docker client / network helpers / env builder / registry).<br>Day 6 Dev B: ODS init + transaction loop logic.<br>Day 6 Dev C: Orchestrator startup sequence + health checks + teardown.<br>Day 8 Dev C: Crash recovery + idempotent teardown hardening. |
| T-03 | Day 6 | Dev B, C | Day 6 Dev B: Admin result-row persistence handler + status updates + partial-results support.<br>Day 6 Dev C: Per-transaction immediate result persistence integration in transaction loop. |
| SR-03 | Day 7 | Dev B | Day 7 Dev B: Run history filter params (`ruleVersion`, `dateFrom`, `dateTo`, `search`) and query path. |
| T-04 | Day 7, 8 | Dev C | Day 7 Dev C: Startup timeout / failure handling + FAILED write semantics + timeout behaviour.<br>Day 8 Dev C: Crash-recovery sweep + orphan cleanup + teardown idempotency hardening. |
| SM-03 | Day 6 | Dev A | Day 6 Dev A: Full `<SimulationStudioView />` overview + iteration history table + action stubs / wiring baseline. |
| SM-04 | Day 6 | Dev A | Day 6 Dev A: "Rerun with New Data" navigation + edit-mode generation prefill + locked rule/TxTp behaviour. |
| SM-05 | Day 8 | Dev A, B | Day 8 Dev A: Clone-mode wizard behaviour + locked identity fields.<br>Day 8 Dev B: `POST /suites/:id/clone-results` to copy runs/results into the cloned suite. |
| RR-01 | Day 8 | Dev B | Day 8 Dev B: Quick-rerun endpoint (`POST /suites/:id/generations/:generationId/quick-rerun`) + run insert + dispatch. |
| RR-02 | Day 8 | Dev B, A | Day 8 Dev B: Uses RR-01 backend endpoint.<br>Day 8 Dev A: Iteration-row rerun button wiring + per-row loading + refresh to show new run sub-row. |
| T-05 | — | — | Out of scope this release. No scheduled start/end and no delivery tasks in this plan. |

---

## 11. Refactors Needed in Existing Code

1. **[`rule-studio/backend/src/services/admin-service-client.ts`](../rule-studio/backend/src/services/admin-service-client.ts)** — add:
   - `getConfigByTransactionType(txtp, version, token)` *(new; admin endpoint exists)*
   - `saveIterationTransactional(suiteId, payload, token)`
   - `listSimulationSuites(filters, pagination, token)`
   - `getSuite(id, token)`, `createSuite(dto, token)`, `saveDraftProgress(id, screen, data, token)`
   - Run lifecycle helpers: `createRun`, `updateRunStatus`, `appendRunResult`, `listRuns`, `getRunStatus`, `getRunResults`, `getRunSummary`
   - `cloneSuiteResults(srcSuiteId, dstSuiteId, token)`
2. **[`rule-studio/backend/src/constants/constant.ts`](../rule-studio/backend/src/constants/constant.ts)** — add URL constants for the new admin endpoints.
3. **[`rule-studio/backend/src/app.module.ts`](../rule-studio/backend/src/app.module.ts)** — register `SimulationStudioModule`.
4. **`rule-studio/backend/package.json`** — add `dockerode`.
5. **[`rule-studio/frontend/src/components/Cards/StatusCard/Status.styles.ts`](../rule-studio/frontend/src/components/Cards/StatusCard/Status.styles.ts)** — add `DRAFT` style case.
6. **[`rule-studio/frontend/src/components/TableActions/index.tsx`](../rule-studio/frontend/src/components/TableActions/index.tsx)** — add optional `onResume?: () => void`.
7. **[`rule-studio/frontend/.env.example`](../rule-studio/frontend/.env.example)** — add `VITE_SIMULATION_STUDIO_API_URL`.
8. **[`rule-studio/frontend/src/routes/index.tsx`](../rule-studio/frontend/src/routes/index.tsx)** — six new entries under `/simulation-studio`.
9. **`rule-studio/frontend/src/redux/Store/index.ts`** — register `simulationStudioApi`.

No existing route, page, or DTO is modified beyond these additive changes. **`connection-studio/` is untouched.**

---

## 12. Risks / Blockers

| # | Risk | Owner | When |
|---|---|---|---|
| R1 | Docker Hub namespace and service-account token rotation policy must be confirmed for HK-05 before any S1-01 work can be tested end-to-end. | Platform | Before Day 1 merge |
| R2 | Rule processor image availability in Docker Hub. T-05 is out of scope; the platform team must confirm at least one image is pullable under the agreed naming convention before Day 5. | Platform | Before Day 5 |
| R3 | The `tcs_config.status` values that mark a TXTP as simulation-ready (`STATUS_04_APPROVED`, `STATUS_06_EXPORTED`) need product confirmation before S1-01 ships the TXTP picker. | Product | Before S1-01 |
| R4 | Advisory-lock key collision risk on `hashtext(suite_id::text || ':' || generation_id::text)`. Hash collisions on a 64-bit hashtext of two integers are vanishingly unlikely, but the convention should be reviewed at code review. | Backend | Code review |

---

## 13. Resolved Ambiguities (Reference)

These decisions were originally open during initial planning; now decided and locked. Kept here for traceability.

### 13.1 `trs_suite_txtp_configs` — DROP
**What it was:** A second TXTP config table with a `dataset_role` discriminator overlapping `trs_suite_context_txtp_configs` + `trs_suite_trigger_txtp_configs`.
**Decision:** Drop. No reader in the codebase, no API uses it, the role-specific tables have richer columns (`message_count`, `payload_template_json`, faker config, etc.). Keeping it would force every persist to write the same thing twice with no upside.

### 13.2 `trs_suite_context_sim_payloads` — DROP
**What it was:** A child table storing the same `context_payload_json` / `trigger_payload_json` already present inline on `trs_suite_context_sim_pairs`, keyed by `payload_role`.
**Decision:** Drop. Same data, no extra fidelity. The pair row's inline JSON is canonical for both the orchestrator and the UI.

### 13.3 Run-number concurrency — advisory lock
**What it is:** Two simultaneous "quick rerun" clicks on the same generation could both compute the same `MAX(run_number)+1` and collide on the `UNIQUE (suite_id, generation_id, run_number)` constraint.
**Decision:** `pg_advisory_xact_lock(hashtext(suite_id::text || ':' || generation_id::text))` at the top of `saveIterationTransactional` and `quick-rerun`. Released automatically at commit. Cheaper than row locks, scoped exactly to the race.

### 13.4 Tenant scoping
**Decision:** Every admin handler that touches a child table joins through `trs_simulation_suites` and filters `tenant_id = $1`. Codify as a single `getSuiteOrThrow(id, tenantId)` helper used before any child read/write.

### 13.5 Docker daemon access
**Decision:** Dockerode picks the right transport from env. Dev = no env vars (defaults to `/var/run/docker.sock`). Prod = `DOCKER_HOST=tcp://...`, `DOCKER_TLS_VERIFY=1`, `DOCKER_CERT_PATH=/etc/docker/certs`. No code branching needed.

### 13.6 Suite-level `ENV_PROVISIONING` filter
**Decision:** Remove from SM-02 filter dropdown. The schema enum is correct: that state only exists on a run, not a suite. If a suite is currently provisioning, its `status` is `RUNNING`.

---

## 14. Acceptance — Definition of Done (Release-level)

- All 17 tables created by [database-migration.sql](database-migration.sql) exist on the target `simulation_studio` database with their constraints, indexes, and trigger.
- All 17 endpoints listed in §8/HK-02 are reachable on `rule-studio/backend` at `/api/v1/simulation-studio/*` and return correctly typed `400`, `401`, `403`, `404`, `409`, `422`, and `500` responses in their failure modes.
- Happy-path DTOs returned at every endpoint match the contracts in `dto/common.dto.ts` and `dto/suite.dto.ts`.
- The wizard flows end-to-end against a real rule image, producing one `trs_simulation_runs` row per Save Iteration and one `trs_simulation_run_results` row per submitted trigger, with results visible on Screen 6.
- Resume from `/simulation-studio/edit/:id` rehydrates the wizard from `metadata.wizardDraft`.
- Quick rerun creates a new run row without opening the wizard, using the same advisory lock as Save Iteration.
- Backend restart transitions any non-terminal run to `FAILED` via the T-04 crash-recovery sweep.
- All new code passes ESLint, Prettier, and Jest in `rule-studio/backend`, `rule-studio/frontend`, and `admin-service`.
- Zero new files have been added under `connection-studio/`.

---

*End of report.*
