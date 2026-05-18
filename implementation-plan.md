# Synthetic Data Factory — Implementation Plan

## 1. Executive Summary

The Synthetic Data Factory is a new Rule Studio capability enabling `trs_editor` and `trs_data_engineer` roles to generate, store, edit, clone, and reuse synthetic data for rule simulations. The feature spans all three tiers:

- **Rule Studio Frontend** — New pages, wizard, field configuration UI, list/table views
- **Rule Studio Backend** — New NestJS module with controller, service, DTOs, admin-service client methods
- **Admin Service** — New handlers, logic services, repository, DB tables, validation schemas

The architecture follows established conventions: NestJS modules with class-validator DTOs on the backend, Fastify handlers with TypeBox schemas on admin-service, RTK Query API slices with MUI components on the frontend. Data flows through the existing chain: Frontend → RS Backend → Admin Service → PostgreSQL.

The core data model is the **Simulation Bucket** — an append-only, auditable container holding context-sim data pairs, each bound to specific rule versions and TXTP schemas. The design supports multiple TXTPs per simulation from day one.

**Key architectural decisions:**

- Append-only generation (historical pairs are never overwritten)
- Multi-TXTP support via a junction/group model
- Schema-driven field configuration UI (not raw JSON editors)
- Immutable generation records with full lineage tracking
- BullMQ for async generation of large payloads (reusing existing queue pattern)

---

## 2. Existing Architecture Findings

### 2.1 Overall Architecture

The system is a three-tier architecture:

```
Rule Studio Frontend (React 19 + MUI + RTK Query)
    ↓ HTTP (Bearer JWT)
Rule Studio Backend (NestJS + BullMQ + Socket.io)
    ↓ HTTP (Bearer JWT passthrough)
Admin Service (Fastify + TypeBox/AJV)
    ↓ SQL (pg)
PostgreSQL (configuration database)
```

### 2.2 Key Conventions Discovered

| Area | Convention |
|------|-----------|
| **Backend modules** | `{feature}.module.ts`, `{feature}.controller.ts`, `{feature}.service.ts`, `dto/{feature}.dto.ts` |
| **Admin service** | Handler functions in `app.controller.ts`, logic in `services/{feature}.logic.service.ts`, DB in `repositories/configuration/{feature}.repository.ts` |
| **DB access** | Raw parameterized SQL via `handlePostExecuteSqlStatement()`, no ORM |
| **Validation (admin)** | `@sinclair/typebox` schemas compiled by AJV |
| **Validation (backend)** | `class-validator` decorators on DTO classes, global `ValidationPipe` |
| **Validation (frontend)** | Yup schemas with React Hook Form |
| **Auth** | JWT tokens via `@tazama-lf/auth-lib`, claim-based RBAC, 3-tier permission system |
| **Pagination** | Offset/limit with total count, POST body for filters |
| **Filtering** | Dynamic WHERE clause building with parameterized queries, ILIKE for search |
| **Status lifecycle** | `STATUS_01_IN_PROGRESS` → `STATUS_02_ON_HOLD` → ... → `STATUS_08_DEPLOYED` |
| **Audit** | `@Audit()` decorator + interceptor, `trs_simulation_logs` table with old/new JSONB |
| **Async jobs** | BullMQ with Redis, WebSocket progress via Socket.io gateway |
| **State management** | RTK Query API slices with mutations for filtered lists, queries for lookups |
| **Frontend lists** | Controller hook pattern (`useXxxController`) + `<Table>` + `<CustomPagination>` |
| **Frontend forms** | React Hook Form + yupResolver + MUI controlled inputs |
| **Tenant isolation** | `tenant_id` column on all tables, extracted from JWT |
| **JSON storage** | JSONB columns with `JSON.stringify()` on insert, type-cast on read |
| **API naming** | Admin: `/v1/admin/{domain}/{resource}/{action}`, RS Backend: `/{feature}/api/{action}` |

---

## 3. Relevant Existing Systems

### 3.1 TCS Config — TXTP Schema & Payload Source

**Admin Service Endpoint:** `GET /v1/admin/config/payload/:transactionType/:transactionVersion`

**Repository:** `admin-service/src/repositories/configuration/tcs.config.repository.ts`

- `getPayloadByTransactionType(txtp, version, tenantId)` — Returns JSON schema and sample payload
- `getSchemaByTransactionType(txtp, version, tenantId)` — Returns schema definition
- `findAllTransactionTypes(tenantId)` — Returns available transaction types

**RS Backend Service:** `rule-studio/backend/src/services/config/config.service.ts`

- `getTransactionTypes(user, endpointKey)` — Lists all TXTPs
- `getVersionsOfTransactionType(txtp, user, endpointKey)` — Lists versions
- `getPayloadByTransactionType(txtp, version, user, endpointKey)` — Gets schema + payload

**RS Frontend Redux:** `redux/Api/Config/index.ts`

- `useGetTypesQuery()` — Fetches transaction types
- `useLazyGetPayloadQuery()` — Fetches schema/payload on demand

This existing chain will be reused for Step 1 (Rule Selection) and TXTP schema fetching.

### 3.2 Existing Simulation System

**Admin Service Endpoints:**

- `GET /v1/admin/trs/simulation/all` — List simulations
- `POST /v1/admin/trs/simulation/create` — Create simulation record
- `GET /v1/admin/trs/simulation/get_simulation_stats` — Stats
- `GET /v1/admin/trs/simulation/get_simulation_results` — Results

**RS Backend:**

- `SimulationModule` — CRUD + BullMQ job processing
- `SendToDemsModule` — Triggers async simulation via queue
- `SimulationProgressGateway` — WebSocket real-time updates
- `SimulationProcessor` — BullMQ worker for processing

**Note:** The existing simulation system processes DLH-sourced data against deployed rules. The Synthetic Data Factory is a **separate** system for generating synthetic data. It does NOT replace the existing simulation pipeline — it produces data that will eventually feed into it.

### 3.3 Existing Rule CRUD Flow

**Create:** Frontend → `POST /rules/api/create` → RS Backend → `POST /v1/admin/trs/rule` → Admin Service → `trs_rules` table

**List:** Frontend → `POST /rules/api/all` (offset/limit + filters body) → RS Backend → `POST /v1/admin/trs/rules/:offset/:limit` → Admin Service → paginated response

**Clone:** Frontend → `POST /rules/api/:ruleId/clone` → RS Backend → `POST /v1/admin/trs/rule/clone/:ruleId` → Admin Service → deep copy + new IDs

### 3.4 Simulation Logs (Audit)

**Table:** `trs_simulation_logs` — stores `old_data`/`new_data` JSONB with `category`, `description`, `rule_id`, `created_by`, `created_by_email`

**Admin Service:** `simulation-logs.logic.service.ts` + `simulation-logs.repository.ts`

**RS Backend:** `SimulationLogsModule` — passthrough to admin service

---

## 4. Repository-by-Repository Analysis

### 4.1 Admin Service (`admin-service/`)

**Files to CREATE:**

| File | Purpose |
|------|---------|
| `src/services/synthetic-data.logic.service.ts` | Business logic for synthetic data CRUD, generation, validation |
| `src/repositories/configuration/synthetic-data.repository.ts` | DB access for all synthetic data tables |
| `src/interface/synthetic-data.interface.ts` | TypeScript interfaces for all entities |
| `src/schemas/syntheticDataSchema.ts` | TypeBox validation schemas |

**Files to MODIFY:**

| File | Change |
|------|--------|
| `src/app.controller.ts` | Add synthetic data route handlers |
| `src/router.ts` | Register new routes with RBAC claims |

### 4.2 Rule Studio Backend (`rule-studio/backend/`)

**Files to CREATE:**

| File | Purpose |
|------|---------|
| `src/services/synthetic-data/synthetic-data.module.ts` | NestJS module |
| `src/services/synthetic-data/synthetic-data.controller.ts` | REST endpoints |
| `src/services/synthetic-data/synthetic-data.service.ts` | Business logic + admin client calls |
| `src/services/synthetic-data/dto/synthetic-data.dto.ts` | Request/response DTOs |
| `src/services/synthetic-data/dto/index.ts` | DTO barrel export |

**Files to MODIFY:**

| File | Change |
|------|--------|
| `src/app.module.ts` | Import `SyntheticDataModule` |
| `src/services/admin-service-client.ts` | Add synthetic data endpoint methods |
| `src/constants/constant.ts` | Add endpoint constants |
| `src/utils/rbac/permissionMatrix.json` | Add synthetic data endpoint permissions |

### 4.3 Rule Studio Frontend (`rule-studio/frontend/`)

**Files to CREATE:**

| File | Purpose |
|------|---------|
| `src/pages/SyntheticData/index.tsx` | List page |
| `src/pages/SyntheticData/useSyntheticDataController.tsx` | List page controller |
| `src/pages/SyntheticData/CreateSimulation/index.tsx` | Multi-step wizard |
| `src/pages/SyntheticData/CreateSimulation/useCreateSimulationController.tsx` | Wizard controller |
| `src/pages/SyntheticData/CreateSimulation/Steps/RuleSelection.tsx` | Step 1 |
| `src/pages/SyntheticData/CreateSimulation/Steps/FieldConfiguration.tsx` | Step 2 — schema-driven config |
| `src/pages/SyntheticData/CreateSimulation/Steps/ContextGeneration.tsx` | Step 3 |
| `src/pages/SyntheticData/CreateSimulation/Steps/SimGeneration.tsx` | Step 4 |
| `src/pages/SyntheticData/CreateSimulation/Steps/Preview.tsx` | Step 5 |
| `src/pages/SyntheticData/CreateSimulation/Steps/Summary.tsx` | Step 6 |
| `src/pages/SyntheticData/ViewSimulation/index.tsx` | View/edit simulation |
| `src/pages/SyntheticData/ViewSimulation/useViewSimulationController.tsx` | View controller |
| `src/components/FieldConfigurator/index.tsx` | Schema-driven field config component |
| `src/components/FieldConfigurator/FieldRow.tsx` | Individual field config row |
| `src/components/FieldConfigurator/types.ts` | Field configurator types |
| `src/components/Stepper/index.tsx` | Multi-step wizard stepper |
| `src/redux/Api/SyntheticData/index.ts` | RTK Query API slice |
| `src/validation/schemas/syntheticDataSchema.ts` | Yup validation schemas |

**Files to MODIFY:**

| File | Change |
|------|--------|
| `src/routes/index.tsx` | Add synthetic data routes |
| `src/layout/Sidebar/index.tsx` | Add "Synthetic Data" menu item |
| `src/redux/Store/index.ts` | Register `syntheticDataApi` reducer + middleware |
| `src/utils/Common/types.ts` | Add synthetic data TypeScript types |

---

## 5. Current Rule Flow Analysis

### 5.1 Rule Creation Flow

```
1. User clicks "Create New Rule" on Home page
2. Navigates to /editor (RuleEditor)
3. Overview tab: select Rule Config, Rule Name, Version, TXTP, TXTP Version
4. Parser tab: upload/paste ISO 20022 payload → validates against TXTP schema
5. Rule Builder tab: visual flow editor (nodes/edges)
6. Simulation tab: send payload to DEMS for execution
7. Test Cases tab: generate test cases from flow
8. History tab: audit log
```

### 5.2 How TXTP Schema is Fetched

```
Frontend: useGetTypesQuery() → GET /config/api/transaction-types
Frontend: useLazyGetPayloadQuery({ txtp, version }) → GET /config/payload/:txtp/:version
    ↓
RS Backend ConfigController → ConfigService.getPayloadByTransactionType()
    ↓ AdminServiceClient.getPayloadByTransactionType()
Admin Service → tcs.config.repository → getPayloadByTransactionType()
    ↓ SQL: SELECT schema, payload_json FROM tcs_config WHERE transaction_type = $1 AND version = $2
    Returns: { schema: JSONSchema, payload: SamplePayload, mapping: FieldMapping[] }
```

