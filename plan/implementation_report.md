# Simulation Studio — Authoritative Implementation Report

> **Scope:** Single-Rule Simulation, Release 4. Integration Testing is out of scope.
> **Authority:** This document supersedes `trs_story_implementation_report.original.md` where they differ.
> Cross-references: [database-migration.sql](database-migration.sql), [changes-in-plan.md](../changes-in-plan.md).

---

## 1. Codebase Baseline (Validated)

| Concern | Reality on disk | Notes |
|---|---|---|
| **Backend host for ALL new Simulation Studio code** | [rule-studio/backend/](../rule-studio/backend/) (NestJS) | Top-level module path: `rule-studio/backend/src/services/simulation-studio/`. Matches existing pattern (`services/simulation/`, `services/rules/`, etc. — see [app.module.ts](../rule-studio/backend/src/app.module.ts)). |
| **`connection-studio/`** | Frozen for this initiative | No new files. Only **read-only** consumer of any of its existing HTTP endpoints if required. The original report's `connection-studio/backend/src/simulation-studio/` path is **wrong** and was discarded. |
| **Frontend** | [rule-studio/frontend/](../rule-studio/frontend/) (Vite + React + RTK Query) | New pages under `pages/SimulationStudio/`. |
| **Admin Service** | [admin-service/](../admin-service/) (Fastify) | Owns all Postgres persistence. Repository pattern: free functions in `repositories/*.repository.ts`, called from `services/*.logic.service.ts`, handlers in `app.controller.ts`, routes in `router.ts`. New work follows this exact layout. |
| **Auth** | `TazamaAuthGuard` + `RequireAnyClaims(...)` ([rule-studio/backend/src/guards/tazama-auth.guard.ts](../rule-studio/backend/src/guards/tazama-auth.guard.ts), [decorators/auth.decorator.ts](../rule-studio/backend/src/decorators/auth.decorator.ts)) | `AuthenticatedUser` exposes `tenantId`, `userId`, `actorEmail`, `token.tokenString`. |
| **Admin client** | [rule-studio/backend/src/services/admin-service-client.ts](../rule-studio/backend/src/services/admin-service-client.ts) | All RS Backend → Admin calls go through this. Token forwarded. Already has `getTransactionTypes`, `getPayloadByTransactionType`, `getVersionsOfTransactionType`. |
| **Existing TXTP endpoints in admin-service** | `/v1/admin/config/transaction-types`, `/v1/admin/config/payload/:txtp/:ver`, `/v1/admin/config/:txtp/:ver` | Confirmed in [admin-service/src/router.ts](../admin-service/src/router.ts) lines 257–267. Pass-through only — no new admin TXTP routes. |
| **`tcs_config` filter** | Column is `status`. `findAllTransactionTypes` filters `status IN ('STATUS_04_APPROVED','STATUS_06_EXPORTED')`. | Plan's "`activated`" column does not exist. |
| **`id` convention** | Existing TRS tables use `serial4` PK ([rule-studio/database/init/01-create-tables.sql](../rule-studio/database/init/01-create-tables.sql)). | Migration uses `BIGSERIAL`. Keep `BIGSERIAL` for sim tables (volume) — TS contracts treat as `number`. |
| **No legacy simulation suites in DB** | No `trs_simulation_*` / `trs_bucket_*` tables exist. | Migration is **net-new**, not a rename. HK-01's "bucket → suite" rename steps are obsolete. |
| **AJV** | Already in `rule-studio/backend` ([services/parse-extract/parse-extract.service.ts](../rule-studio/backend/src/services/parse-extract/parse-extract.service.ts)) and in `package.json`. | `ContextGenerationService` AJV cache lives here. Admin-service has no AJV. |
| **Dockerode** | **Not** in `rule-studio/backend/package.json` | Must be added as a dependency for T-02. |
| **No websocket** | No NestJS gateway carries sim events. | All run-progress UX is polling. |
| **Frontend env** | [rule-studio/frontend/.env.example](../rule-studio/frontend/.env.example) already has `VITE_SANDBOX_API_URL` | Add `VITE_SIMULATION_STUDIO_API_URL`. The new RTK slice uses this. |

---

