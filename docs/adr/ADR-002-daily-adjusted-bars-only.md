# ADR-002: Daily Adjusted Bars Only For Gen5 v0

## Status

Accepted.

## Context

The operational target is evening review after market close and next-open manual orders. Intraday support added complexity in Gen4 and is not needed for the first Gen5 objective.

## Decision

Gen5 v0 uses adjusted daily OHLCV bars only. Raw/unadjusted bars and intraday bars are out of scope for the initial build.

## Consequences

- The data contract is simpler and easier to test.
- Historical corporate-action adjustment is treated as canonical for research.
- Intraday expansion remains a possible future Gen6 or later Gen5 extension, not a v0 requirement.
