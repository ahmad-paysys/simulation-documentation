-- TRS Simulation Studio v2.2
-- First-time database initialization script for a blank database.
-- 3NF schema for suites, iterations, faker inputs, generated datasets,
-- deterministic pairing snapshots, and run lifecycle/result persistence.

BEGIN;

-- -----------------------------------------------------------------------------
-- 0) Shared helper trigger for updated_at maintenance
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trs_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------------
-- 1) Suite root aggregate
-- -----------------------------------------------------------------------------
CREATE TABLE public.trs_simulation_suites (
  id                      BIGSERIAL PRIMARY KEY,
  tenant_id               VARCHAR(255) NOT NULL,
  name                    VARCHAR(120) NOT NULL,
  description             VARCHAR(500),
  simulation_type         VARCHAR(30) NOT NULL DEFAULT 'SINGLE_RULE',
  status                  VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
  rule_repo               VARCHAR(255),
  rule_name               VARCHAR(255),
  rule_version            VARCHAR(128),
  primary_txtp            VARCHAR(80),
  primary_txtp_version    VARCHAR(80),
  clone_source_suite_id   BIGINT REFERENCES public.trs_simulation_suites(id),
  iteration_count         INTEGER NOT NULL DEFAULT 0,
  run_count               INTEGER NOT NULL DEFAULT 0,
  last_run_at             TIMESTAMPTZ,
  wizard_progress         JSONB NOT NULL DEFAULT '{}'::jsonb,
  metadata                JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by              VARCHAR(255) NOT NULL,
  created_by_email        VARCHAR(255),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_trs_simulation_suites_simulation_type
    CHECK (simulation_type IN ('SINGLE_RULE', 'INTEGRATION_TESTING')),
  CONSTRAINT chk_trs_simulation_suites_status
    CHECK (status IN ('DRAFT', 'RUNNING', 'COMPLETED', 'FAILED', 'ARCHIVED'))
);

CREATE INDEX idx_sim_suites_tenant
  ON public.trs_simulation_suites(tenant_id);
CREATE INDEX idx_sim_suites_status
  ON public.trs_simulation_suites(status);
CREATE INDEX idx_sim_suites_updated
  ON public.trs_simulation_suites(updated_at DESC);
CREATE INDEX idx_sim_suites_rule
  ON public.trs_simulation_suites(rule_name);
CREATE INDEX idx_sim_suites_primary_txtp
  ON public.trs_simulation_suites(primary_txtp);
CREATE INDEX idx_sim_suites_tenant_name
  ON public.trs_simulation_suites(tenant_id, name);
CREATE INDEX idx_sim_suites_tenant_status_updated
  ON public.trs_simulation_suites(tenant_id, status, updated_at DESC);

CREATE TRIGGER trg_trs_simulation_suites_updated_at
BEFORE UPDATE ON public.trs_simulation_suites
FOR EACH ROW
EXECUTE FUNCTION public.trs_set_updated_at();

-- -----------------------------------------------------------------------------
-- 2) Iteration (generation) aggregate
-- -----------------------------------------------------------------------------
CREATE TABLE public.trs_suite_generations (
  id                             BIGSERIAL PRIMARY KEY,
  suite_id                       BIGINT NOT NULL REFERENCES public.trs_simulation_suites(id) ON DELETE CASCADE,
  generation_number              INTEGER NOT NULL,
  status                         VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
  simulation_type                VARCHAR(30) NOT NULL DEFAULT 'SINGLE_RULE',
  rule_repo                      VARCHAR(255),
  rule_version                   VARCHAR(128),
  context_count                  INTEGER NOT NULL DEFAULT 0,
  trigger_count                  INTEGER NOT NULL DEFAULT 0,
  enrichment_table_count         INTEGER NOT NULL DEFAULT 0,
  generated_context_count        INTEGER NOT NULL DEFAULT 0,
  generated_trigger_count        INTEGER NOT NULL DEFAULT 0,
  generated_enrichment_row_count INTEGER NOT NULL DEFAULT 0,
  context_field_config_count     INTEGER NOT NULL DEFAULT 0,
  trigger_field_config_count     INTEGER NOT NULL DEFAULT 0,
  enrichment_field_config_count  INTEGER NOT NULL DEFAULT 0,
  wizard_snapshot                JSONB NOT NULL DEFAULT '{}'::jsonb,
  generation_metadata            JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by                     VARCHAR(255) NOT NULL,
  created_by_email               VARCHAR(255),
  created_at                     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_suite_generations_suite_generation
    UNIQUE (suite_id, generation_number),
  CONSTRAINT chk_trs_suite_generations_status
    CHECK (status IN ('DRAFT', 'READY', 'RUNNING', 'COMPLETED', 'FAILED', 'ARCHIVED')),
  CONSTRAINT chk_trs_suite_generations_simulation_type
    CHECK (simulation_type IN ('SINGLE_RULE', 'INTEGRATION_TESTING'))
);