## 2. Top-Level Architecture Decisions

1. **All new APIs are under `/api/v1/simulation-studio/*` on `rule-studio/backend`.** Legacy `/simulation` and `/rerun-simulation` modules in rule-studio backend stay untouched.
2. **NestJS module path:** `rule-studio/backend/src/services/simulation-studio/` (top-level service module, mirroring `services/simulation/`, `services/rules/`, etc.).
3. **All persistence in admin-service.** RS Backend never queries `simulation_studio` DB directly; it calls admin-service via `AdminServiceClient`. New admin module: `admin-service/src/services/simulation-studio.logic.service.ts` + `admin-service/src/repositories/simulation/*.repository.ts`.
4. **Frontend:** new RTK Query slice `simulationStudioApi` at `rule-studio/frontend/src/redux/Api/SimulationStudio/index.ts`. New env var `VITE_SIMULATION_STUDIO_API_URL`.
5. **Reuse, don't duplicate, components:** `<Stepper />` and `<FieldConfigurator />` are the only new shared components. Reuse `StatusCard`, `Table`, `TableActions`, `DropDown`, `BoxWrapper`, `JsonFormatter`, `Input`, `AccordianSummary`.
6. **Run dispatch is fire-and-forget**; UI polls `runs/:runId/status` every 2 s.
7. **No code in `connection-studio/`.** Period.

---

## 3. Database (PostgreSQL `simulation_studio`)

[database-migration.sql](database-migration.sql) is a **first-time init** (`BEGIN; CREATE TABLE …; COMMIT;`). HK-01's "bucket → suite rename" steps are **obsolete**.

### 3.1 Resolved decisions (was §9 in v1; these are now locked)

| Decision | Outcome | Rationale (short) |
|---|---|---|
| **`trs_suite_txtp_configs` (generic union table)** | **DROP from migration.** | Role-specific tables (`trs_suite_context_txtp_configs`, `trs_suite_trigger_txtp_configs`) are sufficient and have richer columns. The union table is dead schema — no consumer reads it. Carrying it doubles every TXTP write. See §9.1 below. |
| **`trs_suite_context_sim_payloads` (child table)** | **DROP from migration.** | `trs_suite_context_sim_pairs` already stores `context_payload_json` and `trigger_payload_json` inline. The child adds a redundant copy with no extra information. See §9.2. |
| **`run_number` concurrency** | **Advisory lock per `(suite_id, generation_id)` inside `saveIterationTransactional` / `quick-rerun`.** | Simpler than `SELECT FOR UPDATE` on a parent row, scoped exactly to the race, and Postgres-native (`pg_advisory_xact_lock`). See §9.3. |
| **Tenant scoping on children** | **Always join through `trs_simulation_suites` and filter `tenant_id = $1`.** Enforced as a SQL-review rule and codified in a single repo helper. | The schema deliberately keeps `tenant_id` only on the root aggregate — denormalising it everywhere would create drift risk. See §9.4. |
| **Docker daemon access** | **Dev: Unix socket (`/var/run/docker.sock`). Prod: remote TCP+TLS via `DOCKER_HOST` + cert paths.** Both are supported by Dockerode using the same env vars; `RegistryService` is unaffected. | Standard Dockerode pattern. The "decision" is just a deployment toggle. See §9.5. |
| **Suite-level `ENV_PROVISIONING`** | **Drop from the SM-02 status filter.** | The suite-level `status` enum is `DRAFT/RUNNING/COMPLETED/FAILED/ARCHIVED`. `ENV_PROVISIONING` is a *run-level* phase. Showing it on the suite filter would require either joining the active run on every list query or expanding the suite enum — both are worse than just removing the option. See §9.6. |

### 3.2 Schema changes vs. the supplied SQL

Apply these edits before running [database-migration.sql](database-migration.sql):

1. **Remove** the entire `trs_suite_txtp_configs` block (the table + its index + its comment).
2. **Remove** the entire `trs_suite_context_sim_payloads` block (the table + its index).
3. **Add** the composite index for SM-02 list query:
   ```sql
   CREATE INDEX idx_sim_suites_tenant_status_updated
     ON public.trs_simulation_suites(tenant_id, status, updated_at DESC);
   ```
