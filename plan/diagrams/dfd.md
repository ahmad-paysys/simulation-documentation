# Simulation Studio — Data Flow Diagram

Two views: (1) wizard authoring data flow, (2) run execution data flow. Both render natively in GitHub via Mermaid.

---

## 1. Wizard authoring — DRAFT to saved Iteration

```mermaid
flowchart LR
    USR(["User<br/>(editor / approver)"])

    subgraph WIZ["Wizard (rule-studio/frontend)"]
        S1["Screen 1<br/>Rule + TxTp"]
        S2["Screen 2<br/>Context Data"]
        S3["Screen 3<br/>Trigger Data"]
        S4["Screen 4<br/>Enrichment"]
        S5["Screen 5<br/>Summary + Save"]
    end

    subgraph RSB["rule-studio/backend  /api/v1/simulation-studio"]
        EP_CREATE["POST /suites"]
        EP_DRAFT["PUT /suites/:id/draft"]
        EP_GEN["POST /suites/:id/generate/context"]
        EP_RUN["POST /suites/:id/run"]
        EP_TXTP["GET /txtp-types<br/>GET /txtp-types/:t/:v/schema<br/>GET /txtp-types/:t/:v/sample"]
        EP_REG["GET /registry/repos<br/>GET /registry/repos/:r/tags"]
        CTXSVC["ContextGenerationService<br/>(AJV cache)"]
        REGSVC["RegistryService"]
    end

    subgraph ADM["admin-service"]
        H_SUITE["simulation-studio.logic<br/>(NEW)"]
        H_TCS["tcs-config.logic<br/>(existing)"]
    end

    DB_SIM[("simulation_studio<br/>trs_simulation_suites<br/>(metadata.wizardDraft<br/>+ wizard_progress)")]
    DB_CFG[("configuration<br/>tcs_config")]
    HUB[("Docker Hub")]

    USR --> S1 --> S2 --> S3 --> S4 --> S5

    S1 -- "POST CreateSuiteDto" --> EP_CREATE
    S1 -- "fetch repos+tags" --> EP_REG
    S1 -- "fetch txtp types" --> EP_TXTP

    S2 -- "PUT draft (screen=2)" --> EP_DRAFT
    S2 -- "fetch schema + sample" --> EP_TXTP
    S2 -- "preview & full generate" --> EP_GEN

    S3 -- "PUT draft (screen=3)" --> EP_DRAFT
    S3 -- "sample (rehydrate)" --> EP_TXTP
    S4 -- "PUT draft (screen=4)" --> EP_DRAFT
    S5 -- "PUT draft (screen=5) | Save as Draft" --> EP_DRAFT
    S5 -- "Save Iteration" --> EP_RUN

    EP_CREATE  --> H_SUITE
    EP_DRAFT   --> H_SUITE
    EP_GEN     --> CTXSVC --> H_TCS
    EP_TXTP    --> H_TCS
    EP_REG     --> REGSVC --> HUB
    H_SUITE -- "INSERT / UPDATE suite<br/>jsonb_set wizardDraft" --> DB_SIM
    H_TCS  -- "SELECT schema/payload/types<br/>WHERE status IN (APPROVED,EXPORTED)" --> DB_CFG

    classDef wiz fill:#e8f4ff,stroke:#0b62a4;
    classDef ep  fill:#fff3c4,stroke:#a07000;
    classDef svc fill:#e6ffe6,stroke:#2a7a2a;
    class S1,S2,S3,S4,S5 wiz;
    class EP_CREATE,EP_DRAFT,EP_GEN,EP_RUN,EP_TXTP,EP_REG ep;
    class CTXSVC,REGSVC,H_SUITE,H_TCS svc;
```

**Key data items in flight:**
- `wizardDraft.screen1..screen5` accumulates in `trs_simulation_suites.metadata` (JSONB). No child tables are written until **Save Iteration**.
- `wizard_progress` is the resume cursor: `{ "screen1": true, ... }`.
- Generated context payloads live in client state during the wizard; persisted to `trs_suite_context_generated_messages` only on `POST /run`.

---

## 2. Run execution — POST /run → results

