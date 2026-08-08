# HYP-MOM-02.2 SMA200 Entry / SMA50 Exit Discovery Results

Status: `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`

## Answer in one paragraph

The asymmetric `02.2` state machine was a meaningful defensive improvement
over cross-only `02.1` in this reused 2021-2023 window, but not a demonstrated
generic timing edge. Median return rose from `-2.73%` to `+0.38%`, while median
maximum drawdown improved by `+11.09` percentage points and exposure fell from
`43.48%` to `16.76%`. Sixty-four of 119 assets improved both return and
drawdown relative to `02.1`. However, `02.2` still lagged buy-and-hold by a
median `-22.20` points, beat ownership in only 32 assets, and ranked at only the
`42.9th` median percentile of exposure-matched circular shifts. The result is
best understood as a selective, cash-heavy composite rule—not validation that
SMA50 is an optimal exit.

## What was actually tested

Every eligible asset started in cash. A fresh in-window close cross above
SMA200 qualified for next-open entry only when that signal close was also above
SMA50. While long, the first completed close at or below SMA50 exited at the
next open. Recovery above SMA50 did not re-enter; a new qualified SMA200 cross
was required.

That last point matters for attribution. `02.2` is not a pure one-variable exit
swap. Relative to `02.1`, it combines:

1. an SMA50 entry-coherence check;
2. an SMA50 long-state exit;
3. strict re-entry lockout until another SMA200 cross.

The experiment therefore evaluates the full predeclared state machine.

## Coverage and integrity

- registered: 122 stocks across 11 sectors;
- eligible: 119;
- excluded without replacement: APHA and SNE for incomplete discovery history,
  and LI for insufficient prehistory;
- window: January 4, 2021 through December 29, 2023;
- 2024+ remained excluded;
- primary and stress costs: 5 and 10 bp per side;
- all paths started cash;
- all 637 entries followed qualified completed-close signals;
- no lockout session carried exposure;
- buy-and-hold paths matched the `02.1` control exactly;
- every integrity check passed.

## The three useful HYP-MOM-02 views

The earlier warm-start result remains useful because it answers a different
question. It should be retained beside the event-triggered strategies without
being mistaken for the same estimand.

| View | Question | Round trips | Median return | Median exposure | Beat buy-and-hold | Assets improving drawdown vs buy-and-hold |
|---|---|---:|---:|---:|---:|---:|
| `02.1` state ownership | Own whenever already above SMA200, including the boundary | 1,729 | +6.24% | 60.82% | 30 / 119 | 79 / 119 |
| `02.1` fresh cross | Start cash; require a new SMA200 cross; exit below SMA200 | 1,624 | -2.73% | 43.48% | 26 / 119 | 88 / 119 |
| `02.2` asymmetric | Qualified SMA200 entry; SMA50 exit; strict new-cross re-entry | 637 | +0.38% | 16.76% | 32 / 119 | 113 / 119 |

The warm-start and cross-only rows are alternative `02.1` estimands within the
same investigation. `02.2` is the first formal mechanics revision.

## Direct comparison with authoritative cross-only 02.1

| Metric | `02.1` fresh cross | `02.2` asymmetric | Change |
|---|---:|---:|---:|
| Median primary return | -2.73% | +0.38% | +3.57 pp median asset-level change |
| Median maximum drawdown | -28.11% | -16.14% | +11.09 pp median asset-level change |
| Median exposure | 43.48% | 16.76% | -26.72 pp |
| Median trade count | 13 | 5 | -8 |
| Assets with higher return | — | 65 / 119 | — |
| Assets with improved drawdown | — | 105 / 119 | — |
| Assets improving both | — | 64 / 119 | — |

Only one asset improved return without improving drawdown. Forty-one improved
drawdown while sacrificing return, and 13 improved neither. The dominant
effect was less exposure and shallower losses, not broader upside capture.

## The rule was extremely selective

The panel generated:

- 637 completed `02.2` round trips;
- 656 SMA200 crosses skipped because the signal close was not above SMA50;
- 75 median strict-lockout sessions per asset;
- 22.25 median within-asset holding duration;
- 16.76% median time invested.

