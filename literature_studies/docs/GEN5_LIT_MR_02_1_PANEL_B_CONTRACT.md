# LIT-MR-02.1 PANEL-B Contract

## Status

`COMPLETED_STOP`

The registry and mechanics below were frozen before any PANEL-B outcomes were
computed. PANEL-A remains immutable and was not reopened, pooled, or
overwritten.

Final status:

`STOP_LIT_MR_02_1_PANEL_B_NO_FULL_PASS`

## Readout

The frozen run packet is:

`runs/research_workbench/literature_grounded/lit_mr_02_1_panel_b_20260728`

All 28 unique symbols refreshed successfully and every pair passed requested
2016-2020 coverage. The pre-refresh cache-health warning records the cold or
partial cache state before that refresh; it does not indicate missing bars in
the completed evidence packet.

- `0 / 15` pairs passed all eight gates.
- `0 / 15` pairs had a positive primary-cost mean net trade return.
- The median mean net trade return was `-13.64 bp` per completed trade.
- `15 / 15` passed integrity and two-sided trade support.
- `14 / 15` passed the positive-beta coverage gate; `XRT-XLY` was `94.3%`.
- `0 / 15` passed cost-aware return and uncertainty, hit rate, matched
  random-sign separation, or robust forward convergence.
- `3 / 15` passed the pragmatic three-of-five-year stability gate:
  `IHI-XLV`, `XRT-XLY`, and `XBI-IBB`.
- Four pairs had negative forward-convergence point estimates, but every
  bootstrap interval crossed zero, so none passed the mechanism gate.

The result is a broad, economically varied rejection of the exact 20-session
adaptive raw-price zero-crossing template on TRAIN. It does not prove that
relative-value mean reversion is impossible, and it does not authorize a
reactive rescue of this variant.

## Research Question

Does the unchanged literature-derived 20-session adaptive raw-price spread
template generalize across 15 additional relationships drawn from defensive,
cyclical, real-estate, health-care, financial, industrial, and commodity-linked
exposures?

This is deliberately broader exploration, not a search for a winning pair.
Every pair, orientation, category, mechanic, cost, inference method, and gate is
fixed before the PANEL-B run.

## Frozen Registry

The first symbol is \(Y\); the second is \(X\) in
\(S_t=Y_t-\beta_tX_t\).

| Pair ID | Pair | Category | Ex-ante rationale |
|---|---|---|---|
| `B01_XLP_VDC` | `XLP-VDC` | Sector near substitute | Two consumer-staples sector implementations |
| `B02_XLU_VPU` | `XLU-VPU` | Sector near substitute | Two utilities-sector implementations |
| `B03_XLRE_VNQ` | `XLRE-VNQ` | Sector near substitute | Real-estate sector versus broad US REIT exposure |
| `B04_XLI_VIS` | `XLI-VIS` | Sector near substitute | Two industrials-sector implementations |
| `B05_XLY_VCR` | `XLY-VCR` | Sector near substitute | Two consumer-discretionary implementations |
| `B06_XLE_VDE` | `XLE-VDE` | Sector near substitute | Two energy-equity implementations |
| `B07_XLV_VHT` | `XLV-VHT` | Sector near substitute | Two broad health-care implementations |
| `B08_XLF_VFH` | `XLF-VFH` | Sector near substitute | Two broad financial-sector implementations |
| `B09_XLB_VAW` | `XLB-VAW` | Sector near substitute | Two materials-sector implementations |
| `B10_ITA_XAR` | `ITA-XAR` | Industry related exposure | Differently weighted aerospace and defense portfolios |
| `B11_IHI_XLV` | `IHI-XLV` | Industry related exposure | Medical devices versus broad health care |
| `B12_XRT_XLY` | `XRT-XLY` | Industry related exposure | Retail versus broad consumer discretionary |
| `B13_XHB_ITB` | `XHB-ITB` | Industry related exposure | Differently concentrated homebuilder portfolios |
| `B14_XBI_IBB` | `XBI-IBB` | Industry related exposure | Differently weighted biotechnology portfolios |
| `B15_GDX_GLD` | `GDX-GLD` | Producer/commodity link | Gold-miner equities versus physical gold |

