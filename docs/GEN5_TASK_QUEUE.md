# Gen5 Task Queue

## Project Recap

Gen5 has completed the v0 market-data-layer closeout and the v0.1 Research Data Workbench queue through the corporate-actions metadata spike. The repository currently has an R-first, Alpaca-only, adjusted daily OHLCV data layer with explicit `as_of_timestamp` handling, deterministic cache planning and merge behavior, validation output, freeze evidence, and workbench handoff artifacts under ignored local run paths.

The completed v0.1 milestone still sits before WFA, PCA/state modeling, strategy research, exits, allocation, dashboard, execution, and live-order work. Those later modules remain out of scope. The workbench only makes adjusted daily data easier to query, inspect, chart, and hand off to later research.

A post-v0.1 minimal WFA contract plan now exists as documentation only. It defines the first WFA build boundary without implementing folds, indicators, returns, labels, regimes, strategy signals, exits, allocation, dashboard, execution, or live-order logic.

The visible behavior now available is practical: an operator can choose a small universe and date range, refresh or read the existing `data_cache/`, inspect severity-labeled data health, render a static candlestick PNG, and produce a canonical research input manifest that future WFA code can consume without calling Alpaca.

## Queue Rules

Codex may work this queue only within the Gen5 data-layer and research-plumbing scope defined in `AGENTS.md` and `docs/GEN5_V0_1_RESEARCH_DATA_WORKBENCH.md`.

For each task, Codex should:

