# TRS Simulation Sandbox — Per-Story Implementation Report
<a id="top"></a>

> **⚠️ SUPERSEDED BY [implementation_report.md](implementation_report.md).** This document is kept verbatim as the original input. Where it differs from `implementation_report.md`, the latter wins. Notably: this report points new code at `connection-studio/backend/src/simulation-studio/` — that path is **wrong**; all new Simulation Studio code lives in `rule-studio/backend/src/services/simulation-studio/`. The HK-01 "bucket → suite" rename steps are also obsolete (no bucket tables exist).

## Release 4 · Rev 2.2 · Single-Rule Simulation Scope

**Integration Testing is excluded from this delivery. All stories and tasks in this report cover the Single-Rule Simulation path only.**

> **Terminology — Suite vs Bucket:** The domain model previously referred to the top-level simulation entity as a "bucket." This is renamed to **suite** throughout the application, API, and database. All `trs_simulation_buckets` table references become `trs_simulation_suites`; associated tables are renamed accordingly. See HK-01 for the full migration detail.

> **Step numbering corrections:** The updated user stories carry step numbers from an earlier draft that included an extra integration testing screen since removed. The corrected six-screen numbering applied throughout this document is: **Screen 1** Rule+TxTp+Metadata · **Screen 2** Context Data · **Screen 3** Trigger Data · **Screen 4** Enrichment · **Screen 5** Summary+Run · **Screen 6** Results. S2-01 is listed in the user stories as "Add and configure TXTPs" but covers Context Data (Screen 2) — the team has been asked to update the title. S4-01's "Step 5" and S5-01's "Step 6" references in the user stories are artefacts of the removed screen and are corrected to Steps 4 and 5 here.

> **Sections §6, §7, and §9 of the Implementation Plan** are flagged for refinement by Copilot with codebase access. API endpoint names and service method signatures must be validated against the live codebase before sprint start.

---

### Working Day Calendar

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

---

### Story Index by Date

Use these linked indexes to jump directly to stories by planned start date or end date.

#### By Start Date

