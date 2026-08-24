# HYP-IMOM-04.1 TSLA 30-Minute SMA Permission Positive-Control Plan

Status: `CAL_A01_COMPLETE_STOP_CALIBRATION_GATES_FAILED_FRESH_CONFIRMATION_NOT_READ`

Date drafted: `2026-08-23`

Feature-atlas execution approved: `2026-08-23`

## Position in the research program

This is a controlled follow-up to the stopped unfiltered HYP-IMOM-01.1
30-minute SMA8/SMA14 strategy. It is not a reactive rescue or a promotion
attempt. Its first purpose is to prove that the research engine can recover a
known permission mechanism in synthetic data and then show, honestly, what a
favorable outcome-aware TSLA calibration example looks like.

No 2024+ bars, confirmation outcome, multi-asset model, portfolio, leverage
selection, live advice, or production behavior is opened by this plan.

## Narrative hypothesis

A fresh TSLA 30-minute SMA8-above-SMA14 cross is not always tradeable.
Information observable by the completed crossover bar may distinguish the
occasions when the expected move is directional, persistent, and large enough
to overcome the parent's high turnover and explicit costs. Simple monotone
permission rules should recover those conditions if the mechanism is present.

## Unchanged parent mechanics

Reuse the admitted HYP-IMOM-01.1 data and policy authority:

- Alpaca SIP adjusted `30Min` bars;
- regular session only, 13 bars normally and seven on admitted early closes;
- the same outcome-independent exclusion of the ten documented SIP archive-gap
  sessions;
- fresh completed-bar `SMA8 > SMA14` cross while flat;
- entry at the next available bar open;
- exit at the next available bar open after a fresh `SMA8 <= SMA14` cross;
- blocks start in cash and end flat;
- positions may cross overnight inside a block;
- 1x primary replay;
- 10 bp/side primary costs and 20 bp/side stress costs;
- one-complete-bar execution-delay sensitivity.

The permission model may suppress a fresh parent entry. It may not change the
moving averages, create a new entry, accelerate or delay the parent exit,
short, pyramid, or use leverage to select a policy.

## Evidence zones and labels

### Stage A — planted synthetic positive control

Create deterministic synthetic trade-event data containing nine separately
planted cases: one for each frozen univariate feature and one for each frozen
two-feature AND gate. In every case, the registered direction and boundary are
known before fitting, while the other features act as distractors. Preserve
realistic class imbalance, return noise, volatility clustering, and time
blocks.

The correct registered variant should recover its planted direction, improve
out-of-fold probability loss, select component thresholds near the planted
boundaries, and produce a better permitted-trade replay than the unfiltered
synthetic parent. Distractor variants and the familywise selector remain
visible. Failure is an engine or design STOP before TSLA calibration.

### Stage B — retrospective TSLA calibration

Use the already inspected 2018-2023 TSLA intraday history. This entire stage is
labeled `OUTCOME_AWARE_REUSED_CALIBRATION`; chronological holdouts inside it
measure internal stability, not fresh discovery.

Use the existing expanding structure:

- initial TRAIN through 2020;
- quarterly causal scoring from 2021Q1 through 2023Q4;
- the algorithm may refit on expanding prior calibration data at each quarter;
- no observation from the scored quarter may determine its feature values,
  threshold, leaf probabilities, or participation rule.

After the calibration design is final, one threshold may be fit on all
2018-2023 data for a possible later confirmation contract. This plan does not
authorize that later read.

### Stage C — frozen fresh TSLA transport

Reserved for a separate operator decision. Before any fresh bar is queried,
freeze the final feature, algorithm, threshold-fitting rule, participation
floor, costs, execution, gates, and exact later date range. Prior inspection
of HYP-IMOM-01.1 left 2024+ sealed, making it the natural candidate only if
coverage and source authority pass a new audit.

### Stage D — multi-asset replication

Reserved for a separate hypothesis and outcome-independent asset registry. A
successful TSLA calibration or transport result cannot choose the replication
assets.

## Unit of observation and target

Construct one row for each fresh upward crossover that the unfiltered parent
would enter while flat. Parent trades are naturally non-overlapping.

For event `j`:

- decision timestamp: completed signal bar close;
- modeled entry: next bar open;
- modeled exit: the parent's next-bar-open exit after its downward cross, or
  the frozen block-end liquidation;
- target return: 1x net completed-trade return after 10 bp/side costs;
- classifier label: `1` when target return is strictly positive, otherwise
  `0`.

Retain continuous net return for policy evaluation. The binary label cannot
hide a high-win-rate policy with economically damaging losses.

## Frozen causal feature atlas

Build one immutable parent-event ledger, then attach the following six
features. Every definition and direction is frozen before reading the TSLA
calibration labels.

