# QQQ Laggard and TSLA Intraday-Permission Hypothesis Slate

Status: `HYP_IMOM_04_1_CAL_A01_STOP_FRESH_CONFIRMATION_NOT_READ`

Date documented: `2026-08-23`

## Purpose

This slate records three operator-origin ideas raised after the HYP-MR-01
investigation. The first two ask whether lagging members of a rising peer group
subsequently catch up. The third asks whether a simple machine-learning model
can identify when the previously tested TSLA 30-minute SMA8/SMA14 strategy is
and is not worth deploying.

The identifiers below reserve distinct research concepts. They do not freeze
an execution contract, authorize outcome reads, or promote any strategy.

## Slate

| Identifier | Working name | Narrative hypothesis | Current boundary |
|---|---|---|---|
| `HYP-MR-02.1` | QQQ Peer-Advance Laggard Catch-Up | When a broad majority of a QQQ constituent's peers rises but that constituent lags, the constituent subsequently earns positive short-horizon return relative to those peers. | Bookmarked; point-in-time Nasdaq-100 membership authority is not currently admitted. |
| `HYP-MR-03.1` | Multivariate Peer-Equilibrium Laggard Reversion | When a related basket's common equilibrium moves upward but one member sits materially below its causal equilibrium estimate, the lagging member subsequently corrects upward in residual terms. | Bookmarked; requires an externally defined basket, stable causal estimation, and the same membership authority where QQQ is claimed. |
| `HYP-IMOM-04.1` | TSLA Intraday Permission and Direct-Exposure Positive-Control Lab | Causal trend, path quality, volatility quality, participation, and market-confirmation information may distinguish periods when TSLA should be held from periods when cash has higher expected utility. | `CAL-A01` crossover permission and `CAL-A02` direct exposure both stopped; all planted controls worked, but neither market model separated upside from downside. Fresh transport remains closed. |

## HYP-MR-02.1 — QQQ Peer-Advance Laggard Catch-Up

### Economic story

Group-level buying or repricing may not arrive everywhere simultaneously. If
most peers have moved upward and one member has not participated, delayed
price reaction may produce short-horizon relative catch-up.

OHLCV evidence can test price-reaction diffusion. It cannot, by itself,
establish investor attention. An attention claim would require a distinct
point-in-time attention measure such as abnormal volume, news, search, social,
or order-flow evidence.

### Recommended first estimand

- Formation horizon: five sessions.
- Forward horizon: five sessions.
- Sampling: non-overlapping weekly anchors.
- Peer construction: leave the target constituent out of every peer statistic.
- Peer advance: positive peer median return and at least 70% positive peers.
- Laggard gap: peer median five-session return minus target five-session
  return.
- Target: target's next five-session return minus the same leave-one-out peer
  basket's next five-session return.
- Primary question: conditional on peer advance, is the continuous laggard gap
  positively associated with forward relative return?

The interaction with peer advance is essential. Catch-up that is equally
strong when peers are flat or falling would support generic relative mean
reversion rather than upward diffusion.

### Required controls

- laggard gap when peers are not advancing;
- randomly selected peer on the same advancing anchors;
- shuffled laggard ranks;
- market- and sector-relative return controls;
- leave-one-out construction and common-calendar integrity;
- intercept-only relative drift;
- chronological TRAIN and later transport partitions.

### Data authority

The repository does not currently possess an admitted point-in-time
Nasdaq-100 membership history. Current constituents may not be projected
backward. A formal QQQ test therefore begins with a return-blind source audit.

A fixed historical cohort may be used only as an explicitly retrospective or
deployment-date-conditioned mechanism demonstration. It cannot establish a
survivorship-safe historical QQQ claim.

## HYP-MR-03.1 — Multivariate Peer-Equilibrium Laggard Reversion

### Economic story

A related group may share one or more common stochastic trends. A member that
falls below the equilibrium implied by those trends may subsequently correct
upward, especially when the common component itself is rising.

### Recommended model sequence

The first model should not be a 100-variable cointegration system. Start with
an externally defined five-to-ten-asset sector or industry basket and compare:

