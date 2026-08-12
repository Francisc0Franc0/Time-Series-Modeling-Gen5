# HYP-MOM-04.3A Target Structure Audit Results

Status: `TARGET_AUDIT_COMPLETE_SELECTION_NOT_FROZEN`

## Question

Did the H04.2 next-quarter target mix stock-specific selection with sector
leadership and prior-beta exposure, and would a clearer target materially
change the feature evidence?

## Scope and boundary

The audit reused the retained H04.2 TRAIN panel:

- 481 identities and 7,208 stock-quarter rows;
- 15 signal quarters, `2017Q1-2020Q3`;
- outcomes ending no later than `2020-12-31`;
- 33 unchanged causal OHLCV features; and
- zero provider calls and zero 2021+ observations.

All 11 integrity checks passed. The effective temporal sample remains 15
market quarters, not 7,208 independent environments.

## Terminology correction

H04.2 implemented next-quarter return minus the eligible-universe mean. It did
not literally subtract SPY. Subtracting SPY would leave cross-sectional ranks
unchanged because the same quarter-level constant is removed from every stock,
but it would change numerical excess-return levels. This audit therefore names
the reference target `UNIVERSE_RELATIVE`.

## Three questions, not three cosmetic normalizations

| Target | Economic question | What it removes |
|---|---|---|
| `UNIVERSE_RELATIVE` | Which stocks beat the eligible universe? | Quarter-level universe mean |
| `SECTOR_RELATIVE` | Which stocks beat their sector peers? | Quarter and sector means |
| `SECTOR_BETA_RESIDUAL` | Which stocks beat what sector and prior beta imply? | Quarter-specific sector fixed effects and linear prior-beta exposure |

The third target is an OLS residual. It is a diagnostic challenger, not an
automatic improvement merely because it removes more variation.

## Sector and beta are material—but time-varying

Across the 15 TRAIN quarters:

- sector alone explained `16.7%` of cross-sectional next-quarter return
  variation on average;
- prior 126-session beta alone explained `9.3%`;
- sector plus beta explained `21.4%`; and
- beta added `4.7` percentage points of R-squared after sector on average.

The average understates regime variation. Sector plus beta explained `46.2%`
in `2020Q3`, including `42.0%` from beta alone. This was also H04.2's worst
outer quarter. The earlier failure therefore contained a large environment-
exposure component, although this audit does not prove that target confounding
was the only cause.

## The target changes who counts as a winner

Average pairwise agreement was:

| Pair | Rank correlation | Top-quartile Jaccard overlap |
|---|---:|---:|
| Universe vs sector | `0.887` | `0.657` |
| Universe vs sector+beta residual | `0.853` | `0.620` |
| Sector vs sector+beta residual | `0.960` | `0.823` |

Thus sector neutralization changes roughly one-third of realized top-quartile
membership relative to the reference. Beta residualization usually makes a
smaller additional change, but not always: in `2020Q3`, sector versus residual
rank agreement fell to `0.777` and top-quartile overlap to `0.503`.

## Sector-relative targeting reduces concentration cleanly

The average largest-sector share of each target's realized top quartile was:

- universe-relative: `22.7%`;
- sector-relative: `16.7%`; and
- sector+beta residual: `16.9%`.

Sector-relative and residual targets therefore produce nearly the same sector-
concentration benefit. The residual target's extra complexity does not buy a
meaningful average concentration improvement.

Cross-sectional target standard deviation fell from `12.69%` universe-relative
to `11.49%` sector-relative and `11.05%` residualized. Tail influence did not
disappear: the largest 1% of absolute targets still supplied about `5.2%-5.4%`
of total absolute target magnitude.

## Several attractive H04.2 relationships were exposure-sensitive

| Feature | Universe-relative mean IC | Sector-relative | Sector+beta residual |
|---|---:|---:|---:|
| `beta126` | `+0.0609` | `+0.0254` | `-0.0124` |
| `rv126` | `+0.0512` | `+0.0218` | `-0.0162` |
| `downside_vol63` | `+0.0421` | `+0.0125` | `-0.0214` |
| `trend_r2_63` | `+0.0433` | `+0.0236` | `+0.0184` |
| `recovery_from_low252` | `+0.0366` | `+0.0268` | `+0.0227` |

The pooled risk-seeking signal that looked strongest in H04.2 shrinks after
sector neutralization and reverses after linear beta removal. This does not
make the residual target true by definition; it shows that the original
feature evidence partly described rewarded market exposure.

Target definition can also flip a feature conclusion. `momentum_accel63_126`
moved from `-0.0495` universe-relative to `-0.0078` sector-relative and
`+0.0220` residualized, the largest observed mean-IC shift (`0.0715`). No such
shift is a promotion result.

## Recommendation for discussion

`SECTOR_RELATIVE` is the recommended next target to consider freezing because
it most directly answers the investable stock-selection question, removes a
material and unstable sector component, sharply reduces winner concentration,
and remains easy to explain and audit.

`SECTOR_BETA_RESIDUAL` should remain a diagnostic challenger. It is especially
informative in beta-dominated environments, but it adds estimation and
interpretation complexity while producing a very similar average ranking and
sector-concentration profile.

This recommendation is not a frozen selection. No Ridge fit, feature basket,
portfolio, trading metric, permutation, or OOS observation was run. A new
contract and explicit operator decision are required before model research
continues.

## Evidence

- packet:
  `runs/research_workbench/operator_hypothesis_lab/hyp_mom_04_3a_target_structure_audit_20260811/`;
- contract:
  `operator_hypothesis_lab/docs/HYP_MOM_04_3A_TARGET_STRUCTURE_AUDIT_CONTRACT.md`; and
- deck:
  `operator_hypothesis_lab/presentations/hyp_mom_04_3a_target_structure_audit_evidence.pptx`.
