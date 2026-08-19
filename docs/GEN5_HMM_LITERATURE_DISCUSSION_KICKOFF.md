# Gen5 Hidden Markov Model Literature Discussion Kickoff

Status: `DISCUSSION_OPEN_IMPLEMENTATION_NOT_AUTHORIZED`

Date: 2026-08-17

## Where This Lane Sits

The T1-T5 trend-indicator series is closed. Its common validation surface was
the causal SMA8/SMA14 parent strategy, on daily data and, where relevant, the
separate 30-minute research surface. Failure to improve that parent does not
show that ADX, Kaufman efficiency ratio, breadth, change-point, multi-horizon,
or range-persistence concepts are categorically invalid. It shows only that
the frozen measurements and gates did not deliver the intended value for that
specific parent and those tested frequencies.

The proposed Hidden Markov Model (HMM) lane is not a rescue of those tests. It
is a new literature-grounded question: can several observable measurements be
explained by a small, persistent, unobserved state process in a way that is
causally inferable, stable, and useful before any strategy is allowed to see
it?

## Recommended Reasoning Level

Use **high or xhigh reasoning** for the substantive literature synthesis and
contract discussion. The central risks are conceptual rather than coding
difficulty:

- confusing a generic HMM with a Hamilton-style Markov-switching regression;
- presenting smoothed or Viterbi hindsight states as live-known states;
- treating a state label such as `bull` or `bear` as discovered truth;
- allowing information criteria alone to determine the number of states;
- mistaking in-sample segmentation for forecasting or trading authority;
- letting a flexible emission model absorb outliers as extra `regimes`;
- losing state identity when the model is refit through time.

## Plain-English Model

An HMM assumes that the market occupies one of a small number of hidden states.
We cannot observe the state directly. We observe emissions--for example,
returns, volatility measurements, or cross-sectional measurements--whose
distribution depends on the current state.

The model has three core pieces:

1. an initial probability for each state;
2. a transition matrix describing how likely each state is to persist or
   switch; and
3. an emission distribution describing what observations tend to look like in
   each state.

The important output is a probability distribution, not an oracle label. At
the end of session `t`, a causal regime estimate is:

`Pr(S_t = k | observations through t)`

and the one-step state forecast is that filtered probability multiplied by the
transition matrix. A smoothed estimate instead uses observations after `t`.
It is valuable for retrospective diagnosis but is leakage if presented as
information available at `t`.

## HMM Versus Markov-Switching Regression

`HMM` is the broader generative framework: a discrete hidden Markov chain
governs the distribution of observed data. Hamilton's canonical econometric
model is a member of the broader regime-switching family in which parameters
of a time-series regression change with the hidden state. The two labels are
often used loosely in finance, but the implementation contract must specify
which object is actually being fit.

For a first exercise, a basic finite-state HMM is easier to audit. A
state-dependent autoregression, GARCH process, time-varying transition model,
or hidden semi-Markov model would be a separate complexity decision.

## Source Ledger and Reading Sequence

### Tier 1: Foundations