```mermaid
flowchart TB
    EP_RUN["POST /suites/:id/run"]
    EP_STAT["GET /suites/:id/runs/:runId/status"]
    EP_RES["GET /suites/:id/runs/:runId/results"]

    subgraph RSB["rule-studio/backend"]
        SVC["SimulationStudioService"]
        REGSVC["RegistryService<br/>verifyImage()"]
        ORC["OrchestratorService"]
        BUILDER["SingleRuleEnvBuilder"]
        ODS["OdsInitService"]
        LOOP["TransactionLoopService"]
        ENVREG["EnvRegistryService<br/>(concurrency pool)"]
        ASC["AdminServiceClient"]
    end

    subgraph ADM["admin-service"]
        H_SAVE["handleSaveIterationTransactional<br/>(advisory_xact_lock)"]
        H_RUN["run lifecycle handlers<br/>updateRunStatus<br/>appendRunResult<br/>getRunStatus / Results"]
    end

    DB_SIM[("simulation_studio")]

    subgraph DOC["Docker Engine"]
        NET["sim-run-<runId> network"]
        PGE[("ephemeral Postgres ODS")]
        NATS["NATS"]
        NUT["nats-utilities"]
        RP["rule-processor<br/>@sha256:..."]
    end

    HUB[("Docker Hub")]

    EP_RUN --> SVC
    SVC --> REGSVC --> HUB
    SVC -- "1. saveIterationTransactional<br/>(generation + run + all snapshots)" --> ASC --> H_SAVE --> DB_SIM
    H_SAVE -. "returns runId" .-> SVC
    SVC -- "2. dispatch (fire-and-forget)" --> ORC
    SVC -. "200 { runId, status: ENV_PROVISIONING }" .-> EP_RUN

    ORC --> ENVREG
    ORC --> BUILDER -- "EnvSpec from generation rows" --> ORC
    ORC -- "create network" --> NET
    ORC -- "start Postgres + NATS (parallel)" --> NET
    ORC --> ODS
    ODS -- "CREATE TABLE + INSERT<br/>context, enrichment" --> PGE
    ORC -- "start nats-utilities + rule-processor" --> NET
    ORC -- "phase / status updates" --> ASC --> H_RUN --> DB_SIM
    ORC --> LOOP

    LOOP -- "per sim pair: submit (await=true)" --> NUT
    NUT --> NATS --> RP
    RP -- "read context / enrichment" --> PGE
    RP -- "response" --> NATS --> NUT
    NUT -- "result" --> LOOP
    LOOP -- "INSERT one result row<br/>per transaction" --> ASC --> H_RUN --> DB_SIM

    ORC -- "teardown: stop containers,<br/>remove network" --> NET
    ORC -- "final status COMPLETED / FAILED" --> ASC --> H_RUN --> DB_SIM

    EP_STAT -- "poll every 2s" --> ASC -- "SELECT runs<br/>+ partialResults" --> H_RUN --> DB_SIM
    EP_RES  -- "on COMPLETED" --> ASC -- "SELECT run_results" --> H_RUN --> DB_SIM

    classDef ep  fill:#fff3c4,stroke:#a07000;
    classDef svc fill:#e6ffe6,stroke:#2a7a2a;
    classDef infra fill:#eef,stroke:#446;
    class EP_RUN,EP_STAT,EP_RES ep;
    class SVC,REGSVC,ORC,BUILDER,ODS,LOOP,ENVREG,ASC,H_SAVE,H_RUN svc;
    class NET,PGE,NATS,NUT,RP,HUB,DB_SIM infra;
```

**Key data items in flight:**
- `verifyImage()` returns a SHA256 digest pinned into `trs_simulation_runs.rule_image_digest` *before* the transaction commits — so reruns are byte-identical.
- The single admin transaction (`handleSaveIterationTransactional`) writes: generation, all context/trigger/enrichment configs + generated rows, all sim pairs, the run row, and increments suite counters. All-or-nothing — orchestrator never starts on rollback.
- The transaction loop persists results **immediately** after each nats-utilities response (T-03 — not batched). UI receives them via `partialResults` on the status endpoint when needed; current Screen 6 only displays on terminal state.
- Crash recovery (T-04) on backend startup: list Docker containers labelled `run_id=*`, cross-reference `trs_simulation_runs.status`, force any non-terminal run to `FAILED` and tear down.