4. (Optional / nice-to-have) Add a 256 KB cap on `metadata` enforced application-side in `PUT /draft`.

Everything else in the migration is sound.

### 3.3 Tables required for the in-scope stories

After the §3.2 edits:
- Aggregate: `trs_simulation_suites`, `trs_suite_generations`
- Context: `trs_suite_context_txtp_configs`, `trs_suite_context_field_strategies`, `trs_suite_context_generated_messages`
- Trigger: `trs_suite_trigger_txtp_configs`, `trs_suite_trigger_field_overrides`, `trs_suite_trigger_generated_messages`
- Enrichment: `trs_suite_enrichment_tables`, `trs_suite_enrichment_field_strategies`, `trs_suite_enrichment_generated_rows`
- Pairing: `trs_suite_context_sim_pairs` *(payloads inline)*
- Run lifecycle: `trs_simulation_runs`, `trs_simulation_run_events`, `trs_simulation_run_results`, `trs_simulation_run_result_context_links`, `trs_simulation_run_artifacts`

### 3.4 Deferred (do not deploy this release)

`trs_suite_dems_function_records`, `trs_integration_run_results`, `trs_integration_evaluations` — Integration Testing scope.

---

## 4. Shared Contracts (Reusable)

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

## 5. Cross-Cutting Implementation Order

Critical path before any story work:

1. **HK-01** — Apply [database-migration.sql](database-migration.sql) to a `simulation_studio` database after the §3.2 edits.
2. **HK-02** — Backend `simulation-studio` module skeleton at `rule-studio/backend/src/services/simulation-studio/`. Register in `AppModule.imports`. Stub handlers throw `NotImplementedException`.
3. **HK-03** — Frontend scaffolding: routes, RTK slice, `<Stepper />`, `<FieldConfigurator />`, list/wizard skeletons. Extend `StatusCard` `getStatusStyles` with a `DRAFT` case.
4. **HK-04** — `PUT /suites/:id/draft` endpoint + admin handler (`jsonb_set` UPDATE).
5. **HK-05** — Docker Hub auth env vars + `RegistryService`.

Story work (SM-01 … SR-03, T-01 … T-04, RR-01/RR-02, SM-05) then proceeds per the original `trs_story_implementation_report.original.md` schedule, against this report's contracts.

---

## 6. Per-Story Validation (Deltas Only)

Where omitted, the original story plan stands.

### HK-01 — DB migration ([orig](trs_story_implementation_report.original.md#hk-01--database-schema-migration))
- No bucket → suite renames. Treat the migration as clean first-time create. Skip Step 1 entirely.
- Apply edits in §3.2.

### HK-02 — Backend Module ([orig](trs_story_implementation_report.original.md#hk-02--rs-backend-nestjs-module-scaffolding))
- **Module path is `rule-studio/backend/src/services/simulation-studio/`.** Original report's `connection-studio/backend/...` path is wrong and overridden by this report.
- `AdminServiceClient` is already a provider; extend it with new methods (see §7) — do not create a second client.

### HK-03 — Frontend Scaffolding ([orig](trs_story_implementation_report.original.md#hk-03--frontend-project-scaffolding))
- Confirmed missing: `Stepper`, `FieldConfigurator` — create.
- `useFilters` exists at `rule-studio/frontend/src/hooks/useFilters.ts`.
- Add `VITE_SIMULATION_STUDIO_API_URL` to [.env.example](../rule-studio/frontend/.env.example).

### HK-04 — Draft persistence ([orig](trs_story_implementation_report.original.md#hk-04--per-screen-draft-persistence-infrastructure))
- Plan's `jsonb_set` SQL is correct. Cap `data` size at the handler boundary (256 KB).

### HK-05 — Docker Hub auth ([orig](trs_story_implementation_report.original.md#hk-05--docker-hub-authentication))
- Env vars added to a validation module if rule-studio backend has one; otherwise consumed directly via `ConfigService.get`. (The legacy connection-studio `env.validation.ts` is **not** the target.)