1. **Lawrence Rabiner (1989), "A Tutorial on Hidden Markov Models and Selected
   Applications in Speech Recognition."** Read the model elements and three
   basic problems on published pages 257-261, then the forward, Viterbi, and
   Baum-Welch solutions on pages 261-267. The application is speech, but the
   probability machinery is the canonical foundation.
   [PDF](https://www.fceia.unr.edu.ar/prodivoz/Rabiner_1989.pdf) |
   [DOI](https://doi.org/10.1109/5.18626)

2. **Walter Zucchini, Iain MacDonald, and Roland Langrock (2016), _Hidden
   Markov Models for Time Series: An Introduction Using R_, second edition.**
   Prioritize the chapters on preliminaries, basic HMM formulation, estimation,
   forecasting/decoding/state prediction, model selection/checking, and the
   financial-series application. This is the best primary textbook for the
   project's R-first and beginner-accessible needs.
   [Publisher page](https://www.routledge.com/Hidden-Markov-Models-for-Time-Series-An-Introduction-Using-R-Second-Edition/Zucchini-MacDonald-Langrock/p/book/9781032179490)

3. **James Hamilton (1989), "A New Approach to the Economic Analysis of
   Nonstationary Time Series and the Business Cycle."** Read pages 357-384 for
   the finance/econometrics bridge: state-dependent autoregressive parameters,
   probabilistic inference about unobserved regimes, nonlinear filtering,
   maximum likelihood, and forecasting.
   [Bibliographic record](https://ideas.repec.org/a/ecm/emetrp/v57y1989i2p357-84.html) |
   [PDF mirror](https://citeseerx.ist.psu.edu/document?doi=de6046f58a05a769b5aa526d95a09c5fa5e5b42c&repid=rep1&type=pdf)

### Tier 2: Financial Interpretation and Validation Discipline

4. **Andrew Ang and Allan Timmermann (2012), "Regime Changes and Financial
   Markets."** Use this survey to understand why regimes may differ in means,
   volatilities, autocorrelations, and cross-covariances, and why abrupt but
   persistent behavior motivates regime-switching models. It also prevents us
   from reducing `regime` to a bullish/bearish color overlay.
   [Annual Reviews](https://www.annualreviews.org/content/journals/10.1146/annurev-financial-110311-101808) |
   [NBER PDF](https://www.nber.org/papers/w17182.pdf)

5. **Jennifer Pohle, Roland Langrock, Floris van Beest, and Niels Schmidt
   (2017), "Selecting the Number of States in Hidden Markov Models."** Read
   Sections 2-4, especially the simulations and pragmatic order-selection
   procedure. Its central warning is directly relevant: AIC or BIC can favor
   extra states that merely absorb misspecification or a few unusual
   observations rather than represent meaningful regimes.
   [Preprint](https://arxiv.org/abs/1701.08673) |
   [DOI](https://doi.org/10.1007/s13253-017-0283-8)

6. **Ingmar Visser and Maarten Speekenbrink (2010), "depmixS4: An R Package
   for Hidden Markov Models."** Treat this as an implementation reference, not
   a decision to add a dependency. It documents EM estimation, multivariate
   emissions, constraints, and posterior state probabilities in an R-native
   framework.
   [Journal of Statistical Software](https://www.jstatsoft.org/article/view/v036i07) |
   [CRAN documentation](https://search.r-project.org/CRAN/refmans/depmixS4/html/00Index.html)

### Tier 3: Applied Finance Examples, Read Critically

7. **Peter Nystrup, Henrik Madsen, and Erik Lindstrom (2017), "Dynamic
   Portfolio Optimization Across Hidden Market Regimes."** This is useful for
   seeing a causal, delayed, transaction-cost-aware connection from state
   inference to a decision process. Its model-predictive-control and portfolio
   optimization layer is far beyond the proposed minimal POC and must not be
   imported automatically.
   [Author manuscript record](https://orbit.dtu.dk/en/publications/dynamic-portfolio-optimization-across-hidden-market-regimes/) |
   [DOI](https://doi.org/10.1080/14697688.2017.1342857)

8. **Andrew Ang and Geert Bekaert (2002), "International Asset Allocation with
   Regime Shifts," plus their related "How Do Regimes Affect Asset
   Allocation?"** These are useful demonstrations that regime differences can
   matter economically while remaining difficult to exploit. They belong
   after the statistical foundations, not before them.
   [Review of Financial Studies DOI](https://doi.org/10.1093/rfs/15.4.1137) |
   [related working paper](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=310626)

### Optional Video Bridge

- **IIT Bombay / NPTEL, Natural Language Processing, Lectures 16-21.** The
  sequence covers HMMs, Viterbi, forward-backward inference, and Baum-Welch.
  It is a visual bridge to the algorithms, not the authority for financial
  design.
  [Course page](https://www.nptel.ac.in/courses/106101007)

## Preliminary Recommendation for the First Discussion

Start with a **descriptive, finite-state, daily HMM POC**, not an HMM trading
strategy. The smallest serious question is:

> Can a small HMM trained only on completed development observations produce
> causally filtered state probabilities whose emission distributions,
> occupancy, duration, transition behavior, and identities remain stable in a
> later held-out development segment and improve held-out data likelihood over
> a one-state baseline?

This formulation does not yet freeze:

- the asset or cross-sectional universe;
- two versus three states;
- observed inputs or transformations;
- Gaussian versus heavy-tailed emissions;
- rolling versus expanding estimation;
- state-matching rules across refits;
- probability thresholds or hysteresis;
- strategy contact, ATR% joins, leverage, allocation, or confirmation access.

### Why this is the recommended first step

- It tests whether the latent-state model earns its complexity before asking
  it to create alpha.
- It separates present-state inference from next-state forecasting.
- It makes the one-state model and simple observable regimes legitimate
  competitors.
- It gives the operator a visible probability tape, transition matrix, dwell
  distribution, and filtered-versus-smoothed comparison.
- It permits synthetic recovery tests before any market interpretation.

## Candidate Validation Layers for Discussion

### Construction and causality

- exact synthetic recovery under separable states;
- append invariance for historical filtered probabilities;
- filtered probabilities computed with data through `t` only;
- smoothed/Viterbi states quarantined to retrospective diagnostics;
- multiple deterministic initializations with convergence and likelihood
  diagnostics;
- explicit handling of label permutations.

### Descriptive and generative value

- held-out log likelihood versus a one-state emission model;
- probability calibration on synthetic data;
- emission separation with uncertainty, not just colored state charts;
- transition counts, occupancy, dwell distributions, and effective numbers of
  state changes;
- posterior predictive or residual checks;
- stability of state identity and parameters across folds/refits.

### Only after descriptive promotion

- a separately frozen strategy overlay;
- unchanged parent mechanics and causal next-open execution;
- exposure-matched timing controls and no-trade;
- costs, turnover, and delay sensitivity;
- sealed confirmation retained until all development gates pass.

## Professional Pushback

An HMM does not discover the market's true regimes. It estimates a compact
latent explanation under assumptions we chose. Clean-looking hindsight bands
can be manufactured by smoothing, flexible emissions, or too many states.
Financial returns are heavy-tailed, mean differences are difficult to
estimate, and regime transitions are few relative to the number of daily bars.
The effective sample size for a regime policy is closer to the number of
independent transitions than the number of observations.

For those reasons, the first lane should not begin with a three-state
`bull/chop/bear` trading rule. It should begin by asking whether a small model
is identifiable, causal, stable, and generatively better than a simpler
baseline.

## Current Stop State

The literature discussion is open. No HMM package, model, state count,
feature set, provider query, training window, strategy, allocation rule,
leverage policy, live behavior, or confirmation access is authorized by this
document. The next gate is operator discussion of the source hierarchy and
the preliminary descriptive POC question.

The first concrete proposal is documented in
[GEN5_LIT_REG_01_1_HMM_POC_DESIGN_DISCUSSION.md](GEN5_LIT_REG_01_1_HMM_POC_DESIGN_DISCUSSION.md).
It recommends a two-observation SPY daily HMM, a static-mixture baseline, four
expanding development folds, causal filtered probabilities, and no strategy
contact. The operator approved those principal choices. The exact contract is
now frozen at
[GEN5_LIT_REG_01_1_HMM_REGIME_POC_CONTRACT.md](../literature_studies/docs/GEN5_LIT_REG_01_1_HMM_REGIME_POC_CONTRACT.md),
with implementation still unopened.
