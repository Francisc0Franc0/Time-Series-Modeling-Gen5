# ADR-004: R-First With Provider Boundary

## Status

Accepted.

## Context

The existing research logic and statistical workflow are R-native. Rewriting everything in Python would add migration risk before Gen5 contracts are stable. At the same time, provider-specific quirks should not leak into research modules.

## Decision

Gen5 is R-first. Alpaca is the only v0 provider, but it must live behind a provider-shaped boundary.

## Consequences

- Research and WFA code stay close to the user's existing statistical workflow.
- Python can later consume shared artifacts if useful.
- Alpaca-specific behavior remains isolated.
