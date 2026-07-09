# Gen5.1 one-symbol data proof helpers.

g5_data_proof_artifact_prefix <- function(as_of_timestamp, symbol) {
  stamp <- gsub("[^0-9A-Za-z]+", "_", as.character(as_of_timestamp))
  stamp <- gsub("_+$", "", stamp)
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  paste("data_proof", symbol, stamp, sep = "_")
}

g5_data_proof_output_dir <- function(repo_root, as_of_timestamp, symbol) {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "data_proofs",
    g5_data_proof_artifact_prefix(as_of_timestamp, symbol)
  )
}

g5_symbol_row_count <- function(bars, symbol) {
  symbol <- g5_standardize_symbol(symbol)
  bars <- if (is.null(bars) || nrow(bars) == 0L) {
    g5_empty_bar_data()
  } else {
    g5_validate_bar_data(bars)
  }
  sum(bars$symbol == symbol)
}

g5_require_chartable_symbol <- function(result, symbol, refresh) {
  row_count <- g5_symbol_row_count(result$bars, symbol)
  if (row_count > 0L) {
    return(invisible(TRUE))
  }
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  hint <- if (isTRUE(refresh)) {
    "The provider/cache query returned no canonical bars for this symbol and date range."
  } else {
    "No cached bars were found for this symbol and date range. Run again with -Refresh, or choose a symbol already present in data_cache/."
  }
  g5_stop(paste("Cannot render data proof for", symbol, "because there are no chartable bars.", hint))
}

g5_symbol_data_proof_summary <- function(result, symbol, candlestick_png, artifact_paths = list()) {
  if (!is.list(result)) {
    g5_stop("result must be a workbench query result list.")
  }
  symbol <- g5_standardize_symbol(symbol)
  if (length(symbol) != 1L) {
    g5_stop("Data proof summary requires exactly one symbol.")
  }
  bars <- if (is.null(result$bars) || nrow(result$bars) == 0L) {
    g5_empty_bar_data()
  } else {
    g5_validate_bar_data(result$bars)
  }
  symbol_bars <- bars[bars$symbol == symbol, , drop = FALSE]
  session_dates <- as.Date(symbol_bars$session_date)

  coverage <- result$symbol_coverage
  symbol_coverage <- if (is.data.frame(coverage) && "symbol" %in% names(coverage)) {
    coverage[coverage$symbol == symbol, , drop = FALSE]
  } else {
    data.frame()
  }
  coverage_value <- function(name) {
    if (nrow(symbol_coverage) == 0L || !(name %in% names(symbol_coverage))) {
      return(NA_character_)
    }
    as.character(symbol_coverage[[name]][[1L]])
  }

  health <- result$health
  health_max <- if (is.data.frame(health)) g5_health_max_severity(health) else NA_character_
  warn_count <- if (is.data.frame(health) && "severity" %in% names(health)) {
    sum(health$severity == "WARN", na.rm = TRUE)
  } else {
    NA_integer_
  }
  error_count <- if (is.data.frame(health) && "severity" %in% names(health)) {
    sum(health$severity == "ERROR", na.rm = TRUE)
  } else {
    NA_integer_
  }

  get_path <- function(name) {
    if (length(artifact_paths) == 0L || is.null(artifact_paths[[name]])) {
      return(NA_character_)
    }
    normalizePath(artifact_paths[[name]], winslash = "/", mustWork = FALSE)
  }

  data.frame(
    schema_version = "gen5_symbol_data_proof_v0.1",
    symbol = symbol,
    as_of_timestamp = as.character(result$resolved_session$as_of_timestamp),
    latest_completed_session = as.Date(result$resolved_session$latest_completed_session),
    resolution_reason = as.character(result$resolved_session$resolution_reason),
    requested_start_date = as.Date(result$date_range$requested_start_date),
    requested_end_date = as.Date(result$date_range$requested_end_date),
    fetch_start_date = as.Date(result$date_range$fetch_start_date),
    fetch_end_date = as.Date(result$date_range$fetch_end_date),
    row_count = nrow(symbol_bars),
    observed_start_date = if (length(session_dates) == 0L) as.Date(NA) else min(session_dates),
    observed_end_date = if (length(session_dates) == 0L) as.Date(NA) else max(session_dates),
    health_max_severity = health_max,
    health_warn_count = warn_count,
    health_error_count = error_count,
    empty_status = coverage_value("empty_status"),
    partial_history_status = coverage_value("partial_history_status"),
    stale_status = coverage_value("stale_status"),
    refresh = isTRUE(result$manifest$refresh[[1L]]),
    candlestick_png = normalizePath(candlestick_png, winslash = "/", mustWork = FALSE),
    bars_csv = get_path("bars_csv"),
    manifest_csv = get_path("manifest_csv"),
    health_csv = get_path("health_csv"),
    symbol_coverage_csv = get_path("symbol_coverage_csv"),
    audit_csv = get_path("audit_csv"),
    refresh_plan_csv = get_path("refresh_plan_csv"),
    stringsAsFactors = FALSE
  )
}

