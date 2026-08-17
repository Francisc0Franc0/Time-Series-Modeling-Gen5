# HYP-REG-12.1 Causal Upper-Range Persistence Contract

Status: `STOP_RANGE_PERSISTENCE_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN`

## Question

Can sustained residence in the upper part of an asset's recent price range
identify a usable present-tense trend context that improves only fresh entries
in the unchanged daily SMA8/SMA14 long/cash parent?

This is a regime-context measurement. It is not a direct breakout entry, a
Donchian strategy, or a claim that every recent high will continue.

## Evidence Boundary

- Identifier: `HYP-REG-12.1`.
- Evidence label: `DEVELOPMENT_REUSED_WINDOW`.
- Analysis: 2018-01-02 through 2023-12-29.
- Panel: the frozen 24-stock strategy panel plus SPY and QQQ references.
- Bars: adjusted daily OHLCV with explicit as-of timestamp
  `2026-08-15 17:30:00 America/New_York`.
- Confirmation: 2024-01-02 onward remains sealed unless all development gates
  pass and the operator separately opens confirmation.
- No range length, threshold, persistence rule, or event horizon may be chosen
  from strategy outcomes.

## Literature Ledger

| Source | Grounding | What it authorizes | What it does not authorize |
|---|---|---|---|
| Brock, Lakonishok, and LeBaron (1992), *Simple Technical Trading Rules and the Stochastic Properties of Stock Returns*, Journal of Finance 47, pp. 1731-1764 | <https://doi.org/10.1111/j.1540-6261.1992.tb04681.x> | Treating moving-average and trading-range break rules as testable hypotheses and comparing them with explicit null models | This exact 63-session state, thresholds, equity panel, or trading overlay |
| Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, Journal of Financial Economics 104, pp. 228-250 | <https://doi.org/10.1016/j.jfineco.2011.11.003> | The economic plausibility of persistent own-price direction across assets | Calling range residence an independent source of alpha or selecting parameters after observing returns |
| Sullivan, Timmermann, and White (1999), *Data-Snooping, Technical Trading Rule Performance, and the Bootstrap*, Journal of Finance 54, pp. 1647-1691 | <https://doi.org/10.1111/0022-1082.00163> | Treating broad technical-rule searches as a multiple-testing problem | Searching many channel lengths until one works |

The exact POC is operator-designed from this literature family. It is not
presented as a published strategy from any cited paper.

## Stage A — Frozen Measurement

At close `t`, use the preceding 63 completed closes, excluding `t`:

```text
L_t  = min(P_(t-63), ..., P_(t-1))
H_t  = max(P_(t-63), ..., P_(t-1))
RP_t = (P_t - L_t) / (H_t - L_t)
```

`RP_t` is not clipped. Values above one are upside range escapes and values
below zero are downside escapes.

For each date, define `upper_now = RP_t >= 0.75`. The primary state is
`UPPER_PERSISTENT` when `upper_now` is true and at least three of the latest
five causal `upper_now` observations are true. A symmetric
`LOWER_PERSISTENT` state uses `RP_t <= 0.25` and exists for construction and
falsification only. All other finite observations are `OTHER`.

An upside breakout event begins only when `RP_t > 1` after the preceding date
was not above one. Its boundary is frozen at `H_t`. The event ledger lasts ten
sessions including the event date and records only information available so
far: age, fixed boundary, fraction of event closes above the boundary, deepest
breach, and retests from above to at/below the boundary. A new high cannot
reset the boundary or extend the event. Completed-event outcomes may inspect
the following ten sessions for measurement validation, but those outcomes are
never inputs to the contemporaneous state or strategy.

Stage A requires:

1. complete causal data coverage with 2024+ absent;
2. clean synthetic up/down paths classified in the intended persistent state
   on at least 90% of paths;
3. synthetic breakout-hold and breakout-fail paths distinguished correctly
   on at least 90% of paths;
4. price-scale invariance within `1e-12`;
5. exact append invariance;
6. zero state, transition, fixed-boundary, or event-window semantic violations;
7. at least 20/24 primary stocks with `UPPER_PERSISTENT` occupancy between 10%
   and 60%, and at least 18/24 with three eligible fresh SMA cross-ups.

## Stage B — Frozen Strategy Contact

- Parent: unchanged daily SMA8/SMA14 long/cash.
- Signal: fresh close-date SMA8-above-SMA14 cross.
- Entry: next open, 1x long, only when the signal date is
  `UPPER_PERSISTENT`.
- A rejected signal is skipped, not deferred.
- Exit: next open after the unchanged parent SMA8-below-SMA14 cross.
- No breakout-driven direct entry, candidate-driven exit, leverage, shorting,
  sizing, ATR join, or parameter grid.
- Costs: 5 bp per side primary; 10 bp per side stress.
- Annual cells reset at each asset-year start and compound internally.
- Baselines: unfiltered parent, buy-and-hold, and cash.
- Controls: 200 deterministic within-asset/year circular rotations of the
  complete eligibility schedule; select 40 exposure-nearest controls using
  exposure only before inspecting returns.

## Gates and Stop Rules

All nine common strategy gates remain required: causal integrity, exact parent
reproduction, construction integrity, median return above parent, at least
15/24 stocks improved, at least 4/6 positive median-excess years, no worse
median drawdown and Sharpe, positive absolute median return, and at least an
80th-percentile return versus exposure-nearest controls.

Do not rescue failure by changing 63 sessions, 0.75/0.25, three-of-five, the
event definition or horizon, the parent, assets, costs, ATR%, leverage, or the
2024+ boundary. A direct breakout strategy, if later desired, must open a
separate `HYP-MOM` lane.

## Explicit Exclusions

- Intraday bars, high/low-based channels, ATR buffers, volume confirmation,
  volatility expansion, or parameter optimization.
- Direct entry on `RP_t > 1` or exit on loss of the breakout boundary.
- Combining T1-T4 measurements or choosing the most favorable earlier lane.
- HMMs; the post-series literature-first HMM bookmark remains unopened.

## Completed Readout

All 7/7 construction gates passed. The synthetic path families recovered the
intended trend and breakout semantics perfectly; causality, price-scale
invariance, state definitions, and fixed event boundaries were exact. All
24/24 primary stocks had usable occupancy and at least three eligible fresh
SMA cross-ups. Median `UPPER_PERSISTENT` occupancy was 38.3%.

The hard entry gate passed only 3/9 strategy gates. Median annual return fell
from 8.95% for the parent to 0.00%; only 1/24 stocks and 1/6 years improved;
median Sharpe fell from 0.642 to -0.132; and actual timing ranked at the 61.3rd
percentile of exposure-nearest controls. The state reduced drawdown by moving
capital to cash, but did not preserve return. Parent entries already in
`UPPER_PERSISTENT` had a 43.1% hit rate and -0.68% median trade return.

Record `STOP_RANGE_PERSISTENCE_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN`.
Retain the descriptive range and event ledgers, do not rescue the hard policy,
and keep 2024+ sealed. The T1-T5 series is complete without a promoted trend
entry filter, making the bookmarked literature-first HMM discussion eligible
but not yet implemented.
