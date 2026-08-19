# LIT-REG-02.2 Directional HMM Forecast-First Decision

Status: `APPROVED_SUPERSEDED_BY_FROZEN_CONTRACT`

Date: 2026-08-19

## Decision

`LIT-REG-02.1` remains stopped. Its ten package-native fits were causal and
deterministic, and its H20 probabilities improved Brier score and log loss in
nine of ten teaching cases, but the frozen hard-state and transition-tail
gates failed. Those gates will not be deleted or reinterpreted.

The operator approved `LIT-REG-02.2` as a substantively different,
forecast-first exercise. The hidden states remain model machinery, while the
primary scientific question becomes whether their causal probability mixture
improves forward 20-session direction probabilities over simpler models.
Hard-state accuracy and transition recovery remain visible diagnostics rather
than promotion gates.

## Why This Is Not a Rescue

- `02.1` keeps its seeds, gates, results, and STOP.
- `02.2` receives a new contract, fresh confirmation seeds, and a stronger
  comparator before any new result is generated.
- The `02.1` detection-frontier and financial-stress registries were frozen
  but structurally unread. `02.2` may inherit those still-unread cases while
  applying its separately frozen forecast-first evaluation.
- No market, residual, strategy, return-performance, or live data are opened.

## Primary Question

At the close of session `t`, does a two-state Markov-switching Gaussian AR(1)
produce a better causal estimate of

```text
Pr(sum(r_(t+1), ..., r_(t+20)) > 0 | information through t)
```

than a TRAIN base rate, a single-regime Gaussian AR(1), and a compact
fixed-penalty ridge-logistic return-history challenger?

## Interpretation Boundary

Success would show that latent-state uncertainty can add synthetic forecast
information under specified signal, persistence, history, and noise
conditions. It would not establish a market regime, alpha, entry threshold,
strategy, PnL, Sharpe, drawdown, allocation, leverage, or live behavior.
