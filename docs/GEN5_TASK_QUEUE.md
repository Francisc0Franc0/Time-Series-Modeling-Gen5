# Gen5 Task Queue

## Project Recap

Gen5 is in the v0 market-data-layer milestone. The repository currently has an R-first, Alpaca-only, adjusted daily OHLCV data layer with explicit `as_of_timestamp` handling, deterministic cache planning and merge behavior, validation output, and freeze evidence under ignored local run artifacts.

The current milestone sits before WFA, PCA/state modeling, strategy research, exits, allocation, dashboard, execution, and live-order work. Those later modules remain out of scope until the data-layer contract, tests, operator guidance, and closeout evidence are stable.

The visible behavior this milestone is moving toward is boring on purpose: an operator can configure local data settings, run the validation wrapper, run a bounded Alpaca refresh when credentials are available, inspect coverage/audit artifacts, and know whether the adjusted daily market-data layer is healthy enough to support later research modules.

## Queue Rules

Codex may work this queue only within the Gen5 v0 market-data-layer scope defined in `AGENTS.md`.

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
- `tests/testthat/test-generated_artifact_ignores.R`

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

Status: pending

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

Status: pending

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

Status: pending

Goal: Define what "data layer stable enough to move on" means without starting WFA or strategy work.

Likely files:

- new `docs/GEN5_V0_DATA_LAYER_CLOSEOUT_CHECKLIST.md`
- `docs/GEN5_TASK_QUEUE.md`

Validation:

- Documentation-only diff check.

Stop conditions:

- Any checklist item that requires implementing downstream modules.

### 9. Review test coverage map for data-layer invariants

Status: pending

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

Status: pending

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

Status: pending

Goal: Clarify how a future operator should regenerate comparable freeze evidence with explicit timestamps and bounded dates.

Likely files:

- `docs/GEN5_V0_DATA_LAYER_FREEZE_EVIDENCE.md`
- `docs/GEN5_V0_OPERATOR_RUNBOOK.md` if created

Validation:

- Documentation-only diff check unless scripts change.

Stop conditions:

- Any instruction to commit generated run artifacts.

## Suggested Overnight Prompt

Use this prompt in a fresh task when ready:

```text
Work through the next 6 pending items in docs/GEN5_TASK_QUEUE.md in this same thread.

Stay within AGENTS.md and Gen5 v0 market-data-layer scope. For each item: inspect relevant files, make scoped changes, run scripts/test/run_tests.ps1 when warranted, commit, push, update docs/GEN5_TASK_QUEUE.md, and leave a concise status note.

Stop if validation fails, the task requires WFA/strategy/allocation/dashboard/execution logic, a new dependency, destructive file operations, live-order behavior, provider expansion beyond Alpaca adjusted daily OHLCV, or an ambiguous project decision.
```
