# Gen5.1 Chart Aesthetic

## Purpose

Gen5.1 charts should look consistent even while they are still dry inspection outputs. The current aesthetic is dependency-free and implemented in `g5_chart_aesthetic()` inside `R/workbench_chart.R`.

The palette is inspired by vaporwave contrast and Wes Anderson-style warmth: soft paper backgrounds, saturated teal/rose trade direction colors, and a restrained ink color for axes and text.

## Core Colors And Symbols

| Role | Color | Symbol / Line |
| --- | --- | --- |
| Chart background | `#FFF8EF` | soft warm page |
| Panel background | `#FFFDF8` | near-white plot panel |
| Grid | `#E8DED2` | quiet warm grid |
| Axis/text ink | `#3A3442` / `#242033` | muted dark plum |
| Up candlestick | `#00A88F` | teal body/wick |
| Down candlestick | `#F15A5A` | coral body/wick |
| Flat candlestick | `#6E6878` | muted gray-plum |
| Entry signal | `#00B4D8` | hollow circle, `pch = 21` |
| Exit signal | `#FF9F1C` | hollow square, `pch = 22` |
| Native trade entry | `#2E86AB` | filled triangle up, `pch = 24` |
| Native trade exit | `#F6C85F` | filled triangle down, `pch = 25` |
| Non-native exit | `#9B5DE5` | cross, `pch = 4` |
| Winning round-trip connector | `#00A88F` | dashed line |
| Losing round-trip connector | `#F15A5A` | dashed line |
| Equity baseline | `#000000` | solid line |
| Equity drawdown shading | `#F15A5A` | soft alpha area below high-water mark |

## Layout Rules

- Single-symbol charts may show their own x/y axis labels.
- Multi-symbol pane charts should share outer x/y axis labels.
- Date tick labels should use a 45-degree angle.
- Signal markers belong on the bar whose close generated the decision.
- Execution markers belong on the next-open bar where the trade is modeled as filled.
- Equity curves should show the diagnostic strategy against a no-leverage buy-and-hold baseline when a baseline is included.
- Strategy drawdowns should be shaded as the actual area between equity and the running high-water mark, not as full-height background bands.
- Generated charts and reports belong under ignored `runs/` paths.
- Chart styling must remain separate from research claims: inspection charts do not imply strategy, returns, WFA, allocation, live advice, or performance evidence.
