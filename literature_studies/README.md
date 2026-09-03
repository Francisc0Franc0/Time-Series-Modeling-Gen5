# Literature Studies

This top-level area is the home of strategy research whose primary hypothesis
source is operator-supplied literature. It is intentionally separate from the
organically developed Gen5.x system lineage.

The separation is intellectual, not methodological. Literature studies still
use Gen5's explicit as-of timestamps, point-in-time discipline, frozen
TRAIN/OOS boundaries, transaction-cost accounting, falsification controls,
human-facing evidence, and STOP decisions.

## Current scope

The current lineage covers `LIT-MR-01.1` through `LIT-MR-06.1`, momentum
concepts `LIT-MOM-01.1` through `LIT-MOM-02.1`, and HMM regime concepts
`LIT-REG-01.1` through the forecast-first directional `LIT-REG-02.2`. The
earlier lanes are grounded primarily in:

- Ernest P. Chan, *Algorithmic Trading: Winning Strategies and Their
  Rationale*; and
- Michael L. Halls-Moore, *Successful Algorithmic Trading*.

Start with:

- [research nomenclature](docs/GEN5_LITERATURE_GROUNDED_STRATEGY_RESEARCH_NOMENCLATURE.md);
- [shared intraday momentum roadmap](../docs/GEN5_INTRADAY_MOMENTUM_RESEARCH_ROADMAP.md);
- [source ledger](docs/GEN5_LITERATURE_SOURCE_LEDGER.md);
- [workflow handoff](docs/GEN5_LITERATURE_GROUNDED_POC_HANDOFF.md); and
- the concept-specific contracts under [docs](docs/).

`LIT-REG-01.1` adds a separately inventoried HMM/regime-switching source set:
Rabiner, Zucchini et al., Hamilton, Ang--Timmermann, Pohle et al., and
implementation/applied references. Its frozen first POC uses SPY daily log
return and log normalized true range, a one-state Gaussian and static
two-component mixture as required baselines, a two-state HMM as primary, and
a three-state HMM as a complexity-controlled diagnostic. Stage A passed seven
of eight gates but stopped because only 77 of 100 synthetic fits were valid;
SPY was not read. See the
[contract](docs/GEN5_LIT_REG_01_1_HMM_REGIME_POC_CONTRACT.md),
[results](docs/GEN5_LIT_REG_01_1_HMM_STAGE_A_RESULTS.md), and
[model registry](registries/gen5_lit_reg_01_1_hmm_model_registry.csv).

`LIT-REG-01.2` preserves that STOP and narrows the next exercise to one
volatility observation: TRAIN-standardized log single-session normalized true
range. It compares a two-state Gaussian HMM against a one-state Gaussian, a
static two-component mixture, and a Gaussian AR(1). The approved
`HiddenMarkov` 1.8-14 package is an independent local numerical authority;
Gen5 separately recomputes causal likelihoods and probabilities. Stage A
passed five of eight gates: all 20 strong simulations were recovered with
99.1% median causal state accuracy, but only 3/20 weak and 1/20 null cases
abstained, while 36/60 cases ended as numerical failures. Record
`STOP_LIT_REG_01_2_REFERENCE_OR_SYNTHETIC_GATES_FAILED_MARKET_DATA_NOT_READ`;
SPY, 2024+, and strategy data were not read. See the
[contract](docs/GEN5_LIT_REG_01_2_HMM_VOLATILITY_STATE_POC_CONTRACT.md),
[results](docs/GEN5_LIT_REG_01_2_HMM_VOLATILITY_STAGE_A_RESULTS.md), and
[model registry](registries/gen5_lit_reg_01_2_hmm_volatility_model_registry.csv),
with the
[evidence deck](presentations/gen5_lit_reg_01_2_hmm_volatility_stage_a_evidence.pptx)
as the concise teaching and review surface.

