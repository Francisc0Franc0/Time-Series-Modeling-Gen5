# Simple deterministic local cache helpers.

g5_cache_symbol_path <- function(cache_root, provider, timeframe, symbol, format = "rds") {
  if (!nzchar(cache_root)) {
    g5_stop("cache_root must be a non-empty path.")
  }
  if (!format %in% c("rds")) {
    g5_stop("Only rds cache format is implemented in the v0 scaffold.")
  }

  safe_symbol <- gsub("[^A-Za-z0-9_.-]", "_", g5_standardize_symbol(symbol))
  file.path(normalizePath(cache_root, winslash = "/", mustWork = FALSE), provider, timeframe, paste0(safe_symbol, ".", format))
}

g5_write_bars_cache <- function(bars, cache_root, provider = "alpaca", timeframe = "1D") {
  bars <- g5_validate_bar_data(bars)
  symbols <- unique(bars$symbol)
  written <- character()

  for (sym in symbols) {
    out_path <- g5_cache_symbol_path(cache_root, provider, timeframe, sym)
    dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
    saveRDS(bars[bars$symbol == sym, , drop = FALSE], out_path)
    written <- c(written, out_path)
  }

  data.frame(symbol = symbols, path = written, stringsAsFactors = FALSE)
}

g5_cache_symbol_summary <- function(bars, symbol) {
  symbol <- g5_standardize_symbol(symbol)
  if (!is.data.frame(bars) || nrow(bars) == 0L) {
    return(data.frame(
      symbol = symbol,
      cached_row_count = 0L,
      first_cached_session = as.Date(NA_character_),
      latest_cached_session = as.Date(NA_character_),
      stringsAsFactors = FALSE
    ))
  }

  bars <- g5_validate_bar_data(bars)
  symbol_bars <- bars[bars$symbol == symbol, , drop = FALSE]
  if (nrow(symbol_bars) == 0L) {
    return(data.frame(
      symbol = symbol,
      cached_row_count = 0L,
      first_cached_session = as.Date(NA_character_),
      latest_cached_session = as.Date(NA_character_),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    symbol = symbol,
    cached_row_count = nrow(symbol_bars),
    first_cached_session = min(as.Date(symbol_bars$session_date)),
    latest_cached_session = max(as.Date(symbol_bars$session_date)),
    stringsAsFactors = FALSE
  )
}

g5_read_bars_cache <- function(
  symbols,
  cache_root,
  provider = "alpaca",
  timeframe = "1D",
  require_all = TRUE,
  return_metadata = FALSE
) {
  symbols <- g5_standardize_symbol(symbols)
  frames <- list()
  missing <- character()
  hit_paths <- character()

  for (sym in symbols) {
    path <- g5_cache_symbol_path(cache_root, provider, timeframe, sym)
    if (!file.exists(path)) {
      missing <- c(missing, sym)
    } else {
      frames[[sym]] <- readRDS(path)
      hit_paths <- c(hit_paths, path)
    }
  }

  if (require_all && length(missing) > 0L) {
    g5_stop(paste("Missing cache files for symbols:", paste(missing, collapse = ", ")))
  }

  bars <- if (length(frames) == 0L) {
    g5_empty_bar_data()
  } else {
    out <- do.call(rbind, frames)
    rownames(out) <- NULL
    out
  }
  bars <- g5_validate_bar_data(bars)

  if (return_metadata) {
    return(list(
      bars = bars,
      requested_symbols = symbols,
      cache_hit_symbols = names(frames),
      cache_missing_symbols = missing,
      cache_hit_paths = hit_paths
    ))
  }

  bars
}

g5_plan_incremental_cache_refresh <- function(
  symbols,
  cache_root,
  requested_start_date,
  requested_end_date,
  latest_completed_session,
  provider = "alpaca",
  timeframe = "1D"
) {
  symbols <- g5_standardize_symbol(symbols)
  requested_start_date <- as.Date(requested_start_date)
  requested_end_date <- as.Date(requested_end_date)
  latest_completed_session <- as.Date(latest_completed_session)
  if (any(is.na(c(requested_start_date, requested_end_date, latest_completed_session)))) {
    g5_stop("requested_start_date, requested_end_date, and latest_completed_session must be valid dates.")
  }
  if (requested_start_date > requested_end_date) {
    g5_stop("requested_start_date must be on or before requested_end_date.")
  }
  if (requested_end_date > latest_completed_session) {
    g5_stop("requested_end_date cannot be after latest_completed_session.")
  }

  cache_read <- g5_read_bars_cache(
    symbols = symbols,
    cache_root = cache_root,
    provider = provider,
    timeframe = timeframe,
    require_all = FALSE,
    return_metadata = TRUE
  )

  rows <- vector("list", length(symbols))
  for (i in seq_along(symbols)) {
    sym <- symbols[[i]]
    path <- g5_cache_symbol_path(cache_root, provider, timeframe, sym)
    has_file <- file.exists(path)
    symbol_bars <- cache_read$bars[cache_read$bars$symbol == sym, , drop = FALSE]
    summary <- g5_cache_symbol_summary(symbol_bars, sym)
    first_cached <- summary$first_cached_session
    latest_cached <- summary$latest_cached_session
    cached_row_count <- summary$cached_row_count

    needs_fetch <- TRUE
    refresh_decision <- "cold_cache"
    fetch_start_date <- requested_start_date
    fetch_end_date <- requested_end_date

    if (has_file && cached_row_count == 0L) {
      refresh_decision <- "cold_cache_empty_file"
    } else if (has_file) {
      has_start <- !is.na(first_cached) && first_cached <= requested_start_date
      has_end <- !is.na(latest_cached) && latest_cached >= requested_end_date

      if (has_start && has_end) {
        needs_fetch <- FALSE
        refresh_decision <- "fully_cached"
        fetch_start_date <- as.Date(NA_character_)
        fetch_end_date <- as.Date(NA_character_)
      } else if (!has_start && !has_end) {
        refresh_decision <- "partial_history_stale"
      } else if (!has_start) {
        refresh_decision <- "partial_history"
        fetch_end_date <- min(first_cached - 1L, requested_end_date)
      } else {
        refresh_decision <- "stale_cache"
        fetch_start_date <- max(latest_cached + 1L, requested_start_date)
      }
    }

    if (needs_fetch && fetch_start_date > fetch_end_date) {
      needs_fetch <- FALSE
      refresh_decision <- "fully_cached"
      fetch_start_date <- as.Date(NA_character_)
      fetch_end_date <- as.Date(NA_character_)
    }

    rows[[i]] <- data.frame(
      symbol = sym,
      cache_path = path,
      cache_file_exists = has_file,
      cached_row_count = cached_row_count,
      first_cached_session = first_cached,
      latest_cached_session = latest_cached,
      requested_start_date = requested_start_date,
      requested_end_date = requested_end_date,
      needs_fetch = needs_fetch,
      refresh_decision = refresh_decision,
      fetch_start_date = fetch_start_date,
      fetch_end_date = fetch_end_date,
      stringsAsFactors = FALSE
    )
  }

  plan <- do.call(rbind, rows)
  rownames(plan) <- NULL
  list(plan = plan, cache_read = cache_read)
}

g5_merge_bar_cache <- function(existing_bars, fetched_bars, prefer = "fetched") {
  if (!prefer %in% c("fetched", "existing")) {
    g5_stop("prefer must be either 'fetched' or 'existing'.")
  }

  existing_bars <- if (is.null(existing_bars) || nrow(existing_bars) == 0L) {
    g5_empty_bar_data()
  } else {
    g5_validate_bar_data(existing_bars)
  }
  fetched_bars <- if (is.null(fetched_bars) || nrow(fetched_bars) == 0L) {
    g5_empty_bar_data()
  } else {
    g5_validate_bar_data(fetched_bars)
  }

  if (nrow(existing_bars) == 0L && nrow(fetched_bars) == 0L) {
    return(g5_empty_bar_data())
  }

  existing_bars$.g5_merge_source <- rep("existing", nrow(existing_bars))
  fetched_bars$.g5_merge_source <- rep("fetched", nrow(fetched_bars))
  combined <- rbind(existing_bars, fetched_bars)
  source_rank <- if (prefer == "fetched") {
    ifelse(combined$.g5_merge_source == "fetched", 2L, 1L)
  } else {
    ifelse(combined$.g5_merge_source == "existing", 2L, 1L)
  }
  combined$.g5_source_rank <- source_rank
  combined <- combined[order(combined$symbol, combined$session_date, combined$.g5_source_rank), , drop = FALSE]
  key <- paste(combined$symbol, combined$session_date)
  combined <- combined[!duplicated(key, fromLast = TRUE), , drop = FALSE]
  combined$.g5_merge_source <- NULL
  combined$.g5_source_rank <- NULL
  rownames(combined) <- NULL

  g5_validate_bar_data(combined)
}

g5_write_incremental_bars_cache <- function(
  fetched_bars,
  cache_root,
  refresh_plan,
  provider = "alpaca",
  timeframe = "1D"
) {
  if (!is.data.frame(refresh_plan) || nrow(refresh_plan) == 0L) {
    g5_stop("refresh_plan must be a non-empty data.frame.")
  }
  fetched_bars <- if (is.null(fetched_bars) || nrow(fetched_bars) == 0L) {
    g5_empty_bar_data()
  } else {
    g5_validate_bar_data(fetched_bars)
  }

  rows <- vector("list", nrow(refresh_plan))
  merged_frames <- list()
  for (i in seq_len(nrow(refresh_plan))) {
    sym <- g5_standardize_symbol(refresh_plan$symbol[[i]])
    path <- g5_cache_symbol_path(cache_root, provider, timeframe, sym)
    existing <- if (file.exists(path)) {
      readRDS(path)
    } else {
      g5_empty_bar_data()
    }
    existing <- if (nrow(existing) == 0L) g5_empty_bar_data() else g5_validate_bar_data(existing)
    fetched <- fetched_bars[fetched_bars$symbol == sym, , drop = FALSE]
    had_returned_bars <- nrow(fetched) > 0L
    merged <- g5_merge_bar_cache(existing, fetched, prefer = "fetched")

    if (nrow(merged) > 0L) {
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      saveRDS(merged, path)
      merged_frames[[sym]] <- merged
    }

    rows[[i]] <- data.frame(
      symbol = sym,
      path = path,
      refresh_decision = as.character(refresh_plan$refresh_decision[[i]]),
      needs_fetch = isTRUE(refresh_plan$needs_fetch[[i]]),
      returned_bar_count = nrow(fetched),
      merged_row_count = nrow(merged),
      first_merged_session = if (nrow(merged) > 0L) min(merged$session_date) else as.Date(NA_character_),
      latest_merged_session = if (nrow(merged) > 0L) max(merged$session_date) else as.Date(NA_character_),
      no_returned_bars = isTRUE(refresh_plan$needs_fetch[[i]]) && !had_returned_bars,
      wrote_cache = nrow(merged) > 0L,
      stringsAsFactors = FALSE
    )
  }

  merged_bars <- if (length(merged_frames) == 0L) {
    g5_empty_bar_data()
  } else {
    do.call(rbind, merged_frames)
  }
  merged_bars <- g5_validate_bar_data(merged_bars)

  write_summary <- do.call(rbind, rows)
  rownames(write_summary) <- NULL
  list(summary = write_summary, bars = merged_bars)
}

g5_refresh_plan_artifact <- function(refresh_plan) {
  required <- c(
    "symbol",
    "cache_path",
    "cache_file_exists",
    "cached_row_count",
    "first_cached_session",
    "latest_cached_session",
    "requested_start_date",
    "requested_end_date",
    "needs_fetch",
    "refresh_decision",
    "fetch_start_date",
    "fetch_end_date"
  )
  if (!is.data.frame(refresh_plan) || nrow(refresh_plan) == 0L) {
    g5_stop("refresh_plan must be a non-empty data.frame.")
  }
  missing <- setdiff(required, names(refresh_plan))
  if (length(missing) > 0L) {
    g5_stop(paste("refresh_plan is missing required columns:", paste(missing, collapse = ", ")))
  }

  out <- refresh_plan[required]
  out$symbol <- g5_standardize_symbol(out$symbol)
  out$cache_file_exists <- as.logical(out$cache_file_exists)
  out$cached_row_count <- as.integer(out$cached_row_count)
  out$needs_fetch <- as.logical(out$needs_fetch)
  out <- out[order(out$symbol), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_cache_merge_summary_artifact <- function(merge_summary) {
  required <- c(
    "symbol",
    "path",
    "refresh_decision",
    "needs_fetch",
    "returned_bar_count",
    "merged_row_count",
    "first_merged_session",
    "latest_merged_session",
    "no_returned_bars",
    "wrote_cache"
  )
  if (!is.data.frame(merge_summary) || nrow(merge_summary) == 0L) {
    g5_stop("merge_summary must be a non-empty data.frame.")
  }
  missing <- setdiff(required, names(merge_summary))
  if (length(missing) > 0L) {
    g5_stop(paste("merge_summary is missing required columns:", paste(missing, collapse = ", ")))
  }

  out <- merge_summary[required]
  names(out)[names(out) == "path"] <- "cache_path"
  out$symbol <- g5_standardize_symbol(out$symbol)
  out$needs_fetch <- as.logical(out$needs_fetch)
  out$returned_bar_count <- as.integer(out$returned_bar_count)
  out$merged_row_count <- as.integer(out$merged_row_count)
  out$no_returned_bars <- as.logical(out$no_returned_bars)
  out$wrote_cache <- as.logical(out$wrote_cache)
  out <- out[order(out$symbol), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_write_refresh_plan_artifact_csv <- function(refresh_plan, path) {
  if (!nzchar(path)) {
    g5_stop("path must be a non-empty file path.")
  }
  artifact <- g5_refresh_plan_artifact(refresh_plan)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(artifact, path, row.names = FALSE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_write_cache_merge_summary_artifact_csv <- function(merge_summary, path) {
  if (!nzchar(path)) {
    g5_stop("path must be a non-empty file path.")
  }
  artifact <- g5_cache_merge_summary_artifact(merge_summary)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(artifact, path, row.names = FALSE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}