CREATE INDEX idx_trs_suite_generations_suite_id
  ON public.trs_suite_generations(suite_id);
CREATE INDEX idx_trs_suite_generations_created_at
  ON public.trs_suite_generations(created_at DESC);

CREATE TRIGGER trg_trs_suite_generations_updated_at
BEFORE UPDATE ON public.trs_suite_generations
FOR EACH ROW
EXECUTE FUNCTION public.trs_set_updated_at();

-- -----------------------------------------------------------------------------
-- 3) Context dataset faker inputs + generated data
-- -----------------------------------------------------------------------------
CREATE TABLE public.trs_suite_context_txtp_configs (
  id                      BIGSERIAL PRIMARY KEY,
  generation_id           BIGINT NOT NULL REFERENCES public.trs_suite_generations(id) ON DELETE CASCADE,
  txtp                    VARCHAR(80) NOT NULL,
  txtp_version            VARCHAR(80) NOT NULL,
  display_order           INTEGER NOT NULL,
  message_count           INTEGER NOT NULL CHECK (message_count >= 1),
  schema_snapshot         JSONB NOT NULL,
  sample_payload_snapshot JSONB,
  faker_seed              BIGINT,
  generator_profile       JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_suite_context_txtp_configs
    UNIQUE (generation_id, txtp, txtp_version, display_order)
);

CREATE INDEX idx_trs_suite_context_txtp_configs_generation_id
  ON public.trs_suite_context_txtp_configs(generation_id);

CREATE TABLE public.trs_suite_context_field_strategies (
  id                      BIGSERIAL PRIMARY KEY,
  context_txtp_config_id  BIGINT NOT NULL REFERENCES public.trs_suite_context_txtp_configs(id) ON DELETE CASCADE,
  field_path              TEXT NOT NULL,
  strategy_code           VARCHAR(24) NOT NULL,
  static_value            JSONB,
  range_min               NUMERIC,
  range_max               NUMERIC,
  generator_type          VARCHAR(64),
  generator_options       JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_required_override    BOOLEAN,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_suite_context_field_strategies
    UNIQUE (context_txtp_config_id, field_path),
  CONSTRAINT chk_trs_suite_context_field_strategies_strategy
    CHECK (strategy_code IN ('keep_sample', 'static', 'range', 'generated', 'null', 'skip')),
  CONSTRAINT chk_trs_suite_context_field_strategies_range
    CHECK (
      strategy_code <> 'range'
      OR (range_min IS NOT NULL AND range_max IS NOT NULL AND range_min <= range_max)
    )
);

CREATE INDEX idx_trs_suite_context_field_strategies_config_id
  ON public.trs_suite_context_field_strategies(context_txtp_config_id);

CREATE TABLE public.trs_suite_context_generated_messages (
  id                      BIGSERIAL PRIMARY KEY,
  context_txtp_config_id  BIGINT NOT NULL REFERENCES public.trs_suite_context_txtp_configs(id) ON DELETE CASCADE,
  message_order           INTEGER NOT NULL CHECK (message_order >= 1),
  payload_json            JSONB NOT NULL,
  payload_hash            CHAR(64),
  validation_status       VARCHAR(16) NOT NULL DEFAULT 'VALID'
                          CHECK (validation_status IN ('VALID', 'INVALID')),
  validation_errors       JSONB,
  generated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_suite_context_generated_messages
    UNIQUE (context_txtp_config_id, message_order)
);

