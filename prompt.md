You are acting as a senior staff engineer and systems architect.

Your task is to thoroughly investigate the codebase and produce a detailed implementation planning document named:

`implementation-plan.md`

This is NOT an implementation task yet.

This is a deep architectural research + implementation planning task.

The final document must be exhaustive, actionable, repository-aware, and aligned with existing architectural conventions already present in the codebase.

---

# CRITICAL INSTRUCTIONS

Before doing anything else:

1. Read ALL PDF documents in the project root recursively.
2. Explore ALL THREE repositories completely before proposing any implementation.
3. Understand:

   * Existing frontend architecture
   * Existing backend architecture
   * Existing admin-service architecture
   * Repository conventions
   * DTO conventions
   * Controller/service/repository flow
   * Existing simulation/rule execution flow
   * Existing rule studio flows
   * Existing NATS utilities
   * Existing schema validation mechanisms
   * Existing payload handling
   * Existing DB design patterns
   * Existing pagination/filter/search conventions
   * Existing authentication/authorization patterns
   * Existing audit logging patterns
   * Existing API naming conventions
   * Existing error handling conventions
   * Existing frontend state management patterns
   * Existing frontend routing/navigation patterns
   * Existing table/list rendering patterns
   * Existing modal/wizard/form patterns
   * Existing validation conventions
   * Existing async job/background processing conventions
   * Existing max payload sizing conventions
   * Existing database migration conventions
   * Existing config management conventions

DO NOT invent architecture that conflicts with repository patterns unless absolutely necessary.

If deviations are necessary:

* explain why
* explain tradeoffs
* explain migration impact
* explain future extensibility impact

---

# FEATURE TO PLAN

We need to design and implement a new capability in Rule Studio:

# Synthetic Data Factory

This feature allows:

* `trs_editor`
* `trs_data_engineer`

to generate synthetic data for running simulations against rules.

This requires:

* frontend pages
* backend APIs
* admin-service APIs
* DB design
* validation flows
* storage architecture
* simulation bucket architecture
* future extensibility considerations

---

# HIGH LEVEL REQUIREMENT

Users should be able to:

1. Create synthetic data
2. Store it persistently
3. Reuse it later
4. Clone simulations
5. Edit simulations
6. Generate additional context-sim pairs later
7. Audit generated datasets
8. Associate synthetic datasets with rule versions
9. Run future simulations against those datasets

This system must be designed consciously for:

* stability
* scalability
* extensibility
* auditability
* future expansion

This is NOT a throwaway prototype.

---

# REQUIRED ARCHITECTURE FLOW

Follow existing repository conventions strictly.

Expected backend flow:

Frontend
→ Rule Studio Backend Controller
→ Service
→ Admin Service Client
→ Admin Service Controller
→ Admin Service Service
→ Repository
→ Database

Document exact classes/modules/files likely to be touched.

---

# FRONTEND REQUIREMENTS

We need a new page:

# Synthetic Data Factory

The page should behave similarly to how rules are currently listed in Rule Studio.

When loaded:

* show existing simulations
* allow:

  * view
  * edit
  * clone

There must also be:

* "Create New Simulation" button on top-right

The implementation plan must:

* identify existing reusable components
* identify existing list/table patterns
* identify existing form/wizard patterns
* identify routing additions required
* identify state management requirements
* identify API integration strategy
* identify validation strategy
* identify pagination/filter/search requirements
* identify permissions enforcement strategy

---

# CREATE NEW SIMULATION FLOW

When user clicks:
`Create New Simulation`

The user enters a multi-step flow/wizard.

---

# STEP 1 — RULE SELECTION

User optionally selects an existing rule.

If a rule is selected:

* fetch corresponding:

  * TXTP schema
  * sample payload

These already exist in:

* `tcs_config`
* via an existing API endpoint

You must:

* discover the existing endpoint
* document how it works
* document how it should be reused

---

# IMPORTANT — MULTIPLE TXTP SUPPORT

The architecture MUST support:

# Multiple TXTP per simulation