This chain is reused directly in the Synthetic Data Factory for Step 1 (Rule Selection).

### 5.3 How Simulation Execution Works

```
1. SendToDemsService.enqueueSimulation(token, tableNames)
2. Creates BullMQ job with SimulationJobPayload
3. SimulationProcessor.process(job):
   a. Fetches messages from admin-service simulation tables
   b. For each message: POST to DEMS endpoint with payload
   c. Emits progress via WebSocket (5% thresholds)
4. Frontend receives progress via Socket.io
5. Results stored in evaluation tables, queried via simulation stats/results endpoints
```

The Synthetic Data Factory will produce data that can later be fed into this pipeline.

---

## 6. Proposed Feature Architecture

### 6.1 High-Level Flow

```
┌─────────────────────────────────────────────────────────┐
│                    Rule Studio Frontend                   │
│                                                          │
│  SyntheticData List Page                                 │
│    ├─ View simulation buckets                            │
│    ├─ Edit (append new pairs)                            │
│    ├─ Clone                                              │
│    └─ Create New Simulation (wizard)                     │
│         Step 1: Rule Selection + TXTP fetch              │
│         Step 2: Field Configuration (per TXTP)           │
│         Step 3: Context Data count + generate            │
│         Step 4: Sim Data count + generate                │
│         Step 5: Preview generated pair                   │
│         Step 6: Save to bucket                           │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP
┌────────────────────────▼────────────────────────────────┐
│               Rule Studio Backend (NestJS)               │
│                                                          │
│  SyntheticDataModule                                     │
│    ├─ SyntheticDataController                            │
│    ├─ SyntheticDataService                               │
│    └─ DTOs (class-validator)                             │
│         ↓ AdminServiceClient                             │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP
┌────────────────────────▼────────────────────────────────┐
│                 Admin Service (Fastify)                   │
│                                                          │
│  synthetic-data handlers (app.controller.ts)             │
│  synthetic-data.logic.service.ts                         │
│  synthetic-data.repository.ts                            │
│         ↓ SQL                                            │
│  PostgreSQL: configuration database                      │
│    ├─ trs_simulation_buckets                             │
│    ├─ trs_bucket_generations                             │
│    ├─ trs_generation_txtp_configs                        │
│    ├─ trs_context_sim_pairs                              │
│    └─ trs_context_sim_payloads                           │
└─────────────────────────────────────────────────────────┘
```

### 6.2 Why This Architecture

- **Follows existing convention exactly:** Frontend → RS Backend → Admin Service → DB
- **RS Backend has no direct DB access** (consistent with all existing modules)
- **Admin Service owns all persistence** (consistent with rules, masking, configs)
- **No new infrastructure** — reuses PostgreSQL, Redis, existing auth
- **No NATS dependency** — admin service is REST-only (confirmed by exploration)

---

## 7. Frontend Design

### 7.1 Routing Additions

Add to `rule-studio/frontend/src/routes/index.tsx`:

```typescript
{ path: '/synthetic-data', element: <SyntheticDataList />, private: true, layout: true, roleGroup: 'trs' },
{ path: '/synthetic-data/create', element: <CreateSimulation />, private: true, layout: true, roleGroup: 'trs' },
{ path: '/synthetic-data/edit/:id', element: <CreateSimulation />, private: true, layout: true, roleGroup: 'trs' },
{ path: '/synthetic-data/view/:id', element: <ViewSimulation />, private: true, layout: true, roleGroup: 'trs' },
{ path: '/synthetic-data/clone/:id', element: <CreateSimulation />, private: true, layout: true, roleGroup: 'trs' },
```

### 7.2 Sidebar Addition

Add to `trsMenuItems` array in `layout/Sidebar/index.tsx`:

```typescript
{ icon: ScienceOutlinedIcon, label: "Synthetic Data", route: "synthetic-data", color: "#4789f6" }
```

### 7.3 List Page Design

**Page:** `pages/SyntheticData/index.tsx`

Follows exact pattern of `pages/Home/index.tsx`:

**Header:** DatasetIcon + "Synthetic Data Factory" + "Create New Simulation" button (top-right, editor/data-engineer only)

**Filters:**

- Search by simulation name (ILIKE)
- Status dropdown (All, Draft, Generated, Archived)
- Rule Association dropdown (All, or specific rule names)
- Reset button

**Table Columns:**

| Label | Key | Type | Custom Render |
|-------|-----|------|---------------|
| Simulation Name | name | — | — |
| Rule | rule_name | — | — |
| TXTP(s) | txtp_list | — | Comma-joined |
| Pairs Count | pair_count | — | — |
| Status | status | — | StatusCard |
| Created At | created_at | date | — |
| Created By | created_by | — | — |
| Actions | actions | — | View/Edit/Clone |

**Controller Hook:** `useSyntheticDataController.tsx`

```typescript
// State
- searchTerm: string
- status: DropdownOption | null
- ruleFilter: DropdownOption | null
- data: SimulationBucket[]
- total: number
- offset, limit (from useFilters)

// RTK Query
- useGetSimulationBucketsMutation()  // POST with filters

// Table actions
- onView(id) → navigate('/synthetic-data/view/:id')
- onEdit(id) → navigate('/synthetic-data/edit/:id')  // only if status allows
- onClone(id) → navigate('/synthetic-data/clone/:id')
```

**Permissions Enforcement:**

- "Create New Simulation" button visible only for `trs_editor` or `trs_data_engineer_editor`
- Edit action visible only for buckets in `DRAFT` or `GENERATED` status
- Clone action always visible for `trs_editor` or `trs_data_engineer_editor`
- View action always visible for all authorized roles

### 7.4 Create New Simulation Wizard

**Page:** `pages/SyntheticData/CreateSimulation/index.tsx`

Uses a custom `<Stepper>` component (MUI Stepper under the hood) with 6 steps.

**Mode detection** via URL:

- `/synthetic-data/create` → create mode
- `/synthetic-data/edit/:id` → edit mode (skip Step 1, load existing config)
- `/synthetic-data/clone/:id` → clone mode (pre-fill from existing, new ID)

#### Step 1 — Rule Selection (`Steps/RuleSelection.tsx`)

**UI Elements:**

- Simulation Name input (required, unique)
- Simulation Description textarea (optional, max 500 chars)
- Rule Selection dropdown (optional — uses existing `useGetRulesMutation()`)
- When rule selected → auto-populate TXTP info
- "Add TXTP" button for multi-TXTP support
- For each TXTP entry:
  - TXTP dropdown (uses `useGetTypesQuery()`)
  - Version dropdown (uses `useLazyGetVersionsQuery()`)
  - Remove button (if > 1 TXTP)

**On selecting a rule:**

```typescript
// Reuse existing config endpoint
const configPayload = await getPayload({ txtp, version }).unwrap();
// configPayload contains: { schema, payload, mapping }
// Store in wizard state for Step 2
```

**Validation (Yup):**

```typescript
name: yup.string().required('Simulation name is required').max(100),
description: yup.string().max(500),
txtpConfigs: yup.array().of(
  yup.object({ txtp: yup.string().required(), version: yup.string().required() })
).min(1, 'At least one TXTP configuration is required'),
```

#### Step 2 — Field Configuration (`Steps/FieldConfiguration.tsx`)

**Per TXTP, per payload type (context + sim):**

Renders the `<FieldConfigurator>` component for each TXTP schema.

Tabs: one tab per TXTP (if multiple TXTPs), sub-tabs for Context Config / Sim Config.

The `<FieldConfigurator>` recursively renders the JSON Schema fields.

#### Step 3 — Context Data Generation (`Steps/ContextGeneration.tsx`)

**UI Elements:**

- Count input (number, min: 1, max: 300)
- "Generate Context Data" button
- Progress indicator (if async)
- Generated payload preview (first item, collapsible JSON view)

#### Step 4 — Sim Data Generation (`Steps/SimGeneration.tsx`)

**UI Elements:**

- Count input (number, min: 1, max: 150)
- "Generate Sim Data" button
- Progress indicator
- Generated payload preview

#### Step 5 — Preview (`Steps/Preview.tsx`)

**UI Elements:**

- Summary card: name, rule, TXTP(s), context count, sim count
- First context-sim pair displayed side-by-side
- Expandable JSON viewer (reuse existing `<JsonFormatter>`)
- Validation status indicator
- "Regenerate" button to go back

#### Step 6 — Summary & Save (`Steps/Summary.tsx`)

**UI Elements:**

- Full summary of configuration
- "Save to Bucket" button
- Confirmation modal
- Success/error toast

### 7.5 FieldConfigurator Component

**File:** `components/FieldConfigurator/index.tsx`

This is the most complex new UI component. It renders a recursive tree of schema fields, each with a configuration strategy.

**Component Hierarchy:**

```
<FieldConfigurator schema={jsonSchema} onConfigChange={handler}>
  <FieldRow field={field} depth={0}>
    ├─ Field name label
    ├─ Strategy selector dropdown:
    │   ├─ "Keep sample value" (default)
    │   ├─ "Static value" → shows input
    │   ├─ "Numeric range" → shows min/max inputs (numbers only)
    │   ├─ "Random/Generated" → shows generation options
    │   ├─ "Null" → sets to null
    │   └─ "Skip" → omits field
    ├─ Value input (contextual based on strategy)
    └─ If object/array → recurse:
        <FieldRow field={childField} depth={1}>
          ...
        </FieldRow>
  </FieldRow>
</FieldConfigurator>
```

**Props:**

```typescript
interface FieldConfiguratorProps {
  schema: JSONSchema;
  samplePayload?: Record<string, unknown>;
  config: FieldConfig[];
  onConfigChange: (config: FieldConfig[]) => void;
  readOnly?: boolean;
}
```

**FieldConfig Type:**

```typescript
interface FieldConfig {
  path: string;           // JSON path (e.g., "transaction.amount.value")
  strategy: FieldStrategy;
  staticValue?: unknown;
  rangeMin?: number;
  rangeMax?: number;
  generatorType?: string; // 'uuid', 'name', 'date', 'enum', etc.
  generatorOptions?: Record<string, unknown>;
}

type FieldStrategy = 'keep_sample' | 'static' | 'range' | 'generated' | 'null' | 'skip';
```

**Recursive Rendering Strategy:**

1. Parse JSON Schema `properties` at each level
2. For `type: "object"` → render collapsible section, recurse into `properties`
3. For `type: "array"` → render with `items` schema, allow count config
4. For `type: "string"` → offer text input, enum selector, or generators
5. For `type: "number"` / `"integer"` → offer static value or range
6. For `type: "boolean"` → offer true/false/random toggle
7. For unsupported/complex schemas → show warning, allow raw JSON input fallback

**Array Handling:**

- Display array item schema configuration
- Additional field: "Array length" (min: 1, max: 50)
- Each array item uses same field config

**Deeply Nested Schema Handling:**

- Indentation increases with depth
- Collapsible sections for objects
- Breadcrumb path display for deep nesting
- Max depth warning at depth > 10

**Validation UX:**

- Real-time validation as user configures fields
- Red border on invalid configurations
- Tooltip with validation error message
- "Validate Configuration" button summarizes all issues

### 7.6 State Management

**New RTK Query Slice:** `redux/Api/SyntheticData/index.ts`

