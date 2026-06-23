# Gen5 Minimal WFA Contract Plan

## Context

This planning record follows the Gen5 v0 market-data-layer closeout and the Gen5 v0.1 Research Data Workbench closeout. The workbench can now produce adjusted daily bar handoff artifacts for later research consumers.

The first minimal WFA milestone must consume those handoff artifacts without calling Alpaca, inferring latest sessions, or recomputing provider authority. This document defines the contract and build order only. It does not implement WFA code.

## Scope

This first WFA planning slice is documentation-only. It defines:

- fold geometry and train/OOS separation rules;
- allowed inputs from the workbench handoff;
- no-leakage rules for fold creation, fitting, selection, and evaluation;
- how later fold-local learned components must be fit on TRAIN only and applied to OOS;
- baseline concepts to reserve;
- minimal audit outputs and frozen decision evidence;
- what remains out of scope until separately authorized.

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

## Fold Geometry Contract

The minimal WFA engine should start with one explicit rolling geometry supplied by configuration or a run manifest. It should not search across multiple geometries in the first implementation slice.

A fold geometry record must include:

- `fold_id`;
- `train_start_date`;
- `train_end_date`;
- `oos_start_date`;
- `oos_end_date`;
- train window length rule;
- OOS window length rule;
- any intentional gap between TRAIN and OOS;
- selected symbols or universe reference;
- source handoff manifest path or ID;
- source `as_of_timestamp`;
- source `latest_completed_session`.

The first implementation should use the canonical `session_date` calendar visible in the handoff bars. Calendar construction is allowed only from handoff data and manifest metadata. It must not call market-clock APIs or infer latest sessions.

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

The first WFA contract reserves at least two baseline concepts:

- `no_trade` or cash/no-position;
- buy-and-hold.

Both baselines must use the same fold calendar, handoff artifacts, health gates, and audit discipline as active candidates. The `no_trade` baseline must remain a first-class competitor rather than a fallback hidden inside strategy failure handling.

This planning slice does not implement baseline returns, benchmark performance, allocation, leverage, or selection logic.

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
2. Add a fold-geometry manifest builder that creates explicit rolling TRAIN/OOS windows only.
3. Add train/OOS split tests that prove fold rows are disjoint and bounded by `latest_completed_session`.
4. Add frozen fold-decision evidence scaffolding before any strategy candidate exists.
5. Add reserved baseline scaffolding for cash/no-position and buy-and-hold concepts before active strategy evaluation.
6. Add the first active research candidate only after leakage tests and audit artifacts are stable.

Each slice should remain generated-artifact aware and should keep default validation non-network.
