# Simulation Studio — Entity Relationship Diagram

Reflects [database-migration.sql](../database-migration.sql) **after** the §3.2 edits in [implementation_report.md](../implementation_report.md):
- `trs_suite_txtp_configs` dropped (redundant union)
- `trs_suite_context_sim_payloads` dropped (payloads inline on pairs)

```mermaid
erDiagram
    trs_simulation_suites ||--o{ trs_suite_generations : "has"
    trs_simulation_suites ||--o{ trs_simulation_runs   : "owns"
    trs_simulation_suites }o--o| trs_simulation_suites : "cloned_from"

    trs_suite_generations ||--o{ trs_suite_context_txtp_configs   : ""
    trs_suite_generations ||--o{ trs_suite_trigger_txtp_configs   : ""
    trs_suite_generations ||--o{ trs_suite_enrichment_tables      : ""
    trs_suite_generations ||--o{ trs_suite_context_sim_pairs      : ""
    trs_suite_generations ||--o{ trs_simulation_runs              : ""

    trs_suite_context_txtp_configs ||--o{ trs_suite_context_field_strategies   : ""
    trs_suite_context_txtp_configs ||--o{ trs_suite_context_generated_messages : ""

    trs_suite_trigger_txtp_configs ||--o{ trs_suite_trigger_field_overrides    : ""
    trs_suite_trigger_txtp_configs ||--o{ trs_suite_trigger_generated_messages : ""

    trs_suite_trigger_generated_messages }o--o| trs_suite_context_generated_messages : "linked_pair"

    trs_suite_enrichment_tables ||--o{ trs_suite_enrichment_field_strategies : ""
    trs_suite_enrichment_tables ||--o{ trs_suite_enrichment_generated_rows   : ""

    trs_suite_context_sim_pairs }o--|| trs_suite_context_generated_messages : "context_msg"
    trs_suite_context_sim_pairs }o--|| trs_suite_trigger_generated_messages : "trigger_msg"

    trs_simulation_runs ||--o{ trs_simulation_run_events    : ""
    trs_simulation_runs ||--o{ trs_simulation_run_results   : ""
    trs_simulation_runs ||--o{ trs_simulation_run_artifacts : ""
    trs_simulation_runs }o--o| trs_simulation_runs          : "source_run"

    trs_simulation_run_results ||--o{ trs_simulation_run_result_context_links : ""
    trs_simulation_run_result_context_links }o--|| trs_suite_context_generated_messages : ""

    trs_simulation_suites {
        bigserial id PK
        varchar   tenant_id
        varchar   name
        varchar   status
        varchar   rule_repo
        varchar   rule_name
        varchar   rule_version
        varchar   primary_txtp
        varchar   primary_txtp_version
        bigint    clone_source_suite_id FK
        int       iteration_count
        int       run_count
        jsonb     wizard_progress
        jsonb     metadata
        varchar   created_by
        timestamptz created_at
        timestamptz updated_at
    }

    trs_suite_generations {
        bigserial id PK
        bigint    suite_id FK
        int       generation_number
        varchar   status
        varchar   rule_repo
        varchar   rule_version
        int       context_count
        int       trigger_count
        int       enrichment_table_count
        jsonb     wizard_snapshot
        timestamptz created_at
    }

    trs_suite_context_txtp_configs {
        bigserial id PK
        bigint    generation_id FK
        varchar   txtp
        varchar   txtp_version
        int       display_order
        int       message_count
        jsonb     schema_snapshot
        jsonb     sample_payload_snapshot
        bigint    faker_seed
        jsonb     generator_profile
    }

    trs_suite_context_field_strategies {
        bigserial id PK
        bigint    context_txtp_config_id FK
        text      field_path
        varchar   strategy_code
        jsonb     static_value
        numeric   range_min
        numeric   range_max
        varchar   generator_type
    }

    trs_suite_context_generated_messages {
        bigserial id PK
        bigint    context_txtp_config_id FK
        int       message_order
        jsonb     payload_json
        char      payload_hash
        varchar   validation_status
    }

    trs_suite_trigger_txtp_configs {
        bigserial id PK
        bigint    generation_id FK
        varchar   txtp
        varchar   txtp_version
        int       display_order
        int       message_count
        boolean   link_to_context_pairs
        jsonb     payload_template_json
        numeric   expected_independent_variable
        varchar   expected_result_band
    }

    trs_suite_trigger_field_overrides {
        bigserial id PK
        bigint    trigger_txtp_config_id FK
        text      field_path
        varchar   override_type
        jsonb     static_value
    }

    trs_suite_trigger_generated_messages {
        bigserial id PK
        bigint    trigger_txtp_config_id FK
        int       message_order
        jsonb     payload_json
        varchar   end_to_end_id
        bigint    linked_context_message_id FK
        varchar   validation_status
    }

    trs_suite_enrichment_tables {
        bigserial id PK
        bigint    generation_id FK
        varchar   table_name
        int       table_order
        int       row_count
        jsonb     payload_template_json
    }

    trs_suite_enrichment_field_strategies {
        bigserial id PK
        bigint    enrichment_table_id FK
        varchar   column_name
        varchar   column_type
        varchar   strategy_code
    }

    trs_suite_enrichment_generated_rows {
        bigserial id PK
        bigint    enrichment_table_id FK
        int       row_order
        jsonb     record_json
    }

    trs_suite_context_sim_pairs {
        bigserial id PK
        bigint    generation_id FK
        int       pair_order
        bigint    context_message_id FK
        bigint    trigger_message_id FK
        jsonb     context_payload_json
        jsonb     trigger_payload_json
        varchar   validation_status
        varchar   pairing_key
    }

    trs_simulation_runs {
        bigserial id PK
        bigint    suite_id FK
        bigint    generation_id FK
        int       run_number
        bigint    source_run_id FK
        varchar   trigger_source
        varchar   status
        varchar   phase
        varchar   triggered_by
        varchar   rule_image_tag
        varchar   rule_image_digest
        varchar   docker_network_name
        varchar   error_code
        text      error_message
        timestamptz started_at
        timestamptz completed_at
    }

    trs_simulation_run_events {
        bigserial id PK
        bigint    run_id FK
        int       event_order
        varchar   phase
        varchar   level
        varchar   event_type
        text      message
        jsonb     details_json
        timestamptz occurred_at
    }

    trs_simulation_run_results {
        bigserial id PK
        bigint    run_id FK
        int       transaction_order
        bigint    trigger_message_id FK
        varchar   trigger_message_external_id
        varchar   trigger_txtp
        numeric   independent_variable
        varchar   result_band
        numeric   expected_independent_variable
        varchar   expected_result_band
        text      notes
        jsonb     rule_processor_response
    }

    trs_simulation_run_result_context_links {
        bigint run_result_id PK,FK
        bigint context_message_id PK,FK
    }

    trs_simulation_run_artifacts {
        bigserial id PK
        bigint    run_id FK
        varchar   artifact_type
        varchar   artifact_name
        text      content_text
        jsonb     content_json
    }
```

## Key invariants

- **Tenant scoping** lives on `trs_simulation_suites.tenant_id` only. All child queries must join through and filter on it.
- **Iteration immutability:** `trs_suite_generations` rows are immutable after `saveIterationTransactional`. New iterations create a new row, not an update.
- **Run-number allocation:** `UNIQUE (suite_id, generation_id, run_number)` enforced by DB; computed under `pg_advisory_xact_lock(hashtext(suite_id || ':' || generation_id))`.
- **Pairing:** A trigger message can independently belong to (a) one or more pair rows in `trs_suite_context_sim_pairs`, and (b) a context message via `linked_context_message_id` when `link_to_context_pairs = true`.
