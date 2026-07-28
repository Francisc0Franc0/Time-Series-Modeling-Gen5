# Gen5 Retail Quant Mechanism POC Atlas

Status: `T1_STOP_M1_STOP_S0_STOP`

## Purpose

This memo deliberately zooms out from the current Gen5.4 event-reaction lane.
It asks a more basic question:

> Which economically credible quantitative-trading mechanisms can a retail
> trader test and eventually operate with obtainable data, ordinary brokerage
> access, and non-institutional infrastructure?

The answer should not begin with PCA, Markov models, XGBoost, an LLM, or a
technical indicator. Those are possible measurement or implementation tools.
The research object is the economic mechanism that could make another market
participant transfer return to the strategy.

This is a theory and POC-planning document only. It does not authorize a new
provider, dependency, strategy family, performance calculation, live behavior,
shorting program, options program, or implementation slice.

## The central distinction

A quantitative strategy can earn returns for several very different reasons:

1. **Compensated risk bearing:** the strategy accepts crash, gap, liquidity,
   volatility, or funding risk that others pay to avoid.
2. **Behavioral persistence:** investors underreact, extrapolate, anchor, or
   update slowly, creating continuation over some horizon.
3. **Liquidity provision:** the strategy supplies immediacy when others demand
   it and is paid for accepting adverse-selection and inventory risk.
4. **Relative-value convergence:** economically related assets temporarily
   diverge and the strategy bears the risk that convergence may be slow or
   never occur.
5. **Information processing:** the strategy converts genuinely point-in-time
   information into a usable decision faster or more accurately than the
   marginal participant.
6. **Implementation discipline:** diversification, cost control, sizing,
   execution, and abstention preserve a small gross edge that a careless
   implementation would lose.

An indicator is not a seventh mechanism. A moving average may measure trend; a
z score may measure relative divergence; a neural network may combine
characteristics. None explains why the return should exist.

## What “works” should mean here

For this project, “works” should not mean that one historical backtest has an
attractive equity curve. A serious retail POC should require:

- an economic counterparty or risk-transfer explanation;
- signal and universe definitions frozen before confirmation outcomes;
- point-in-time membership and data availability;
- next-executable-price timing;
- explicit spread, slippage, borrow, and turnover assumptions;
- comparison with no-trade and the correct passive or neutral benchmark;
- dispersion across many dates and instruments rather than one lucky tape;
- stability across nearby, economically equivalent parameter values;
- a genuinely untouched confirmation window or prospective shadow;
- operational feasibility with the data feed and account actually available.

Published findings are priors, not proof that the edge remains available to us.
Transaction costs reduce every anomaly and are especially damaging to
high-turnover strategies. Research-design freedom creates another large source
of false confidence.

## The LLM's proper role

The LLM can be valuable as:

- an educator and mechanism critic;
- a research-contract and leakage auditor;
- a code and test author;
- a data-schema and timestamp reviewer;
- a generator of falsification tests and negative controls;
- an experiment archivist and visual explainer;
- a monitor that compares live observations with frozen research authority.

The LLM should not be treated as:

- a database of secret profitable strategies;
- a point-in-time historical oracle;
- evidence that a remembered pattern survived publication and costs;
- a direct return forecaster because it can discuss markets fluently;
- a substitute for market data, fills, borrow availability, or causal logic.

Training-data memory is a particular hazard: an LLM can repeat a result that
was discovered with hindsight without preserving the original information set.

## Candidate mechanism families

