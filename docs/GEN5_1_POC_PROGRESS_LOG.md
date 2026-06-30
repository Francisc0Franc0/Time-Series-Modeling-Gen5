# Gen5.1 POC Progress Log

## Purpose

This log is the concise memory of the Gen5/Gen5.1 proof-of-concept pathway. It records the conceptual POCs we have run, the question each POC answered, the primary artifact folders, and the practical readout or next decision.

This is not a performance leaderboard and not an allocation approval record. Unless an entry explicitly says otherwise, every result here is research/inspection evidence only.

## Status Legend

- `INSPECTION`: useful artifact or audit surface; not accepted research or allocation evidence.
- `PROMISING`: worth retesting, expanding, or keeping as a contender.
- `DEPRECATED`: unlikely to remain a primary path, based on current inspection.
- `BLOCKED`: needs data, code, or operator decision before continuing.
- `ACCEPTED_DIRECTION`: operator-approved direction for further research work; still not live advice or deployment evidence.

## Closeout Rule

At the conclusion of each future POC or research-inspection slice, add or update one entry here with:

- the question;
- the scope;
- the main artifact folder or report;
- the short readout;
- the next decision or STOP state.

## Timeline

| POC | Status | Question | Main Artifacts | Readout / Decision |
|---|---|---|---|---|
| 01. Data Layer And Research Workbench | `ACCEPTED_DIRECTION` | Can Gen5 reliably pull, cache, audit, and chart Alpaca adjusted daily bars with explicit `as_of_timestamp` discipline? | [data proofs](../runs/research_workbench/data_proofs), [multi-symbol reports](../runs/research_workbench/multi_symbol_reports), [data-layer freeze evidence](GEN5_V0_DATA_LAYER_FREEZE_EVIDENCE.md), [research workbench doc](GEN5_V0_1_RESEARCH_DATA_WORKBENCH.md) | Established the auditable adjusted-daily data base. This remains the foundation for later POCs. |
| 02. Static Strategy Demos | `INSPECTION` | Can simple long-only strategy demos produce legible charts, leverage variants, and trade/equity artifacts? | [strategy demos](../runs/research_workbench/strategy_demos) | Proved charting, event annotation, and simple strategy artifact mechanics before rolling WFA. |
| 03. Minimal EMA WFA | `ACCEPTED_DIRECTION` | Can AMD EMA crossover be run as a bounded WFA POC with fold artifacts and no OOS leakage? | [WFA POCs](../runs/research_workbench/wfa_pocs), commits `297b41d`, `5aa1833` | Established the first WFA skeleton and manifest/report shape. |
| 04. Multi-Fold Stitched WFA | `ACCEPTED_DIRECTION` | Can rolling folds be stitched into an OOS inspection surface with fold-shaded charts and carried-trade accounting? | [WFA POCs](../runs/research_workbench/wfa_pocs), commits `2c84df6`, `c5fde12` | Stitched OOS mechanics became the reusable downstream inspection shape. |
| 05. Multi-Signal And Exit-Stack WFA | `PROMISING` | Can multiple strategy families and close-based exit stacks compete inside the WFA structure? | [WFA POCs](../runs/research_workbench/wfa_pocs), commits `e798a39`, `a032429`, `2370a70`, `bdffc00`, `1170004` | Expanded from a single EMA family to a broader candidate set with `no_trade` as a first-class competitor. |
| 06. Multi-Asset WFA Contact Sheets | `INSPECTION` | Can several symbols be inspected together with compact contact sheets and comparable artifacts? | [WFA POCs](../runs/research_workbench/wfa_pocs), commits `f4984ae`, `46bb182` | Created scalable visual review surfaces for multi-asset WFA outputs. |
| 07. PCA Regime Diagnostic POC | `ACCEPTED_DIRECTION` | Can PCA states be fit on TRAIN windows and scored into OOS as frozen regime labels? | [regime POCs](../runs/research_workbench/regime_pocs), commits `57a37ca`, `743c9c4`, `ff233f9` | Established PCA state-space diagnostics and report/plot conventions. |
| 08. PCA-Routed WFA | `PROMISING` | Can fold-local PCA states route TRAIN-selected strategy specs into OOS without leakage? | [regime WFA POCs](../runs/research_workbench/regime_wfa_pocs), commits `a28e31a`, `5ec579c` | Connected PCA state assignment to WFA routing. Five-fold routing became the base research engine pattern. |
| 09. PCA State-Map Variants | `PROMISING` | How do quantile-grid and k-means state maps change PCA-routed WFA behavior? | [regime POCs](../runs/research_workbench/regime_pocs), [regime WFA POCs](../runs/research_workbench/regime_wfa_pocs), commit `9d8dbe5` | Added k-means state assignment as a serious contender against 3x3 quantile bins. |
| 10. Regime Context Universe POC | `ACCEPTED_DIRECTION` | Can PCA regime context be built from assets beyond the traded target while preserving TRAIN-only fitting? | [regime WFA POCs](../runs/research_workbench/regime_wfa_pocs), commit `2cf8248` | Opened the context-universe research path: target, tradeable, and context universes can be separated. |
| 11. Behavioral-Pool PCA Mode | `PROMISING` | Does pooled asset-day PCA provide a useful alternative to date-aligned contextual snapshots? | [regime WFA POCs](../runs/research_workbench/regime_wfa_pocs), commit `811e104` | Added the second PCA panel mode. This became important in later context-universe and portfolio inspections. |
| 12. PCA Router Workbench And Comparison Reports | `ACCEPTED_DIRECTION` | Can panel/state-map permutations be compared with contact sheets and summary reports? | [regime WFA comparisons](../runs/research_workbench/regime_wfa_comparisons), commits `b35ff8d`, `322fe97`, `7015e8e` | Made PCA routing comparisons easy to inspect without manually opening every child packet. |
| 13. PCA Feature Enrichment | `PROMISING` | Do chop and return-skew features improve the regime feature surface enough to keep? | [regime WFA POCs](../runs/research_workbench/regime_wfa_pocs), commit `b9142d5` | Added richer regime inputs while preserving the TRAIN/OOS contract. |
| 14. Context-Universe Panels And Overview Graphics | `PROMISING` | How does regime context size/composition affect PCA routing and state coverage? | [regime WFA universe comparisons](../runs/research_workbench/regime_wfa_universe_comparisons), commits `57cb396`, `8fee124` | Produced visual context-universe comparison panels. Active-plus-risk context started to look more interesting than active-only or external-only context. |
| 15. Portfolio Accounting POC | `INSPECTION` | Can existing PCA-routed WFA child packets be consumed by a portfolio accounting surface for downstream inspection? | [portfolio strategy POCs](../runs/research_workbench/portfolio_strategy_pocs), commits `857e47a`, `756f7cb` | Established portfolio accounting as an inspection layer only. Added passive baselines for context, not allocation acceptance. |
| 16. Research Engine Contract | `ACCEPTED_DIRECTION` | Can we formalize the leakage-safe Gen5.1 research engine contract before expanding factorial runs? | [research engine contract](GEN5_1_RESEARCH_ENGINE_CONTRACT.md), commit `2c60505` | Clarified universe roles, artifact expectations, STOP decisions, and the portfolio-accounting boundary. |
| 17. Context-Universe Factorial Portfolio Wrapper | `PROMISING` | For the same active set, how do active-self, active-plus-risk, and ex-active market-risk contexts behave downstream? | [context-universe factorials](../runs/research_workbench/context_universe_factorials), commits `e8dc6a9`, `57827b9` | Created top-level run spec, taxonomy, portfolio index, summary CSV, and report. Active-plus-risk context looked most intuitively and empirically promising in inspection. |
| 18. Medium Context Factorial Grid | `PROMISING` | How do context universe, PCA panel mode, and state map interact across a broader but still bounded grid? | [medium context factorial packet](../runs/research_workbench/context_universe_factorials/ctxfac_A5_5f_3u_4s_20260624_20260624173000), commit `617eeca` | Compared contextual snapshot vs behavioral pool and quantile vs k-means across three context universes. Reinforced active-plus-risk as the context to keep exploring. |
| 19. Auto k-Means State-Map Triage | `PROMISING` | Within active-plus-risk behavioral-pool PCA, should k-means use fixed k=9 or select k TRAIN-only from 2..9? | [state-map triage packet](../runs/research_workbench/context_universe_factorials/ctxfac_A5_5f_1u_3s_20260624_20260624173000), commit `be42f67` | Added `pca_kmeans_auto` using TRAIN-only Calinski-Harabasz selection. Auto-k selected fold sequence `5,4,5,8,4` and looked promising in inspection versus 3x3 and fixed k9. |
| 20. State-Map Visual Audit Sheets | `ACCEPTED_DIRECTION` | Can the binning choices be audited visually at the top level instead of hunting through child folders? | [visual audit index](../runs/research_workbench/context_universe_factorials/ctxfac_A5_5f_1u_3s_20260624_20260624173000/context_universe_factorial_visual_audit_index.csv), [visual audit folder](../runs/research_workbench/context_universe_factorials/ctxfac_A5_5f_1u_3s_20260624_20260624173000/state_map_visual_audit), commit `4c294a5` | Added per-symbol 3x3-vs-k9 PCA scatter/state-band sheets and auto-k multi-panel sheets. This is now the visual audit pattern for state-map triage runs. |
| 21. Fixed-k State-Map Scale Triage | `PROMISING` | Within active-plus-risk behavioral-pool PCA, does forcing more k-means clusters improve the state map versus 3x3 and fixed k9? | [June fixed-k scale packet](../runs/research_workbench/context_universe_factorials/ctxfac_A5_5f_1u_3s_fixedkscale_20260624_20260624173000), [March fixed-k scale packet](../runs/research_workbench/context_universe_factorials/ctxfac_A5_5f_1u_3s_fixedkscale_20260331_20260331173000) | June ranked fixed k9 ahead of 3x3 and k15 on inspection metrics; k15 was weaker and operationally heavier with k-means warnings. March also ranked k9 best, but every symbol had partial-history WARNs, so March is caveated and should not be treated as clean confirmation without refresh/audit. |