`LIT-REG-02.1` is the package-native directional proof-of-mechanism. It fits a
two-state Markov-switching Gaussian AR(1) with `hmmTMB 1.1.2` and forecasts
the probability of a positive cumulative 20-session return. All ten teaching
cases produced valid, deterministic, causal fits. The HMM beat both frozen
probability baselines on Brier score and log loss in nine of ten cases, but
median hard-state accuracy was only 72.1% and the transition-error tail missed
its gate. Record
`STOP_LIT_REG_02_1_DIRECTIONAL_MECHANISM_QUALIFICATION_FAILED`; the detection
frontier, financial-shaped stress, market data, and strategy data were not
run. See the
[decision note](docs/GEN5_LIT_REG_02_1_DIRECTIONAL_HMM_DECISION.md),
[contract](docs/GEN5_LIT_REG_02_1_DIRECTIONAL_HMM_POC_CONTRACT.md),
[results](docs/GEN5_LIT_REG_02_1_DIRECTIONAL_HMM_STAGE_A_RESULTS.md), and
[model registry](registries/gen5_lit_reg_02_1_directional_hmm_model_registry.csv),
with the
[evidence deck](presentations/gen5_lit_reg_02_1_directional_hmm_stage_a_evidence.pptx)
as the concise teaching and review surface.

`LIT-REG-02.2` preserves that STOP and asks a different question: whether soft
H20 probabilities replicate under fresh evidence and beat B0, B1, and a
fixed-ridge B2. All eight fresh confirmation gates passed. Only 2/16 frontier
cells formally detected, no null cell did, and H2 lost mean advantage over B0
and B1 under Student-t/GARCH stress. Record
`COMPLETE_LIT_REG_02_2_SYNTHETIC_FORECAST_FRONTIER_MAPPED_MARKET_NOT_OPENED`.
See the
[decision](docs/GEN5_LIT_REG_02_2_DIRECTIONAL_FORECAST_DECISION.md),
[contract](docs/GEN5_LIT_REG_02_2_DIRECTIONAL_FORECAST_POC_CONTRACT.md),
[results](docs/GEN5_LIT_REG_02_2_DIRECTIONAL_FORECAST_RESULTS.md), and
[registry](registries/gen5_lit_reg_02_2_directional_forecast_model_registry.csv).
The
[evidence deck](presentations/gen5_lit_reg_02_2_directional_forecast_frontier_evidence.pptx)
is the concise teaching and review surface.

## Layout

```text
literature_studies/
├── R/                  # Literature-study analysis modules
├── scripts/            # Operator launchers and evidence builders
├── tests/testthat/     # Dedicated non-network tests
├── presentations/      # Human-facing evidence and textbook-exercise decks
└── docs/               # Source ledger, nomenclature, contracts, and readouts
```

Generated evidence packets remain under
`runs/research_workbench/literature_grounded/`. They are ignored research
artifacts rather than source files. The original `LIT-MR-01.1` packet retains
its historical `retail_quant_mechanisms/` location.

Shared infrastructure remains at the repository root. Literature launchers
may source canonical data, cache, calendar, and workbench helpers from `R/`
and `scripts/lib/`, but literature-specific strategy mechanics must live here.

`LIT-MR-06.1` is a narrowly approved research-only intraday exception. Its
minute-entry helper and evidence remain literature-specific; it does not
change the root adjusted-daily provider contract or any live-facing behavior.
The completed ten-panel TRAIN atlas produced no full pass, so DEVELOPMENT was
not queried. See the [results note](docs/GEN5_LIT_MR_06_1_BUY_ON_GAP_RESULTS.md)
and [evidence deck](presentations/gen5_lit_mr_06_1_buy_on_gap_evidence.pptx).

The subsequent
[recent-wide replication](docs/GEN5_LIT_MR_06_1_RECENT_WIDE_ATLAS_02_RESULTS.md)
kept those mechanics unchanged and tested a frozen 305-stock union plus all
eleven sector panels on 2023-2024 TRAIN. The combined panel improved to 7/8
gates, +4.12% primary return, and 56.2% up/down accuracy, but its uncertainty
lower bound remained negative. Record
`STOP_LIT_MR_06_1_RECENT_WIDE_ATLAS_02_NO_FULL_PASS`; 2025-June 2026
DEVELOPMENT was not queried. See the
[evidence deck](presentations/gen5_lit_mr_06_1_recent_wide_atlas_02_evidence.pptx).