| Start Date | Stories |
|------------|---------|
| 21 May | [HK-03 — Frontend Project Scaffolding](#hk-03--frontend-project-scaffolding)<br>[SM-01 — Create a New Simulation Suite via Simulation Studio](#sm-01--create-a-new-simulation-suite-via-simulation-studio)<br>[SM-02 — View All Simulation Suites in a Searchable List](#sm-02--view-all-simulation-suites-in-a-searchable-list)<br>[HK-02 — RS Backend NestJS Module Scaffolding](#hk-02--rs-backend-nestjs-module-scaffolding)<br>[HK-05 — Docker Hub Authentication](#hk-05--docker-hub-authentication)<br>[S1-01 — Select a Rule and Transaction Version for the Suite](#s1-01--select-a-rule-and-transaction-version-for-the-suite)<br>[HK-04 — Per-Screen Draft Persistence Infrastructure](#hk-04--per-screen-draft-persistence-infrastructure)<br>[HK-01 — Database Schema Migration](#hk-01--database-schema-migration)<br>[T-01 — Atomically Persist Wizard Data and Dispatch Orchestrator on Run](#t-01--atomically-persist-wizard-data-and-dispatch-orchestrator-on-run) |
| 22 May | [S1-02 — Define Suite Metadata](#s1-02--define-suite-metadata)<br>[S2-01 — Configure Context Data](#s2-01--configure-context-data) |
| 25 May | [S3-01 — Configure and Preview Simulation Trigger Transactions](#s3-01--configure-and-preview-simulation-trigger-transactions) |
| 29 May | [S4-01 — Define One or More Enrichment Tables](#s4-01--define-one-or-more-enrichment-tables)<br>[S5-01 — Review the Full Suite Summary Before Saving](#s5-01--review-the-full-suite-summary-before-saving) |
| 01 Jun | [SR-01 — Run a Simulation and Observe Results Upon Completion](#sr-01--run-a-simulation-and-observe-results-upon-completion)<br>[T-02 — Orchestrate an Isolated Docker Container Lifecycle Per Run](#t-02--orchestrate-an-isolated-docker-container-lifecycle-per-run) |
| 02 Jun | [T-03 — Persist One Result Row Per Sim Transaction](#t-03--persist-one-result-row-per-sim-transaction)<br>[SM-03 — View Suite Details and Iteration History](#sm-03--view-suite-details-and-iteration-history)<br>[SM-04 — Run a New Iteration in an Existing Suite](#sm-04--run-a-new-iteration-in-an-existing-suite) |
| 03 Jun | [SR-02 — View Simulation Results with Band-Coded Outcome Per Transaction](#sr-02--view-simulation-results-with-band-coded-outcome-per-transaction)<br>[SR-03 — Search and Filter Simulation History](#sr-03--search-and-filter-simulation-history)<br>[T-04 — Handle Container Startup Failures and Run Timeouts Gracefully](#t-04--handle-container-startup-failures-and-run-timeouts-gracefully) |
| 04 Jun | [SM-05 — Clone an Existing Suite](#sm-05--clone-an-existing-suite)<br>[RR-01 — Rerun a Past Iteration from Simulation Result Page](#rr-01--rerun-a-past-iteration-from-simulation-result-page)<br>[RR-02 — Rerun a Past Iteration from Simulation Suite History](#rr-02--rerun-a-past-iteration-from-simulation-suite-history) |

#### By End Date

| End Date | Stories |
|----------|---------|
| 21 May | [HK-03 — Frontend Project Scaffolding](#hk-03--frontend-project-scaffolding)<br>[HK-02 — RS Backend NestJS Module Scaffolding](#hk-02--rs-backend-nestjs-module-scaffolding)<br>[HK-05 — Docker Hub Authentication](#hk-05--docker-hub-authentication)<br>[HK-01 — Database Schema Migration](#hk-01--database-schema-migration) |
| 22 May | [S1-01 — Select a Rule and Transaction Version for the Suite](#s1-01--select-a-rule-and-transaction-version-for-the-suite)<br>[S1-02 — Define Suite Metadata](#s1-02--define-suite-metadata)<br>[HK-04 — Per-Screen Draft Persistence Infrastructure](#hk-04--per-screen-draft-persistence-infrastructure)<br>[S2-01 — Configure Context Data](#s2-01--configure-context-data) |
| 25 May | [S3-01 — Configure and Preview Simulation Trigger Transactions](#s3-01--configure-and-preview-simulation-trigger-transactions) |
| 29 May | [SM-01 — Create a New Simulation Suite via Simulation Studio](#sm-01--create-a-new-simulation-suite-via-simulation-studio)<br>[S4-01 — Define One or More Enrichment Tables](#s4-01--define-one-or-more-enrichment-tables)<br>[S5-01 — Review the Full Suite Summary Before Saving](#s5-01--review-the-full-suite-summary-before-saving) |
| 01 Jun | [SM-02 — View All Simulation Suites in a Searchable List](#sm-02--view-all-simulation-suites-in-a-searchable-list)<br>[T-01 — Atomically Persist Wizard Data and Dispatch Orchestrator on Run](#t-01--atomically-persist-wizard-data-and-dispatch-orchestrator-on-run) |
| 02 Jun | [T-03 — Persist One Result Row Per Sim Transaction](#t-03--persist-one-result-row-per-sim-transaction)<br>[SM-03 — View Suite Details and Iteration History](#sm-03--view-suite-details-and-iteration-history)<br>[SM-04 — Run a New Iteration in an Existing Suite](#sm-04--run-a-new-iteration-in-an-existing-suite) |
| 03 Jun | [SR-01 — Run a Simulation and Observe Results Upon Completion](#sr-01--run-a-simulation-and-observe-results-upon-completion)<br>[SR-02 — View Simulation Results with Band-Coded Outcome Per Transaction](#sr-02--view-simulation-results-with-band-coded-outcome-per-transaction)<br>[SR-03 — Search and Filter Simulation History](#sr-03--search-and-filter-simulation-history) |
| 04 Jun | [T-02 — Orchestrate an Isolated Docker Container Lifecycle Per Run](#t-02--orchestrate-an-isolated-docker-container-lifecycle-per-run)<br>[T-04 — Handle Container Startup Failures and Run Timeouts Gracefully](#t-04--handle-container-startup-failures-and-run-timeouts-gracefully)<br>[SM-05 — Clone an Existing Suite](#sm-05--clone-an-existing-suite)<br>[RR-01 — Rerun a Past Iteration from Simulation Result Page](#rr-01--rerun-a-past-iteration-from-simulation-result-page)<br>[RR-02 — Rerun a Past Iteration from Simulation Suite History](#rr-02--rerun-a-past-iteration-from-simulation-suite-history) |

#### Undated Story

| Story | Note |
|-------|------|
| [T-05 — Push Rule Processor Image to Registry on Deployment](#t-05--push-rule-processor-image-to-registry-on-deployment) | Marked out of scope in this report and does not include a scheduled start/end date. |

---

> **Pre-story housekeeping — required before SM-01 and SM-02 can begin.** The work below is Day 1 frontend infrastructure with no user story of its own. SM-01 (wizard shell) and SM-02 (list page shell) both depend on routing and shared component availability from the moment their Day 1 tasks start.

## HK-03 — Frontend Project Scaffolding
[Back to Top](#top)

**Day:** 1 (21 May) | **Owner:** Dev A

> Simulation Studio lives **inside Rule Studio** as a new, isolated set of pages under `rule-studio/frontend/src/pages/SimulationStudio/` mounted at the `/simulation-studio` route prefix. It is never a standalone app and it is **not** built on top of the legacy `pages/Simulation*` pages or the legacy `/simulation` routes — those remain untouched. See [changes-in-plan.md](changes-in-plan.md) §1–§3, §9 for the canonical naming and isolation decisions.

### Route Configuration

Six routes must be added to [rule-studio/frontend/src/routes/index.tsx](rule-studio/frontend/src/routes/index.tsx) on Day 1, alongside (not replacing) the existing `/simulation*` entries:

```
/simulation-studio                       → <SimulationStudioList />
/simulation-studio/create                → <SimulationStudioWizard />   (mode=create)
/simulation-studio/edit/:id              → <SimulationStudioWizard />   (mode=edit, new iteration / resume draft)
/simulation-studio/clone/:id             → <SimulationStudioWizard />   (mode=clone)
/simulation-studio/view/:id              → <SimulationStudioView />
/simulation-studio/view/:id/run/:runId   → <SimulationStudioView />     (deep-link to specific run)
```

All entries use `private: true`, `layout: true`, `roleGroup: 'trs' as const` to match the existing pattern. The legacy `/simulation`, `/simulation/create`, `/simulation/view/:id`, and `/simulation/error` routes stay registered and unchanged.

### Page Directory Layout

```
rule-studio/frontend/src/pages/SimulationStudio/
├── List/        → <SimulationStudioList />
├── Wizard/      → <SimulationStudioWizard />  (Screens 1–5 + post-run Screen 6 child)
└── View/        → <SimulationStudioView />
```

No files are created under `pages/Simulation/`, `pages/SimulationList/`, or `pages/SimulationView/` — those remain the legacy module.

### `<SimulationStudioWizard />` Shell

The wizard shell manages the current screen index, Next/Back navigation, and per-screen validation gating. It is the single component used by the create, edit, and clone routes — `mode: 'create' | 'edit' | 'clone'` is derived from the active route. This shell must exist on Day 1 as a bare skeleton so SM-01's Day 1 work can begin on top of it.

Key responsibilities of the shell:
- Screen index state: `currentScreen: 0..4` for the **five** Next/Back screens (Rule + TxTp · Context Data · Trigger Data · Enrichment · Summary). Screen 6 (Results) is rendered post-run by a `<Screen6Results />` child mounted after `POST /run` — it is **not** part of the stepper count.
- `canProceed` flag per screen — Next is disabled until the active screen signals valid via a `validate()` callback exposed by each screen component
- Back navigation: previous screen, or `/simulation-studio` if on Screen 1
- Mode detection from route params (`/create` vs `/edit/:id` vs `/clone/:id`)
- Render the `<Stepper />` component with the five labelled steps

### `<Stepper />` Component

A horizontal step indicator showing the five wizard step names. Current step highlighted; completed steps show a check mark. Dumb presentational component receiving `currentStep: number` and `steps: string[]` as props. New file: `rule-studio/frontend/src/components/Stepper/index.tsx`. Confirmed not present in [rule-studio/frontend/src/components](rule-studio/frontend/src/components).

### Navigation Guard

`useBlocker` (React Router **v7** — already a dependency in [rule-studio/frontend/package.json](rule-studio/frontend/package.json)) must be configured within `<SimulationStudioWizard />` to intercept navigation away from the wizard when the current screen has uncommitted edits. `window.beforeunload` handles browser-tab close. These guards protect **only the current screen's uncommitted changes** — all previously completed screens are safe in `wizardDraft` server-side (see HK-04).

### RTK Query API Slice

A **new** RTK Query slice `simulationStudioApi` is created at `rule-studio/frontend/src/redux/Api/SimulationStudio/index.ts` and registered in [rule-studio/frontend/src/redux/Store/index.ts](rule-studio/frontend/src/redux/Store/index.ts) alongside the other slices. The legacy `simulationApi` at [rule-studio/frontend/src/redux/Api/Simulation/index.ts](rule-studio/frontend/src/redux/Api/Simulation/index.ts) is **not** modified.

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

Day 1 also adds `VITE_SIMULATION_STUDIO_API_URL=` to [rule-studio/frontend/.env.example](rule-studio/frontend/.env.example).

Cache invalidation rules:
- `POST /suites` invalidates `SuiteList`
- `PUT /suites/:id/draft` invalidates `Suite` for that id
- `POST /suites/:id/run` invalidates `Suite`, `SuiteList`, and `Run` lists
- `POST /suites/:id/generations/:generationId/quick-rerun` invalidates `Run` lists for that suite

### `<FieldConfigurator />` Shared Component

Used by Screen 2 (S2-01 Context Data). Built as a shared component at `rule-studio/frontend/src/components/FieldConfigurator/index.tsx`, not inline per screen. It accepts a TXTP JSON schema and renders per-field rows. Each row shows: field name (left), strategy selector (right). Strategy options per the user stories: **Keep sample value**, **Static value** (sub-option: value input), **Skip field**. This component is a blocking dependency for S2-01 on Day 2.

### Status Badge — Reuse Existing `<StatusCard />`

The existing `<StatusCard />` at [rule-studio/frontend/src/components/Cards/StatusCard/index.tsx](rule-studio/frontend/src/components/Cards/StatusCard/index.tsx) is reused directly — no new badge component is created. Its style map at [rule-studio/frontend/src/components/Cards/StatusCard/Status.styles.ts](rule-studio/frontend/src/components/Cards/StatusCard/Status.styles.ts) already supports `RUNNING`, `COMPLETED`, `Completed`, `FAILED`, `Failed`. **Day 1 task: add a `DRAFT` case** (and `ENV_PROVISIONING` if used as a distinct status) to `getStatusStyles` so the same component can be used on suite list rows and run status displays.

`<SimulationTypeBadge />` is **not built**. Integration Testing is out of scope for this delivery, so all suites are SINGLE_RULE and a type badge would always display the same value.

### `<SimulationStudioList />` Skeleton

A bare page shell at `rule-studio/frontend/src/pages/SimulationStudio/List/index.tsx` modelled on the existing [rule-studio/frontend/src/pages/SimulationList/index.tsx](rule-studio/frontend/src/pages/SimulationList/index.tsx) and [rule-studio/frontend/src/pages/Home/index.tsx](rule-studio/frontend/src/pages/Home/index.tsx) patterns: `<BoxWrapper />`, page title "Simulation Studio", subtitle, "Create Simulation Suite" CTA wired to `/simulation-studio/create`, `<SuspenseLoader />` initial state, empty state, and `<Table />` placeholder. Full list implementation (search, filters, columns per SM-02 user story) is built on Day 5 in SM-02. Skeleton must exist on Day 1 so routing tests do not break.

---

## SM-01 — Create a New Simulation Suite via Simulation Studio
[Back to Top](#top)

**Start:** 21 May | **End:** 29 May

### Overview

SM-01 covers the six-screen wizard creation flow — the container, stepper navigation, inter-screen state management, and the context data generation call (`POST /generate/context`) which has no standalone story of its own. Individual screen content is covered by S1-01, S1-02, S2-01, S3-01, S4-01, and S5-01. SM-01 owns the frame they all live in. Per §4.1, every screen's Next action persists data server-side via `PUT /suites/:id/draft` (HK-04), so the wizard survives disconnects at any point.

### Frontend — `<SimulationStudioWizard />` Wizard Container

The container is built at `rule-studio/frontend/src/pages/SimulationStudio/Wizard/index.tsx` (greenfield — does not touch the legacy [rule-studio/frontend/src/pages/Simulation/index.tsx](rule-studio/frontend/src/pages/Simulation/index.tsx)).

- Screen index management: `currentScreen: 0..4` advances on each validated Next, decrements on Back. The Results screen (Screen 6 in the user stories) is rendered post-run by a `<Screen6Results />` child mounted after `POST /run` returns a `runId` — it is **not** part of the stepper count
- **Per-screen validation gate:** Next button disabled until the active screen emits a valid signal. Each screen component exposes a `validate()` callback that the container calls
- **Resume mode:** on load of `/simulation-studio/edit/:id`, the container fetches the suite (`GET /api/v1/simulation-studio/suites/:id`) and reads `metadata.wizardDraft` to reconstruct each screen's state. `wizard_progress` determines which screen to open at
- **"Save as Draft"** available from Screen 5 (S5-01): persists the suite as DRAFT and returns to the list (`/simulation-studio`)
- Creation flow exits into Screen 6 (Results) after `POST /run` is called from Screen 5
- **Context data generation:** after Screen 2 (S2-01) Next, the wizard calls `POST /generate/context` before advancing to Screen 3. This generates context rows from the field strategies configured in Screen 2. The "Preview Data" button in S2-01 calls the same endpoint with `count=5` for an inline preview

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/simulation-studio/suites/:id` | Fetch suite + `wizardDraft` on resume, edit, or clone load. Returns suite row + `generations[]` + `metadata.wizardDraft`. |
| POST | `/api/v1/simulation-studio/suites/:id/generate/context` | Generate context rows from Screen 2 field configs. Body: `GenerateContextDto` — `{ txtpConfigs: Array<{ txtp: string; version: string; fieldConfig: Record<string, FieldStrategy>; count: number }> }`. Query param `count` overrides per-txtp count for preview: 5 for preview, omitted for full Next-flow count. Returns `{ rows: Array<{ txtp: string; version: string; payload: object }> }`. Does not persist — caller stores in wizardDraft via `PUT /draft`. |

Both endpoints are added to the new `simulationStudioApi` RTK Query slice (HK-03) and require `Authorization: Bearer <token>`. Error responses follow the existing Nest exception filter conventions: `400` (validation), `401` (missing/invalid token), `403` (RBAC fail — non-`trs` claim), `404` (suite not found or wrong tenant), `422` (schema validation failure on generated row, AJV error path in `errors[]`), `500` (admin-service failure or unexpected).

### RS Backend — `ContextGenerationService` (NEW)

Lives at `connection-studio/backend/src/simulation-studio/context/context-generation.service.ts`. Owns the schema cache and the generation algorithm.

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
  ): Promise<{ rows: ContextRowDto[] }> { /* ... */ }

  private async getValidator(txtp: string, version: string, tenantId: string, token: string): Promise<ValidateFunction> {
    const key = `${txtp}:${version}`;
    const cached = this.schemaCache.get(key);
    if (cached) return cached;
    // Existing admin handler — see admin-service/src/services/tcs-config.logic.service.ts: handleGetConfigByTransactionType
    const { schema } = await this.adminClient.getConfigByTransactionType(txtp, version, tenantId, token);
    const validator = this.ajv.compile(schema);
    this.schemaCache.set(key, validator);
    return validator;
  }
}
```

Schema compilation can take 50–200 ms for complex ISO 20022 schemas. With up to 300 context rows per TXTP, caching is mandatory. Cache is process-local; eviction is not required for the expected catalogue size.

### Admin Service — No Changes Required for SM-01

The existing `handleGetConfigByTransactionType(transactionType, version, tenantId)` at [admin-service/src/services/tcs-config.logic.service.ts](admin-service/src/services/tcs-config.logic.service.ts) is reused as the schema + sample source. It already returns `{ schema, mapping, payload }` from `tcs_config`. No new admin route or handler is added for SM-01. `AdminServiceClient.getConfigByTransactionType()` on the RS Backend is a thin wrapper.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | `metadata.wizardDraft` updated per-screen via `PUT /suites/:id/draft` (HK-04). `wizard_progress` updated. `status` transitions to `RUNNING` on `POST /suites/:id/run` (T-01). |
| `tcs_config` | SELECT (via admin-service `handleGetConfigByTransactionType`) — read-only |

### Prerequisites

- HK-03 (wizard shell, routing, `<Stepper />`, `<FieldConfigurator />`, `simulationStudioApi` slice — Day 1)
- HK-02 (RS Backend `simulation-studio` module + controller + `AdminServiceClient.getConfigByTransactionType` method exist)
- S1-01 (suite must already exist — `POST /suites` is called on Screen 1 Next so a suite id is available for `PUT /draft` and `POST /generate/context`)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 1 | `<SimulationStudioWizard />` shell at `pages/SimulationStudio/Wizard/index.tsx` — screen index state, Next/Back handlers, `<Stepper />` wiring, validation gate framework, navigation guard (`useBlocker` v7 + `beforeunload`), mode prop detection for create/edit/clone, load-from-draft on `/simulation-studio/edit/:id` entry. |
| Dev A | Day 3 | Wire `POST /api/v1/simulation-studio/suites/:id/generate/context` into Screen 2 → Screen 3 transition. Preview Data button: call generate/context with `count=5`, render inline 5-row preview table. Screen 2 Next: call generate/context for full count and store result in wizard state before advancing to Screen 3. |
| Dev B | Day 3 | `ContextGenerationService` and its controller method on RS Backend (`connection-studio/backend/src/simulation-studio/`). AJV cache initialisation. Add `getConfigByTransactionType(txtp, version, tenantId, token)` method to `AdminServiceClient` if not present. Wire request validation via `GenerateContextDto` (class-validator). Return 422 with per-row AJV errors if any generated row fails schema validation. |

---

## SM-02 — View All Simulation Suites in a Searchable List
[Back to Top](#top)

**Start:** 21 May | **End:** 01 Jun

### Overview

The `<SimulationStudioList />` page is the entry point to the Simulation Studio module, mounted at `/simulation-studio` (see [changes-in-plan.md](changes-in-plan.md) §2–§3). Built greenfield at `rule-studio/frontend/src/pages/SimulationStudio/List/index.tsx`. Follows the existing list-page pattern used by [rule-studio/frontend/src/pages/Home/index.tsx](rule-studio/frontend/src/pages/Home/index.tsx) and [rule-studio/frontend/src/pages/SimulationList/index.tsx](rule-studio/frontend/src/pages/SimulationList/index.tsx) — but it does **not** modify either. Per the updated user stories, columns are: Suite Name, Associated Rule, TXTP, Status, Iterations, Last Updated, Created By, and Actions.

### Frontend — `<SimulationStudioList />`

- **Page shell:** `<BoxWrapper />`, `<ScienceOutlinedIcon />` header at `#4789f6` (matching the legacy SimulationList visual), title "Simulation Studio", subtitle "Create, run, and review simulation suites for your rules", "Create Simulation Suite" CTA button wired to `/simulation-studio/create`
- **Columns** (in order): Suite Name (`name`), Associated Rule (`rule_name`), TXTP (`primary_txtp`), Status (`<StatusCard status={row.status} bullet={false} />`), Iterations (`iteration_count`), Last Updated (`updated_at`, type `'date'`), Created By (`created_by`), Actions
- **Search:** real-time filter by Suite Name — uses existing `useFilters({ search_delay: 500 })` from [rule-studio/frontend/src/hooks/useFilters.ts](rule-studio/frontend/src/hooks/useFilters.ts) which provides `search`, `debouncedSearch`, `setSearch` with built-in 500 ms debounce. Pass `debouncedSearch` as the RTK Query arg
- **Status filter dropdown:** `<DropDown />` with options `[All, DRAFT, RUNNING, COMPLETED, FAILED]` (and `ENV_PROVISIONING` if surfaced as a distinct status — to be confirmed in T-02). `DropdownOption` value type from [rule-studio/frontend/src/components/DropDown](rule-studio/frontend/src/components/DropDown)
- **Rule filter dropdown:** `<DropDown />` populated from `GET /api/v1/simulation-studio/registry/repos` (S1-01 endpoint) — filters list to suites for a given rule. Includes an "All" option
- **Reset filters** icon (`<FilterAltOffIcon />`) — clears search, status, and rule filter (matches the Home page pattern)
- **Actions per row** via an extended `<TableActions />` (see below): View (always), Edit (DRAFT only), Clone (any non-DRAFT suite), and **Resume** for DRAFT suites with non-empty `wizard_progress`
- Empty state (`Text` + "Create your first suite" CTA), `<SuspenseLoader />` on initial load, `<CustomPagination />` via `<Table pagination={...} />` (Home pattern)

#### `<TableActions />` Extension

The existing [rule-studio/frontend/src/components/TableActions/index.tsx](rule-studio/frontend/src/components/TableActions/index.tsx) exposes `onView`, `onEdit`, `onDelete`, `onClone`, `onHold`, `onToggleStatus`. Add an optional `onResume?: () => void` prop with a `<PlayCircleOutlineIcon />` (or similar) rendered when supplied. This is a small additive change — no existing call sites need modification because the prop is optional. Alternatively, wrap `<TableActions />` in a `<SimulationStudioActions />` row component if a custom button arrangement is preferred (matches the legacy [rule-studio/frontend/src/pages/SimulationList/SimulationActions.tsx](rule-studio/frontend/src/pages/SimulationList/SimulationActions.tsx) pattern).

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/simulation-studio/suites?search=&status=&rule=&page=&limit=` | Paginated, tenant-scoped list of suites. Returns `{ data: SuiteListItemDto[], total: number, limit: number, offset: number }` matching the existing `PaginatedResult<T>` shape from `@tazama-lf/tcs-lib` used elsewhere in the backend. |

Each `SuiteListItemDto`:
```ts
{
  id: number;
  name: string;
  rule_name: string;
  primary_txtp: string;
  status: 'DRAFT' | 'RUNNING' | 'COMPLETED' | 'FAILED' | 'ENV_PROVISIONING';
  iteration_count: number;
  last_run_at: string | null;   // ISO timestamp
  updated_at: string;           // ISO timestamp — drives "Last Updated" column
  created_by: string;
  wizard_progress: Record<string, boolean>;  // included so Actions cell can compute Resume eligibility
}
```

Auth: `TazamaAuthGuard` with `@RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.APPROVER)` (matches the existing [connection-studio/backend/src/simulation/simulation.controller.ts](connection-studio/backend/src/simulation/simulation.controller.ts) pattern).

Error responses: `400` (invalid query params), `401` (missing/invalid token), `403` (RBAC fail), `500` (DB error).

### RS Backend Controller — `SimulationStudioController.listSuites`

Lives in `connection-studio/backend/src/simulation-studio/simulation-studio.controller.ts` on the route `GET /api/v1/simulation-studio/suites`. Validates query params via a `ListSuitesQueryDto` (class-validator: `@IsOptional() @IsString() search?`, `@IsOptional() @IsIn([...]) status?`, `@IsOptional() @IsString() rule?`, `@IsOptional() @IsInt() @Min(1) page?`, `@IsOptional() @IsInt() @Min(1) @Max(100) limit?`). Calls `simulationStudioService.listSuites(query, tenantId)` which delegates to Admin Service via `AdminServiceClient`.

### Admin Service — `listSimulationSuites` Handler (NEW)

New handler in `admin-service/src/services/simulation-studio.logic.service.ts` (new file) registered in `admin-service/src/router.ts`:

```typescript
export const handleListSimulationSuites = async (
  tenantId: string,
  filters: { search?: string; status?: string; rule?: string },
  pagination: { offset: number; limit: number },
): Promise<PaginatedResult<SuiteListRow>> => { /* ... */ };
```

Built on top of a new `SimulationSuiteRepository` mirroring the structure of [admin-service/src/repositories/configuration/tcs.config.repository.ts](admin-service/src/repositories/configuration/tcs.config.repository.ts) (parameterised WHERE clause builder, separate COUNT query, ORDER BY `updated_at DESC` with LIMIT/OFFSET — see existing pattern in that file at lines 160–220).

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | `SELECT id, name, rule_name, primary_txtp, status, iteration_count, last_run_at, updated_at, created_by, wizard_progress FROM trs_simulation_suites WHERE tenant_id = $1 [AND name ILIKE $N] [AND status = $N] [AND rule_name = $N] ORDER BY updated_at DESC LIMIT $N OFFSET $N`. Separate `SELECT COUNT(*)` for total. |

Indexes used (all created in HK-01): `idx_sim_suites_tenant`, `idx_sim_suites_status`, `idx_sim_suites_updated`, `idx_sim_suites_rule`.

### Prerequisites

- HK-03 (routing, list page skeleton at `pages/SimulationStudio/List/`, `<StatusCard />` extended for `DRAFT` — Day 1)
- HK-01 (DB migration — `primary_txtp`, `iteration_count`, `wizard_progress`, renamed table)
- HK-02 (RS Backend `simulation-studio` module + controller route binding)
- S1-01 (for the Rule filter dropdown's `GET /registry/repos` source)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 1 | `<SimulationStudioList />` skeleton at `pages/SimulationStudio/List/index.tsx`: route wired in `routes/index.tsx`, page header (`<ScienceOutlinedIcon />` + title + subtitle), "Create Simulation Suite" CTA wired to `/simulation-studio/create`, `<SuspenseLoader />` initial state, empty state, `<Table />` placeholder with column definitions. |
| Dev A | Day 5 | Full list implementation: extend `<TableActions />` with `onResume`, build `useSimulationStudioListController` (modelled on `useHomeController`) using `useFilters()` for search + pagination + `useLazyListSuitesQuery`, wire search input, status `<DropDown />`, rule `<DropDown />` (consumes registry repos query), reset-filters icon, all columns including Last Updated date formatting, Resume eligibility logic (`status === 'DRAFT' && Object.values(wizard_progress).some(Boolean)`). |
| Dev B | Day 5 | `GET /api/v1/simulation-studio/suites` endpoint — controller binding, `ListSuitesQueryDto` validation, service delegation. `handleListSimulationSuites` admin handler + new `SimulationSuiteRepository` paginated SELECT with filter WHERE clauses and COUNT query. Ensure response shape matches `PaginatedResult<SuiteListItemDto>`. Register handler in `admin-service/src/router.ts` with appropriate privilege key. |

---

> **Pre-story housekeeping — required before S1-01 can begin.** The two items below are Day 1 backend infrastructure. S1-01 cannot be built without the NestJS module existing and RegistryService having a valid Docker Hub token. Both are owned by Dev C on Day 1, in parallel with Dev A's frontend scaffolding.

## HK-02 — RS Backend NestJS Module Scaffolding
[Back to Top](#top)

**Day:** 1 (21 May) | **Owner:** Dev C

The `simulation-studio` NestJS module must exist before any controller or service code can be written; without the module binding, Nest cannot resolve injected dependencies. Per [changes-in-plan.md](changes-in-plan.md) §1 and §7, the module is registered as a **top-level module folder** (matching the convention of the existing `src/simulation/`, `src/sftp/`, `src/job/`, etc. modules — see [connection-studio/backend/src/app.module.ts](connection-studio/backend/src/app.module.ts)), **not** under `src/services/`.

### Directory and File Structure

```
connection-studio/backend/src/simulation-studio/
├── simulation-studio.module.ts          ← registers providers, controllers, imports
├── simulation-studio.controller.ts      ← all /api/v1/simulation-studio/* route bindings (handlers may stub on Day 1)
├── simulation-studio.service.ts         ← orchestrates downstream service calls
├── registry/
│   └── registry.service.ts              ← Docker Hub API client + token cache (HK-05)
├── orchestrator/
│   ├── orchestrator.service.ts          ← Docker Engine lifecycle via dockerode
│   ├── single-rule-env.builder.ts       ← builds SingleRuleEnvSpec from suite + iteration
│   ├── ods-init.service.ts              ← SQL template render + execute against ephemeral ODS
│   ├── transaction-loop.service.ts      ← sequential sim transaction pair submission
│   └── env-registry.service.ts          ← concurrency pool tracking (in-memory + DB)
├── context/
│   └── context-generation.service.ts    ← AJV schema cache + iteration payload generation (per changes-in-plan.md §11)
└── dto/
    ├── index.ts
    ├── common.dto.ts                    ← shared DTOs (PaginationQueryDto, status enums)
    ├── single-rule.dto.ts               ← CreateSuiteDto, UpdateDraftDto, RunSuiteDto
    └── list-suites-query.dto.ts         ← ListSuitesQueryDto (SM-02)
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
import { ConfigModule } from '../config/config.module';
import { AuthModule } from '../auth/auth.module';
import { AdminServiceClient } from '../services/admin-service-client.service';

@Module({
  imports: [HttpModule, ConfigModule, AuthModule],
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

Register in `AppModule.imports` alongside the existing `SimulationModule` (the legacy module remains untouched per changes-in-plan.md §9):

```typescript
// app.module.ts (additive change)
import { SimulationStudioModule } from './simulation-studio/simulation-studio.module';

@Module({
  imports: [ /* …existing… */, SimulationModule, SimulationStudioModule, /* … */ ],
})
```

### DTOs Required Concrete on Day 1

```typescript
// single-rule.dto.ts
import { IsString, IsNotEmpty, IsOptional, IsInt, MaxLength, Min, Max, IsObject } from 'class-validator';

export class CreateSuiteDto {
  @IsString() @IsNotEmpty() @MaxLength(100) name: string;
  @IsOptional() @IsString() @MaxLength(500) description?: string;
  @IsString() @IsNotEmpty() rule_repo: string;       // e.g. 'myorg/rule-high-value'
  @IsString() @IsNotEmpty() rule_name: string;
  @IsString() @IsNotEmpty() rule_version: string;    // image tag
  @IsString() @IsNotEmpty() primary_txtp: string;    // TxTp type from Screen 1
  @IsString() @IsNotEmpty() primary_txtp_version: string;
  @IsOptional() @IsInt() clone_source_id?: number;
}

// common.dto.ts
export class UpdateDraftDto {
  @IsInt() @Min(1) @Max(5) screen: number;           // 5 wizard Next/Back steps per changes-in-plan.md §4
  @IsObject() data: Record<string, unknown>;
}
```

### Controller Skeleton

```typescript
// simulation-studio.controller.ts
import { Controller, UseGuards } from '@nestjs/common';
import { TazamaAuthGuard } from '../auth/tazama-auth.guard';

@Controller('api/v1/simulation-studio')
@UseGuards(TazamaAuthGuard)
export class SimulationStudioController {
  // Day 1: route handlers stub `throw new NotImplementedException()`; bound per story.
  // GET    /suites                        ← SM-02
  // POST   /suites                        ← SM-01
  // GET    /suites/:id                    ← SM-03
  // PATCH  /suites/:id/draft              ← SM-01 (wizard autosave)
  // POST   /suites/:id/run                ← SR-01
  // GET    /suites/:id/iterations         ← SM-03
  // GET    /registry/repos                ← S1-01
  // GET    /registry/repos/:repo/tags     ← S1-01
}
```

Route prefix `/api/v1/simulation-studio` is set once at the controller level; all sub-paths in the spec inherit it. See [changes-in-plan.md](changes-in-plan.md) §6 for the full path remapping table.

### `RuleSourceService` Removal

`RuleSourceService` from Rev 2.1 is **removed** and replaced by `RegistryService`. The endpoints `GET /rules/search` and `GET /rules/:ruleId/versions` are also removed (§9.2). Run `grep -rn "RuleSourceService\|/rules/search\|/rules/.*/versions" connection-studio/backend/src` and confirm zero hits before deleting.

### `ContextGenerationService` Placement

AJV schema cache and iteration payload generation live in `simulation-studio/context/context-generation.service.ts` in **this** module — not in `admin-service`. `admin-service` does not currently depend on AJV, and the RS Backend already uses AJV elsewhere. The service consumes `{schema, mapping}` fetched from admin-service via `AdminServiceClient.handleGetConfigByTransactionType()` and compiles+caches the validator/mapper functions on first use per (txtp, version) tuple.

---

## HK-05 — Docker Hub Authentication
[Back to Top](#top)

**Day:** 1 (21 May) | **Owner:** Dev C

`RegistryService` (located at `connection-studio/backend/src/simulation-studio/registry/registry.service.ts` per HK-02) must authenticate against Docker Hub to list repos and tags. This is both a code concern and an environment provisioning concern that must be resolved before any Screen 1 (S1-01) work can be tested end-to-end.

### Environment Variables

Add to [connection-studio/backend/src/config/env.validation.ts](connection-studio/backend/src/config/env.validation.ts):

```typescript
@IsOptional() @IsString() DOCKER_HUB_USER?: string;
@IsOptional() @IsString() DOCKER_HUB_TOKEN?: string;
@IsOptional() @IsString() DOCKER_HUB_NAMESPACE?: string; // org name — e.g. 'tazama-lf'
```

Marked `@IsOptional()` so the app still starts without them (only the Simulation Studio features will fail gracefully). Consumed via `ConfigService.get<string>('DOCKER_HUB_USER')` — matching the existing pattern throughout the backend (see [connection-studio/backend/src/services/admin-service-client.service.ts](connection-studio/backend/src/services/admin-service-client.service.ts) for the `ConfigService` injection pattern).

Also add to the service's `.env.example`:
```
DOCKER_HUB_USER=       # Docker Hub service account username
DOCKER_HUB_TOKEN=      # Docker Hub personal/service access token (read-only scope)
DOCKER_HUB_NAMESPACE=  # Docker Hub org/namespace containing rule-* repos
```

### `RegistryService` — `getToken()` Implementation

```typescript
import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';

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

Cache tag list responses with a 5-minute TTL using `Map<string, { tags: TagDto[]; expiresAt: number }>` keyed by `repo`. If `expiresAt > Date.now()`, return cached result. This is mandatory to respect Docker Hub's 200-pulls-per-6h rate limit (§15.1).

Implementation: in-memory `Map` on the singleton `RegistryService` instance — adequate because the RS Backend is a single-replica deployment. If multi-replica scaling is introduced, consider extracting to a short-TTL Redis key (out of scope for Day 1).

### Open Questions (§15.3 — must resolve before Day 1 merge)

- **Docker Hub org namespace** — confirm naming convention (`rule-{name}` repos inside which namespace?) with platform team. Interim: use `DOCKER_HUB_NAMESPACE` env var so no hardcoding is required.
- **Service account vs personal access token** — determines rotation procedure (personal = user-bound 90-day rotate; service = org-bound, no auto-rotate)
- **Read-only scope sufficient?** — `RegistryService` only calls list-repos and list-tags; write access is never needed. Confirm minimal permissions with DevOps.

---

## S1-01 — Select a Rule and Transaction Version for the Suite

**Start:** 21 May | **End:** 22 May

### Overview

Screen 1 of the wizard. The user selects the rule, rule version, and the primary TxTp (the transaction type the rule is designed to evaluate). Rule + primary TxTp form the **immutable identity** of the suite - per the updated user stories, neither can be changed once the suite is created. Only the rule version can be changed in edit mode (SM-04). Rules are sourced exclusively from Docker Hub; `trs_rules` is not queried (§2).

### Frontend - `<SimulationStudioWizard />` Screen 1

- **Rule picker** - searchable dropdown from `GET /api/v1/simulation-studio/registry/repos`. Repo names (e.g. `rule-high-value`) parsed to friendly display names
- **Rule Version picker** - from `GET /api/v1/simulation-studio/registry/repos/:repo/tags` on rule selection, sorted by `last_updated DESC`
- **Primary TxTp picker** - from `GET /api/v1/simulation-studio/txtp-types`. Label: "Primary Message Type"
- **Primary TxTp Version picker** - populated from the selected TxTp row returned by `GET /txtp-types` (no separate versions endpoint required)
- All four fields required before Next is enabled
- **Edit mode** (`/simulation-studio/edit/:id`): rule and primary TxTp rendered as read-only labels (not dropdowns). Rule version dropdown remains editable. Per S1-01 AC: "the rule and transaction is pre-selected and its dropdown is disabled; only the version dropdown is editable"
- On Screen 1 Next: `POST /api/v1/simulation-studio/suites` creates DRAFT suite and returns `{ id, status: 'DRAFT' }`

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/simulation-studio/registry/repos` | Lists rule repos from Docker Hub. Returns `[{ repo, friendlyName }]`. |
| GET | `/api/v1/simulation-studio/registry/repos/:repo/tags` | Lists tags sorted by `last_updated DESC`. Returns `[{ tag, digest, lastUpdated }]`. 5-min TTL cache. |
| GET | `/api/v1/simulation-studio/txtp-types` | Lists TxTp types and versions using existing admin-service handler `handleGetAllTransactionTypes(tenantId)` via RS Backend pass-through. |
| POST | `/api/v1/simulation-studio/suites` | Creates a DRAFT `trs_simulation_suites` row. Body: `CreateSuiteDto`. Returns `{ id, status: 'DRAFT' }`. |

### Backend Services — `RegistryService` (§6.3)

| Method | External Call |
|--------|--------------|
| `listRepos(namespace)` | `GET https://hub.docker.com/v2/repositories/{namespace}/?page_size=100`. Filters to `rule-*` repos. Paginates if > 100. |
| `listTags(namespace, repo)` | `GET https://hub.docker.com/v2/repositories/{namespace}/{repo}/tags/?page_size=100`. Sorted by `last_updated DESC`. 5-min TTL cache per repo. |
| `verifyImage(namespace, repo, tag)` | Calls `listTags`, confirms tag exists. Returns `{ exists: boolean, digest: string }`. Used by POST /run. |
| `getToken()` | See HK-05 |

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | INSERT: `name`, `description`, `rule_repo`, `rule_name`, `rule_version`, `primary_txtp`, `primary_txtp_version`, `simulation_type = 'SINGLE_RULE'`, `status = 'DRAFT'`, `tenant_id`, `created_by` |
| `tcs_config` | Read-only source behind existing admin-service TxTp handlers; filter column is `status` (not `activated`). |

### Prerequisites

- HK-02 (RS Backend module and controller must exist)
- HK-05 (Docker Hub token — needed for `listRepos` and `listTags`)
- HK-01 (DB migration — `primary_txtp`, `primary_txtp_version`, `rule_repo` columns on `trs_simulation_suites`)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 1 | `RegistryService` full implementation: `listRepos()`, `listTags()` with 5-min TTL cache, `getToken()` with 50-min JWT cache, `verifyImage()`. Wire `GET /api/v1/simulation-studio/registry/repos` and `GET /api/v1/simulation-studio/registry/repos/:repo/tags` controller methods. |
| Dev A | Day 2 | Screen 1 FE in `<SimulationStudioWizard />`: rule picker, version picker (populated on rule change), Primary TxTp picker, TxTp version picker. Edit-mode lock on rule + TxTp fields. All four fields required validation. RTK Query wiring. `POST /suites` on Next. |
| Dev B | Day 2 | `POST /api/v1/simulation-studio/suites` endpoint: validate `CreateSuiteDto`, insert DRAFT row into `trs_simulation_suites`, return `{ id, status }`. `GET /api/v1/simulation-studio/txtp-types` endpoint: pass through to existing admin handler `handleGetAllTransactionTypes(tenantId)` and map response for FE dropdowns. |

---

## S1-02 — Define Suite Metadata

**Start:** 22 May | **End:** 22 May

### Overview

Screen 1 also captures the suite's name and description. These are part of the same `POST /api/v1/simulation-studio/suites` payload and Screen 1 component as S1-01. S1-02 is a separate story to make validation requirements explicit.

### Frontend - `<SimulationStudioWizard />` Screen 1

- **Suite Name** — required text input, max 100 chars, character counter, inline validation error on Next if empty
- **Suite Description** — optional textarea, max 500 chars, character counter
- Clone mode: name pre-filled as `Copy of [Original Name]` (editable). All other fields from source suite

### API

Same `POST /api/v1/simulation-studio/suites` as S1-01. `name` and `description` are part of the same `CreateSuiteDto`.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | `name VARCHAR(100) NOT NULL`, `description VARCHAR(500)` — same INSERT as S1-01 |

### Prerequisites

- S1-01 (Screen 1 component and POST /suites endpoint)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 2 | Name + description fields in Screen 1 component. Character counters, required validation on name. Covered by S1-01 Day 2 FE task. |
| Dev B | Day 2 | `@IsNotEmpty()` + `@MaxLength(100)` on `name`, `@IsOptional()` + `@MaxLength(500)` on `description` in `CreateSuiteDto`. Covered by S1-01 Day 2 BE task. |

---

> **Pre-story housekeeping — required before S2-01 can begin.** Screen 2 is the first wizard screen whose Next action calls PUT /draft to persist state server-side. This infrastructure must exist before S2-01 is built, because every subsequent screen depends on the same pattern.

## HK-04 — Per-Screen Draft Persistence Infrastructure
[Back to Top](#top)

**Day:** 1–2 (21–22 May) | **Owner:** Dev B (endpoint), Dev A (frontend wiring)

Per §5.5, every wizard screen's Next action persists its data server-side before navigating forward. This is cross-cutting infrastructure not described by any individual user story. The closest is T-09 in §A.12 (new stories needed), which is not in the current scope.

### RS Backend Endpoint

`PUT /api/v1/simulation-studio/suites/:id/draft` (§9.1):
- Body: `UpdateDraftDto` — `{ screen: number (1-5), data: Record<string, unknown> }`
- Calls Admin Service `saveDraftProgress` to merge `data` into `metadata.wizardDraft` JSONB, keyed by screen number
- Updates `wizard_progress.screen${n} = true`
- Returns 200 with `{ wizard_progress }`

### Admin Service Handler — `saveDraftProgress` (§7.1)

Single SQL statement using `jsonb_set` with `create_missing = true` (idempotent — submitting the same screen twice overwrites the previous draft for that screen):

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
  updated_at = NOW()
WHERE id = $id AND tenant_id = $tenantId
RETURNING wizard_progress;
```

### Frontend Reconnect and Resume Flow

On load of `/simulation-studio/edit/:id` (resume, edit, or rerun with new data):
1. Call `GET /api/v1/simulation-studio/suites/:id` to fetch the suite
2. Read `metadata.wizardDraft` and dispatch each screen's data into wizard Redux state
3. Read `wizard_progress` to find the highest completed screen number
4. Navigate stepper to `highestCompletedScreen + 1`

On `<SimulationStudioList />`: any suite with `status = 'DRAFT'` and non-empty `wizard_progress` shows a **Resume** action. Clicking Resume navigates to `/simulation-studio/edit/:id`.

### Prerequisites

- HK-02 (RS Backend module must exist for the controller route)
- HK-01 (DB migration — `metadata` JSONB and `wizard_progress` JSONB columns on `trs_simulation_suites`)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 1 | `PUT /api/v1/simulation-studio/suites/:id/draft` RS Backend controller method. `UpdateDraftDto` validation (`screen` in 1-5). Admin Service `saveDraftProgress` route handler with `jsonb_set` UPDATE SQL. |
| Dev A | Day 2 | Wire PUT `/suites/:id/draft` call into `<SimulationStudioWizard />` `onNext` handler - called for each wizard step before advancing screen index. Wire reconnect flow: on `/simulation-studio/edit/:id` load, reconstruct wizard state from `wizardDraft` and jump to the correct step. |

---

## S2-01 — Configure Context Data

**Start:** 22 May | **End:** 22 May

> **Note:** This story is titled "Add and configure TXTPs for the suite" in the current user stories document. It covers **Screen 2 — Context Data**: configuring TXTPs and their per-field generation strategies to produce synthetic context (historical) messages for the ODS. The team has been asked to update the story title.

### Overview

Screen 2 configures how context data is generated. The user adds TXTPs (the first row is pre-populated from the primary TxTp selected on Screen 1), sets the number of synthetic context messages per TXTP, and configures per-field generation strategies using `<FieldConfigurator />`. This data drives `POST /api/v1/simulation-studio/suites/:id/generate/context` (wired in SM-01) and determines the Context count shown in the Screen 5 summary.

S2-01 remains a **new Simulation Studio flow** and does not reuse legacy `pages/Simulation/*` tab content. Existing legacy simulation pages remain untouched.

### Frontend — `<SimulationStudioWizard />` Screen 2

- **TXTP table** — initialised with one row: the primary TxTp from Screen 1 (pre-populated, cannot be removed)
- **Add TXTP** button — appends additional rows for multi-TXTP context
- **Per TXTP row:**
  - TXTP type (locked/read-only for row 1; editable dropdown for additional rows — `GET /api/v1/simulation-studio/txtp-types`)
  - TXTP version (dropdown, populated on type selection)
  - **No. of messages** — integer input, min 1. Sum across all TXTPs = "Context count" in Screen 5 summary
  - **Schema Loaded** badge — shown once schema for this TXTP version is fetched successfully
  - **Sample Available** badge — shown if TCS has a sample payload for this TXTP version
  - **Preview Data** button — calls `POST /api/v1/simulation-studio/suites/:id/generate/context?count=5` for this TXTP and renders an inline 5-row preview
  - **Expand** button — opens `<FieldConfigurator />` panel
  - **Remove** button — available on additional rows only (row 1 locked)
- **`<FieldConfigurator />` panel** (from HK-03): schema fields on the left, strategy selector on the right. Strategies: **Keep sample value** · **Static value** (value input appears) · **Skip field**
- On Next: `PUT /api/v1/simulation-studio/suites/:id/draft` with `{ screen: 2, data: { txtpConfigs, fieldConfigs, messageCounts } }`. SM-01 then fires `POST /api/v1/simulation-studio/suites/:id/generate/context` for the full count before advancing to Screen 3.

Implementation note from current codebase:
- `FieldConfigurator` does not exist yet under `rule-studio/frontend/src/components/`; it must be created as planned in HK-03.
- Existing frontend API hooks in `rule-studio/frontend/src/redux/Api/Config/index.ts` (`getTypes`, `getTxtpVersions`, `getSamplePayload`) are tied to the current `/config/api/*` module and should not be reused directly by Simulation Studio; S2-01 should consume the dedicated `simulationStudioApi` slice introduced in HK-03.

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/simulation-studio/txtp-types` | Lists TxTp candidates for the wizard. RS Backend proxies Admin Service `/v1/admin/config/transaction-types` and maps to `{ txtp, versions[] }` for UI consumption. |
| GET | `/api/v1/simulation-studio/txtp-types/:txtp/:version/schema` | Returns `{ schema }` for FieldConfigurator. Internally sourced from Admin Service `/v1/admin/config/:transactionType/:version` (`config.schema`). |
| GET | `/api/v1/simulation-studio/txtp-types/:txtp/:version/sample` | Returns `{ payload }` for Sample Available and Trigger defaults. Internally sourced from Admin Service `/v1/admin/config/payload/:transactionType/:transactionVersion`. |
| POST | `/api/v1/simulation-studio/suites/:id/generate/context` | Generates context rows from strategies. `count=5` for preview; full count on Next. |
| PUT | `/api/v1/simulation-studio/suites/:id/draft` | Persists Screen 2 wizard draft (`screen=2`). |

Auth and errors (all endpoints):
- Auth: `Authorization: Bearer <token>` required.
- Errors: `400` (invalid params/body), `401` (missing/invalid token), `403` (RBAC denial), `404` (suite/txtp/version not found), `422` (schema validation failure for generated rows), `500` (unexpected backend/admin-service failure).

Contract notes from current codebase:
- Admin Service `handleGetConfigByTransactionType(transactionType, version, tenantId)` returns `{ schema, mapping, payload }` (payload is JSON or XML-derived depending on `content_type`).
- Admin Service `findAllTransactionTypes(tenantId)` currently filters by `status IN ('STATUS_04_APPROVED','STATUS_06_EXPORTED')`, not an `activated` column.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | `metadata.wizardDraft.screen2` updated via PUT /draft |
| `trs_suite_txtp_configs` | **Not written here** — written atomically on POST /run via `saveIterationTransactional` (T-01) |
| `tcs_config` | Read-only source for TxTp/schema/sample via Admin Service handlers; transaction-type listing currently constrained by `status IN ('STATUS_04_APPROVED','STATUS_06_EXPORTED')`. |

### Prerequisites

- S1-01 (suite must exist — `POST /api/v1/simulation-studio/suites` called on Screen 1 Next)
- HK-03 (`<FieldConfigurator />` shared component)
- HK-04 (PUT /draft infrastructure)

Additional implementation prerequisites:
- RS Backend `simulation-studio` controller methods for `txtp-types`, `schema`, and `sample` must be added; these do not exist yet in current `connection-studio/backend` modules.
- `AdminServiceClient` currently has no helper methods for Admin Service config transaction-type/schema/payload reads; those wrappers must be added for S2-01 wiring.

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 2 | Screen 2 FE under `pages/SimulationStudio/Wizard/Screen2ContextData/` — TXTP table, pre-populated row 1 from wizard state, Add/Remove rows, type + version dropdowns, No. of messages input, Schema Loaded + Sample Available badges (schema/sample fetch on type+version selection), Preview Data (5-row table), `<FieldConfigurator />`, PUT `/suites/:id/draft` on Next. |
| Dev B | Day 2 | Implement RS Backend Simulation Studio endpoints: `GET /txtp-types`, `GET /txtp-types/:txtp/:version/schema`, `GET /txtp-types/:txtp/:version/sample`; add `AdminServiceClient` wrappers to call admin `/v1/admin/config/transaction-types`, `/v1/admin/config/:transactionType/:version`, `/v1/admin/config/payload/:transactionType/:transactionVersion`. |
| Dev B | Day 3 | Implement `POST /api/v1/simulation-studio/suites/:id/generate/context` in RS Backend `ContextGenerationService` (AJV cache local to RS Backend), plus 422 row-level validation response shape used by S2-01 Preview and Next flows. |

---

## S3-01 — Configure and Preview Simulation Trigger Transactions

**Start:** 25 May | **End:** 25 May

### Overview

Screen 3 configures the trigger transactions — the payloads actually submitted to the rule processor during the run. Unlike Screen 2 (which uses FieldConfigurator generation strategies), Screen 3 uses a JSON editor pre-populated with the TCS sample payload for each TXTP. The user edits field values directly in JSON. A maximum of 15 trigger messages is enforced across all TXTPs combined.

### Frontend — `<SimulationStudioWizard />` Screen 3

- One **collapsible card** per TXTP configured in Screen 2
- **Per card:**
  - TXTP label (type + version, read-only)
  - **JSON editor** — pre-populated with the TCS sample payload (fetched in S2-01, available in wizard state). User edits field values directly in JSON
  - **No. of msgs** — integer input. Cross-card total must not exceed 15. Validation error shown if total > 15: "Total trigger messages across all TXTPs cannot exceed 15"
  - **Link to context pairs** checkbox — when checked, each trigger message is linked to a corresponding context pair for that TXTP via `EndtoEndID`. Checkbox only enabled if Screen 2 generated context rows for this TXTP
- On Next: validate total No. of msgs ≤ 15. If valid: `PUT /api/v1/simulation-studio/suites/:id/draft` with `{ screen: 3, data: { triggerConfigs: [{ txtp, version, payload: object, count: number, linkToContext: boolean }] } }`. Advance to Screen 4 (Enrichment).

Reusable frontend building blocks from current codebase:
- `rule-studio/frontend/src/components/JsonFormatter/index.tsx` can be reused for structured JSON edit/add/delete interactions per TXTP card.
- `rule-studio/frontend/src/components/AccordianSummary/index.tsx` can be reused for card expansion headers.
- S3 remains under new Simulation Studio page tree and does not modify legacy `pages/Simulation/*`.

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| PUT | `/api/v1/simulation-studio/suites/:id/draft` | Persists Screen 3 trigger data (HK-04 infrastructure). |

Auth and errors:
- Auth: `Authorization: Bearer <token>` required.
- Errors: `400` (invalid payload/count), `401` (missing/invalid token), `403` (RBAC denial), `404` (suite not found), `422` (invalid trigger JSON or business validation), `500` (unexpected failure).

The TCS sample payload is normally available in frontend state from S2-01 sample loading. If state is cold (resume/refresh), Screen 3 can rehydrate sample payload through the existing Simulation Studio sample endpoint (`GET /api/v1/simulation-studio/txtp-types/:txtp/:version/sample`) before rendering the editor.

### Backend

The 15-transaction maximum is enforced server-side in `saveIterationTransactional` (T-01). The frontend check is defensive UI only. Server-side validation should use the sum of `triggerConfigs[].count` from `wizardDraft.screen3` during run dispatch, not per-card independent checks.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | `metadata.wizardDraft.screen3` updated via PUT /draft |
| `trs_suite_context_sim_pairs` | Written on run via `saveIterationTransactional` (T-01), not during Screen 3 |

### Prerequisites

- S2-01 (TXTP list and TCS sample payloads in wizard state)
- SM-01 (wizard shell, context generation wired)
- HK-04 (PUT /draft)

Additional implementation prerequisites:
- RS Backend Simulation Studio `PUT /suites/:id/draft` must accept and validate Screen 3 shape (`triggerConfigs[]` with `txtp`, `version`, `payload`, `count`, `linkToContext`).
- Simulation Studio frontend API slice (`simulationStudioApi`) must provide draft update mutation and optional sample rehydrate query for resume flows.

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 3 | Screen 3 FE under `pages/SimulationStudio/Wizard/Screen3TriggerData/` — one collapsible card per TXTP from Screen 2, JSON editor pre-populated from sample payload, No. of msgs input with cross-card total validation (≤ 15), Link to context pairs checkbox (enabled only when context exists for that TXTP), PUT `/api/v1/simulation-studio/suites/:id/draft` on Next. |
| Dev B | Day 3 | Validate `PUT /api/v1/simulation-studio/suites/:id/draft` for Screen 3 contract, including count bounds and payload type checks. Wire 15-transaction server-side enforcement into `saveIterationTransactional` (T-01 scope). |

---

## S4-01 — Define One or More Enrichment Tables

**Start:** 29 May | **End:** 29 May

> **Step correction:** The user stories document references "Step 5" for this screen. The correct step is **Step 4**. See the note at the top of this document.

### Overview

Screen 4 allows the user to define one or more enrichment tables that will be created and populated in the ephemeral Postgres ODS during a run. Each table is defined by a name and a JSON payload template. There is no hard cap on the number of enrichment tables (per user story assumptions). The system issues `CREATE TABLE` and `bulk INSERT` for each enrichment table during ODS initialisation (T-02).

Table names and payloads are draft-stage inputs in this story; physical table creation occurs only during run orchestration (T-02).

### Frontend — `<SimulationStudioWizard />` Screen 4

- **Target Table Name** input — required text field. Save Record button disabled if empty
- **JSON payload** text area — user pastes or types the JSON template for this table's rows
- **Save Record** button — appends `{ tableName, payload }` to the Saved Enrichment Records list
- **Saved Enrichment Records table** — columns: Table Name, Payload (truncated), Remove
- **Remove** button per row — deletes that record
- Back → Screen 3 (Trigger Data). Next → Screen 5 (Summary). All saved records reflected in the Screen 5 summary.
- On Next: `PUT /api/v1/simulation-studio/suites/:id/draft` with `{ screen: 4, data: { enrichmentRecords: [{ tableName, payload }] } }`

Reusable frontend components from current codebase:
- `rule-studio/frontend/src/components/Input/index.tsx` for table-name and JSON textarea input controls.
- `rule-studio/frontend/src/components/Table/index.tsx` for Saved Enrichment Records listing.
- `rule-studio/frontend/src/components/Button/index.tsx` for Save/Remove actions.
- `rule-studio/frontend/src/components/JsonFormatter/index.tsx` can be reused for JSON preview/edit support if richer structured editing is required.

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| PUT | `/api/v1/simulation-studio/suites/:id/draft` | Persists Screen 4 enrichment data (HK-04 infrastructure). |

Auth and errors:
- Auth: `Authorization: Bearer <token>` required.
- Errors: `400` (invalid tableName/payload shape), `401` (missing/invalid token), `403` (RBAC denial), `404` (suite not found), `422` (JSON parse or table-name semantic validation failure), `500` (unexpected failure).

Validation contract for `enrichmentRecords[]`:
- `tableName`: non-empty, <= 63 chars, regex `^[A-Z_]\w*$` (case-insensitive), and not reserved SQL keyword.
- `payload`: valid JSON object/array accepted by enrichment initialisation pipeline.
- Duplicate `tableName` entries in a single screen payload should be rejected with `409` or `422` (implementation choice to be standardised).

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | `metadata.wizardDraft.screen4` updated via PUT /draft |
| `trs_suite_enrichment_records` | Written on run via `saveIterationTransactional` (T-01), not during Screen 4 |

Table-name validation reference:
- Existing utility `admin-service/src/utils/enrichment-utils.ts` already enforces Postgres-safe table naming and reserved keyword blocking via `validateTableName`. RS Backend Simulation Studio should apply equivalent validation before persisting draft/run payloads.

### Prerequisites

- SM-01 (wizard shell)
- HK-04 (PUT /draft)
- S3-01 (Screen 3 Next proceeds to here)

Additional implementation prerequisites:
- Draft endpoint schema must include Screen 4 payload contract (`enrichmentRecords: Array<{ tableName: string; payload: unknown }>`).
- Run-time persistence (`saveIterationTransactional`) and T-02 ODS init must consume the same canonical enrichment record shape to avoid transform drift.

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 4 | Screen 4 FE under `pages/SimulationStudio/Wizard/Screen4Enrichment/` — table name input, JSON payload editor/textarea, Save Record button (disabled if name empty or invalid JSON), Saved Enrichment Records table with Remove action, PUT `/api/v1/simulation-studio/suites/:id/draft` on Next. |
| Dev B | Day 4 | Validate Screen 4 draft payload on `PUT /api/v1/simulation-studio/suites/:id/draft`, enforce tableName/payload constraints, and verify shape compatibility with `saveIterationTransactional` (T-01) and ODS init (T-02). |

---

## S5-01 — Review the Full Suite Summary Before Saving

**Start:** 29 May | **End:** 29 May

> **Step correction:** The user stories document references "Step 6" for this screen. The correct step is **Step 5**. See the note at the top of this document.

### Overview

Screen 5 is the read-only summary of all wizard inputs before the user commits. Two save paths: **Save as Draft** (persists as DRAFT, returns to list) and **Save Iteration** (persists and dispatches the run, advancing to Screen 6 — Results). In edit mode (SM-04), a warning banner is shown.

### Frontend — `<SimulationStudioWizard />` Screen 5

**Summary fields displayed:**
- Suite Name
- Associated Rule (rule name + version)
- Primary TxTp + version
- TXTPs configured (list from Screen 2 wizard state)
- Iteration Number (e.g. "Iteration 1" for new suites; "Iteration N" for edit mode — derived from `iteration_count + 1`)
- Enrichment Tables (count + table names from Screen 4)
- Context count (sum of "No. of messages" per TXTP from Screen 2)
- Trigger count (sum of "No. of msgs" per TXTP card from Screen 3)
- Total Valid Payloads (context count + trigger count, validated against TXTP schemas)

**Buttons:**
- **Back** → Screen 4 (Enrichment) with all data intact
- **Save as Draft** → persists latest Screen 5 summary state to `wizardDraft` via draft endpoint and returns to `/simulation-studio`; suite remains in DRAFT until run is triggered.
- **Save Iteration** → `POST /api/v1/simulation-studio/suites/:id/run`, then transition to Screen 6 (Results)

**Edit mode warning banner (SM-04, shown on `/edit/:id` route):** "Saving will create a new iteration and will not overwrite previous ones."

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/simulation-studio/suites/:id` | Fetch suite + `wizardDraft` for summary display. |
| PUT | `/api/v1/simulation-studio/suites/:id/draft` | Persist latest summary/draft state before leaving wizard via Save as Draft. |
| POST | `/api/v1/simulation-studio/suites/:id/run` | Triggers T-01 `saveIterationTransactional` + orchestrator dispatch. Returns `{ runId, status: 'ENV_PROVISIONING' }`. Wizard advances to Screen 6. |

Auth and errors:
- Auth: `Authorization: Bearer <token>` required.
- Errors: `400` (invalid suite ID/body), `401` (missing/invalid token), `403` (RBAC denial), `404` (suite not found/tenant mismatch), `409` (suite already RUNNING), `422` (run preconditions fail: invalid draft payload, missing required screen data, image/tag validation failure), `500` (unexpected backend/admin-service failure).

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | `metadata.wizardDraft.screen5` refreshed on PUT /draft when Save as Draft is used; `status` transitions to `RUNNING` on POST /run; `iteration_count` incremented by `saveIterationTransactional`. |

### Prerequisites

- S4-01 (Screen 4 completable — enrichment data in wizardDraft)
- SM-01 (wizard container drives transition to Screen 6)
- T-01 (POST /run endpoint)

Additional implementation prerequisites:
- Simulation Studio RS Backend module/controller must expose `GET /suites/:id`, `PUT /suites/:id/draft`, and `POST /suites/:id/run` under `/api/v1/simulation-studio/*`.
- Frontend must consume a dedicated `simulationStudioApi` slice; existing legacy `ruleSimulationApi` (`/simulation/api/*`) and legacy `pages/Simulation/*` are not part of this flow.

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 4 | Screen 5 FE under `pages/SimulationStudio/Wizard/Screen5Summary/` — render read-only summary from wizard state, compute iteration label from `iteration_count + 1`, show edit-mode warning banner, wire Back, Save as Draft (`PUT /suites/:id/draft` + redirect `/simulation-studio`), and Save Iteration (`POST /suites/:id/run` + navigate to Results). |
| Dev B | Day 4 | Implement `GET /api/v1/simulation-studio/suites/:id` summary endpoint and `POST /api/v1/simulation-studio/suites/:id/run` dispatcher contract; if T-01 orchestration is incomplete, return a controlled stub response with explicit `status='ENV_PROVISIONING'` and temporary `runId` for FE integration tests. |

---

> **Pre-story housekeeping — required before T-01 can begin.** The database migration is the foundational prerequisite for all persistence. T-01's first task (Day 1, Dev B) IS the DB migration — no application code that reads or writes the database can function correctly without it.

## HK-01 — Database Schema Migration
[Back to Top](#top)

**Day:** 1 (21 May) | **Owner:** Dev B

Per §10.5, migration file `05-create-simulation-studio-v2_2-additions.sql` must be created and applied first on Day 1. It covers the bucket → suite table renames and Single-Rule Simulation Studio schema additions required by HK-04, S1-S5, T-01, and SR stories.

Repository evidence note:
- No existing simulation migration SQL files were found in `admin-service` or `connection-studio` at review time (only bootstrap SQL such as `connection-studio/backend/tcs-init.sql`). This migration must therefore be authored as a net-new DB migration and tracked in the deployment pipeline.

### Step 1 — Table and Column Renames (Bucket → Suite)

```sql
-- Main table rename
ALTER TABLE public.trs_simulation_buckets         RENAME TO trs_simulation_suites;
ALTER TABLE public.trs_bucket_generations         RENAME TO trs_suite_generations;
ALTER TABLE public.trs_bucket_txtp_configs        RENAME TO trs_suite_txtp_configs;
ALTER TABLE public.trs_bucket_enrichment_records  RENAME TO trs_suite_enrichment_records;

-- FK column renames on child tables
ALTER TABLE public.trs_suite_generations   RENAME COLUMN bucket_id TO suite_id;
ALTER TABLE public.trs_suite_txtp_configs  RENAME COLUMN bucket_id TO suite_id;

-- Index renames
ALTER INDEX idx_sim_buckets_tenant  RENAME TO idx_sim_suites_tenant;
ALTER INDEX idx_sim_buckets_status  RENAME TO idx_sim_suites_status;
ALTER INDEX idx_sim_buckets_updated RENAME TO idx_sim_suites_updated;

-- Sequence rename (if applicable)
ALTER SEQUENCE trs_simulation_buckets_id_seq RENAME TO trs_simulation_suites_id_seq;
```

### Step 2 — ALTER TABLE `trs_simulation_suites`

```sql
ALTER TABLE public.trs_simulation_suites
  ADD COLUMN simulation_type      VARCHAR(30) NOT NULL DEFAULT 'SINGLE_RULE'
              CHECK (simulation_type IN ('SINGLE_RULE')),
  ADD COLUMN rule_repo             VARCHAR(255),
  ADD COLUMN primary_txtp          VARCHAR(50),
  ADD COLUMN primary_txtp_version  VARCHAR(50),
  ADD COLUMN metadata              JSONB NOT NULL DEFAULT '{}',
  ADD COLUMN wizard_progress       JSONB NOT NULL DEFAULT '{}',
  ALTER COLUMN rule_id DROP NOT NULL;

-- New indexes
CREATE INDEX idx_sim_suites_type ON trs_simulation_suites(simulation_type);
CREATE INDEX idx_sim_suites_rule ON trs_simulation_suites(rule_name);
```

Column notes:
- `rule_repo`: Docker Hub repo path, e.g. `myorg/rule-high-value`. Used for image pulls.
- `primary_txtp` + `primary_txtp_version`: Screen 1 TxTp selection — immutable after suite creation. Shown in the list page TXTP column.
- `metadata`: stores wizard draft envelope (`wizardDraft.screen1..screen5`) and future suite-level metadata.
- `wizard_progress`: tracks completed screens, e.g. `{ "screen1": true, "screen2": true }`. Used to resume the wizard.
- `rule_id`: made nullable — NULL for integration testing. May be NULL for single-rule if rule is identified solely by `rule_repo`.

`rule_id` note for this release:
- Keep nullable to support registry-based `rule_repo` identity in Single-Rule mode; integration-testing rationale is out-of-scope in this release.

### Step 3 — ALTER TABLE `trs_suite_generations`

```sql
ALTER TABLE public.trs_suite_generations
  ADD COLUMN simulation_type            VARCHAR(30) NOT NULL DEFAULT 'SINGLE_RULE',
  ADD COLUMN dems_function_table_count  INT4 NOT NULL DEFAULT 0,
  ADD COLUMN dems_configs               JSONB NOT NULL DEFAULT '[]';
```

Note: `rule_version` made nullable (NULL for integration testing).

### Step 4 — CREATE TABLE `trs_suite_dems_function_records` (NEW)

```sql
CREATE TABLE public.trs_suite_dems_function_records (
    id            SERIAL PRIMARY KEY,
    generation_id INT4 NOT NULL REFERENCES trs_suite_generations(id) ON DELETE CASCADE,
    table_name    VARCHAR(63) NOT NULL,
    row_index     INT4 NOT NULL,
    record_data   JSONB NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_dems_function_row UNIQUE(generation_id, table_name, row_index)
);
CREATE INDEX idx_dems_fn_gen_id    ON trs_suite_dems_function_records(generation_id);
CREATE INDEX idx_dems_fn_gen_table ON trs_suite_dems_function_records(generation_id, table_name);
```

Structurally identical to `trs_suite_enrichment_records`. Separate table so the orchestrator can distinguish which records go into DEMS vs ODS during init.

### Step 5 — CREATE TABLE `trs_integration_run_results` (DEFERRED — out of scope this delivery)

```sql
CREATE TABLE public.trs_integration_run_results (
    id                  SERIAL PRIMARY KEY,
    run_id              INT4 NOT NULL REFERENCES trs_simulation_runs(id) ON DELETE CASCADE,
    transaction_order   INT4 NOT NULL,
    txtp                VARCHAR(50) NOT NULL,
    sim_payload         JSONB NOT NULL,
    per_rule_results    JSONB NOT NULL,
    typology_result     JSONB,
    tadproc_result      JSONB,
    received_at         TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_integration_result UNIQUE(run_id, transaction_order)
);
CREATE INDEX idx_integ_results_run_id ON trs_integration_run_results(run_id);
```

This table is **not** required for Single-Rule release execution and should be delivered in a separate integration-focused migration to avoid inflating current deployment risk.

### Step 6 — CREATE TABLE `trs_integration_evaluations` (DEFERRED — out of scope this delivery)

```sql
CREATE TABLE public.trs_integration_evaluations (
    id                SERIAL PRIMARY KEY,
    run_id            INT4 NOT NULL REFERENCES trs_simulation_runs(id) ON DELETE CASCADE,
    evaluation_report JSONB NOT NULL,
    compiled_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_integration_eval UNIQUE(run_id)
);
CREATE INDEX idx_integ_eval_run_id ON trs_integration_evaluations(run_id);
```

This table is **not** required for Single-Rule release execution and should be delivered in a separate integration-focused migration.

### Step 7 — Triggers (§10.3)

New trigger: increment `dems_function_table_count` on `trs_suite_generations` when a row is inserted into `trs_suite_dems_function_records`. Mirrors the existing `enrichment_table_count` trigger pattern exactly.

Implementation hardening guidance:
- Use `IF EXISTS` / `IF NOT EXISTS` clauses (or guarded DO blocks) for renames/indexes to support rerunnable non-destructive deployment pipelines.
- Sequence/index rename assumptions must be validated in pre-prod before production rollout because the current repository does not contain authoritative baseline DDL for simulation tables.

---

## T-01 — Atomically Persist Wizard Data and Dispatch Orchestrator on Run
[Back to Top](#top)

**Start:** 21 May | **End:** 01 Jun

### Overview

T-01 covers the two critical backend operations on "Save Iteration": (1) the atomic database transaction converting all wizard draft data into a persisted iteration, and (2) the run-dispatch endpoint that triggers orchestrator execution. The DB work in HK-01 is treated as a **first-time schema initialization** prerequisite for this story.

### Backend — RS Backend

**`POST /api/v1/simulation-studio/suites/:id/run`** (§4.2):
1. Validate suite exists, `simulation_type = SINGLE_RULE`, suite is not already in an active run state, and caller has required RBAC claims.
2. Call `RegistryService.verifyImage(ruleRepo, ruleVersion)` before DB writes; return 422 if image/tag/digest cannot be resolved.
3. Call Admin Service `saveIterationTransactional()` to persist the new generation + run atomically.
4. Dispatch orchestrator asynchronously (fire-and-forget from HTTP handler).
5. If dispatch fails after commit, update the just-created run row to `FAILED` with an error reason and do not start any containers.
6. On successful dispatch, return `{ runId, status: 'ENV_PROVISIONING' }` immediately — caller does not wait for completion.

**`GET /api/v1/simulation-studio/suites/:id/runs/:runId/status`** (polling endpoint for SR-01):
- Returns `{ status, phase, error_message? }`
- Per T-03 updated AC: also returns `{ partialResults: ResultRowDto[] }` — incremental result rows for the frontend

### Admin Service — `saveIterationTransactional`

Single `BEGIN ... COMMIT` transaction. If any insert fails, entire transaction rolls back and orchestrator is never dispatched:

| Table | What is written |
|-------|----------------|
| `trs_suite_generations` | New immutable generation row (`generation_number`, `simulation_type`, `rule_repo`, `rule_version`, `context_count`, `trigger_count`, `enrichment_table_count`, snapshot metadata, `created_by`) |
| `trs_suite_context_txtp_configs`, `trs_suite_context_field_strategies`, `trs_suite_context_generated_messages` | Context TXTP config + per-field faker strategy + generated context payload snapshots |
| `trs_suite_trigger_txtp_configs`, `trs_suite_trigger_field_overrides`, `trs_suite_trigger_generated_messages` | Trigger TXTP config + override strategy + generated trigger payload snapshots |
| `trs_suite_enrichment_tables`, `trs_suite_enrichment_field_strategies`, `trs_suite_enrichment_generated_rows` | Enrichment table configs + per-column strategies + generated enrichment records |
| `trs_suite_context_sim_pairs`, `trs_suite_context_sim_payloads` | Deterministic context-trigger pairing and pair-level payload snapshots used by the run |
| `trs_suite_txtp_configs` | Compatibility snapshot rows (dataset role + txTp/version) when required by consumer APIs |
| `trs_simulation_runs` | New run row with `run_number = max + 1`, `status = 'ENV_PROVISIONING'`, `phase = 'ENV_PROVISIONING'`, image metadata, `triggered_by` |
| `trs_simulation_suites` | Suite counters and status update (`iteration_count += 1`, `run_count += 1`, `status = 'RUNNING'`, `last_run_at` refreshed) |

### Database

All tables listed above are written in one transaction boundary. Status flow for `trs_simulation_runs` remains `ENV_PROVISIONING → RUNNING → COMPLETED / FAILED` (with `TIMED_OUT`/`CANCELLED` available for exceptional paths).

### Prerequisites

- HK-01 (first-time Simulation Studio schema initialization completed in the target DB)
- S5-01 (`POST /api/v1/simulation-studio/suites/:id/run` triggered from Screen 5)
- S1-01 (`RegistryService.verifyImage()` implemented)
- T-02 (orchestrator dispatch service available; stub allowed for integration-first rollout)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 1 | First-time Simulation Studio DB initialization script for HK-01 (no legacy renames), including suites, generations, context/trigger/enrichment config + generated tables, pairing, runs, and results. |
| Dev B | Day 3 | Implement Admin Service `saveIterationTransactional` covering full generation + run persistence in one DB transaction, including rollback semantics and run-number allocation (`max + 1`). |
| Dev B | Day 5 | Implement RS Backend run endpoints: `POST /api/v1/simulation-studio/suites/:id/run` with registry pre-check + async orchestrator dispatch, plus `GET /api/v1/simulation-studio/suites/:id/runs/:runId/status` returning status/phase/error and `partialResults` payload. |

---

## SR-01 — Run a Simulation and Observe Results Upon Completion
[Back to Top](#top)

**Start:** 01 Jun | **End:** 03 Jun

### Overview

SR-01 covers Screen 6 of the wizard — the Results screen. The user is navigated here automatically after clicking "Save Iteration" on Screen 5. They see a non-interactive waiting state while the run is in progress. When the run reaches a terminal state, results are displayed without any manual action. Per the user story: results are only shown once the full run is complete and all rows are seeded — there are no incremental result updates in the UI (even though the backend supports partial results via T-03 for future use).

### Frontend — `<SimulationStudioWizard />` Screen 6

Screen 6 is reached after `POST /api/v1/simulation-studio/suites/:id/run` succeeds on Screen 5. It can render as a post-run screen inside the wizard or via redirect to `/simulation-studio/view/:id/run/:runId` under `<SimulationStudioView />`, but it remains non-stepper in both cases.

**Waiting state:**
- Non-interactive loading indicator: "Simulation in progress…"
- RTK Query polling on `GET /api/v1/simulation-studio/suites/:id/runs/:runId/status` every 2s until `COMPLETED` or `FAILED`

**On `FAILED`:**
- Clear failure state displayed with `error_message` from the status response
- No partial results shown

**On `COMPLETED`:**
- Fetch `GET /api/v1/simulation-studio/suites/:id/runs/:runId/results`
- Render results table: one row per sim transaction ordered by `transaction_order ASC`
- **Result row columns:** Trigger Message ID · Independent Variable · Result Band chip · Expected IV · Expected Band chip · Notes
- **Band chip colours:** green (good) · grey (neutral) · orange (bad) · red (error)
- Current run expanded at top; previous runs for same suite listed collapsed below

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/simulation-studio/suites/:id/runs/:runId/status` | Polled every 2s. Returns `{ status, phase, error_message? }` (and `partialResults` for backend compatibility with T-03). |
| GET | `/api/v1/simulation-studio/suites/:id/runs/:runId/results` | Fetched once on COMPLETED. Returns `{ results: ResultRowDto[] }`. |

### Prerequisites

- S5-01 (`POST /api/v1/simulation-studio/suites/:id/run` triggered from Screen 5; `runId` received)
- T-01 (run endpoint and status contracts)
- T-02 (orchestrator runs the environment)
- T-03 (result rows written for display)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 5 | `GET /api/v1/simulation-studio/suites/:id/runs/:runId/status` endpoint — reads from `trs_simulation_runs`, returns `{ status, phase, error_message? }` (+ `partialResults`), with status transitions from orchestrator callbacks. |
| Dev A | Day 7 | Screen 6 FE in Simulation Studio flow — polling loop (start on Screen 5 → Screen 6 transition, stop on terminal status), non-interactive waiting state, FAILED display, COMPLETED → results fetch and table render, previous runs collapsed section. |

---

## SR-02 — View Simulation Results with Band-Coded Outcome Per Transaction
[Back to Top](#top)

**Start:** 03 Jun | **End:** 03 Jun

### Overview

SR-02 covers the results display detail on Screen 6 — summary stat cards, per-transaction table with colour-coded band chips, Expected IV and Expected Band comparison, and multi-run collapsed view.

### Frontend — `<SimulationStudioWizard />` Screen 6 (completed state)

Results rendering can occur in the Screen 6 post-run view of the wizard or in `/simulation-studio/view/:id/run/:runId` under `<SimulationStudioView />`, but both use the same data contracts and comparison behavior.

**Summary stat cards** (per SR-02 AC):
- **Total Iterations** — number of runs completed for this suite
- **Latest Success Rate** — percentage of transactions in the most recent run where Result Band = Expected Band
- **Total Messages Processed** — sum of trigger message counts across all completed runs for this suite
- **Active Dataset** — suite name + current iteration identifier (e.g. "My Suite · Iteration 3")

**Result row columns:** Trigger Message ID · Independent Variable · Result Band chip · Expected IV · Expected Band chip · Notes

- Expected IV and Expected Band are stored with the sim transaction configuration at creation time and do not change between runs (per SR-02 assumptions)
- Where Result Band ≠ Expected Band: highlight the delta visually
- Most recent run expanded at top; prior runs collapsed below, each expandable for direct comparison

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/simulation-studio/suites/:id/runs/:runId/results?page=&limit=` | Paginated result rows for a run. |
| GET | `/api/v1/simulation-studio/suites/:id/runs` | All runs for a suite with metadata (run number, status, rule version, created_at). Populates collapsed prior-runs list. |

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_run_results` | SELECT WHERE `run_id = $1` ORDER BY `transaction_order ASC`, paginated |
| `trs_simulation_runs` | SELECT WHERE generation is related to this suite — for all-runs list |

### Prerequisites

- T-03 (result rows persisted)
- SR-01 (Screen 6 shell in Simulation Studio flow — completed state triggers results fetch)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 7 | Summary stat card components, band chip component (string → colour mapping), Expected Band delta highlight, expandable prior-runs section. Covered by SR-01 Day 7 task. |
| Dev B | Day 7 | `GET /api/v1/simulation-studio/suites/:id/runs/:runId/results` paginated endpoint and `GET /api/v1/simulation-studio/suites/:id/runs` list endpoint. Admin Service: paginated result query. |

---

## T-02 — Orchestrate an Isolated Docker Container Lifecycle Per Run
[Back to Top](#top)

**Start:** 01 Jun | **End:** 04 Jun

### Overview

T-02 implements the full Docker orchestration engine for single-rule simulation runs. Per §8.1, orchestration is programmatic via Dockerode — no Docker Compose. The ephemeral environment for single-rule is four containers: Postgres, NATS, nats-utilities, and the rule processor (§8.2).

### Backend Services (RS Backend — `orchestrator/` directory, §6.1)

**`single-rule-env.builder.ts`** — builds `SingleRuleEnvSpec`:

```typescript
interface SingleRuleEnvSpec {
  type: 'SINGLE_RULE';
  runId: number;
  networkName: string;              // sim-run-{runId}
  containers: {
    postgres:      ContainerSpec;
    nats:          ContainerSpec;
    natsUtilities: ContainerSpec;
    ruleProcessor: ContainerSpec;   // image pinned to exact SHA256 digest from verifyImage()
  };
  init: {
    odsTables:          TableSpec[];
    contextInserts:     ContextInsertSpec[];
    enrichmentTables:   EnrichmentTableSpec[];
    demsFunctionTables: DemsFunctionTableSpec[];  // empty in Single-Rule scope for this release
  };
  transactionLoop: { simPairs: SimPairSpec[]; haltOnError: boolean };
}
```

**`ods-init.service.ts`:**
- `CREATE TABLE` for ODS history tables (rule-specific schema)
- `INSERT` context rows (from `trs_suite_context_sim_payloads`)
- `CREATE TABLE` + `INSERT` for each enrichment table (from `trs_suite_enrichment_tables` + `trs_suite_enrichment_generated_rows`)
- `CREATE TABLE` + `INSERT` for any DEMS function tables (none in this Single-Rule delivery; leave extension point only)

**`transaction-loop.service.ts`:**
- For each sim pair: `POST` to nats-utilities with `await=true`
- Per-transaction timeout: `TRANSACTION_TIMEOUT_MS` (default 30s)
- Result written immediately after each transaction (not batched) to enable T-03 partial results

**`env-registry.service.ts`:** Concurrency pool. Max `MAX_CONCURRENT_SIM_ENVS` (default 4 for single-rule, §3.4). Returns 429 if pool full.

### Single-Rule Run Sequence (§4.2)

```
1. POST /api/v1/simulation-studio/suites/:id/run → validate → verifyImage → saveIterationTransactional → dispatch orchestrator
2. Create Docker bridge network: sim-run-{runId}          (status: ENV_PROVISIONING)
3. Start Postgres + NATS in parallel → poll until healthy
4. ODS init: CREATE + INSERT context and enrichment tables (DEMS function set empty in Single-Rule)
5. Start nats-utilities → start rule processor → poll healthy (status: RUNNING)
6. Transaction loop: submit each sim pair sequentially (await=true)
7. Teardown: stop containers in reverse order → remove network
8. trs_simulation_runs.status → COMPLETED / FAILED
```

Per T-02 acceptance criteria: the rule processor image is pinned to the exact SHA256 digest returned by `RegistryService.verifyImage()` at POST /run time — not pulled by mutable tag.

### Infrastructure

- **Dockerode** (npm) — Docker Engine API client. Unchanged from Rev 2.1 (§8.1).
- **Docker daemon access (§8.7):** Dev: Unix socket (`/var/run/docker.sock`). Production: remote TCP+TLS via `DOCKER_HOST`, `DOCKER_TLS_CERT_PATH`, `DOCKER_TLS_KEY_PATH`. **This decision must be made before Day 5** (§15.1 high-severity risk).

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `MAX_CONCURRENT_SIM_ENVS` | 4 | Single-rule env concurrency cap |
| `DOCKER_HOST` | unix socket | Docker daemon endpoint |
| `CONTAINER_HEALTH_TIMEOUT_MS` | 120000 | Max ms to wait for container healthy (T-04) |
| `TRANSACTION_TIMEOUT_MS` | 30000 | Per-transaction timeout in loop (T-04) |

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_runs` | `ENV_PROVISIONING → RUNNING → COMPLETED / FAILED`. `started_at`, `completed_at`, `error_message` written. |
| `trs_simulation_suites` | `last_run_at` updated on completion. |

### Prerequisites

- T-01 (`trs_simulation_runs` row must exist before orchestrator can begin)
- HK-02 (RS Backend module — `orchestrator/` directory)
- HK-05 (Docker Hub auth — needed to pull rule processor image by digest)
- HK-01 (first-time Simulation Studio schema initialization completed in the target DB)
- Infrastructure: Docker daemon access decision made before Day 5

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 5 | Orchestrator foundation: Dockerode client setup, Docker network create/remove helpers, `single-rule-env.builder.ts` (builds EnvSpec from run + generation data), `env-registry.service.ts` (concurrency pool), container start/stop lifecycle helpers. |
| Dev B | Day 6 | `ods-init.service.ts` — SQL rendering for ODS history tables, context inserts, and enrichment table create/insert from generation snapshots. `transaction-loop.service.ts` — sequential sim pair POST to nats-utilities, per-transaction timeout, immediate result write per transaction (not batched). |
| Dev C | Day 6 | `orchestrator.service.ts` — full startup sequence: parallel Postgres+NATS start, health check polling (pg_isready / HTTP health endpoints), sequential nats-utilities → rule processor start, ODS init invocation, transaction loop invocation, teardown. |
| Dev C | Day 8 | Crash recovery on RS Backend startup (§8.8): scan Docker for networks/containers with `run_id` label; orphaned run detection; teardown + `status = FAILED`. Full teardown idempotency hardening. |

---

## T-03 — Persist One Result Row Per Sim Transaction
[Back to Top](#top)

**Start:** 02 Jun | **End:** 02 Jun

### Overview

After each sim transaction is submitted and a response is received from nats-utilities, the orchestrator persists a result row **immediately** (not batched at end of run). Per the updated T-03 acceptance criteria, the status polling endpoint (`GET /api/v1/simulation-studio/suites/:id/runs/:runId/status`) includes incremental result data (`partialResults`) so partial progress is visible. If the rule processor returns an error for a transaction, `result_band = 'error'` is written and the run continues — individual transaction errors do not abort the loop.

### Backend

Result row written immediately after each transaction:
- Orchestrator → Admin Service result persistence handler via `AdminServiceClient` (one call per transaction)
- On loop completion: `trs_simulation_runs.status = 'COMPLETED'`, `completed_at = NOW()`

**Data extracted from nats-utilities response per transaction:**
- `result_band` — the band string (good / neutral / bad / error)
- `independent_variable` — the numeric IV value
- `trigger_message_external_id` — propagated message identifier for UI traceability
- `trigger_txtp` — transaction type used for this submitted message
- `rule_processor_response` — full response JSONB for audit
- `expected_independent_variable` and `expected_result_band` are copied from generation snapshot data when available (for SR-02 comparisons)

**Polling response augmentation** (`GET /api/v1/simulation-studio/suites/:id/runs/:runId/status` extended):
```json
{
  "status": "RUNNING",
  "phase": "TRANSACTION_LOOP",
  "partialResults": [
    {
      "transaction_order": 0,
      "trigger_message_external_id": "E2E-1001",
      "result_band": "good",
      "independent_variable": 142.5
    }
  ]
}
```

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_run_results` | INSERT per transaction: `run_id`, `transaction_order`, `trigger_message_id`, `trigger_message_external_id`, `trigger_txtp`, `independent_variable`, `result_band`, `expected_independent_variable`, `expected_result_band`, `notes`, `rule_processor_response`, `received_at`. |

### Prerequisites

- T-02 (transaction loop must run to produce results)
- T-01 (`trs_simulation_runs` row must exist)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 6 | Admin Service result persistence handler — validate result row DTO, INSERT one row to `trs_simulation_run_results`, update run status to COMPLETED on loop end. Extend `GET /api/v1/simulation-studio/suites/:id/runs/:runId/status` response to include `partialResults`. |
| Dev C | Day 6 | Wire per-transaction result write in `transaction-loop.service.ts` — after each nats-utilities response, call Admin Service result persistence immediately before the next transaction. Parse and persist `result_band`, `independent_variable`, `trigger_message_external_id`, `trigger_txtp`, and `rule_processor_response`. |

---

## SR-03 — Search and Filter Simulation History
[Back to Top](#top)

**Start:** 03 Jun | **End:** 03 Jun

### Overview

SR-03 adds search and filter capability to the results page iteration list — finding specific runs by simulation ID, rule version, or date. Scoped to the results page within a suite.

### Frontend — Screen 6 and `<SimulationStudioView />`

Filtering applies to the run-history panel rendered in Screen 6 and the suite run-history view at `/simulation-studio/view/:id` (including deep-link run context at `/simulation-studio/view/:id/run/:runId`).

- **Search box** — filters iteration list to rows whose run ID or rule version contains the search string
- **Rule Version filter** — dropdown in expandable filter panel; Apply and Clear buttons
- **Date filter** — date picker in filter panel; Apply and Clear buttons
- **Clear All** — resets all filters and restores the full iteration list
- **Expand All / Collapse All** — expands or collapses all iteration result rows

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/simulation-studio/suites/:id/runs?ruleVersion=&dateFrom=&dateTo=&search=&page=&limit=` | Filtered, paginated run history for a suite. |

### Prerequisites

- SR-02 (results + run list available on Screen 6)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 7 | Add `ruleVersion`, `dateFrom`, `dateTo`, `search` filter params to `GET /api/v1/simulation-studio/suites/:id/runs`. Admin Service: run history query with these filter dimensions. |

---

## T-04 — Handle Container Startup Failures and Run Timeouts Gracefully
[Back to Top](#top)

**Start:** 03 Jun | **End:** 04 Jun

### Overview

T-04 layers defensive error handling on top of the orchestrator — health check timeouts, per-transaction timeouts, graceful teardown on any failure, and crash recovery on RS Backend startup.

### Backend

**Container health check timeout:**
- Per-container: if healthy status not reached within `CONTAINER_HEALTH_TIMEOUT_MS` (default 120s): abort startup, trigger full teardown, write `status = 'FAILED'`, `phase = 'FAILED'`, and `error_message = 'Container {name} failed health check after {n}ms'`.

**Per-transaction timeout:**
- Each nats-utilities call has a timeout of `TRANSACTION_TIMEOUT_MS` (default 30s)
- On timeout: write `result_band = 'error'` for that transaction and continue (run does not abort for individual transaction errors)
- If total run timeout (`RUN_TIMEOUT_MS`, configurable) is exceeded: halt loop, trigger teardown, and mark run terminal (`status = 'FAILED'` with timeout reason; optional `TIMED_OUT` internal code in metadata).

**Teardown on failure:**
- Regardless of failure phase: stop all running containers, remove Docker network, write FAILED terminal state
- Teardown must be idempotent — safe even if some containers never started

**Crash recovery on RS Backend startup (§8.8):**
- Query Docker for all networks/containers with a `run_id` label
- For each: check `trs_simulation_runs.status`
- If non-terminal (`ENV_PROVISIONING` or `RUNNING`): invoke teardown, write `status = 'FAILED'`, `phase = 'FAILED'`, `error_message = 'Recovered: RS Backend restarted while run was active'`.

**Failure visibility contract:**
- `GET /api/v1/simulation-studio/suites/:id/runs/:runId/status` must return terminal failure state and reason (`error_message`) immediately after orchestrator failure/timeout handling completes.

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_runs` | UPDATE `status = 'FAILED'`, `phase = 'FAILED'`, `error_message`, `completed_at = NOW()` on any terminal failure |

### Prerequisites

- T-02 (orchestrator core must be built before failure modes can be layered in)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev C | Day 7 | Per-container health check timeout logic, halt-on-failure teardown trigger, FAILED terminal state write with structured error message, per-transaction timeout handling (error result + continue vs total run timeout + halt). |
| Dev C | Day 8 | Crash recovery on RS Backend startup — Docker network label query, orphaned run detection, teardown + FAILED write. Teardown idempotency hardening (handle already-stopped containers gracefully). |

---

## SM-03 — View Suite Details and Iteration History
[Back to Top](#top)

**Start:** 02 Jun | **End:** 02 Jun

### Overview

The `<SimulationStudioView />` page displays a suite's metadata and all past iterations. Per the updated user stories, the Iteration History table shows: Gen label, Created Date, Context count, Trigger count, Status, Simulation Results, and Rule Version. A "Use" action on completed iterations navigates to the Rule Studio Simulation tab with that suite pre-selected.

### Frontend — `<SimulationStudioView />`

- Route: `/simulation-studio/view/:id` (with deep-link run context at `/simulation-studio/view/:id/run/:runId`)
- **Overview section:** Suite Name, Description, Status badge, Associated Rule + version, Primary TxTp, Created By, Created At
- **Iteration History table** — most recent at top:
  - Gen label (e.g. "Iteration 1")
  - Created Date
  - Context count, Trigger count
  - Status badge
  - Simulation Results (link to results view)
  - Rule Version
  - **Actions:** Quick Rerun (RR-02), Rerun with New Data (SM-04), Use (COMPLETED iterations only — navigates to Rule Studio Simulation tab)
- Back arrow → list page

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/simulation-studio/suites/:id` | Full suite detail including `generations[]` (iterations) and `runs[]` per generation. |

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | SELECT by `id` + `tenant_id` |
| `trs_suite_generations` | SELECT WHERE `suite_id = $1` ORDER BY `generation_number DESC` |
| `trs_simulation_runs` | SELECT WHERE `generation_id IN (...)` — for run status per iteration |

### Prerequisites

- SM-02 (navigation comes from list page View action)
- T-01 (at least one iteration must exist for history)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 6 | Full `<SimulationStudioView />` component — overview card, iteration history table with all columns, Quick Rerun + Rerun with New Data + Use buttons (Quick Rerun wired in RR-02, Rerun with New Data in SM-04 — rendered here as stubs on Day 6). |

---

## SM-04 — Run a New Iteration in an Existing Suite
[Back to Top](#top)

**Start:** 02 Jun | **End:** 02 Jun

### Overview

SM-04 is the "Rerun with New Data" flow — the wizard opens pre-populated from the most recent iteration so the user can change the rule version and/or any screen data, then save a new iteration. The rule and primary TxTp are locked; only rule version is editable (per S1-01 edit mode behaviour).

### Frontend

- **"Rerun with New Data"** button on each iteration row in `<SimulationStudioView />` → navigates to `/simulation-studio/edit/:id?generation={generationId}`
- `<SimulationStudioWizard />` in edit mode: `GET /api/v1/simulation-studio/suites/:id` fetches suite + specified generation's `wizardDraft`
- Screen 1: rule and primary TxTp locked (read-only labels), rule version dropdown editable
- All subsequent screens: pre-populated from stored configs, all editable
- Screen 5 warning banner: "Saving will create a new iteration and will not overwrite previous ones"
- On Save Iteration: `POST /api/v1/simulation-studio/suites/:id/run` creates a new `trs_suite_generations` row (`generation_number = max + 1`) + new `trs_simulation_runs` row

### API

Same wizard creation path. No new endpoints. `/simulation-studio/edit/:id` reuses:
- `GET /api/v1/simulation-studio/suites/:id`
- `PUT /api/v1/simulation-studio/suites/:id/draft`
- `POST /api/v1/simulation-studio/suites/:id/run`

### Prerequisites

- SM-03 (Rerun with New Data button on ViewSimulation page)
- SM-01 (wizard supports full pre-population from stored generation data)
- T-01 (`POST /api/v1/simulation-studio/suites/:id/run` path)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 6 | Wire "Rerun with New Data" button to `/simulation-studio/edit/:id?generation={generationId}`. Ensure `<SimulationStudioWizard />` in edit mode pre-populates from the specified generation. Rule + TxTp locked. Warning banner on Screen 5. |

---

## SM-05 — Clone an Existing Suite
[Back to Top](#top)

**Start:** 04 Jun | **End:** 04 Jun

### Overview

Cloning creates a new independent suite pre-populated from the source suite's wizard configuration. Per the updated user stories: rule and primary TxTp are locked (cannot be changed), version can be changed, TXTPs in Screen 2 cannot be added or removed. The clone **also copies simulation run results** (per SM-05 assumptions: "Cloning copies wizard configuration, along with the simulation run results").

### Frontend

- Route: `/simulation-studio/clone/:id` → `<SimulationStudioWizard />` in clone mode
- On load: `GET /api/v1/simulation-studio/suites/:id` fetches source suite + most recent iteration's `wizardDraft`
- **Screen 1:** Suite Name pre-filled as "Copy of [Original Name]" (editable). Rule locked. Primary TxTp locked. Rule version editable.
- **Screen 2:** TXTPs pre-populated. Add TXTP and Remove TXTP buttons hidden (cannot add or remove TXTPs — per SM-05 assumptions)
- All other screens: pre-populated, editable
- On Save (Screen 5): `POST /api/v1/simulation-studio/suites` with `clone_source_suite_id` → new suite created → `POST /api/v1/simulation-studio/suites/:sourceSuiteId/clone-results` to copy result history into the newly created suite

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/simulation-studio/suites/:id` | Fetch source suite + iteration configs for pre-population. |
| POST | `/api/v1/simulation-studio/suites` | Creates new suite with `clone_source_suite_id = {sourceId}`. |
| POST | `/api/v1/simulation-studio/suites/:id/clone-results` | Copies `trs_simulation_runs` + `trs_simulation_run_results` rows from source suite's completed runs to a target suite. Returns `{ copiedRunCount }`. |

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_suites` | INSERT with `clone_source_suite_id = {source suite id}` |
| `trs_simulation_runs`, `trs_simulation_run_results` | Rows copied from source suite's completed runs |

### Prerequisites

- All wizard FE screens complete (SM-01, S1-01, S2-01, S3-01, S4-01, S5-01)
- SM-02 (Clone icon on list page)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev A | Day 8 | Clone mode in `<SimulationStudioWizard />` — detect `/simulation-studio/clone/:id`, fetch source suite, map to wizard initial state, lock rule + TxTp labels (hide dropdowns), hide Add/Remove TXTP on Screen 2, "Copy of [Name]" pre-fill on Screen 1, send `clone_source_suite_id` on `POST /api/v1/simulation-studio/suites`. |
| Dev B | Day 8 | `POST /api/v1/simulation-studio/suites/:id/clone-results` endpoint — copy `trs_simulation_runs` + `trs_simulation_run_results` rows from source suite's completed iterations to the target suite. |

---

## RR-01 — Rerun a Past Iteration from Simulation Result Page
[Back to Top](#top)

**Start:** 04 Jun | **End:** 04 Jun

### Overview

Quick Rerun dispatches a new run using the exact stored iteration data — no wizard, no changes. Invoked from Screen 6 (Results) with a "Rerun" button against a specific iteration. Any user with access can trigger a rerun (supporting separation of duties for independent verification).

### Frontend

- **Rerun** button on each iteration row in Screen 6 (current run and prior runs collapsed section)
- On click: `POST /api/v1/simulation-studio/suites/:id/generations/:generationId/quick-rerun` → receive `{ runId, status: 'ENV_PROVISIONING' }` → switch Screen 6 to non-interactive loading state for the new run → poll status endpoint → display results when complete

### API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/v1/simulation-studio/suites/:id/generations/:generationId/quick-rerun` | No body. Fetches existing generation data, inserts new `trs_simulation_runs` row (`run_number = MAX + 1`, atomic to prevent race), dispatches orchestrator with same `SingleRuleEnvSpec`. Returns `{ runId, status }`. |

### Database

| Table | Operation |
|-------|-----------|
| `trs_simulation_runs` | INSERT: `suite_id = existing suite`, `generation_id = existing`, `run_number = SELECT MAX(run_number) + 1` (locked per suite+generation), `status = 'ENV_PROVISIONING'` |

### Prerequisites

- SR-01 (Screen 6 where the Rerun button lives)
- T-01 (run dispatch pattern — quick rerun skips `saveIterationTransactional`, reuses existing generation)
- T-02 (orchestrator handles re-running an existing generation via same code path)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 8 | Quick rerun endpoint (`POST /api/v1/simulation-studio/suites/:id/generations/:generationId/quick-rerun`) — fetch existing generation, atomic INSERT new run row, rebuild `SingleRuleEnvSpec` from persisted generation data, dispatch orchestrator. |

---

## RR-02 — Rerun a Past Iteration from Simulation Suite History
[Back to Top](#top)

**Start:** 04 Jun | **End:** 04 Jun

### Overview

Identical backend behaviour to RR-01. Entry point differs: the "Rerun" button is on the Iteration History table in `<SimulationStudioView />` (SM-03), not on Screen 6. A new run sub-row appears under the iteration once complete with its own `started_at` and `triggered_by`.

### Frontend

- **Rerun** button per iteration row in `<SimulationStudioView />` Iteration History table (stub rendered on Day 6 by Dev A — wired here)
- On click: same `POST /api/v1/simulation-studio/suites/:id/generations/:generationId/quick-rerun` endpoint
- Iteration row shows a non-interactive loading state while run is in progress
- On completion: new run sub-row appears under the iteration with `started_at` and `triggered_by`

### API

Same endpoint as RR-01.

### Prerequisites

- SM-03 (SimulationStudioView page with Rerun button stub from Day 6)
- RR-01 (endpoint shared)

### Task Division

| Assignee | Day | Work |
|----------|-----|------|
| Dev B | Day 8 | Covered by RR-01 endpoint. |
| Dev A | Day 8 | Wire the Rerun button on iteration rows in `<SimulationStudioView />` (stubbed Day 6). Show per-row loading state on click, refresh iteration history on completion to show new run sub-row with `started_at` and `triggered_by`. |

---

# Out-of-Scope Notes

## T-05 — Push Rule Processor Image to Registry on Deployment
[Back to Top](#top)

T-05 is out of scope for the Simulation Studio implementation. This story concerns the deployment pipeline that builds and pushes versioned rule processor Docker images to the container registry. Simulation Studio **reads** from the registry; it does not push to it. T-05 is a CI/CD and DevOps concern external to this module.

**Action required before Day 5 (first run):** confirm with the DevOps / platform team that at least one rule processor image is available in the Docker Hub namespace under the agreed naming convention (`{namespace}/rule-{name}:{version}`). T-02 smoke testing cannot proceed without a pullable image. The image digest must be retrievable via `RegistryService.verifyImage()` for the run dispatch to succeed.

---

*End of report. All section references are to the Simulation Studio Implementation Plan, Release 4, Rev 2.2.*