- read the relevant files before editing;
- keep changes scoped to the task;
- avoid WFA, PCA, strategy, exit, allocation, dashboard, execution, and live-order logic;
- preserve explicit `as_of_timestamp` and bounded-request invariants;
- run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` when code, validation behavior, operator commands, or data-layer documentation meaningfully changes;
- commit completed work with a clear message;
- push only when authorized for the current run;
- update this queue when task status changes.

Codex must stop and ask before:

- adding package dependencies;
- changing provider scope beyond Alpaca adjusted daily OHLCV;
- making destructive file operations;
- changing live-facing behavior beyond advice-only market-data-layer outputs;
- starting WFA, PCA, strategy, exit, allocation, dashboard, execution, or order-routing work;
- resolving ambiguous project decisions by assumption.

## Status Legend

- `done`: completed, validated when warranted, and committed.
- `pending`: ready to be picked up.
- `blocked`: requires operator input or an external condition.
- `deferred`: intentionally later than the current milestone slice.

## Completed Setup

### 1. Document Codex autonomy and freeze-evidence operator guidance

Status: done

Branch: `codex/gen5-v0-data-layer-closeout`

Commit: `89e8a9f docs: clarify Gen5 v0 data-layer freeze guidance`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added a bounded Codex autonomy policy to `AGENTS.md`.
- Clarified README validation commands and freeze-evidence scope.
- Clarified covered-range versus stale-tail freeze evidence interpretation.

## Recommended Next Six

These are the recommended first six pending tasks for a one-thread autonomous run. They stay inside the Gen5 v0 market-data-layer milestone and build toward a clean data-layer closeout.

### 2. Review generated artifact ignore coverage

Status: done

Branch: `codex/gen5-v0-market-data-queue-pass-1`

Commit: `test: expand generated artifact ignore coverage`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Confirmed targeted ignore coverage for local caches, run artifacts, validation outputs, local config overlays, credential files, repo-local R libraries, and heavyweight data formats.
- Expanded the non-network ignore test and added a concise README note for generated local files.

Goal: Confirm caches, run artifacts, validation outputs, local config, local R libraries, and other heavy or machine-local files stay out of git.

Likely files:

- `.gitignore`
- `README.md`
- `docs/GEN5_V0_DATA_LAYER_FREEZE_EVIDENCE.md`
- `tests/testthat/test_generated_artifact_ignores.R`

Validation:

- Inspect `git status --ignored` or targeted ignore checks.
- Run the local test wrapper if ignore tests or documentation guidance changes.

Stop conditions:

- Any deletion of generated artifacts.
- Any need to move real cache data or secrets.

### 3. Tighten operator setup guidance

Status: done

Branch: `codex/gen5-v0-market-data-queue-pass-1`

Commit: `docs: add Gen5 v0 operator runbook`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added a dedicated v0 operator runbook covering local config overlays, credentials, cache root placement, repo-local R libraries, validation order, and live Alpaca refresh smoke order.
- Clarified that credentials belong in environment variables or ignored `.Renviron`, not YAML.

Goal: Make the local setup path obvious for a human operator: config overlay, credentials, local cache root, `.codex_r_libs/`, validation wrapper, and live refresh order.

Likely files:

- `README.md`
- `config/data_layer.example.yml`
- possibly a new `docs/GEN5_V0_OPERATOR_RUNBOOK.md`

Validation:

- Run the local test wrapper if command examples or config assumptions change.

Stop conditions:

- Any request to store credentials in source files.
- Any change to provider behavior or config schema beyond documentation.

### 4. Review data-layer validation PASS/SKIP interpretation

Status: done

Branch: `codex/gen5-v0-market-data-queue-pass-1`

Commit: `docs: clarify validation skip semantics`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Clarified that PASS covers non-network data-layer contract checks only.
- Clarified that `SKIP live Alpaca fetch smoke` means validation did not exercise a network fetch, even when credentials and runtime packages are present.

Goal: Ensure operators understand that non-network validation can pass while live Alpaca fetch remains a deliberate SKIP, and that the live smoke is a separate credentialed check.

Likely files:

- `README.md`
- `docs/GEN5_V0_DATA_LAYER_FREEZE_EVIDENCE.md`
- `scripts/validate/validate_data_layer.R` only if output text is materially misleading

Validation:

- Run the local test wrapper if validation script text changes.

Stop conditions:

- Any change that turns the validation script into a network test.
- Any change that hides stale, partial-history, empty-symbol, or no-returned-bars warnings.

### 5. Normalize cache and audit terminology

Status: done

Branch: `codex/gen5-v0-market-data-queue-pass-1`

Commit: `test: cover cache terminology labels`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added operator-facing terminology references for refresh decisions, `no_returned_bars`, `covers_requested_range`, and `stale`.
- Expanded cache planner tests to cover all six `refresh_decision` labels without changing cache-planning semantics.

Goal: Make terms consistent across README, freeze evidence, validation output, and tests: `fully_cached`, `stale_cache`, `partial_history`, `partial_history_stale`, `cold_cache`, `cold_cache_empty_file`, `no_returned_bars`, `stale`, and `covers_requested_range`.

Likely files:

- `README.md`
- `docs/GEN5_V0_DATA_LAYER_FREEZE_EVIDENCE.md`
- `R/`
- `tests/testthat/`

Validation:

- Run the local test wrapper if code or tests change.

Stop conditions:

- Any semantic change to cache planning without explicit review.
- Any terminology change that would invalidate existing freeze evidence.

### 6. Review provider-boundary documentation

Status: done

Branch: `codex/gen5-v0-market-data-queue-pass-1`

Commit: `docs: clarify Alpaca provider boundary`

Validation: Documentation-only diff check.

Notes:

- Clarified that Alpaca credentials, request construction, feed selection, pagination, response parsing, and provider errors stay inside `R/alpaca_provider.R`.
- Reiterated that downstream modules should consume canonical bars and cache/audit artifacts, not Alpaca response shapes or provider quirks.

Goal: Confirm Alpaca-specific behavior is documented as provider-contained and that downstream research modules are not asked to know provider quirks.

Likely files:

- `docs/adr/ADR-004-r-first-provider-boundary.md`
- `docs/GEN5_SYSTEM_DESIGN.md`
- `README.md`
- provider files under `R/`

Validation:

- Documentation-only diff check unless code comments or provider behavior change.

Stop conditions:

- Any addition of a second provider.
- Any broad provider abstraction that is not needed for Gen5 v0.

### 7. Review ADR consistency against current v0 freeze

Status: done

Branch: `codex/gen5-v0-market-data-queue-pass-1`

Commit: `docs: align ADR scope with v0 freeze`

Validation: Documentation-only diff check.

Notes:

- Clarified that system-design current decisions are architectural constraints and build-order direction, not implementation status.
- Clarified ADR-003 as a later live-advisor decision that does not make v0 a live runner.

Goal: Ensure ADRs, system design, README, and freeze evidence agree on current scope and do not imply completed downstream modules.

Likely files:

- `docs/adr/ADR-001-data-layer-first.md`
- `docs/adr/ADR-002-daily-adjusted-bars-only.md`
- `docs/adr/ADR-003-advice-only-live-runner.md`
- `docs/adr/ADR-004-r-first-provider-boundary.md`
- `docs/GEN5_SYSTEM_DESIGN.md`
- `README.md`

Validation:

- Documentation-only diff check unless operator commands change.

Stop conditions:

- Any decision that changes build order or authorizes downstream modules.

## Additional Pending Tasks

### 8. Prepare Gen5 v0 data-layer closeout checklist

Status: done

Branch: `codex/gen5-v0-closeout-checklist-pass-1`

Commit: `docs: add Gen5 v0 closeout checklist`

Validation: Documentation-only diff check.

Notes:

- Added `docs/GEN5_V0_DATA_LAYER_CLOSEOUT_CHECKLIST.md` defining data-layer-only closeout gates.
- Kept the checklist limited to Alpaca adjusted daily OHLCV ingestion, explicit timestamp/date handling, deterministic cache/audit behavior, ignored artifacts, operator docs, validation, and bounded live smoke evidence.
- Added README/runbook/freeze-evidence cross-links without authorizing downstream modules.

Goal: Define what "data layer stable enough to move on" means without starting WFA or strategy work.

Likely files:

- new `docs/GEN5_V0_DATA_LAYER_CLOSEOUT_CHECKLIST.md`
- `docs/GEN5_TASK_QUEUE.md`

Validation:

- Documentation-only diff check.

Stop conditions:

- Any checklist item that requires implementing downstream modules.

### 9. Review test coverage map for data-layer invariants

Status: done

Branch: `codex/gen5-v0-closeout-checklist-pass-1`

Commit: `docs: add Gen5 v0 closeout checklist`

Validation: Documentation-only diff check; no tests changed.

Notes:

- Mapped current smoke, validation, and non-network `testthat` coverage to the Gen5 v0 data-layer invariants in the closeout checklist.
- Identified live Alpaca connectivity and date-specific evidence snapshots as operator-reviewed closeout items rather than default network tests.

Goal: Map current non-network tests to Gen5 v0 invariants and identify data-layer-only gaps.

Likely files:

- `tests/testthat/`
- `docs/GEN5_V0_DATA_LAYER_CLOSEOUT_CHECKLIST.md`
- `docs/GEN5_TASK_QUEUE.md`

Validation:

- Run the local test wrapper if tests change.

Stop conditions:

- Any test requiring live network access by default.

### 10. Review local cache path ergonomics

Status: done

Branch: `codex/gen5-v0-closeout-checklist-pass-1`

Commit: `docs: add Gen5 v0 closeout checklist`

Validation: Documentation-only diff check; no config loading behavior changed.

Notes:

- Confirmed `config/data_layer.example.yml` recommends an outside-OneDrive cache root.
- Confirmed ignored `config/data_layer.local.yml` and `GEN5_CACHE_ROOT` are documented operator override paths.
- Clarified in the operator runbook that the repo does not migrate or delete existing caches.

Goal: Confirm local cache configuration supports storage outside OneDrive when configured and that operator docs explain the expected behavior.

Likely files:

- `config/data_layer.example.yml`
- `README.md`
- `docs/GEN5_V0_OPERATOR_RUNBOOK.md` if created

Validation:

- Run the local test wrapper if config loading behavior changes.

Stop conditions:

- Any automatic migration or deletion of existing cache files.

### 11. Review freeze evidence reproducibility notes

Status: done

Branch: `codex/gen5-v0-closeout-checklist-pass-1`

Commit: `docs: add Gen5 v0 closeout checklist`

Validation: Documentation-only diff check.

Notes:

- Clarified that comparable evidence should be regenerated with explicit `GEN5_AS_OF_TIMESTAMP`, `GEN5_FETCH_START_DATE`, and `GEN5_FETCH_END_DATE`.
- Reiterated that generated evidence artifacts remain ignored and only closeout interpretation belongs in source-controlled documentation.

Goal: Clarify how a future operator should regenerate comparable freeze evidence with explicit timestamps and bounded dates.

Likely files:

- `docs/GEN5_V0_DATA_LAYER_FREEZE_EVIDENCE.md`
- `docs/GEN5_V0_OPERATOR_RUNBOOK.md` if created

Validation:

- Documentation-only diff check unless scripts change.

Stop conditions:

- Any instruction to commit generated run artifacts.

## Suggested Closeout Confirmation Prompt

Use this prompt in a fresh task only after the operator has run any credentialed closeout checks they want to refresh:

```text
Perform a final no-code Gen5 v0 market-data-layer closeout confirmation.

Stay within AGENTS.md and Gen5 v0 market-data-layer scope. Confirm the closeout checklist, freeze evidence, operator runbook, README, task queue, and ignore coverage still agree after the operator refreshes any credentialed Alpaca smoke evidence. Do not add WFA, strategy, allocation, dashboard, execution, or live-order logic.