`LIT-MOM-01.1` reconstructs Chan's Chapter 6 interday time-series-momentum
workflow. It first evaluates the frozen 49-cell lookback/holding table on
TRAIN, then trades exactly one selected rule with daily overlapping swing
sleeves. The SHY screen selected `60/5`; all six TRAIN gates passed, but the
frozen 2021-2023 DEVELOPMENT replay finished essentially flat after ordinary
costs and negative under stress. Keep `250/25` as the canonical literature
reference, record `OOS_DEVELOPMENT_COMPLETE_LIT_MOM_01_1`, and stop before
2024+ CONFIRMATION. See the
[contract](docs/GEN5_LIT_MOM_01_1_INTERDAY_TIME_SERIES_MOMENTUM_POC_CONTRACT.md),
[results](docs/GEN5_LIT_MOM_01_1_INTERDAY_MOMENTUM_RESULTS.md), and
[evidence deck](presentations/gen5_lit_mom_01_1_interday_momentum_evidence.pptx).

`LIT-MOM-01.2` is the operator-origin, long-only execution variant of that
same signal. It keeps the open TRAIN horizon search and causal next-open
timing, but only a positive selected-lookback return may enter one fully
invested, fixed-quantity long trade held for exactly `H` open-to-open
intervals; negative or zero signals mean cash. Each next trade compounds from
current equity. TRAIN again selected `60/5`. In the explicitly retrospective
2021-2023 SHY replay, 69 long trades earned +0.22% gross but lost 6.46% after
literal 5 bp-per-side round trips and 12.70% under stress. Record
`RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2`; this is an implementation
lesson, not fresh confirmation. See the
[contract](docs/GEN5_LIT_MOM_01_2_SINGLE_POSITION_RETROSPECTIVE_CONTRACT.md),
[results](docs/GEN5_LIT_MOM_01_2_SINGLE_POSITION_RETROSPECTIVE_RESULTS.md), and
[authoritative evidence deck](presentations/gen5_lit_mom_01_2_long_only_retrospective_evidence.pptx).
The earlier same-named long/short implementation and its deck are archived as
`PRE_CORRECTION_LONG_SHORT_DIAGNOSTIC`, not current `01.2` evidence.

SHY is only the worked mechanics example. The substantive
`LIT-MOM-01.2 / STOCK_ATLAS_01_RETROSPECTIVE` exercise reused the frozen
22-stock, eleven-sector panel and independently searched all 49 TRAIN `L/H`
cells for every asset before replaying its own winner. The 1,078-cell search
produced ten distinct selected horizons, so `60/5` was not imposed on the
panel. Sixteen of 22 long-only retrospective paths were positive after primary
costs; median primary return was +17.96%, mean return was +23.82%, and the
worst drawdown was -49.73%.
Record
`RETROSPECTIVE_EXPLORATION_COMPLETE_LIT_MOM_01_2_STOCK_ATLAS_01`; do not
promote the strongest names, form a portfolio, or treat the known
2021-2023 window as fresh OOS evidence. See the
[atlas contract](docs/GEN5_LIT_MOM_01_2_STOCK_ATLAS_01_RETROSPECTIVE_CONTRACT.md)
and the combined results and evidence deck above.

`LIT-MOM-01.2 / STOCK_ATLAS_02_2020_BREADTH_ATTENTION` added 100 frozen,
non-overlapping names: a 75-name sector-diversified core from SPY's June 30,
2020 SEC filing and 25 names documented in contemporaneous retail-attention
sources. Ninety-one names had eligible coverage; 50 were primary-positive and
47 stress-positive. Median primary return was +6.92% overall, +11.69% in the
eligible diversified core, and -19.95% in the smaller attention cohort.
These are retrospective cohort descriptions, not asset-selection or causal
evidence. See the
[Atlas 02 contract](docs/GEN5_LIT_MOM_01_2_STOCK_ATLAS_02_2020_BREADTH_ATTENTION_CONTRACT.md),
[registry](registries/gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv),
and combined results and authoritative deck above.

