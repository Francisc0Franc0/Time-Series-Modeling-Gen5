# Literature Studies

This top-level area is the home of strategy research whose primary hypothesis
source is operator-supplied literature. It is intentionally separate from the
organically developed Gen5.x system lineage.

The separation is intellectual, not methodological. Literature studies still
use Gen5's explicit as-of timestamps, point-in-time discipline, frozen
TRAIN/OOS boundaries, transaction-cost accounting, falsification controls,
human-facing evidence, and STOP decisions.

## Current scope

The current lineage covers `LIT-MR-01.1` through `LIT-MR-06.1` and momentum
concepts `LIT-MOM-01.1` through `LIT-MOM-02.1`, grounded primarily in:

- Ernest P. Chan, *Algorithmic Trading: Winning Strategies and Their
  Rationale*; and
- Michael L. Halls-Moore, *Successful Algorithmic Trading*.

Start with:

- [research nomenclature](docs/GEN5_LITERATURE_GROUNDED_STRATEGY_RESEARCH_NOMENCLATURE.md);
- [source ledger](docs/GEN5_LITERATURE_SOURCE_LEDGER.md);
- [workflow handoff](docs/GEN5_LITERATURE_GROUNDED_POC_HANDOFF.md); and
- the concept-specific contracts under [docs](docs/).

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
