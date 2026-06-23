# AGENTS.md

## Purpose

This repository is the Gen5 rebuild of the Time-Series-Modeling WFA trading system.

Gen5 keeps the strongest Gen4 principles while discarding accidental complexity:

- WFA-first validation.
- No leakage from OOS into training, state assignment, parameter selection, or execution.
- Auditability over opaque performance claims.
- No-trade as a first-class competitor.
- Research-to-execution separation through frozen decision packs.
- Daily long-only advice-first operation before any automation.

## Gen5 v0 Contract

The first implementation target is the market-data layer only.

Gen5 v0 is:

- R-first.
- Alpaca-only.
- Adjusted daily OHLCV only.
- Long-only.
- Advice-only for live operation.
- After-close signal generation for next-open manual orders.
- Designed for local cache storage outside OneDrive when configured.

Do not add WFA, PCA, strategy, exit, allocation, or dashboard code until the data-layer contract and tests are stable.

## Objective

Build a long-only, rolling walk-forward, regime-conditioned tactical equity/ETF system targeting aggressive capital growth from volatile but structurally tradeable assets, with explicit controls for drawdown, concentration, leverage value-add, and out-of-sample robustness.

## Invariants

1. No analytical module may call `Sys.Date()` or independently infer the latest market session.
2. Every data pull must carry an explicit `as_of_timestamp`.
3. Adjusted daily bars are the canonical Gen5 v0 bar type.
4. Provider quirks must stay inside provider modules.
5. Cache reads and writes must be auditable and deterministic.
6. Live-facing outputs must eventually consume frozen WFA evidence, not recompute authority.
7. Heavy generated artifacts and data caches should not live in git.

## Planning Requirement

For non-trivial changes, present a short plan before modifying files. Include:

- files likely to change
- invariants to preserve
- side effects or downstream implications
- validation or smoke checks

## Coding Style

- Prefer explicit, boring, testable R over clever abstractions.
- Keep base-R paths available where practical.
- Add dependencies only when they clearly earn their keep.
- Fail loudly on ambiguous dates, missing required columns, duplicate bars, or future data.
- Keep generated plots rare and purposeful.
