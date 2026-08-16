# HYP-REG-08.1 Rolling Variance-Ratio Persistence Contract

Status: `EXECUTED_FROZEN_CONTRACT`

## Question

Can a causally measured `HIGH` relative positive-return-dependence state improve
fresh next-open entries in the unchanged daily SMA8/SMA14 long/cash parent?

This lane tests return dependence, not direction. The SMA parent continues to
own direction; variance ratio is allowed only to judge entry eligibility.

## Evidence Boundary

- Evidence label: `DEVELOPMENT_REUSED_WINDOW`.
- Analysis: 2018-01-02 through 2023-12-29.
- Panel: the audited 24-stock strategy panel plus SPY and QQQ references.
- Bar authority: adjusted daily OHLCV with explicit as-of timestamp
  `2026-08-15 17:30:00 America/New_York`.
- Confirmation: 2024-01-02 onward remains sealed unless every frozen
  strategy-relative development gate passes and the operator separately opens
  confirmation.
- The provider supplied 503 prehistory sessions. The preferred buffer was 550,
  but the exact 252-return estimator and prior-252-score rank were retained.
  Early states remain `NA`; neither window is shortened or backfilled.

## Stage A — Measurement

- Use adjusted-close log returns.
- Estimate the finite-sample-adjusted overlapping Lo-MacKinlay variance ratio
  from the prior 252 completed returns.
- Primary aggregation scale: `q = 5`.
- Durability-only scale: `q = 10`; it cannot replace or rescue `q = 5`.
- Report the heteroskedasticity-robust z statistic and p-value. P-values are
  descriptive only and never gate capital.
- Rank the current robust z-score against the prior 252 completed z-scores,
  excluding the current score.
- Signed hysteresis:
  - enter `HIGH` when `z > 0` and percentile `>= 70`; remain while `z > 0` and
    percentile `>= 60`;
  - enter `LOW` when `z < 0` and percentile `<= 30`; remain while `z < 0` and
    percentile `<= 40`;
  - otherwise assign `MEDIUM` when the score is finite.

Construction must pass synthetic IID, heteroskedastic IID, negatively
autocorrelated, and positively autocorrelated calibration; append invariance;
signed-state semantics; coverage; and state usability before strategy access.

## Stage B — Frozen Strategy Contact

- Parent: daily SMA8/SMA14 long/cash.
- Signal: fresh close-date SMA8-above-SMA14 cross.
- Entry: next open, 1x long, only when the close-date variance-ratio state is
  `HIGH`.
- A rejected signal is skipped, not deferred.
- Exit: next open after the unchanged parent SMA8-below-SMA14 cross.
- No variance-ratio-driven exit or position sizing.
- Primary friction: 5 bp per side; stress: 10 bp per side.
- Annual cells reset at the start of each asset-year and compound within the
  cell.
- Baselines: unfiltered parent, buy-and-hold, and cash.
- Controls: 200 deterministic within-asset/year circular state rotations;
  select the 40 exposure-nearest rotations by exposure only before comparing
  returns.

## Strategy Gates

All nine are required: causal integrity, exact parent reproduction,
construction integrity, median return above parent, at least 15/24 stocks
improved, at least 4/6 positive median-excess years, no worse median drawdown
and Sharpe, positive absolute median return, and at least an 80th-percentile
return versus exposure-nearest timing controls.

No threshold, horizon, asset, strategy, ATR join, leverage, allocation, or
confirmation rescue is permitted after development outcomes are read.

## Literature Anchors

- Ernest P. Chan, *Algorithmic Trading: Winning Strategies and Their
  Rationale* (2013), printed pp. 44–46 / PDF pp. 62–64.
- Lo and MacKinlay (1988), “Stock Market Prices Do Not Follow Random Walks”:
  <https://web.mit.edu/~alo/www/Papers/lo-mackinlay-88.html>.
- Lo and MacKinlay (1989), “The Size and Power of the Variance Ratio Test in
  Finite Samples”:
  <https://web.mit.edu/Alo/www/Papers/lo-mackinlay-89.html>.