Even though:

* current unit testing flows generally only involve one rule
* a rule belongs to a typology
* typologies arrays in network maps are generally tied to separate TXTP schemas

We STILL need the architecture to support:

* multiple TXTP schemas
* multiple TXTP payload configurations
* multiple TXTP payload generations

inside BOTH:

* context data generation
* sim data generation

This means:

* a context-sim pair may contain multiple TXTP-generated payload groups
* validation must support multiple schemas
* UI must support multiple schema editors
* DB model must support multiple payload/schema references
* generation pipeline must support multi-schema generation
* future simulation execution must support multi-TXTP execution

The implementation plan MUST consciously design for this even if initial usage mostly involves single-TXTP simulations.

The implementation plan should explicitly discuss:

* whether TXTP should be grouped
* ordering concerns
* relationship modeling
* schema conflict handling
* payload grouping semantics
* validation sequencing
* future orchestration considerations

---

# IMPORTANT UX REQUIREMENT

DO NOT simply expose raw JSON editors.

We need an intelligent payload configuration UI.

For EACH field in the schema/sample payload, the user should be able to configure:

* Keep sample value
* Set explicit static/default value
* Set numeric range
* Set generated/randomized range
* Set null
* Potential future extensibility hooks

The implementation plan should propose:

* exact UX structure
* component hierarchy
* recursive nested field handling
* arrays handling
* deeply nested schema handling
* validation UX
* unsupported schema handling
* schema rendering strategy

---

# CONTEXT DATA GENERATION

The user then specifies:

How many messages to synthesize for:

* raw_history
* other DB context population requirements

This generated data is called:

# Context Data

Stored inside:

# Sim Bucket (Simulation Bucket)

Requirements:

* minimum count = 1
* maximum count = 300
* max should be configurable later
* identify where config should live

The generated data must:

* conform to TXTP schema
* be validated before generation
* reject malformed or insane payloads

Need:

* field-level limits
* payload-level limits
* safe generation strategy
* schema-aware generation
* DB-safe sizing
* API-safe sizing
* memory-safe sizing

Research existing validation libraries/utilities before proposing new ones.

---

# GENERATED DATA PREVIEW

After generation:

* show first generated payload to user
* allow validation/inspection
* ensure generated output matches expectations

The plan should specify:

* preview UX
* truncation strategy
* rendering strategy
* large payload handling

---

# SIM DATA GENERATION

After context data generation:

User generates:

# Sim Data

This is:

* actual payload data sent to rule processor
* through existing TRS + NATS utilities

This uses the SAME schema-driven generation system.

Requirements:

* same field configuration system
* same validation guarantees
* same limits strategy

But:

* max generation count = 150

---

# CONTEXT-SIM DATA PAIRS

IMPORTANT:

Each generated unit is a:

# Context-Sim Data Pair

Requirements:

* context data and sim data are generated together
* user cannot proceed with one missing
* mismatches are invalid
* validation required before continuing

A single pair may contain:

* multiple TXTP payload groups
* multiple schema references
* multiple generated payload collections

The plan must define:

* exact relational model
* lifecycle
* validation flow
* pairing guarantees
* transactional guarantees

---

# EDIT EXISTING SIMULATION FLOW

We MUST support editing existing simulations.

However:

# Existing context-sim pairs must NEVER be overwritten.

Editing a simulation means:

* re-opening simulation configuration
* generating NEW context-sim pairs
* appending them to the simulation bucket
* preserving historical pairs permanently

This flow should behave similarly to:

* create new simulation

BUT:

* without requiring rule selection again
* while preserving existing simulation metadata
* while preserving historical generations
* while preserving audit history

The implementation plan MUST define:

* append-only generation strategy
* immutable historical generation behavior
* versioning behavior
* lineage tracking
* clone/edit semantics
* audit semantics
* retrieval semantics
* UI flow differences between create vs edit
* DB impact
* API contracts
* concurrency considerations

---

# SIMULATION BUCKET DESIGN

