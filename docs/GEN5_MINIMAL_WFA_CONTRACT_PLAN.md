# Gen5 Minimal WFA Contract Plan

## Context

This planning record follows the Gen5 v0 market-data-layer closeout and the Gen5 v0.1 Research Data Workbench closeout. The workbench can now produce adjusted daily bar handoff artifacts for later research consumers.

The first minimal WFA milestone must consume those handoff artifacts without calling Alpaca, inferring latest sessions, or recomputing provider authority. This document defines the contract and build order only. It does not implement WFA code.

Implementation note: the first Minimal WFA Foundation code slice now exists as a handoff reader/gate in `R/wfa_handoff_gate.R`. It validates a completed Research Data Workbench handoff before later fold construction, while still leaving indicators, returns, labels, regimes, strategy logic, exits, allocation, dashboards, execution, live-order behavior, provider expansion, corporate-actions ingestion, and earnings-data integration out of scope.

Implementation note: the first fold construction slice now exists as a quarterly fold geometry builder in `R/wfa_fold_geometry.R`. It consumes an accepted WFA handoff gate result plus explicit geometry inputs and emits TRAIN/OOS date records only; it does not partition bars, compute features, compute returns, evaluate candidates, or search across geometry alternatives.

Implementation note: the first TRAIN/OOS split audit slice now exists as `R/wfa_train_oos_split_audit.R`. It consumes an accepted WFA handoff gate result, canonical handoff bars, source symbol coverage and health context, and the explicit quarterly fold geometry manifest; it partitions rows by fold dates only, produces fold-local symbol availability evidence, and records leakage attestation without computing indicators, returns, labels, regimes, strategy signals, exits, allocation, dashboards, execution, live-order behavior, provider expansion, corporate-actions ingestion, or earnings-data integration.

Implementation note: the first frozen fold-decision evidence scaffold now exists as `R/wfa_frozen_fold_evidence.R`. It consumes the accepted handoff gate result, explicit fold geometry, TRAIN/OOS split audit outputs, accepted source warning context, and local git/code metadata when available; it emits one fold-level evidence row before OOS evaluation and records that no active candidate, feature model, strategy selector, baseline decision, return calculation, or performance claim exists yet.

Implementation note: the first baseline-family registry scaffold now exists as `R/wfa_baseline_registry.R`. It reserves `no_trade`/cash, broad-market buy-and-hold, per-asset buy-and-hold, fixed equal-weight basket buy-and-hold, and active-curation-with-passive-holding families as declarative definitions tied to the same accepted handoff, explicit quarterly fold calendar, frozen evidence, health gate, and audit discipline as later active candidates, without computing returns, choosing assets from OOS evidence, allocating capital, evaluating performance, or producing live-facing advice.

Implementation note: the first Minimal WFA Foundation closeout check now exists as `tests/testthat/test_wfa_foundation_closeout.R`. It exercises the handoff gate result, explicit quarterly fold geometry, TRAIN/OOS split audit, frozen no-active-decision evidence scaffold, and declarative baseline-family registry as one non-network contract chain, and confirms generated artifacts remain under ignored run paths before any indicators, returns, labels, regimes, PCA, HMMs, strategy signals, exits, allocation, dashboards, execution, live-order logic, provider expansion, corporate-actions ingestion, earnings-data integration, or active research candidates are added.

Implementation note: the first no-trade and reserved baseline-family evaluation contract scaffold now exists as `R/wfa_baseline_evaluation_contract.R`. It creates schema/readiness rows, deterministic ignored-run artifact paths, review status fields, and leakage attestations for `no_trade` first and then reserved baseline families, while keeping OOS application/evaluation status explicitly `not_applied` and `not_authorized`; it does not compute returns, cash yields, benchmark math, performance metrics, ranks, drawdowns, volatility, allocation weights, leverage reports, dashboards, execution, live advice, active candidates, or performance claims.

Implementation note: the AMD EMA long/cash strategy evaluation gate is now opened only as a narrow research authorization contract in `R/wfa_amd_ema_evaluation_gate.R`. It consumes accepted minimal WFA POC closeout evidence plus baseline evaluation readiness evidence, records the single `AMD` / `ema_long_cash` scope, preserves no-trade baseline discipline and leakage attestations, and keeps implementation status as gate-only. It does not compute EMA signals, returns, cash yields, trade accounting, performance metrics, allocation, leverage, dashboards, execution, live advice, broader strategy families, or performance claims.

Implementation note: the first AMD EMA long/cash evaluation contract surface now exists as `R/wfa_amd_ema_evaluation_contract.R`. It consumes the accepted AMD EMA gate plus fold geometry, TRAIN/OOS split audit availability, frozen fold evidence, and no-trade baseline contract rows. It emits schema-only manifest, review rows, and a readiness review with `no_trade_cash` first for every fold and `amd_ema_long_cash` second, deterministic ignored-run artifact paths, guarded CSV writers, review-required reasons, and leakage attestations. It does not compute EMA signals, returns, cash yields, trade accounting, benchmark math, performance metrics, allocation, leverage, dashboards, execution, live advice, broader strategy families, or performance claims.

Implementation note: the first AMD EMA train-only parameter-freeze contract now exists as `R/wfa_amd_ema_parameter_freeze_contract.R`. It consumes the accepted AMD EMA evaluation contract readiness review, requires explicit operator acceptance of that readiness surface, freezes one explicit fast/slow EMA period decision per fold, preserves `no_trade_cash` as a first-class comparison row, and emits readiness/write helpers with deterministic ignored-run artifact paths. It does not compute EMA signals, apply frozen parameters to OOS rows, compute returns, cash yields, trade accounting, benchmark math, performance metrics, allocation, leverage, dashboards, execution, live advice, broader strategy families, or performance claims.

Implementation note: the first AMD EMA frozen-parameter OOS application boundary now exists as `R/wfa_amd_ema_parameter_application_boundary.R`. It consumes the accepted AMD EMA parameter-freeze readiness review and source freeze surfaces, preserves `no_trade_cash` as row 1 for every fold, and binds already-frozen train-only fast/slow EMA periods to fold OOS windows as schema/readiness rows only. It does not compute EMA signals, returns, cash yields, trade accounting, benchmark math, performance metrics, allocation, leverage, dashboards, execution, live advice, broader strategy families, or performance claims. The next pause point is a separately authorized Task 49 measurement contract that must name allowed measurement fields before work begins.

