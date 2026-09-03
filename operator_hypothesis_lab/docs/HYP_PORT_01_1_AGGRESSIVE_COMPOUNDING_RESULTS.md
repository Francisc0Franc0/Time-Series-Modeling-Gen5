# HYP-PORT-01.1 — Aggressive compounding portfolio comparison results

## Status

`PORTFOLIO_POLICY_POC_COMPLETE_DESCRIPTIVE_ONLY`

All 12 data and timing gates passed. The final cache-only replay reported `INFO` health, retained 100% of SPY's sessions on the common panel, and used 1,478 common sessions from 2020-10-14 through 2026-09-02. The first tradable interval began at the 2020-10-15 open.

## What was compared

- Aggressive policy: 50% SCHG, 20% QUAL, 15% XSD, and 5% each AMD/NVDA/TSLA; quarterly review, 20% relative drift bands, annual target restore.
- The same starting mix with no subsequent rebalancing.
- Equal-weight AMD/NVDA/TSLA.
- SCHG.
- QQQM.
- SPY as a diagnostic baseline.

Every variant used the same open-to-open interval and a 5-basis-point one-way cost on traded notional.

## Descriptive outcome

| Variant | Net CAGR | Annualized volatility | Zero-cash Sharpe | Maximum drawdown | Worst 252 sessions | Ending wealth |
|---|---:|---:|---:|---:|---:|---:|
| Aggressive policy | 22.56% | 25.84% | 0.920 | -39.77% | -35.90% | 3.31x |
| Same mix, no rebalance | 23.03% | 27.75% | 0.889 | -40.77% | -37.48% | 3.38x |
| Equal-weight AMD/NVDA/TSLA | 42.23% | 47.26% | 0.985 | -63.94% | -62.19% | 7.94x |
| SCHG | 16.28% | 22.57% | 0.784 | -35.79% | -33.79% | 2.43x |
| QQQM | 17.29% | 22.50% | 0.825 | -36.69% | -34.44% | 2.56x |
| SPY | 16.04% | 16.83% | 0.971 | -26.28% | -19.10% | 2.40x |

The aggressive policy occupied the intended middle ground. It gave up 19.66 percentage points of CAGR versus the concentrated trio while improving maximum drawdown by 24.17 points and reducing volatility by 21.42 points. It exceeded QQQM by 5.27 points of CAGR, but its maximum drawdown was 3.08 points worse. It exceeded SPY by 6.53 points of CAGR while accepting 13.49 points of additional maximum drawdown.

The result is not a clean dominance claim. SPY's zero-cash Sharpe was slightly higher, and the concentrated trio's extraordinary realized upside kept its Sharpe above the proposed policy despite much worse drawdown. The proposed policy is better described as an aggressive concentration reducer than a risk-adjusted-return winner.

## What the rebalance control taught us

The governance rule did not create return in this sample. The rebalanced policy trailed the untouched starting mix by 0.47 percentage points of CAGR. In exchange it reduced annualized volatility by 1.91 points, improved maximum drawdown by 1.00 point, improved the worst 252-session return by 1.58 points, and raised zero-cash Sharpe from 0.889 to 0.920.

The policy generated 18 allocation events and 1.62x total one-way turnover including inception. This is consistent with governance acting as modest risk containment rather than a return engine.

## Plain-English interpretation

The comparison supports the portfolio's basic purpose, but not an optimized-strategy claim. Historically, it preserved meaningfully more growth than SCHG, QQQM, or SPY while avoiding the deepest pain of owning only AMD, NVDA, and TSLA. It did not make aggressive investing gentle: a roughly 40% drawdown and a 517-session maximum underwater stretch remain severe.

The biggest lesson is that diversification can change the shape of the ride without eliminating the central bet. SCHG, XSD, and the three stocks overlap economically, so this remains a technology- and semiconductor-heavy portfolio. Rebalancing kept sleeve weights from drifting indefinitely, but the initial asset mix explains almost all of the historical growth result.

## Evidence boundary

This is one retrospective window beginning with QQQM's actual history. The weights were chosen with present-day knowledge, the period is short, 2020 and 2026 are partial calendar years, and historical ETF look-through holdings were not reconstructed. Taxes, recurring contributions, account frictions, parameter variation, walk-forward tests, sealed confirmation, and forward observation remain unopened.

Do not tune the weights or rebalance bands from this result. A next slice, if opened, should test the policy idea rather than optimize this exact sample: predeclare a small number of economically different allocation controls, extend history without synthetic QQQM backfill where possible, and separate lump-sum from recurring-contribution behavior.

## Evidence packet

The ignored run packet is at `runs/research_workbench/operator_hypothesis_lab/hyp_port_01_1_aggressive_compounding_20260903/`.
