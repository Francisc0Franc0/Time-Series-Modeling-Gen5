# HYP-ALT-01.1 WSB Forward Collection Contract

Status: `FROZEN_IMPLEMENTED_LIVE_ACCESS_PENDING`

Evidence stage: `FORWARD_COLLECTION_POC`

## Question

Can an approved, OAuth-authenticated Reddit collector produce a healthy daily
tape of US equity and ETF mentions in `r/wallstreetbets` without pretending
that a recent listing is a complete historical archive?

## Scope

- Collect comments from the official `oauth.reddit.com` subreddit comment
  listing only after Reddit explicitly approves the use case.
- Do not scrape Reddit HTML or circumvent listing, authentication, or rate
  limits.
- Use one registered OAuth client and a descriptive user agent.
- Poll every two minutes by default. Page backward until a previously observed
  comment establishes overlap, the listing ends, or the ten-page safety cap is
  reached.
- Treat the first page as a bootstrap sample with no completeness authority.
- Use New York calendar dates for the first human-readable daily tape.
- Do not join prices, calculate returns, infer sentiment, or define a trading
  rule in this lane.

## Ticker authority

The recognition universe is the active `us_equity` asset registry returned by
Alpaca's official assets endpoint. The registry includes equities and ETFs and
is timestamped when generated. It is a current forward-recognition authority,
not a point-in-time historical-membership source.

Ticker extraction has two visible channels:

1. a validated cashtag such as `$TSLA`; and
2. an exact uppercase bare token such as `TSLA`, admitted only if it is in the
   registry and not in the frozen ambiguity denylist.

The denylist requires cashtag syntax for highly ambiguous symbols such as
`AI`, `ALL`, `DD`, `IT`, `NA`, and `US`. Company-name inference, fuzzy matching,
crypto, futures, and option-contract parsing are outside `01.1`.

## Durable data boundary

Raw comment bodies are processed in memory and never written to disk. Usernames,
profile data, flair, and user-level behavioral identifiers are not collected.
The durable ignored cache contains only:

- comment ID and publication timestamp;
- first collection and last verification timestamps;
- ticker, detection channel, and occurrence count;
- collection-run coverage diagnostics; and
- daily ticker aggregates.

Deletion reconciliation revisits stored comment IDs in batches of at most 100.
If Reddit no longer returns an active comment body, the collector removes both
the observation and every ticker contribution derived from it, then rebuilds
the daily aggregate. The reconciliation ledger retains only batch-level counts,
not deleted IDs or content.

## Daily attention fields

The primary quantity is `comments_mentioning`: distinct comments that mention a
ticker. `total_occurrences` is secondary so repetition inside one comment does
not masquerade as independent attention. The tape also reports cashtag-comment
count, bare-symbol-comment count, all observed WSB comments, mention share, and
within-day attention rank.

## Coverage states

- `BOOTSTRAP_NO_COVERAGE_AUTHORITY`: first sample; useful for plumbing only.
- `PASS_FORWARD_OVERLAP`: the collector reached a known comment within the
  page cap and the prior poll gap was at most five minutes.
- `WARN_LATE_POLL_OVERLAP_RECOVERED`: overlap was found, but the scheduler ran
  late.
- `WARN_PAGE_CAP_WITHOUT_OVERLAP`: the collector exhausted its page budget
  before proving continuity; the interval may contain missing comments.
- `WARN_NO_OVERLAP`: continuity was not established for another reason.

No daily mention statistic may be treated as complete unless its associated
coverage surface is acceptable. A later predictive lane must use only comments
available by a separately frozen decision cutoff.

## Current gate

Reddit's current Responsible Builder Policy requires explicit approval before
API access. Live collection therefore remains blocked until the operator has
approved credentials and truthfully sets:

- `GEN5_REDDIT_ACCESS_APPROVED=true`;
- `GEN5_REDDIT_CLIENT_ID`;
- `GEN5_REDDIT_CLIENT_SECRET`; and
- `GEN5_REDDIT_USER_AGENT`, including the associated `/u/` account.

The relevant official policies are the
[Responsible Builder Policy](https://support.reddithelp.com/hc/en-us/articles/42728983564564-Responsible-Builder-Policy),
[Data API Wiki](https://support.reddithelp.com/hc/en-us/articles/16160319875092-Reddit-Data-API-Wiki),
and [Data API Terms](https://redditinc.com/policies/data-api-terms).
