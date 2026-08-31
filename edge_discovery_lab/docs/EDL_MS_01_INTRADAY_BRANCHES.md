# EDL-MS-01 — Bookmarked Intraday Branches

The daily Rule 201 Reclaim discovery work has exposed two different intraday
questions. They must remain separate because their information clocks are not
the same.

## Branch A — Completed-Event Intraday Entry Timing

The daily event is allowed to finish first. The operator knows at the event-day
close that the adjusted daily low crossed the -10% proxy and knows the final
close-location value.

The later question is whether entry during the following session has better
geometry than an unconditional next-open entry. A future 30-minute slice could
inspect:

- the following session's opening gap;
- early-session continuation or stabilization;
- candidate entries after one or more completed 30-minute bars; and
- the remaining same-day and multi-session path after each candidate clock.

This is an entry-timing study conditional on a completed daily event. It must
not use information from later bars on the entry day.

## Branch B — Live Breach/Reclaim Signal

The -10% threshold is crossed during the event day. A causal reclaim condition
is then defined only from completed intraday bars, such as recovery magnitude,
time since breach, or persistence above a predeclared recovery level.

This is a new signal hypothesis. It cannot use the final daily close-location
value because that value is unknown before the event day closes.

## Shared Requirements Before Execution

- A separately approved 30-minute data slice.
- Explicit regular-hours and session-boundary handling.
- A fixed definition of threshold time, observation bar, entry bar, and exit.
- No use of final daily high, low, close, or close-location value before known.
- Separate treatment of halts, missing bars, spreads, and other execution
  frictions before any performance claim.
- Daily-low threshold remains a proxy unless official listing-market Rule 201
  activation status is joined.

## Status

Both branches are bookmarked only. Neither has been executed or promoted.
