# EDL-MS-01 Rule 201 Wide-Atlas Replication

## Question

Does the ten-stock pilot's tentative five-session recovery hump persist when the same Rule 201 proxy and reclaim definitions are applied to the frozen 129-instrument atlas?

## Frozen scope

- TRAIN only: 2018-01-02 through 2023-12-29.
- Alpaca adjusted daily OHLCV.
- Primary breadth: 88 sector-balanced GICS stocks.
- Separate challengers: 16 attention/meme stocks.
- Separate controls: 15 equity ETFs and 10 non-equity ETF proxies.
- Discovery band: daily low versus prior close from -12% through -8%.
- Triggered proxy: daily low versus prior close at or below -10%.
- Strong reclaim: close-location value at or above 0.75.
- Weak close: close-location value at or below 0.25.
- Entry clock: completed signal close at t, entry open at t+1.
- Forward-path context: sessions 0 through 10 after entry.

No definition was changed after seeing the ten-stock pilot.

## Representation policy

All 129 registry instruments remain enrolled. Six have no discovery-band event and 94 have no triggered/strong-reclaim event; they remain visible in the coverage and count ledgers. Seven recent listings begin materially after the common TRAIN start and retain their shorter available histories.

Stocks and ETFs are never silently pooled in the primary readout. The 88-stock core is the main replication surface; attention stocks and ETF controls are shown separately.

## Two weighting views

1. **Event pooled:** every qualifying event receives one observation.
2. **Equal symbol:** compute the median path within each eligible symbol, then average those symbol medians equally.

The second view asks whether an event-rich name controls the apparent path. It does not impute a path for symbols with zero events.

## Descriptive readout

- Pilot ten-stock triggered/strong group: day-five median +3.72% across 24 events; day-ten median -1.12%.
- Primary 88-stock core: day-five median -0.24% across 21 events; day-ten median -0.48%.
- All 104 stocks: day-five median +2.24% across 68 events; day-ten median -1.54%.
- Equal-symbol 88-stock core: day-five mean of symbol medians +0.51% across 20 eligible symbols; day-ten +1.08%.
- The attention-stock cohort supplies 47 of the 68 all-stock triggered/strong events and shows the clearest day-five event-pooled hump, about +2.65%, before a negative day-ten median.
- ETF triggered/strong cells contain one eligible event per ETF cohort and are examples, not stable cohort estimates.

The pilot's day-five hump therefore does not replicate cleanly as an asset-agnostic effect in the balanced stock core. It is substantially associated with the attention-stock cohort. The core still shows a down-then-recovery shape and a modestly positive equal-symbol view, but only 21 events across 20 eligible symbols make that a mechanism clue rather than evidence of edge.

## Interpretation boundary

This slice does not run p-values, confidence intervals, multiplicity correction, costs, overlapping-trade replay, sizing, portfolio accounting, or post-2023 outcomes. No holding horizon is selected.

## Status

`WIDE_ATLAS_REPLICATION_COMPLETE_NO_EDGE_CLAIM`

The breadth question is answered: the initial hump is cohort-sensitive rather than broadly uniform. The next decision belongs to the operator: inspect why attention stocks differ, run a predeclared falsification of that cohort distinction, or pause the daily lane before opening either bookmarked 30-minute branch.