We need a persistent storage concept:

# Simulation Bucket

This is extremely important.

You MUST deeply think through:

* data modeling
* retrieval
* scalability
* indexing
* retention
* auditability
* cloning
* versioning
* append-only generation behavior
* future simulation reuse

A Simulation Bucket may contain:

* many dozens
* potentially unbounded
* context-sim data pairs

Design carefully.

The implementation document MUST include:

* ERD-style explanations
* proposed tables/entities
* indexes
* partitioning considerations if necessary
* archival considerations
* future extensibility strategy

---

# SIMULATION BUCKET MUST STORE

At minimum:

* generated context data
* generated sim data
* rule association
* exact rule version
* generation timestamp
* payload used
* schema used
* TXTP references
* multi-TXTP relationships
* generator configuration
* generation metadata
* audit metadata
* creator identity
* clone lineage
* simulation metadata
* future extensibility hooks

Potentially:

* generation seed
* generation strategy version
* validation result metadata
* simulation execution metadata later

---

# IMPORTANT ARCHITECTURAL GOALS

The implementation plan MUST optimize for:

* long-term maintainability
* extensibility
* auditability
* reproducibility
* performance
* operational simplicity
* future simulation execution support
* future analytics support
* future replay support
* future AI-assisted generation support

---

# API DESIGN REQUIREMENTS

The implementation plan MUST provide:

* exact proposed endpoints
* request/response contracts
* DTO structures
* validation rules
* pagination contracts
* filtering contracts
* clone flow contracts
* edit flow contracts
* append-generation flow contracts
* preview generation contracts
* persistence contracts

Include:

* backend endpoints
* admin-service endpoints

Follow existing naming conventions.

---

# DATABASE REQUIREMENTS

You MUST:

* inspect existing DB conventions
* inspect migrations strategy
* inspect entity naming patterns
* inspect JSON/blob handling patterns
* inspect audit conventions

Then propose:

* exact tables
* columns
* relationships
* indexes
* constraints
* migration ordering
* retention strategy
* future-proofing considerations

---

# SECURITY REQUIREMENTS

Plan must cover:

* RBAC
* trs_editor permissions
* trs_data_engineer permissions
* payload abuse prevention
* oversized payload prevention
* malformed schema protection
* generation throttling
* API abuse protection

---

# PERFORMANCE REQUIREMENTS

Plan must discuss:

* payload size controls
* batching
* pagination
* lazy loading
* generation performance
* DB growth concerns
* future archival strategy
* background jobs if needed

---

# REQUIRED OUTPUT STRUCTURE

The generated `implementation-plan.md` should include:

1. Executive Summary
2. Existing Architecture Findings
3. Relevant Existing Systems
4. Repository-by-Repository Analysis
5. Current Rule Flow Analysis
6. Proposed Feature Architecture
7. Frontend Design
8. Backend Design
9. Admin-Service Design
10. API Contracts
11. Database Design
12. Simulation Bucket Design
13. Multi-TXTP Design Considerations
14. Context-Sim Pair Lifecycle
15. Edit Simulation Append-Only Strategy
16. Validation Strategy
17. Security Considerations
18. Performance Considerations
19. Scalability Considerations
20. Auditability Strategy
21. Future Extensibility
22. Migration Plan
23. Risks & Unknowns
24. Open Questions
25. Recommended Implementation Order
26. Estimated Complexity by Component
27. Suggested Test Strategy
28. Suggested Observability/Logging
29. Suggested Config Strategy
30. Suggested Rollout Strategy

---

# IMPORTANT FINAL REQUIREMENTS

The implementation plan must:

* be concrete
* repository-aware
* architecture-aware
* highly detailed
* implementation actionable

DO NOT produce vague suggestions.

DO:

* reference actual files/modules/classes discovered
* reference actual conventions discovered
* reference actual APIs discovered
* reference actual DB structures discovered

You are expected to deeply investigate the repositories before proposing solutions.

The resulting document should be detailed enough that multiple engineers can independently implement parts of the system consistently.