| Family | Why it can exist | Retail feasibility | Primary danger | Atlas verdict |
|---|---|---:|---|---|
| Multi-asset time-series trend | Slow information diffusion, institutional rebalancing, crisis persistence, and hedging demand | High with liquid ETFs; higher fidelity with retail futures access | Whipsaw, parameter mining, and confusing volatility scaling with signal value | Frozen T1 completed; STOP on persistence mechanism |
| Cross-sectional momentum | Relative winners and losers adjust gradually; capital and attention move slowly | High with a frozen liquid ETF or stock universe | Momentum crashes, turnover, and survivorship bias | First-priority POC |
| Post-event drift | Investors incompletely digest discrete fundamental information | Medium; requires trustworthy event timestamps and surprise measurements | Using revised data, imprecise announcement time, or price-defined events as if they were fundamentals | Second-priority POC |
| Statistical arbitrage / pairs | Close substitutes temporarily diverge because of flows, constraints, or temporary mispricing | Medium; requires many pairs, shorting, borrow, and neutralization | One hand-picked pair, unstable relationships, hidden beta, and costs | Feasibility POC before strategy POC |
| Short-horizon reversal | Liquidity demand temporarily moves prices; a patient counterparty earns the reversal | Medium to low; requires consolidated intraday trades/quotes and careful execution | Bid-ask bounce, adverse selection, fill assumptions, and excessive turnover | Conditional intraday POC |
| Overnight / intraday structure | Risk and information arrive differently when markets are closed versus continuously trading | Medium with session-aware bars; high-quality intraday work needs SIP data | Treating return decomposition as a tradeable forecast; opening-auction slippage and gap risk | Measurement POC, not presumed alpha |
| Volatility-managed exposure | Volatility changes faster than expected return, so constant dollar exposure can take risk at the wrong times | High | Calling risk shaping “alpha,” leverage, estimation lag, and turnover | Overlay POC after a base strategy |
| Value, quality, and profitability | Long-horizon risk premia and slow fundamental repricing | Medium; requires point-in-time fundamentals and a broad universe | Revised fundamentals, stale universe membership, long droughts, and factor crowding | Valuable, but more plumbing |
| Option volatility risk premium | Option buyers pay for convexity and insurance; sellers bear crash and jump risk | Operationally possible, but historical proof is currently weak with the available Alpaca archive | Severe tail loss, surface/quote errors, assignment, and short history | Do not make this the next minimal POC |
| Scalping / market making | Fast liquidity provision, queue priority, rebates, and microstructure skill | Low for ordinary retail infrastructure | Latency, adverse selection, incomplete depth, and unrealistic fills | Reject as an initial lane |

## Minimal POC 1 — T1 multi-asset trend persistence

### Question

Does a deliberately simple trend rule improve the distribution of outcomes
across a diversified set of liquid markets, rather than merely fitting one
equity bull market?

### Minimal design

- Use roughly 12–20 liquid ETFs spanning US equities, international equities,
  government bonds, gold, commodities, and selected sectors.
- Freeze only ETFs that existed and were liquid before each test boundary.
- Rebalance monthly after the close for next-open execution.
- Test one primary signal, such as trailing 12-month excess return above zero.
- Long the asset when its own trend is positive; otherwise hold cash.
- Use equal notional weights first. Test volatility scaling only as a separate
  overlay, because scaling can create much of the apparent improvement.
- Compare with static equal-weight ownership of the identical eligible assets,
  cash/no-trade, and a sign-randomized control.
- Reserve later years or a prospective period before inspecting results.

### Falsification

Stop if the result depends on one asset class, one crisis, one lookback, or
volatility scaling; disappears after next-open execution and costs; or fails
to improve either net return or drawdown behavior consistently across folds.

### Why first

It is low turnover, transparent, easily deployable with daily data, and tests a
mechanism documented across more than one asset class.

## Minimal POC 2 — M1 cross-sectional momentum

### Question

At each historical decision date, do the strongest assets in a broad,
point-in-time eligible panel continue to outperform the weakest or the panel
average over the next month?

### Minimal design

- Use 20–40 liquid sector, industry, country, and broad-asset ETFs, or a
  point-in-time liquid large-cap stock universe.
- Rank trailing 12-minus-1-month total return once per month.
- Hold the top quartile long; use cash for the remainder in the initial
  long-only version.
- Compare with equal weight across the same eligible panel, the raw ranking
  spread, random rankings, and sector-neutral rankings where relevant.
- Freeze a minimum breadth requirement and a turnover-aware hold zone before
  confirmation.
- Inspect whether results are diversified across dates and names and whether
  crash episodes dominate the distribution.

### Falsification

Stop if rank ordering is unstable, top-basket excess is concentrated in a few
assets or one regime, turnover consumes the spread, or nearby formation
horizons reverse the conclusion.

### Professional caveat

Momentum is a serious return regularity, but it can crash. Its existence does
not justify maximum concentration in recent winners.