The pooled trades were `34.69%` positive, with a `-1.72%` median and only
`+0.08%` mean. Median pooled duration was 18 sessions, mean duration 24.3, and
53.22% lasted 20 sessions or fewer. This remains a right-skewed, low-hit-rate
trend structure, but with fewer attempts and much more cash than `02.1`.

## A faster average did not always produce an earlier exit

SMA50 reacts faster to price, but it is not always above SMA200. During weak or
recovering regimes it can sit below the slow average. Therefore crossing below
SMA50 can occur after crossing below SMA200.

Across 637 matched entries:

- `02.2` exited earlier than `02.1` 155 times;
- both exited on the same session 176 times;
- `02.2` exited later 306 times.

Among the 155 genuinely earlier exits, the median lead was 16 trading sessions.
Price subsequently declined before the `02.1` exit in 123 cases, rose in 31,
and was unchanged in one. The median return from the early `02.2` exit open to
the later `02.1` exit open was `-2.27%`, so the genuinely early subset usually
saved downside. These are retrospective diagnostics, not foresight available
at the exit.

## Ownership and timing controls remain sobering

`02.2` had a median `+0.38%` asset return versus `+20.79%` for buy-and-hold.
Only 32 of 119 assets beat ownership. Maximum drawdown improved versus
buy-and-hold in 113 assets, by a median `+19.46` percentage points. This is a
clear return/protection tradeoff.

The median actual schedule ranked at the `42.9th` percentile of 500 circular
shifts preserving its exposure fraction and block structure. Forty-nine assets
ranked above the 50th percentile and six above the 80th. Thus the amount and
shape of cash exposure explain much of the defense; the observed calendar
alignment was not broadly exceptional.

## Frozen cohort readout

| Cohort | Assets | Median `02.1` | Median `02.2` | Median buy-and-hold | Median `02.2` change |
|---|---:|---:|---:|---:|---:|
| Original 22 | 22 | +4.63% | +3.06% | +35.41% | -1.16 pp |
| Diversified core | 75 | -1.05% | +0.49% | +25.06% | +2.94 pp |
| Retail attention 2020 | 22 | -18.67% | -9.58% | -31.26% | +8.27 pp |

The attention cohort again looks like loss mitigation, not positive alpha: the
median `02.2` path still lost money. The original 22 cohort shows that the
composite did not improve every predeclared panel.

## Representative paired tapes

The mechanically selected tapes expose both the value and cost of selectivity:

- `CSCO`, median return change: `02.2 -2.5%` versus `02.1 -6.1%`; defense
  improved, but both strategies lost and ownership gained.
- `TSLA`, largest improvement: `+42.3%` versus `-3.2%`, with drawdown improving
  by 11.1 points. Selective participation helped materially in this path.
- `LLY`, largest deterioration: `0.0%` versus `+126.4%`. Every cross was
  disqualified below SMA50, so the rule missed an exceptional trend entirely.
- `SQ`, largest drawdown improvement: `+15.9%` versus `-18.6%`, with drawdown
  improving by 28.3 points.
- `ORLY`, largest exposure reduction: `+6.3%` versus `+74.4%`. Strict lockout
  preserved little of a persistent trend.
- `PEP`, most lockout: 355 sessions; `+5.3%` versus `+17.0%`.

The tapes make the central mechanism visible: the same cash discipline that
rescues TSLA and SQ can abandon LLY, ORLY, and PEP.

## Decision

Record `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`.

`HYP-MOM-02.2` is more encouraging than the fresh-cross `02.1` control as a
defensive state machine. It improved both return and drawdown in a majority of
assets and converted the median path from a small loss to roughly flat. But it
achieved this with only 16.76% exposure, extensive signal rejection, and long
re-entry lockouts; it still failed the ownership and matched-timing readouts.

Do not call SMA50 optimal, isolate the result as an exit-only effect, tune either
moving average, allow recovery re-entry, select favorable assets or cohorts,
or inspect 2024+ from this packet. No portfolio, allocation, live-advice, or
execution authority is created.