| ID | Feature | Causal definition at event `j` | Registered permission direction |
|---|---|---|---|
| `T` | Asset trend | TSLA `close[d-1] / SMA200[d-1] - 1` | higher |
| `V` | ATR% movement capacity | percentile of TSLA Wilder `ATR14/close` at `d-1` against the 252 completed sessions ending at `d-2` | higher |
| `I` | Crossover impulse | two-bar change in the completed-bar `SMA8-SMA14` spread, divided by signal-bar close | higher |
| `W` | Recent whipsaw count | number of `SMA8>SMA14` state changes across the 26 completed bars ending immediately before the signal bar | lower |
| `P` | Participation surprise | signal-bar dollar volume divided by the median dollar volume for the same bar slot over the preceding 20 admitted sessions, minus one | higher |
| `M` | Market alignment | QQQ `close[d-1] / SMA200[d-1] - 1` | higher |

Daily OHLCV is aggregated from the admitted 30-minute panel. All daily
features use only sessions completed before event session `d`. The current
completed intraday signal bar may enter `I` and `P`, because permission is
decided after that bar closes and execution remains at the next bar open.

The existing September 2017 intraday prehistory does not supply 200 completed
prior sessions or a causal ATR14/252 percentile at the beginning of 2018.
Events remain visibly feature-ineligible until every frozen feature exists.
They may not be backfilled, shortened, or silently discarded. All nine
variants use the same complete-case event population so support and familywise
comparisons remain like-for-like.

`bars_remaining_in_session` is retained as a fixed-bin diagnostic only. It may
describe early, middle, and late entry behavior but may not compete for model
selection in this execution.

## Frozen candidate family

The six univariate candidates are `T`, `V`, `I`, `W`, `P`, and `M`. Each is a
base-R monotone decision stump. The first five higher-direction rules and the
market rule permit above a threshold; `W` permits below a threshold.

Three two-feature AND gates are also frozen:

1. `T_AND_V`: supportive asset trend and sufficient movement capacity;
2. `I_AND_W`: decisive crossover impulse and low recent whipsaw count;
3. `T_AND_P`: supportive asset trend and unusual same-slot participation.

Each AND gate inherits the two component thresholds fitted by the corresponding
univariate rules on the same TRAIN sample. It introduces no additional
combination-specific threshold. Logistic regression, deeper trees, feature
interactions beyond these three gates, and alternate feature windows remain
outside this execution.

## Minimal model and threshold fitting

Candidate threshold quantiles are frozen at `25%, 35%, 45%, 50%, 55%, 65%,
75%`. The winning quantile is selected with expanding chronological inner
folds using Brier loss; its numeric threshold is then refit on the full outer
TRAIN event set. For every candidate, estimate permitted- and rejected-leaf
win probabilities using TRAIN only. Require:

- at least 20 TRAIN events in each leaf;
- the permitted leaf to contain at least 25% of TRAIN entry events;
- the permitted leaf's TRAIN win probability to exceed the rejected leaf's;
- deterministic tie-breaking toward the higher-participation threshold and
  then the lower registered quantile.

If no candidate is admissible, the fold returns an intercept-only/no-permission
decision rather than weakening support rules.

For a two-feature gate, both inherited component stumps must be admissible and
the joint permitted leaf must satisfy the same support and direction rules.
If any rule is inadmissible, that variant returns the intercept probability and
no permission rather than weakening its support requirements.

## Predictive comparisons

Report chronological out-of-fold for all nine variants:

- Brier loss for the stump and intercept-only win-rate model;
- log loss with probabilities clipped only by a predeclared numerical epsilon;
- calibration by predicted leaf;
- AUC as a secondary ranking diagnostic;
- permitted-versus-rejected win rate and continuous net trade return;
- quarterly support and class balance.

The primary selector is the lowest pooled out-of-fold Brier loss among
admissible variants. Its improvement is compared with the maximum improvement
attained anywhere in the nine-variant family under each whole-session shift.
The selected permitted leaf must also show higher continuous mean net return
than the rejected leaf.

## Policy comparisons and falsification controls

Replay the permitted entries with the unchanged parent exits and compare with:

1. unfiltered HYP-IMOM-01.1 TSLA at 1x;
2. no-trade;
3. fixed hand rule `prior_daily_trend >= 0`;
4. 200 random permission assignments with identical entry count per scored
   block;
5. 200 whole-session circular shifts that preserve within-session bar slots
   and recompute the maximum result across all nine variants;
6. one-complete-bar execution delay;
7. gross, 10 bp/side primary, and 20 bp/side stress costs.

Report total return, mean and median trade return, hit rate, maximum drawdown,
exposure, turnover, trade count, holding bars, same-session versus overnight
contribution, and the permitted policy's percentile in each matched control
family.

