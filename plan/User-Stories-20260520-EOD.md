# SM-01: Create a new simulation suite via Simulation Studio 

## Type

Functional

## User Story

As a rule developer, I can create a new simulation suite by completing the six-screen wizard, so that I have a structured, versioned unit of work for testing a specific rule.

## Acceptance Criteria

**Given** the user is on the Simulation Studio list page, **When** they click Create Simulation Suite, **Then** the six-screen wizard opens at Step 1.

**Given** the user completes all mandatory fields across all wizard screens, **When** they click Save Iteration on the summary screen, **Then** a new suite is created and the user is redirected to the suite detail page.

**Given** the user has partially filled the wizard, **When** they navigate back to a previous step, **Then** all previously entered data is retained.

**Given** the wizard is open on Step 1, **When** the user clicks Back, **Then** they are returned to the list page with no suite created.

## Assumptions

- The wizard is the only path to creating a new suite; there is no quick-create shortcut.
- Partial progress is held in component state for the session but is not auto-saved to the backend.

# SM-02: View all simulation suites in a searchable list 

## Type

Functional

## User Story

As a rule developer, I can view all simulation suites in a searchable, filterable list, so that I can quickly find the suite I need to work with.

## Acceptance Criteria

**Given** suites exist in the system, **When** the user navigates to Simulation Studio, **Then** all suites are displayed in a table with columns: Suite Name, Associated Rule, TXTP, Status, Iterations, Last Updated, Created By, and Actions.

**Given** the list is visible, **When** the user types in the search field, **Then** the table filters in real time to rows whose Suite Name contains the search string.

**Given** the list is visible, **When** the user selects a status from the Status filter dropdown, **Then** only suites matching that status are shown.

**Given** the list is visible, **When** the user selects a rule from the Rule filter dropdown, **Then** only suites associated with that rule are shown.

# SM-03: View suite details and iteration history 

## Type

Functional

## User Story

As a rule developer, I can open a suite detail page and review its metadata and all past iterations, so that I have full visibility of what was configured and run historically.

## Acceptance Criteria

**Given** a suite exists, **When** the user clicks the View icon on the list, **Then** the detail page opens showing suite metadata and the iteration history table.

**Given** the detail page is open, **When** the user reviews the Iteration History table, **Then** it shows one row per iteration with: Gen label, Created Date, Context count, Trigger count, and Status, Simulation Results, Rule Version.

**Given** a iteration has status Ready, **When** the user clicks Use on that row, **Then** they are navigated to the Rule Studio Simulation tab with that suite pre-selected.

**Given** the detail page is open, **When** the user clicks the back arrow, **Then** they return to the list page.

## Assumptions

- The latest iteration is shown at the top of the history table.
- Archived iterations remain visible but cannot be used in new simulations.

# SM-04: Run a new iteration in an existing suite 

## Type

Functional

## User Story

As a rule developer, I can run a new iteration in an existing suite by selecting a different version of the same rule, so that I can compare simulation outcomes across rule versions side by side.

## Acceptance Criteria

**Given** the user is editing an existing suite and reaches the Preview and Save screen, **When** it renders, **Then** a warning banner explains that saving will create a new iteration and will not overwrite previous ones.

**Given** the user saves a new iteration, **When** they return to the detail page, **Then** the new iteration appears at the top of the Iteration History table with an incremented version label.

**Given** an existing suite has iterations v1 and v2, **When** the user adds v3 with a different rule version, **Then** all three iterations remain accessible and can be individually viewed or run.

**Given** the edit wizard opens at Step 1, **When** it renders, **Then** the rule dropdown is pre-selected and locked; only the rule version dropdown is editable.

## Assumptions

- A suite is permanently bound to one rule; only the rule version can change between iterations.
- Previous iterations are never mutated by adding a new one.

# SM-05: Clone an existing suite 

## Type

Functional

## User Story

As a rule developer, I can clone an existing simulation suite, so that I can quickly create a variant without re-entering all wizard data from scratch.

## Acceptance Criteria

**Given** the user clicks the Clone icon on the list, **Then** the wizard opens in clone mode with all fields pre-populated from the source suite.

**Given** the wizard is in clone mode, **When** the user reaches the Suite Name field, **Then** it is pre-filled as Copy of [Original Name] and is editable.

**Given** the user saves the cloned suite, **When** it appears on the list, **Then** it is a new independent suite at iteration v1 with no run history from the source.

**Given** the clone wizard is open, **When** the user changes any field, **Then** the original suite is not affected.

## Assumptions

