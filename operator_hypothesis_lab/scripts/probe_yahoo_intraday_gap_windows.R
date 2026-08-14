options(stringsAsFactors = FALSE)
repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
local_lib <- file.path(repo, ".codex_r_libs")
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))
if (!requireNamespace("httr", quietly=TRUE) || !requireNamespace("jsonlite", quietly=TRUE)) {
  stop("Existing httr and jsonlite packages are required.")
}

cases <- data.frame(
  symbol=c("AMD","TSLA","PLD","CAT"),
  start=as.Date(c("2018-05-02","2018-05-02","2021-04-19","2022-03-08")),
  end=as.Date(c("2018-05-03","2018-05-03","2021-04-19","2022-03-08"))
)

rows <- lapply(seq_len(nrow(cases)), function(i) {
  start <- as.numeric(as.POSIXct(cases$start[[i]], tz="America/New_York"))
  end <- as.numeric(as.POSIXct(cases$end[[i]] + 1, tz="America/New_York"))
  url <- sprintf("https://query1.finance.yahoo.com/v8/finance/chart/%s", cases$symbol[[i]])
  response <- httr::GET(url, query=list(
    period1=format(start, scientific=FALSE), period2=format(end, scientific=FALSE),
    interval="30m", includePrePost="false", events="div,splits"
  ), httr::user_agent("Gen5 research data-gap diagnostic"))
  body <- httr::content(response, as="text", encoding="UTF-8")
  parsed <- tryCatch(jsonlite::fromJSON(body, simplifyVector=FALSE), error=function(e)NULL)
  error_description <- if (!is.null(parsed$chart$error$description)) {
    as.character(parsed$chart$error$description)
  } else NA_character_
  timestamps <- if (!is.null(parsed$chart$result[[1L]]$timestamp)) {
    unlist(parsed$chart$result[[1L]]$timestamp)
  } else numeric()
  data.frame(
    symbol=cases$symbol[[i]],start=cases$start[[i]],end=cases$end[[i]],
    http_status=httr::status_code(response),returned_bars=length(timestamps),
    error_description=error_description,stringsAsFactors=FALSE
  )
})
result <- do.call(rbind, rows)
run_dir <- file.path(repo,"runs","research_workbench","operator_hypothesis_lab",
                     "intraday_momentum_feed_comparison_20260813")
dir.create(run_dir,recursive=TRUE,showWarnings=FALSE)
write.csv(result,file.path(run_dir,"yahoo_30min_gap_probe.csv"),row.names=FALSE)
writeLines(c(
  "YAHOO_30MIN_GAP_PROBE_COMPLETE",
  paste("returned_gap_bars",sum(result$returned_bars)),
  paste("all_requests_failed_to_supply_bars",all(result$returned_bars==0))
),file.path(run_dir,"YAHOO_STATUS.txt"))
print(result,row.names=FALSE)