Implementation note: the first AMD EMA minimal OOS measurement contract now exists as `R/wfa_amd_ema_oos_measurement_contract.R`. It consumes the accepted AMD EMA application-boundary readiness review and source application surfaces, records a deterministic application artifact hash, preserves `no_trade_cash` as first-class zero-return comparison evidence, and authorizes only named schema fields for session open-to-close returns, trade open-to-open returns, zero cash/no-position returns, position/trade accounting, Sharpe, trade return, and max drawdown. It defines row-per-session, per-trade, per-fold summary, and global summary schemas plus strict future session-row validation for frozen application coverage. It does not compute EMA signals, return values, trade PnL, Sharpe, drawdown, allocation, leverage, dashboards, execution, live advice, broader strategy families, or performance claims.

## Scope

This first WFA planning slice is documentation-only. It defines:

- fold geometry and train/OOS separation rules;
- allowed inputs from the workbench handoff;
- no-leakage rules for fold creation, fitting, selection, and evaluation;
- how later fold-local learned components must be fit on TRAIN only and applied to OOS;
- baseline concepts to reserve;
- minimal audit outputs and frozen decision evidence;
- what remains out of scope until separately authorized.

## Operator Intent

The WFA engine is a methodology first. It should simulate standing at a historical decision point with only the data and frozen evidence that would have been available then. The engine should behave as if Gen5 had a time machine, moved to each historical quarter, made a decision without knowing what came next, and then measured what happened OOS.

This means WFA is not only a strategy backtest wrapper. It is the required methodology for:

- rejecting weak ideas;
- producing frozen decision packs;
- testing universe-creation logic;
- testing asset or basket curation logic;
- testing portfolio construction logic;
- testing entry, exit, state, filter, or strategy logic when those later modules are authorized.

The first design priority is consistency across folds. High aggregate performance that depends on a few extreme OOS wins should not be treated as strong evidence if fold behavior is unstable or grotesque in important periods. A bad OOS fold does not automatically kill a candidate, especially when later regime-conditioned work may explain when a candidate is useful, but every bad fold must remain visible.

The first decision cadence should be quarterly. Frozen decision evidence should be valid for the next quarter in historical research, and later for the current unfinished quarter in advice-only live operation. This planning record keeps that live-facing shape in mind without implementing live runner behavior.

The 25% drawdown level is a warning threshold, not an initial hard disqualification rule. The early WFA engine should allow unconstrained research runs while making drawdown discomfort visible enough that the operator can later decide what is deployable.

Cash/no-position should be a real outcome. The system should not be forced to invest when evidence is weak, though future universe selection and basket curation may aim to reduce unnecessary all-cash periods. Complexity is allowed when it is auditable and earns its keep through stable OOS evidence; complexity that only works by fitting noise should fail under the WFA methodology.

## Allowed Inputs

Future minimal WFA code may consume only completed Research Data Workbench handoff artifacts:

- canonical adjusted daily bars;
- the matching manifest row;
- severity-labeled health rows;
- audit CSV;
- symbol coverage CSV;
- refresh plan CSV;
- merge summary CSV when a credentialed refresh produced one;
- source-controlled universe registry rows used to select the symbols.

The WFA layer may read manifest metadata such as `as_of_timestamp`, `latest_completed_session`, requested dates, bounded dates, universe name, selected roles, requested symbols, returned symbols, provider, feed, cache root, generated artifact paths, `health_max_severity`, and git SHA.

The WFA layer must not consume:

- Alpaca HTTP APIs;
- `g5_fetch_alpaca_daily_adjusted_bars()` or lower-level provider helpers;
- provider response shapes, pagination fields, or authentication state;
- `.Renviron`, Alpaca credentials, or live network checks;
- unmanifested cache files as authoritative research input;
- runtime date authority such as `Sys.Date()`.

## Handoff Gate Before Fold Construction

Before any fold is constructed, a WFA run must confirm:

- the handoff was produced by a documented workbench wrapper;
- `as_of_timestamp` is explicit and consistent across bars, manifest, audit, and health artifacts;
- all bar rows are on or before `latest_completed_session`;
- `health_max_severity` is not `ERROR`;
- any `WARN` rows were reviewed and accepted before research use;
- canonical bar columns are present and valid;
- `adjusted == TRUE`, `timeframe == "1D"`, and `provider == "alpaca"` for Gen5 v0.1 handoffs;
- duplicate `symbol` plus `session_date` rows are absent;
- generated artifacts remain ignored and are not committed.

This gate may fail the run or require operator acceptance. It must not silently repair provider data, fetch replacement bars, or reinterpret latest-session authority.

The current gate returns `PASS` when the handoff has no warning health rows and `REVIEW_REQUIRED` when `WARN` rows are present. `ERROR` health rows, missing artifacts, schema failures, duplicated `symbol` plus `session_date` rows, future bars, or inconsistent `as_of_timestamp`/`latest_completed_session` evidence fail loudly.

## Fold Geometry Contract

The minimal WFA engine should start with one explicit rolling geometry supplied by configuration or a run manifest. It should not search across multiple geometries in the first implementation slice.

A fold geometry record must include:

- `fold_id`;
- `train_start_date`;
- `train_end_date`;
- `oos_start_date`;
- `oos_end_date`;
- decision cadence, initially `quarterly`;
- decision-pack validity start and end dates;
- train window length rule;
- OOS window length rule;
- any intentional gap between TRAIN and OOS;
- selected symbols or universe reference;
- source handoff manifest path or ID;
- source `as_of_timestamp`;
- source `latest_completed_session`.

The first implementation uses `g5_build_quarterly_fold_geometry()` for a single explicit quarterly geometry. The emitted manifest records include `fold_id`, TRAIN dates, OOS dates, `decision_cadence`, decision-pack validity dates, train and OOS window rules, intentional gap days and gap dates, source handoff reference, handoff gate status/review acceptance fields, source `as_of_timestamp`, source `latest_completed_session`, and `geometry_search_policy == "none_single_explicit_quarterly_geometry"`.

The first implementation should use quarterly OOS periods and the canonical `session_date` calendar visible in the handoff bars. Calendar construction is allowed only from handoff data and manifest metadata. It must not call market-clock APIs or infer latest sessions.

Fold boundaries must satisfy:

- `train_start_date <= train_end_date`;
- `oos_start_date <= oos_end_date`;
- `train_end_date < oos_start_date` unless an explicitly recorded gap policy says otherwise;
- `oos_end_date <= latest_completed_session`;
- TRAIN and OOS rows are disjoint;
- each fold's OOS period occurs strictly after that fold's TRAIN period;
- fold membership is decided from explicit dates and manifest metadata, not from OOS outcomes.

