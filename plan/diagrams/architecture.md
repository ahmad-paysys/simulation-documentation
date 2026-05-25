# Simulation Studio — High-Level Architecture

Logical deployment view. `connection-studio/` is shown only because it shares the `admin-service` and the same auth — **no new code lands there**.

```mermaid
flowchart TB
    subgraph BROWSER["Browser"]
        FE["rule-studio/frontend<br/>pages/SimulationStudio/*<br/>RTK: simulationStudioApi<br/>VITE_SIMULATION_STUDIO_API_URL"]
    end

    subgraph KC["Identity"]
        IDP["Keycloak<br/>(Tazama claims:<br/>editor, approver)"]
    end

    subgraph RS["rule-studio/backend (NestJS)"]
        SSM["SimulationStudioModule<br/>src/services/simulation-studio/"]
        SSC["SimulationStudioController<br/>/api/v1/simulation-studio/*"]
        SVC["SimulationStudioService"]
        REG["RegistryService<br/>(Docker Hub JWT + tag cache)"]
        CTX["ContextGenerationService<br/>(AJV cache per txtp:version)"]
        ORC["OrchestratorService<br/>+ SingleRuleEnvBuilder<br/>+ OdsInitService<br/>+ TransactionLoopService<br/>+ EnvRegistryService"]
        ASC["AdminServiceClient<br/>(extended)"]
        LEGACY["(existing modules:<br/>simulation, rules, rerun-simulation<br/>parse-extract, masking, ...)<br/>UNCHANGED"]
    end

    subgraph ADMIN["admin-service (Fastify)"]
        AR["router.ts"]
        AL["simulation-studio.logic.service.ts<br/>(NEW)"]
        ATC["tcs-config.logic.service.ts<br/>(existing — used as-is)"]
        REPO["repositories/simulation/*<br/>(NEW)"]
        TCSREPO["repositories/configuration/tcs.config.repository.ts<br/>(existing)"]
    end

    subgraph DB["PostgreSQL"]
        SIMDB[("simulation_studio<br/>(new database)<br/>see ERD")]
        CFGDB[("configuration<br/>tcs_config, trs_rule, ...<br/>(existing)")]
    end

    subgraph DOCKER["Docker Engine (dev: socket | prod: TCP+TLS)"]
        NET["sim-run-<runId> network"]
        PG[(Postgres ODS<br/>ephemeral)]
        NATS["NATS"]
        NUTIL["nats-utilities"]
        RP["rule-processor<br/>(pinned by SHA256 digest)"]
    end

    subgraph HUB["Docker Hub"]
        REGI["registry: rule-* images"]
    end

    FE -- "Bearer JWT" --> IDP
    FE -- "HTTPS<br/>/api/v1/simulation-studio/*" --> SSC

    SSC --> SVC
    SVC --> CTX
    SVC --> REG
    SVC --> ORC
    SVC --> ASC
    CTX --> ASC
    ORC --> ASC

    REG -- "list repos / tags<br/>verify digest" --> REGI
    ORC -- "Dockerode API" --> NET
    NET --> PG
    NET --> NATS
    NET --> NUTIL
    NET --> RP
    RP -- "pulled by digest" --> REGI

    ORC -- "submit sim pair" --> NUTIL
    NUTIL -- "publish" --> NATS
    NATS -- "deliver" --> RP
    RP -- "read history / enrichment" --> PG

    ASC -- "HTTPS + JWT" --> AR
    AR --> AL
    AR --> ATC
    AL --> REPO
    ATC --> TCSREPO
    REPO --> SIMDB
    TCSREPO --> CFGDB

    classDef new fill:#cdeaff,stroke:#0b62a4,color:#062642;
    classDef ext fill:#fff3c4,stroke:#a07000,color:#3a2a00;
    classDef untouched fill:#eee,stroke:#888,color:#333;
    class FE,SSM,SSC,SVC,REG,CTX,ORC,AL,REPO,SIMDB new;
    class ASC,AR,ATC,TCSREPO,CFGDB,IDP ext;
    class LEGACY untouched;
```

## What's new vs. what's reused

| Layer | NEW (this initiative) | REUSED (existing) | UNTOUCHED |
|---|---|---|---|
| Frontend | `pages/SimulationStudio/*`, `simulationStudioApi` slice, `<Stepper />`, `<FieldConfigurator />` | `StatusCard`, `Table`, `TableActions`, `DropDown`, `Input`, `BoxWrapper`, `JsonFormatter`, `AccordianSummary`, `useFilters` | All legacy `pages/Simulation*`, `simulationApi` |
| rule-studio backend | `services/simulation-studio/*` module (controller, service, registry, orchestrator, context-gen, dto) | `TazamaAuthGuard`, `RequireAnyClaims`, `AdminServiceClient` (extended) | `services/simulation/`, `services/rerun-simulation/`, etc. |
| admin-service | `services/simulation-studio.logic.service.ts`, `repositories/simulation/*` | `tcs-config.logic.service.ts`, `enrichment-utils.validateTableName`, repo pattern, `PaginatedResult<T>` | All existing handlers |
| Database | `simulation_studio` DB (per migration, post §3.2 edits) | `configuration` DB (`tcs_config`) — read-only via existing admin handlers | All existing tables |
| Runtime | Dockerode-driven `sim-run-<id>` networks + 4-container envs | Docker Hub auth pattern | — |

## Trust boundaries

1. **Browser → rule-studio/backend.** JWT bearer; `TazamaAuthGuard` validates and extracts `AuthenticatedUser` (`tenantId`, `userId`).
2. **rule-studio/backend → admin-service.** Same JWT forwarded through `AdminServiceClient`. All tenant filtering enforced inside admin-service repositories.
3. **rule-studio/backend → Docker Engine.** Out-of-band (socket or mTLS). Each run gets a network namespace; nothing crosses runs.
4. **rule-studio/backend → Docker Hub.** Service-account JWT (50-min TTL cache).
