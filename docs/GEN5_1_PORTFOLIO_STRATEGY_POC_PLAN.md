# Gen5.1 Portfolio Strategy POC Plan

Status date: 2026-06-28

This note defines the first portfolio strategy proof of concept. It is an accounting and inspection slice only. It does not approve production allocation, live advice, broker execution, leverage automation, or final research evidence.

## Where This Fits

The current PCA-routed WFA surface can research and simulate one traded symbol at a time while using a larger Regime Context Universe for PCA state assignment. The portfolio POC is the next layer above that: it consumes a small set of single-symbol stitched OOS WFA artifacts and asks whether shared-account portfolio accounting is clear and auditable.

## Universe Vocabulary

- **Regime Context Universe**: symbols used to build the PCA state panel.
- **Research Candidate Universe**: symbols whose WFA/PCA strategy packets are generated.
- **Tradeable Universe**: symbols the portfolio replay may trade.
- **Active Allocation Set**: symbols allowed to receive capital in the portfolio accounting replay.

For the first POC, the Research Candidate Universe, Tradeable Universe, and Active Allocation Set are the same five symbols.

## First POC Defaults

- Active Allocation Set: `AMD,NVDA,TSLA,COIN,MSTR`
- Regime Context Universe: `AMD,NVDA,TSLA,COIN,MSTR,SMH,QQQ,SPY,IWM,TLT,GLD,VXX`
- Panel mode: `behavioral_pool` / internal `pooled_asset_day`
- State map: `quantile_grid`
- State grid: `3x3`
- Fold count: `5`
- Strategy grid preset: `standard`
- Initial capital: `$100,000`
- Slot count: `5`

The selected assets are intentionally active and volatile enough to exercise accounting behavior, while the context universe adds broad equity, growth, small-cap, semiconductor, duration, gold, and volatility context.

## Accounting Policy

The first POC uses **dynamic equal-slot sizing at entry, cash-capped**.

Rules:

- There are five portfolio slots.
- A new entry targets `current portfolio equity / 5`.
- Existing open positions are not resized by scheduled rebalance.
- Exits execute first on a session and return cash to the shared account.
- Entries then execute, using the shared cash pool.
- If target notional exceeds available cash, the entry takes a smaller cash-capped position.
- If no cash is available, the entry is skipped.
- There is no margin, leverage, shorting, or cross-symbol execution optimization.
- One active position per symbol is allowed.

This mirrors the operator's discretionary workflow more closely than fixed initial sleeves: current account value drives the next entry size, but open positions are left alone.

## Leakage Boundary

The portfolio layer must not select assets, strategies, states, parameters, or context universes based on OOS performance.

The portfolio POC may consume:

- declared operator-selected symbols;
- single-symbol PCA-routed WFA stitched OOS trades;
- single-symbol stitched OOS equity/price marks;
- generated artifact paths and manifests.

The portfolio POC must not:

- recompute strategy authority from OOS;
- change state assignment;
- choose winners from OOS metrics;
- create live advice;
- create broker orders;
- imply production allocation readiness.

## Tangible Output

The first POC should write an ignored packet under:

`runs/research_workbench/portfolio_strategy_pocs/`

Expected outputs:

- portfolio report Markdown;
- portfolio equity CSV;
- portfolio event ledger CSV;
- standalone per-symbol reference equity CSV;
- symbol summary CSV;
- child artifact index CSV;
- PNG chart showing portfolio equity and per-symbol standalone reference curves.

The portfolio curve is the authoritative accounting POC output. Per-symbol curves are standalone reference curves scaled to one slot, not a claim that the real portfolio uses isolated fixed sleeves.

After child WFA packets exist, rerun the wrapper with `-SkipChildRuns` to rebuild only the portfolio accounting/report packet from the existing child artifacts.

## STOP Decisions Before Future Expansion

The operator must decide before any future step that changes research or trading authority:

- whether the five-symbol Active Allocation Set is acceptable for broader testing;
- whether the Regime Context Universe should remain this 12-symbol set or expand;
- whether dynamic equal-slot cash-capped sizing remains the intended accounting policy;
- whether to compare panel modes/state maps after the accounting POC is validated;
- whether to run `modest_expanded` as a second-tier artifact family;
- whether any portfolio result may be interpreted as research evidence rather than accounting validation.