Stop if validation fails, generated artifacts appear as tracked files, the task requires WFA/strategy/allocation/dashboard/execution logic, a new dependency, destructive file operations, live-order behavior, provider expansion beyond Alpaca adjusted daily OHLCV, or an ambiguous project decision.
```

## Completed Milestone Queue: Gen5 v0.1 Research Data Workbench

Planning spec: `docs/GEN5_V0_1_RESEARCH_DATA_WORKBENCH.md`

Initial recommended branch for the first implementation chunk: `codex/gen5-v0-1-research-data-workbench`

These tasks were completed sequentially after the operator confirmed the v0 closeout. They remain research-plumbing tasks only. They do not authorize WFA, strategy, allocation, dashboard, execution, live-order logic, or provider expansion beyond Alpaca.

### 12. Align cache guidance around repo-local `data_cache/`

Status: done

Branch: `codex/gen5-v0-1-workbench-foundation`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Updated the default cache root to ignored repo-local `data_cache/alpaca_daily_adjusted/`.
- Clarified README/runbook guidance that outside-OneDrive cache roots remain optional operator overrides.
- Added relative cache-root resolution under the repository root; no cache migration, deletion, or artifact tracking was added.

Goal: Make operator docs and config comments agree that `data_cache/` is the simple default working cache for now, while outside-OneDrive cache roots remain an optional future optimization.

Likely files:

- `README.md`
- `docs/GEN5_V0_OPERATOR_RUNBOOK.md`
- `config/data_layer.example.yml`
- possibly `docs/GEN5_V0_1_RESEARCH_DATA_WORKBENCH.md`

Validation:

- Documentation/config diff review.
- Run the local test wrapper if config loading behavior changes.

Stop conditions:

- Any automatic migration, deletion, or rewriting of existing cache files.
- Any change that causes generated cache artifacts to be tracked by git.

### 13. Add manual universe registry scaffold

Status: done

Branch: `codex/gen5-v0-1-workbench-foundation`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added `config/universe_registry.csv` with manual `candidate_universe`, `research_universe`, and `context_universe` rows for the v0.1 POC symbols.
- Added registry validation/helpers with `live_basket` as an allowed later label but no selected live symbols.
- Added non-network tests for role validation, duplicate detection, and symbol resolution.

Goal: Represent manually curated universes with role labels for `candidate_universe`, `research_universe`, `context_universe`, and later `live_basket`, starting with the v0.1 growth/meme POC symbols.

Likely files:

- new config or data file under `config/` for source-controlled universe definitions
- `README.md`
- `docs/GEN5_V0_1_RESEARCH_DATA_WORKBENCH.md`
- tests under `tests/testthat/` if a parser/validator is added

Validation:

- Non-network validation for required fields, duplicate symbols, invalid roles, inverse/leveraged ETF exclusions if encoded.
- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` if code or tests change.

Stop conditions:

- Rule-based universe selection logic.
- Survivorship-bias modeling.
- Live basket selection logic beyond labels/placeholders.

### 14. Promote shared latest-complete-session helper for workbench use

Status: done

Branch: `codex/gen5-v0-1-workbench-foundation`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added the workbench query path with explicit `GEN5_AS_OF_TIMESTAMP` requirement.
- Workbench session resolution uses `g5_resolve_latest_completed_session()` and bounded date handling uses the existing Alpaca daily date-range helper.
- No `Sys.Date()` or live market-clock dependency was added.

Goal: Ensure refresh, query, validation, and chart paths all use one explicit `as_of_timestamp` session resolver and do not independently infer latest market sessions.

Likely files:

- `R/calendar.R`
- scripts under `scripts/validate/` or a new workbench script path
- `tests/testthat/test_calendar_resolution.R`
- operator docs

Validation:

- Non-network tests covering after-close, before-close, weekend/holiday, and future-request clipping behavior.
- Run the local test wrapper.

Stop conditions:

- Any analytical helper calling `Sys.Date()` or silently using runtime date authority.
- Any reliance on live market-clock APIs for default validation.

### 15. Add small-basket research query wrapper

Status: done

Branch: `codex/gen5-v0-1-workbench-foundation`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added `R/workbench_query.R` and `scripts/query_research_data.R`.
- The query wrapper reads explicit symbol baskets or universe-role selections, uses existing cache planning/read/write helpers, and only refreshes from Alpaca when explicitly requested.
- Query artifacts include canonical adjusted daily bars, manifest, audit, symbol coverage, refresh plan, and health CSVs under ignored `runs/research_workbench/`.

Goal: Provide an operator-facing query path for a universe or symbol basket plus date range, returning canonical adjusted daily bars and a manifest from the existing cache/provider plumbing.

Likely files:

- new script under `scripts/`
- possible helper under `R/`
- `README.md`
- tests under `tests/testthat/`

Validation:

- Non-network tests using local fixture/cache behavior.
- Run the local test wrapper.

Stop conditions:

- WFA fold generation.
- indicators, returns, labels, regimes, features, or strategy events.
- direct Alpaca calls outside provider/data-layer boundaries.

### 16. Add severity-labeled data health report

Status: done

Branch: `codex/gen5-v0-1-workbench-foundation`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added severity-labeled health helpers in `R/data_audit.R`.
- Validation and query runs now write durable health CSVs with `ERROR`, `WARN`, and `INFO` rows.
- Non-network tests cover duplicate-row errors plus clipped-future, empty, partial, stale/cache-warning, and info classifications.

Goal: Produce console plus CSV or Markdown health output for query/validation runs, with `ERROR`, `WARN`, and `INFO` severities for missing, stale, partial, empty, duplicate, and clipped-future conditions.

Likely files:

- `R/data_audit.R`
- validation/query scripts
- `README.md`
- `tests/testthat/test_data_audit.R`

Validation:

- Non-network tests for severity classification.
- Run the local test wrapper.

Stop conditions:

- Hiding or downgrading hard data-contract failures.
- Turning default validation into a network test.

### 17. Add static candlestick PNG inspection script

Status: done

Branch: `codex/gen5-v0-1-workbench-foundation`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added a separate base-R static candlestick inspection helper for canonical adjusted daily bars.
- Added `scripts/inspect/render_candlestick_png.R` to query one symbol through the existing workbench cache/provider helpers and write a PNG under ignored `runs/research_workbench/`.
- Added non-network tests for PNG rendering and canonical adjusted-bar enforcement.

Goal: Render a basic static candlestick PNG for one symbol/date range from canonical bars, separate from the core pipeline.

Likely files:

- new script under `scripts/validate/` or `scripts/inspect/`
- possible plotting helper under `R/`
- `README.md`
- generated output under ignored `runs/`

Validation:

- Non-network smoke using cached or fixture bars.
- Confirm generated PNG path is under ignored output.
- Run the local test wrapper if code or tests change.

Stop conditions:

- Adding package dependencies without operator approval.
- Creating a dashboard or broad plotting suite.
- Embedding chart generation into the core refresh path.

### 18. Add opt-in Alpaca credential preflight

Status: done

Branch: `codex/gen5-v0-1-workbench-closeout`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added `scripts/preflight_alpaca_credentials.R` as an explicit no-network credential readiness check.
- Added provider helpers that reject missing or placeholder-like credentials without printing credential values.
- Added non-network tests for placeholder detection, runtime package readiness reporting, and skipped network probing.

Goal: Give the operator a clear way to confirm credential presence and basic credentialed readiness without making default tests depend on network access.

Likely files:

- provider/config helpers under `R/`
- script under `scripts/`
- operator docs
- tests for non-secret environment handling

Validation:

- Non-network tests for missing/placeholder credentials.
- Optional operator-run credentialed smoke.
- Run the local test wrapper if code or tests change.

Stop conditions:

- Storing credentials in YAML or source-controlled files.
- Printing secrets.
- Making default validation require credentials or network.

### 19. Define research handoff manifest and gate checklist

Status: done

Branch: `codex/gen5-v0-1-workbench-closeout`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added `docs/GEN5_V0_1_RESEARCH_HANDOFF_CHECKLIST.md`.
- Defined the future WFA consumer rule: consume workbench handoff artifacts, do not call Alpaca directly, and do not infer latest sessions.
- Documented manifest fields, bar-contract gates, health-review gates, and cash/no-position plus buy-and-hold as reserved later baseline concepts only.