### SM-01 — Create suite + wizard ([orig](trs_story_implementation_report.original.md#sm-01--create-a-new-simulation-suite-via-simulation-studio))
- Stepper has **5** steps; Screen 6 is post-stepper (canon §4).
- `ContextGenerationService` AJV cache local to `rule-studio/backend` (already an AJV consumer).

### SM-02 — List ([orig](trs_story_implementation_report.original.md#sm-02--view-all-simulation-suites-in-a-searchable-list))
- `PaginatedResult<T>` from `@tazama-lf/tcs-lib` — reuse.
- Drop `ENV_PROVISIONING` from suite-status filter (§3.1 decision).

### S1-01 / S1-02 — Rule + metadata ([orig](trs_story_implementation_report.original.md#s1-01--select-a-rule-and-transaction-version-for-the-suite))
- `tcs_config` filter is `status IN ('STATUS_04_APPROVED','STATUS_06_EXPORTED')` — open question: confirm with product team which `status` value(s) make a TXTP "simulation-ready" (canon §13).

### S2-01 — Context data ([orig](trs_story_implementation_report.original.md#s2-01--configure-context-data))
- Three RS endpoints fan out to admin's `getConfigByTransactionType`. Add it to `AdminServiceClient` (a sibling of the existing `getPayloadByTransactionType`).
- Persist nothing to child tables on Next — only `metadata.wizardDraft.screen2`.

### S3-01 — Trigger data ([orig](trs_story_implementation_report.original.md#s3-01--configure-and-preview-simulation-trigger-transactions))
- 15-message cap enforced server-side inside `saveIterationTransactional`.

### S4-01 — Enrichment ([orig](trs_story_implementation_report.original.md#s4-01--define-one-or-more-enrichment-tables))
- Reuse `validateTableName` at [admin-service/src/utils/enrichment-utils.ts](../admin-service/src/utils/enrichment-utils.ts) in both `PUT /draft` validation and `saveIterationTransactional`.

### S5-01 — Summary + save ([orig](trs_story_implementation_report.original.md#s5-01--review-the-full-suite-summary-before-saving))
- No new contracts.

### T-01 — Persist + dispatch ([orig](trs_story_implementation_report.original.md#t-01--atomically-persist-wizard-data-and-dispatch-orchestrator-on-run))
- Single admin handler `handleSaveIterationTransactional`: open a pg transaction, `pg_advisory_xact_lock(hashtext(suite_id||generation_id))`, compute next `run_number`, insert all rows, commit.
- Dispatch is fire-and-forget in the controller (`void this.orchestratorService.dispatch(runId)`).

### T-02 — Orchestrator ([orig](trs_story_implementation_report.original.md#t-02--orchestrate-an-isolated-docker-container-lifecycle-per-run))
- Add `dockerode` to `rule-studio/backend/package.json`.
- Daemon: socket in dev, TCP+TLS in prod via env (§3.1 decision).
- Pin image by SHA256 digest from `RegistryService.verifyImage()` at dispatch time.
- All containers labelled `run_id=<id>` for T-04 crash recovery.

### T-03 — Per-transaction result write ([orig](trs_story_implementation_report.original.md#t-03--persist-one-result-row-per-sim-transaction))
- One `INSERT INTO trs_simulation_run_results` per transaction immediately after nats-utilities response.
- `…/status` returns `partialResults` for future streaming use; today Screen 6 only displays on terminal state.

### T-04 — Failure & recovery ([orig](trs_story_implementation_report.original.md#t-04--handle-container-startup-failures-and-run-timeouts-gracefully))
- Crash-recovery scan keyed off the `run_id` Docker label (set in T-02).

### SR-01 / SR-02 / SR-03 — Results UI ([orig](trs_story_implementation_report.original.md#sr-01--run-a-simulation-and-observe-results-upon-completion))
- 2 s polling cadence; stop on terminal state.
- Stat cards (Total Iterations, Latest Success Rate, Total Messages Processed, Active Dataset) served by **dedicated** `GET /suites/:id/runs/summary` — cleaner cache invalidation than overloading the list response.

### SM-03 / SM-04 / SM-05 — Detail / rerun / clone ([orig](trs_story_implementation_report.original.md#sm-03--view-suite-details-and-iteration-history))
- Clone-with-results runs in one admin transaction copying `trs_simulation_runs` + `trs_simulation_run_results` + `trs_simulation_run_result_context_links`.