CREATE INDEX idx_trs_suite_context_generated_messages_config_id
  ON public.trs_suite_context_generated_messages(context_txtp_config_id);
CREATE INDEX idx_trs_suite_context_generated_messages_generated_at
  ON public.trs_suite_context_generated_messages(generated_at DESC);

-- -----------------------------------------------------------------------------
-- 4) Trigger dataset faker inputs + generated data
-- -----------------------------------------------------------------------------
CREATE TABLE public.trs_suite_trigger_txtp_configs (
  id                            BIGSERIAL PRIMARY KEY,
  generation_id                 BIGINT NOT NULL REFERENCES public.trs_suite_generations(id) ON DELETE CASCADE,
  txtp                          VARCHAR(80) NOT NULL,
  txtp_version                  VARCHAR(80) NOT NULL,
  display_order                 INTEGER NOT NULL,
  message_count                 INTEGER NOT NULL CHECK (message_count >= 1),
  link_to_context_pairs         BOOLEAN NOT NULL DEFAULT FALSE,
  payload_template_json         JSONB NOT NULL,
  expected_independent_variable NUMERIC,
  expected_result_band          VARCHAR(16),
  notes                         TEXT,
  faker_seed                    BIGINT,
  generator_profile             JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_suite_trigger_txtp_configs
    UNIQUE (generation_id, txtp, txtp_version, display_order),
  CONSTRAINT chk_trs_suite_trigger_txtp_configs_expected_band
    CHECK (
      expected_result_band IS NULL
      OR expected_result_band IN ('good', 'neutral', 'bad', 'error')
    )
);

CREATE INDEX idx_trs_suite_trigger_txtp_configs_generation_id
  ON public.trs_suite_trigger_txtp_configs(generation_id);

CREATE TABLE public.trs_suite_trigger_field_overrides (
  id                      BIGSERIAL PRIMARY KEY,
  trigger_txtp_config_id  BIGINT NOT NULL REFERENCES public.trs_suite_trigger_txtp_configs(id) ON DELETE CASCADE,
  field_path              TEXT NOT NULL,
  override_type           VARCHAR(24) NOT NULL,
  static_value            JSONB,
  range_min               NUMERIC,
  range_max               NUMERIC,
  generator_type          VARCHAR(64),
  generator_options       JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_suite_trigger_field_overrides
    UNIQUE (trigger_txtp_config_id, field_path),
  CONSTRAINT chk_trs_suite_trigger_field_overrides_type
    CHECK (override_type IN ('static', 'range', 'generated', 'remove', 'null')),
  CONSTRAINT chk_trs_suite_trigger_field_overrides_range
    CHECK (
      override_type <> 'range'
      OR (range_min IS NOT NULL AND range_max IS NOT NULL AND range_min <= range_max)
    )
);

CREATE INDEX idx_trs_suite_trigger_field_overrides_config_id
  ON public.trs_suite_trigger_field_overrides(trigger_txtp_config_id);

CREATE TABLE public.trs_suite_trigger_generated_messages (
  id                        BIGSERIAL PRIMARY KEY,
  trigger_txtp_config_id    BIGINT NOT NULL REFERENCES public.trs_suite_trigger_txtp_configs(id) ON DELETE CASCADE,
  message_order             INTEGER NOT NULL CHECK (message_order >= 1),
  payload_json              JSONB NOT NULL,
  end_to_end_id             VARCHAR(140),
  linked_context_message_id BIGINT REFERENCES public.trs_suite_context_generated_messages(id),
  validation_status         VARCHAR(16) NOT NULL DEFAULT 'VALID'
                            CHECK (validation_status IN ('VALID', 'INVALID')),
  validation_errors         JSONB,
  generated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_suite_trigger_generated_messages
    UNIQUE (trigger_txtp_config_id, message_order)
);

CREATE INDEX idx_trs_suite_trigger_generated_messages_config_id
  ON public.trs_suite_trigger_generated_messages(trigger_txtp_config_id);
CREATE INDEX idx_trs_suite_trigger_generated_messages_e2e
  ON public.trs_suite_trigger_generated_messages(end_to_end_id);