Goal: Create the source-controlled contract and checklist that future WFA code must consume, including no direct Alpaca calls, explicit as-of timestamp, universe metadata, data-health status, and baseline concepts.

Likely files:

- new checklist doc under `docs/`
- `docs/GEN5_V0_1_RESEARCH_DATA_WORKBENCH.md`
- `docs/GEN5_SYSTEM_DESIGN.md`
- `README.md`

Validation:

- Documentation-only diff review unless code changes.

Stop conditions:

- Implementing WFA or strategy evaluation.
- Treating cash/no-position or buy-and-hold baselines as implemented performance logic.

### 20. Corporate-actions metadata spike

Status: done

Branch: `codex/gen5-v0-1-corporate-actions-spike`

Validation: Documentation-only diff review.

Notes:

- Reviewed Alpaca corporate-actions metadata after the Research Data Workbench closeout.
- Decision: corporate-actions metadata may belong in later Gen5 data-layer scope only as an explicitly authorized Alpaca sidecar, not as part of the canonical adjusted daily bar table and not as a v0.1 research signal.
- If later authorized, caching should use explicit `as_of_timestamp`, `start`, and `end` inputs, keep provider quirks inside the Alpaca provider boundary, store snapshots separately from adjusted bars under ignored cache paths, and audit request scope, pagination, row counts, query timestamp, provider/action filters, and deterministic hashes.
- Key risks are lookahead from late-arriving/restated events, accidental double-adjustment of already adjusted bars, symbol identity drift, cache invalidation complexity, and premature use as labels or signals before WFA authority exists.

Goal: After the core workbench is stable, decide whether Alpaca corporate-actions metadata belongs in Gen5 data-layer scope and how it should be cached/audited.

Notes:

- Alpaca supports corporate actions such as splits, dividends, mergers, spin-offs, name changes, and reorganizations.
- A structured earnings calendar or earnings-surprise feed is not part of the v0.1 plan.

Stop conditions:

- Starting this without explicit operator authorization.
- Mixing corporate actions into canonical adjusted daily bars before the bar workbench is stable.
- Adding a non-Alpaca provider for earnings data without a separate scope decision.

### 21. Confirm Gen5 v0.1 Research Data Workbench closeout alignment

Status: done

Branch: `codex/gen5-v0-1-closeout-confirmation`

Validation: Documentation-only diff review.

Notes:

- Confirmed README, operator runbook, workbench spec, research handoff checklist, system design, task queue, and ignore guidance agree after the corporate-actions metadata spike.
- Updated README and this queue so v0.1 is described as closed out through the corporate-actions spike rather than only as the next planned milestone.
- Reconfirmed that future research remains gated by the handoff contract and that WFA, indicators, returns, labels, regimes, strategy signals, allocation, dashboards, execution, live-order logic, corporate-actions ingestion, earnings-data integration, and provider expansion remain out of scope.

Goal: Confirm the completed v0.1 workbench documentation is aligned before any later research milestone starts consuming handoff artifacts.

Likely files:

- `README.md`
- `docs/GEN5_TASK_QUEUE.md`
- `docs/GEN5_V0_OPERATOR_RUNBOOK.md`
- `docs/GEN5_V0_1_RESEARCH_DATA_WORKBENCH.md`
- `docs/GEN5_V0_1_RESEARCH_HANDOFF_CHECKLIST.md`
- `docs/GEN5_SYSTEM_DESIGN.md`
- `.gitignore`

Validation:

- Documentation-only diff review unless code, config, validation behavior, or operator commands change.

Stop conditions:

- Implementing WFA, indicators, returns, labels, regimes, strategy signals, allocation, dashboards, execution, live-order logic, corporate-actions ingestion, earnings-data integration, or provider expansion.
- Changing cache or generated artifact behavior.

## Planning Task After v0.1 Closeout

### 22. Define minimal WFA contract plan

Status: done

Branch: `codex/gen5-minimal-wfa-contract-planning`

Validation: Documentation-only diff review.

Notes:

- Added `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md` as the first WFA planning boundary after the Research Data Workbench.
- Defined allowed workbench handoff inputs, fold geometry requirements, TRAIN/OOS separation, no-leakage rules, fold-local fit/apply requirements for later learned components, reserved cash/no-position and buy-and-hold baselines, minimal audit outputs, and frozen decision evidence.
- Captured operator intent that WFA is the time-machine methodology for research decisions and frozen quarterly decision packs, with fold consistency as the first selection priority and 25% drawdown as a warning threshold.
- Reconfirmed that this slice does not implement WFA, indicators, returns, labels, regimes, PCA, HMMs, strategy signals, exits, allocation, dashboards, execution, live-order logic, provider expansion, corporate-actions ingestion, or earnings-data integration.

Goal: Define the first minimal WFA milestone contract and build order before implementation begins.

Likely files:

- `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`
- `README.md`
- `docs/GEN5_SYSTEM_DESIGN.md`
- `docs/GEN5_TASK_QUEUE.md`
- `docs/GEN5_V0_1_RESEARCH_DATA_WORKBENCH.md`
- `docs/GEN5_V0_1_RESEARCH_HANDOFF_CHECKLIST.md`

Validation:

- Documentation-only diff review unless code, config, validation behavior, or operator commands change.

Stop conditions:

- Implementing WFA, indicators, returns, labels, regimes, strategy signals, allocation, dashboards, execution, live-order logic, corporate-actions ingestion, earnings-data integration, or provider expansion.
- Changing the workbench handoff contract in a way that requires code changes.

## Recommended Next Queue: Minimal WFA Foundation

These tasks are intended to be handed off one chunk at a time after the minimal WFA contract plan is accepted. They start building WFA infrastructure without adding indicators, returns, labels, regimes, strategy signals, exits, allocation, dashboards, execution, or live-order logic.

### 23. Add WFA handoff reader and gate

Status: done

Recommended branch: `codex/gen5-wfa-handoff-gate`

Branch: `codex/gen5-wfa-handoff-gate`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added `R/wfa_handoff_gate.R` as the first Minimal WFA Foundation code slice.
- The gate reads a completed Research Data Workbench manifest and only its linked canonical bars, audit, symbol coverage, health, refresh plan, and optional merge summary artifacts.
- It rejects missing artifacts, missing required columns, duplicate `symbol` plus `session_date` rows, bars after `latest_completed_session`, inconsistent timestamp/session evidence, non-Alpaca/non-adjusted/non-1D bars, and `ERROR` health.
- `WARN` health rows return `REVIEW_REQUIRED` with the warning rows preserved for operator review rather than silently repairing or fetching data.
- No folds, indicators, returns, labels, regimes, PCA, HMMs, strategy signals, exits, allocation, dashboard, execution, live-order logic, provider expansion, corporate-actions ingestion, earnings-data integration, Alpaca credentials, `.Renviron`, network calls, `Sys.Date()`, or direct cache authority were added.

Goal: Validate a completed Research Data Workbench handoff before future WFA folds consume it.

Likely files:

- new helper under `R/` for WFA handoff loading/gating
- focused tests under `tests/testthat/`
- docs updates to `README.md`, `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`, or this queue only if operator-facing behavior changes

Required behavior:

- Read a workbench manifest and its linked canonical bars, health rows, audit, symbol coverage, refresh plan, and optional merge summary.
- Confirm explicit `as_of_timestamp` and `latest_completed_session` consistency across the handoff artifacts.
- Confirm no bar rows occur after `latest_completed_session`.
- Confirm required adjusted daily Alpaca bar schema, `adjusted == TRUE`, `timeframe == "1D"`, and `provider == "alpaca"`.
- Fail loudly on duplicate `symbol` plus `session_date` rows, missing required columns, missing required artifacts, or `health_max_severity == "ERROR"`.
- Surface `WARN` health rows as review-required evidence without silently repairing or fetching data.
- Avoid provider/network dependencies, Alpaca credentials, `.Renviron`, `Sys.Date()`, or direct cache authority outside the manifest.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1`.

Stop conditions:

- Direct Alpaca calls or provider-helper calls from WFA code.
- Any attempt to infer latest sessions independently.
- Implementing folds, indicators, returns, labels, regimes, strategy signals, exits, allocation, dashboards, execution, live-order logic, corporate-actions ingestion, earnings-data integration, or provider expansion.

### 24. Add quarterly fold geometry manifest builder

Status: done

Recommended branch: `codex/gen5-wfa-quarterly-fold-geometry`

Branch: `codex/gen5-wfa-quarterly-fold-geometry`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added `R/wfa_fold_geometry.R` as the quarterly fold geometry manifest builder for the Minimal WFA Foundation.
- The builder consumes a WFA handoff gate result plus explicit geometry inputs only, requires `REVIEW_REQUIRED` handoffs to be explicitly accepted, and emits TRAIN/OOS date records with quarterly decision cadence, decision-pack validity dates, source handoff reference, source `as_of_timestamp`, and source `latest_completed_session`.
- The first geometry is a single explicit expanding-TRAIN/calendar-quarter-OOS geometry, with final OOS bounded by `latest_completed_session`, explicit no-gap or intentional calendar-day gap policy, and `geometry_search_policy == "none_single_explicit_quarterly_geometry"`.
- Added focused non-network tests for valid quarterly folds, intentional gap recording, review-required acceptance, invalid dates, invalid gate status, and latest-completed-session bounds.
- No indicators, returns, labels, regimes, PCA, HMMs, strategy signals, exits, allocation, dashboard, execution, live-order logic, provider expansion, corporate-actions ingestion, earnings-data integration, provider calls, cache authority, or `Sys.Date()` use were added.

Goal: Create explicit quarterly TRAIN/OOS fold manifests from an accepted handoff without computing research features or performance.

Likely files:

- WFA fold-geometry helper under `R/`
- focused non-network tests under `tests/testthat/`
- documentation updates for generated fold-manifest fields

Required behavior:

- Consume only an accepted WFA handoff gate result and explicit geometry inputs.
- Emit fold records with `fold_id`, TRAIN dates, OOS dates, decision cadence, decision-pack validity dates, source handoff reference, `as_of_timestamp`, and `latest_completed_session`.
- Use quarterly OOS periods for the first geometry.
- Ensure TRAIN and OOS windows are date-valid, ordered, disjoint, and bounded by `latest_completed_session`.
- Record any intentional gap policy explicitly.
- Avoid searching across multiple geometries in this first slice.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1`.

Stop conditions:

- Any feature, return, label, regime, strategy, exit, allocation, or live-order logic.
- Any `Sys.Date()` or market-clock API use.
- Any direct provider/cache authority outside the accepted handoff.

### 25. Add TRAIN/OOS split verifier and fold-local availability audit

Status: done

Recommended branch: `codex/gen5-wfa-train-oos-split-audit`

Branch: `codex/gen5-wfa-train-oos-split-audit`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added `R/wfa_train_oos_split_audit.R` as the TRAIN/OOS split verifier and fold-local availability audit helper for the Minimal WFA Foundation.
- The helper consumes an accepted WFA handoff gate result, canonical handoff bars, source symbol coverage and health context, and the explicit quarterly fold geometry manifest.
- It returns `train_rows`, `oos_rows`, `split_summary`, `symbol_availability`, preserved warning rows, and a leakage attestation; fold membership is assigned by explicit fold dates only.
- Fold-local symbol availability records every source handoff symbol, including missing, partial, stale, and warning context, without filtering symbols based on OOS performance.
- Added focused non-network tests for disjoint TRAIN/OOS splits, OOS bounds, warning/context preservation, fake outcome-column immunity, review acceptance, and invalid fold bounds.
- No indicators, returns, labels, regimes, PCA, HMMs, strategy signals, exits, allocation, dashboard, execution, live-order logic, provider expansion, corporate-actions ingestion, earnings-data integration, provider calls, cache authority, or `Sys.Date()` use were added.

Goal: Prove that accepted handoff bars can be partitioned by the quarterly fold manifest without leakage.

Likely files:

- WFA split/audit helper under `R/`
- generated-artifact schema documentation
- focused tests under `tests/testthat/`

Required behavior:

- Partition bars into TRAIN and OOS rows for each fold using only explicit fold dates.
- Verify TRAIN and OOS rows are disjoint for every fold.
- Verify OOS rows occur strictly after TRAIN rows and never after `latest_completed_session`.
- Produce fold-local symbol availability evidence without filtering symbols based on OOS performance.
- Preserve missing, partial, stale, and warning context from the source handoff rather than repairing data.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1`.

Stop conditions:

- Computing indicators, returns, labels, regimes, strategy signals, drawdowns, allocation, or performance metrics.
- Any OOS-informed symbol eligibility decision.
- Any provider/network dependency.

### 26. Add frozen fold-decision evidence scaffolding

Status: done

Recommended branch: `codex/gen5-wfa-frozen-evidence-scaffold`

Branch: `codex/gen5-wfa-frozen-evidence-and-baseline-scaffold`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added `R/wfa_frozen_fold_evidence.R` as the frozen fold-decision evidence scaffold for the Minimal WFA Foundation.
- The helper consumes an accepted WFA handoff gate result, explicit quarterly fold geometry, TRAIN/OOS split audit outputs, accepted source warnings, and local git/code metadata when available.
- It emits one fold-level evidence row with source handoff, gate/review status, fold dates, TRAIN rows available, warning context, leakage attestations, and explicit no-active-decision status.
- Generated evidence CSV writing is constrained to ignored `runs/` paths by default.
- No OOS performance, indicators, returns, labels, regimes, PCA, HMMs, strategy signals, exits, allocation, dashboards, execution, live-order logic, provider expansion, corporate-actions ingestion, earnings-data integration, provider calls, cache authority, or `Sys.Date()` use were added.

Goal: Define and write the minimal frozen evidence structure for each fold before any active strategy candidate exists.

Likely files:

- WFA evidence helper under `R/`
- generated-artifact schema documentation
- focused tests under `tests/testthat/`

Required behavior:

- Write a fold-level evidence artifact that links source handoff, gate result, fold geometry, TRAIN rows available, accepted warnings, and code revision when available.
- Record that no active candidate, feature model, or strategy selector has been fit yet.
- Include leakage attestation fields for no provider calls, no latest-session inference, and no OOS fitting.
- Keep artifacts under ignored run paths when generated by scripts.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1`.

