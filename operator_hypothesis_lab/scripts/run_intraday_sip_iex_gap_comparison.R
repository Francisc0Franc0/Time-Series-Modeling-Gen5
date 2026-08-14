options(stringsAsFactors = FALSE)
repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
local_lib <- file.path(repo, ".codex_r_libs")
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))
source(file.path(repo, "R", "data_contract.R"))
source(file.path(repo, "R", "alpaca_provider.R"))
source(file.path(repo, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))

as_of <- "2026-08-13 17:30:00 America/New_York"
registry <- read.csv(file.path(repo, "operator_hypothesis_lab", "registries",
                              "gen5_intraday_momentum_poc_registry.csv"))
sip_paths <- file.path(repo, "data_cache", "alpaca_intraday_30min",
                       sprintf("intraday_30min_sip_all_%d.rds", 2017:2023))
if (!all(file.exists(sip_paths))) stop("Frozen SIP cache is incomplete.")
sip <- do.call(rbind, lapply(sip_paths, readRDS))
sip$session_date <- as.Date(sip$session_date)
sip <- sip[sip$session_date >= as.Date("2018-01-02") &
             sip$session_date <= as.Date("2023-12-29"), , drop=FALSE]
spy_sessions <- sort(unique(sip$session_date[sip$symbol == "SPY"]))

diagnostic_dir <- file.path(repo, "runs", "research_workbench", "operator_hypothesis_lab",
                            "intraday_momentum_data_admission_20260813")
missing <- read.csv(file.path(diagnostic_dir, "intraday_calendar_mismatch_detail.csv"))
gap_dates <- sort(unique(as.Date(missing$session_date)))
previous_session <- vapply(gap_dates, function(date) {
  prior <- spy_sessions[spy_sessions < date]
  as.character(tail(prior, 1L))
}, character(1))
comparison_dates <- sort(unique(c(gap_dates, as.Date(previous_session))))

config <- g5_alpaca_config_from_env()
g5_alpaca_require_credentials(config)
cache_dir <- file.path(repo, "data_cache", "alpaca_intraday_30min_iex_diagnostic")
dir.create(cache_dir, recursive=TRUE, showWarnings=FALSE)
iex_chunks <- lapply(comparison_dates, function(date) {
  path <- file.path(cache_dir, sprintf("iex_%s.rds", date))
  if (file.exists(path)) return(readRDS(path))
  request <- imom30_feed_comparison_request(registry$symbol, date, date, as_of, "iex")
  out <- imom30_fetch(request, config)
  saveRDS(out, path)
  message(date, ": IEX rows=", nrow(out), " symbols=", length(unique(out$symbol)))
  out
})
iex <- do.call(rbind, iex_chunks)
iex$session_date <- as.Date(iex$session_date)

key <- function(x) paste(x$symbol, format(x$timestamp_utc, tz="UTC", usetz=TRUE))
sip$key <- key(sip); iex$key <- key(iex)
matched <- merge(
  sip[, c("key","symbol","session_date","bar_time_et","open","high","low","close","volume")],
  iex[, c("key","open","high","low","close","volume")], by="key", suffixes=c("_sip","_iex")
)
matched$close_abs_difference_bps <- abs(matched$close_iex/matched$close_sip-1)*10000

session_rows <- lapply(comparison_dates, function(date) {
  sip_date <- sip[sip$session_date == date, , drop=FALSE]
  iex_date <- iex[iex$session_date == date, , drop=FALSE]
  ref_count <- sum(sip_date$symbol == "SPY")
  sip_count <- table(factor(sip_date$symbol, levels=registry$symbol))
  iex_count <- table(factor(iex_date$symbol, levels=registry$symbol))
  gap_keys <- unlist(lapply(registry$symbol, function(symbol) {
    ref <- sip_date$key[sip_date$symbol == "SPY"]
    sub(paste0("^SPY "), paste0(symbol, " "),
        ref[!sub(paste0("^SPY "), paste0(symbol, " "), ref) %in%
              sip_date$key[sip_date$symbol == symbol]])
  }), use.names=FALSE)
  day_matched <- matched[matched$session_date == date, , drop=FALSE]
  data.frame(
    session_date=date,
    role=if(date %in% gap_dates)"SIP_GAP"else"ADJACENT_CONTROL",
    spy_reference_bars=ref_count,
    sip_complete_symbols=sum(sip_count == ref_count),
    iex_complete_symbols=sum(iex_count == ref_count),
    sip_total_bars=sum(sip_count),
    iex_total_bars=sum(iex_count),
    iex_fills_sip_gap=sum(gap_keys %in% iex_date$key),
    matched_bars=nrow(day_matched),
    median_close_abs_difference_bps=if(nrow(day_matched))median(day_matched$close_abs_difference_bps)else NA_real_,
    maximum_close_abs_difference_bps=if(nrow(day_matched))max(day_matched$close_abs_difference_bps)else NA_real_
  )
})
session_summary <- do.call(rbind, session_rows)

symbol_rows <- lapply(registry$symbol, function(symbol) {
  s <- sip[sip$symbol == symbol & sip$session_date %in% comparison_dates, , drop=FALSE]
  i <- iex[iex$symbol == symbol & iex$session_date %in% comparison_dates, , drop=FALSE]
  m <- matched[matched$symbol == symbol & matched$session_date %in% comparison_dates, , drop=FALSE]
  data.frame(symbol=symbol,sip_bars=nrow(s),iex_bars=nrow(i),matched_bars=nrow(m),
             iex_fraction_of_sip=if(nrow(s))nrow(i)/nrow(s)else NA_real_,
             median_close_abs_difference_bps=if(nrow(m))median(m$close_abs_difference_bps)else NA_real_)
})
symbol_summary <- do.call(rbind, symbol_rows)

run_dir <- file.path(repo, "runs", "research_workbench", "operator_hypothesis_lab",
                     "intraday_momentum_feed_comparison_20260813")
dir.create(run_dir, recursive=TRUE, showWarnings=FALSE)
write.csv(session_summary, file.path(run_dir, "sip_iex_session_comparison.csv"), row.names=FALSE)
write.csv(symbol_summary, file.path(run_dir, "sip_iex_symbol_comparison.csv"), row.names=FALSE)
write.csv(matched, file.path(run_dir, "sip_iex_matched_bar_differences.csv"), row.names=FALSE)
writeLines(c(
  "FEED_COMPARISON_COMPLETE",
  paste("gap_sessions", length(gap_dates)),
  paste("iex_filled_sip_gap_bars", sum(session_summary$iex_fills_sip_gap)),
  paste("iex_bars_on_gap_sessions", sum(session_summary$iex_total_bars[session_summary$role=="SIP_GAP"]))
), file.path(run_dir, "STATUS.txt"))
print(session_summary, row.names=FALSE)
cat("\nSymbol summary:\n")
print(symbol_summary, row.names=FALSE)
