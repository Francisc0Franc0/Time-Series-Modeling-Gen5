# TSLA Signed-ER20-Conditioned Return Geometry

## Question

Do the fixed UP, SIDEWAYS, and DOWN signed-ER20 states separate TSLA's
prior-versus-future cumulative-return grid, including the previously observed
difference between positive- and negative-prior branches?

## Frozen Design

- Prior and following horizons: `1, 2, 3, 4, 5, 10, 15, 20, 25` sessions.
- Signed ER20:
  `(log_close[t] - log_close[t-20]) / sum(abs(one-session log moves))`.
- UP: signed ER20 `>= +0.30`; SIDEWAYS: between `-0.30` and `+0.30`; DOWN:
  signed ER20 `<= -0.30`.
- The state is known at anchor close `t`; every following-return window begins
  at `t+1`.
- The 2018-2023 TSLA window, daily adjusted bars, log returns, and 9 by 9
  horizon grid are unchanged.
- No window, cutoff, horizon, sample, or state-persistence search was performed.

## Structural Dependency

At prior horizon `p=20`, signed ER20 and the prior return use the same signed
20-session displacement. Every `p=20` UP observation therefore has a positive
prior return, and every `p=20` DOWN observation has a negative prior return.
The opposite-sign branches are structurally empty, not null results. They are
marked `NE` and excluded from the multiplicity families.

This dependence also becomes visible before `p=20`: opposite-sign branch counts
fall below 30 at prior horizons 10, 15, 20, and 25 in the UP and DOWN states.
The SIDEWAYS state retains both signs across the full grid.

## Aggregate State Grid

- DOWN contains the only within-state multiplicity-robust island: `18/81`
  slope tests pass the state-family BH correction. UP and SIDEWAYS pass `0/81`.
- The DOWN survivors occupy prior horizons 10-25 and following horizons 3-25,
  with the strongest concentration in the long/long corner.
- The strongest cell is DOWN, prior 20 / following 20: Pearson `-0.5757`, OLS
  slope `-0.9917`, `n=183`, state-family BH q approximately `1.32e-9`, and
  global q approximately `1.07e-8`.
- Mean following 20-session log return in that cell is `+5.61%`, and
  P(following return > 0) is `61.2%`. Because all prior returns are negative in
  that state, the negative slope means deeper preceding declines align with
  stronger subsequent rebounds. It is not downside continuation.
- DOWN-minus-SIDEWAYS has `24/81` pair-family BH survivors. Its largest
  correlation contrast is `-0.5512` at prior 20 / following 20, with
  pair-family q `0.0054` and global q `0.0105`.
- UP-minus-SIDEWAYS and UP-minus-DOWN have no pair-family survivors.

## Prior-Sign Branch Grid

- Estimable positive-versus-negative slope interactions are DOWN `45/81`,
  SIDEWAYS `81/81`, and UP `45/81` after requiring at least 30 observations per
  branch.
- All `17` within-state sign-interaction BH survivors occur in DOWN states at
  prior horizons 1-5.
- The strongest estimable branch contrast is DOWN, prior 5 / following 20:
  negative-prior Pearson `-0.3413`, positive-prior Pearson `+0.4707`, and
  positive-minus-negative Pearson `+0.8120`. The direct slope interaction is
  `+4.0578`, with family q `0.0016` and global q `0.0017`.
- Mean following return is positive in both branches in that cell (`+5.75%`
  after a negative prior and `+4.98%` after a positive prior). The interaction
  describes different within-branch slopes, not a realized return spread.

The short-prior branch separation and longer-prior aggregate rebound island are
related two-scale views of the DOWN state, but they are not the same test.

## Multiplicity Readout

There are `657` estimable tests in the strict global pool. After BH correction
across that pool:

- `16` state-slope tests retain q `< 0.05`;
- `13` state-pair interactions retain q `< 0.05`; and
- `8` prior-sign interactions retain q `< 0.05`.

The family-level results remain the primary interpretation because each family
corresponds to a distinct question. The global pool is a stricter audit, not a
replacement for the predeclared family structure.

## Interpretation

The principal new shape is conditional rebound geometry in signed-ER20 DOWN
states. It is not the intuitive story that a clean uptrend should continue.
Splitting unsigned green/trending ER20 into direction resolves an important
aggregation: the surprising reversal structure lives primarily in trending
down paths.

This is the strongest descriptive separation in the recent TSLA microscope,
but it is still not an edge:

- signed ER20 and the prior-return predictor share trailing-path data;
- DOWN contains only `183` anchor sessions and multiple overlapping windows;
- horizon cells are nested rather than independent replications;
- a negative slope does not by itself establish positive expectancy after
  drift, execution timing, and costs; and
- no later period or other asset has yet tested transport.

Freeze this as an unexpected in-sample rebound finding. Do not tune the ER
window/cutoff or formulate a trading rule from it.

## Artifacts

- Packet:
  `runs/research_workbench/operator_hypothesis_lab/tsla_signed_er20_conditioned_grid_20260826`
- Script:
  `scripts/inspect/run_tsla_signed_er20_conditioned_grid.R`
- Calculation helpers:
  `operator_hypothesis_lab/R/tsla_signed_er20_grid.R`
- Running evidence deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`