```typescript
export const syntheticDataApi = createApi({
  reducerPath: 'syntheticDataApi',
  baseQuery: fetchBaseQuery({
    baseUrl: `${VITE_API_URL}/synthetic-data/api/`,
    prepareHeaders: (headers) => {
      const token = getAuthToken();
      if (token) headers.set('authorization', `Bearer ${token}`);
      return headers;
    },
  }),
  tagTypes: ['syntheticData'],
  endpoints: (builder) => ({
    getSimulationBuckets: builder.mutation({
      query: ({ params, body }) => ({
        url: 'all',
        method: 'POST',
        params,
        body,
      }),
    }),
    getBucketById: builder.query({
      query: (id) => `${id}`,
      providesTags: ['syntheticData'],
    }),
    createBucket: builder.mutation({
      query: (body) => ({ url: 'create', method: 'POST', body }),
      invalidatesTags: ['syntheticData'],
    }),
    cloneBucket: builder.mutation({
      query: ({ id }) => ({ url: `clone/${id}`, method: 'POST' }),
      invalidatesTags: ['syntheticData'],
    }),
    generateContextData: builder.mutation({
      query: ({ bucketId, body }) => ({
        url: `${bucketId}/generate/context`,
        method: 'POST',
        body,
      }),
    }),
    generateSimData: builder.mutation({
      query: ({ bucketId, body }) => ({
        url: `${bucketId}/generate/sim`,
        method: 'POST',
        body,
      }),
    }),
    saveGeneration: builder.mutation({
      query: ({ bucketId, body }) => ({
        url: `${bucketId}/generation/save`,
        method: 'POST',
        body,
      }),
      invalidatesTags: ['syntheticData'],
    }),
    getGenerations: builder.query({
      query: ({ bucketId, params }) => ({
        url: `${bucketId}/generations`,
        params,
      }),
    }),
    getPairById: builder.query({
      query: ({ bucketId, pairId }) => `${bucketId}/pairs/${pairId}`,
    }),
  }),
});
```

### 7.7 Wizard State Management

The wizard uses local React state via `useReducer` to manage the multi-step flow:

```typescript
interface WizardState {
  step: number;
  mode: 'create' | 'edit' | 'clone';
  bucketId?: string;
  name: string;
  description: string;
  ruleId?: number;
  ruleName?: string;
  txtpConfigs: TxtpConfig[];
  contextFieldConfigs: Record<string, FieldConfig[]>; // keyed by txtp
  simFieldConfigs: Record<string, FieldConfig[]>;     // keyed by txtp
  contextCount: number;
  simCount: number;
  generatedContextData?: Record<string, unknown>[];
  generatedSimData?: Record<string, unknown>[];
  previewPair?: ContextSimPair;
  isDirty: boolean;
}
```

---

## 8. Backend Design (Rule Studio Backend)

### 8.1 Module Structure

```
src/services/synthetic-data/
├── synthetic-data.module.ts
├── synthetic-data.controller.ts
├── synthetic-data.service.ts
└── dto/
    ├── index.ts
    └── synthetic-data.dto.ts
```

### 8.2 Module

```typescript
// synthetic-data.module.ts
@Module({
  imports: [HttpModule],
  controllers: [SyntheticDataController],
  providers: [SyntheticDataService, AdminServiceClient],
})
export class SyntheticDataModule {}
```

### 8.3 Controller

```typescript
@ApiTags('Synthetic Data')
@ApiBearerAuth('JWT-auth')
@Controller('synthetic-data')
@UseGuards(TazamaAuthGuard)
export class SyntheticDataController {

  @Post('/api/all')
  @RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.DATA_ENGINEER_EDITOR,
                     TazamaClaims.APPROVER, TazamaClaims.DATA_ENGINEER_APPROVER)
  @Audit()
  async getAllBuckets(
    @Query('offset', new DefaultValuePipe(0), ParseIntPipe) offset: number,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
    @Body() filters: BucketFiltersDto,
    @AuthUser() user: AuthenticatedUser,
  ): Promise<BucketListResponseDto> {}

  @Get('/api/:id')
  @RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.DATA_ENGINEER_EDITOR,
                     TazamaClaims.APPROVER, TazamaClaims.DATA_ENGINEER_APPROVER)
  async getBucketById(
    @Param('id', ParseIntPipe) id: number,
    @AuthUser() user: AuthenticatedUser,
  ): Promise<BucketDetailResponseDto> {}

  @Post('/api/create')
  @RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.DATA_ENGINEER_EDITOR)
  @Audit()
  async createBucket(
    @Body() body: CreateBucketDto,
    @AuthUser() user: AuthenticatedUser,
  ): Promise<CreateBucketResponseDto> {}

  @Post('/api/clone/:id')
  @RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.DATA_ENGINEER_EDITOR)
  @Audit()
  async cloneBucket(
    @Param('id', ParseIntPipe) id: number,
    @AuthUser() user: AuthenticatedUser,
  ): Promise<CreateBucketResponseDto> {}

  @Post('/api/:id/generate/context')
  @RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.DATA_ENGINEER_EDITOR)
  @Audit()
  async generateContextData(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: GenerateDataDto,
    @AuthUser() user: AuthenticatedUser,
  ): Promise<GenerateDataResponseDto> {}

  @Post('/api/:id/generate/sim')
  @RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.DATA_ENGINEER_EDITOR)
  @Audit()
  async generateSimData(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: GenerateDataDto,
    @AuthUser() user: AuthenticatedUser,
  ): Promise<GenerateDataResponseDto> {}

  @Post('/api/:id/generation/save')
  @RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.DATA_ENGINEER_EDITOR)
  @Audit()
  async saveGeneration(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: SaveGenerationDto,
    @AuthUser() user: AuthenticatedUser,
  ): Promise<SaveGenerationResponseDto> {}

  @Get('/api/:id/generations')
  @RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.DATA_ENGINEER_EDITOR,
                     TazamaClaims.APPROVER, TazamaClaims.DATA_ENGINEER_APPROVER)
  async getGenerations(
    @Param('id', ParseIntPipe) id: number,
    @Query('offset', new DefaultValuePipe(0), ParseIntPipe) offset: number,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
    @AuthUser() user: AuthenticatedUser,
  ): Promise<GenerationListResponseDto> {}

  @Get('/api/:id/pairs/:pairId')
  @RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.DATA_ENGINEER_EDITOR,
                     TazamaClaims.APPROVER, TazamaClaims.DATA_ENGINEER_APPROVER)
  async getPairById(
    @Param('id', ParseIntPipe) bucketId: number,
    @Param('pairId', ParseIntPipe) pairId: number,
    @AuthUser() user: AuthenticatedUser,
  ): Promise<PairDetailResponseDto> {}

  @Put('/api/:id')
  @RequireAnyClaims(TazamaClaims.EDITOR, TazamaClaims.DATA_ENGINEER_EDITOR)
  @Audit()
  async updateBucket(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: UpdateBucketDto,
    @AuthUser() user: AuthenticatedUser,
  ): Promise<UpdateBucketResponseDto> {}
}
```

### 8.4 DTOs

```typescript
// === Request DTOs ===

export class BucketFiltersDto {
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() status?: string;
  @IsOptional() @IsString() ruleId?: string;
  @IsOptional() @IsString() sortOrder?: 'ASC' | 'DESC';
}

export class TxtpConfigDto {
  @IsString() @IsNotEmpty() txtp: string;
  @IsString() @IsNotEmpty() version: string;
  @IsOptional() @IsObject() schema?: Record<string, unknown>;
  @IsOptional() @IsObject() samplePayload?: Record<string, unknown>;
}

export class FieldConfigDto {
  @IsString() @IsNotEmpty() path: string;
  @IsString() @IsNotEmpty() strategy: string; // keep_sample | static | range | generated | null | skip
  @IsOptional() staticValue?: unknown;
  @IsOptional() @IsNumber() rangeMin?: number;
  @IsOptional() @IsNumber() rangeMax?: number;
  @IsOptional() @IsString() generatorType?: string;
  @IsOptional() @IsObject() generatorOptions?: Record<string, unknown>;
}

export class CreateBucketDto {
  @IsString() @IsNotEmpty() name: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsNumber() ruleId?: number;
  @IsOptional() @IsString() ruleName?: string;
  @IsOptional() @IsString() ruleVersion?: string;
  @IsArray() @ValidateNested({ each: true }) @Type(() => TxtpConfigDto)
  txtpConfigs: TxtpConfigDto[];
}

export class GenerateDataDto {
  @IsInt() @Min(1) @Max(300) count: number;
  @IsArray() @ValidateNested({ each: true }) @Type(() => TxtpFieldConfigGroupDto)
  txtpFieldConfigs: TxtpFieldConfigGroupDto[];
}

export class TxtpFieldConfigGroupDto {
  @IsString() @IsNotEmpty() txtp: string;
  @IsString() @IsNotEmpty() version: string;
  @IsArray() @ValidateNested({ each: true }) @Type(() => FieldConfigDto)
  fieldConfigs: FieldConfigDto[];
}

export class SaveGenerationDto {
  @IsArray() contextData: Record<string, unknown>[];
  @IsArray() simData: Record<string, unknown>[];
  @IsArray() @ValidateNested({ each: true }) @Type(() => TxtpFieldConfigGroupDto)
  contextFieldConfigs: TxtpFieldConfigGroupDto[];
  @IsArray() @ValidateNested({ each: true }) @Type(() => TxtpFieldConfigGroupDto)
  simFieldConfigs: TxtpFieldConfigGroupDto[];
}

export class UpdateBucketDto {
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsString() status?: string;
}

// === Response DTOs ===

export class SimulationBucketDto {
  @ApiProperty() id: number;
  @ApiProperty() name: string;
  @ApiProperty() description: string;
  @ApiProperty() status: string;
  @ApiProperty() rule_id: number | null;
  @ApiProperty() rule_name: string | null;
  @ApiProperty() rule_version: string | null;
  @ApiProperty() pair_count: number;
  @ApiProperty() txtp_list: string;
  @ApiProperty() created_by: string;
  @ApiProperty() created_by_email: string;
  @ApiProperty() created_at: string;
  @ApiProperty() updated_at: string;
}

export class BucketListResponseDto {
  @ApiProperty() buckets: SimulationBucketDto[];
  @ApiProperty() total: number;
  @ApiProperty() limit: number;
  @ApiProperty() offset: number;
  @ApiProperty() pages: number;
}

export class CreateBucketResponseDto {
  @ApiProperty() success: boolean;
  @ApiProperty() message: string;
  @ApiProperty() bucket_id: number;
}

export class GenerateDataResponseDto {
  @ApiProperty() success: boolean;
  @ApiProperty() data: Record<string, unknown>[];
  @ApiProperty() count: number;
  @ApiProperty() validation_errors?: string[];
}

export class GenerationDto {
  @ApiProperty() id: number;
  @ApiProperty() bucket_id: number;
  @ApiProperty() generation_number: number;
  @ApiProperty() context_count: number;
  @ApiProperty() sim_count: number;
  @ApiProperty() created_by: string;
  @ApiProperty() created_at: string;
}

export class GenerationListResponseDto {
  @ApiProperty() generations: GenerationDto[];
  @ApiProperty() total: number;
  @ApiProperty() limit: number;
  @ApiProperty() offset: number;
}

export class PairDetailResponseDto {
  @ApiProperty() id: number;
  @ApiProperty() generation_id: number;
  @ApiProperty() context_data: Record<string, unknown>;
  @ApiProperty() sim_data: Record<string, unknown>;
  @ApiProperty() txtp_payloads: Record<string, unknown>[];
  @ApiProperty() created_at: string;
}
```

### 8.5 Service