-- -----------------------------------------------------------------------------
-- 5) Enrichment dataset faker inputs + generated rows
-- -----------------------------------------------------------------------------
CREATE TABLE public.trs_suite_enrichment_tables (
  id                     BIGSERIAL PRIMARY KEY,
  generation_id          BIGINT NOT NULL REFERENCES public.trs_suite_generations(id) ON DELETE CASCADE,
  table_name             VARCHAR(63) NOT NULL,
  table_order            INTEGER NOT NULL DEFAULT 1,
  row_count              INTEGER NOT NULL DEFAULT 0 CHECK (row_count >= 0),
  payload_template_json  JSONB,
  schema_template_json   JSONB,
  faker_profile          JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_suite_enrichment_tables
    UNIQUE (generation_id, table_name)
);

CREATE INDEX idx_trs_suite_enrichment_tables_generation_id
  ON public.trs_suite_enrichment_tables(generation_id);

CREATE TABLE public.trs_suite_enrichment_field_strategies (
  id                      BIGSERIAL PRIMARY KEY,
  enrichment_table_id     BIGINT NOT NULL REFERENCES public.trs_suite_enrichment_tables(id) ON DELETE CASCADE,
  column_name             VARCHAR(128) NOT NULL,
  column_type             VARCHAR(64),
  strategy_code           VARCHAR(24) NOT NULL,
  static_value            JSONB,
  range_min               NUMERIC,
  range_max               NUMERIC,
  generator_type          VARCHAR(64),
  generator_options       JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_suite_enrichment_field_strategies
    UNIQUE (enrichment_table_id, column_name),
  CONSTRAINT chk_trs_suite_enrichment_field_strategies_strategy
    CHECK (strategy_code IN ('static', 'range', 'generated', 'null', 'copy')),
  CONSTRAINT chk_trs_suite_enrichment_field_strategies_range
    CHECK (
      strategy_code <> 'range'
      OR (range_min IS NOT NULL AND range_max IS NOT NULL AND range_min <= range_max)
    )
);

CREATE INDEX idx_trs_suite_enrichment_field_strategies_table_id
  ON public.trs_suite_enrichment_field_strategies(enrichment_table_id);

CREATE TABLE public.trs_suite_enrichment_generated_rows (
  id                     BIGSERIAL PRIMARY KEY,
  enrichment_table_id    BIGINT NOT NULL REFERENCES public.trs_suite_enrichment_tables(id) ON DELETE CASCADE,
  row_order              INTEGER NOT NULL CHECK (row_order >= 1),
  record_json            JSONB NOT NULL,
  generated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_suite_enrichment_generated_rows
    UNIQUE (enrichment_table_id, row_order)
);

CREATE INDEX idx_trs_suite_enrichment_generated_rows_table_id
  ON public.trs_suite_enrichment_generated_rows(enrichment_table_id);

-- -----------------------------------------------------------------------------
-- 6) Context <-> trigger pairing snapshots for deterministic run orchestration
-- -----------------------------------------------------------------------------
CREATE TABLE public.trs_suite_context_sim_pairs (
  id                    BIGSERIAL PRIMARY KEY,
  generation_id         BIGINT NOT NULL REFERENCES public.trs_suite_generations(id) ON DELETE CASCADE,
  pair_order            INTEGER NOT NULL CHECK (pair_order >= 1),
  context_message_id    BIGINT NOT NULL REFERENCES public.trs_suite_context_generated_messages(id) ON DELETE CASCADE,
  trigger_message_id    BIGINT NOT NULL REFERENCES public.trs_suite_trigger_generated_messages(id) ON DELETE CASCADE,
  context_payload_json  JSONB,
  trigger_payload_json  JSONB,
  validation_status     VARCHAR(16) NOT NULL DEFAULT 'VALID'
                        CHECK (validation_status IN ('VALID', 'INVALID', 'SKIPPED')),
  pairing_key           VARCHAR(140),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_suite_context_sim_pairs_order
    UNIQUE (generation_id, pair_order),
  CONSTRAINT uq_trs_suite_context_sim_pairs_message
    UNIQUE (context_message_id, trigger_message_id)
);

CREATE INDEX idx_trs_suite_context_sim_pairs_generation_id
  ON public.trs_suite_context_sim_pairs(generation_id);

