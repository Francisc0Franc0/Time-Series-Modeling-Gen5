# ADR-003: Advice-Only Live Runner

## Status

Accepted.

## Context

The intended operational workflow is compatible with a normal day job: run the system after close, review clean signals, manually place next-open market orders, and avoid high operational complexity.

## Decision

When the later live-advisor milestone is built, Gen5 live operation will be advice-only. It should produce professional console output and dashboard-style charts, but it should not submit orders.

This ADR does not make the Gen5 v0 market-data layer a live runner. Current v0 work remains limited to adjusted daily Alpaca data ingestion, cache behavior, validation, and audit artifacts.

## Consequences

- Live safety risk is lower.
- Output provenance and clarity matter more than broker automation.
- A future order-routing layer would require a separate decision record and stronger controls.
