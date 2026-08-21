# LIT-MOM-01.4 Multi-Market Predictor Atlas Results

Status: `STOP_LIT_MOM_01_4_NO_FDR_CONTROLLED_TRANSPORT`

## Decision

Stop this predictor family at DEVELOPMENT. All 92 frozen instruments were
mechanically and analytically eligible, but none of the 79 independently
tested fixed cells survived the predeclared within-stratum false-discovery
gate. Do not query the sealed 2024-2025 confirmation period and do not build a
trading rule from these results.

This is stronger evidence than the preceding single-SPY null. It shows that
the stopped result did not become a controlled discovery after broadening to
a category-balanced set of U.S.-listed daily market proxies and
survivor-limited stock challengers. It does not establish that markets never
trend; it rejects this frozen own-return linear horizon-surface formulation
on this atlas and sample split.

## Frozen execution

- Registry: all 92 rows under frozen SHA-256
  `69C481DCB8443AADC30D8BF10FC7FFB7EC23D193CE88A992E42F8529225E4737`.
- Strata: 68 plain ETFs, six leveraged/inverse ETFs, and 18 stock
  challengers.
- TRAIN: 2017-2020, with all 28 `(L,H)` cells evaluated and at most one
  largest-positive cell nominated per asset.
- DEVELOPMENT: 2021-2023, with exactly the nominated cell tested once.
- Multiplicity: one-sided circular-shift probabilities followed by
  Benjamini-Hochberg `q=0.10` separately within the three frozen strata.
- Data boundary: Alpaca adjusted daily bars through `2023-12-29` only.
- Confirmation and strategy contact: not opened.

The authoritative evidence invocation used `refresh=FALSE` after a bounded
preflight refresh completed every requested 2016-2023 cache range. The packet
health maximum is `WARN` only because those intentionally bounded caches are
stale relative to August 2026, not because the requested evidence window is
incomplete.

## Primary readout

Every registry row passed the mechanical and analytical gates. Seventy-nine
assets had at least one strictly positive TRAIN cell and therefore received
one fixed DEVELOPMENT test. Thirteen had no positive TRAIN cell: `QQQ`,
`XLV`, `XBI`, `GDXJ`, `FXI`, `PPLT`, `FXY`, `TMF`, `MSFT`, `TXN`, `UNH`,
`MCD`, and `NEE`.

| Stratum | Registry assets | Non-SPY fixed tests | Positive DEVELOPMENT rho | FDR candidates | Minimum raw p | Minimum BH q |
|---|---:|---:|---:|---:|---:|---:|
| `PLAIN_ETF` | 68 | 60 | 12 | 0 | 0.088850 | 0.986063 |
| `ENGINEERED_ETF` | 6 | 5 | 2 | 0 | 0.222997 | 0.766551 |
| `STOCK_CHALLENGER` | 18 | 13 | 5 | 0 | 0.097561 | 0.883275 |

SPY was reproduction-only and excluded from asset multiplicity. All three
frozen reproduction checks passed to numerical tolerance: observed surface
maximum `0.016240`, shift-surface p90 `0.177058`, and canonical `250/25`
correlation `-0.118644`.

## Closest cases are not candidates

The following rows are useful diagnostics, not a basis for post-hoc promotion:

- `XLRE`, plain ETF, `L1_H10`: TRAIN rho `0.000434`, DEVELOPMENT rho
  `0.043005`, beta `0.138883`, raw shift p `0.088850`, BH q `0.986063`, and
  90% stationary-bootstrap beta interval `[-0.028029, 0.279312]`.
- `TQQQ`, engineered ETF, `L5_H10`: TRAIN rho `0.036548`, DEVELOPMENT rho
  `0.034428`, beta `0.047115`, raw shift p `0.222997`, BH q `0.766551`, and
  90% interval `[-0.082109, 0.167345]`.
- `APD`, stock challenger, `L10_H5`: TRAIN rho `0.027959`, DEVELOPMENT rho
  `0.142908`, beta `0.094306`, raw shift p `0.097561`, BH q `0.883275`, and
  90% interval `[0.020722, 0.146022]`.

APD's bootstrap interval is positive, but the frozen primary gate was the
fixed-cell circular-shift probability after asset multiplicity. Its BH value
is `0.883275`, so the bootstrap clue cannot rescue or promote it.

## Interpretation boundary

The atlas covers daily own-return prediction in currently tradable
U.S.-listed instruments. Commodity, currency, rate, and international ETFs
are proxies rather than native futures, FX, or local-market histories, and
the stock challenger is survivor-limited. The result does not test
cross-sectional momentum, nonlinear predictors, regime conditioning, native
market data, or intraday behavior.

No thresholds, positions, trades, costs, P&L, Sharpe, drawdown, allocation,
leverage, advice, or live behavior were computed.

## Evidence packet

- Packet:
  `runs/research_workbench/literature_grounded/lit_mom_01_4_multi_market_predictor_atlas_20260821`
- Report: `mom014_report.md`
- Coverage ledger: `mom014_coverage_and_eligibility.csv`
- Complete TRAIN surface: `mom014_train_surface.csv`
- Frozen nominees: `mom014_train_nominees.csv`
- Fixed DEVELOPMENT tests: `mom014_development_fixed_cells.csv`
- Category summary: `mom014_category_summary.csv`
- Visual evidence: `visuals/`

The locked 2024-2025 confirmation period remains unread because the frozen
DEVELOPMENT gate produced no candidate.
