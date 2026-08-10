# HYP-MOM SMA Follow-Up Research Series Contract

Status: `FROZEN_AND_EXECUTED_NO_DEVELOPMENT_NOMINEE`

## Purpose

This series follows `HYP-MOM-02.1` and `HYP-MOM-02.2`. It asks whether their
drawdown behavior contains a genuine timing mechanism or mainly reflects time
spent in cash. It remains long-only, adjusted-daily, next-open, and swing
oriented. It does not open portfolio construction, allocation, leverage, live
advice, or execution automation.

## Evidence sequence

| Stage | Window | Authority |
|---|---|---|
| Attribution discovery | 2021-01-04 through 2023-12-29 | Reused-window diagnostics only |
| Historical development | 2016-01-04 through 2020-12-31 | Distinct historical replication; survivor-biased and not forward confirmation |
| Strategy-specific confirmation | 2024-01-02 through 2025-12-31 | At most one completely frozen nominee |
| Sealed | 2026-01-02 onward | Must not be queried by this series |

All stages use the frozen combined 122-name registry without replacement, 220
sessions of causal indicator warm-up, explicit as-of timestamp
`2026-08-07 17:30:00 America/New_York`, 5 bp primary and 10 bp stress costs per
side, full-capital single-asset compounding, idle cash at zero, and causal
completed-close signals executed at the next open.

### Pre-outcome development-data feasibility amendment

The frozen Alpaca feed returned complete 2016-2020 bars for 114 registry names
but no observations before 2016, even after a bounded refresh. This was learned
before any development strategy outcome was computed. Therefore development
keeps the declared 2016-2020 data boundary, uses each eligible asset's first 220
observed sessions strictly for causal indicator warm-up, starts that asset in
cash on the following session, and evaluates through 2020-12-31. Assets missing
any session inside 2016-2020 remain excluded without replacement. This does not
change a signal, parameter, cost, candidate, parent, gate, or later evidence
window; it makes the already-declared warm-up operational under available data.

## Attribution policies

`HYP-MOM-02 / ATTRIBUTION_ATLAS_01` recomputes five policies on the reused
2021-2023 window:

1. `FRESH_021`: fresh SMA200 entry; exit below SMA200; new SMA200 cross re-entry.
2. `ENTRY_CONFIRMATION`: entry additionally requires close above SMA50; exit
   remains below SMA200.
3. `EXIT_LOCKOUT`: any fresh SMA200 entry; exit below SMA50; new SMA200 cross
   required after exit.
4. `COMPOSITE_022`: qualified SMA200 entry above SMA50; exit below SMA50; new
   SMA200 cross required.
5. `REENTRY_REPAIR_023`: initial qualified SMA200 entry and SMA50 exit; after
   the first completed trade, a new SMA50 reclaim while above SMA200 may
   re-enter without waiting for another SMA200 cross.

The atlas also measures every fresh SMA200 cross over fixed 5-, 20-, and
60-session next-open horizons: absolute, SPY-relative, and sector-relative
returns, up/down accuracy, MFE, MAE, and non-overlapping-event sensitivity.
Nothing in the attribution atlas can authorize promotion.

## Development candidates

### HYP-MOM-02.3 — repaired re-entry

- First entry: fresh SMA200 cross whose signal close is above SMA50.
- Exit: first completed close at or below SMA50.
- Re-entry after the first exit: first completed cross back above SMA50 while
  close remains above SMA200.
- Every signal executes at the next open.
- Declared parent for development gates: `COMPOSITE_022`.

### HYP-MOM-03.1 — SMA200 regime / SMA50 pullback reclaim

- Permission: close above SMA200 and `SMA200(t) > SMA200(t-20)`.
- Setup and entry: a completed cross from at/below SMA50 to above SMA50 while
  permission is true; buy next open.
- Exit: first completed close at/below SMA50, at/below SMA200, or loss of the
  frozen rising-SMA200 permission; sell next open.
- A later valid SMA50 reclaim may re-enter.
- Declared parent for development gates: `FRESH_021`.

## Development gates

A candidate may enter the context atlas only if all gates pass on 2016-2020:

1. integrity and causal-timing checks all pass;
2. median asset return is positive at both primary and stress costs;
3. median excess return over exposure-matched circular controls is positive;
4. median observed circular-control percentile is at least 0.60;
5. at least 55% of eligible assets have positive primary return;
6. at least 55% improve primary return versus their declared parent;
7. equal-asset aggregate return is positive in at least three of five years;
8. median trade count is at least three and no sector supplies more than 35%
   of positive aggregate contribution;
9. median maximum drawdown is not worse than the parent by more than two
   percentage points.

If neither candidate passes, no context strategy or confirmation is run. If
both pass, the candidate with the higher median excess over matched controls is
nominated; ties break by asset breadth, then lower drawdown.

## Context atlas

The nominated base, if any, is evaluated on development data under three
one-at-a-time diagnostics:

1. `MARKET_SECTOR_ALIGNMENT`: SPY and the asset's sector ETF are above rising
   SMA200 anchors at entry.
2. `RELATIVE_STRENGTH_126`: the asset's trailing 126-session return exceeds its
   sector ETF's return at entry.
3. `VOLATILITY_SCALED_TREND`: continuous entry diagnostics for SMA200
   20-session slope and distance above SMA200, both divided by ATR20. This is
   diagnostic only and cannot create a cutoff in this series.

Only the unchanged base or one binary context challenger may be nominated for
confirmation. A challenger must improve median return and median matched-control
excess, improve at least 55% of assets, retain at least half the base trades,
remain positive at stress costs, and not worsen median drawdown by more than two
points. If both binary challengers pass, the higher matched-control excess wins;
ties break by breadth and drawdown. The continuous volatility diagnostics may
educate later theory but cannot be selected here.

## Confirmation gates

Exactly one frozen specification may query 2024-2025. It confirms only if:

- all integrity and coverage checks pass;
- median primary and stress returns are positive;
- median excess over matched circular controls is positive;
- median observed control percentile is at least 0.50;
- at least 55% of assets are positive;
- both calendar years have positive equal-asset aggregate return;
- median drawdown is not worse than the frozen parent/base by more than two
  percentage points.

Failure is a STOP. Passing these research gates still does not create portfolio
or live authority.

## Required evidence

Every implemented stage reports trade- and bar-level results, Sharpe, hit rate,
payoff asymmetry, turnover, exposure, drawdown, buy-and-hold, circular timing
controls, calendar and asset breadth, cost stress, representative tapes, source
notes, and explicit STOP or nomination state. Generated packets remain ignored;
contracts, results, tests, concise decks, and decision records are versioned.