Stop conditions:

- Implementing strategy decisions, returns, labels, regimes, exits, allocation, or performance claims.
- Writing generated evidence into source control.

### 27. Add baseline-family registry scaffolding

Status: done

Recommended branch: `codex/gen5-wfa-baseline-registry-scaffold`

Branch: `codex/gen5-wfa-frozen-evidence-and-baseline-scaffold`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added `R/wfa_baseline_registry.R` as a declarative baseline-family registry scaffold.
- Reserved `no_trade_cash`, `broad_market_buy_hold`, `per_asset_buy_hold`, `fixed_equal_weight_basket_buy_hold`, and `active_curation_no_timing` families.
- Grouped baseline families by research question and diagnostic group so later summaries can stay organized.
- Tied baseline definitions to the same accepted handoff gate, explicit quarterly fold calendar, frozen fold evidence, health gate, TRAIN/OOS audit, and ignored `runs/` artifact discipline as later active candidates.
- No baseline returns, benchmark performance, asset selection from OOS evidence, allocation, strategy evaluation, live-facing advice, dashboards, execution, provider expansion, corporate-actions ingestion, earnings-data integration, provider calls, cache authority, or `Sys.Date()` use were added.

Goal: Represent baseline concepts before active strategy evaluation so `no_trade` and buy-and-hold comparisons stay first-class.

Likely files:

- baseline registry helper or config under WFA/research scope
- tests under `tests/testthat/`
- documentation updates describing baseline families

Required behavior:

- Register baseline families for `no_trade`/cash, broad-market buy-and-hold, per-asset buy-and-hold, fixed equal-weight basket buy-and-hold, and active curation without additional entry/exit timing.
- Group baselines by research question so top-level diagnostics do not become cluttered.
- Keep baseline definitions tied to the same fold calendar, handoff artifacts, health gates, and audit discipline as active candidates.
- Do not compute baseline returns or benchmark performance in this slice.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1`.

Stop conditions:

- Implementing returns, performance metrics, leverage reports, allocation, strategy evaluation, or live-facing advice.

### 28. Add first minimal WFA foundation closeout check

Status: done

Recommended branch: `codex/gen5-wfa-foundation-closeout`

Branch: `codex/gen5-wfa-foundation-closeout`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added `tests/testthat/test_wfa_foundation_closeout.R` as the first Minimal WFA Foundation closeout guard.
- Confirmed the accepted handoff gate result, explicit quarterly fold geometry, TRAIN/OOS split audit, frozen no-active-decision evidence scaffold, and declarative baseline-family registry align as one contract chain.
- Confirmed generated artifacts remain constrained to ignored run paths and `.gitignore` still covers `runs/`, `artifacts/`, `logs/`, and `data_cache/`.
- Confirmed the default local validation runner remains non-network and does not invoke data refresh, credential preflight, research query, or Alpaca environment paths.
- No indicators, returns, labels, regimes, PCA, HMMs, strategy signals, exits, allocation, dashboards, execution, live-order logic, provider expansion, corporate-actions ingestion, earnings-data integration, or active research candidates were added.

Goal: Confirm the first WFA foundation slices agree before any active research candidate, return calculation, indicator, label, regime, or strategy work begins.

Likely files:

- `README.md`
- `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`
- `docs/GEN5_TASK_QUEUE.md`
- tests only if a gap is found in foundation coverage

Required behavior:

- Confirm handoff gate, quarterly fold geometry, TRAIN/OOS split audit, frozen evidence scaffold, and baseline registry scaffold align with the minimal WFA contract.
- Confirm generated artifacts remain ignored.
- Confirm default validation remains non-network.
- Confirm there are still no indicators, returns, labels, regimes, PCA, HMMs, strategy signals, exits, allocation, dashboards, execution, live-order logic, provider expansion, corporate-actions ingestion, or earnings-data integration.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` if code or tests exist by this point.
- Otherwise perform a documentation-only diff review.

Stop conditions:

- Any unresolved leakage issue.
- Any generated artifacts appearing as tracked files.
- Any ambiguous decision about moving from WFA foundation into return/performance evaluation.

## Recommended Next Queue: WFA Post-Foundation Guardrails

These tasks are the next minimal WFA chunks after the first foundation closeout. They are intended to harden audit readiness and operator gates before any active research candidate, return calculation, performance evaluation, indicator, label, regime, PCA, HMM, strategy signal, exit, allocation, dashboard, execution, live-order logic, provider expansion, corporate-actions ingestion, or earnings-data integration is authorized.

### 29. Define WFA audit artifact schema and readiness checklist

Status: done

Recommended branch: `codex/gen5-wfa-audit-artifact-readiness`

Branch: `codex/gen5-wfa-post-foundation-guardrails`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added the documentation-first WFA audit artifact schema and readiness contract to `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`.
- Defined required linkage to explicit `as_of_timestamp`, `latest_completed_session`, source handoff, fold geometry, gate/review status, ignored artifact paths, schema versions, deterministic IDs or paths, leakage attestations, and code revision metadata when available.
- Kept the task documentation-only and did not add generated evidence, returns, performance metrics, indicators, labels, regimes, PCA, HMMs, strategy signals, exits, allocation, dashboards, execution, live-order logic, provider expansion, corporate-actions ingestion, earnings-data integration, or active research candidates.

Goal: Document the minimum generated WFA audit artifact schemas and readiness checks that must exist before returns or performance evaluation can be added.

Likely files:

- `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`
- `docs/GEN5_TASK_QUEUE.md`
- possibly a new schema note under `docs/`

Required behavior:

- Define the expected schema/readiness contract for run manifests, fold manifests, handoff gate results, fold-local availability, frozen decision evidence, baseline/candidate registries, OOS application/evaluation audit placeholders, leakage attestations, and later aggregate/stability summaries.
- Require each generated artifact to link back to explicit `as_of_timestamp`, `latest_completed_session`, source workbench handoff, fold geometry, gate/review status, and code revision when available.
- Require generated artifacts to remain under ignored run paths and source-controlled docs to describe schemas rather than store run evidence.
- Define readiness checks for required columns, deterministic IDs or paths, schema-version fields, ignored-output locations, and no provider/network/date-authority dependencies.
- Keep the task documentation-first unless a later implementation task is separately authorized.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1`.

Stop conditions:

- Implementing returns, performance metrics, indicators, labels, regimes, PCA, HMMs, strategy signals, exits, allocation, dashboards, execution, live-order logic, provider expansion, corporate-actions ingestion, earnings-data integration, or active research candidates.
- Adding generated audit artifacts to source control.
- Changing the current handoff, fold, split, frozen-evidence, or baseline helper behavior without a separate implementation task.

### 30. Define fold-stability summary contract

Status: done

Recommended branch: `codex/gen5-wfa-fold-stability-contract`

Branch: `codex/gen5-wfa-post-foundation-guardrails`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added the fold-stability summary contract surface to `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`.
- Defined required lineage, fold coverage, warning propagation, bad-fold visibility, outlier-dependence placeholders, no-trade/baseline slots, and leakage attestation references for later authorized evaluation.
- Kept the task documentation-only and did not compute returns, drawdowns, volatility, benchmark comparisons, ranks, pass/fail scores, labels, regimes, strategy outcomes, or candidate selections.

Goal: Define the operator-facing and artifact-level contract for fold-stability summaries before any returns or performance values exist.

Likely files:

- `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`
- `docs/GEN5_TASK_QUEUE.md`
- possibly a new schema note under `docs/`

Required behavior:

- Define fold-stability summary fields as a contract surface, with explicit placeholders for future completed-OOS evidence only.
- Preserve the project posture that fold consistency matters more than headline aggregate results.
- Require summaries to identify outlier dependence, bad-fold visibility, missing/partial fold coverage, warning-context propagation, and no-trade/baseline comparison slots once evaluation is later authorized.
- State that this task does not compute returns, drawdowns, benchmark comparisons, ranks, pass/fail scores, or candidate selections.
- Require any later implementation to aggregate only already-frozen and already-evaluated OOS records.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1`.

