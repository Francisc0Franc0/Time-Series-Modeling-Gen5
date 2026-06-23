# ADR-003: Advice-Only Live Runner

## Status

Accepted.

## Context

The intended operational workflow is compatible with a normal day job: run the system after close, review clean signals, manually place next-open market orders, and avoid high operational complexity.

## Decision

Gen5 live operation is advice-only. It should produce professional console output and dashboard-style charts, but it should not submit orders.

## Consequences

- Live safety risk is lower.
- Output provenance and clarity matter more than broker automation.
- A future order-routing layer would require a separate decision record and stronger controls.