Buy-and-hold is reported as ownership context. Because the immediate purpose
is permission relative to the stopped parent, failure to beat full-period
buy-and-hold does not invalidate a positive-control demonstration, but it
prevents any ownership-alpha interpretation.

## Stage gates

### Synthetic engine gate

All must pass before TSLA calibration:

1. schema, timing, and no-leakage checks pass;
2. fitted permission direction matches the planted positive direction;
3. out-of-fold Brier loss improves on intercept-only;
4. selected threshold falls inside the predeclared recovery tolerance;
5. permitted synthetic trades have positive mean net return and beat the
   unfiltered synthetic parent;
6. rerunning with the same seed reproduces every artifact exactly.

### Retrospective TSLA calibration readout

Record `POSITIVE_CONTROL_CALIBRATION_WORKED` only if:

1. all source, event, feature-timing, and fold-integrity checks pass;
2. the selected variant's pooled chronological Brier improvement over
   intercept-only is positive;
3. permitted events have positive mean net return and exceed both rejected
   events and the unfiltered parent trades;
4. the permitted 1x policy has positive primary-cost return and improves on
   the unfiltered parent over the same blocks;
5. actual permission timing strictly exceeds the p90 of matched random
   permission controls, and its predictive improvement strictly exceeds the
   p90 familywise maximum across whole-session-shift controls;
6. at least 25% of parent entry events remain permitted.

Stress costs, one-bar delay, quarterly sign stability, drawdown, and
buy-and-hold comparison are mandatory diagnostics but do not redefine the
pedagogical calibration label after inspection.

Passing Stage B does not authorize 2024+ data or constitute an edge claim. It
records that the positive-control exercise produced the intended kind of
historical separation.

## Multiplicity and iteration ledger

The operator explicitly allows learning from a failed positive-control
attempt. That learning remains quarantined inside retrospective calibration.

- The first execution, `CAL-A01`, must run all six univariate rules, all three
  frozen AND gates, and the maximum-statistic familywise control exactly as
  specified. The nine registered variants count as one predeclared atlas, not
  nine invisible rescue attempts.
- Every later attempted feature, window, combination, label, model,
  participation floor, or cost interpretation receives a sequential
  `CAL-A02`, `CAL-A03`, ... record.
- All attempts and their outcomes remain visible; none may be deleted from the
  calibration report.
- A successful later attempt cannot be described as independently discovered.
- Before fresh transport, the final chosen mechanic receives a separately
  frozen contract that lists the full calibration attempt count.

This permits engineering for understanding without converting repeated
calibration searches into false confirmation.

## Required implementation outputs

- frozen run specification and parent-reproduction audit;
- synthetic generator specification, planted truth, and recovery report;
- TSLA entry-event ledger with all causal features and completed parent
  outcome;
- chronological fold and threshold ledger;
- intercept and nine-variant prediction table;
- feature-only correlation and support audit completed before label-based
  selection;
- matched random and whole-session-shift controls;
- primary/stress/delay policy summaries;
- representative permitted, rejected, winning, losing, overnight, and whipsaw
  trade tapes;
- concise Markdown report and human-facing evidence-deck chapter;
- explicit `FRESH_CONFIRMATION_NOT_READ` marker;
- progress-log entry and attempt ledger.

## Expected implementation surface

Likely new files in an approved execution slice:

- `operator_hypothesis_lab/R/gen5_hyp_imom_04_1_tsla_30min_sma_permission_positive_control.R`;
- `operator_hypothesis_lab/tests/testthat/test_hyp_imom_04_1_tsla_30min_sma_permission_positive_control.R`;
- `scripts/inspect/run_hyp_imom_04_1_tsla_30min_sma_permission_positive_control.R`;
- one results document and an update to the intraday evidence deck.

Reuse the existing intraday registry, admission/cache modules, strategy
schedule, replay mechanics, and ignored run-packet conventions. Add no package
dependency for the decision stump.

## STOP discipline

- Do not read 2024+ during calibration.
- Do not change the 8/14 parent, entry, exit, costs, or overnight convention.
- Do not let rejected entries create alternative later entries while the
  parent remains above SMA14.
- Do not use current-session or future daily state in `T`, `V`, or `M`.
- Do not use a partial signal bar, future same-slot volume, or signal-bar
  outcome information in `I`, `W`, or `P`.
- Do not add a seventh feature or fourth combination after viewing CAL-A01.
- Do not select on 1.8x, leverage, full-history cumulative return, or a
  memorable chart.
- Do not call a TSLA calibration success evidence of general asset-agnostic
  edge.
- Do not hide failed calibration attempts before freezing fresh transport.