Any minimum-history rule for symbol eligibility must be declared before evaluation. If a symbol lacks required bars inside a fold, the run must record the fold-local availability decision rather than silently filtering the symbol based on OOS performance.

## Train And OOS Separation

For each fold:

- TRAIN contains only rows with `session_date` inside the fold's training window.
- OOS contains only rows with `session_date` inside the fold's out-of-sample window.
- No OOS row may be used to fit, scale, label, cluster, tune, rank, select, or reject a candidate before the fold's frozen decision evidence is written.
- No later fold may change an earlier fold's frozen selection or OOS record.
- Cross-fold summaries may aggregate completed OOS evidence only after each fold has been independently frozen and evaluated.

The WFA layer may use OOS rows to measure the already-frozen decision for that fold. It may not use OOS rows to decide what that decision should have been.

The first TRAIN/OOS split audit helper returns these tabular evidence surfaces:

- `train_rows` and `oos_rows`, which preserve the canonical handoff bar columns and add fold membership fields (`fold_id`, `split_role`, fold TRAIN/OOS dates, and `split_membership_rule`);
- `split_summary`, with per-fold row counts, first/latest TRAIN and OOS sessions, symbol counts, disjointness checks, OOS-after-TRAIN checks, latest-session bounds, and `outcome_columns_used_for_membership == FALSE`;
- `symbol_availability`, with one row per fold and source handoff symbol, fold-local TRAIN/OOS row counts and date edges, source empty/partial/stale coverage fields, source health warning context, and an availability rule that records no OOS performance filtering;
- `source_warn_health_rows`, preserving accepted source warning rows for downstream evidence;
- `leakage_attestation`, recording no provider calls, no latest-session inference, and no OOS-outcome membership decisions.

The first frozen evidence helper returns a tabular scaffold with one row per fold. Each row links the source handoff reference, gate status and review acceptance, fold dates and decision-pack validity dates, TRAIN rows and symbols available, accepted source warnings, leakage attestations for no provider calls, no latest-session inference, no OOS membership decisions, and no OOS fitting, plus code revision metadata when available. It deliberately records `FROZEN_NO_ACTIVE_DECISION`, `oos_performance_evaluated == FALSE`, and no active candidate or strategy decision.

## Selection And Rejection Posture

WFA summaries should privilege fold stability over headline aggregate performance. The engine should preserve enough per-fold evidence to answer:

- whether performance depends on one or two outlier OOS periods;
- whether losses or drawdowns are concentrated in a way that would be hard to live through;
- whether a candidate is broadly consistent, regime-specific, or simply lucky;
- whether a simpler or more complex candidate is earning its place through repeatable OOS evidence.

The engine should not discard a candidate only because one OOS period failed. It should also not pass a candidate only because total OOS return finished high. The audit surface should make both facts visible so later research can distinguish "bad idea", "useful in some regimes", and "promising but not yet deployable".

## Fold-Stability Summary Contract

Fold-stability summaries are an operator-facing contract surface before they are an implementation. They exist to keep per-fold behavior visible and to prevent later aggregate results from hiding fragile evidence. This contract does not compute returns, drawdowns, volatility, benchmark comparisons, ranks, pass/fail scores, labels, regimes, strategy outcomes, or candidate selections.

A future fold-stability summary artifact must include:

- `schema_version`;
- run manifest ID or path;
- source workbench handoff manifest ID or path;
- source `as_of_timestamp`;
- source `latest_completed_session`;
- fold geometry ID or path;
- handoff gate status and review status;
- frozen decision evidence artifact references;
- evaluated OOS artifact references, populated only after OOS evaluation is separately authorized and completed;
- fold count expected, fold count evaluated, and missing or partial fold coverage flags;
- warning-context propagation fields from the source handoff and fold-local availability audit;
- bad-fold visibility placeholders for later completed-OOS evidence;
- outlier-dependence placeholders for later completed-OOS evidence;
- no-trade and baseline comparison slots for later authorized evaluation;
- leakage attestation reference confirming no OOS evidence changed any frozen fold decision;
- code revision metadata when available.

The summary must aggregate only already-frozen and already-evaluated OOS records. It may not reach backward into raw provider data, recompute latest-session authority, infer missing folds, repair data-health warnings, or update a frozen decision after seeing OOS evidence. Missing, partial, stale, or warning-heavy fold coverage must remain visible rather than being dropped from the summary.

Until returns and performance evaluation are separately authorized, fold-stability artifacts may contain only schema fields, lineage, readiness status, coverage status, warning propagation, and explicit empty placeholders for future completed-OOS evidence. The absence of evaluated OOS records is a valid STOP state, not a reason to synthesize performance claims.

## Returns And Performance Evaluation Gate

Returns, OOS performance evaluation, benchmark comparison, candidate scoring, leverage reporting, allocation, dashboards, execution, live advice, and performance claims are `STOP` by default. The existence of fold geometry, split audits, frozen no-active-decision evidence, baseline registry scaffolding, audit schema readiness, or fold-stability schema placeholders does not open this gate by itself.

The gate may move from `STOP` to `GO` only for a separately authorized first evaluation slice after all of the following are true:

- accepted handoff gate results exist for the source workbench handoff;
- explicit fold geometry exists and is linked to the accepted handoff;
- TRAIN/OOS split audit evidence exists and preserves fold-local availability and warning context;
- frozen fold evidence exists before OOS evaluation and records the no-active-decision or later frozen-decision state;
- baseline-family registry scaffolding exists and keeps `no_trade` first-class;
- WFA audit artifact schema readiness has been reviewed, including schema versions, deterministic IDs or paths, ignored-output locations, source lineage, and leakage attestations;
- fold-stability summary contract fields have been reviewed, including missing/partial coverage, bad-fold visibility, outlier-dependence placeholders, warning propagation, and no-trade/baseline slots;
- generated performance artifacts are planned for ignored run paths rather than source control;
- the operator explicitly approves the first evaluation slice and its scope.

The first future evaluation slice, if the gate is opened, must begin with no-trade and reserved baseline-family evaluation discipline before any active candidate is evaluated. Performance artifacts must reference frozen fold decisions and OOS application/evaluation audit records. They must not recompute authority from raw provider data, fetch replacement bars, infer latest sessions, change fold geometry, change symbol eligibility from OOS evidence, or update a frozen fold decision after seeing OOS results.