`LIT-MOM-01.2 / AUDIT_01_EXPOSURE_AND_SELECTION` then tested whether those
positive raw paths reflected incremental timing value. Across 113 stocks, only
30 beat buy-and-hold and 29 beat an exposure-matched constant policy. Median
excess versus buy-and-hold was -13.31 percentage points; median matched-random
percentile was 48.6%; selected horizons beat fixed `60/5` but not canonical
`250/25`; and only 54/113 SPY-regression intercepts were positive. The frozen
scorecard passed 2/11. Record
`STOP_LIT_MOM_01_2_AUDIT_01_NO_INCREMENTAL_TIMING`. Environment cells remain
descriptive and may not be converted into filters on 2021-2023. See the
[audit contract](docs/GEN5_LIT_MOM_01_2_AUDIT_01_EXPOSURE_SELECTION_CONTRACT.md),
[audit results](docs/GEN5_LIT_MOM_01_2_AUDIT_01_EXPOSURE_SELECTION_RESULTS.md),
and [audit deck](presentations/gen5_lit_mom_01_2_audit_01_exposure_selection_evidence.pptx).

The frozen representative-tape addendum then selected eight deliberately
contrasting paths before inspecting them: `SHY`, `HD`, `UNP`, `F`, `TJX`,
`META`, `AAL`, and `NKE`. The tapes distinguish cost erosion, ordinary
exposure, missed recovery, concentrated winners, severe drawdown dependence,
cyclicality, and possible selective loss avoidance. Record
`RETROSPECTIVE_DESCRIPTIVE_TRADE_TAPE_REVIEW_COMPLETE` without changing the
Audit 01 STOP or nominating a filter. See the
[trade-tape results](docs/GEN5_LIT_MOM_01_2_AUDIT_01_TRADE_TAPE_REVIEW_RESULTS.md)
and [review deck](presentations/gen5_lit_mom_01_2_audit_01_representative_trade_tapes.pptx).

`LIT-MOM-01.3` returns to the direct prediction question before any trading
policy. It freezes `SPY` and a 28-cell surface formed from seven Chan-style
lookbacks and four confirmable swing targets. Every cell uses a trailing
adjusted-close log-return predictor and causal next-open-to-exit-open target;
`250/25` remains the literature anchor rather than a forced SPY horizon. A
global circular-shift maximum-statistic test must pass before a deterministic
sandbox nominee can be frozen, and only that nominee may later receive the
single locked-confirmation test. The already inspected 2017-2023 history is
sandbox only; 2024-2025 remains locked behind a later operator gate, and all
2026 targets remain outside the card. The frozen sandbox subsequently failed:
its best correlation was `0.016240` versus a `0.177058` circular-shift
maximum p90 threshold. Record
`STOP_LIT_MOM_01_3_SANDBOX_NO_SEARCH_ADJUSTED_PREDICTIVE_SURFACE`, nominate no
cell, and preserve confirmation. See the
[hypothesis card](docs/GEN5_LIT_MOM_01_3_MINIMAL_SPY_PREDICTOR_HYPOTHESIS_CARD.md)
and [results](docs/GEN5_LIT_MOM_01_3_SPY_HORIZON_SURFACE_RESULTS.md).

`LIT-MOM-01.4` broadens that predictor-only question across the complete
previously frozen 92-instrument opening-gap registry without reusing its
intraday rule. The atlas keeps 68 plain ETFs, six leveraged/inverse ETFs, and
18 survivor-limited stock challengers in separate evidence strata. It uses
2017-2020 only to select one positive cell per eligible asset, tests exactly
that cell in 2021-2023, and applies 10% Benjamini-Hochberg control separately
within each stratum. SPY is a reproduction reference, not a candidate.
The frozen execution admitted all 92 assets and produced 79 fixed-cell
DEVELOPMENT tests. Twelve of 60 non-SPY plain-ETF tests, two of five
engineered-ETF tests, and five of 13 stock tests had positive correlations,
but no asset survived within-stratum BH control. Record
`STOP_LIT_MOM_01_4_NO_FDR_CONTROLLED_TRANSPORT`; preserve sealed 2024-2025
confirmation and open no strategy or performance surface. See the
[contract](docs/GEN5_LIT_MOM_01_4_MULTI_MARKET_PREDICTOR_ATLAS_CONTRACT.md)
and [results](docs/GEN5_LIT_MOM_01_4_MULTI_MARKET_PREDICTOR_ATLAS_RESULTS.md).

