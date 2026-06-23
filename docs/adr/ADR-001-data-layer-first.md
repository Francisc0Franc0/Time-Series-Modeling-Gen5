# ADR-001: Build Data Layer First

## Status

Accepted.

## Context

Gen4 accumulated substantial complexity around date resolution, fetching, artifacts, diagnostics, and downstream assumptions. Several later-phase problems are easier to prevent than repair if the market-data contract is made explicit first.

## Decision

Gen5 begins with a market-data layer only. WFA, PCA, strategies, exits, allocation, and dashboards are deferred until the adjusted daily bar contract, cache behavior, and data audits are stable.

## Consequences

- Early progress will look intentionally boring.
- The first runnable milestone should validate bars and audits, not returns.
- Downstream modules will depend on one canonical definition of daily adjusted bars.