This gate is documentation-only. It does not add return formulas, benchmark math, performance metrics, ranking rules, candidate scoring, allocation, leverage analysis, dashboard behavior, execution, live advice, or active research authorization.

## No-Trade And Reserved Baseline Evaluation Authorization Boundary

The first evaluation authorization boundary is for a future no-trade and reserved baseline-family slice only. This boundary is documentation-only. It does not open evaluation by itself and does not compute returns, benchmark math, performance metrics, ranks, allocation, leverage reports, dashboards, execution, live advice, or active candidates.

A later baseline-evaluation implementation task may start only after the returns and performance evaluation gate is explicitly moved to `GO` for this narrow scope. That task must receive explicit operator approval and must state which reserved baseline families are in scope before any code or generated performance artifact is added.

The first baseline-evaluation authorization request must define:

- included baseline families, starting with `no_trade` and then only the reserved baseline families already present in the baseline registry;
- excluded baseline families, including any leverage variants unless leverage evaluation is separately authorized;
- allowed input artifacts, limited to accepted workbench handoff artifacts, explicit fold geometry, TRAIN/OOS split audit evidence, frozen fold evidence, baseline-family registry rows, and reviewed audit-schema contracts;
- prohibited inputs, including Alpaca/provider calls, credentials, unmanifested cache files, independent date authority, active-candidate outputs, and OOS outcome evidence used to change fold decisions;
- the future evaluation artifact surfaces to be created, including OOS application/evaluation audit records and fold-stability summary inputs, with schema versions and ignored output locations;
- review gates for missing or partial fold coverage, source health warnings, stale symbols, unavailable broad-market proxies, and any ambiguity about cash/no-position interpretation;
- leakage attestations proving that baseline application uses the same fold calendar, handoff gate, availability audit, warning context, and frozen evidence discipline as later active candidates.

This boundary keeps `no_trade` visible as a first-class competitor before active research begins. It also prevents the reserved baseline registry from becoming an implicit performance claim: baseline definitions are not baseline results, and a future baseline-evaluation task must not use OOS evidence to select symbols, change fold geometry, repair data, rank alternatives, or update a frozen fold decision.

The future baseline-evaluation slice remains separate from active candidate authorization. It may prepare the comparison discipline that active candidates must eventually face, but it must not name, design, fit, score, or select an active research candidate.

## First No-Trade And Reserved Baseline Evaluation Scope

The first future no-trade and reserved baseline-family evaluation implementation slice must be scoped before code is added. This scope definition is documentation-only. It does not implement evaluation and does not compute returns, benchmark math, performance metrics, ranks, allocation, leverage reports, dashboards, execution, live advice, active candidates, or active candidate comparisons.

The first implementation slice, when separately authorized, should be limited to preparing the minimum baseline-evaluation contract surfaces needed to apply already-reserved baseline definitions against already-frozen fold evidence. It may define artifact schemas, function boundaries, validation expectations, ignored output locations, and review gates for `no_trade` first, followed only by reserved baseline families already present in the baseline registry. It must not produce baseline results or performance claims.

The allowed scope for that first implementation slice is:

- read-only consumption of accepted WFA handoff gate results, explicit fold geometry, TRAIN/OOS split audit evidence, frozen fold evidence, baseline-family registry rows, and reviewed audit-schema contracts;
- schema definitions for baseline OOS application/evaluation audit records that reference frozen fold evidence and fold-local availability evidence;
- schema definitions for no-trade and reserved baseline review status fields, including skipped, unavailable, review-required, and not-yet-evaluated states;
- deterministic identifiers or paths for generated baseline evaluation artifacts under ignored run paths;
- validation checks for required lineage fields, schema versions, fold IDs, source `as_of_timestamp`, source `latest_completed_session`, handoff references, frozen evidence references, and leakage attestations;
- review gates for source health warnings, missing or partial folds, unavailable broad-market proxy symbols, ambiguous cash/no-position assumptions, stale symbol context, and baseline families reserved but intentionally excluded from the slice.

The prohibited scope for that first implementation slice is:

- computing returns, cash yields, benchmark math, performance metrics, ranks, drawdowns, volatility, leverage value-add, allocation weights, or portfolio equity curves;
- selecting, removing, weighting, ranking, or tuning symbols by OOS evidence;
- changing fold geometry, symbol eligibility, handoff acceptance, or frozen fold decisions after seeing OOS outcomes;
- reading Alpaca/provider APIs, credentials, unmanifested cache files, market-clock APIs, or runtime date authority;
- naming, designing, fitting, scoring, or selecting an active research candidate;
- creating dashboards, live advice, execution behavior, order-routing behavior, or deployability claims.

The first implementation slice should stop if the contract cannot represent `no_trade` without an implicit return assumption, if a reserved baseline needs a proxy symbol that is absent from the accepted handoff, if fold coverage is missing or ambiguous, if source warnings have not been accepted, if generated outputs would need to be source-controlled, or if any requested behavior requires returns/performance computation rather than schema and audit preparation.

The current implementation scaffold is intentionally limited to `g5_build_wfa_baseline_evaluation_contract_scaffold()` and related schema/path/readiness validators. It writes no generated files by default, reads no bars or provider data, and plans placeholder artifact paths under ignored `runs/` locations only. It records review-required reasons for unresolved cash/no-position assumptions, broad-market proxy availability, warning context, fixed-basket membership, curation authorization, and any reserved baseline families intentionally excluded from a narrow slice without resolving those questions through OOS evidence or performance computation.

The readiness review helper summarizes an already-validated baseline evaluation contract into one review-only row. It requires `no_trade_cash` coverage for every fold, unique baseline-family/fold rows, one preserved handoff lineage, ignored artifact path policy, calculation STOP status, and true leakage attestations. The review row may be cited by a later explicit operator gate after acceptance, but it remains non-computational evidence only.

## WFA Post-Guardrails Closeout Review

The WFA post-foundation guardrails are closed through the baseline evaluation contract scaffold only. This closeout confirms that the audit artifact readiness contract, fold-stability summary contract, returns/performance `STOP` gate, first-candidate authorization boundary, no-trade/reserved-baseline authorization boundary, first baseline-evaluation implementation scope, and current baseline evaluation contract scaffold agree on the same status:

- generated WFA artifact schemas are readiness and lineage surfaces only until a later task explicitly authorizes evaluation;
- fold-stability artifacts may carry lineage, coverage, warning propagation, and placeholder fields, but may not synthesize returns, drawdowns, volatility, ranks, benchmark comparisons, pass/fail scores, or performance claims;
- returns, OOS performance evaluation, benchmark comparison, candidate scoring, leverage reporting, allocation, dashboards, execution, live advice, and performance claims remain `STOP` by default;
- no active research candidate is authorized by foundation closeout, audit readiness, fold-stability readiness, baseline scaffolding, or the baseline evaluation contract scaffold;
- a future first evaluation slice must be explicitly authorized, must begin with `no_trade`, must remain limited to reserved baseline-family concepts already represented by the baseline registry, and must preserve excluded reserved-family questions when the authorized slice is narrow;
- the current baseline evaluation contract scaffold records schema versions, deterministic ignored-run paths, review status fields, leakage attestations, lineage to accepted WFA artifacts, `not_applied` OOS application status, and `not_authorized` evaluation status without reading provider data, computing returns, assuming cash yield, performing benchmark math, creating performance metrics, allocating weights, or naming active candidates.

This closeout does not open the returns/performance gate. It records readiness for an operator to decide whether to authorize a separate future baseline/no-trade evaluation task. Until that approval exists, contract rows, deterministic paths, review statuses, and reserved-family definitions remain scaffolding rather than baseline results.

## First Minimal WFA POC Plan

The first minimal WFA POC should be a contract rehearsal, not a research result. Its objective is to prove that one small, accepted WFA-ready handoff can be traced through the existing WFA guardrail surfaces: handoff gate, explicit quarterly fold geometry, TRAIN/OOS split audit, frozen no-active-decision evidence, baseline-family readiness scaffolding, fold-stability placeholders, and leakage attestations. The POC should demonstrate that the project can preserve lineage, warning context, fold boundaries, and STOP states before any evaluation or active candidate exists.

This POC is documentation-only until a later implementation task is explicitly authorized. It does not compute returns, cash yields, benchmark math, performance metrics, ranks, drawdowns, volatility, allocation weights, leverage value-add, dashboards, execution behavior, live advice, active candidates, or performance claims. It also does not open the returns/performance gate.

Allowed inputs for the first minimal WFA POC are limited to:

- this source-controlled contract plan and the task queue entry that authorizes the documentation boundary;
- an accepted Research Data Workbench handoff manifest and its listed canonical adjusted daily bars, health rows, audit rows, symbol coverage, refresh plan, merge summary when present, and source-controlled universe registry rows;
- existing WFA scaffold outputs or schemas for handoff gate status, quarterly fold geometry, TRAIN/OOS split audit, frozen fold evidence, baseline-family registry rows, baseline-evaluation contract readiness rows, fold-stability placeholder fields, and leakage attestations;
- explicit `as_of_timestamp`, `latest_completed_session`, source handoff references, fold IDs, schema versions, code revision metadata, and ignored-run-path planning fields already carried by accepted artifacts;
- operator review notes that accept or reject source warnings, missing or partial fold coverage, and unresolved baseline-family inclusion questions.

Prohibited inputs for the first minimal WFA POC are:

- Alpaca/provider calls, credentials, `.Renviron`, market-clock APIs, provider response payloads, or unmanifested cache files;
- independent runtime date authority, including any new use of `Sys.Date()` or inferred latest sessions;
- returns, cash yield assumptions, benchmark math, performance metric values, ranks, drawdown values, volatility values, allocation weights, leverage reports, dashboard outputs, live advice, execution artifacts, or performance claims;
- OOS evidence used to select symbols, alter fold geometry, accept or reject warnings, tune parameters, rank alternatives, change baseline inclusion, or update frozen fold decisions;
- indicators, labels, regimes, PCA, HMMs, strategy signals, exits, allocation logic, candidate-specific features, active candidate definitions, or active candidate outputs.

The planned artifact surfaces for a later separately authorized POC implementation are schema and review surfaces only:

- `poc_scope_decision_log`: records the operator-approved POC scope, excluded work, STOP states, and unresolved questions;
- `poc_run_manifest`: links the accepted handoff, explicit timestamp/session authority, fold geometry reference, ignored output root, schema versions, and code revision metadata;
- `poc_handoff_review_record`: records handoff gate status, accepted warnings, rejected warnings, and reviewer identity or review source;
- `poc_fold_geometry_reference`: records that the POC uses one explicit quarterly geometry and no geometry search;
- `poc_split_audit_reference`: links TRAIN/OOS disjointness, fold-local availability, warning context, and latest-session bounds;
- `poc_frozen_evidence_reference`: links fold-level frozen no-active-decision evidence written before any OOS evaluation;
- `poc_baseline_readiness_record`: keeps `no_trade` visible and records reserved baseline families as included, excluded, unavailable, or not yet authorized without computing results;
- `poc_fold_stability_placeholder`: records expected/evidenced fold coverage, warning propagation, missing/partial coverage flags, and empty placeholders for future evaluated OOS evidence;
- `poc_leakage_attestation`: records no provider calls, no credentials, no independent date authority, no OOS fitting, no OOS outcome authority, no return/performance computation, and no active-candidate input.

The review gates for the first minimal WFA POC are:

- Scope gate: confirm the POC remains a contract rehearsal and does not request evaluation, active candidates, or live-facing behavior.
- Source gate: confirm the handoff gate is accepted or explicitly review-accepted, with all source warnings preserved.
- Geometry gate: confirm one explicit quarterly geometry is used, with no geometry search or OOS-informed fold changes.
- Split gate: confirm TRAIN/OOS split evidence is disjoint, bounded by `latest_completed_session`, and preserves fold-local availability decisions.
- Frozen-evidence gate: confirm frozen fold evidence exists before any OOS application/evaluation and records no active decision unless a later authorized candidate exists.
- Baseline-readiness gate: confirm `no_trade` remains first-class and any reserved baseline-family inclusion, exclusion, or unavailability is visible without becoming a result.
- Leakage gate: confirm no provider calls, credentials, independent date authority, unmanifested cache reads, OOS fitting, OOS outcome authority, return/performance computation, or active-candidate input entered the POC.
- Operator gate: require explicit operator acceptance of unresolved warnings, partial coverage, unavailable proxies, excluded reserved families, and the decision to stop before evaluation.

The POC must stop if any of the following occur:

