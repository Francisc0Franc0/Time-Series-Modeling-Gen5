# Alternative Data Lab

This lab holds narrow, operator-guided exercises that establish whether a
non-market dataset can be collected, timestamped, mapped, audited, and
visualized before any predictive or trading question is opened.

The first slice is `ADL-WIKI-01.1`: daily user-classified page views for the
English Wikipedia article `GameStop` from 2019-01-01 through 2023-12-31.
GameStop's 2021 public-attention episode is used only as a positive-control
sanity check for the collection pipeline.

The second slice is `ADL-WIKI-02.1`: a deliberately minimal directional-lead
test. It compares a completed same-session reaction control with the only
causal surface in the slice: a 28-calendar-day trailing attention surprise,
made available only after the UTC day ends plus a fixed 48-hour safeguard,
against exactly one following GME open-to-open return. It opens no threshold,
horizon search, trade rule, costs, or performance claim.

Current authority:

- preserve the exact Wikimedia response and complete daily calendar;
- preserve a causal availability clock when market data are joined;
- produce auditable data-health, construction, and descriptive visual outputs;
- keep `ADL-WIKI-02.1` at
  `STOP_NO_OBVIOUS_ONE_SESSION_DIRECTIONAL_LEAD`;
- make no threshold, strategy, performance, or edge claim.