Stop conditions:

- Computing returns, drawdowns, volatility, Sharpe-like metrics, benchmark performance, ranks, labels, regimes, or strategy outcomes.
- Allowing OOS evidence to change a frozen fold decision.
- Authorizing an active research candidate.

### 31. Define explicit stop/go gate for returns and performance evaluation

Status: done

Recommended branch: `codex/gen5-wfa-returns-evaluation-gate`

Branch: `codex/gen5-wfa-post-foundation-guardrails`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added a STOP-by-default returns and performance evaluation gate to `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`.
- Defined the GO checklist for accepted handoff gates, explicit fold geometry, split audit evidence, frozen fold evidence, baseline-family registry, audit schema readiness, fold-stability contract review, ignored output locations, leakage attestations, and explicit operator approval.
- Required any future first evaluation slice to start with no-trade and reserved baseline-family evaluation discipline before active candidates, while keeping this task documentation-only with no return formulas, benchmark math, performance metrics, allocation, candidate scoring, dashboards, execution, or live advice.

Goal: Add an explicit documentation gate that says what must be true before any return calculation, OOS performance evaluation, benchmark comparison, or performance claim can begin.

Likely files:

- `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`
- `docs/GEN5_TASK_QUEUE.md`

Required behavior:

- Define a `STOP` default posture for returns and performance evaluation until the audit artifact schema, fold-stability contract, ignored-artifact discipline, and leakage attestations are reviewed.
- Define a `GO` checklist that requires accepted handoff gates, explicit fold geometry, split audit, frozen fold evidence, baseline-family registry, audit schema readiness, fold-stability summary contract, and operator approval for the first evaluation slice.
- Require the first future evaluation slice, when authorized, to start with no-trade and reserved baseline-family evaluation discipline before any active candidate is evaluated.
- Require performance artifacts to reference frozen fold decisions and prohibit recomputing authority from raw provider data.
- Keep the gate documentation-only and avoid adding return formulas or metric implementations.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1`.

Stop conditions:

- Adding returns, benchmark math, performance metrics, allocation, leverage reports, candidate scoring, strategy evaluation, dashboards, execution, or live advice.
- Treating this gate as approval to begin active research.
- Any ambiguous decision about whether evaluation should begin.

### 32. Define first candidate authorization boundary

Status: done

Recommended branch: `codex/gen5-wfa-first-candidate-boundary`

Branch: `codex/gen5-wfa-post-foundation-guardrails`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added the first active candidate authorization boundary to `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`.
- Stated that foundation closeout, audit readiness, fold-stability contract, returns/performance gate, and baseline scaffolding do not authorize an active candidate.
- Required any later first-candidate task to name the candidate, define allowed inputs, candidate family, TRAIN-only rules, OOS application rules, baseline/no-trade comparison scope, artifact outputs, ignored output locations, leakage attestations, and stop conditions before implementation.
- Kept this task documentation-only and did not name or design a candidate, add indicators, labels, regimes, PCA, HMMs, strategy signals, exits, allocation, dashboards, execution, live-order logic, provider expansion, corporate-actions ingestion, earnings-data integration, candidate-specific data sources, or active research logic.

Goal: Define the authorization boundary that must be crossed before the first active research candidate can be proposed or implemented.

Likely files:

- `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`
- `docs/GEN5_TASK_QUEUE.md`

Required behavior:

- State that no active research candidate is authorized by the foundation closeout, audit readiness work, fold-stability contract, or returns/performance stop/go gate.
- Require explicit operator approval for a named first candidate in a later task, including allowed inputs, candidate family, TRAIN-only fit rules if any, OOS application rules, baseline comparison scope, artifact outputs, and stop conditions.
- Require the first candidate authorization to come after the returns/performance evaluation gate is explicitly opened for baseline/no-trade evaluation discipline.
- Prohibit adding indicators, labels, regimes, PCA, HMMs, strategy signals, exits, allocation, dashboards, execution, live-order logic, provider expansion, corporate-actions ingestion, earnings-data integration, or candidate-specific data sources inside this boundary-definition task.
- Preserve no-trade as a first-class competitor and require any future active candidate to consume frozen WFA evidence rather than raw provider authority.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1`.

Stop conditions:

- Naming or designing the first active candidate beyond the authorization checklist.
- Implementing feature engineering, returns, labels, regimes, strategy signals, exits, allocation, dashboard, execution, live-order logic, or new data ingestion.
- Treating baseline scaffolding as evidence that an active candidate is ready.

### 33. Define no-trade and reserved baseline-family evaluation authorization boundary

Status: done

Recommended branch: `codex/gen5-wfa-baseline-evaluation-authorization`

Branch: `codex/gen5-wfa-baseline-evaluation-authorization`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added the first documentation-only no-trade and reserved baseline-family evaluation authorization boundary to `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`.
- Required any future baseline-evaluation implementation task to receive explicit operator approval, start with `no_trade`, stay limited to reserved baseline-family registry concepts, use accepted WFA artifacts only, and define artifact surfaces, ignored output locations, review gates, and leakage attestations before code is added.
- Clarified that this boundary does not compute returns, benchmark math, performance metrics, ranks, allocation, leverage reports, dashboards, execution, live advice, active candidates, or performance claims.
- Clarified that the baseline/no-trade boundary remains separate from active candidate authorization.

Goal: Define the authorization boundary for a future no-trade and reserved baseline-family evaluation slice without implementing evaluation or opening active research.

Likely files:

- `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`
- `docs/GEN5_TASK_QUEUE.md`

Required behavior:

