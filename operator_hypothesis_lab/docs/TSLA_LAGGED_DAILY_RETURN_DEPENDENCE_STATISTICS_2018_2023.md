# TSLA Lagged Daily Return Dependence: Descriptive Measurement

## Question

Does one TSLA daily log return contain measurable information about the next
session's signed return on the same fixed sample used for the original
scatterplot?

The purpose of this slice is measurement, not model selection. It quantifies
the visual relationship before any alternate lag, horizon, conditional state,
prediction system, or trading rule is opened.

## Fixed Surface

- Asset: `TSLA`.
- Source: canonical Alpaca SIP adjusted daily bars.
- Return: `log(adjusted_close[t] / adjusted_close[t-1])`.
- Target sessions: `2018-01-02` through `2023-12-29`.
- Consecutive-session pairs: `1,509`.
- Primary estimand: Pearson correlation, equivalently the OLS slope in
  `r[t] = alpha + beta * r[t-1] + error[t]`.
- Primary uncertainty: 95% circular moving-block bootstrap interval using
  `5,000` replicates and 20-pair blocks.
- Regression check: Newey-West/HAC standard errors with 7 Bartlett-weighted
  lags.
- Diagnostics: Spearman rank correlation, direction transitions, fixed
  1%/99% winsorization, annual HAC slopes, and absolute-return dependence.
- Alternate lag or horizon search: none.
- Post-2023 data: not queried.
- Trading policy or performance calculation: none.

Pearson/OLS is the primary signed-return question. The diagnostics are not
counted as separate independent confirmations.

## Signed-Return Result

The adjacent-session signed relationship is effectively zero:

| Measure | Estimate | 95% interval |
|---|---:|---:|
| Pearson correlation | -0.0210 | [-0.0734, +0.0275] block bootstrap |
| OLS slope | -0.0210 | [-0.0757, +0.0336] HAC |
| Spearman correlation | -0.0042 | [-0.0542, +0.0435] block bootstrap |

The OLS model explains `0.000443` of next-session variance, or approximately
`0.044%`. Its HAC slope p-value is `0.451`. The fitted line is therefore both
visually shallow and statistically imprecise around zero.

## Direction Transition

The binary direction view reaches the same conclusion:

- Unconditional probability that the next session is up: `52.5%`.
- Probability of an up session after a prior down session: `52.9%`.
- Probability of an up session after a prior up session: `52.1%`.
- Up-after-up minus up-after-down: `-0.7` percentage points.
- 95% block-bootstrap interval for that difference: `-5.8` to `+4.2`
  percentage points.

Yesterday's sign does not visibly or statistically separate tomorrow's
direction on this surface.

## Obvious Robustness Checks

The fixed 1%/99% winsor sensitivity moves Pearson correlation from `-0.0210`
to `-0.0079`, closer to zero. Annual OLS slopes vary in sign from `-0.132` in
2018 to `+0.067` in 2019, but every annual HAC interval crosses zero. Neither
rank dependence, fixed tail treatment, nor calendar-year inspection reveals a
stable signed relationship.

These are diagnostics, not a search for a favorable subsample. No year was
selected or promoted after inspection.

## Separate Magnitude Finding

Signed-return dependence can be absent while return magnitude persists. On the
same pairs:

- Pearson correlation of `abs(r[t-1])` and `abs(r[t])`: `+0.1066`.
- 95% block-bootstrap interval: `+0.0334` to `+0.1680`.
- Absolute-return Spearman correlation: `+0.0531`.
- Its 95% block-bootstrap interval: `-0.0038` to `+0.1078`.
- Squared-return Pearson correlation: `+0.1342`.
- Fixed 1%/99% winsorized absolute-return Pearson correlation: `+0.0857`.

This is a modest and non-monotonic magnitude-persistence clue. The decile plot
is jagged rather than steadily increasing, and the rank interval crosses zero.
It says nothing about direction and does not rescue the stopped signed-return
question.

## Readout

For this fixed TSLA sample, the descriptive signed-return question stops: there
is no measurable adjacent-session continuation or reversal. The separate
magnitude result is worth remembering as a narrowly bounded future question,
but it is not yet a predictive result and has no strategy authority.

## Artifacts

- Running slide deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`
- Statistical packet:
  `runs/research_workbench/operator_hypothesis_lab/tsla_lagged_return_dependence_statistics_20260825/`
- Reproduction script:
  `scripts/inspect/run_tsla_lagged_return_dependence_statistics.R`
- Original visual notes:
  `operator_hypothesis_lab/docs/TSLA_LAGGED_DAILY_RETURN_SCATTER_2018_2023.md`
  and
  `operator_hypothesis_lab/docs/TSLA_ER20_PATH_REGIME_BANDS_2018_2023.md`

## Follow-Up

The predeclared cumulative prior-versus-forward horizon grid is documented in
`operator_hypothesis_lab/docs/TSLA_CUMULATIVE_RETURN_HORIZON_GRID_2018_2023.md`.
It extends both sides to `1, 2, 3, 4, 5, 10, 15, 20, 25` sessions without
opening a trading rule or reading post-2023 data.
