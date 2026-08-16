# HYP-REG-05.2 ADX Strategy-Relative Overlay Contract

Status: `FROZEN_FOR_DEVELOPMENT_EXECUTION`

## Where This Fits

`HYP-REG-05.1` rejected a specific forecasting claim: causal, asset-relative
ADX(14) did not predict a straighter next-open H10/H20 price path. It also
showed that ADX states were operationally coherent, with balanced occupancy,
about 14 switches per year, an 11.5-session median run, and no one-session
reversals.

`HYP-REG-05.2` asks a different, strategy-relative question. A state does not
need to forecast itself far into the future if it causally changes which action
is preferable until the next decision. This derivative therefore tests whether
the observed ADX state adds value to one unchanged long-only momentum policy.
It is not a rescue or reinterpretation of the failed `05.1` path forecast.

## Question

Does permitting fresh daily SMA8/SMA14 entries only when the signal-close ADX
state is `HIGH` improve the unchanged parent strategy? After admission, does
reactively exiting at the next open when ADX leaves `HIGH` add protection or
only turnover?

## Frozen Identity

- Lane: `HYP-REG-05`
- Version: `HYP-REG-05.2`
- Name: ADX Strategy-Relative Present-State Utility Overlay
- Parent state: `HYP-REG-05.1` ADX(14), prior-252 percentile, 30/40/60/70
  hysteresis
- Parent strategy: `HYP-MOM-06.1` daily SMA8/SMA14 long/cash crossover
- Evidence stage: `DEVELOPMENT_REUSED_WINDOW`

The decimal increment is substantive because the descriptive ADX state may now
control strategy entry permission and, in one predeclared challenger, exit
permission. No ADX or SMA mechanics change.

## Data Authorities and Causal Join

1. ADX labels come unchanged from the completed `HYP-REG-05.1` daily ledger.
   A state dated `t` is known only after that close.
2. SMA signals and next-open executions use the retained daily surface
   reconstructed from admitted Alpaca SIP regular-session 30-minute bars for
   `HYP-MOM-06.1`.
3. A signal observed after close `t` may alter the position only at open
   `t+1`.
4. The parent strategy calendar retains the ten globally excluded SIP archive
   gap sessions documented in `D126`. Admission requires 1,499 strategy
   sessions, 1,509 state sessions, zero strategy dates lacking a state, and ten
   state-only dates per asset.
5. The runner must reproduce the unfiltered parent asset-year returns within
   `1e-10` before overlay evidence is interpreted.

## Frozen Universe and Window

- Registry: the same 26 assets used by `HYP-REG-05.1`.
- Primary decision panel: 24 registered stocks.
- Reference-only: SPY and QQQ.
- DEVELOPMENT: 2018-01-02 through 2023-12-29, evaluated as six calendar-year
  asset cells.
- 2024-01-02 and later remain sealed.
- Every asset begins each calendar year in cash and requires a fresh in-year
  crossover before entry.

## Parent Strategy Mechanics

- SMA8 and SMA14 of reconstructed daily close.
- Fresh `SMA8 > SMA14` cross after close: candidate next-open entry.
- Fresh `SMA8 <= SMA14` cross after close: next-open exit.
- Long/cash, 1x only.
- No deferred entry, stop, target, holding cap, or additional confirmation.

## Frozen Policies

### `UNFILTERED`

The exact parent strategy.

### `ENTRY_HIGH_ONLY` — primary

- Execute a fresh parent entry only when the signal-close ADX state is `HIGH`.
- Skip fresh entries in `LOW` or `MEDIUM`.
- A skipped entry is not deferred.
- Once admitted, ADX changes do not alter the open trade.
- The parent cross-down remains the ordinary exit.

This policy isolates whether the present state selects better entry
opportunities.

### `REACTIVE_HIGH_ONLY` — predeclared challenger

- Use the same `HIGH`-only fresh-entry rule.
- Exit at the next open after either the parent cross-down or the signal-close
  ADX state leaves `HIGH`.
- Parent cross-down receives the exit-reason label when both events coincide.
- After an ADX exit, do not re-enter while SMA8 remains above SMA14. A new
  parent cross-up is required.

This policy directly tests the operator's reactive-state intuition while
preserving the parent's fresh-cross entry identity.

`MEDIUM/HIGH`, raw-ADX thresholds, rising-ADX rules, percentile grids, delayed
exits, state dwell rules, re-entry on state recovery, and ER combinations are
prohibited.

## Accounting

- Initial wealth: $100,000 per asset-year cell.
- Primary: 1x, 5 bp per side.
- Stress: 1x, 10 bp per side.
- Profits and losses compound within each annual cell.
- Report return, Sharpe, maximum drawdown, exposure, turnover, trade count,
  hit rate, mean/median trade, holding duration, and underwater behavior.
- Only primary-cost evidence governs the decision.

## Baselines and Timing Controls

Direct baselines:

- unchanged `UNFILTERED` SMA8/SMA14;
- buy-and-hold under the same cost convention;
- cash.

For each overlay policy separately:

- create 200 deterministic circular shifts of the complete within-asset,
  within-year ADX-state sequence on the strategy calendar;
- preserve state occupancy and serial run structure while breaking historical
  alignment with crossovers;
- select the 40 shift IDs whose stock-panel median exposure is nearest the
  actual policy, using exposure only;
- report the actual policy's midrank return percentile and excess over those
  controls' median.

Shifted states are noncausal null controls, not executable alternatives.

## Required Diagnostics

- parent-reproduction and calendar-integrity audits;
- policy-level annual, six-year asset, and calendar summaries;
- entry-state audit of all parent trades;
- reactive exit-reason audit, including avoided-loss and false-exit examples;
- matched/circular timing-control evidence for each policy;
- representative AMD, TSLA, improvement, degradation, protective-exit, and
  missed-continuation tapes where distinct examples are available;
- human-facing charts, results document, and sourced evidence deck.

## Frozen Gates

Each overlay is evaluated independently. All eight gates must pass to open a
confirmation discussion:

1. **Integrity:** complete 26-asset causal join, 24-stock primary panel, known
   1,499/1,509 calendar pattern, no missing entry/held states, and no 2024+.
2. **Parent reproduction:** all 156 unfiltered asset-year rows match the
   retained parent within `1e-10`.
3. **Panel return:** stock-panel median annual return exceeds `UNFILTERED`.
4. **Asset breadth:** at least 15 of 24 stocks improve six-year compounded
   return.
5. **Calendar breadth:** median excess is positive in at least four of six
   years.
6. **Protection and risk adjustment:** median maximum drawdown is no worse and
   median Sharpe is no lower than `UNFILTERED`.
7. **Absolute viability:** median annual return remains positive.
8. **State specificity:** actual median return is at or above the 80th
   percentile of its 40 exposure-nearest circular controls and exceeds their
   median.

If neither policy passes, record
`STOP_ADX_STRATEGY_RELATIVE_GATES_FAILED_CONFIRMATION_NOT_RUN`. If one passes,
record only `PASS_TO_CONFIRMATION_DISCUSSION`; confirmation still requires a
separate operator decision.

## Prohibited Scope

Do not:

- reinterpret `05.1` as a successful future-path forecast;
- tune ADX/SMA lengths, percentiles, hysteresis, state eligibility, or exits;
- select assets, years, policies, or tapes as authority after inspection;
- stack ATR%, ER, breadth, volatility, volume, or another filter;
- add leverage, sizing, allocation, portfolio construction, or live behavior;
- inspect 2024+ confirmation data.
