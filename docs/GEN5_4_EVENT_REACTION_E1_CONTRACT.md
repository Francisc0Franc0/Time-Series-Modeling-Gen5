# Gen5.4 Event-Conditioned Continuation E1 Contract

Status: frozen and authorized for implementation on 2026-07-27.

## Purpose

E1 asks whether an unusual point-in-time issuer information cycle followed by
a positive market-adjusted overnight reaction and positive next-session
intraday confirmation shows additional five-session continuation after the
signal becomes executable.

This is a measurement POC. It does not authorize a forecasting model, position
size, portfolio replay, performance acceptance, PnL claim, or live-advice
change.

## Economic hypothesis

Some economically important information is incorporated gradually rather than
instantaneously. News identifies when information may have arrived; price
determines the market's directional interpretation.

The news condition must add information beyond the same price pattern. E1
therefore compares qualifying information shocks with non-news observations
that have similar positive overnight and intraday reactions.

## Authority and development boundary

- Information-cycle authority:
  `runs/research_workbench/gen54_ml_decision_engine/g54_event_e0_20260726/`.
- TRAIN-only equal-count percentile authority:
  `runs/research_workbench/gen54_ml_decision_engine/g54_news_n1d_20260725/`.
- Adjusted daily OHLCV authority: the existing Alpaca cache and workbench query.
- Market adjustment: adjusted daily `SPY`.
- Historical development window: `2025Q1` through `2026Q2`.
- Prospective shadow freeze begins with the `2026-07-27` decision cycle.

The historical window has already informed prior news-representation research.
Its E1 continuation readout is development evidence, not pristine confirmation.
Only observations accumulated after the E1 freeze may become prospective
confirmation authority.

## Frozen timing

For an information cycle with decision session `t`:

1. The cycle closes at `17:30 America/New_York` on `t`.
2. The next market session is the reaction session `t+1`.
3. Overnight reaction becomes observable at the `t+1` open.
4. Intraday confirmation becomes observable only after the `t+1` close.
5. The earliest hypothetical entry is the `t+2` open.
6. The continuation endpoint is the open five sessions after entry.

No E1 observation may use the `t+1` open as an executable entry after using
that price to define the reaction.

## Frozen measurements

### 1. Unusual information cycle

The cycle must have:

- at least one admissible novel cluster; and
- an issuer-local equal-count percentile greater than or equal to `0.80`.

The percentile is inherited from the accepted N1D eight-quarter TRAIN ECDF.
E1 may not recalibrate the percentile, tune a count threshold, or reopen the
failed recency representation.

### 2. Initial reaction

```text
overnight_excess =
  log(issuer_open[t+1] / issuer_close[t])
  - log(SPY_open[t+1] / SPY_close[t])
```

The initial reaction passes when `overnight_excess > 0`.

### 3. Prospective price confirmation

```text
intraday_excess =
  log(issuer_close[t+1] / issuer_open[t+1])
  - log(SPY_close[t+1] / SPY_open[t+1])
```

Confirmation passes when `intraday_excess > 0`.

The E1 signal is known only after the `t+1` close.

### 4. Continuation outcome

```text
continuation_excess_h5 =
  log(issuer_open[entry+5] / issuer_open[entry])
  - log(SPY_open[entry+5] / SPY_open[entry])
```

The entry is the `t+2` open. The outcome is a measurement, not strategy PnL.

## Overlap rule

Qualifying signals are processed chronologically within issuer. Retain the
first signal, then suppress later signals whose hypothetical entry occurs
before the retained signal's outcome endpoint. A new signal may be retained on
or after the prior endpoint open.

This deterministic embargo prevents one continuing price path from appearing
as several independent event observations.

## Matched price-pattern control

Each retained signal is matched within the same issuer and OOS quarter to the
nearest observation satisfying:

- zero admitted novel clusters;
- positive SPY-adjusted overnight reaction;
- positive SPY-adjusted intraday reaction;
- complete executable h5 continuation outcome; and
- no use as an information-shock signal.

Matching uses only the two reaction measurements. Each reaction is standardized
by the issuer-fold TRAIN median and median absolute deviation. The deterministic
distance is Euclidean distance in those two TRAIN-frozen robust z-scores.

Controls may be reused. Ties select the earliest decision session. A match is
admitted only when the absolute difference is no greater than `0.50` robust
z-score units in each reaction dimension. Unmatched signals remain visible in
the audit but do not enter the matched-difference readout.

Outcomes, later prices, headlines, sentiment, source identity, and event
semantics may not influence matching.

## Development readout

E1 reports:

- eligible unusual cycles;
- positive overnight reactions;
- positive intraday confirmations;
- retained non-overlapping signals;
- matched and unmatched signal counts;
- issuer and quarter coverage;
- signal and control mean/median h5 excess continuation;
- signal-minus-control matched differences;
- positive-outcome and positive-difference shares;
- match distance and control-reuse diagnostics; and
- representative event/reaction/continuation tapes.

These quantities describe the frozen development sample. No historical
outcome gate may promote the hypothesis.

## Frozen integrity gates

All gates must pass:

1. E0 integrity remains fully `PASS`.
2. N1D leakage authority remains fully `PASS`.
3. Every boundary-purged positive N1D OOS equal-count row exactly matches its
   E0 cycle authority.
4. Adjusted issuer and SPY bars cover the bounded development window.
5. N1D issuer-local percentiles end strictly before each OOS fold.
6. Every reaction session follows its decision session.
7. Every hypothetical entry follows the confirmation session.
8. Every h5 outcome begins at entry and ends inside its OOS fold.
9. Every retained signal satisfies the frozen unusual-cycle and two positive
   reaction rules.
10. Retained signals obey the issuer-local overlap embargo.
11. Every admitted control has zero news, the same issuer and fold, and two
    positive reaction measurements.
12. Matching uses only TRAIN-frozen reaction scales and never uses outcomes.
13. At least `20` non-overlapping signals exist across at least `8` issuers and
    at least `4` quarters.
14. At least `70%` of retained signals receive an in-caliper control.
15. No sentiment, text model, predictive model, threshold search, portfolio,
    PnL, allocation, or live-advice surface enters the packet.

If all integrity and support gates pass, record:

`PASS_E1_DEVELOPMENT_MECHANICS_READY_FOR_PROSPECTIVE_SHADOW`

Otherwise record:

`STOP_E1_DEVELOPMENT_MECHANICS`

Neither status is a predictive promotion.

## Prospective shadow boundary

The prospective shadow applies these frozen rules to information cycles
beginning `2026-07-27`. A signal cannot mature until its five-session endpoint
open exists. Shadow rows must retain:

- local news receipt-time authority;
- the frozen news-intensity calibration authority;
- reaction, confirmation, entry, and endpoint timestamps;
- data-health status;
- overlap disposition; and
- whether the outcome has matured.

Prospective evidence may be reviewed only after a separately agreed minimum
sample and observation period. E1 implementation may create the shadow schema
and readiness status, but it may not change live advice or treat an empty
initial shadow as failure.