1. a rolling common-factor residual model; then
2. a Johansen/vector-error-correction challenger if the simple residual
   formulation produces credible evidence.

For the simple formulation, estimate each member's sensitivity to the causal
common factor using prior data only. The predictor is the member's negative
residual while the common factor is positive. The target is forward residual
return.

The long-only mechanism requires the laggard itself to rise. Spread closure
caused primarily by the peer basket falling does not count as confirmation.

### Required controls

- the same negative residual when the common factor is flat or negative;
- ordinary cross-sectional laggard rank without equilibrium estimation;
- market-plus-sector factor residuals;
- whole-period or blockwise timing shifts;
- externally defined pseudo-baskets of comparable size;
- coefficient and cointegration-rank stability across chronological folds;
- explicit decomposition of convergence into laggard rise versus peer decline.

### Data and complexity boundary

Basket membership and sector identity must be known without future outcomes.
If the claim is specifically about QQQ, the point-in-time membership blockade
from HYP-MR-02.1 also applies. A high-dimensional all-QQQ system is not the
minimal test and may not be introduced before the simpler factor-residual
baseline is understood.

## HYP-IMOM-04.1 — TSLA 30-Minute SMA8/SMA14 ML Permission

### Research role

This hypothesis is intentionally a positive-control and calibration lane.
TSLA and AMD were already registered as outcome-aware educational cases in the
original intraday momentum atlas. A favorable retrospective TSLA result may
show what a functioning permission model looks like; it cannot establish
prospective asset selection or cross-asset generalization.

The parent is `HYP-IMOM-01.1`, whose unfiltered 30-minute SMA8/SMA14 policy was
economically poor across the broad panel because high turnover and costs
consumed the gross movement. HYP-IMOM-04.1 does not alter the parent entry or
exit mechanics. It asks whether a causal permission model can identify a
sparser favorable subset of its TSLA entry events.

### Positive-control ladder

`planted synthetic control -> retrospective TSLA calibration -> frozen TSLA transport -> multi-asset replication`

- Synthetic control verifies that the engine can recover a deliberately
  planted permission relationship.
- Retrospective TSLA calibration permits transparent iteration with an attempt
  ledger; it is pedagogical rather than independent evidence.
- Frozen TSLA transport requires a separately approved contract and data not
  used during calibration.
- Multi-asset replication requires a separate frozen registry and may not
  select remembered winners.

The approved `CAL-A01` atlas contains six monotone univariate rules—asset
trend, causal ATR% percentile, crossover impulse, recent whipsaw count,
same-slot participation surprise, and prior-day QQQ trend—plus three fixed
two-feature AND gates. All candidates share one complete-case event ledger and
one familywise maximum-statistic control. The detailed execution surface is
recorded in
`HYP_IMOM_04_1_TSLA_30MIN_SMA_PERMISSION_POSITIVE_CONTROL_PLAN.md`.

The separately approved `CAL-A02` attempt removed the crossover action
constraint. At each completed session it used twelve causal state features and
four frozen interactions to decide whether the next executable open-to-open
interval should be long TSLA or cash. The primary ridge model failed the
predictive, familywise, return, downside-capture, quarterly-stability, and
matched-permission gates. Its 71.8% upside capture came with 72.2% downside
capture. The secondary tree produced a positive compounded return but remained
a diagnostic because it forecast worse than drift, captured most downside, and
changed root features across folds. The detailed frozen surface and decision
are recorded in
`HYP_IMOM_04_1_CAL_A02_TSLA_DIRECT_EXPOSURE_PLAN.md` and
`HYP_IMOM_04_1_CAL_A02_TSLA_DIRECT_EXPOSURE_RESULTS.md`.

## Recommended research order

1. Preserve the completed CAL-A01 and CAL-A02 TSLA STOPs without opening fresh
   confirmation; any nonlinear tail-capture question requires CAL-A03.
2. Separately run a return-blind point-in-time Nasdaq-100 membership source
   audit.
3. If membership authority passes, freeze and execute HYP-MR-02.1.
4. Use HYP-MR-03.1 only after the simple laggard and factor-residual questions
   are understood; cointegration is a challenger, not the starting point.
