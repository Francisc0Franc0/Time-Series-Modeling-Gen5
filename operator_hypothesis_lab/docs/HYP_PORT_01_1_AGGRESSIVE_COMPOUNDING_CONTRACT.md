# HYP-PORT-01.1 — Aggressive compounding portfolio comparison

## Evidence boundary

This is a retrospective, descriptive portfolio-policy proof of concept. It asks whether a deliberately diversified aggressive-growth portfolio would have offered a more attractive historical return/risk shape than concentrated ownership of AMD, NVDA, and TSLA. It does not search for an edge, establish investability, provide live advice, or authorize capital.

The comparison contract below was frozen before the outcome data were run.

## Primary policy

| Sleeve | Target weight |
|---|---:|
| SCHG | 50% |
| QUAL | 20% |
| XSD | 15% |
| AMD | 5% |
| NVDA | 5% |
| TSLA | 5% |

The design intentionally combines a broad growth core, a quality diversifier, a semiconductor sleeve, and three small conviction positions. The ETF sleeves contain overlapping exposures. Current look-through holdings informed the economic motivation, but historical constituent-level look-through is not available from the OHLCV dataset and is not tested here.

## Frozen comparison set

1. Aggressive policy with quarterly review, 20% relative drift bands, and a forced annual target-weight restore.
2. The same six assets and starting weights, then left untouched as a buy-and-hold control.
3. Equal-weight AMD/NVDA/TSLA buy-and-hold.
4. SCHG buy-and-hold.
5. QQQM buy-and-hold.
6. SPY buy-and-hold as a broad-market diagnostic baseline.

## Timing and execution

- Explicit as-of timestamp: `2026-09-03 10:30:00 America/Los_Angeles`.
- Query begins: 2020-10-13.
- Initial allocation decision: 2020-10-14.
- First executable portfolio interval begins at the next common open after that decision.
- Evaluation ends: 2026-09-02.
- Primary history is intentionally limited to QQQM's actual history. QQQ is not backfilled as a proxy.
- Canonical inputs are Alpaca adjusted daily OHLCV bars.
- Returns are open-to-open so that the decision/execution boundary remains explicit.
- One-way transaction cost assumption: 5 basis points on traded notional, including the initial allocation.

## Rebalancing rule

The policy is reviewed on the first common trading session of each calendar quarter, using only weights observable at the prior close. A rebalance occurs when any invested sleeve is more than 20% above or below its target weight. The first session of each calendar year forces a target-weight restore regardless of drift. The order is executed at that session's open.

The no-rebalance variant isolates the value or cost of the governance rule from the value of the initial asset mix.

## Admission gates

- All eight required symbols must be present: SCHG, QUAL, XSD, AMD, NVDA, TSLA, QQQM, and SPY.
- All records must be adjusted daily bars with finite, positive opens and closes.
- Symbol/session rows must be unique.
- Every symbol must cover the frozen beginning and end dates.
- The common-session panel must begin and end on the frozen dates and retain at least 99.5% of SPY's sessions in the window.
- All target vectors must sum to one.

If a gate fails, no performance interpretation is admitted.

## Descriptive outputs

The packet will report growth of one dollar, CAGR, annualized volatility, zero-cash Sharpe ratio, maximum drawdown, maximum underwater duration, worst 63-session and 252-session returns, calendar returns, rolling three-year annualized returns, turnover, and rebalance events. These are descriptive historical measurements, not hypothesis-test statistics.

## Known limitations

- The start date is constrained by QQQM, producing a relatively short and unusually growth-friendly/hostile mixed era rather than a full-cycle proof.
- The selected portfolio and weights reflect present-day operator judgment and therefore carry design hindsight.
- Historical ETF constituents and look-through concentration caps are not tested.
- Taxes, spreads beyond the fixed cost allowance, market impact, account constraints, fractional-share limitations, and recurring contributions are not modeled.
- No parameter search, statistical inference, walk-forward validation, sealed confirmation sample, or prospective test is opened.
- The three single-stock positions and overlapping ETF holdings can still create substantial technology and semiconductor concentration.

## Decision after this slice

Use the result to decide whether the policy deserves a separately frozen robustness and contribution-policy study. Do not tune weights or rebalance bands in response to this first outcome.