- Define that the first future evaluation authorization must begin with `no_trade` and only reserved baseline-family concepts already represented by the baseline registry.
- Require allowed inputs to come from accepted workbench handoff artifacts, explicit fold geometry, TRAIN/OOS split audit evidence, frozen fold evidence, baseline-family registry rows, and reviewed audit-schema contracts.
- Require prohibited inputs to include provider calls, credentials, unmanifested cache files, independent date authority, active-candidate outputs, and OOS evidence used to change fold decisions.
- Require future artifact surfaces, schema versions, ignored output locations, warning/coverage review gates, and leakage attestations to be named before implementation.
- Preserve the separation between baseline/no-trade evaluation discipline and active candidate authorization.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1`.

Stop conditions:

- Computing returns, benchmark math, performance metrics, ranks, allocation, leverage reports, dashboards, execution, live advice, or performance claims.
- Naming, designing, fitting, scoring, or selecting an active research candidate.
- Treating reserved baseline definitions as baseline results.

### 34. Define first no-trade and reserved baseline-family evaluation implementation scope

Status: done

Recommended branch: `codex/gen5-wfa-baseline-evaluation-scope`

Branch: `codex/gen5-wfa-baseline-evaluation-scope`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added the documentation-only implementation scope for the first future no-trade and reserved baseline-family evaluation slice to `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`.
- Limited the future first slice to schema definitions, function boundaries, validation expectations, ignored output locations, review gates, and leakage attestations for `no_trade` first and then only reserved baseline families already present in the baseline registry.
- Required read-only consumption of accepted WFA artifacts and prohibited provider calls, credentials, unmanifested cache files, independent date authority, active-candidate outputs, and OOS outcome authority.
- Clarified that this scope does not compute returns, cash yields, benchmark math, performance metrics, ranks, drawdowns, volatility, allocation weights, leverage value-add, dashboards, execution, live advice, active candidates, or performance claims.

Goal: Define the documentation-only scope for the first future no-trade and reserved baseline-family evaluation implementation slice without adding evaluation code or opening active research.

Likely files:

- `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`
- `docs/GEN5_TASK_QUEUE.md`

Required behavior:

- Define the future first implementation slice as contract preparation only, covering schema surfaces, validation checks, deterministic identifiers or paths, ignored output locations, and review gates.
- Start with `no_trade` and then only reserved baseline families already represented by the baseline registry.
- Require allowed inputs to come from accepted WFA handoff gate results, explicit fold geometry, TRAIN/OOS split audit evidence, frozen fold evidence, baseline-family registry rows, and reviewed audit-schema contracts.
- Preserve the separation between baseline/no-trade evaluation preparation, actual returns/performance computation, and active candidate authorization.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1`.

Stop conditions:

- Computing returns, cash yields, benchmark math, performance metrics, ranks, drawdowns, volatility, allocation weights, leverage reports, dashboards, execution, live advice, or performance claims.
- Selecting, removing, weighting, ranking, or tuning symbols by OOS evidence.
- Naming, designing, fitting, scoring, or selecting an active research candidate.
- Treating reserved baseline definitions or schema placeholders as baseline results.

### 35. Add first no-trade and reserved baseline-family evaluation contract scaffold

Status: done

Recommended branch: `codex/gen5-wfa-baseline-evaluation-contract-scaffold`

Branch: `codex/gen5-wfa-baseline-evaluation-contract-scaffold`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Added `R/wfa_baseline_evaluation_contract.R` with schema/readiness helpers, deterministic ignored-run artifact path planning, review status fields, and leakage attestations for `no_trade` first and reserved baseline-family contract rows.
- Added non-network tests in `tests/testthat/test_wfa_baseline_evaluation_contract.R` covering no-trade ordering, ignored output paths, review acceptance, scaffold-only status fields, and rejection of tainted OOS/performance evidence.
- Updated `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md` to record the implemented scaffold without opening returns/performance evaluation or active candidate work.
- Did not compute returns, cash yields, benchmark math, performance metrics, ranks, drawdowns, volatility, allocation weights, leverage reports, dashboards, execution, live advice, active candidates, or performance claims.

Goal: Implement only the first no-trade and reserved baseline-family evaluation contract scaffold without producing baseline results.

Likely files:

- `R/wfa_baseline_evaluation_contract.R`
- `tests/testthat/test_wfa_baseline_evaluation_contract.R`
- `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`
- `docs/GEN5_TASK_QUEUE.md`

Required behavior:

- Start contract rows with `no_trade_cash`, followed only by reserved baseline families already represented by the baseline registry.
- Preserve accepted handoff, explicit fold geometry, TRAIN/OOS split audit, frozen evidence, and baseline registry lineage.
- Plan deterministic artifact paths under ignored `runs/` locations.
- Record review statuses for warning context, no-trade assumptions, unavailable proxy checks, fold coverage, and excluded/not-yet-authorized family questions.
- Record leakage attestations for no provider calls, credentials, unmanifested cache reads, latest-session inference, OOS outcome authority, OOS fitting, active-candidate inputs, or return/metric computation.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1`.

Stop conditions:

- Computing returns, cash yields, benchmark math, performance metrics, ranks, drawdowns, volatility, allocation weights, leverage reports, dashboards, execution, live advice, or performance claims.
- Selecting, removing, weighting, ranking, or tuning symbols by OOS evidence.
- Naming, designing, fitting, scoring, or selecting an active research candidate.
- Treating contract rows, deterministic paths, or readiness statuses as baseline results.

### 36. Review baseline evaluation contract scaffold for closeout readiness

Status: done

Recommended branch: `codex/gen5-wfa-baseline-evaluation-contract-closeout`

Branch: `codex/gen5-wfa-baseline-evaluation-contract-closeout`

Validation: `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1` passed.

Notes:

- Confirmed the first no-trade and reserved baseline-family evaluation contract scaffold remains schema/readiness only and keeps OOS application/evaluation status explicitly `not_applied` and `not_authorized`.
- Added explicit inclusion/exclusion review fields so a no-trade-only or otherwise narrow slice records which reserved baseline families are excluded and not yet authorized, instead of dropping that question silently.
- Expanded non-network tests for reserved-family exclusion review status, deterministic no-trade-first behavior, duplicate included-family rejection, ignored `runs/` artifact paths, leakage attestations, and no return/performance/allocation implementation statuses.
- Did not compute returns, cash yields, benchmark math, performance metrics, ranks, drawdowns, volatility, allocation weights, leverage reports, dashboards, execution, live advice, active candidates, or performance claims.

Goal: Confirm the first no-trade and reserved baseline-family evaluation contract scaffold is ready to close without producing baseline results.

Likely files:

- `R/wfa_baseline_evaluation_contract.R`
- `tests/testthat/test_wfa_baseline_evaluation_contract.R`
- `docs/GEN5_MINIMAL_WFA_CONTRACT_PLAN.md`
- `docs/GEN5_TASK_QUEUE.md`

Required behavior:

- Confirm schema/readiness helpers preserve required lineage, deterministic IDs or paths, review status fields, leakage attestations, and ignored output locations.
- Confirm no-trade remains first and excluded reserved baseline-family questions remain visible when a narrow slice is requested.
- Confirm validation remains non-network and no provider calls, credentials, unmanifested cache reads, latest-session inference, OOS outcome authority, OOS fitting, active-candidate inputs, or return/metric computation are introduced.

Validation:

- Run `powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1`.

Stop conditions:

- Computing returns, cash yields, benchmark math, performance metrics, ranks, drawdowns, volatility, allocation weights, leverage reports, dashboards, execution, live advice, or performance claims.
- Selecting, removing, weighting, ranking, or tuning symbols by OOS evidence.
- Naming, designing, fitting, scoring, or selecting an active research candidate.
- Treating contract rows, deterministic paths, or readiness statuses as baseline results.
