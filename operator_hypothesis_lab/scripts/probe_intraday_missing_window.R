options(stringsAsFactors = FALSE)
repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
local_lib <- file.path(repo, ".codex_r_libs")
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))
source(file.path(repo, "R", "data_contract.R"))
source(file.path(repo, "R", "alpaca_provider.R"))
source(file.path(repo, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))

config <- g5_alpaca_config_from_env()
g5_alpaca_require_credentials(config)
cases <- data.frame(
  symbol = c("AMD", "PLD", "CAT"),
  start = as.Date(c("2018-05-02", "2021-04-19", "2022-03-08")),
  end = as.Date(c("2018-05-03", "2021-04-19", "2022-03-08"))
)
rows <- list(); z <- 1L
for (i in seq_len(nrow(cases))) for (feed in c("sip", "iex")) {
  request <- imom30_feed_comparison_request(
    cases$symbol[[i]], cases$start[[i]], cases$end[[i]],
    "2026-08-13 17:30:00 America/New_York", feed
  )
  fetched <- imom30_fetch(request, config)
  rows[[z]] <- data.frame(
    symbol=cases$symbol[[i]], start=cases$start[[i]], end=cases$end[[i]], feed=feed,
    returned_bars=nrow(fetched), first=if(nrow(fetched))min(fetched$timestamp_et)else NA,
    last=if(nrow(fetched))max(fetched$timestamp_et)else NA
  )
  z <- z + 1L
}
result <- do.call(rbind, rows)
run_dir <- file.path(repo, "runs", "research_workbench", "operator_hypothesis_lab",
                     "intraday_momentum_feed_comparison_20260813")
dir.create(run_dir, recursive=TRUE, showWarnings=FALSE)
write.csv(result, file.path(run_dir, "targeted_missing_window_comparison.csv"), row.names=FALSE)
print(result, row.names = FALSE)
