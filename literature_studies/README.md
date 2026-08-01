# Literature Studies

This top-level area is the home of strategy research whose primary hypothesis
source is operator-supplied literature. It is intentionally separate from the
organically developed Gen5.x system lineage.

The separation is intellectual, not methodological. Literature studies still
use Gen5's explicit as-of timestamps, point-in-time discipline, frozen
TRAIN/OOS boundaries, transaction-cost accounting, falsification controls,
human-facing evidence, and STOP decisions.

## Current scope

The current lineage covers `LIT-MR-01.1` through `LIT-MR-06.1` and the first
momentum concept, `LIT-MOM-01.1`, grounded primarily in:

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