```typescript
@Injectable()
export class SyntheticDataService {
  private readonly logger = new Logger(SyntheticDataService.name);

  constructor(private readonly adminServiceClient: AdminServiceClient) {}

  async getAllBuckets(offset, limit, filters, user): Promise<BucketListResponseDto> {
    const normalizedRole = this.rbacService.getNormalizedRole(user);
    const endpointKey = 'POST /synthetic-data/api/all';
    const tier2 = this.rbacService.getTier2({ role: normalizedRole, endpointKey });
    if (!tier2.allowed) throw new ForbiddenException(tier2.reason);

    return this.adminServiceClient.getAllSimulationBuckets(offset, limit, filters, user.token.tokenString);
  }

  async createBucket(body, user): Promise<CreateBucketResponseDto> {
    // 1. Validate TXTP configs exist via config endpoints
    // 2. Call admin service to create bucket
    // 3. Log audit
  }

  async generateData(bucketId, body, type: 'context' | 'sim', user): Promise<GenerateDataResponseDto> {
    // 1. Validate bucket exists and user has access
    // 2. Validate field configs against TXTP schemas
    // 3. Call admin service generation endpoint
    // 4. Return generated data for preview
  }

  async saveGeneration(bucketId, body, user): Promise<SaveGenerationResponseDto> {
    // 1. Validate both context and sim data present
    // 2. Call admin service to persist generation
    // 3. Update bucket pair count
    // 4. Log audit
  }

  async cloneBucket(id, user): Promise<CreateBucketResponseDto> {
    // 1. Fetch existing bucket
    // 2. Deep copy metadata (not generations)
    // 3. Create new bucket with clone lineage
  }
}
```

### 8.6 Admin Service Client Additions

Add to `admin-service-client.ts`:

```typescript
// Simulation Buckets
async getAllSimulationBuckets(offset, limit, filters, token): Promise<BucketListResponseDto>
async getSimulationBucketById(id, token): Promise<BucketDetailResponseDto>
async createSimulationBucket(body, token): Promise<CreateBucketResponseDto>
async updateSimulationBucket(id, body, token): Promise<UpdateBucketResponseDto>
async cloneSimulationBucket(id, token): Promise<CreateBucketResponseDto>

// Generation
async generateSyntheticData(bucketId, body, type, token): Promise<GenerateDataResponseDto>
async saveGeneration(bucketId, body, token): Promise<SaveGenerationResponseDto>
async getGenerations(bucketId, offset, limit, token): Promise<GenerationListResponseDto>
async getPairById(bucketId, pairId, token): Promise<PairDetailResponseDto>
```

### 8.7 Constants Additions

Add to `constants/constant.ts`:

```typescript
// Synthetic Data
export const SYNTHETIC_DATA_BASE = '/v1/admin/trs/synthetic-data';
export const SYNTHETIC_DATA_ALL = `${SYNTHETIC_DATA_BASE}/all`;
export const SYNTHETIC_DATA_CREATE = `${SYNTHETIC_DATA_BASE}/create`;
export const SYNTHETIC_DATA_CLONE = `${SYNTHETIC_DATA_BASE}/clone`;
export const SYNTHETIC_DATA_GENERATE = `${SYNTHETIC_DATA_BASE}/generate`;
export const SYNTHETIC_DATA_GENERATIONS = `${SYNTHETIC_DATA_BASE}/generations`;
export const SYNTHETIC_DATA_PAIRS = `${SYNTHETIC_DATA_BASE}/pairs`;
export const SYNTHETIC_DATA_SAVE_GENERATION = `${SYNTHETIC_DATA_BASE}/generation/save`;
```

---

## 9. Admin Service Design

### 9.1 Route Handlers

Add to `app.controller.ts` and register in `router.ts`:

| Handler | Method | Route | Claim |
|---------|--------|-------|-------|
| `getAllSimulationBucketsHandler` | POST | `/v1/admin/trs/synthetic-data/all/:offset/:limit` | `['editor', 'trs_data_engineer_editor', 'approver', 'trs_data_engineer_approver']` |
| `getSimulationBucketByIdHandler` | GET | `/v1/admin/trs/synthetic-data/:id` | same |
| `createSimulationBucketHandler` | POST | `/v1/admin/trs/synthetic-data/create` | `['editor', 'trs_data_engineer_editor']` |
| `updateSimulationBucketHandler` | PUT | `/v1/admin/trs/synthetic-data/:id` | `['editor', 'trs_data_engineer_editor']` |
| `cloneSimulationBucketHandler` | POST | `/v1/admin/trs/synthetic-data/clone/:id` | `['editor', 'trs_data_engineer_editor']` |
| `generateSyntheticDataHandler` | POST | `/v1/admin/trs/synthetic-data/:id/generate/:type` | `['editor', 'trs_data_engineer_editor']` |
| `saveGenerationHandler` | POST | `/v1/admin/trs/synthetic-data/:id/generation/save` | `['editor', 'trs_data_engineer_editor']` |
| `getGenerationsHandler` | GET | `/v1/admin/trs/synthetic-data/:id/generations/:offset/:limit` | same as list |
| `getPairByIdHandler` | GET | `/v1/admin/trs/synthetic-data/:bucketId/pairs/:pairId` | same as list |

### 9.2 Logic Service

**File:** `src/services/synthetic-data.logic.service.ts`

**Key Functions:**

```typescript
// Bucket CRUD
export async function handleGetAllBuckets(offset, limit, filters, tenantId): Promise<PaginatedResult<BucketRow>>
export async function handleGetBucketById(id, tenantId): Promise<BucketRow>
export async function handleCreateBucket(data: CreateBucketInput, tenantId): Promise<number>
export async function handleUpdateBucket(id, data: UpdateBucketInput, tenantId): Promise<void>
export async function handleCloneBucket(id, tenantId, userId): Promise<number>

// Generation
export async function handleGenerateSyntheticData(bucketId, fieldConfigs, count, type, tenantId): Promise<GeneratedPayload[]>
export async function handleSaveGeneration(bucketId, contextData, simData, configs, tenantId, userId): Promise<number>
export async function handleGetGenerations(bucketId, offset, limit, tenantId): Promise<PaginatedResult<GenerationRow>>
export async function handleGetPairById(bucketId, pairId, tenantId): Promise<PairRow>
```

**Generation Logic:**

The `handleGenerateSyntheticData` function:

1. Fetches bucket to validate it exists and belongs to tenant
2. For each TXTP config in the request:
   a. Fetches the TXTP schema from `tcs_config`
   b. Fetches the sample payload
   c. For each field config, applies the generation strategy:
      - `keep_sample` → uses value from sample payload
      - `static` → uses provided static value
      - `range` → generates random number in [min, max]
      - `generated` → applies generator (UUID, date, name, etc.)
      - `null` → sets to null
      - `skip` → omits field
3. Validates each generated payload against the TXTP schema using AJV
4. Returns array of generated payloads
5. Does NOT persist — persistence happens in `handleSaveGeneration`

**Validation in Generation:**

```typescript
const ajv = new Ajv({ allErrors: true });
addFormats(ajv);
const validate = ajv.compile(txtpSchema);

for (const payload of generatedPayloads) {
  const valid = validate(payload);
  if (!valid) {
    throw new HttpException(
      { message: 'Generated payload failed schema validation', errors: validate.errors },
      HttpStatus.BAD_REQUEST
    );
  }
}
```

### 9.3 Repository

**File:** `src/repositories/configuration/synthetic-data.repository.ts`

**Key Functions:**

```typescript
// Buckets
export async function createBucketInDB(data, tenantId): Promise<number>
export async function findBucketByIdFromDB(id, tenantId): Promise<BucketRow | null>
export async function findBucketsWithFiltersInDB(offset, limit, filters, tenantId): Promise<{ data: BucketRow[], total: number }>
export async function updateBucketInDB(id, data, tenantId): Promise<void>
export async function cloneBucketInDB(sourceId, tenantId, userId): Promise<number>

// TXTP Configs
export async function createTxtpConfigsInDB(bucketId, configs: TxtpConfigInput[], tenantId): Promise<void>
export async function getTxtpConfigsByBucketId(bucketId, tenantId): Promise<TxtpConfigRow[]>

// Generations
export async function createGenerationInDB(bucketId, generationNumber, contextCount, simCount, userId, tenantId): Promise<number>
export async function findGenerationsByBucketId(bucketId, offset, limit, tenantId): Promise<{ data: GenerationRow[], total: number }>

// Context-Sim Pairs
export async function createPairsInDB(generationId, pairs: PairInput[], tenantId): Promise<void>
export async function findPairByIdFromDB(pairId, bucketId, tenantId): Promise<PairRow | null>
export async function countPairsByBucketId(bucketId, tenantId): Promise<number>

// Payloads
export async function createPayloadsInDB(pairId, payloads: PayloadInput[]): Promise<void>
```

### 9.4 Interfaces

**File:** `src/interface/synthetic-data.interface.ts`

```typescript
export interface BucketRow {
  id: number;
  name: string;
  description: string | null;
  status: string;
  rule_id: number | null;
  rule_name: string | null;
  rule_version: string | null;
  clone_source_id: number | null;
  tenant_id: string;
  created_by: string;
  created_by_email: string | null;
  created_at: Date;
  updated_at: Date;
  metadata: Record<string, unknown>;
}

export interface TxtpConfigRow {
  id: number;
  bucket_id: number;
  txtp: string;
  version: string;
  schema_snapshot: Record<string, unknown>;
  sample_payload_snapshot: Record<string, unknown>;
  display_order: number;
}

export interface GenerationRow {
  id: number;
  bucket_id: number;
  generation_number: number;
  context_count: number;
  sim_count: number;
  context_field_configs: Record<string, unknown>;
  sim_field_configs: Record<string, unknown>;
  generation_metadata: Record<string, unknown>;
  created_by: string;
  created_by_email: string | null;
  created_at: Date;
}

export interface PairRow {
  id: number;
  generation_id: number;
  pair_index: number;
  context_data: Record<string, unknown>;
  sim_data: Record<string, unknown>;
  validation_status: string;
  created_at: Date;
}

export interface PayloadRow {
  id: number;
  pair_id: number;
  txtp: string;
  version: string;
  payload_type: 'context' | 'sim';
  payload_data: Record<string, unknown>;
}

export type BucketStatus = 'DRAFT' | 'GENERATED' | 'ARCHIVED';
```

### 9.5 TypeBox Validation Schemas

**File:** `src/schemas/syntheticDataSchema.ts`

```typescript
import { Type } from '@sinclair/typebox';

export const CreateBucketSchema = Type.Object({
  name: Type.String({ minLength: 1, maxLength: 100 }),
  description: Type.Optional(Type.String({ maxLength: 500 })),
  ruleId: Type.Optional(Type.Number()),
  ruleName: Type.Optional(Type.String()),
  ruleVersion: Type.Optional(Type.String()),
  txtpConfigs: Type.Array(
    Type.Object({
      txtp: Type.String({ minLength: 1 }),
      version: Type.String({ minLength: 1 }),
      schema: Type.Optional(Type.Object({}, { additionalProperties: true })),
      samplePayload: Type.Optional(Type.Object({}, { additionalProperties: true })),
    }),
    { minItems: 1 }
  ),
});

export const GenerateDataSchema = Type.Object({
  count: Type.Integer({ minimum: 1, maximum: 300 }),
  txtpFieldConfigs: Type.Array(
    Type.Object({
      txtp: Type.String({ minLength: 1 }),
      version: Type.String({ minLength: 1 }),
      fieldConfigs: Type.Array(
        Type.Object({
          path: Type.String({ minLength: 1 }),
          strategy: Type.String({ enum: ['keep_sample', 'static', 'range', 'generated', 'null', 'skip'] }),
          staticValue: Type.Optional(Type.Unknown()),
          rangeMin: Type.Optional(Type.Number()),
          rangeMax: Type.Optional(Type.Number()),
          generatorType: Type.Optional(Type.String()),
          generatorOptions: Type.Optional(Type.Object({}, { additionalProperties: true })),
        })
      ),
    })
  ),
});

export const SaveGenerationSchema = Type.Object({
  contextData: Type.Array(Type.Object({}, { additionalProperties: true }), { minItems: 1 }),
  simData: Type.Array(Type.Object({}, { additionalProperties: true }), { minItems: 1 }),
  contextFieldConfigs: Type.Array(Type.Object({
    txtp: Type.String(),
    version: Type.String(),
    fieldConfigs: Type.Array(Type.Unknown()),
  })),
  simFieldConfigs: Type.Array(Type.Object({
    txtp: Type.String(),
    version: Type.String(),
    fieldConfigs: Type.Array(Type.Unknown()),
  })),
});

export const UpdateBucketSchema = Type.Object({
  name: Type.Optional(Type.String({ minLength: 1, maxLength: 100 })),
  description: Type.Optional(Type.String({ maxLength: 500 })),
  status: Type.Optional(Type.String({ enum: ['DRAFT', 'GENERATED', 'ARCHIVED'] })),
});

export const BucketFilterSchema = Type.Object({
  name: Type.Optional(Type.String()),
  status: Type.Optional(Type.String()),
  ruleId: Type.Optional(Type.String()),
  sortOrder: Type.Optional(Type.String({ enum: ['ASC', 'DESC'] })),
});
```

