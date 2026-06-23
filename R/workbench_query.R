# Gen5 v0.1 research data workbench query helpers.

g5_parse_bool_env <- function(value, default = FALSE) {
  if (!nzchar(value)) {
    return(isTRUE(default))
  }
  tolower(trimws(value)) %in% c("1", "true", "yes", "y")
}

g5_filter_query_bars <- function(bars, symbols, start_date, end_date) {
  bars <- if (is.null(bars) || nrow(bars) == 0L) {
    g5_empty_bar_data()
  } else {
    g5_validate_bar_data(bars)
  }
  symbols <- g5_standardize_symbol(symbols)
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  if (any(is.na(c(start_date, end_date)))) {
    g5_stop("start_date and end_date must be valid dates.")
  }
  if (start_date > end_date) {
    g5_stop("start_date must be on or before end_date.")
  }
  if (nrow(bars) == 0L) {
    return(bars)
  }
  keep <- bars$symbol %in% symbols &
    as.Date(bars$session_date) >= start_date &
    as.Date(bars$session_date) <= end_date
  g5_validate_bar_data(bars[keep, , drop = FALSE])
}

g5_git_sha_or_na <- function(repo_root) {
  out <- tryCatch(
    system2("git", c("-C", repo_root, "rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(e) character()
  )
  if (length(out) == 0L || !nzchar(out[[1L]])) {
    return(NA_character_)
  }
  out[[1L]]
}

g5_workbench_manifest <- function(
  wrapper,
  as_of_timestamp,
  latest_completed_session,
  resolution_reason,
  requested_start_date,
  requested_end_date,
  fetch_start_date,
  fetch_end_date,
  universe_name,
  universe_roles,
  requested_symbols,
  returned_symbols,
  cache_root,
  provider,
  feed,
  refresh,
  git_sha,
  health_max_severity
) {
  data.frame(
    wrapper = wrapper,
    as_of_timestamp = as.character(as_of_timestamp),
    latest_completed_session = as.Date(latest_completed_session),
    resolution_reason = as.character(resolution_reason),
    requested_start_date = as.Date(requested_start_date),
    requested_end_date = as.Date(requested_end_date),
    fetch_start_date = as.Date(fetch_start_date),
    fetch_end_date = as.Date(fetch_end_date),
    universe_name = as.character(universe_name),
    universe_roles = paste(as.character(universe_roles), collapse = ","),
    requested_symbols = paste(g5_standardize_symbol(requested_symbols), collapse = ","),
    returned_symbols = paste(g5_standardize_symbol(returned_symbols), collapse = ","),
    cache_root = normalizePath(cache_root, winslash = "/", mustWork = FALSE),
    provider = as.character(provider),
    feed = as.character(feed),
    refresh = isTRUE(refresh),
    git_sha = as.character(git_sha),
    health_max_severity = as.character(health_max_severity),
    stringsAsFactors = FALSE
  )
}

g5_workbench_query_adjusted_daily_bars <- function(
  cfg,
  start_date,
  end_date,
  as_of_timestamp,
  symbols = NULL,
  universe_registry = NULL,
  universe_name = "gen5_v0_1_poc_growth",
  universe_roles = "research_universe",
  cache_root = cfg$cache$root,
  refresh = FALSE,
  repo_root = normalizePath(".", winslash = "/", mustWork = TRUE),
  fetcher = g5_fetch_alpaca_daily_adjusted_bars,
  git_sha = g5_git_sha_or_na(repo_root)
) {
  if (missing(as_of_timestamp) || is.null(as_of_timestamp)) {
    g5_stop("as_of_timestamp is required for workbench queries.")
  }
  cfg <- g5_validate_data_layer_config(cfg)
  if (!identical(as.character(cfg$provider), "alpaca")) {
    g5_stop("Workbench query supports Alpaca adjusted daily bars only.")
  }
  if (!identical(as.character(cfg$timeframe), "1D") || !isTRUE(cfg$adjusted)) {
    g5_stop("Workbench query supports adjusted daily 1D bars only.")
  }

  if (is.null(symbols)) {
    if (is.null(universe_registry)) {
      universe_registry <- g5_load_universe_registry(file.path(repo_root, "config", "universe_registry.csv"))
    }
    symbols <- g5_universe_symbols(universe_registry, universe_name = universe_name, roles = universe_roles)
  } else {
    symbols <- g5_standardize_symbol(symbols)
  }
  if (length(symbols) == 0L) {
    g5_stop("Workbench query resolved zero symbols.")
  }

  resolved <- g5_resolve_latest_completed_session(
    as_of_timestamp = as_of_timestamp,
    timezone = cfg$calendar$timezone,
    market_close_time = cfg$calendar$market_close_time
  )
  date_range <- g5_alpaca_resolve_daily_date_range(
    start_date = start_date,
    end_date = end_date,
    latest_completed_session = resolved$latest_completed_session
  )
  request <- g5_alpaca_daily_adjusted_request(
    symbols = symbols,
    start_date = date_range$fetch_start_date,
    end_date = date_range$fetch_end_date,
    as_of_timestamp = resolved$as_of_timestamp,
    latest_completed_session = resolved$latest_completed_session,
    feed = cfg$feed
  )

  cache_root <- g5_require_writable_cache_root(cache_root)
  refresh_plan <- g5_plan_incremental_cache_refresh(
    symbols = symbols,
    cache_root = cache_root,
    requested_start_date = date_range$fetch_start_date,
    requested_end_date = date_range$fetch_end_date,
    latest_completed_session = resolved$latest_completed_session,
    provider = cfg$provider,
    timeframe = cfg$timeframe
  )

  fetched_bars <- g5_empty_bar_data()
  merge_summary <- data.frame()
  if (isTRUE(refresh)) {
    fetch_rows <- refresh_plan$plan[refresh_plan$plan$needs_fetch, , drop = FALSE]
    fetched_frames <- list()
    if (nrow(fetch_rows) > 0L) {
      alpaca_cfg <- g5_alpaca_config_from_env()
      g5_alpaca_preflight_live_fetch(alpaca_cfg)
      for (i in seq_len(nrow(fetch_rows))) {
        symbol_request <- g5_alpaca_daily_adjusted_request(
          symbols = fetch_rows$symbol[[i]],
          start_date = fetch_rows$fetch_start_date[[i]],
          end_date = fetch_rows$fetch_end_date[[i]],
          as_of_timestamp = resolved$as_of_timestamp,
          latest_completed_session = resolved$latest_completed_session,
          feed = cfg$feed
        )
        fetched_frames[[fetch_rows$symbol[[i]]]] <- fetcher(symbol_request, config = alpaca_cfg)
      }
    }
    fetched_bars <- if (length(fetched_frames) == 0L) {
      g5_empty_bar_data()
    } else {
      g5_validate_bar_data(do.call(rbind, fetched_frames))
    }
    written <- g5_write_incremental_bars_cache(
      fetched_bars = fetched_bars,
      cache_root = cache_root,
      refresh_plan = refresh_plan$plan,
      provider = cfg$provider,
      timeframe = cfg$timeframe
    )
    merge_summary <- written$summary
  }

  cache_read <- g5_read_bars_cache(
    symbols,
    cache_root = cache_root,
    provider = cfg$provider,
    timeframe = cfg$timeframe,
    require_all = FALSE,
    return_metadata = TRUE
  )
  query_bars <- g5_filter_query_bars(
    cache_read$bars,
    symbols = symbols,
    start_date = date_range$fetch_start_date,
    end_date = date_range$fetch_end_date
  )

  audit <- g5_audit_bars(
    bars = query_bars,
    requested_symbols = symbols,
    latest_completed_session = resolved$latest_completed_session,
    requested_start_date = date_range$requested_start_date,
    requested_end_date = date_range$requested_end_date,
    provider_query_timestamp = resolved$as_of_timestamp,
    cache_hits = cache_read$cache_hit_symbols,
    cache_misses = cache_read$cache_missing_symbols,
    availability_warnings = date_range$date_range_warnings,
    cache_refresh_plan = refresh_plan$plan,
    cache_refresh_result = merge_summary
  )
  symbol_coverage <- g5_symbol_coverage_artifact(
    bars = query_bars,
    requested_symbols = symbols,
    latest_completed_session = resolved$latest_completed_session,
    requested_start_date = date_range$requested_start_date,
    requested_end_date = date_range$requested_end_date,
    cache_refresh_plan = refresh_plan$plan,
    cache_refresh_result = merge_summary
  )
  health <- g5_data_health_report(
    bars = query_bars,
    audit = audit,
    symbol_coverage = symbol_coverage,
    date_range = date_range,
    refresh_plan = refresh_plan$plan
  )
  max_severity <- g5_health_max_severity(health)
  returned_symbols <- if (nrow(query_bars) > 0L) unique(query_bars$symbol) else character()

  manifest <- g5_workbench_manifest(
    wrapper = "g5_workbench_query_adjusted_daily_bars",
    as_of_timestamp = resolved$as_of_timestamp,
    latest_completed_session = resolved$latest_completed_session,
    resolution_reason = resolved$resolution_reason,
    requested_start_date = date_range$requested_start_date,
    requested_end_date = date_range$requested_end_date,
    fetch_start_date = date_range$fetch_start_date,
    fetch_end_date = date_range$fetch_end_date,
    universe_name = universe_name,
    universe_roles = universe_roles,
    requested_symbols = symbols,
    returned_symbols = returned_symbols,
    cache_root = cache_root,
    provider = cfg$provider,
    feed = cfg$feed,
    refresh = refresh,
    git_sha = git_sha,
    health_max_severity = max_severity
  )

  list(
    bars = query_bars,
    manifest = manifest,
    audit = audit,
    symbol_coverage = symbol_coverage,
    health = health,
    refresh_plan = refresh_plan$plan,
    merge_summary = merge_summary,
    date_range = date_range,
    request = request,
    resolved_session = resolved
  )
}

g5_workbench_artifact_prefix <- function(as_of_timestamp, universe_name) {
  stamp <- gsub("[^0-9A-Za-z]+", "_", as.character(as_of_timestamp))
  stamp <- gsub("_+$", "", stamp)
  name <- gsub("[^0-9A-Za-z_.-]+", "_", as.character(universe_name[[1L]]))
  paste("research_query", name, stamp, sep = "_")
}

g5_write_workbench_query_artifacts <- function(result, output_dir, prefix) {
  if (!is.list(result)) {
    g5_stop("result must be a workbench query result list.")
  }
  if (!nzchar(output_dir) || !nzchar(prefix)) {
    g5_stop("output_dir and prefix must be non-empty.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  paths <- list(
    bars_csv = file.path(output_dir, paste0(prefix, "_bars.csv")),
    manifest_csv = file.path(output_dir, paste0(prefix, "_manifest.csv")),
    audit_csv = file.path(output_dir, paste0(prefix, "_audit.csv")),
    symbol_coverage_csv = file.path(output_dir, paste0(prefix, "_symbol_coverage.csv")),
    health_csv = file.path(output_dir, paste0(prefix, "_health.csv")),
    refresh_plan_csv = file.path(output_dir, paste0(prefix, "_refresh_plan.csv"))
  )
  if (is.data.frame(result$merge_summary) && nrow(result$merge_summary) > 0L) {
    paths$merge_summary_csv <- file.path(output_dir, paste0(prefix, "_merge_summary.csv"))
  }

  utils::write.csv(result$bars, paths$bars_csv, row.names = FALSE)
  g5_write_audit_artifact_csv(result$audit, paths$audit_csv)
  g5_write_symbol_coverage_artifact_csv(result$symbol_coverage, paths$symbol_coverage_csv)
  g5_write_data_health_report_csv(result$health, paths$health_csv)
  g5_write_refresh_plan_artifact_csv(result$refresh_plan, paths$refresh_plan_csv)
  if (!is.null(paths$merge_summary_csv)) {
    g5_write_cache_merge_summary_artifact_csv(result$merge_summary, paths$merge_summary_csv)
  }

  manifest <- result$manifest
  for (nm in names(paths)) {
    manifest[[nm]] <- normalizePath(paths[[nm]], winslash = "/", mustWork = FALSE)
  }
  utils::write.csv(manifest, paths$manifest_csv, row.names = FALSE)

  list(paths = lapply(paths, normalizePath, winslash = "/", mustWork = FALSE), manifest = manifest)
}