-- Note: pair-level context/trigger payloads are stored inline on
-- trs_suite_context_sim_pairs (context_payload_json, trigger_payload_json).
-- The previously planned trs_suite_context_sim_payloads child table was
-- dropped from this migration as redundant (see implementation_report.md §3.2).

-- -----------------------------------------------------------------------------
-- 7) Run lifecycle + result persistence
-- -----------------------------------------------------------------------------
CREATE TABLE public.trs_simulation_runs (
  id                    BIGSERIAL PRIMARY KEY,
  suite_id              BIGINT NOT NULL REFERENCES public.trs_simulation_suites(id) ON DELETE CASCADE,
  generation_id         BIGINT NOT NULL REFERENCES public.trs_suite_generations(id) ON DELETE CASCADE,
  run_number            INTEGER NOT NULL,
  source_run_id         BIGINT REFERENCES public.trs_simulation_runs(id),
  trigger_source        VARCHAR(32) NOT NULL DEFAULT 'WIZARD',
  status                VARCHAR(32) NOT NULL DEFAULT 'ENV_PROVISIONING',
  phase                 VARCHAR(64) NOT NULL DEFAULT 'ENV_PROVISIONING',
  triggered_by          VARCHAR(255) NOT NULL,
  triggered_by_email    VARCHAR(255),
  rule_repo             VARCHAR(255),
  rule_version          VARCHAR(128),
  rule_image_tag        VARCHAR(255),
  rule_image_digest     VARCHAR(255),
  docker_network_name   VARCHAR(255),
  orchestrator_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  error_code            VARCHAR(64),
  error_message         TEXT,
  started_at            TIMESTAMPTZ,
  completed_at          TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_simulation_runs
    UNIQUE (suite_id, generation_id, run_number),
  CONSTRAINT chk_trs_simulation_runs_status
    CHECK (status IN ('ENV_PROVISIONING', 'RUNNING', 'COMPLETED', 'FAILED', 'TIMED_OUT', 'CANCELLED')),
  CONSTRAINT chk_trs_simulation_runs_phase
    CHECK (phase IN (
      'ENV_PROVISIONING',
      'NETWORK_CREATE',
      'BASE_CONTAINERS_START',
      'ODS_INIT',
      'APP_CONTAINERS_START',
      'TRANSACTION_LOOP',
      'CLEANUP',
      'COMPLETED',
      'FAILED'
    ))
);

CREATE INDEX idx_trs_simulation_runs_suite_generation
  ON public.trs_simulation_runs(suite_id, generation_id);
CREATE INDEX idx_trs_simulation_runs_status
  ON public.trs_simulation_runs(status);
CREATE INDEX idx_trs_simulation_runs_created_at
  ON public.trs_simulation_runs(created_at DESC);

CREATE TRIGGER trg_trs_simulation_runs_updated_at
BEFORE UPDATE ON public.trs_simulation_runs
FOR EACH ROW
EXECUTE FUNCTION public.trs_set_updated_at();

CREATE TABLE public.trs_simulation_run_events (
  id            BIGSERIAL PRIMARY KEY,
  run_id        BIGINT NOT NULL REFERENCES public.trs_simulation_runs(id) ON DELETE CASCADE,
  event_order   INTEGER NOT NULL,
  phase         VARCHAR(64),
  level         VARCHAR(16) NOT NULL DEFAULT 'INFO'
                CHECK (level IN ('DEBUG', 'INFO', 'WARN', 'ERROR')),
  event_type    VARCHAR(64),
  message       TEXT NOT NULL,
  details_json  JSONB,
  occurred_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_simulation_run_events
    UNIQUE (run_id, event_order)
);

CREATE INDEX idx_trs_simulation_run_events_run_id
  ON public.trs_simulation_run_events(run_id);
CREATE INDEX idx_trs_simulation_run_events_time
  ON public.trs_simulation_run_events(occurred_at DESC);