---

## 10. API Contracts

### 10.1 Rule Studio Backend Endpoints

#### `POST /synthetic-data/api/all?offset=0&limit=10`

**Request Body:**
```json
{
  "name": "fraud",
  "status": "GENERATED",
  "ruleId": "42",
  "sortOrder": "DESC"
}
```

**Response:**
```json
{
  "buckets": [
    {
      "id": 1,
      "name": "Fraud Test Set A",
      "description": "High-value transactions",
      "status": "GENERATED",
      "rule_id": 42,
      "rule_name": "High Value Rule",
      "rule_version": "1.0.0",
      "pair_count": 25,
      "txtp_list": "pacs.008.001.10",
      "created_by": "user1",
      "created_by_email": "user1@example.com",
      "created_at": "2026-05-15T10:30:00Z",
      "updated_at": "2026-05-15T11:00:00Z"
    }
  ],
  "total": 1,
  "limit": 10,
  "offset": 0,
  "pages": 1
}
```

#### `POST /synthetic-data/api/create`

**Request Body:**
```json
{
  "name": "Fraud Test Set A",
  "description": "High-value transactions for rule 42",
  "ruleId": 42,
  "ruleName": "High Value Rule",
  "ruleVersion": "1.0.0",
  "txtpConfigs": [
    {
      "txtp": "pacs.008.001.10",
      "version": "10",
      "schema": { "type": "object", "properties": { ... } },
      "samplePayload": { "FIToFICstmrCdtTrf": { ... } }
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Simulation bucket created successfully",
  "bucket_id": 1
}
```

#### `POST /synthetic-data/api/:id/generate/context`

**Request Body:**
```json
{
  "count": 50,
  "txtpFieldConfigs": [
    {
      "txtp": "pacs.008.001.10",
      "version": "10",
      "fieldConfigs": [
        { "path": "FIToFICstmrCdtTrf.CdtTrfTxInf.Amt.InstdAmt.value", "strategy": "range", "rangeMin": 100, "rangeMax": 50000 },
        { "path": "FIToFICstmrCdtTrf.CdtTrfTxInf.Amt.InstdAmt.Ccy", "strategy": "static", "staticValue": "USD" },
        { "path": "FIToFICstmrCdtTrf.GrpHdr.MsgId", "strategy": "generated", "generatorType": "uuid" },
        { "path": "FIToFICstmrCdtTrf.GrpHdr.CreDtTm", "strategy": "generated", "generatorType": "datetime_recent" },
        { "path": "FIToFICstmrCdtTrf.CdtTrfTxInf.DbtrAgt.FinInstnId.Nm", "strategy": "keep_sample" }
      ]
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "data": [
    { "FIToFICstmrCdtTrf": { "GrpHdr": { "MsgId": "a1b2c3d4-...", ... }, ... } },
    ...
  ],
  "count": 50,
  "validation_errors": null
}
```

#### `POST /synthetic-data/api/:id/generate/sim`

Same schema as context, but `count` max is 150 instead of 300.

#### `POST /synthetic-data/api/:id/generation/save`

**Request Body:**
```json
{
  "contextData": [ { ... }, { ... } ],
  "simData": [ { ... }, { ... } ],
  "contextFieldConfigs": [ { "txtp": "pacs.008", "version": "10", "fieldConfigs": [...] } ],
  "simFieldConfigs": [ { "txtp": "pacs.008", "version": "10", "fieldConfigs": [...] } ]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Generation saved successfully",
  "generation_id": 5,
  "pair_count": 50
}
```

#### `POST /synthetic-data/api/clone/:id`

**Response:**
```json
{
  "success": true,
  "message": "Simulation bucket cloned successfully",
  "bucket_id": 2
}
```

#### `GET /synthetic-data/api/:id/generations?offset=0&limit=10`

**Response:**
```json
{
  "generations": [
    {
      "id": 5,
      "bucket_id": 1,
      "generation_number": 3,
      "context_count": 50,
      "sim_count": 25,
      "created_by": "user1",
      "created_at": "2026-05-15T11:00:00Z"
    }
  ],
  "total": 3,
  "limit": 10,
  "offset": 0
}
```

#### `GET /synthetic-data/api/:id/pairs/:pairId`

**Response:**
```json
{
  "id": 42,
  "generation_id": 5,
  "context_data": { ... },
  "sim_data": { ... },
  "txtp_payloads": [
    { "txtp": "pacs.008.001.10", "version": "10", "payload_type": "context", "data": { ... } },
    { "txtp": "pacs.008.001.10", "version": "10", "payload_type": "sim", "data": { ... } }
  ],
  "created_at": "2026-05-15T11:00:00Z"
}
```

### 10.2 Admin Service Endpoints

The admin service endpoints mirror the RS Backend endpoints, following the established pattern where RS Backend passes through to admin service:

| RS Backend | Admin Service |
|-----------|---------------|
| `POST /synthetic-data/api/all` | `POST /v1/admin/trs/synthetic-data/all/:offset/:limit` |
| `GET /synthetic-data/api/:id` | `GET /v1/admin/trs/synthetic-data/:id` |
| `POST /synthetic-data/api/create` | `POST /v1/admin/trs/synthetic-data/create` |
| `PUT /synthetic-data/api/:id` | `PUT /v1/admin/trs/synthetic-data/:id` |
| `POST /synthetic-data/api/clone/:id` | `POST /v1/admin/trs/synthetic-data/clone/:id` |
| `POST /synthetic-data/api/:id/generate/:type` | `POST /v1/admin/trs/synthetic-data/:id/generate/:type` |
| `POST /synthetic-data/api/:id/generation/save` | `POST /v1/admin/trs/synthetic-data/:id/generation/save` |
| `GET /synthetic-data/api/:id/generations` | `GET /v1/admin/trs/synthetic-data/:id/generations/:offset/:limit` |
| `GET /synthetic-data/api/:id/pairs/:pairId` | `GET /v1/admin/trs/synthetic-data/:bucketId/pairs/:pairId` |

---

## 11. Database Design

### 11.1 Entity Relationship Diagram

```
┌──────────────────────────┐
│  trs_simulation_buckets  │
│──────────────────────────│
│ id (PK, serial)          │
│ name                     │
│ description              │
│ status                   │  1
│ rule_id (FK nullable)    │──────┐
│ rule_name                │      │
│ rule_version             │      │
│ clone_source_id (self FK)│      │
│ tenant_id                │      │
│ created_by               │      │
│ created_by_email         │      │
│ metadata (JSONB)         │      │
│ created_at               │      │
│ updated_at               │      │
└─────────┬────────────────┘      │
          │ 1                      │
          │                        │ (optional link to trs_rules)
          ▼ *                      │
┌──────────────────────────────┐  │
│  trs_bucket_txtp_configs     │  │
│──────────────────────────────│  │
│ id (PK, serial)              │  │
│ bucket_id (FK)               │  │
│ txtp                         │  │
│ version                      │  │
│ schema_snapshot (JSONB)      │  │
│ sample_payload_snapshot (JSONB)│ │
│ display_order                │  │
│ tenant_id                    │  │
└──────────────────────────────┘  │
                                   │
┌──────────────────────────┐      │
│  trs_bucket_generations  │      │
│──────────────────────────│      │
│ id (PK, serial)          │      │
│ bucket_id (FK)           │◄─────┘ (same bucket)
│ generation_number        │
│ context_count            │  1
│ sim_count                │──────┐
│ context_field_configs (JSONB)│   │
│ sim_field_configs (JSONB)│      │
│ generation_metadata (JSONB)│    │
│ created_by               │      │
│ created_by_email         │      │
│ created_at               │      │
└─────────┬────────────────┘      │
          │ 1                      │
          ▼ *                      │
┌──────────────────────────────┐  │
│   trs_context_sim_pairs      │  │
│──────────────────────────────│  │
│ id (PK, serial)              │  │
│ generation_id (FK)           │  │
│ pair_index                   │  │
│ context_data (JSONB)         │  │
│ sim_data (JSONB)             │  │
│ validation_status            │  │
│ created_at                   │  │
└─────────┬────────────────────┘  │
          │ 1                      │
          ▼ *                      │
┌──────────────────────────────┐  │
│  trs_context_sim_payloads    │  │
│──────────────────────────────│  │
│ id (PK, serial)              │  │
│ pair_id (FK)                 │  │
│ txtp                         │  │
│ version                      │  │
│ payload_type ('context'|'sim')│  │
│ payload_data (JSONB)         │  │
│ created_at                   │  │
└──────────────────────────────┘  │
```

### 11.2 Table Definitions

#### `trs_simulation_buckets`

```sql
CREATE TABLE public.trs_simulation_buckets (
    id              serial PRIMARY KEY,
    name            varchar(100) NOT NULL,
    description     varchar(500),
    status          varchar(50) NOT NULL DEFAULT 'DRAFT',
    rule_id         int4,
    rule_name       varchar(100),
    rule_version    varchar(50),
    clone_source_id int4 REFERENCES trs_simulation_buckets(id),
    tenant_id       varchar(255) NOT NULL,
    created_by      varchar(255) NOT NULL,
    created_by_email varchar(255),
    metadata        jsonb DEFAULT '{}',
    created_at      timestamp NOT NULL DEFAULT NOW(),
    updated_at      timestamp NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sim_buckets_tenant ON trs_simulation_buckets(tenant_id);
CREATE INDEX idx_sim_buckets_status ON trs_simulation_buckets(status);
CREATE INDEX idx_sim_buckets_rule_id ON trs_simulation_buckets(rule_id);
CREATE INDEX idx_sim_buckets_created_at ON trs_simulation_buckets(created_at DESC);
CREATE INDEX idx_sim_buckets_name ON trs_simulation_buckets(name);
```

**Column Notes:**

- `name` — User-defined simulation name, searchable via ILIKE
- `status` — `DRAFT` (created, no generations yet), `GENERATED` (has at least one generation), `ARCHIVED` (soft archive)
- `rule_id` — Nullable FK to `trs_rules.id` (optional association)
- `rule_name`, `rule_version` — Denormalized for display (rule may be deleted later)
- `clone_source_id` — Self-referencing FK for lineage tracking
- `metadata` — Extensible JSONB for future fields (generation seed, strategy version, etc.)

#### `trs_bucket_txtp_configs`

```sql
CREATE TABLE public.trs_bucket_txtp_configs (
    id                       serial PRIMARY KEY,
    bucket_id                int4 NOT NULL REFERENCES trs_simulation_buckets(id) ON DELETE CASCADE,
    txtp                     varchar(50) NOT NULL,
    version                  varchar(50) NOT NULL,
    schema_snapshot          jsonb NOT NULL,
    sample_payload_snapshot  jsonb,
    display_order            int4 NOT NULL DEFAULT 0,
    tenant_id                varchar(255) NOT NULL
);

CREATE INDEX idx_bucket_txtp_bucket_id ON trs_bucket_txtp_configs(bucket_id);
```

**Column Notes:**

- `schema_snapshot` — Frozen copy of the TXTP schema at bucket creation time (immutable reference)
- `sample_payload_snapshot` — Frozen copy of sample payload
- `display_order` — Ordering of TXTPs within the bucket (for UI)
- These are snapshots so that generation is reproducible even if the source config changes