`LIT-MOM-01.5` is the frozen diagnostic sibling authorized after the `01.4`
STOP. It compares constant TRAIN drift, raw trailing return, and a compact
path-quality extension containing positive-move efficiency and shock
concentration. All 24 nondegenerate cells are equally weighted rather than
searched, DEVELOPMENT loss differences receive stationary-block inference
and within-stratum FDR control, and 2024-2025 remains sealed. The previously
stopped ER/ADX future-path test is acknowledged rather than reopened. The
frozen execution retained 2,184 complete cells across 91 assets: drift had the
lowest loss for 77, raw return for 13, and path quality for one. No raw or
path-quality comparison survived the complete controlled gate. Record
`STOP_LIT_MOM_01_5_NO_INCREMENTAL_PATH_QUALITY_FORECAST`, preserve
confirmation, and see the
[contract](docs/GEN5_LIT_MOM_01_5_PATH_QUALITY_FORECAST_COMPARISON_CONTRACT.md)
and [results](docs/GEN5_LIT_MOM_01_5_PATH_QUALITY_FORECAST_COMPARISON_RESULTS.md).

The approved
[LIT-IMOM-01.2 contract](docs/GEN5_LIT_IMOM_01_2_30MIN_PATH_QUALITY_FORECAST_COMPARISON_CONTRACT.md)
transports that forecast comparison into the existing adjusted SIP 30-minute
panel without multiplying horizons by thirteen. It preserves the numeric
24-cell grid in bar units, adds a parallel TRAIN-fitted bar-slot control,
performs inference on whole-session averages, and keeps 2024+ sealed. No
`01.2` forecast outcome was read before the contract was frozen. The complete
execution retained all 26 instruments and 624 cells. Baseline models were
lowest-loss for 21/26 instruments in both chains, raw return for five, and
path quality for none; zero raw or path clues survived the controlled gates.
Record `STOP_LIT_IMOM_01_2_NO_CLOCK_CONTROLLED_PATH_QUALITY_FORECAST` and see
the [results](docs/GEN5_LIT_IMOM_01_2_30MIN_PATH_QUALITY_FORECAST_COMPARISON_RESULTS.md).

The approved
[LIT-IMOM-01.3 contract](docs/GEN5_LIT_IMOM_01_3_SAME_SLOT_RELATIVE_MOMENTUM_CONTRACT.md)
opens a distinct minimal question: does a stock's SPY-relative return in one
30-minute slot forecast the same slot on the next session? It fixes one
session lag, pools all 13 regular slots, controls both target-slot seasonality
and prior full-session relative momentum, and requires the same-slot model to
beat the best of all twelve wrong-clock alignments. The 22 diverse stocks form
the candidate family; AMD, TSLA, and QQQ remain diagnostic-only, SPY is the
benchmark, and 2024+ remains sealed. No `01.3` outcome was read before the
contract was frozen.
The frozen execution admitted 731 TRAIN and 735 DEVELOPMENT target sessions.
At the equal-weight 22-stock panel level, prior-day, same-slot-over-prior-day,
same-slot-over-clock, and same-slot-over-best-placebo loss contrasts were all
negative with strictly negative 90% intervals. Zero assets survived. Record
`STOP_LIT_IMOM_01_3_NO_CLOCK_SPECIFIC_RELATIVE_MOMENTUM` and see the
[results](docs/GEN5_LIT_IMOM_01_3_SAME_SLOT_RELATIVE_MOMENTUM_RESULTS.md).
The complete five-test learning sequence is consolidated in the
[momentum predictor evidence-series deck](presentations/gen5_momentum_predictor_evidence_series.pptx),
which separates daily own-return continuation, daily and 30-minute path
quality, and same-slot clock recurrence with explicit transition slides and
STOP states.

