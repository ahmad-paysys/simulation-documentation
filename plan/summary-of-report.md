# Simulation Studio — Implementation Report Summary

Full report: [implementation_report.md](implementation_report.md)

## Where the code lives

- **Backend:** `rule-studio/backend/src/services/simulation-studio/` (NestJS, top-level module alongside `services/simulation/`, `services/rules/`).
- **Frontend:** `rule-studio/frontend/src/pages/SimulationStudio/` + new RTK slice `simulationStudioApi` (env: `VITE_SIMULATION_STUDIO_API_URL`).
- **Persistence:** `admin-service/` only — new `services/simulation-studio.logic.service.ts` + `repositories/simulation/*.repository.ts`.
- **`connection-studio/` is frozen.** Zero new files. Read-only consumer at most.

## API surface (all on `/api/v1/simulation-studio` of rule-studio/backend)

17 endpoints covering suites CRUD, draft autosave, context generation, run dispatch, run status/results/summary, quick rerun, clone-with-results, registry repos/tags, and TXTP pass-through. Full list in §4 of the report.

## Database

The supplied `database-migration.sql` is a clean first-time init — HK-01's bucket→suite renames are obsolete (no such tables exist).

Required edits before applying:
1. **Drop** `trs_suite_txtp_configs` (redundant union of role-specific tables).
2. **Drop** `trs_suite_context_sim_payloads` (duplicates inline JSON on `trs_suite_context_sim_pairs`).
3. **Add** `CREATE INDEX idx_sim_suites_tenant_status_updated ON trs_simulation_suites(tenant_id, status, updated_at DESC);`

## Existing patterns being reused (no duplication)

- `AdminServiceClient` ([rule-studio/backend/src/services/admin-service-client.ts](../rule-studio/backend/src/services/admin-service-client.ts)) — extended with sim-studio methods.
- `TazamaAuthGuard` + `@RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.APPROVER)`.
- AJV is already in `rule-studio/backend` (used by parse-extract) — `ContextGenerationService` reuses it.
- `PaginatedResult<T>` from `@tazama-lf/tcs-lib`.
- Admin TXTP endpoints already exist: `/v1/admin/config/transaction-types`, `/v1/admin/config/payload/:txtp/:ver`, `/v1/admin/config/:txtp/:ver` — no new admin TXTP routes.
- Frontend: reuse `StatusCard`, `Table`, `TableActions`, `DropDown`, `BoxWrapper`, `JsonFormatter`, `Input`, `AccordianSummary`.

New shared components: `<Stepper />`, `<FieldConfigurator />` only.
New backend dependency: `dockerode` (T-02).

## Critical-path order

HK-01 (DB) → HK-02 (module skeleton) → HK-03 (FE shell) → HK-04 (draft endpoint) → HK-05 (Docker Hub auth) → per-story work.

## Resolved decisions (previously ambiguous)

| Question | Decision |
|---|---|
| Keep `trs_suite_txtp_configs`? | **Drop** — role-specific tables are sufficient. |
| Keep `trs_suite_context_sim_payloads`? | **Drop** — payloads already inline on pairs row. |
| `run_number` race on concurrent reruns? | **`pg_advisory_xact_lock` keyed by suite+generation** inside the transaction. |
| Tenant scoping on child tables? | **Always join through `trs_simulation_suites`**; one `getSuiteOrThrow(id, tenantId)` helper used everywhere. |
| Docker daemon access? | **Dockerode reads env**: dev = socket, prod = TCP+TLS via `DOCKER_HOST`/`DOCKER_TLS_VERIFY`/`DOCKER_CERT_PATH`. |
| `ENV_PROVISIONING` in SM-02 suite filter? | **Drop** — it's a run-level phase, not a suite status. |

## Still open (need product/devops, not code decisions)

- Docker Hub namespace + service account scope (HK-05).
- Which `tcs_config.status` values mean "simulation-ready" for the S1-01 TXTP picker.
- Confirmation that a rule processor image will be in Docker Hub before Day 5 (T-05 out of scope).
