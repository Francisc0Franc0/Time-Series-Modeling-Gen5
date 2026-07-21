# Gen5.4 News Live Feasibility N1L Contract

Status: completed; `PARTIAL_PASS_N1L_TRANSPORT_READY_NO_LIVE_ARTICLE`

Decision date: 2026-07-21

Branch: `codex/Gen5.4-ml-decision-engine-plan`

## Question

Can the existing Alpaca account receive real-time news, preserve local receipt
timestamps, reconnect cleanly, and reconcile a REST overlap window before any
news measurement is joined to a market outcome?

N1L is an operational capability check. It is not a feature, signal, model,
backtest, or live-advice implementation.

## Provider And Transport

- provider: Alpaca Market Data API;
- stream: `wss://stream.data.alpaca.markets/v1beta1/news`;
- authentication: existing Alpaca key ID and secret in request headers;
- subscription: the fixed 24-stock N1A universe plus the historical `FB`
  alias, not an unbounded production universe;
- reconciliation: Alpaca REST `/v1beta1/news` over an explicit overlap window;
- approved local R dependencies: `websocket` and `later` in the ignored
  repository-local library.

## Frozen Trial Shape

1. Require an explicit run ID and `as_of_timestamp` in the run record.
2. Open a first bounded WebSocket connection, authenticate, subscribe, and
   capture messages for 30 seconds by default.
3. Close the first connection deliberately.
4. Open a second bounded connection with the same subscription and capture for
   another 30 seconds by default.
5. Record a local UTC `received_at` timestamp and connection ID for every raw
   frame before parsing it.
6. Query an explicit REST window beginning 15 minutes before the first
   connection and ending at the reconciliation timestamp.
7. Reconcile stream and REST rows by article ID while retaining differences in
   provider timestamps and symbol associations.

The duration may be changed only through an explicit environment value between
5 and 300 seconds per connection. Duration changes test transport observation,
not research outcomes.

## Raw And Normalized Evidence

The ignored packet must preserve:

- raw WebSocket frames in receipt order;
- connection lifecycle events with local timestamps;
- authentication and subscription acknowledgements;
- parsed news frames with article ID, provider timestamps, symbols, source,
  headline, connection ID, and local `received_at`;
- the raw REST reconciliation pages and page manifest;
- a deterministic stream-versus-REST reconciliation table;
- severity-labeled health and gate tables;
- a compact report and purposeful human-facing visuals.

Credentials and authentication payloads must never be written to artifacts,
logs, reports, tests, or slides.

## Frozen Gates

Hard PASS requires:

- both bounded connections open successfully;
- Alpaca authenticates both connections;
- Alpaca acknowledges the requested subscription on both connections;
- the deliberate close and second connection demonstrate reconnectability;
- every captured frame receives a nonmissing local UTC receipt timestamp and
  connection ID;
- every captured news frame has an article ID, headline, `created_at`, and
  `updated_at`;
- REST reconciliation returns HTTP 200 and exhausts pagination;
- reconciliation is deterministic and article IDs do not produce conflicting
  normalized rows without an explicit update distinction.

If the connection, authentication, subscription, reconnect, or REST gates fail,
the result is `STOP_N1L_LIVE_PATH_FAILURE`.

If every hard transport and reconciliation gate passes but no live article is
observed during the bounded windows, record
`PARTIAL_PASS_N1L_TRANSPORT_READY_NO_LIVE_ARTICLE`. This is not silently
promoted to full prospective-equivalence evidence.

When at least one valid live news article is observed and all hard gates pass,
record `PASS_N1L_LIVE_PATH_READY`.

## Explicit Boundaries

N1L computes no news intensity, sentiment, embedding, event category, return,
volatility, drawdown, PnL, allocation, or exposure recommendation. It does not
join OHLCV and does not alter advice-only or execution behavior.

Passing N1L only removes the operational data-path STOP in the frozen N1B
contract. It does not establish that news contains predictive information.

## N1L Readout

The authority run used two 120-second connections and a corrected explicit
15-minute REST overlap. All 13 frozen hard gates passed:

- both connections opened, authenticated, and received subscription
  acknowledgements for all 25 requested point-in-time symbol keys;
- the first connection closed cleanly and the second connection opened;
- all six received control frames had complete local UTC receipt metadata and
  parsed without error;
- the REST overlap exhausted one HTTP 200 page;
- reconciliation contained no same-version conflicts;
- credentials, sentiment, features, outcomes, OHLCV joins, and model fits were
  absent from the packet.

No live candidate article arrived during the combined four-minute observation.
The corrected REST window contained one candidate article whose provider update
preceded the first subscription, so it was correctly classified as REST-only.

The result is therefore the predeclared partial pass rather than full live
payload equivalence. N1B outcome testing remains blocked unless a later shadow
observation captures at least one valid live candidate article or the operator
explicitly accepts this limitation.