The subsequent
[stock breadth replication](docs/GEN5_LIT_MOM_01_1_STOCK_ATLAS_01_RESULTS.md)
kept those mechanics unchanged across a frozen 22-stock, eleven-sector panel.
Only `HD` passed all six TRAIN gates with a selected `10/10` rule. Its sole
authorized 2021-2023 replay retained 58.7% directional accuracy and positive
past/future correlation but lost 5.86% after primary costs and 9.82% under
stress. Record `OOS_DEVELOPMENT_COMPLETE_LIT_MOM_01_1_STOCK_ATLAS_01` and
stop before CONFIRMATION; the atlas is breadth evidence, not stock-selection
or portfolio authority. See the
[contract](docs/GEN5_LIT_MOM_01_1_STOCK_ATLAS_01_CONTRACT.md) and
[evidence deck](presentations/gen5_lit_mom_01_1_stock_atlas_01_evidence.pptx).

The point-in-time
[2016 high-beta replication](docs/GEN5_LIT_MOM_01_1_STOCK_ATLAS_02_HIGH_BETA_2016_RESULTS.md)
then froze all 99 common-equity constituents from SPHB's October 31, 2016 SEC
Schedule of Investments. Eighty-four had exact TRAIN coverage and 11 passed
all six gates; XEC then received an OOS coverage STOP after its acquisition.
Every one of the ten complete 2021-2023 replays lost money. Pooled long sleeves
were 54.3% directionally correct with positive mean net return, while short
sleeves were only 43.0% correct with negative mean net return. Record
`OOS_DEVELOPMENT_COMPLETE_LIT_MOM_01_1_STOCK_ATLAS_02_HIGH_BETA_2016` and stop
before CONFIRMATION. The asymmetry is a useful lesson, not post-hoc authority
to remove shorts. See the
[contract](docs/GEN5_LIT_MOM_01_1_STOCK_ATLAS_02_HIGH_BETA_2016_CONTRACT.md)
and
[evidence deck](presentations/gen5_lit_mom_01_1_stock_atlas_02_high_beta_2016_evidence.pptx).

`LIT-MOM-02.1` recapitulates Chan's Example 7.1 opening-gap momentum rule and
then translates it causally: observe the opening auction at 09:31 ET, enter at
the 09:32 adjusted minute-bar open, and exit at the close. None of the eight
small-POC anchors or 92 wide-atlas instruments passed all eight TRAIN gates.
`XLP` reached 7/8 with a positive uncertainty bound and +15.54% primary return,
but its 20 bp stress path was -5.49%; it was not promoted. Record
`STOP_LIT_MOM_02_1_OPENING_GAP_NO_TRAIN_NOMINEE`; DEVELOPMENT was not queried
and 2024+ CONFIRMATION remains sealed. See the
[contract](docs/GEN5_LIT_MOM_02_1_OPENING_GAP_MOMENTUM_CONTRACT.md) and
[results](docs/GEN5_LIT_MOM_02_1_OPENING_GAP_MOMENTUM_RESULTS.md), with the
[evidence deck](presentations/gen5_lit_mom_02_1_opening_gap_evidence.pptx) as
the concise human-facing review surface.