- Cloning copies wizard configuration, along with the simulation run results.
- User will not be able to:
  - Change the Rule and TXTP selected (version can be changed)
  - Add or remove the TXTPs from the list
  
# S1-01: Select a rule and transaction version for the suite 

## Type

Functional

## User Story

As a rule developer, I can select the rule and transaction versions of that rule in Step 1 of the wizard, so that the simulation suite is correctly bound to the intended rule and transaction versions.

## Acceptance Criteria

**Given** the user is on Step 1, **When** the Rule dropdown renders, **Then** it lists all available rules fetched from the registry.

**Given** a rule is selected, **When** the user opens the Rule Version dropdown, **Then** it shows only versions available for that selected rule.

**Given** a rule and version are selected, **When** the user opens the TxTp dropdown, **Then** it shows the list of deployed TxTps along with the version to act as the Primary Message Type against that rule.

**Given** the user is in edit mode and reaches Step 1, **When** it renders, **Then** the rule and transaction is pre-selected and its dropdown is disabled; only the version dropdown is editable.

## Assumptions

- Rule and transaction version lists are fetched dynamically from the backend at wizard load time.
- In create mode, no rule is pre-selected by default.

# S1-02: Define suite metadata 

## Type

Functional

## User Story

As a rule developer, I can provide a suite name and description in Step 1, so that the suite is identifiable and its intent is documented for other team members.

## Acceptance Criteria

**Given** the user is on Step 1 and leaves the Suite Name field empty, **When** they click Next, **Then** a validation error prevents navigation and highlights the required field.

**Given** the user enters a valid suite name and clicks Next, **Then** they advance to Step 2 with the name saved in wizard state.

**Given** the wizard is in clone mode and the user reaches Step 1, **When** it renders, **Then** the name is pre-filled as Copy of [Original Name] and all other fields reflect the source suite.

# S2-01: Add and configure TXTPs for the suite 

## Type

Functional

## User Story

As a rule developer, I can add one or more TXTPs and configure per-field iteration strategies for each, so that synthetic context messages conform to the schema required by the rule.

## Acceptance Criteria

**Given** the user is on Step 2, **When** they select a TXTP type and version, number of messages they need of this TXTP, and click Add TXTP, **Then** a new row appears in the TXTP table.

**Given** a TXTP row exists, **When** the user clicks it to expand, **Then** the field configuration panel opens with schema fields listed on the left and the strategy configurator on the right.

**Given** the field configuration panel is open, **When** the user selects a iteration strategy (Keep sample value, Static value, or Skip field), **Then** the appropriate sub-options render for that strategy.

**Given** multiple TXTPs are added, **When** the user reviews the table, **Then** each row shows its order number; the first row is the primary TXTP.

**Given** a TXTP row exists, **When** the user clicks Remove, **Then** the row is deleted from the table.

**Given** a TXTP has a loaded schema and sample payload, **When** the table renders, **Then** Schema Loaded and Sample Available status badges are shown for that row.

**Given** a TXTP has a loaded schema, **When** the user clicks on Preview Data, **Then** a preview of the data is shown in a table with 5 records.

## Assumptions

- The first TXTP in the list is the primary TXTP and forms part of the suite identity alongside the selected rule.
- TXTPs are sourced from tcs_config; only schema-valid TXTPs are listed.

# S3-01: Configure and preview simulation trigger transactions 

## Type

Functional

## User Story

As a rule developer, I can configure a sample message payload for each selected TXTP on the Trigger Data screen, so that I can customise specific field values to make my simulation transactions more targeted to the scenario I am testing.

## Acceptance Criteria

**Given** the user arrives on Step 3 (Trigger Data), **When** the screen renders, **Then** one collapsible card appears per TXTP selected in Step 2, each pre-populated with the sample payload from TCS.

**Given** a TXTP card is expanded, **When** the user reviews the payload editor, **Then** the JSON is displayed in an editable text area with the TCS sample as the default content.

**Given** the payload editor is visible, **When** the user modifies field values within the JSON, **Then** the changes are saved in wizard state for that TXTP.

**Given** a TXTP card is visible, **When** the user sets the No. of msgs value, **Then** the specified number of trigger transactions will be generated using that payload as the base template.

**Given** the No. of msgs value exceeds 15 across all TXTPs, **When** the user attempts to proceed, **Then** a validation error is shown and navigation to the next step is blocked.

**Given** the Link to context pairs checkbox is checked for a TXTP, **When** trigger messages are generated, **Then** each message is linked to a corresponding context pair for that TXTP via the EndtoEndID.

