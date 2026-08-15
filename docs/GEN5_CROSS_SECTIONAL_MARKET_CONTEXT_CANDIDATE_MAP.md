# Cross-Sectional Market-Context Candidate Map

Status: `DOCUMENTED_CANDIDATES_ONLY_HYP_REG_04_1_OPEN`

## Why Market Context Is Not a SPY Strategy

The intended product is a market-level context measurement that can eventually
be joined to an asset-level volatility state and an unchanged asset strategy.
SPY is useful during development because it is a liquid cap-weighted summary of
the U.S. equity market, but predicting SPY is not the final operating action.

For an asset such as TSLA or AMD, the eventual architecture is:

`market trend direction/health x asset-relative ATR% state x unchanged asset signal`

The market field would answer whether the surrounding equity tape is broadly
advancing, broadly declining, or internally mixed. The accepted `HYP-REG-01.1`
ATR% state would answer how large that specific asset's movement environment is
relative to its own history. The asset strategy would still supply the entry
and exit. Neither context measurement creates a trade by itself.

Examples of later, separately tested policies could include allowing fresh
long momentum entries only in a broad positive market field, changing no-trade
permission in a fragile field, or routing between already frozen strategy
families. None of those policies is authorized by the present diagnostic.
They would require an unchanged-strategy overlay, asset breadth, temporal
transport, exposure-near controls, and fresh confirmation.

## Candidate 1 — Cross-Sectional Trend Field

Recommended lane: `HYP-REG-04.1`.

Measure four distinct properties across a stable, economically diverse ETF
panel:

1. **Direction:** the robust median of volatility-normalized 20- and 60-session
   trends.
2. **Participation:** the fraction of exposures with positive trend scores.
3. **Multi-horizon agreement:** the fraction whose 20- and 60-session trend
   signs agree.
4. **Flow:** the balance of exposures whose trend score has improved versus
   deteriorated over five sessions.

The measurements remain separate. A small fixed state map may describe broad
up, fragile up, broad down, and fragile down configurations, but no fitted
linear score is allowed. This differs from `HYP-REG-03.2`: it measures the
current cross-sectional configuration and its flow rather than assuming that
an accumulated 20-session breadth decline must continue.

## Candidate 2 — Latent Market Mode

Reserved lane: `HYP-REG-05.1`; not open.

A rolling robust common factor or first principal component could separate:

- the sign of the common return component;
- the fraction of cross-sectional variance explained by that component;
- loading-sign agreement across exposures; and
- residual dispersion or fragmentation.

This is attractive because a cap-weighted index can rise while the common
component weakens. The key caveat is that commonality is not synonymous with
health: correlations often rise during coordinated declines. Factor direction
and factor strength must therefore remain separate. Rolling sign alignment,
loading instability, and estimation-window sensitivity make this less
transparent than the trend field.

## Candidate 3 — Economic Confirmation Network

Reserved lane: `HYP-REG-06.1`; not open.

Economically distinct relative-strength channels could vote on risk appetite:

- equal weight versus cap weight;
- small/mid cap versus large cap;
- cyclicals versus defensives;
- semiconductors versus utilities;
- high-yield credit versus Treasuries; and
- other predeclared, non-duplicative confirmation ratios.

The output would retain direction, agreement, and disagreement rather than
collapse every pair into one vote count. Correlated channels would be grouped
so several versions of one theme could not overwhelm a distinct theme. This is
broader than equity breadth and can be affected by rates and macro structure,
so it deserves a separate hypothesis and source review.

## Eventual Data Upgrade — Point-in-Time Constituent Breadth

A survivorship-safe point-in-time constituent panel would be the closest
implementation of classic market breadth. It could support percentages above
20/50/200-day anchors, advance/decline measures, new-high/new-low participation,
and breadth by sector, size, or capitalization bucket.

The current ETF approach is deliberately lower resolution but avoids using
today's constituents historically. Constituent breadth should not be opened
until a trustworthy membership and delisting source is available. It is a data
authority upgrade, not permission to rescue a failed ETF specification.

## Frozen Sequence

1. Execute only `HYP-REG-04.1` as a strategy-independent diagnostic.
2. Validate future cross-sectional semantics before treating SPY direction as
   consequential evidence.
3. Stop after the diagnostic regardless of outcome.
4. If it passes, discuss—but do not automatically run—a separate join with the
   accepted asset-relative ATR% state.
5. Only a later unchanged-strategy overlay across a diverse asset panel can
   determine whether the joint regime map helps TSLA, AMD, or another asset.

## Source and Decision Grounding

- Operator dialogue decisions `D130` through `D132`.
- S&P Dow Jones Indices, *Worth the Weight*, on equal weighting and index
  concentration as distinct market views.
- Paulo Maio, *Cross-sectional return dispersion and the equity premium*,
  Journal of Financial Markets 29 (2016), 87-109, for the general proposition
  that cross-sectional distributions can contain aggregate information. The
  candidate map does not assume its fitted result or sign.
