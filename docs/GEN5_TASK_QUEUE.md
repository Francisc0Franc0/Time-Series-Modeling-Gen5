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

Status: pending

Recommended branch: `codex/gen5-wfa-handoff-gate`

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

Status: pending

Recommended branch: `codex/gen5-wfa-quarterly-fold-geometry`

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

Status: pending

Recommended branch: `codex/gen5-wfa-train-oos-split-audit`

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

Status: pending

Recommended branch: `codex/gen5-wfa-frozen-evidence-scaffold`

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

Status: pending

Recommended branch: `codex/gen5-wfa-baseline-registry-scaffold`

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

Status: pending

Recommended branch: `codex/gen5-wfa-foundation-closeout`

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
