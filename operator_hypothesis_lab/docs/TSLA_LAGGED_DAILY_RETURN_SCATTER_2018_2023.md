# TSLA Lagged Daily Return Scatter: Visual Exploration

## Question

What does the raw relationship between one TSLA daily log return and the next
daily log return look like before fitting a model or calculating a statistic?

## Construction

- Asset: `TSLA`.
- Source: canonical Alpaca SIP adjusted daily bars.
- Return: `log(adjusted_close[t] / adjusted_close[t-1])`.
- Visible target sessions: `2018-01-02` through `2023-12-29`.
- X-axis: the prior session's log return, `r[t-1]`.
- Y-axis: the current session's log return, `r[t]`.
- Each point: one pair of consecutive trading sessions.
- Color: the four up/down direction combinations.
- Fitted line, correlation, p-value, binning, and outlier removal: none.

The first visible point uses the `2017-12-29` return on the x-axis and the
`2018-01-02` return on the y-axis. Data after `2023-12-29` were not queried.

## Bench Readout

The plot is a dense cloud around zero with observations in every quadrant.
Large positive and negative next-day moves are visible after both positive and
negative prior days. Direction alone does not look visually deterministic, but
this figure deliberately makes no statistical or trading claim.

The quadrant colors encode direction without collapsing the observations onto
four binary coordinates. Their continuous positions preserve the magnitude of
both returns.

## What This Does Not Answer

This picture does not establish whether the relationship is positive,
negative, nonlinear, conditional on volatility, stable across years, or useful
after costs. Those are separate questions and should be opened only one at a
time.

## Artifacts

- Chart:
  `runs/research_workbench/operator_hypothesis_lab/tsla_lagged_daily_return_scatter_20260824/visuals/tsla_t_minus_1_vs_t_daily_log_return_scatter.png`
- Consecutive-pair ledger:
  `runs/research_workbench/operator_hypothesis_lab/tsla_lagged_daily_return_scatter_20260824/tsla_consecutive_daily_return_pairs.csv`
- Run specification and source checks:
  `runs/research_workbench/operator_hypothesis_lab/tsla_lagged_daily_return_scatter_20260824/`
- Reproduction script:
  `scripts/inspect/run_tsla_lagged_daily_return_scatter.R`
- Running descriptive-research deck:
  `operator_hypothesis_lab/presentations/tsla_descriptive_microscope_evidence.pptx`
