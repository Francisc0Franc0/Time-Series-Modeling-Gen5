# Gen5.4 Event-Conditioned Continuation E0 Construction Contract

Status: frozen and authorized for implementation on 2026-07-26.

## Purpose

E0 asks whether the accepted Alpaca news archive can produce a deterministic,
point-in-time issuer information-cycle tape suitable for a later discussion of
event-conditioned continuation.

E0 does not ask whether news predicts direction, whether the initial market
reaction continues, or whether any information cycle should produce a trade.
It contains no price, volume, outcome, sentiment, model, policy, exposure,
allocation, cost, PnL, or live-advice calculation.

## Why “information cycle,” not “event”

The observable unit is:

`issuer × scheduled 17:30 America/New_York decision`

All admissible novel article clusters known for that issuer by that decision
belong to one information cycle. This is operationally reproducible. It does
not claim that every article in the cycle describes one semantic real-world
event.

A future representation layer may distinguish semantic events only after a
separate point-in-time theory and validation contract. E0 may not infer that
identity from hindsight.

## Input authority

- Provider: Alpaca historical news.
- Window: `2025-01-01` through `2026-06-30`.
- Ranked issuer panel: the frozen 24-stock Gen5.4 registry.
- Historical availability timestamp: provider `updated_at`.
- Prospective availability authority remains local receipt time under the
  accepted N1L contract.
- FB is valid through `2022-06-08`; META begins `2022-06-09`. Only META is
  relevant inside E0, but the point-in-time issuer registry remains unchanged.
- Source pages and calendar come from the accepted N1D packet and are rebuilt
  without a network refresh.

N1D stopped its recency representation, not its data integrity. E0 may reuse
the preserved pages only if every N1D integrity check remains `PASS`.

## Admissibility

An article association enters E0 only when:

1. its issuer symbol is valid on the assigned decision date;
2. its final update is no more than 24 hours after creation;
3. it is not a backward-looking exact normalized-title repeat within 72 hours;
4. its `updated_at` maps to the same or next scheduled 17:30 decision without
   using future metadata; and
5. a following market session exists for the execution timestamp.

Articles may be associated with multiple issuers. Each issuer association is a
separate observable information arrival, while the original article ID remains
preserved.

## Cycle schema

Each information cycle records:

- deterministic cycle ID;
- issuer and economic group;
- decision and following execution sessions;
- first and last admitted availability timestamps;
- novel cluster and unique article counts;
- source count and a compact source sample;
- youngest and oldest article age at decision;
- revision-crossed-cycle count;
- multi-symbol article count; and
- compact representative headline metadata for human audit.

The full article-level tape remains available separately.

## Frozen construction gates

All gates must pass:

1. Every accepted N1D integrity check remains `PASS`.
2. Every preserved Alpaca page is HTTP 200 and both page chains terminate.
3. Rebuilding from raw pages exactly reproduces the admitted N1D
   article/issuer/session/cluster association set.
4. No admitted availability timestamp is after its decision cutoff.
5. Every execution session is after its decision session.
6. No update delayed more than 24 hours is admitted.
7. No backward-looking exact-title repeat is admitted.
8. Cycle IDs are unique.
9. Every retained cycle contains at least one novel cluster.
10. All 24 issuers have at least one cycle in all six quarters from `2025Q1`
    through `2026Q2`.
11. Every issuer-quarter contains at least five information cycles.
12. The packet contains no price, outcome, sentiment, predictive, portfolio,
    PnL, or live-authority surface.

If every gate passes, record:

`PASS_E0_INFORMATION_CYCLES_READY_FOR_FEATURE_THEORY`

Otherwise record:

`STOP_E0_EVENT_CONSTRUCTION`

## Boundary after a pass

An E0 pass proves only that timestamped information cycles are reproducible and
operationally supported. It does not authorize:

- a directional news label;
- headline sentiment;
- semantic event embeddings;
- price-reaction features;
- volume-confirmation features;
- future-return joins;
- an event-conditioned ranker;
- portfolio replay; or
- live advice.

The next gate after an E0 pass is a theory session that freezes one minimal
initial-reaction measurement and determines how genuinely prospective
confirmation will be accumulated.