**Given** the user has configured payloads for all TXTPs and clicks Next Step, **When** validation passes, **Then** they advance to Step 4 (Enrichment Data) with all payload configurations saved.

## Assumptions

- The 15-transaction maximum is enforced server-side as well as in the UI.

# S4-01: Define one or more enrichment tables

## Type

Functional

## User Story

As a rule developer, I can define one or more enrichment tables with a JSON payload, so that rules requiring ODS lookups have the correct reference data available during simulation.

## Acceptance Criteria

**Given** the user is on Step 5 and enters a table name and pastes a JSON payload, **When** they click Save Record, **Then** the record appears in the Saved Enrichment Records table.

**Given** the user needs multiple enrichment tables, **When** they repeat the add process, **Then** each additional table appears as a new row in the saved records table.

**Given** the Target Table Name field is empty, **When** the user tries to click Save Record, **Then** the button is disabled and no record is added.

**Given** a saved enrichment record exists, **When** the user clicks Remove, **Then** the record is deleted from the list.

**Given** enrichment records are saved, **When** the user proceeds to Step 6, **Then** all saved tables are reflected in the suite summary.

## Assumptions

- There is no hard cap on the number of enrichment tables per iteration.
- The JSON payload is the schema template; during simulation the system issues CREATE TABLE and bulk-INSERT for each table.

# S5-01: Review the full suite summary before saving

## Type

Functional

## User Story

As a rule developer, I can review a complete read-only summary of all wizard inputs before committing, so that I can catch errors before a iteration is persisted.

## Acceptance Criteria

**Given** the user reaches Step 6, **When** the summary renders, **Then** it shows: Suite Name, Associated Rule, Rule Version, TXTPs, Iteration Number, Enrichment Tables, Context count, Trigger count, and total Valid Payloads.

**Given** the summary is shown, **When** the user clicks Back in the wizard footer, **Then** they return to Step 5 with all data intact.

**Given** the user is in edit mode, **When** Step 6 renders, **Then** a warning banner states that saving will create a new iteration without overwriting previous ones.

**Given** the user clicks Save as Draft, **When** the action completes, **Then** they are returned to the list page and the suite appears with status Draft.

**Given** the user clicks Save Iteration, **When** the action completes, **Then** they are redirected to the suite detail page and the new iteration appears in the history table.

# SR-01: Run a simulation and observe results upon completion

## Type

Functional

## User Story

As a rule developer, I can click Run Simulation on the summary screen and be navigated to a results screen once the run completes, so that I can review the outcomes of all sim transactions against the rule.

## Acceptance Criteria

**Given** the user is on the summary screen and clicks Run Simulation, **When** the request is dispatched, **Then** the button transitions to a disabled loading state and the user sees a non-interactive waiting state indicating the simulation is in progress.

**Given** the simulation is running, **When** the run reaches a terminal state (Completed or Failed), **Then** the user is automatically navigated to the Results screen without any manual action.

**Given** the Results screen loads after a completed run, **When** the page renders, **Then** it displays the seeded results with one row per sim transaction showing: Trigger Message ID, Independent Variable, Result Band chip, Expected IV, Expected Band chip, and Notes.

**Given** the run fails before completion, **When** the user is navigated to the Results screen, **Then** a clear failure state is shown with a reason, and no partial results are displayed.

**Given** the Results screen is open, **When** the user reviews the page, **Then** the current run's results appear at the top expanded, with any previous runs for the same bucket listed collapsed below it.

## Assumptions

- The frontend polls the backend using the run_id until a terminal state is returned, then triggers navigation to the Results screen.
- There are no live logs or incremental result updates; results are only displayed once the full run is complete and seeded.

## Dependency

| Dependency | Purpose |
|---|---|
| nats-utilities API | Sends trigger messages to the rule processor |
| NATS subject | Routes the trigger message to the correct rule processor |
| Rule Processor | Receives and evaluates the trigger transaction |
| Sandbox ODS | Provides historical context during rule execution |

# SR-02: View simulation results with band-coded outcome per transaction

## Type

Functional

## User Story

As a rule developer, I can view the completed simulation results as a table of per-transaction outcomes with colour-coded band chips, so that I can quickly identify which transactions produced unexpected results.

## Acceptance Criteria

**Given** a run has completed, **When** the results section renders, **Then** it shows summary stat cards: Total Iterations, Latest Success Rate, Total Messages Processed, and Active Dataset.

**Given** the results table is shown, **When** the user reviews it, **Then** each row shows: Trigger Message ID, Independent Variable, Result Band chip, Expected IV, Expected Band chip, and Notes.

**Given** a result band is good, **When** the chip renders, **Then** it is green. For neutral it is grey, for bad it is orange, and for error it is red.