All are established US-listed ETFs. The registry intentionally emphasizes
industry and sector structure rather than individual high-beta equities.

## Unchanged Mechanics

Every pair uses the exact `LIT-MR-02.1` rule:

- Alpaca adjusted daily OHLCV only;
- explicit as-of `2026-07-24 17:30:00`;
- TRAIN `2016-01-04` through `2020-12-31`;
- 20-session rolling OLS of adjusted close \(Y\) on \(X\);
- spread \(S_t=Y_t-\beta_tX_t\), without subtracting the intercept;
- 20-session rolling spread mean and sample standard deviation;
- enter long spread below \(-1z\), short spread above \(+1z\);
- exit on zero crossing;
- signal after close and trade at the next open;
- daily adaptive rehedging and one gross-normalized unit;
- 5 bp per one-way weight change, with the existing stress-cost diagnostic;
- the same seeded trade bootstrap, forward bootstrap, and matched random-sign
  control; and
- the same eight TRAIN gates.

Pair indices `101` through `115` produce deterministic seeds distinct from
PANEL-A.

## Eight-Gate Design Logic

All eight remain required for a full pair pass, but their roles differ.

### Firm admissibility gates

1. **Integrity:** all frozen data, timing, position, partition, and accounting
   checks pass. This is non-negotiable leakage and implementation hygiene.
2. **Positive-beta coverage:** at least 95% after warm-up. This preserves the
   intended opposite-leg relative-value semantics.
3. **Trade support:** at least 30 completed trades, with at least 10 long and
   10 short. This prevents conclusions from a thin or one-sided sample.

### Economic robustness gates

4. **Cost-aware return and uncertainty:** mean net trade return is positive
   and its 95% moving-block-bootstrap lower bound exceeds zero.
5. **Hit rate:** completed-trade hit rate exceeds 50%. This is useful for this
   convergence hypothesis, but it is not a universal profitability law.
6. **Random-sign separation:** observed mean net return exceeds the matched
   random-sign p90. This tests whether signal direction adds value.
7. **Calendar stability:** primary-cost bar return is positive in at least
   three of five TRAIN years. The `3 / 5` threshold is a pragmatic stability
   hurdle, not a theorem.

### Mechanism-confirmation gate

8. **Forward convergence:** z-score versus next-five-session fixed-beta spread
   return is negative and its 95% bootstrap upper bound is below zero. This
   tests the specific convergence prediction rather than relying on PnL alone.

The books motivate the trading rule, costs, trade/bar evaluation, hit-rate,
stability, uncertainty, and statistical diagnostics. They do not publish this
eight-gate checklist. The exact thresholds, conjunction, random-sign control,
bootstrap definitions, and Gen5 integrity requirements are project-designed.

## Multiplicity And Interpretation

Testing 15 additional pairs increases the probability that at least one result
looks attractive by chance. Therefore:

- every pair is reported in frozen registry order;
- no pair is deleted, added, or reoriented after outcomes;
- outcome-ranked tables are not the primary evidence surface;
- one full pass is not strategy acceptance;
- a full pass permits only discussion of a pair-specific sealed confirmation
  contract; and
- no development or confirmation outcome is opened in PANEL-B.

If no pair passes all eight gates, record
`STOP_LIT_MR_02_1_PANEL_B_NO_FULL_PASS`.

If at least one pair passes, record
`REVIEW_REQUIRED_LIT_MR_02_1_PANEL_B_PAIR_SPECIFIC_CONFIRMATION`.

## Prohibited Rescue

After PANEL-B outcomes are inspected, do not:

- choose a pair from the largest observed return;
- add similar pairs to amplify one favorable category;
- change pair orientation;
- alter the 20-session window, transform, thresholds, exit, or costs;
- weaken an individual gate or the all-eight requirement;
- pool PANEL-A and PANEL-B as though the batch boundary were not sequential;
- open later partitions, allocation, live shorting, or live behavior.