### M1 decision and readout

The operator approved and froze the exact equity-only, measurement-first M1
contract in
`docs/GEN5_M1_CROSS_SECTIONAL_MOMENTUM_POC_CONTRACT.md`.

M1 was implemented without changing the fixed 24-ETF panel, point-in-time
eligibility, 12-minus-1 rank, next-open outcome, randomized control,
concentration caps, or M1A/M1B gate sequence. All 25 required histories shared
the same 2,638 reference sessions and all 11 integrity checks passed.

The ranking mechanism nevertheless failed four of six M1A gates:

- mean confirmation rank IC was positive at `0.029382`, but only `19 / 36`
  months were positive;
- mean top-minus-bottom return was `22.10 bp`, but only `6 / 12` quarters were
  positive;
- observed top-K excess was `26.84 bp` versus the random-policy p90 of
  `33.74 bp`; and
- emerging-country ETFs supplied `92.3%` of positive contribution, while the
  largest ETF supplied `25.4%`.

Record `STOP_M1_RANKING_MECHANISM`. M1B was structurally not run, so no
portfolio CAGR, drawdown, turnover, or P&L exists to reinterpret. Do not rescue
M1 with a new horizon, subset, group-neutral rank, or tuned concentration
rule. The next mechanism requires a fresh theory discussion and contract.

## Minimal POC 3 — S0 statistical-arbitrage admissibility

### Question

Before trading a pair, can a retail-accessible universe support rolling,
out-of-sample relative-value relationships with adequate shortability and
cost-adjusted convergence?

### Minimal design

- Begin with 37 liquid, unleveraged equity ETFs rather than hand-picked famous
  stock pairs.
- Freeze four economic groups and disclose that the panel is a current
  survivor panel, not a reconstructed historical universe.
- Use 504-session rolling TRAIN windows and quarterly OOS folds.
- Select at most three non-overlapping pairs per group by one TRAIN-only
  residual-stability score.
- Define dislocations with a TRAIN-frozen residual z score.
- Observe after the close and enter no earlier than the next regular open.
- Make 10-session convergence primary; retain 5 and 20 sessions as fixed
  diagnostics.
- Compare selected pairs with seeded random within-group policies,
  same-pair non-event dates, and no-trade.
- Require breadth across pairs, groups, quarters, and years.

The exact thresholds, universe, costs, controls, and nine gates are frozen in
`docs/GEN5_S0_STATISTICAL_ARBITRAGE_ADMISSIBILITY_CONTRACT.md`. The operator
approved that exact contract, and S0A was implemented without changing it.

### Falsification

Stop before a trading POC if pair membership is unstable, the result does not
beat randomized relationship selection, controls do not support a distinct
event effect, most apparent mean reversion occurs inside ordinary costs, or
convergence is concentrated in one pair, group, or year.

### Professional caveat

Real statistical arbitrage is a portfolio of many small residual bets with
neutralization and cost control. “These two charts look cointegrated” is not a
professional strategy.

### Borrow and claim boundary

Alpaca can report current shortability and borrow status, and hard-to-borrow
locates can be checked prospectively. Its documented interface does not provide
a general historical archive of borrow availability and fees. S0A therefore
tests historical convergence after ordinary two-leg costs only. A pass can
open an S0B prospective borrow-status shadow; it cannot retroactively establish
historical short executability.

### Frozen S0A readout

The run used explicit as-of `2026-07-24 17:30:00` and the exact frozen
37-ETF panel. All ETFs covered every actual reference session and all 12
integrity rows passed. The raw cache-health WARN reflected only the requested
weekend boundary before the first 2016 trading session, not a missing
analytical session.

Primary 10-session net convergence was `31.69 bp` and positive in `9 / 12`
quarters. That attractive average was not admissible mechanism evidence:

- breadth cleared in only `8 / 12` quarters;
- the run produced 99 eligible events and only six pairs cleared support;
- observed convergence missed the seeded random-policy p90 of `36.64 bp`;
- only `47.5%` of events had a valid frozen quiet-date match;
- one year supplied `65.5%` of positive contribution; and
- the weakest quarter retained only `22.2%` of selected relationships.