#### `trs_bucket_generations`

```sql
CREATE TABLE public.trs_bucket_generations (
    id                     serial PRIMARY KEY,
    bucket_id              int4 NOT NULL REFERENCES trs_simulation_buckets(id) ON DELETE CASCADE,
    generation_number      int4 NOT NULL,
    context_count          int4 NOT NULL,
    sim_count              int4 NOT NULL,
    context_field_configs  jsonb NOT NULL,
    sim_field_configs      jsonb NOT NULL,
    generation_metadata    jsonb DEFAULT '{}',
    created_by             varchar(255) NOT NULL,
    created_by_email       varchar(255),
    created_at             timestamp NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_bucket_generation UNIQUE(bucket_id, generation_number)
);

CREATE INDEX idx_generations_bucket_id ON trs_bucket_generations(bucket_id);
CREATE INDEX idx_generations_created_at ON trs_bucket_generations(created_at DESC);
```

**Column Notes:**

- `generation_number` — Auto-incremented per bucket (1, 2, 3, ...) for append-only semantics
- `context_field_configs`, `sim_field_configs` — Full field configuration used for this generation (frozen)
- `generation_metadata` — Extensible: `{ seed, strategy_version, generator_library_version, validation_summary }`
- Unique constraint prevents duplicate generation numbers per bucket

#### `trs_context_sim_pairs`

```sql
CREATE TABLE public.trs_context_sim_pairs (
    id                serial PRIMARY KEY,
    generation_id     int4 NOT NULL REFERENCES trs_bucket_generations(id) ON DELETE CASCADE,
    pair_index        int4 NOT NULL,
    context_data      jsonb NOT NULL,
    sim_data          jsonb NOT NULL,
    validation_status varchar(50) NOT NULL DEFAULT 'VALID',
    created_at        timestamp NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pairs_generation_id ON trs_context_sim_pairs(generation_id);
CREATE INDEX idx_pairs_validation ON trs_context_sim_pairs(validation_status);
```

**Column Notes:**

- `pair_index` — Order within the generation (0-based)
- `context_data` — Aggregated context payload (may contain multiple TXTP payloads)
- `sim_data` — Aggregated sim payload
- `validation_status` — `VALID`, `INVALID`, `SKIPPED`

#### `trs_context_sim_payloads`

```sql
CREATE TABLE public.trs_context_sim_payloads (
    id              serial PRIMARY KEY,
    pair_id         int4 NOT NULL REFERENCES trs_context_sim_pairs(id) ON DELETE CASCADE,
    txtp            varchar(50) NOT NULL,
    version         varchar(50) NOT NULL,
    payload_type    varchar(10) NOT NULL CHECK (payload_type IN ('context', 'sim')),
    payload_data    jsonb NOT NULL,
    created_at      timestamp NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payloads_pair_id ON trs_context_sim_payloads(pair_id);
CREATE INDEX idx_payloads_txtp ON trs_context_sim_payloads(txtp);
```

**Column Notes:**

- This table enables multi-TXTP support by storing individual TXTP payloads per pair
- For a single-TXTP simulation, each pair has 2 rows (1 context + 1 sim)
- For multi-TXTP, each pair has 2N rows (N context + N sim)
- `payload_data` — The actual generated payload conforming to the TXTP schema

### 11.3 Migration Strategy

Following the existing pattern in `rule-studio/database/init/`, create a new init SQL file:

**File:** `rule-studio/database/init/02-create-synthetic-data-tables.sql`

Contains all CREATE TABLE and CREATE INDEX statements above.

**For admin-service:** The tables are created in the `configuration` database (same as `trs_rules`, `trs_rule_flow`, etc.). The repository will use `handlePostExecuteSqlStatement(query, 'configuration')`.

**No formal migration framework** exists in the codebase. Tables are created via init scripts or `handlePostExecuteSqlStatement()` utility. Follow the same pattern.

---

## 12. Simulation Bucket Design

### 12.1 Data Model Philosophy

The Simulation Bucket is designed as an **append-only container**:

- A bucket is created once with metadata (name, rule association, TXTP configs)
- Generations are appended, never modified or deleted
- Each generation contains a batch of context-sim pairs
- Pairs within a generation are immutable
- Editing a simulation = creating a new generation within the same bucket
- Cloning a bucket = creating a new bucket with copied metadata but no generations

### 12.2 Retrieval Strategy

**List buckets:** Query `trs_simulation_buckets` with LEFT JOIN to count pairs:

```sql
SELECT b.*, COUNT(DISTINCT p.id) AS pair_count,
       STRING_AGG(DISTINCT tc.txtp, ', ') AS txtp_list
FROM trs_simulation_buckets b
LEFT JOIN trs_bucket_generations g ON g.bucket_id = b.id
LEFT JOIN trs_context_sim_pairs p ON p.generation_id = g.id
LEFT JOIN trs_bucket_txtp_configs tc ON tc.bucket_id = b.id
WHERE b.tenant_id = $1
GROUP BY b.id
ORDER BY b.created_at DESC
LIMIT $2 OFFSET $3;
```

**Get bucket detail:** Fetch bucket + TXTP configs + generations summary

**Get generation pairs:** Paginated query on `trs_context_sim_pairs` by `generation_id`

**Get pair detail:** Fetch pair + associated payloads from `trs_context_sim_payloads`

### 12.3 Scalability Considerations

- **JSONB indexing:** For large payloads, avoid GIN indexes on payload_data (too expensive). Use B-tree indexes on metadata columns instead.
- **Payload size:** Individual JSONB payloads should be kept under 1MB. The generation logic should validate total payload size.
- **Pair count:** With max 300 context + 150 sim per generation, and potentially many generations, use pagination for all list queries.
- **Connection pooling:** Batch inserts for pairs/payloads using multi-row INSERT statements.

### 12.4 Retention & Archival

- `ARCHIVED` status prevents new generations but preserves data
- Future: Add `archived_at` timestamp and background cleanup job
- Consider `TABLESPACE` for cold storage in future
- No automatic deletion — all retention is manual/admin-driven

### 12.5 Cloning Behavior

When cloning a bucket:

1. Create new bucket with `clone_source_id = original.id`
2. Copy TXTP configs to new bucket
3. Copy bucket metadata
4. Do NOT copy generations or pairs (clone starts empty)
5. Name defaults to `"Copy of {original_name}"`

---

## 13. Multi-TXTP Design Considerations

### 13.1 Grouping Strategy

TXTPs within a simulation bucket are **ordered** via `display_order` in `trs_bucket_txtp_configs`. This ordering is preserved in:

- UI rendering (tab order)
- Field configuration (per-TXTP tabs)
- Payload generation (sequential per TXTP)
- Payload storage (per-TXTP rows in `trs_context_sim_payloads`)

### 13.2 Ordering Concerns

- `display_order` is a simple integer (0, 1, 2, ...)
- UI allows drag-to-reorder (future enhancement)
- Generation always processes TXTPs in `display_order` sequence
- Payloads are stored with explicit TXTP reference, so ordering is reconstructible

### 13.3 Relationship Modeling

```
Bucket (1) ──→ (*) TxtpConfig     (which TXTPs are used)
Bucket (1) ──→ (*) Generation     (batches of generated data)
Generation (1) ──→ (*) Pair       (individual context-sim pairs)
Pair (1) ──→ (*) Payload          (per-TXTP payload within a pair)
```

A pair contains one payload per TXTP per type (context/sim). For a bucket with 2 TXTPs, each pair has 4 payload rows.

### 13.4 Schema Conflict Handling

- Each TXTP has its own independent schema — no cross-schema validation
- Field configurations are per-TXTP (stored in `txtpFieldConfigs` array)
- If a TXTP schema is updated after bucket creation, the `schema_snapshot` preserves the original
- UI clearly separates TXTP configurations with distinct tabs

### 13.5 Payload Grouping Semantics

- Context data = all TXTP payloads combined for the "context" role
- Sim data = all TXTP payloads combined for the "sim" role
- The `context_data` / `sim_data` JSONB in `trs_context_sim_pairs` contains the aggregated view
- The `trs_context_sim_payloads` table provides the per-TXTP breakdown
- This dual storage enables both quick retrieval (aggregated) and detailed inspection (per-TXTP)

### 13.6 Validation Sequencing

For multi-TXTP generation:

1. Validate each TXTP's field config independently against its schema
2. Generate payloads per TXTP independently
3. Validate each generated payload against its respective schema
4. Aggregate into context_data / sim_data
5. Mark pair validation_status as VALID only if ALL TXTP payloads pass

### 13.7 Future Orchestration

- Multi-TXTP simulations may require specific execution ordering
- The `display_order` field provides a natural execution sequence
- Future: Add `execution_order` or `dependency` fields if cross-TXTP dependencies emerge

---

## 14. Context-Sim Pair Lifecycle

### 14.1 Creation

```
1. User configures field settings (Step 2)
2. User triggers context data generation (Step 3)
   → POST /synthetic-data/api/:id/generate/context
   → Returns generated payloads (NOT persisted yet)
3. User triggers sim data generation (Step 4)
   → POST /synthetic-data/api/:id/generate/sim
   → Returns generated payloads (NOT persisted yet)
4. User previews first pair (Step 5)
5. User saves generation (Step 6)
   → POST /synthetic-data/api/:id/generation/save
   → Creates generation record
   → Creates N context-sim pair records
   → Creates per-TXTP payload records
   → Updates bucket status to GENERATED
   → Updates bucket pair count
```

### 14.2 Pairing Guarantees

- Context and sim data must be provided together in `saveGeneration`
- The number of context payloads must match the number of sim payloads
- If counts differ, the API rejects with `400 Bad Request`
- Each pair[i] = { contextData[i], simData[i] }
- Pairs are created in a single SQL transaction

### 14.3 Transactional Guarantees

The `handleSaveGeneration` function wraps all inserts in a transaction:

```typescript
// Pseudo-code for save generation
BEGIN TRANSACTION;
  INSERT INTO trs_bucket_generations (...) RETURNING id;
  FOR EACH pair IN zip(contextData, simData):
    INSERT INTO trs_context_sim_pairs (...) RETURNING id;
    FOR EACH txtp IN txtpConfigs:
      INSERT INTO trs_context_sim_payloads (...);
  UPDATE trs_simulation_buckets SET status = 'GENERATED', updated_at = NOW() WHERE id = bucketId;
COMMIT;
```

Note: The admin-service uses `handlePostExecuteSqlStatement()` which executes individual queries. For transactional guarantees, use the raw `databaseManager` connection to execute a BEGIN/COMMIT block. This is a deviation from the typical single-query pattern but is necessary for data integrity.

**Tradeoff:** This adds complexity but prevents orphaned pairs or partial generations.

**Alternative (if transactions are too complex):** Use a `generation_status` column on `trs_bucket_generations` with values `PENDING`, `COMPLETE`, `FAILED`. Write pairs in batches, mark complete only when all pairs are written. Query only `COMPLETE` generations.

### 14.4 Immutability

- Once a pair is created, it is never updated
- Context-sim pairs have no `updated_at` column (intentional)
- Generations have no update endpoints
- "Editing" means creating a new generation (append-only)

---

## 15. Edit Simulation Append-Only Strategy

### 15.1 Edit Flow

When user clicks "Edit" on an existing simulation bucket:

1. Navigate to `/synthetic-data/edit/:id`
2. Load existing bucket metadata + TXTP configs
3. **Skip Step 1** (rule selection) — already configured
4. Show Step 2 (field configuration) pre-populated with last generation's config
5. User adjusts field configuration
6. Generate new context + sim data (Steps 3-4)
7. Preview (Step 5)
8. Save as new generation (Step 6) — appended to existing bucket

### 15.2 What is Preserved

- All previous generations and their pairs
- Bucket metadata (name, description, rule association, TXTP configs)
- Clone lineage
- All audit history