**Given** multiple simulation runs exist for the suite, **When** the results page loads, **Then** the most recent run is shown expanded at the top and all prior runs are listed collapsed below it.

**Given** the user clicks a collapsed run row, **When** it expands, **Then** it shows that run's full results table for direct comparison with other runs.

## Assumptions

- Expected IV and Expected Band are values stored with the sim transaction configuration and do not change between runs.

# SR-03: Search and filter simulation history

## Type

Functional

## User Story

As a rule developer, I can search and filter the simulation run history by simulation ID, rule version, and date, so that I can quickly locate a specific run for review or comparison.

## Acceptance Criteria

**Given** the results page is open, **When** the user types in the search box, **Then** the iteration list filters to rows whose ID or rule version contains the search string.

**Given** the filter panel is open and the user sets a Rule ID / Version filter and clicks Apply, **When** the filter is applied, **Then** only matching iterations are shown.

**Given** the filter panel is open and the user sets a Date filter and clicks Apply, **When** the filter is applied, **Then** only iterations from that date are shown.

**Given** filters are active, **When** the user clicks Clear All in the filter panel, **Then** all filters are reset and the full list is restored.

**Given** results are shown, **When** the user clicks Expand All, **Then** all iteration rows expand; clicking Collapse All collapses them all.

# RR-01: Rerun a past iteration from Simulation Result page

## Type

Functional

## User Story

As a rule developer or reviewer, I can rerun any past iteration from the Simulation Results page with a single click, so that I can reproduce results or verify behaviour after a fix without re-entering the wizard.

## Acceptance Criteria

**Given** the user is on the Results page, **When** they click Rerun against an iteration, **Then** the run is dispatched immediately without opening the wizard.

**Given** the rerun is dispatched, **When** the user is waiting, **Then** they see a non-interactive loading state indicating the simulation is in progress.

**Given** the rerun completes, **When** the Results page refreshes, **Then** the new run appears at the top of the results with its own started_at timestamp, and the previous run is pushed down.

**Given** the rerun fails, **When** the Results page updates, **Then** a clear failure state is shown with a reason in place of the results.

## Assumptions

- Reruns replay the exact stored wizard data; no edits are possible without creating a new iteration.
- Any user with access to the suite can trigger a rerun, supporting separation of duties for independent verification.

# RR-02: Rerun a past iteration from Simulation Suite History

## Type

Functional

## User Story

As a rule developer or reviewer, I can rerun any past iteration from the Simulation Suite History, so that I can independently verify results for a specific historical iteration without affecting other runs.

## Acceptance Criteria

**Given** the user is on the Simulation Suite History page, **When** they click Rerun against a specific iteration, **Then** the run is dispatched immediately without opening the wizard.

**Given** the rerun is dispatched, **When** the user is waiting, **Then** they see a non-interactive loading state against that iteration row indicating the run is in progress.

**Given** the rerun completes, **When** the Suite History updates, **Then** a new run row appears under the same iteration with its own started_at and triggered_by values recorded.

**Given** the rerun fails, **When** the Suite History updates, **Then** the new run row reflects a Failed status with a visible reason.

## Assumptions

- Reruns replay the exact stored wizard data; no edits are possible without creating a new iteration. If any changes to an iteration are needed, the user shall Edit the iteration from the Simulation Suite History.
- Any user with access to the suite can trigger a rerun, supporting separation of duties for independent verification.

# T-01: Atomically persist wizard data and dispatch orchestrator on run

## Type

Technical

## User Story

As a system, I can atomically persist the full wizard payload as a new iteration before dispatching the orchestrator, so that no partial or corrupt iteration state can exist if dispatch fails.

## Acceptance Criteria

**Given** the user clicks Run Simulation, **When** the backend receives the request, **Then** all wizard data (context, sim transactions, enrichment tables, rule version) is written to the database in a single transaction before the orchestrator is called.

**Given** the database write succeeds but orchestrator dispatch fails, **When** the run record is inspected, **Then** it exists with status FAILED and no containers are started.

**Given** the orchestrator is dispatched successfully, **When** the HTTP response is returned to the frontend, **Then** it contains a run_id immediately without waiting for run completion.

**Given** the frontend receives a run_id, **When** it needs status updates, **Then** it polls the status endpoint using the run_id until the run reaches a terminal state.

# T-02: Orchestrate an isolated Docker container lifecycle per run

## Type

Technical

## User Story

As a system, I can spin up an isolated Docker environment per simulation run and tear it down on completion, so that runs are fully isolated and do not affect each other or the host environment.