Only `3 / 9` gates passed. Record
`STOP_S0A_RELATIVE_VALUE_MECHANISM`. S0B remains closed, and the result does
not support historical-borrow, portfolio-performance, or live-short claims.

## Minimal POC 4 — E2 post-earnings drift

### Question

After a truly point-in-time earnings surprise, does issuer-relative abnormal
return continue in the surprise direction after the result becomes
executable?

### Minimal design

- Obtain timestamped earnings announcements and a non-revised surprise measure
  such as reported versus contemporaneous consensus, or freeze an explicitly
  weaker historical-surprise proxy.
- Separate premarket, regular-session, and after-close announcements.
- Enter only at the first execution time after both the announcement and the
  chosen initial-reaction measurement are known.
- Rank surprises within issuer history or contemporaneous cross-section.
- Hold for one predeclared medium horizon, such as 10 or 20 sessions.
- Compare with same-sector non-event controls and with price-gap-only controls.

### Falsification

Stop if timestamp uncertainty changes entry classification, the result exists
only when revised analyst data are used, or event drift does not exceed the
matched price-gap control.

### Practical boundary

This is attractive conceptually but is not the first detour POC because the
surprise and timestamp data require new trustworthy plumbing.

## Minimal POC 5 — I0 overnight/intraday anatomy

### Question

Where does return and risk actually occur, and does any session component
predict a later executable component after realistic delay and cost?

### Minimal design

- Use a small panel of highly liquid ETFs and large stocks.
- Decompose prior close to open, open to close, opening 5–30 minutes, and the
  remainder of the session.
- Begin as measurement only: return contribution, variance, gaps, spreads, and
  news overlap.
- Predeclare one actionable hypothesis after inspection, such as whether a
  market-adjusted overnight shock continues or reverses after 09:35.
- Require consolidated SIP data for execution-sensitive minute work; IEX-only
  data are suitable for plumbing, not a definitive US-market microstructure
  claim.
- Execute after the observation window, never at its opening price.

### Falsification

Stop if the effect is bid-ask bounce, opening-auction slippage, a few gap days,
or disappears when entry is delayed until the signal is observable.

## Minimal POC 6 — L1 short-horizon liquidity reversal

### Question

Are large market- and sector-adjusted intraday moves partly temporary, leaving
an executable reversal large enough to pay for spread and adverse selection?

### Minimal design

- Restrict the universe to very liquid, easy-to-borrow instruments.
- Use consolidated quotes and trades.
- Define one residual shock over a frozen 15–60-minute window.
- Enter in the following interval with explicit limit/market fill rules.
- Exit within hours or by the close; forbid overnight carry in the first POC.
- Compare with random shock times and with continuation.
- Attribute gross return, spread, missed fills, and slippage separately.

### Falsification

Stop if theoretical midquote returns cannot be reproduced with executable
quotes, if missed fills create the result, or if net expectancy is not robust
to a conservative extra half-spread.

## Minimal POC 7 — V1 volatility-managed overlay

### Question

Does scaling an already-defined base strategy down when estimated volatility
is high improve risk-adjusted compounding without silently adding leverage or
timing freedom?

### Minimal design

- Apply only after T1 or M1 is frozen.
- Estimate volatility from trailing data available at the decision.
- Target one fixed annualized volatility with a conservative exposure cap.
- Compare fixed-dollar and volatility-managed versions using identical
  underlying signals and execution.
- Report how much of any benefit comes from lower average exposure.

### Falsification

Stop if improvement disappears after matching average exposure, is driven by
leverage, or requires tuning the volatility window or target on confirmation
data.

## Ideas to defer

### Generic news sentiment

Sentiment can work in carefully defined contexts, but generic positive/negative
classification confounds expectations, importance, novelty, issuer exposure,
and market state. It is not a first-priority detour after the existing news
work.

### Deep learning or reinforcement learning on daily OHLCV

These methods add a large selection surface to a small, nonstationary,
low-signal dataset. They do not create an economic mechanism.

### One-pair cointegration

A single pair provides too few independent bets and encourages selection by
chart appearance.

### Retail scalping

Professional scalping and market making can work, but much of the edge comes
from latency, queue position, fee tiers, inventory control, and superior
market data. A slow retail implementation is exposed to the informed flow that
professionals are trying to avoid.