### 15.3 What Changes

- New generation record added with incremented `generation_number`
- Bucket `pair_count` increases
- Bucket `updated_at` updates
- If bucket was `DRAFT`, status changes to `GENERATED`

### 15.4 Versioning Behavior

Each generation acts as a version. The `generation_number` is the version identifier:

- Generation 1: Initial creation
- Generation 2: First edit (appended)
- Generation 3: Second edit (appended)

Users can view any generation's pairs independently via the generations list.

### 15.5 Lineage Tracking

- `trs_bucket_generations.created_by` tracks who created each generation
- `trs_bucket_generations.created_at` tracks when
- `trs_bucket_generations.context_field_configs` / `sim_field_configs` capture exact configs used
- `trs_simulation_buckets.clone_source_id` tracks bucket cloning lineage

### 15.6 UI Flow Differences: Create vs Edit

| Aspect | Create | Edit |
|--------|--------|------|
| Step 1 (Rule Selection) | Required | Skipped (pre-populated) |
| Step 2 (Field Config) | Empty | Pre-populated from last generation |
| Step 3-4 (Generate) | Same | Same |
| Step 5-6 (Save) | Creates bucket + generation | Appends generation to existing bucket |
| TXTP configs | Configurable | Locked (from bucket creation) |
| Name/Description | Editable | Editable via separate update |

### 15.7 Concurrency Considerations

- Two users editing the same bucket simultaneously could create conflicting generation_numbers
- Mitigation: Use `SELECT MAX(generation_number) FROM trs_bucket_generations WHERE bucket_id = $1 FOR UPDATE` before inserting
- The `UNIQUE(bucket_id, generation_number)` constraint prevents duplicates at DB level
- If a conflict occurs, retry with incremented number (rare edge case)

---

## 16. Validation Strategy

### 16.1 Input Validation Layers

| Layer | Library | What it validates |
|-------|---------|-------------------|
| Frontend form | Yup + React Hook Form | Field presence, string lengths, count ranges |
| RS Backend DTO | class-validator + ValidationPipe | Request structure, types, constraints |
| Admin Service schema | TypeBox + AJV | Request structure, field constraints |
| Generation validation | AJV | Generated payloads against TXTP JSON Schema |

### 16.2 Field Config Validation

Before generation:

- Each field path must exist in the TXTP schema
- `range` strategy requires `rangeMin < rangeMax`
- `range` strategy only valid for numeric schema types
- `static` strategy value must match schema type
- `generated` strategy generator type must be compatible with schema type

### 16.3 Generated Payload Validation

After generation, each payload is validated against its TXTP schema:

```typescript
const ajv = new Ajv({ allErrors: true });
addFormats(ajv);
const validate = ajv.compile(txtpSchema);

for (let i = 0; i < payloads.length; i++) {
  if (!validate(payloads[i])) {
    return {
      success: false,
      validation_errors: validate.errors.map(e => `Payload[${i}]: ${e.instancePath} ${e.message}`)
    };
  }
}
```

### 16.4 Count Validation

- Context data: min 1, max 300 (enforced at DTO level and DB constraint)
- Sim data: min 1, max 150
- Maximum configurable later via environment variable: `SYNTHETIC_DATA_MAX_CONTEXT_COUNT`, `SYNTHETIC_DATA_MAX_SIM_COUNT`

### 16.5 Payload Size Validation

Before persistence:

```typescript
const MAX_PAYLOAD_SIZE_BYTES = 1_048_576; // 1MB per payload
const serialized = JSON.stringify(payload);
if (Buffer.byteLength(serialized, 'utf8') > MAX_PAYLOAD_SIZE_BYTES) {
  throw new HttpException('Payload exceeds maximum size of 1MB', HttpStatus.BAD_REQUEST);
}
```

Total generation size check:

```typescript
const MAX_GENERATION_SIZE_BYTES = 50_000_000; // 50MB total per generation
const totalSize = payloads.reduce((sum, p) => sum + Buffer.byteLength(JSON.stringify(p)), 0);
if (totalSize > MAX_GENERATION_SIZE_BYTES) {
  throw new HttpException('Total generation size exceeds 50MB limit', HttpStatus.BAD_REQUEST);
}
```

---

## 17. Security Considerations

### 17.1 RBAC

| Action | Required Claims |
|--------|----------------|
| List buckets | `trs_editor`, `trs_data_engineer_editor`, `trs_approver`, `trs_data_engineer_approver` |
| View bucket/pairs | Same as list |
| Create bucket | `trs_editor`, `trs_data_engineer_editor` |
| Edit bucket | `trs_editor`, `trs_data_engineer_editor` |
| Clone bucket | `trs_editor`, `trs_data_engineer_editor` |
| Generate data | `trs_editor`, `trs_data_engineer_editor` |
| Save generation | `trs_editor`, `trs_data_engineer_editor` |

Following existing RBAC conventions:

- RS Backend: `@RequireAnyClaims()` decorator on controller methods
- Admin Service: `routePrivilege` mapping in `router.ts`

### 17.2 Tenant Isolation

All queries include `tenant_id` filter (consistent with existing pattern):

```sql
WHERE tenant_id = $1
```

### 17.3 Payload Abuse Prevention

- Max payload size per individual payload: 1MB
- Max total generation size: 50MB
- Max context count: 300
- Max sim count: 150
- Field configs validated against schema before generation
- No arbitrary code execution in generators
- Generator types are whitelisted: `uuid`, `name`, `date`, `datetime_recent`, `integer`, `float`, `boolean`, `enum`, `string`

### 17.4 Oversized Payload Prevention

- Fastify body limit: Already configured globally
- NestJS ValidationPipe `whitelist: true` strips unknown properties
- AJV `removeAdditional: 'all'` removes extra fields
- Size checks at admin-service before DB writes

### 17.5 Malformed Schema Protection

- Schema snapshots are validated when fetched from `tcs_config`
- If a schema cannot be compiled by AJV, generation fails with a clear error
- No user-supplied schemas — only TCS-managed schemas are used

### 17.6 Rate Limiting / Throttling

- Generation endpoints should implement rate limiting (future enhancement)
- For now: the existing BullMQ concurrency limit (2 workers) provides natural throttling
- Consider adding a per-user generation limit in the config: `MAX_GENERATIONS_PER_HOUR = 10`

---

## 18. Performance Considerations

### 18.1 Payload Size Controls

| Limit | Value | Configurable |
|-------|-------|-------------|
| Max context count | 300 | Yes (env var) |
| Max sim count | 150 | Yes (env var) |
| Max payload size | 1MB | Yes (env var) |
| Max generation size | 50MB | Yes (env var) |
| Max TXTP configs per bucket | 10 | Yes (env var) |

### 18.2 Batching Strategy

For large generations (e.g., 300 context items):

- Generate payloads in memory (streaming not needed at 300 items)
- Insert pairs in batches of 50 using multi-row INSERT:

```sql
INSERT INTO trs_context_sim_pairs (generation_id, pair_index, context_data, sim_data, validation_status, created_at)
VALUES ($1, $2, $3::jsonb, $4::jsonb, $5, NOW()),
       ($6, $7, $8::jsonb, $9::jsonb, $10, NOW()),
       ...
```

- Batch payload inserts similarly

### 18.3 Pagination

All list endpoints use offset/limit pagination (consistent with existing pattern):

- Default limit: 10
- Maximum limit: 100
- Default sort: `created_at DESC`

### 18.4 Lazy Loading

- Bucket list shows summary data only (no payloads)
- Pair list shows metadata only
- Full payload loaded only when viewing individual pair detail
- Generation list shows counts only (no payload data)

### 18.5 Generation Performance

For 300 context items with a typical ISO 20022 schema (~50 fields):

- Schema compilation: ~5ms (cached per TXTP)
- Payload generation: ~1ms per payload × 300 = ~300ms
- Validation: ~0.5ms per payload × 300 = ~150ms
- Total generation: <1s (synchronous, no BullMQ needed)

For larger payloads or more complex schemas, generation stays synchronous unless profiling shows > 5s latency, at which point BullMQ can be introduced.

### 18.6 DB Growth Concerns

Estimated storage per generation (300 context + 150 sim, single TXTP):

- `trs_context_sim_pairs`: 300 rows × ~2KB avg = ~600KB
- `trs_context_sim_payloads`: 900 rows × ~1KB avg = ~900KB
- `trs_bucket_generations`: 1 row × ~5KB = ~5KB
- Total per generation: ~1.5MB

With 100 active buckets, 5 generations each: ~750MB — well within PostgreSQL capacity.

### 18.7 Future Archival Strategy

- Add `archived_at` column to buckets
- Background job to move archived bucket data to cold storage
- Consider PostgreSQL table partitioning by `created_at` year if data exceeds 10GB
- Archive endpoint: `PATCH /synthetic-data/api/:id/archive`

---

## 19. Scalability Considerations

### 19.1 Horizontal Scaling

- RS Backend: Stateless — scale horizontally behind load balancer
- Admin Service: Stateless — scale horizontally
- DB: Single PostgreSQL instance (existing pattern), scale vertically first
- Redis: Used for BullMQ only, not for synthetic data (no new Redis load)

### 19.2 Vertical Scaling Triggers

- If pair count per bucket exceeds 10,000 → consider pagination at pair level (already planned)
- If total synthetic data exceeds 100GB → consider archival/partitioning
- If generation takes > 10s → consider BullMQ async generation

### 19.3 Future: Background Generation

If needed, introduce a BullMQ queue for generation:

```typescript
// Add to queues/ following existing SimulationProcessor pattern
@Processor('synthetic-data-generation', { concurrency: 2, lockDuration: 15000 })
export class SyntheticDataProcessor extends WorkerHost {
  async process(job: Job<SyntheticDataJobPayload>): Promise<void> {
    // Generate data, emit progress via WebSocket
  }
}
```

This is NOT needed for the initial implementation but the architecture supports it.

---

## 20. Auditability Strategy

### 20.1 Audit Points

| Action | Audit Method |
|--------|-------------|
| Create bucket | `@Audit()` decorator + `trs_simulation_logs` entry |
| Edit bucket metadata | `@Audit()` + simulation log |
| Generate data | `@Audit()` |
| Save generation | `@Audit()` + simulation log with generation details |
| Clone bucket | `@Audit()` + simulation log with lineage |
| Archive bucket | `@Audit()` + simulation log |

### 20.2 Audit Log Structure

Reuse existing `trs_simulation_logs` table:

```typescript
await insertSimulationLogs(token, {
  rule_id: bucket.rule_id ?? 'synthetic-data',
  old_data: {},
  new_data: { bucket_id: 1, generation_number: 3, context_count: 50, sim_count: 25 },
  description: 'New generation added to simulation bucket "Fraud Test Set A"',
  category: 'synthetic_data_generation',
  created_by: user.userId,
  created_by_email: user.actorEmail,
});
```

### 20.3 Audit Categories

New categories for `trs_simulation_logs.category`:

- `synthetic_data_bucket_create`
- `synthetic_data_bucket_edit`
- `synthetic_data_bucket_clone`
- `synthetic_data_bucket_archive`
- `synthetic_data_generation`

### 20.4 What is Recorded

- **Who:** `created_by`, `created_by_email` from JWT
- **When:** `created_at` timestamp
- **What:** `description` (human-readable) + `new_data` (structured)
- **Where:** `category` for filtering
- **Lineage:** `clone_source_id`, `generation_number`

---

## 21. Future Extensibility

### 21.1 Planned Future Capabilities

| Capability | How Architecture Supports It |
|-----------|------------------------------|
| Run simulation against bucket | Bucket pairs can be fed into existing DEMS pipeline via `send-to-dems` module |
| AI-assisted generation | `generation_metadata.strategy` field, new generator types |
| Analytics on generated data | Aggregate queries on `trs_context_sim_pairs` |
| Replay generation | `context_field_configs` + `sim_field_configs` stored per generation |
| Export/import buckets | Serialize bucket + generations + pairs to JSON |
| Share buckets across tenants | `metadata.shared_with` JSONB field |
| Template buckets | `metadata.is_template` flag |
| Generation scheduling | BullMQ cron jobs for periodic generation |
| Custom generator plugins | `generatorType` + `generatorOptions` extensible schema |

