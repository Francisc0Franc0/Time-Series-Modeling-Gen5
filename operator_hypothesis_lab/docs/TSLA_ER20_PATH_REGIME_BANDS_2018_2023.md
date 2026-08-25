# TSLA ER20 Path-Regime Bands: Visual Exploration

## Question

Can a simple trailing path-efficiency measure produce trend-versus-sideways
bands that resemble the regimes a person perceives on a TSLA price chart?

## Metric Choice

The chart uses a log-price form of the 20-session Kaufman-style Efficiency
Ratio (`ER20`):

`abs(log_close[t] - log_close[t-20]) / sum(abs(one-session log-price moves))`

This is a good first path-efficiency metric because its interpretation is
direct and bounded:

- `ER20 = 1` means every move in the 20-session path had the same sign.
- `ER20` near zero means the path traveled substantially but ended near where
  it began.
- The absolute numerator makes the measure direction-agnostic. A smooth rise
  and a smooth decline can both have high efficiency.

The 20-session window is approximately one trading month. The color split was
fixed before rendering: green for `ER20 >= 0.30`, red for `ER20 < 0.30`. The
cutoff is a visual convention for this first inspection, not a fitted or
validated threshold.

## Construction

- Asset: `TSLA`.
- Source: canonical Alpaca SIP adjusted daily bars.
- Visible sessions: `2018-01-02` through `2023-12-29`.
- Price axis: adjusted close on a log scale.
- Green background: trending or directionally efficient trailing path.
- Red background: sideways or choppy trailing path.
- Lower panel: the continuous `ER20` value and the fixed `0.30` boundary.
- Causal timing: the value at close `t` uses only closes through `t`; the band
  begins at `t` and extends until the next session.
- Optimization, fitted model, performance calculation, and statistical test:
  none.

## Interpretive Guardrail

Path efficiency is not volatility. A high-volatility path can be green if it
moves persistently in one direction, and a low-volatility path can be red if
it repeatedly reverses. These colors should therefore be read as path-shape
regimes, not high-versus-low volatility regimes.

## Bench Readout

The bands do recognize several visually clean directional runs. Green appears
during substantial portions of the 2019-2020 advance, the late-2021 ascent,
the sharp 2022 declines, the early-2023 advance, and the strong mid-2023 rally.
The down-move examples are useful confirmation that the metric is measuring
path efficiency rather than bullishness.

The alignment is not uniformly clean. Around turning points and irregular
rallies the state often alternates in short red/green strips, and the full
2020-2021 secular rise is not continuously green. That is coherent with the
definition: `ER20` asks whether only the latest 20-session path was efficient,
not whether the longer-term trend remained upward. As a trailing metric it can
also recognize a new regime only after enough of that path has occurred.

The raw daily threshold therefore looks useful as a descriptive microscope,
but visually somewhat flickery as a standalone regime label. No persistence
rule, smoothing, alternate cutoff, or window search was added after seeing
this result.

## What This Does Not Answer

This chart does not establish that `ER20` predicts future returns, that `0.30`
is the right threshold, that 20 sessions is the best horizon, or that the
regimes improve a trading system. Each would require a separate hypothesis.

## Artifacts

- Chart:
  `runs/research_workbench/operator_hypothesis_lab/tsla_efficiency_ratio_regime_bands_20260824/visuals/tsla_er20_path_regime_bands.png`
- Daily metric ledger and contiguous regime spans:
  `runs/research_workbench/operator_hypothesis_lab/tsla_efficiency_ratio_regime_bands_20260824/`
- Reproduction script:
  `scripts/inspect/run_tsla_efficiency_ratio_regime_bands.R`
- Running descriptive-research deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`