`LIT-MOM-03.1` opens a distinct dual-momentum lane from Quantpedia's July 2026
practitioner video and May 2026 Active Dual Momentum GTAA article, grounded by
the broader academic cross-sectional and time-series momentum literature. The
opening [study deck](presentations/gen5_lit_mom_03_1_dual_momentum_study.pptx)
records why earlier single-asset Gen5 nulls can coexist with a weak
portfolio-level momentum tendency, the “fleet rather than one leaf” intuition,
the extra hurdle faced by long-only timing against drift, matched exposure,
SPY, and buy-and-hold, and the exact published nine-ETF, 10/25-week,
top-three, positive-momentum-only mechanics. It also records the evidence
boundary: the source selected its final specification after inspecting
multiple horizons and breadths on the same 2007-2026 history, so a recent
publication date does not make that backtest independent confirmation. Record
`MECHANICS_REPRODUCTION_PASS_LOCAL_WINDOW_PUBLISHED_WINDOW_BLOCKED`. The exact
ranking, positive-veto, one-sixth-slot, duplicate-sleeve, holiday-fallback,
and next-open designation mechanics now produce a 508-week allocation tape on
clean adjusted Alpaca data from 2016-06-29 through 2026-03-18. The attempted
refresh still returned no pre-2016 bars, so the publisher's 2008-2015 segment
remains an explicit coverage STOP. The expanded 18-slide deck and
[mechanics results](docs/GEN5_LIT_MOM_03_1_DUAL_MOMENTUM_MECHANICS_RESULTS.md)
show that 463/508 weeks were fully invested, mean cash weight was 2.56%, and
the two sleeves shared at least one ETF in 488/508 weeks. These are allocation
descriptors only. The subsequently authorized
[causal replay](docs/GEN5_LIT_MOM_03_1_DUAL_MOMENTUM_REPLAY_RESULTS.md) covers
507 weekly next-open intervals through 2026-03-19 at 5 bps per one-way traded
notional. The source rule reached 3.053x wealth, 12.17% net CAGR, and -15.45%
maximum drawdown. It beat equal-weight all nine on the point estimates and
cut SPY's drawdown roughly in half, but trailed SPY's 14.36% CAGR. Most
importantly, it was virtually identical to relative-only: average invested
weight was 97.44%, so the absolute veto added almost nothing in this window.
Record
`RETROSPECTIVE_VALUE_ADD_REPLAY_COMPLETE_NO_ROBUSTNESS_OR_FORWARD_AUTHORITY`.
The result motivates a separately frozen robustness discussion, not an edge
claim or forward promotion.

The follow-up
[universe-transport POC](docs/GEN5_LIT_MOM_03_2_UNIVERSE_TRANSPORT_RESULTS.md)
keeps the exact 10/25-week, top-three, Wednesday-close, next-open, and 5-bps
rule while changing only the ranking fleet. One clean ten-sector-ETF universe
and eleven pre-existing eight-stock sector baskets each contribute 507 weekly
intervals. Source dual momentum returned 8.53% CAGR in sector ETFs versus
11.98% for equal weight. It beat equal-weight CAGR in only 1/11 stock sectors,
while producing shallower drawdown in 6/11. Relative only beat source in all
twelve fleets; the positive-momentum gate behaved as costly defense rather
than a broad return enhancer. The stock baskets remain static survivor-biased
exploratory POCs. Record
`UNIVERSE_TRANSPORT_POC_COMPLETE_DESCRIPTIVE_ONLY`; no inference, parameter
search, point-in-time stock membership, robustness, or forward gate is open.

The authorized
[broad cross-sector stock-fleet POC](docs/GEN5_LIT_MOM_03_3_BROAD_STOCK_FLEET_RESULTS.md)
then allowed all 88 static atlas stocks to compete together. It preserved the
source selection fraction as 29-of-88 per 10-week and 25-week sleeve without a
top-N search. Relative-only rotation reached 17.95% net CAGR versus 17.04% for
equal-weight ownership of all 88, a descriptive +0.90-point ranking lift. The
positive-return gate reduced the full source rule to 16.69% CAGR but improved
maximum drawdown to -24.83%, versus -28.57% for relative-only and -32.51% for
equal weight. Record
`BROAD_CROSS_SECTOR_STOCK_FLEET_POC_COMPLETE_DESCRIPTIVE_ONLY`. The static
survivor-biased universe prevents promotion; no inference, robustness,
point-in-time membership, or forward authority is open.

## Running checks

Run only the literature-study tests with:

```powershell
& 'C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe' -e ".libPaths(c(normalizePath('.codex_r_libs', winslash='/'), .libPaths())); testthat::test_dir('literature_studies/tests/testthat')"
```

The repository-wide wrapper also runs this suite:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test/run_tests.ps1
```

## Future book sets

Do not create author- or book-specific subtrees preemptively. When a second
genuinely distinct literature lineage is opened, split this umbrella by
source set and preserve existing `LIT-[FAMILY]-[CONCEPT].[VARIANT]`
identifiers and evidence paths rather than renaming prior results.
