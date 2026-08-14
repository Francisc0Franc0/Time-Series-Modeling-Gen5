options(stringsAsFactors = FALSE)

repo <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
local_lib <- file.path(repo, ".codex_r_libs")
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))
source(file.path(repo, "R", "data_contract.R"))
source(file.path(repo, "R", "alpaca_provider.R"))
source(file.path(repo, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))

as_of <- "2026-08-13 17:30:00 America/New_York"
query_start <- as.Date("2017-09-01")
development_start <- as.Date("2018-01-02")
development_end <- as.Date("2023-12-29")
confirmation_start <- as.Date("2024-01-02")
registry_path <- file.path(repo, "operator_hypothesis_lab", "registries", "gen5_intraday_momentum_poc_registry.csv")
registry <- read.csv(registry_path, check.names = FALSE)
cache_dir <- file.path(repo, "data_cache", "alpaca_intraday_30min")
run_dir <- file.path(repo, "runs", "research_workbench", "operator_hypothesis_lab", "intraday_momentum_data_admission_20260813")
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)

config <- g5_alpaca_config_from_env()
g5_alpaca_require_credentials(config)
if (!identical(config$feed, "sip")) config$feed <- "sip"

all_years <- 2017:2023
year_filter <- trimws(Sys.getenv("GEN5_INTRADAY_YEAR", ""))
years <- if (nzchar(year_filter)) as.integer(strsplit(year_filter, ",", fixed=TRUE)[[1L]]) else all_years
if (any(is.na(years)) || any(!years %in% all_years)) stop("GEN5_INTRADAY_YEAR must be a comma-separated subset of 2017:2023.")
chunks <- list(); health <- list()
for (year in years) {
  start <- max(query_start, as.Date(sprintf("%d-01-01", year)))
  end <- min(development_end, as.Date(sprintf("%d-12-31", year)))
  path <- file.path(cache_dir, sprintf("intraday_30min_sip_all_%d.rds", year))
  refresh <- identical(tolower(Sys.getenv("GEN5_INTRADAY_REFRESH", "false")), "true")
  status <- "CACHE_HIT"
  if (!file.exists(path) || refresh) {
    message("Fetching Alpaca SIP 30Min ", year, " ...")
    symbol_groups <- split(registry$symbol, ceiling(seq_along(registry$symbol) / 4L))
    group_bars <- vector("list", length(symbol_groups))
    for (group_i in seq_along(symbol_groups)) {
      group_path <- file.path(cache_dir, sprintf("intraday_30min_sip_all_%d_group_%02d.rds", year, group_i))
      if (file.exists(group_path) && !refresh) {
        group_bars[[group_i]] <- readRDS(group_path)
        group_status <- "CACHE_HIT"
      } else {
        request <- imom30_request(symbol_groups[[group_i]], start, end, as_of)
        group_bars[[group_i]] <- imom30_fetch(request, config)
        saveRDS(group_bars[[group_i]], group_path)
        group_status <- "FETCHED"
      }
      message("  group ", group_i, "/", length(symbol_groups), " ", group_status,
              " rows=", nrow(group_bars[[group_i]]))
    }
    bars <- do.call(rbind, group_bars)
    attr(bars, "page_count") <- sum(vapply(group_bars, function(x) {
      value <- attr(x, "page_count")
      if (is.null(value)) 0L else as.integer(value)
    }, integer(1)))
    saveRDS(bars, path)
    status <- "FETCHED"
  } else {
    bars <- readRDS(path)
  }
  chunks[[as.character(year)]] <- bars
  health[[as.character(year)]] <- data.frame(
    year=year, status=status, row_count=nrow(bars), symbol_count=length(unique(bars$symbol)),
    first_timestamp=if(nrow(bars)) min(bars$timestamp_et) else NA_character_,
    last_timestamp=if(nrow(bars)) max(bars$timestamp_et) else NA_character_,
    page_count=if(is.null(attr(bars,"page_count"))) NA_integer_ else attr(bars,"page_count"),
    stringsAsFactors=FALSE
  )
  message(year, ": ", status, " rows=", nrow(bars), " symbols=", length(unique(bars$symbol)))
}

if (nzchar(year_filter)) {
  message("CACHE_YEAR_COMPLETE: ", paste(years, collapse=","))
  quit(status=0L)
}

bars <- do.call(rbind, chunks)
bars <- bars[!duplicated(bars[c("symbol","timestamp_utc")]), , drop=FALSE]
bars <- bars[order(bars$symbol,bars$timestamp_utc), , drop=FALSE]
bars <- imom30_apply_rth_calendar(bars)
bars <- imom30_apply_archive_exclusions(bars)
if (any(bars$session_date >= confirmation_start)) stop("Confirmation data entered admission packet.")
audit <- imom30_audit(bars, registry, development_start, development_end, 520L)

write.csv(do.call(rbind, health), file.path(run_dir, "intraday_data_query_health.csv"), row.names=FALSE)
write.csv(audit$coverage, file.path(run_dir, "intraday_data_coverage.csv"), row.names=FALSE)
write.csv(audit$sessions, file.path(run_dir, "intraday_session_audit.csv"), row.names=FALSE)
write.csv(audit$integrity, file.path(run_dir, "intraday_data_integrity.csv"), row.names=FALSE)
write.csv(registry, file.path(run_dir, "intraday_registry.csv"), row.names=FALSE)
write.csv(data.frame(
  field=c("as_of_timestamp","query_start","development_start","development_end","confirmation_start","provider","feed","timeframe","adjustment","bar_scope"),
  value=c(as_of,as.character(query_start),as.character(development_start),as.character(development_end),as.character(confirmation_start),"alpaca","sip","30Min","all","regular_session_only")
), file.path(run_dir, "intraday_data_run_spec.csv"), row.names=FALSE)

status <- if (all(audit$integrity$passed) && sum(audit$coverage$analysis_eligible & audit$coverage$asset_type=="stock") >= 20L &&
  all(audit$coverage$analysis_eligible[audit$coverage$symbol %in% c("AMD","TSLA","SPY")])) "PASS_INTRADAY_DATA_ADMISSION" else "STOP_INTRADAY_DATA_ADMISSION"
writeLines(c(status, paste("eligible",sum(audit$coverage$analysis_eligible),"of",nrow(audit$coverage))), file.path(run_dir,"STATUS.txt"))
message(status)
print(audit$coverage[,c("symbol","prehistory_bars","development_bars","coverage_status")],row.names=FALSE)
if (!identical(status,"PASS_INTRADAY_DATA_ADMISSION")) quit(status=2L)