g5_write_symbol_data_proof_markdown <- function(summary, health, path) {
  if (!is.data.frame(summary) || nrow(summary) != 1L) {
    g5_stop("summary must be a one-row data.frame.")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  lines <- c(
    paste0("# Gen5 Symbol Data Proof: ", summary$symbol[[1L]]),
    "",
    paste0("- As of timestamp: `", summary$as_of_timestamp[[1L]], "`"),
    paste0("- Latest completed session: `", as.character(summary$latest_completed_session[[1L]]), "`"),
    paste0("- Requested range: `", as.character(summary$requested_start_date[[1L]]), "` to `", as.character(summary$requested_end_date[[1L]]), "`"),
    paste0("- Fetch range: `", as.character(summary$fetch_start_date[[1L]]), "` to `", as.character(summary$fetch_end_date[[1L]]), "`"),
    paste0("- Observed range: `", as.character(summary$observed_start_date[[1L]]), "` to `", as.character(summary$observed_end_date[[1L]]), "`"),
    paste0("- Rows: `", summary$row_count[[1L]], "`"),
    paste0("- Health max severity: `", summary$health_max_severity[[1L]], "`"),
    paste0("- Chart: `", summary$candlestick_png[[1L]], "`"),
    "",
    "## Health Rows",
    ""
  )
  if (is.data.frame(health) && nrow(health) > 0L) {
    keep_cols <- intersect(c("severity", "category", "symbol", "message"), names(health))
    health_small <- health[, keep_cols, drop = FALSE]
    header <- paste(keep_cols, collapse = " | ")
    sep <- paste(rep("---", length(keep_cols)), collapse = " | ")
    rows <- apply(health_small, 1L, function(x) paste(as.character(x), collapse = " | "))
    lines <- c(lines, paste0("| ", header, " |"), paste0("| ", sep, " |"), paste0("| ", rows, " |"))
  } else {
    lines <- c(lines, "No health rows were produced.")
  }
  writeLines(lines, con = path, useBytes = TRUE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_write_symbol_data_proof_outputs <- function(result, symbol, output_dir) {
  if (!nzchar(output_dir)) {
    g5_stop("output_dir must be non-empty.")
  }
  symbol <- g5_standardize_symbol(symbol)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  prefix <- g5_data_proof_artifact_prefix(result$resolved_session$as_of_timestamp, symbol)
  written <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = prefix)
  png_path <- file.path(output_dir, paste0(prefix, "_candlestick.png"))
  g5_write_static_candlestick_png(
    result$bars,
    symbol = symbol,
    path = png_path,
    start_date = result$date_range$fetch_start_date,
    end_date = result$date_range$fetch_end_date
  )

  summary <- g5_symbol_data_proof_summary(
    result = result,
    symbol = symbol,
    candlestick_png = png_path,
    artifact_paths = written$paths
  )
  summary_csv <- file.path(output_dir, paste0(prefix, "_summary.csv"))
  summary_md <- file.path(output_dir, paste0(prefix, "_summary.md"))
  utils::write.csv(summary, summary_csv, row.names = FALSE)
  g5_write_symbol_data_proof_markdown(summary, result$health, summary_md)

  paths <- c(
    written$paths,
    list(
      candlestick_png = normalizePath(png_path, winslash = "/", mustWork = FALSE),
      summary_csv = normalizePath(summary_csv, winslash = "/", mustWork = FALSE),
      summary_md = normalizePath(summary_md, winslash = "/", mustWork = FALSE)
    )
  )
  list(paths = paths, summary = summary, manifest = written$manifest)
}

g5_multi_symbol_report_artifact_prefix <- function(as_of_timestamp, symbols) {
  stamp <- gsub("[^0-9A-Za-z]+", "_", as.character(as_of_timestamp))
  stamp <- gsub("_+$", "", stamp)
  symbols <- unique(g5_standardize_symbol(symbols))
  paste("multi_symbol_report", paste0(length(symbols), "symbols"), stamp, sep = "_")
}

g5_multi_symbol_report_output_dir <- function(repo_root, as_of_timestamp, symbols) {
  file.path(
    repo_root,
    "runs",
    "research_workbench",
    "multi_symbol_reports",
    g5_multi_symbol_report_artifact_prefix(as_of_timestamp, symbols)
  )
}

g5_multi_symbol_report_summary <- function(result, symbols, multi_panel_png, artifact_paths = list()) {
  symbols <- unique(g5_standardize_symbol(symbols))
  rows <- lapply(symbols, function(sym) {
    one <- g5_symbol_data_proof_summary(
      result = result,
      symbol = sym,
      candlestick_png = multi_panel_png,
      artifact_paths = artifact_paths
    )
    one$schema_version <- "gen5_multi_symbol_report_v0.1"
    one
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_write_multi_symbol_report_markdown <- function(summary, health, path) {
  if (!is.data.frame(summary) || nrow(summary) == 0L) {
    g5_stop("summary must be a non-empty data.frame.")
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  lines <- c(
    "# Gen5 Multi-Symbol Data Report",
    "",
    paste0("- Symbols: `", paste(summary$symbol, collapse = ", "), "`"),
    paste0("- As of timestamp: `", summary$as_of_timestamp[[1L]], "`"),
    paste0("- Latest completed session: `", as.character(summary$latest_completed_session[[1L]]), "`"),
    paste0("- Requested range: `", as.character(summary$requested_start_date[[1L]]), "` to `", as.character(summary$requested_end_date[[1L]]), "`"),
    paste0("- Health max severity: `", summary$health_max_severity[[1L]], "`"),
    paste0("- Multi-panel chart: `", summary$candlestick_png[[1L]], "`"),
    "",
    "## Symbol Coverage",
    "",
    "| symbol | rows | observed_start | observed_end | empty | partial_history | stale |",
    "| --- | ---: | --- | --- | --- | --- | --- |"
  )
  coverage_rows <- apply(summary, 1L, function(x) {
    paste0(
      "| ", x[["symbol"]],
      " | ", x[["row_count"]],
      " | ", x[["observed_start_date"]],
      " | ", x[["observed_end_date"]],
      " | ", x[["empty_status"]],
      " | ", x[["partial_history_status"]],
      " | ", x[["stale_status"]],
      " |"
    )
  })
  lines <- c(lines, coverage_rows, "", "## Health Rows", "")
  if (is.data.frame(health) && nrow(health) > 0L) {
    keep_cols <- intersect(c("severity", "category", "symbol", "message"), names(health))
    health_small <- health[, keep_cols, drop = FALSE]
    header <- paste(keep_cols, collapse = " | ")
    sep <- paste(rep("---", length(keep_cols)), collapse = " | ")
    rows <- apply(health_small, 1L, function(x) paste(as.character(x), collapse = " | "))
    lines <- c(lines, paste0("| ", header, " |"), paste0("| ", sep, " |"), paste0("| ", rows, " |"))
  } else {
    lines <- c(lines, "No health rows were produced.")
  }
  writeLines(lines, con = path, useBytes = TRUE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_write_multi_symbol_report_outputs <- function(result, symbols, output_dir) {
  symbols <- unique(g5_standardize_symbol(symbols))
  if (!nzchar(output_dir)) {
    g5_stop("output_dir must be non-empty.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  prefix <- g5_multi_symbol_report_artifact_prefix(result$resolved_session$as_of_timestamp, symbols)
  written <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = prefix)
  row_counts <- vapply(symbols, function(sym) g5_symbol_row_count(result$bars, sym), integer(1L))
  chart_symbols <- names(row_counts)[row_counts > 0L]
  if (length(chart_symbols) == 0L) {
    hint <- "No requested symbols have cached bars for the requested range. Run again with -Refresh or choose symbols already present in data_cache/."
    g5_stop(paste("Cannot render multi-symbol report because there are no chartable bars.", hint))
  }

  png_path <- file.path(output_dir, paste0(prefix, "_multi_panel_candlestick.png"))
  g5_write_multi_symbol_candlestick_png(
    result$bars,
    symbols = chart_symbols,
    path = png_path,
    start_date = result$date_range$fetch_start_date,
    end_date = result$date_range$fetch_end_date,
    title = paste("Gen5 Multi-Symbol Data Report:", paste(chart_symbols, collapse = ", "))
  )

  summary <- g5_multi_symbol_report_summary(
    result = result,
    symbols = symbols,
    multi_panel_png = png_path,
    artifact_paths = written$paths
  )
  summary_csv <- file.path(output_dir, paste0(prefix, "_summary.csv"))
  summary_md <- file.path(output_dir, paste0(prefix, "_summary.md"))
  utils::write.csv(summary, summary_csv, row.names = FALSE)
  g5_write_multi_symbol_report_markdown(summary, result$health, summary_md)

  paths <- c(
    written$paths,
    list(
      multi_panel_png = normalizePath(png_path, winslash = "/", mustWork = FALSE),
      summary_csv = normalizePath(summary_csv, winslash = "/", mustWork = FALSE),
      summary_md = normalizePath(summary_md, winslash = "/", mustWork = FALSE)
    )
  )
  list(paths = paths, summary = summary, manifest = written$manifest, chart_symbols = chart_symbols)
}