## Acceptance Criteria

**Given** a run is dispatched, **When** the orchestrator starts, **Then** it creates a new isolated bridge network unique to that run.

**Given** the bridge network exists, **When** containers are started, **Then** Postgres and NATS start in parallel; nats-utilities and the rule processor start only after both are confirmed healthy.

**Given** Postgres is healthy, **When** ODS init runs, **Then** it executes CREATE TABLE for rule history, bulk-INSERT of all context rows, and CREATE TABLE plus bulk-INSERT for each enrichment table.

**Given** all four containers are healthy, **When** the transaction loop runs, **Then** each sim transaction is submitted sequentially with await=true to preserve history-dependent evaluation order.

**Given** the run reaches a terminal state, **When** cleanup runs, **Then** all containers and the bridge network are removed.

**Given** the rule processor container is started, **When** its image is pulled, **Then** it is pinned to the exact image digest of the chosen rule version and not a mutable tag.

## Assumptions

- Container orchestration is implemented via Dockerode or an equivalent programmatic Docker client.
- Health checks are configured on Postgres and NATS; the orchestrator waits for healthy status before proceeding.

# T-03: Persist one result row per sim transaction

## Type

Technical

## User Story

As a system, I can persist one result row per sim transaction after each run, so that results are queryable, auditable, and available for comparison across iterations.

## Acceptance Criteria

**Given** the transaction loop processes a sim transaction, **When** the rule processor returns a response, **Then** the system parses independent_variable and result_band and writes one result row to the database.

**Given** the rule processor returns an error for a transaction, **When** the result row is written, **Then** result_band is set to error and the run continues with the remaining transactions rather than aborting.

**Given** a run is marked COMPLETED, **When** results are queried, **Then** they are returned in transaction submission order.

**Given** results are being stored during a run, **When** the frontend polls for status, **Then** the polling response includes incremental result data so the UI can display partial results as they arrive.

# T-04: Handle container startup failures and run timeouts gracefully

## User Story

As a system, I can detect container startup failures and enforce a run timeout, so that failed runs are surfaced clearly to users and infrastructure is never left in an orphaned state.

## Acceptance Criteria

**Given** a container fails its health check within the expected startup window, **When** the orchestrator detects the failure, **Then** the run is marked FAILED with a descriptive reason identifying which container failed.

**Given** a run does not reach a terminal state within the configured timeout, **When** the timeout elapses, **Then** the run is marked FAILED, containers are torn down, and the user sees a timed-out failure state.

**Given** a run is marked FAILED, **When** the user views the results page, **Then** a clear failure message and reason are displayed.

**Given** any unhandled exception occurs during a run, **When** the orchestrator catches it, **Then** the run is marked FAILED and cleanup is triggered before the exception propagates further.

## Assumptions

- The timeout window is configurable via environment variable or system configuration.

# T-05: Push Rule Processor Image to Registry on Deployment

## Type

Technical

## User Story

As a system, I can build and push a versioned rule processor Docker image to a container registry upon rule deployment from TRS, so that every deployed rule version has an immutable, retrievable image that the simulation orchestrator can pin to by exact digest.

## Acceptance Criteria

**Given** a rule is submitted for deployment in TRS, **When** the deployment pipeline is triggered, **Then** a Docker image is built for the rule processor incorporating the exact rule logic and configuration of that version.

**Given** the image build succeeds, **When** the push is initiated, **Then** the image is pushed to the configured container registry tagged with both a human-readable version label (e.g. rule-001-v2.1) and the rule version identifier from TRS.

**Given** the image is pushed, **When** the registry confirms receipt, **Then** the image digest (SHA256) is captured and persisted against the rule version record in the TRS database.

**Given** the digest is stored, **When** the simulation orchestrator starts a run pinned to that rule version, **Then** it pulls the image by digest rather than by tag, guaranteeing bit-for-bit reproducibility.

**Given** the image build or push fails, **When** the failure is detected, **Then** the deployment is marked failed, no digest is stored, and the rule version is not made available for simulation.

**Given** a rule version is already deployed and its digest is stored, **When** a user attempts to re-deploy the same version, **Then** the system either skips the build and reuses the existing digest or explicitly re-validates that the registry image matches before proceeding.

## Assumptions

- The container registry (e.g. Docker Hub, ECR, or a self-hosted registry) is pre-configured and credentials are available to the deployment pipeline.
- Image tagging convention and registry URL are defined in system configuration, not hardcoded.
- The digest stored in TRS is the registry-returned digest post-push, not a locally computed one, to account for any registry-side transformation.