CREATE TABLE public.trs_simulation_run_results (
  id                            BIGSERIAL PRIMARY KEY,
  run_id                        BIGINT NOT NULL REFERENCES public.trs_simulation_runs(id) ON DELETE CASCADE,
  transaction_order             INTEGER NOT NULL,
  trigger_message_id            BIGINT REFERENCES public.trs_suite_trigger_generated_messages(id),
  trigger_message_external_id   VARCHAR(140),
  trigger_txtp                  VARCHAR(80),
  independent_variable          NUMERIC,
  result_band                   VARCHAR(16) NOT NULL,
  expected_independent_variable NUMERIC,
  expected_result_band          VARCHAR(16),
  notes                         TEXT,
  rule_processor_response       JSONB,
  received_at                   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_trs_simulation_run_results
    UNIQUE (run_id, transaction_order),
  CONSTRAINT chk_trs_simulation_run_results_result_band
    CHECK (result_band IN ('good', 'neutral', 'bad', 'error')),
  CONSTRAINT chk_trs_simulation_run_results_expected_band
    CHECK (expected_result_band IS NULL OR expected_result_band IN ('good', 'neutral', 'bad', 'error'))
);

CREATE INDEX idx_trs_simulation_run_results_run_id
  ON public.trs_simulation_run_results(run_id);
CREATE INDEX idx_trs_simulation_run_results_band
  ON public.trs_simulation_run_results(result_band);

CREATE TABLE public.trs_simulation_run_result_context_links (
  run_result_id      BIGINT NOT NULL REFERENCES public.trs_simulation_run_results(id) ON DELETE CASCADE,
  context_message_id BIGINT NOT NULL REFERENCES public.trs_suite_context_generated_messages(id) ON DELETE CASCADE,
  PRIMARY KEY (run_result_id, context_message_id)
);

CREATE INDEX idx_trs_simulation_run_result_context_links_context
  ON public.trs_simulation_run_result_context_links(context_message_id);

CREATE TABLE public.trs_simulation_run_artifacts (
  id             BIGSERIAL PRIMARY KEY,
  run_id         BIGINT NOT NULL REFERENCES public.trs_simulation_runs(id) ON DELETE CASCADE,
  artifact_type  VARCHAR(32) NOT NULL,
  artifact_name  VARCHAR(255),
  content_text   TEXT,
  content_json   JSONB,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_trs_simulation_run_artifacts_type
    CHECK (artifact_type IN (
      'CONTAINER_LOG',
      'ODS_SQL',
      'NATS_REQUEST',
      'NATS_RESPONSE',
      'RULE_PROCESSOR_RAW',
      'ERROR_STACK',
      'METRICS',
      'OTHER'
    ))
);

CREATE INDEX idx_trs_simulation_run_artifacts_run_id
  ON public.trs_simulation_run_artifacts(run_id);
CREATE INDEX idx_trs_simulation_run_artifacts_type
  ON public.trs_simulation_run_artifacts(artifact_type);

-- -----------------------------------------------------------------------------
-- 8) (Removed) Shared TXTP config snapshot table
--    The previously planned trs_suite_txtp_configs union table was dropped from
--    this migration. The role-specific tables (trs_suite_context_txtp_configs,
--    trs_suite_trigger_txtp_configs) are authoritative and have richer columns.
--    See implementation_report.md §3.2 for the decision.
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- 9) Documentation comments
-- -----------------------------------------------------------------------------
COMMENT ON TABLE public.trs_simulation_suites IS
  'Top-level Simulation Studio suites. A suite can have many immutable generations (iterations).';

COMMENT ON TABLE public.trs_suite_generations IS
  'Immutable per-save iteration snapshot for a suite, including wizard snapshot and generated-data counters.';

COMMENT ON TABLE public.trs_suite_context_txtp_configs IS
  'Context dataset faker input config per TXTP for an iteration.';

COMMENT ON TABLE public.trs_suite_trigger_txtp_configs IS
  'Trigger dataset input/faker config per TXTP for an iteration.';

COMMENT ON TABLE public.trs_suite_enrichment_tables IS
  'Enrichment dataset input config per table for an iteration.';

COMMENT ON TABLE public.trs_simulation_runs IS
  'Run lifecycle state and orchestrator metadata for each iteration execution.';

COMMENT ON TABLE public.trs_simulation_run_results IS
  'One result row per processed trigger transaction in run submission order.';

COMMIT;