### 21.2 Extension Points

- `metadata` JSONB on `trs_simulation_buckets` — add any bucket-level metadata
- `generation_metadata` JSONB on `trs_bucket_generations` — add generation-level metadata
- `generatorOptions` in field configs — pass arbitrary options to generators
- `trs_context_sim_payloads` — add new payload types beyond 'context'/'sim'
- `FieldStrategy` enum — add new strategies (e.g., 'ml_generated', 'distribution')

---

## 22. Migration Plan

### 22.1 Database Migration

**Step 1:** Create SQL migration script with all 5 tables

**Step 2:** Execute via admin-service `handlePostExecuteSqlStatement()` or add to `database/init/` scripts

**Step 3:** Verify tables exist in `configuration` database

No data migration needed — this is a greenfield feature.

### 22.2 Backward Compatibility

- No existing tables are modified
- No existing APIs are changed
- No existing frontend routes are affected
- The feature is purely additive

---

## 23. Risks & Unknowns

### 23.1 Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Large JSONB payloads degrade DB performance | Medium | Size limits, batch inserts, pagination |
| Complex recursive schema rendering in UI | High | Depth limit (10), fallback to raw JSON editor |
| Multi-TXTP UX complexity | Medium | Clear tab-based separation, progressive disclosure |
| Transaction support in admin-service | Medium | Use `generation_status` column as fallback |
| AJV schema compilation for complex schemas | Low | Cache compiled validators |
| Concurrent edit conflicts | Low | DB unique constraint + retry logic |

### 23.2 Unknowns

| Unknown | Impact | Resolution |
|---------|--------|-----------|
| Exact generator library to use | Medium | Research: Consider `@faker-js/faker` for realistic data generation, or build minimal generators in-house |
| Whether admin-service `databaseManager` supports transactions | High | Investigate `databaseManager` API — if no transaction support, use `generation_status` pattern |
| Maximum practical schema complexity | Low | Test with real production schemas |
| Performance characteristics of 300-item generation | Low | Benchmark during implementation |

---

## 24. Open Questions

1. **Generator library:** Should we use `@faker-js/faker` for realistic data generation (names, addresses, dates) or build minimal generators? Faker adds a dependency but provides high-quality generators.

2. **Schema snapshot frequency:** Should TXTP schemas be snapshotted at bucket creation only, or refreshed per generation? Current design snapshots at creation for reproducibility.

3. **Pair matching strategy:** When context count ≠ sim count, how should pairs be formed? Current design requires counts to match. Alternative: allow different counts and pair by index with remaining unpaired.

4. **Future simulation execution:** How exactly will synthetic data pairs be fed into the existing DEMS simulation pipeline? This affects payload format decisions.

5. **Bucket sharing:** Should buckets be shareable across users within the same tenant? Current design: visible to all authorized users in the tenant.

6. **Archival policy:** Should there be an automatic archival policy (e.g., archive after 90 days of inactivity)?

7. **Generation limits:** Are 300 context / 150 sim sufficient, or should these be higher? These are configurable via env vars.

---

## 25. Recommended Implementation Order

### Phase 1: Foundation (Backend + DB)

1. Create database tables (migration SQL)
2. Implement admin-service interfaces
3. Implement admin-service repository (CRUD operations)
4. Implement admin-service logic service (bucket CRUD, no generation yet)
5. Implement admin-service route handlers + schema validation
6. Implement RS backend module (controller, service, DTOs)
7. Add admin-service client methods
8. Add constants + RBAC permission matrix entries

### Phase 2: Generation Engine

8. Implement synthetic data generation logic in admin-service
9. Implement field config validation
10. Implement AJV schema validation for generated payloads
11. Implement save generation with transactional guarantees
12. Add payload size validation and limits

### Phase 3: Frontend — List & Navigation

13. Create RTK Query API slice
14. Add routes to router
15. Add sidebar menu item
16. Implement list page (table, filters, pagination)
17. Implement view simulation page

### Phase 4: Frontend — Wizard

18. Implement Stepper component
19. Implement Step 1 (Rule Selection + TXTP config)
20. Implement FieldConfigurator component (recursive schema renderer)
21. Implement Step 2 (Field Configuration)
22. Implement Step 3 (Context Generation)
23. Implement Step 4 (Sim Generation)
24. Implement Step 5 (Preview)
25. Implement Step 6 (Summary & Save)

### Phase 5: Edit, Clone, Polish

26. Implement edit flow (append generation)
27. Implement clone flow
28. Implement Yup validation schemas
29. Add audit logging for all actions
30. Error handling polish
31. Loading states and edge cases

---

## 26. Estimated Complexity by Component

| Component | Complexity | Story Points (est.) | Notes |
|-----------|-----------|---------------------|-------|
| DB tables + migration | Low | 2 | Straightforward SQL |
| Admin service repository | Medium | 5 | Multiple tables, batch inserts |
| Admin service logic service | High | 8 | Generation engine, validation |
| Admin service handlers + schemas | Medium | 3 | Standard Fastify pattern |
| RS Backend module | Medium | 5 | Standard NestJS module |
| Admin service client additions | Low | 2 | HTTP method additions |
| RTK Query API slice | Low | 2 | Standard pattern |
| List page | Low | 3 | Follows Home page pattern exactly |
| Wizard shell + Stepper | Medium | 3 | MUI Stepper + routing |
| Step 1 (Rule Selection) | Medium | 3 | Reuses existing config APIs |
| FieldConfigurator component | **Very High** | 13 | Recursive schema rendering, most complex UI |
| Step 2 (Field Config) | Medium | 5 | Integrates FieldConfigurator |
| Steps 3-4 (Generation) | Medium | 5 | API calls + preview |
| Step 5 (Preview) | Low | 2 | JSON display |
| Step 6 (Summary) | Low | 2 | Confirmation + save |
| Edit flow | Medium | 5 | Pre-population, append logic |
| Clone flow | Low | 3 | Copy metadata |
| RBAC additions | Low | 1 | Permission matrix update |
| Audit logging | Low | 2 | Follows existing pattern |
| **Total** | | **~72** | |

---

## 27. Suggested Test Strategy

### 27.1 Admin Service Unit Tests

**File:** `__tests__/unit/synthetic-data.logic.service.test.ts`

| Test | Coverage |
|------|----------|
| `handleCreateBucket` — creates bucket with valid input | Happy path |
| `handleCreateBucket` — rejects missing name | Validation |
| `handleCreateBucket` — rejects empty txtpConfigs | Validation |
| `handleGenerateSyntheticData` — generates valid payloads | Generation |
| `handleGenerateSyntheticData` — validates against schema | Validation |
| `handleGenerateSyntheticData` — rejects count > max | Limits |
| `handleGenerateSyntheticData` — handles range strategy | Generation |
| `handleGenerateSyntheticData` — handles multi-TXTP | Multi-TXTP |
| `handleSaveGeneration` — saves with correct pair count | Persistence |
| `handleSaveGeneration` — rejects mismatched counts | Validation |
| `handleCloneBucket` — creates clone with lineage | Cloning |
| `handleGetAllBuckets` — paginates correctly | Pagination |
| `handleGetAllBuckets` — filters by status | Filtering |
| `handleGetAllBuckets` — filters by name ILIKE | Search |

### 27.2 RS Backend Unit Tests

**File:** `test/synthetic-data.service.spec.ts`

| Test | Coverage |
|------|----------|
| RBAC enforcement for each endpoint | Security |
| Service delegates to admin client correctly | Integration |
| DTO validation rejects invalid input | Validation |
| Controller returns correct status codes | API contract |

### 27.3 Frontend Tests

**File:** `__tests__/pages/SyntheticData/`

| Test | Coverage |
|------|----------|
| List page renders table with data | Rendering |
| List page handles empty state | Edge case |
| Filters update query params | Interaction |
| Create button hidden for non-editors | RBAC |
| Wizard steps progress correctly | Navigation |
| FieldConfigurator renders schema fields | Rendering |
| FieldConfigurator handles nested objects | Recursive |
| Generation preview shows first pair | Preview |

---

## 28. Suggested Observability/Logging

### 28.1 Logging Points

| Event | Level | Logger |
|-------|-------|--------|
| Bucket created | INFO | `loggerService.log` |
| Generation started | INFO | `loggerService.log` |
| Generation completed | INFO | `loggerService.log` |
| Generation failed | ERROR | `loggerService.error` |
| Schema validation failed | WARN | `loggerService.warn` |
| Payload size limit exceeded | WARN | `loggerService.warn` |
| Bucket cloned | INFO | `loggerService.log` |
| Pair count mismatch | ERROR | `loggerService.error` |

### 28.2 Structured Log Format

Follow existing pattern:

```typescript
loggerService.log(`Start - handleGenerateSyntheticData: bucketId=${bucketId}, type=${type}, count=${count}`);
// ... processing ...
loggerService.log(`End - handleGenerateSyntheticData: bucketId=${bucketId}, generated=${payloads.length}`);
```

### 28.3 Metrics (Future)

- Generation count per hour
- Average generation time
- Average payload size
- Bucket count per tenant
- Error rate per endpoint

---

## 29. Suggested Config Strategy

### 29.1 Environment Variables

Add to admin-service `.env`:

```env
SYNTHETIC_DATA_MAX_CONTEXT_COUNT=300
SYNTHETIC_DATA_MAX_SIM_COUNT=150
SYNTHETIC_DATA_MAX_PAYLOAD_SIZE_BYTES=1048576
SYNTHETIC_DATA_MAX_GENERATION_SIZE_BYTES=52428800
SYNTHETIC_DATA_MAX_TXTP_PER_BUCKET=10
```

Add to RS backend `.env`:

```env
# No new env vars needed — all limits enforced at admin-service level
```

### 29.2 Config Loading

Admin-service: Add to `IConfig` interface in `config.ts`:

```typescript
SYNTHETIC_DATA_MAX_CONTEXT_COUNT: number;    // default: 300
SYNTHETIC_DATA_MAX_SIM_COUNT: number;        // default: 150
SYNTHETIC_DATA_MAX_PAYLOAD_SIZE_BYTES: number; // default: 1048576
SYNTHETIC_DATA_MAX_GENERATION_SIZE_BYTES: number; // default: 52428800
SYNTHETIC_DATA_MAX_TXTP_PER_BUCKET: number;  // default: 10
```

---

## 30. Suggested Rollout Strategy

### 30.1 Phase 1 — Backend Foundation

- Deploy DB tables to staging
- Deploy admin-service changes
- Deploy RS backend changes
- Verify API contracts with Postman/curl
- No frontend impact — feature is invisible

### 30.2 Phase 2 — Frontend MVP

- Deploy list page + basic create wizard
- Single-TXTP only in initial release
- No edit/clone yet
- Feature flag: `SYNTHETIC_DATA_ENABLED=true` (default: false in production)

### 30.3 Phase 3 — Full Feature

- Deploy edit + clone flows
- Enable multi-TXTP support
- Full field configurator
- Remove feature flag

### 30.4 Feature Flag Implementation

Frontend: Check env variable `VITE_SYNTHETIC_DATA_ENABLED`:

```typescript
// In routes/index.tsx
if (import.meta.env.VITE_SYNTHETIC_DATA_ENABLED === 'true') {
  routes.push(
    { path: '/synthetic-data', element: <SyntheticDataList />, private: true, layout: true, roleGroup: 'trs' },
    // ...
  );
}
```

Sidebar: Conditionally render menu item based on same flag.

Backend: No feature flag needed — endpoints exist but are unused until frontend calls them.