### RR-01 / RR-02 — Quick rerun ([orig](trs_story_implementation_report.original.md#rr-01--rerun-a-past-iteration-from-simulation-result-page))
- Rebuild `SingleRuleEnvSpec` from persisted generation rows.
- Run-number race: same advisory lock as T-01.

---

## 7. Refactors Needed in Existing Code

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

## 8. Risks / Blockers

| # | Risk | Owner | When |
|---|---|---|---|
| R1 | Docker Hub namespace + token rotation policy (HK-05 §15.3) | Platform | Before Day 1 merge |
| R2 | Rule processor image availability for first run (T-05 out of scope) | Platform | Before Day 5 |
| R3 | `tcs_config.status` filter values for "simulation-ready" TXTPs | Product | Before S1-01 |
| R4 | Advisory-lock key collision (hash of two ints is very low risk) | Backend | Code review |

---

## 9. Resolved Ambiguities (Reference)

Originally listed as open in v1; now decided. Kept here for traceability.

### 9.1 `trs_suite_txtp_configs` — DROP
**What it was:** A second TXTP config table with a `dataset_role` discriminator overlapping `trs_suite_context_txtp_configs` + `trs_suite_trigger_txtp_configs`.
**Decision:** Drop. No reader in the codebase, no API uses it, the role-specific tables have richer columns (`message_count`, `payload_template_json`, faker config, etc.). Keeping it would force every persist to write the same thing twice with no upside.

### 9.2 `trs_suite_context_sim_payloads` — DROP
**What it was:** A child table storing the same `context_payload_json` / `trigger_payload_json` already present inline on `trs_suite_context_sim_pairs`, keyed by `payload_role`.
**Decision:** Drop. Same data, no extra fidelity. The pair row's inline JSON is canonical for both the orchestrator and the UI.

### 9.3 Run-number concurrency — advisory lock
**What it is:** Two simultaneous "quick rerun" clicks on the same generation could both compute the same `MAX(run_number)+1` and collide on the `UNIQUE (suite_id, generation_id, run_number)` constraint.
**Decision:** `pg_advisory_xact_lock(hashtext(suite_id::text || ':' || generation_id::text))` at the top of `saveIterationTransactional` and `quick-rerun`. Released automatically at commit. Cheaper than row locks, scoped exactly to the race.

### 9.4 Tenant scoping
**Decision:** Every admin handler that touches a child table joins through `trs_simulation_suites` and filters `tenant_id = $1`. Codify as a single `getSuiteOrThrow(id, tenantId)` helper used before any child read/write.

### 9.5 Docker daemon access
**Decision:** Dockerode picks the right transport from env. Dev = no env vars (defaults to `/var/run/docker.sock`). Prod = `DOCKER_HOST=tcp://...`, `DOCKER_TLS_VERIFY=1`, `DOCKER_CERT_PATH=/etc/docker/certs`. No code branching needed.

### 9.6 Suite-level `ENV_PROVISIONING` filter
**Decision:** Remove from SM-02 filter dropdown. The schema enum is correct: that state only exists on a run, not a suite. If a suite is currently provisioning, its `status` is `RUNNING`.

---

## 10. Acceptance — Definition of Done (Release-level)

- All migrations in [database-migration.sql](database-migration.sql) (after §3.2 edits) applied to `simulation_studio`.
- All 17 endpoints in §4 reachable on `rule-studio/backend`; each returns 401/403/400/404 in their failure modes; happy paths produce expected DTOs.
- Wizard flows end-to-end against a real rule image, producing one `trs_simulation_runs` row per Save Iteration, one `trs_simulation_run_results` row per submitted trigger, results visible in Screen 6.
- Resume from `/simulation-studio/edit/:id` rehydrates wizard from `metadata.wizardDraft`.
- Quick rerun creates a new run row without re-opening the wizard.
- Backend restart transitions any non-terminal run to `FAILED`.
- All new code passes ESLint, Prettier, Jest in `rule-studio/backend`, `rule-studio/frontend`, and `admin-service`.
- **Zero new files** in `connection-studio/`.

---

*End of report.*