### Option premium selling as “income”

The premium compensates for nonlinear crash and jump exposure. With Alpaca
historical options data beginning only in February 2024 and feed quality
depending on indicative versus OPRA access, a convincing historical POC needs
a better archive than the current account has demonstrated.

## Recommended detour sequence

The smallest serious program tests three different mechanisms without first
building a large architecture:

1. **T1 multi-asset trend persistence** — slow behavioral/risk-transfer
   mechanism; daily data; low plumbing.
2. **M1 cross-sectional momentum** — relative ranking mechanism; monthly
   decisions; broader panel.
3. **S0 statistical-arbitrage admissibility** — stopped after convergence
   failed the frozen breadth, controls, concentration, and stability standard.

Only after those:

4. **I0 overnight/intraday anatomy**, if consolidated SIP data are available.
5. **E2 post-earnings drift**, after point-in-time earnings-surprise data are
   sourced.
6. **V1 volatility management**, attached to a frozen base strategy rather
   than presented as standalone alpha.

This sequence intentionally includes persistence, relative ranking, and mean
reversion. It gives the project a chance to learn which market mechanism fits
the operator's data, temperament, holding period, and execution constraints.

## T1 decision and readout

The operator selected T1 and froze:

- asset class and universe;
- data authority and available history;
- long-only versus long/short;
- decision and execution timestamp;
- primary benchmark and no-trade control;
- cost model;
- development and untouched confirmation windows;
- pass, stop, and prospective-shadow gates.

T1 was implemented without optimization or contract changes. The run passed
all integrity checks but failed the central persistence tests:

- confirmation pooled `ON minus OFF` separation was `-29.71 bp`;
- only `5 / 14` assets had positive full-history separation;
- confirmation T1 CAGR trailed the exposure-matched control by `0.59
  percentage points`;
- the result failed the frozen `10 bp` central-conclusion gate.

T1 did reduce confirmation maximum drawdown by `72.5%` relative to static
equal weight. That is useful risk shaping, not evidence of trend-conditioned
asset-selection edge, because the exposure-matched control compounded faster.
Record `STOP_T1_TREND_PERSISTENCE` and do not rescue T1 by changing its
lookback, deleting assets, replacing `BIL`, or adding volatility scaling.

The next recommended detour is a theory-first M1 cross-sectional momentum
discussion. M1 is a different ranking hypothesis, not permission to implement
or a continuation of T1.

Decks:

- `presentations/gen5_retail_quant_mechanism_atlas_and_t1_design.pptx`
- `presentations/gen5_t1_multi_asset_trend_evidence.pptx`
- `presentations/gen5_m1_cross_sectional_momentum_design.pptx`
- `presentations/gen5_m1_cross_sectional_momentum_evidence.pptx`
- `presentations/gen5_s0_statistical_arbitrage_design.pptx`

## Research anchors

- Moskowitz, Ooi, and Pedersen, “Time Series Momentum”:
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2089463
- Jegadeesh and Titman, “Profitability of Momentum Strategies”:
  https://www.nber.org/papers/w7159
- Gatev, Goetzmann, and Rouwenhorst, “Pairs Trading”:
  https://www.nber.org/papers/w7032
- Nagel, “Evaporating Liquidity”:
  https://academic.oup.com/rfs/article-abstract/25/7/2005/1602153
- Cliff, Cooper, and Gulen, “Return Differences between Trading and
  Non-Trading Hours”:
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1004081
- Moreira and Muir, “Volatility Managed Portfolios”:
  https://www.nber.org/papers/w22208
- Novy-Marx and Velikov, “A Taxonomy of Anomalies and Their Trading Costs”:
  https://academic.oup.com/rfs/article-abstract/29/1/104/1844518
- Gu, Kelly, and Xiu, “Empirical Asset Pricing via Machine Learning”:
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3306110
- Alpaca market-data plan and feed coverage:
  https://docs.alpaca.markets/us/docs/about-market-data-api
- Alpaca short-selling and locate boundary:
  https://docs.alpaca.markets/us/docs/margin-and-short-selling
- Alpaca historical-options boundary:
  https://docs.alpaca.markets/us/docs/historical-option-data