- the work requires returns, cash yields, benchmark math, performance metrics, ranks, drawdowns, volatility, allocation weights, leverage reports, dashboards, execution, live advice, active candidates, or performance claims;
- a handoff artifact is missing, unaccepted, ambiguous, or inconsistent across `as_of_timestamp` or `latest_completed_session`;
- source warnings, missing coverage, partial folds, stale symbols, unavailable proxies, or excluded baseline families cannot be represented without hiding them;
- the POC would need provider access, credentials, unmanifested cache reads, runtime date authority, market-clock APIs, or generated outputs committed to source control;
- any OOS evidence would affect fold construction, symbol eligibility, warning acceptance, baseline inclusion, frozen fold decisions, or active candidate design;
- an operator request is ambiguous about whether the returns/performance gate should open.

Validation expectations for this documentation task are limited to the repository validation wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1
```

For any later implementation task, validation must remain non-network by default and must test schema fields, deterministic identifiers or ignored paths, source lineage, review statuses, leakage attestations, and STOP states. It must not add dependencies, provider calls, return formulas, performance calculations, benchmark comparisons, allocation logic, dashboards, execution behavior, live advice, active candidate definitions, or performance claims.

The exact separate authorization required before any evaluation work can begin is a later operator prompt that explicitly says all of the following in substance: open the returns/performance gate for a no-trade and reserved baseline-family evaluation slice only; name the branch for that task; identify the accepted handoff/fold/frozen-evidence artifacts or fixture scope; name included and excluded reserved baseline families; authorize only the narrow evaluation artifact surfaces specified in that later prompt; and state that active candidates remain unauthorized. Without that later prompt, evaluation remains `STOP`.

The exact separate authorization required before any active candidate work can begin is an even later operator prompt, after baseline/no-trade evaluation discipline has been reviewed, that explicitly names the first candidate, candidate family, allowed inputs and columns, prohibited inputs, TRAIN-only fit or selection rules, OOS application rules, baseline/no-trade comparison scope, artifact surfaces, ignored output locations, leakage attestations, and candidate-specific STOP conditions. Without that later prompt, active candidate work remains `STOP`.

High-level questions to settle before opening any later gate:

- Should the first POC be the thinnest possible lineage rehearsal, or should it intentionally include a warning-heavy handoff to test review discipline? The safer first insight is to start thin, then run a warning-heavy rehearsal only after the clean path is accepted.
- Should `no_trade` be the only included baseline readiness row, with all other reserved families preserved as excluded/not-yet-authorized, or should unavailable broad-market and basket questions be surfaced in the same POC? The cleaner first insight is to keep `no_trade` included and make every other family explicitly visible but not evaluated.
- Who has authority to accept WARN rows and partial fold coverage for POC use: the operator only, a named review note, or a future checklist status? The durable insight is that acceptance should be explicit and attributable rather than inferred from a passing script.
- What minimum fold coverage is enough for a contract rehearsal without drifting into performance interpretation? The useful answer is coverage sufficient to exercise lineage, missing/partial flags, and STOP states, not coverage sufficient to persuade anyone of an outcome.
- Should the next authorization stop at writing schema/review artifacts, or should it open the narrow no-trade/reserved-baseline evaluation gate? The current recommendation is to keep those as separate prompts so the project can inspect the POC surfaces before any evaluation begins.

## Minimal WFA Engine Toward AMD EMA POC Roadmap

The next larger autonomous milestone is Minimal WFA Engine Toward AMD EMA POC. It sits after the Research Data Workbench and current WFA guardrails, and before strategy research. Its purpose is to make the minimal WFA engine, review surfaces, and evaluation contracts ready enough that a later operator can deliberately open a first human-facing strategy slice.

The first intended human-facing strategy vertical slice after those prerequisites is AMD EMA long/cash: a single-symbol AMD long-or-cash EMA-family candidate evaluated inside WFA against explicit cash/no-position and reserved baseline discipline. This names the destination only. It does not authorize EMA signal code, return calculation, trade accounting, performance metrics, active candidate implementation, dashboards, live advice, allocation, leverage analysis, execution, or performance claims.

Autonomous work inside this milestone may cover only:

- documentation and queue updates that preserve the existing system-design build order;
- WFA handoff, fold geometry, TRAIN/OOS split, frozen evidence, baseline readiness, fold-stability placeholder, and leakage-attestation schema/review surfaces;
- minimal POC run-manifest and closeout scaffolding that records lineage, STOP states, warning context, deterministic ignored-run paths, and validation status;
- non-network tests for schema fields, deterministic identifiers or paths, ignored-output locations, source lineage, review statuses, leakage attestations, and STOP states.

Autonomous work inside this milestone must stop before:

- computing returns, cash yields, benchmark math, performance metrics, ranks, drawdowns, volatility, allocation weights, leverage reports, or performance claims;
- adding trade accounting, position accounting, order simulation, exits, dashboards, live advice, execution, or live-order behavior;
- implementing EMA signals, active candidates, active candidate features, active candidate scoring, parameter selection, or OOS-informed candidate decisions;
- adding dependencies, provider calls, credentials, unmanifested cache reads, independent date authority, market-clock APIs, or source-controlled generated run artifacts;
- changing the build order in `docs/GEN5_SYSTEM_DESIGN.md` or treating AMD EMA as authorized strategy work.

The exact AMD EMA strategy evaluation gate was closed by default until the operator explicitly opened it for the branch `codex/gen5-amd-ema-evaluation-gate`. The open gate is intentionally narrow: `AMD` only, `ema_long_cash` only, research evaluation only, non-live, non-dashboard, no allocation, no leverage, no execution, and no broader strategy family.

That gate-opening prompt must also:

- name the branch for the AMD EMA evaluation task;
- identify the accepted minimal WFA POC closeout evidence or fixture scope;
- confirm the relevant no-trade/reserved-baseline evaluation contract readiness has been reviewed and accepted;
- define the exact evaluation scope, including which returns, trade-accounting, performance-metric, EMA-signal, and active-candidate surfaces are authorized for that task;
- list allowed input artifacts and columns, prohibited inputs, TRAIN-only fit or parameter rules, OOS application rules, baseline/no-trade comparison scope, artifact outputs, ignored output locations, validation expectations, and leakage attestations;
- state that dashboards, live advice, allocation, leverage, execution, and any broader strategy family remain unauthorized unless separately named.

With that gate-opening prompt accepted, the repository now has a gate authorization surface plus a first schema-only AMD EMA evaluation contract surface. Actual EMA signal computation, return calculation, trade accounting, performance metrics, generated evaluation artifacts, interpretation, deployment, dashboards, live advice, allocation, leverage, execution, and broader strategy families remain separate follow-on tasks that must preserve the gate's scope and leakage controls.

## Minimal WFA POC Manifest Scaffold

The minimal WFA POC scaffold is a schema and review surface only. It records accepted WFA handoff lineage, explicit quarterly fold geometry, TRAIN/OOS split audit presence, frozen no-active-decision evidence, no-trade-first baseline readiness, reserved baseline family readiness, baseline evaluation contract availability, ignored output paths, fold-stability placeholder status, and leakage attestations.

The scaffold does not evaluate OOS results. It records `not_evaluated`, `not_authorized`, and `not_implemented` statuses for OOS evaluation, returns, cash yield, benchmark math, performance metrics, allocation, and active candidate inputs. Its planned artifact paths must remain under ignored `runs/` locations.

The scaffold may be used later as closeout evidence for deciding whether to open a narrower evaluation gate. It is not strategy evidence, not performance evidence, and not authorization for AMD EMA or any other active candidate.

The closeout validation surface turns the scaffold into a compact pass/fail review table. It checks accepted handoff lineage, explicit fold geometry, TRAIN/OOS split evidence, frozen no-active-decision evidence, baseline readiness, fold-stability placeholder status, ignored run paths, STOP states, and leakage attestations. This closeout table remains a readiness review only; it does not write generated artifacts by default and does not evaluate OOS results.

## Minimal WFA Engine Toward AMD EMA POC Closeout Review

The Minimal WFA Engine Toward AMD EMA POC milestone is ready for operator review of a later gate decision. The repository now has schema-only surfaces for:

- minimal WFA POC run manifest and fold review rows;
- minimal WFA POC closeout validation;
- baseline evaluation contract readiness review.

These surfaces preserve accepted handoff lineage, explicit quarterly fold geometry, TRAIN/OOS split evidence, frozen no-active-decision evidence, `no_trade_cash` first-class readiness, reserved baseline family readiness, fold-stability placeholders, ignored `runs/` paths, STOP states, and leakage attestations.

This closeout does not open the AMD EMA strategy evaluation gate. It also does not compute returns, cash yields, benchmark math, trade accounting, performance metrics, EMA signals, active candidate outputs, allocation, leverage, dashboards, live advice, execution, or performance claims.

The project appears ready for the operator to consider the exact AMD EMA long/cash strategy evaluation gate prompt later, provided that prompt explicitly opens the gate and supplies the required scope, accepted evidence, authorized calculation surfaces, prohibited inputs, TRAIN-only rules, OOS application rules, artifact outputs, validation expectations, and leakage attestations. Until that prompt is given, AMD EMA remains a roadmap target only.

## First Candidate Authorization Boundary

No active research candidate is authorized by the foundation closeout, audit artifact readiness work, fold-stability summary contract, returns/performance stop/go gate, or no-trade/reserved-baseline evaluation boundary. Baseline scaffolding is not evidence that an active candidate is ready. It only preserves comparison discipline for the future.

The first active candidate may be proposed or implemented only in a later task after the returns/performance evaluation gate has been explicitly opened for no-trade and reserved baseline-family evaluation discipline, and after the baseline/no-trade comparison boundary has been reviewed. That later task must name the candidate and receive explicit operator approval before any candidate-specific implementation begins.

A first-candidate authorization request must define:

- candidate name and candidate family;
- allowed input artifacts and columns, limited to frozen WFA evidence and accepted handoff-derived artifacts;
- prohibited input artifacts, including raw provider data, credentials, unmanifested cache files, OOS outcome authority, and independent date authority;
- TRAIN-only fit, selection, parameter, and eligibility rules, if any;
- OOS application rules for applying the frozen TRAIN decision without refitting;
- baseline and no-trade comparison scope;
- artifact outputs, schema versions, ignored output locations, and leakage attestations;
- stop conditions for data-health warnings, missing fold coverage, ambiguous fit rules, or any need for out-of-scope modules.

Inside this boundary-definition task, the project still prohibits indicators, returns, labels, regimes, PCA, HMMs, strategy signals, exits, allocation, dashboards, execution, live-order logic, provider expansion, corporate-actions ingestion, earnings-data integration, candidate-specific data sources, or candidate-specific feature engineering. Any future active candidate must preserve `no_trade` as a first-class competitor and consume frozen WFA evidence rather than recomputing authority from Alpaca or raw provider data.

## No-Leakage Rules

The following rules apply to all future WFA implementation work:

- No analytical WFA module may call `Sys.Date()` or independently infer the latest market session.
- No WFA module may call Alpaca or provider helpers directly.
- No transformation may be fit on the full handoff range when it will affect fold-local decisions.
- No feature scaler, state model, volatility threshold, candidate selector, strategy parameter, or eligibility rule may learn from OOS rows for the fold being evaluated.
- No asset may be selected, removed, or weighted because of OOS returns, OOS labels, OOS volatility, OOS drawdown, OOS regime identity, or OOS benchmark comparison.
- No global performance ranking may choose parameters before all folds have been evaluated under predeclared rules.
- No missing-data or stale-data condition may be hidden by reading provider data outside the handoff.
- No baseline may be advantaged or disadvantaged by using a different fold calendar than the active candidate.
- No live-facing decision pack may recompute authority from raw provider data.

If a future implementation needs an internal validation split inside TRAIN, that split must also be fold-local and must end before the fold's OOS window begins.

## Fold-Local Learned Components

Future learned or estimated components are allowed only after the minimal WFA contract is stable. When added, they must follow this pattern:

1. Fit on TRAIN only.
2. Freeze the fitted object, parameters, thresholds, or selected candidate metadata.
3. Apply the frozen object to OOS without refitting.
4. Record fit scope, input columns, training dates, selected parameters, deterministic hashes where practical, and any warnings.

This applies to:

- PCA or any other dimensionality reduction;
- HMMs, clustering models, or regime classifiers;
- volatility filters, volatility thresholds, and volatility-normalization rules;
- feature scalers, winsorization thresholds, missing-value rules, and normalization constants;
- parameter selectors, model selectors, strategy selectors, and asset-ranking rules.

For state assignment, OOS states must be produced by applying the TRAIN-fitted model to OOS data. OOS data must not update the model fit, choose the number of states, rotate PCA loadings, recalibrate thresholds, or change selected parameters for that fold.

## Reserved Baselines

The first WFA contract reserves baseline families rather than one overloaded benchmark. This keeps diagnostics useful without turning every study into a wall of comparisons.

Core baselines should include:

- `no_trade` or cash/no-position;
- broad-market buy-and-hold, initially `SPY` and/or `QQQ` when present in the handoff universe;
- per-asset buy-and-hold when the study asks whether active logic improved on simply holding that asset.

Study-specific baselines may later include:

- fixed equal-weight basket buy-and-hold;
- active basket curation with no additional entry/exit timing;
- active universe selection with otherwise passive holding;
- leverage variants when leverage evaluation is explicitly authorized.

All baselines must use the same fold calendar, handoff artifacts, health gates, and audit discipline as active candidates. The `no_trade` baseline must remain a first-class competitor rather than a fallback hidden inside strategy failure handling.

To avoid clutter, top-level diagnostics should group baselines by the question being asked. Detailed artifacts may preserve every baseline result, but operator-facing summaries should separate core baselines from study-specific baselines.

This planning slice does not implement baseline returns, benchmark performance, allocation, leverage, or selection logic.

The first baseline registry helper returns one declarative row per reserved baseline family. It groups families by research question and diagnostic group, records that returns/performance/allocation are not implemented, and carries source handoff, gate acceptance, fold calendar, health-gate, split-audit, and frozen-evidence linkage fields so future baseline evaluation must use the same WFA discipline as active candidates.

## Minimal Audit Outputs

A future minimal WFA run should emit source-controlled documentation describing its schema before code is added. The first implementation should then write generated artifacts under ignored run paths.

At minimum, the WFA audit surface should include:

- a run manifest linking to the source workbench handoff manifest;
- a fold manifest with every fold boundary and geometry rule;
- a handoff gate result with health status and accepted warnings;
- a fold-local data availability table by symbol;
- a frozen decision evidence artifact for each fold before OOS evaluation;
- a component-fit registry for any learned component added later;
- a candidate or baseline registry that includes `no_trade` and buy-and-hold concepts when evaluation begins;
- an OOS application/evaluation audit that references the frozen fold decision;
- a leakage attestation recording that provider calls, latest-session inference, and OOS fitting were not used.

The minimum schema contract is documentation-first. Source control should describe artifact fields and readiness rules, while generated run evidence remains under ignored paths such as `runs/`. A WFA audit artifact is not ready for returns or performance evaluation unless it records:

- `schema_version`;
- deterministic run, fold, artifact, or registry identifiers where applicable;
- generated artifact path or source artifact path;
- explicit source `as_of_timestamp`;
- explicit source `latest_completed_session`;
- source workbench handoff manifest path or ID;
- fold geometry reference when the artifact is fold-specific;
- handoff gate status, review status, and accepted-warning reference when applicable;
- code revision metadata when available;
- leakage attestation fields for no provider calls, no latest-session inference, no OOS fitting, and no OOS outcome authority.

The artifact-specific readiness contract is:

- Run manifest: links the accepted workbench handoff, requested universe or symbol selection, bounded date range, generated artifact directory, schema versions, code revision, validation status, and the explicit timestamp/session authority inherited from the handoff.
- Fold manifest: records fold IDs, TRAIN/OOS dates, decision cadence, decision-pack validity dates, gap policy, geometry search policy, source handoff reference, source `as_of_timestamp`, and source `latest_completed_session`.
- Handoff gate result: records gate status, health severity, accepted warnings, required artifact paths, canonical bar schema checks, duplicate/future-bar checks, and review acceptance when `REVIEW_REQUIRED`.
- Fold-local availability: records one row per fold and source handoff symbol, TRAIN/OOS row counts and date edges, source missing/partial/stale/warning context, and the declared rule that no OOS performance filtering was used.
- Frozen decision evidence: records fold identity, TRAIN evidence available before OOS, no-active-decision or later frozen-decision status, accepted warning context, leakage attestations, and code revision metadata.
- Baseline or candidate registry: records declarative family or candidate identity, source handoff, gate/fold/evidence linkage, evaluation authorization status, and whether returns, allocation, or live advice remain unimplemented.
- OOS application/evaluation audit placeholder: records the frozen decision reference, OOS window, application status, evaluation authorization status, and required future output path without computing returns or performance values in this slice.
- Leakage attestation: records the artifact scope, source evidence IDs, no provider/network dependency, no independent date authority, no OOS fitting, no OOS-informed symbol filtering, and no recomputation from raw provider data.
- Later aggregate and stability summaries: record only references to already-frozen and already-evaluated OOS records, plus missing/partial fold coverage and warning-context propagation.

Before returns or performance evaluation can be added, a readiness review must confirm required columns, deterministic IDs or paths, schema-version fields, ignored-output locations, source handoff and fold references, explicit timestamp/session authority, and leakage attestations for every generated artifact family. This review must also confirm that default validation remains non-network and that no provider helper, credential path, `Sys.Date()`, or market-clock API is part of WFA artifact creation.

Most durable WFA evidence should be tabular and manifest-driven: per-fold results, aggregate summaries, stability summaries, and links to frozen decision artifacts. Narrative interpretation is useful during development, but it should remain an operator-requested analysis layer rather than a required frozen artifact format.

Frozen decision evidence should answer:

- what input handoff was used;
- what fold was being decided;
- what TRAIN rows were available;
- what rules or fitted objects were learned from TRAIN;
- what candidate, baseline, parameter set, or no-trade decision was selected before OOS;
- who or what accepted any data-health warnings;
- which code revision produced the evidence.

## Deliberately Out Of Scope

This planning slice does not implement or authorize:

- WFA code;
- indicators;
- returns;
- labels;
- regimes;
- PCA;
- HMMs;
- volatility filters;
- feature scalers;
- strategy signals;
- exits;
- allocation;
- dashboards;
- execution;
- live-order logic;
- provider expansion;
- corporate-actions ingestion;
- earnings-data integration;
- leverage reports;
- optimization across fold geometries;
- performance claims.

## Future Build Order

After this planning record is accepted, the first implementation milestone should proceed in small slices:

1. Add a handoff reader/gate that validates a completed workbench handoff without provider calls.
2. Add a quarterly fold-geometry manifest builder that creates explicit rolling TRAIN/OOS windows only.
3. Add train/OOS split tests that prove fold rows are disjoint and bounded by `latest_completed_session`.
4. Add frozen fold-decision evidence scaffolding before any strategy candidate exists.
5. Add reserved baseline-family scaffolding for cash/no-position, broad-market buy-and-hold, per-asset buy-and-hold, fixed basket, and active-curation concepts before active strategy evaluation.
6. Add the first active research candidate only after leakage tests, fold-stability summaries, audit artifacts, baseline/no-trade evaluation discipline, and explicit operator authorization for a named candidate are stable.

Each slice should remain generated-artifact aware and should keep default validation non-network.
