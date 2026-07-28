# Gen5 Literature-Grounded POC Handoff

Status: `WORKFLOW_FROZEN_RESEARCH_SCOPE_CLOSED`

## Purpose

This handoff starts a fresh Gen5 research conversation after the frozen T1,
M1, and S0 mechanism POCs all produced valid STOP results. The new phase will
begin from literature supplied by the operator rather than from another
free-form search across strategy families.

This document freezes the collaboration and evidence workflow. It does not
approve any strategy, dataset, performance calculation, portfolio replay, or
live-facing change.

## Starting authority

- Repository: `Time-Series-Modeling-Gen5`
- Starting branch: `codex/Gen5.4-ml-decision-engine-plan`
- Starting commit: `0b86eda`
- T1 verdict: `STOP_T1_TREND_PERSISTENCE`
- M1 verdict: `STOP_M1_RANKING_MECHANISM`
- S0 verdict: `STOP_S0A_RELATIVE_VALUE_MECHANISM`
- S0B prospective borrow monitoring remains closed.
- No prior POC creates production, allocation, leverage, execution, or
  live-advice authority.

The new conversation should read `AGENTS.md`, this handoff, the relevant
literature, `docs/GEN5_1_POC_PROGRESS_LOG.md`, and
`docs/GEN5_4_DECISION_DIALOGUE_INDEX.md` before proposing implementation.

## Collaboration contract

Codex should continue to act as both educator and technical research partner.
The operator is scientifically literate but is learning quantitative finance.
Explanations should therefore begin from the economic and statistical idea,
define unfamiliar concepts plainly, and still apply professional skepticism.

In particular:

- Push back on claims inherited from technical-analysis culture when the
  economic mechanism, statistical evidence, or implementation assumptions are
  weak.
- Separate a published empirical regularity from a deployable retail strategy.
- Explain why a design choice is being made, not merely how to code it.
- Prefer one recommended design plus at most one or two meaningful
  alternatives.
- Keep no-trade and STOP as legitimate outcomes.
- Recommend an appropriate reasoning level before each substantial theory,
  contract-design, or implementation phase. Default recommendation: Sol high
  for literature synthesis and contract design; Sol medium is normally enough
  for routine implementation after the design is frozen.

## Literature-first workflow

### 1. Inventory before interpretation

For every operator-supplied folder:

- list the documents and record their local paths;
- identify title, author, publication date, document type, and version when
  available;
- distinguish peer-reviewed research, practitioner research, books or
  chapters, vendor material, and informal commentary;
- note inaccessible, corrupted, duplicate, or incomplete files; and
- do not infer authority merely from polished presentation.

### 2. Extract claims with precise provenance

Create a compact source ledger. Each potentially testable idea should cite the
local document plus page, section, figure, or table where practical. Record:

- the claimed economic or behavioral mechanism;
- universe and sample period;
- signal information and when it becomes observable;
- entry, holding period, and exit;
- benchmark or control;
- reported costs and execution assumptions;
- reported robustness tests;
- data that a retail trader would need in research and in real time; and
- caveats, failed variants, and signs of selection or publication bias.

Do not turn a source's conclusion into Gen5 authority. The source is a
hypothesis generator and design input.

### 3. Produce one idea card per distinct mechanism

Each idea card should answer:

1. What mechanism could cause the effect?
2. What exact observable information represents it?
3. When is that information known?
4. What is the smallest estimand that tests the mechanism?
5. What naive benchmark and mechanism-specific control could falsify it?
6. Which costs, spreads, borrow constraints, or market-impact assumptions
   matter?
7. Is equivalent data realistically available to this Alpaca-based retail
   workflow in both history and live operation?
8. What nonstationarity or crowding risk could make the literature result fail
   now?
9. What result would force a STOP?

### 4. Triage before choosing a POC

Rank candidate ideas on:

- clarity of economic mechanism;
- point-in-time data integrity;
- retail data and execution feasibility;
- number of independent observations;
- ability to construct a strong control;
- sensitivity to costs, borrow, latency, and capacity;
- freedom from outcome-driven parameter choice; and
- informational difference from already stopped Gen5 mechanisms.

Do not rank candidates by the most attractive published return alone.

The first discussion should recommend one default candidate and no more than
two serious alternatives. The operator retains authority to choose which
research gate to open.

### 5. Freeze one minimal contract before implementation

The selected POC contract must predeclare:

- question and claim boundary;
- universe and survivor-bias disclosure;
- source data and point-in-time rules;
- explicit `as_of_timestamp`;
- TRAIN, development, confirmation, or prospective boundaries as applicable;
- signal, decision, and earliest execution timestamps;
- primary estimand and fixed diagnostics;
- baselines and mechanism-specific falsification controls;
- transaction costs and other implementation frictions;
- support, breadth, stability, and concentration gates;
- treatment of missing data and unavailable historical fields;
- representative human-facing visualizations;
- exact PASS and STOP language; and
- prohibited rescue paths after inspection.

No retrieval joined to future outcomes, model fitting, parameter search,
performance calculation, portfolio replay, or live behavior should begin
until the operator explicitly approves the exact contract.

### 6. Implement and report autonomously after approval

Once the exact POC is approved, Codex may autonomously:

- implement conservative helpers, tests, and a quiet wrapper;
- refresh in-scope Alpaca cache coverage when required;
- run the frozen analysis;
- inspect the manifest, health, summaries, report, and selected visuals;
- fix implementation defects without changing the research contract;
- produce a concise evidence deck;
- update the progress log, contract, atlas or phase memo, and decision index;
- run focused checks and `scripts/test/run_tests.ps1`;
- review `git status`, stage only scoped files, commit, and push the named
  `codex/` branch; and
- report the verdict, artifacts, validation, commit, branch, and remaining
  operator gate.

Codex must stop for operator authority if evidence raises a material data,
methodology, risk, or product decision rather than a routine implementation
issue.

## Human-facing evidence convention

Every implemented POC should produce a small, readable evidence surface:

- one verdict or gate-summary visual;
- one chart showing the primary estimand across independent periods;
- one mechanism-specific control comparison;
- one support, breadth, stability, or concentration diagnostic;
- representative event, trade, ranking, or relationship tapes when timing or
  behavior matters; and
- no equity curve unless portfolio replay was explicitly authorized.

The evidence deck should:

- remain concise;
- use transition slides when it covers literature, contract, and evidence;
- state what was tested, why it was credible or not, and what remains closed;
- include speaker-note citations to source literature and generated artifacts;
- reference the relevant dialogue decision IDs; and
- pass render, overflow, and template-fidelity inspection before delivery.

## Dialogue bookmarking convention

Continue the decision ledger from `D56`.

For every material discussion decision:

- record the question, decision, reason, and boundary in
  `docs/GEN5_4_DECISION_DIALOGUE_INDEX.md`;
- preserve a short recognizable phrase from the operator's prompt in the
  dialogue-cue column;
- cite the decision ID in the related slide's speaker notes;
- cite source documents separately from chat decisions; and
- keep the slide concise, using the decision index to recover the longer
  reasoning later.

The current transition is:

- `D56`: replace free-form mechanism search with a literature-grounded
  hypothesis-extraction and minimal-POC workflow while preserving the existing
  evidence, documentation, deck, bookmarking, validation, commit, and push
  conventions.

## First task in the new conversation

The operator will provide one or more local literature folders. The first task
is read-only research design:

1. inventory the literature;
2. build the source ledger;
3. explain the strongest concrete mechanisms in beginner-accessible but
   professionally critical language;
4. propose a ranked shortlist of minimal POCs;
5. identify data and deployment feasibility through the existing retail
   workflow; and
6. stop for discussion before freezing or implementing a POC.

No implementation is authorized by this handoff.