## Current Research Posture

The current most useful branch of the POC pathway is:

1. Keep Active Allocation / Research Candidate / Tradeable Universe at `AMD,NVDA,TSLA,COIN,MSTR` unless explicitly revised.
2. Keep active-plus-risk context as the leading context universe candidate for the next narrow tests.
3. Keep behavioral-pool PCA and k-means variants in contention, with fixed k15 deprioritized unless visual review reveals a compelling niche.
4. Treat fixed k9 and `pca_kmeans_auto` as the main state-map contenders, but not accepted, until they survive clean confirmation runs.
5. Continue using portfolio accounting only as a downstream inspection layer.

## Next Candidate Tests

- Refresh or audit the March 31, 2026 shifted-window cache before using that window as confirmation evidence.
- Compare active-plus-risk behavioral-pool fixed k9 against `pca_kmeans_auto` on a clean shifted end date or adjacent data window.
- Compare auto-k against fixed k9 under a modestly expanded strategy grid after the clean-window check.
- Inspect whether contextual snapshot retains any useful niche despite active-plus-risk behavioral-pool looking stronger.
- Decide whether to codify a smaller default state-map surface for future research runs.

## STOP States

- Do not treat portfolio-accounting metrics as accepted allocation evidence.
- Do not choose a live advice or execution path from these POCs.
- Do not select a final context universe, state map, allocation method, or leverage policy without an explicit operator research gate.
