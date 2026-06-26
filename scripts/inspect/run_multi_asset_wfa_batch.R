# Gen5.1 multi-asset WFA batch diagnostic.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "cache_store.R"))
source(file.path(repo_root, "R", "data_audit.R"))
source(file.path(repo_root, "R", "universe_registry.R"))
source(file.path(repo_root, "R", "workbench_query.R"))
source(file.path(repo_root, "R", "workbench_chart.R"))
source(file.path(repo_root, "R", "workbench_data_proof.R"))
source(file.path(repo_root, "R", "strategy_ema_cross.R"))
source(file.path(repo_root, "R", "strategy_bollinger_touch.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_poc.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))

g5_batch_parse_int_list_env <- function(value, label) {
  if (!nzchar(value)) {
    g5_stop(paste0(label, " must be a comma-separated list of positive integers."))
  }
  raw <- trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
  raw <- raw[nzchar(raw)]
  parsed <- suppressWarnings(as.integer(raw))
  if (length(parsed) == 0L || any(is.na(parsed)) || any(parsed < 1L)) {
    g5_stop(paste0(label, " must be a comma-separated list of positive integers."))
  }
  sort(unique(parsed))
}

g5_batch_parse_num_list_env <- function(value, label) {
  if (!nzchar(value)) {
    g5_stop(paste0(label, " must be a comma-separated list of positive numbers."))
  }
  raw <- trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
  raw <- raw[nzchar(raw)]
  parsed <- suppressWarnings(as.numeric(raw))
  if (length(parsed) == 0L || any(is.na(parsed)) || any(parsed <= 0)) {
    g5_stop(paste0(label, " must be a comma-separated list of positive numbers."))
  }
  sort(unique(parsed))
}

g5_batch_parse_character_list_env <- function(value, label) {
  if (!nzchar(value)) {
    g5_stop(paste0(label, " must be a comma-separated list."))
  }
  raw <- unique(trimws(strsplit(value, ",", fixed = TRUE)[[1L]]))
  raw <- raw[nzchar(raw)]
  if (length(raw) == 0L) {
    g5_stop(paste0(label, " must be a comma-separated list."))
  }
  raw
}

g5_batch_fmt_pct <- function(x) {
  ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
}

g5_batch_fmt_num <- function(x) {
  ifelse(is.na(x), "NA", ifelse(is.infinite(x), "Inf", sprintf("%.3f", as.numeric(x))))
}

g5_multi_asset_wfa_batch_prefix <- function(as_of_timestamp, symbols, wfa_start_date, wfa_end_date, fold_count) {
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp))
  symbols <- g5_standardize_symbol(symbols)
  window_label <- paste0(
    gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_start_date))),
    "_",
    gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_end_date)))
  )
  paste(c("mawfa", paste0(length(symbols), "a"), paste0(fold_count, "f"), window_label, stamp), collapse = "_")
}

g5_multi_asset_table_lines <- function(df, cols) {
  df <- df[, cols, drop = FALSE]
  header <- paste(c("", names(df), ""), collapse = " | ")
  sep <- paste(c("", rep("---", ncol(df)), ""), collapse = " | ")
  rows <- apply(df, 1, function(row) paste(c("", as.character(row), ""), collapse = " | "))
  c(header, sep, rows)
}

g5_contact_sheet_pages <- function(items, max_facets_per_image) {
  max_facets_per_image <- as.integer(max_facets_per_image)
  if (is.na(max_facets_per_image) || max_facets_per_image < 1L) {
    g5_stop("max_facets_per_image must be a positive integer.")
  }
  split(seq_along(items), ceiling(seq_along(items) / max_facets_per_image))
}

g5_draw_contact_date_axis <- function(session_dates, tick_positions, aesthetic) {
  graphics::axis(1, at = tick_positions, labels = FALSE, col = aesthetic$axis, col.axis = aesthetic$axis)
  usr <- graphics::par("usr")
  y <- usr[[3L]] - diff(usr[3:4]) * 0.04
  graphics::text(
    x = tick_positions,
    y = y,
    labels = format(session_dates[tick_positions], "%Y-%m"),
    srt = 45,
    adj = 1,
    xpd = NA,
    cex = 0.6,
    col = aesthetic$axis
  )
}

g5_draw_contact_drawdown_shelves <- function(x, strategy_equity, aesthetic, lwd = 1.6) {
  strategy_equity <- as.numeric(strategy_equity)
  strategy_peak <- cummax(strategy_equity)
  underwater <- strategy_equity < strategy_peak
  if (!any(underwater, na.rm = TRUE)) {
    return(invisible(NULL))
  }
  runs <- rle(underwater)
  run_ends <- cumsum(runs$lengths)
  run_starts <- run_ends - runs$lengths + 1L
  for (i in seq_along(runs$values)) {
    if (!isTRUE(runs$values[[i]])) {
      next
    }
    idx <- seq(run_starts[[i]], run_ends[[i]])
    peak_level <- strategy_peak[[idx[[1L]]]]
    segment_start <- max(1L, idx[[1L]] - 1L)
    segment_end <- idx[[length(idx)]]
    segment_end_x <- x[[segment_end]]
    if (segment_end < length(x) && !isTRUE(underwater[[segment_end + 1L]])) {
      y0 <- strategy_equity[[segment_end]]
      y1 <- strategy_equity[[segment_end + 1L]]
      if (is.finite(y0) && is.finite(y1) && y1 != y0) {
        crossing_fraction <- max(0, min(1, (peak_level - y0) / (y1 - y0)))
        segment_end_x <- x[[segment_end]] + crossing_fraction * (x[[segment_end + 1L]] - x[[segment_end]])
      }
    }
    graphics::segments(
      x0 = x[[segment_start]],
      y0 = peak_level,
      x1 = segment_end_x,
      y1 = peak_level,
      col = grDevices::adjustcolor(aesthetic$down_candle, alpha.f = 0.42),
      lwd = lwd,
      lend = "round"
    )
  }
  invisible(NULL)
}

g5_draw_wfa_strategy_contact_panel <- function(item) {
  ind <- item$stitched_indicators
  trades <- item$stitched_trades
  folds <- item$folds
  symbol <- item$symbol
  aesthetic <- g5_chart_aesthetic()
  session_dates <- as.Date(ind$session_date)
  x <- seq_len(nrow(ind))
  y_range <- range(c(ind$low, ind$high, ind$fast_ema, ind$slow_ema, ind$bb_mid, ind$bb_upper, ind$bb_lower), finite = TRUE)
  padding <- diff(y_range) * 0.06
  if (!is.finite(padding) || padding <= 0) {
    padding <- max(abs(y_range), 1) * 0.02
  }
  graphics::plot(x = c(0.5, length(x) + 0.5), y = y_range + c(-padding, padding), type = "n", xaxt = "n", xlab = "", ylab = "", main = symbol, cex.main = 1, xaxs = "i", col.axis = aesthetic$axis, col.main = aesthetic$text, fg = aesthetic$axis)
  g5_plot_fold_backgrounds(session_dates, folds, fold_ids = ind$fold_id)
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
  body_colors <- ifelse(ind$close > ind$open, aesthetic$up_candle, ifelse(ind$close < ind$open, aesthetic$down_candle, aesthetic$flat_candle))
  graphics::segments(x0 = x, y0 = ind$low, x1 = x, y1 = ind$high, col = body_colors, lwd = 0.8)
  graphics::segments(x0 = x, y0 = ind$open, x1 = x, y1 = ind$close, col = body_colors, lwd = 2)
  for (fold_id in unique(ind$fold_id)) {
    part <- ind[ind$fold_id == fold_id, , drop = FALSE]
    part_x <- match(as.Date(part$session_date), session_dates)
    family <- unique(part$strategy_family)
    if (length(family) > 0L && identical(family[[1L]], "ema_cross")) {
      graphics::lines(part_x, part$fast_ema, col = aesthetic$native_entry_color, lwd = 0.9)
      graphics::lines(part_x, part$slow_ema, col = aesthetic$non_native_exit_color, lwd = 0.9)
    }
    if (length(family) > 0L && identical(family[[1L]], "bollinger_touch")) {
      band_col <- grDevices::adjustcolor(aesthetic$non_native_exit_color, alpha.f = 0.65)
      graphics::lines(part_x, part$bb_mid, col = aesthetic$native_entry_color, lwd = 0.8)
      graphics::lines(part_x, part$bb_upper, col = band_col, lwd = 0.8, lty = 2)
      graphics::lines(part_x, part$bb_lower, col = band_col, lwd = 0.8, lty = 2)
    }
  }
  if (is.data.frame(trades) && nrow(trades) > 0L) {
    line_cols <- ifelse(trades$trade_outcome == "win", aesthetic$trade_win_line, ifelse(trades$trade_outcome == "loss", aesthetic$trade_loss_line, aesthetic$flat_candle))
    graphics::segments(match(trades$entry_execution_date, session_dates), trades$entry_execution_price, match(trades$trace_end_date, session_dates), trades$trace_end_price, col = line_cols, lty = aesthetic$trade_line_lty, lwd = 0.9)
    graphics::points(match(trades$entry_execution_date, session_dates), trades$entry_execution_price, pch = aesthetic$native_entry_pch, col = aesthetic$native_entry_color, bg = aesthetic$native_entry_color, cex = 0.7)
    closed <- trades[!is.na(trades$exit_execution_date), , drop = FALSE]
    if (nrow(closed) > 0L) {
      native_closed <- closed[!("exit_attribution" %in% names(closed)) | is.na(closed$exit_attribution) | closed$exit_attribution == "native", , drop = FALSE]
      stack_closed <- if ("exit_attribution" %in% names(closed)) closed[closed$exit_attribution == "exit_stack", , drop = FALSE] else closed[FALSE, , drop = FALSE]
      if (nrow(native_closed) > 0L) {
        graphics::points(match(native_closed$exit_execution_date, session_dates), native_closed$exit_execution_price, pch = aesthetic$native_exit_pch, col = aesthetic$native_exit_color, bg = aesthetic$native_exit_color, cex = 0.7)
      }
      if (nrow(stack_closed) > 0L) {
        graphics::points(match(stack_closed$exit_execution_date, session_dates), stack_closed$exit_execution_price, pch = aesthetic$non_native_exit_pch, col = aesthetic$non_native_exit_color, cex = 0.85, lwd = 1.1)
      }
    }
  }
  tick_positions <- unique(round(seq(1L, length(x), length.out = min(4L, length(x)))))
  g5_draw_contact_date_axis(session_dates, tick_positions, aesthetic)
}

g5_draw_wfa_equity_contact_panel <- function(item) {
  curve <- item$stitched_equity_curve
  folds <- item$folds
  symbol <- item$symbol
  aesthetic <- g5_chart_aesthetic()
  session_dates <- as.Date(curve$session_date)
  x <- seq_len(nrow(curve))
  strategy_peak <- cummax(as.numeric(curve$strategy_equity))
  y_range <- range(c(curve$strategy_equity, strategy_peak, curve$buy_hold_equity), finite = TRUE)
  padding <- diff(y_range) * 0.08
  if (!is.finite(padding) || padding <= 0) {
    padding <- max(abs(y_range), 1) * 0.03
  }
  graphics::plot(x = c(0.5, length(x) + 0.5), y = y_range + c(-padding, padding), type = "n", xaxt = "n", xlab = "", ylab = "", main = symbol, cex.main = 1, xaxs = "i", col.axis = aesthetic$axis, col.main = aesthetic$text, fg = aesthetic$axis)
  g5_plot_fold_backgrounds(session_dates, folds)
  g5_draw_contact_drawdown_shelves(x, curve$strategy_equity, aesthetic)
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)
  graphics::abline(h = 1, col = grDevices::adjustcolor(aesthetic$axis, alpha.f = 0.35), lty = 3)
  graphics::lines(x, curve$buy_hold_equity, col = "#000000", lwd = 1)
  graphics::lines(x, curve$strategy_equity, col = aesthetic$trade_win_line, lwd = 1.4)
  tick_positions <- unique(round(seq(1L, length(x), length.out = min(4L, length(x)))))
  g5_draw_contact_date_axis(session_dates, tick_positions, aesthetic)
}

g5_write_wfa_contact_sheet_pages <- function(items, batch_dir, batch_prefix, chart_type = c("strategy", "equity"), max_facets_per_image = 6L) {
  chart_type <- match.arg(chart_type)
  pages <- g5_contact_sheet_pages(items, max_facets_per_image)
  rows <- list()
  aesthetic <- g5_chart_aesthetic()
  for (page_no in seq_along(pages)) {
    idx <- pages[[page_no]]
    page_items <- items[idx]
    panel_count <- length(page_items)
    cols <- if (panel_count == 1L) 1L else 2L
    rows_n <- ceiling(panel_count / cols)
    path <- file.path(batch_dir, paste0(batch_prefix, "_", chart_type, "_contact_sheet_", sprintf("%02d", page_no), ".png"))
    grDevices::png(filename = path, width = 3600L, height = max(1520L, rows_n * 1240L), res = 180L)
    old_par <- graphics::par(
      mfrow = c(rows_n, cols),
      mar = c(4.2, 3.8, 2.2, 1),
      oma = c(3, 4, 3, 1),
      bg = aesthetic$background,
      col.axis = aesthetic$axis,
      col.lab = aesthetic$text,
      fg = aesthetic$axis
    )
    tryCatch(
      {
        for (item in page_items) {
          if (identical(chart_type, "strategy")) {
            g5_draw_wfa_strategy_contact_panel(item)
          } else {
            g5_draw_wfa_equity_contact_panel(item)
          }
        }
        if (panel_count < rows_n * cols) {
          for (i in seq_len(rows_n * cols - panel_count)) {
            graphics::plot.new()
          }
        }
        graphics::mtext(if (identical(chart_type, "strategy")) "Adjusted daily price" else "Equity, starting at 1.0", side = 2, outer = TRUE, line = 2.2, col = aesthetic$text)
        graphics::mtext("Session date", side = 1, outer = TRUE, line = 1.6, col = aesthetic$text)
        graphics::mtext(paste("Gen5 WFA", chart_type, "contact sheet", page_no, "of", length(pages)), side = 3, outer = TRUE, line = 1, col = aesthetic$text, font = 2)
      },
      finally = {
        graphics::par(old_par)
        grDevices::dev.off()
      }
    )
    rows[[length(rows) + 1L]] <- data.frame(
      chart_type = chart_type,
      page_no = page_no,
      symbols = paste(vapply(page_items, function(x) x$symbol, character(1L)), collapse = ","),
      panel_count = panel_count,
      path = normalizePath(path, winslash = "/", mustWork = FALSE),
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_write_multi_asset_wfa_batch_report <- function(batch_summary, selected_specs, contact_sheet_index, path, settings) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  printable <- batch_summary
  for (col in c("total_return", "cagr", "max_drawdown", "buy_hold_total_return", "buy_hold_max_drawdown")) {
    printable[[col]] <- g5_batch_fmt_pct(printable[[col]])
  }
  printable$sharpe <- g5_batch_fmt_num(printable$sharpe)
  printable$buy_hold_sharpe <- g5_batch_fmt_num(printable$buy_hold_sharpe)

  spec_print <- selected_specs
  spec_print$train_sharpe <- g5_batch_fmt_num(spec_print$train_sharpe)
  spec_print$train_total_return <- g5_batch_fmt_pct(spec_print$train_total_return)
  contact_print <- contact_sheet_index

  lines <- c(
    "# Multi-Asset WFA Batch Diagnostic",
    "",
    "Proof-of-concept only: each asset is trained, selected, and traded independently. This batch report aggregates outputs only; it does not pool TRAIN data or select a global strategy spec.",
    "",
    "## Run Context",
    "",
    paste0("- Symbols: `", paste(settings$symbols, collapse = ", "), "`"),
    paste0("- As-of timestamp: `", settings$as_of_timestamp, "`"),
    paste0("- WFA analysis window: `", settings$wfa_start_date, " to ", settings$wfa_end_date, "`"),
    paste0("- Train period: `", settings$train_quarters, " quarters`"),
    paste0("- OOS period: `", settings$oos_quarters, " quarter(s)`"),
    paste0("- Fold count: `", settings$fold_count, "`"),
    paste0("- Contact-sheet max facets per image: `", settings$max_facets_per_image, "`"),
    paste0("- Candidate families: `", paste(settings$candidate_families, collapse = ", "), "`"),
    paste0("- Exit stack max-hold sessions: `", paste(settings$max_hold_sessions, collapse = ", "), "`"),
    paste0("- Exit stack stop-loss percentages: `", paste(sprintf("%.1f%%", 100 * as.numeric(settings$stop_loss_pcts)), collapse = ", "), "`"),
    paste0("- Exit stack take-profit percentages: `", paste(sprintf("%.1f%%", 100 * as.numeric(settings$take_profit_pcts)), collapse = ", "), "`"),
    "",
    "## Asset Summary",
    "",
    g5_multi_asset_table_lines(
      printable,
      c("symbol", "total_return", "sharpe", "max_drawdown", "trade_count", "native_exit_count", "exit_stack_exit_count", "buy_hold_total_return", "strategy_chart_png")
    ),
    "",
    "## Fold-Selected Strategy Specs",
    "",
    g5_multi_asset_table_lines(
      spec_print,
      c("symbol", "fold_id", "strategy_family", "model_instance_id", "exit_stack_id", "strategy_spec_id", "train_sharpe", "train_total_return")
    ),
    "",
    "## Contact Sheets",
    "",
    g5_multi_asset_table_lines(
      contact_print,
      c("chart_type", "page_no", "symbols", "path")
    ),
    "",
    "## Audit Notes",
    "",
    "- Each asset contributes its own independent TRAIN folds and selected OOS path.",
    "- Cross-asset rows are summaries of independently generated WFA packets.",
    "- Native exits and exit-stack exits are counted from each selected stitched OOS trade ledger."
  )
  writeLines(lines, con = path, useBytes = TRUE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

as_of_env <- Sys.getenv("GEN5_WFA_BATCH_AS_OF_TIMESTAMP", unset = Sys.getenv("GEN5_AS_OF_TIMESTAMP", unset = ""))
if (!nzchar(as_of_env)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP is required for multi-asset WFA batch.")
}
as_of_timestamp <- as.POSIXct(as_of_env, tz = cfg$calendar$timezone)
if (is.na(as_of_timestamp)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP could not be parsed as a timestamp.")
}

symbols <- g5_standardize_symbol(g5_batch_parse_character_list_env(Sys.getenv("GEN5_WFA_BATCH_SYMBOLS", unset = "AMD,NVDA,TSLA,META,QQQ,SPY"), "GEN5_WFA_BATCH_SYMBOLS"))
if (length(symbols) < 1L) {
  g5_stop("GEN5_WFA_BATCH_SYMBOLS must include at least one symbol.")
}

end_env <- Sys.getenv("GEN5_WFA_BATCH_END_DATE", unset = "")
if (!nzchar(end_env)) {
  g5_stop("GEN5_WFA_BATCH_END_DATE is required.")
}
wfa_end_date <- as.Date(end_env)
if (is.na(wfa_end_date)) {
  g5_stop("GEN5_WFA_BATCH_END_DATE could not be parsed as a date.")
}

train_quarters <- g5_ema_cross_wfa_validate_quarters(suppressWarnings(as.numeric(Sys.getenv("GEN5_WFA_BATCH_TRAIN_QUARTERS", unset = "8"))), "GEN5_WFA_BATCH_TRAIN_QUARTERS")
oos_quarters <- g5_ema_cross_wfa_validate_quarters(suppressWarnings(as.numeric(Sys.getenv("GEN5_WFA_BATCH_OOS_QUARTERS", unset = "1"))), "GEN5_WFA_BATCH_OOS_QUARTERS")
fold_count <- suppressWarnings(as.integer(Sys.getenv("GEN5_WFA_BATCH_FOLD_COUNT", unset = "3")))
if (is.na(fold_count) || fold_count < 1L) {
  g5_stop("GEN5_WFA_BATCH_FOLD_COUNT must be a positive integer.")
}
max_facets_per_image <- suppressWarnings(as.integer(Sys.getenv("GEN5_WFA_BATCH_MAX_FACETS_PER_IMAGE", unset = "6")))
if (is.na(max_facets_per_image) || max_facets_per_image < 1L) {
  g5_stop("GEN5_WFA_BATCH_MAX_FACETS_PER_IMAGE must be a positive integer.")
}

start_env <- Sys.getenv("GEN5_WFA_BATCH_START_DATE", unset = "")
lookback_env <- Sys.getenv("GEN5_WFA_BATCH_LOOKBACK_DAYS", unset = "")
if (nzchar(start_env)) {
  wfa_start_date <- as.Date(start_env)
  if (is.na(wfa_start_date)) {
    g5_stop("GEN5_WFA_BATCH_START_DATE could not be parsed as a date.")
  }
} else if (nzchar(lookback_env)) {
  lookback_days <- suppressWarnings(as.integer(lookback_env))
  if (is.na(lookback_days) || lookback_days < 1L) {
    g5_stop("GEN5_WFA_BATCH_LOOKBACK_DAYS must be a positive integer when supplied.")
  }
  wfa_start_date <- wfa_end_date - lookback_days
} else {
  wfa_start_date <- wfa_end_date - (g5_ema_cross_wfa_quarters_to_days(train_quarters) + fold_count * g5_ema_cross_wfa_quarters_to_days(oos_quarters) + 2L)
}
if (wfa_start_date > wfa_end_date) {
  g5_stop("Multi-asset WFA start date cannot be after end date.")
}

fast_periods <- g5_batch_parse_int_list_env(Sys.getenv("GEN5_WFA_BATCH_FAST_PERIODS", unset = "8,12,20"), "GEN5_WFA_BATCH_FAST_PERIODS")
slow_periods <- g5_batch_parse_int_list_env(Sys.getenv("GEN5_WFA_BATCH_SLOW_PERIODS", unset = "30,50,80,120"), "GEN5_WFA_BATCH_SLOW_PERIODS")
if (!any(outer(fast_periods, slow_periods, FUN = "<"))) {
  g5_stop("Multi-asset WFA EMA grid must include at least one fast_period < slow_period pair.")
}
bb_lookback_periods <- g5_batch_parse_int_list_env(Sys.getenv("GEN5_WFA_BATCH_BB_LOOKBACK_PERIODS", unset = "10,20,30"), "GEN5_WFA_BATCH_BB_LOOKBACK_PERIODS")
bb_sd_multipliers <- g5_batch_parse_num_list_env(Sys.getenv("GEN5_WFA_BATCH_BB_SD_MULTIPLIERS", unset = "1.5,2,2.5"), "GEN5_WFA_BATCH_BB_SD_MULTIPLIERS")
candidate_families <- g5_wfa_candidate_families(g5_batch_parse_character_list_env(Sys.getenv("GEN5_WFA_BATCH_CANDIDATE_FAMILIES", unset = "ema_cross,bollinger_touch"), "GEN5_WFA_BATCH_CANDIDATE_FAMILIES"))
max_hold_sessions <- g5_batch_parse_int_list_env(Sys.getenv("GEN5_WFA_BATCH_MAX_HOLD_SESSIONS", unset = "10,20,40"), "GEN5_WFA_BATCH_MAX_HOLD_SESSIONS")
stop_loss_pcts <- g5_batch_parse_num_list_env(Sys.getenv("GEN5_WFA_BATCH_STOP_LOSS_PCTS", unset = "0.10"), "GEN5_WFA_BATCH_STOP_LOSS_PCTS")
take_profit_pcts <- g5_batch_parse_num_list_env(Sys.getenv("GEN5_WFA_BATCH_TAKE_PROFIT_PCTS", unset = "0.25"), "GEN5_WFA_BATCH_TAKE_PROFIT_PCTS")
refresh <- g5_parse_bool_env(Sys.getenv("GEN5_WFA_BATCH_REFRESH", unset = ""), default = FALSE)

warmup_days <- max(c(slow_periods, bb_lookback_periods)) * 4L
query_start_date <- wfa_start_date - warmup_days
batch_prefix <- g5_multi_asset_wfa_batch_prefix(as_of_timestamp, symbols, wfa_start_date, wfa_end_date, fold_count)
batch_dir <- file.path(repo_root, "runs", "research_workbench", "wfa_pocs", batch_prefix)
dir.create(batch_dir, recursive = TRUE, showWarnings = FALSE)

message("Gen5 multi-asset WFA batch diagnostic")
message("Repository: ", repo_root)
message("Cache root: ", cfg$cache$root)
message("Symbols: ", paste(symbols, collapse = ", "))
message("WFA window: ", as.character(wfa_start_date), " to ", as.character(wfa_end_date))
message("Query window with indicator warmup: ", as.character(query_start_date), " to ", as.character(wfa_end_date))
message("As of: ", as.character(as_of_timestamp))
message("Fold count: ", fold_count)
message("Max facets per contact-sheet image: ", max_facets_per_image)
message("Refresh: ", refresh)
message("Batch output: ", batch_dir)
message("POC only: each asset is trained and selected independently; this report aggregates outputs only.")

summary_rows <- list()
selected_rows <- list()
path_rows <- list()
contact_items <- list()

for (symbol in symbols) {
  message("")
  message("== Running independent WFA for ", symbol, " ==")
  result <- g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = query_start_date,
    end_date = wfa_end_date,
    as_of_timestamp = as_of_timestamp,
    symbols = symbol,
    universe_name = paste0("multi_asset_wfa_batch_", symbol),
    universe_roles = "research_universe",
    refresh = refresh,
    repo_root = repo_root
  )
  g5_require_chartable_symbol(result, symbol = symbol, refresh = refresh)
  symbol_dir <- file.path(batch_dir, symbol)
  dir.create(symbol_dir, recursive = TRUE, showWarnings = FALSE)
  written <- g5_write_ema_cross_wfa_multi_outputs(
    result,
    symbol = symbol,
    output_dir = symbol_dir,
    wfa_start_date = wfa_start_date,
    wfa_end_date = wfa_end_date,
    fast_periods = fast_periods,
    slow_periods = slow_periods,
    bb_lookback_periods = bb_lookback_periods,
    bb_sd_multipliers = bb_sd_multipliers,
    candidate_families = candidate_families,
    max_hold_sessions = max_hold_sessions,
    stop_loss_pcts = stop_loss_pcts,
    take_profit_pcts = take_profit_pcts,
    train_quarters = train_quarters,
    oos_quarters = oos_quarters,
    fold_count = fold_count
  )
  metrics <- written$stitched_metrics[1L, , drop = FALSE]
  summary_rows[[length(summary_rows) + 1L]] <- data.frame(
    symbol = symbol,
    total_return = metrics$total_return[[1L]],
    cagr = metrics$cagr[[1L]],
    sharpe = metrics$sharpe[[1L]],
    max_drawdown = metrics$max_drawdown[[1L]],
    trade_count = metrics$trade_count[[1L]],
    closed_trade_count = metrics$closed_trade_count[[1L]],
    open_trade_count = metrics$open_trade_count[[1L]],
    native_exit_count = metrics$native_exit_count[[1L]],
    exit_stack_exit_count = metrics$exit_stack_exit_count[[1L]],
    buy_hold_total_return = metrics$buy_hold_total_return[[1L]],
    buy_hold_sharpe = metrics$buy_hold_sharpe[[1L]],
    buy_hold_max_drawdown = metrics$buy_hold_max_drawdown[[1L]],
    strategy_chart_png = written$paths$stitched_strategy_chart_png,
    equity_curve_png = written$paths$stitched_equity_curve_png,
    metrics_md = written$paths$stitched_metrics_md,
    stringsAsFactors = FALSE
  )
  selected <- written$selected_models
  selected$symbol <- symbol
  selected_rows[[length(selected_rows) + 1L]] <- selected
  contact_items[[length(contact_items) + 1L]] <- list(
    symbol = symbol,
    folds = written$folds,
    stitched_indicators = written$stitched_indicators,
    stitched_trades = written$stitched_trades,
    stitched_equity_curve = written$stitched_equity_curve
  )
  path_rows[[length(path_rows) + 1L]] <- data.frame(
    symbol = symbol,
    output_dir = normalizePath(symbol_dir, winslash = "/", mustWork = FALSE),
    strategy_chart_png = written$paths$stitched_strategy_chart_png,
    equity_curve_png = written$paths$stitched_equity_curve_png,
    metrics_md = written$paths$stitched_metrics_md,
    selected_models_csv = written$paths$selected_models_csv,
    trades_csv = written$paths$stitched_trades_csv,
    stringsAsFactors = FALSE
  )
  message("  Return: ", g5_batch_fmt_pct(metrics$total_return[[1L]]))
  message("  Sharpe: ", g5_batch_fmt_num(metrics$sharpe[[1L]]))
  message("  Max drawdown: ", g5_batch_fmt_pct(metrics$max_drawdown[[1L]]))
  message("  Native exits: ", metrics$native_exit_count[[1L]], " | Exit-stack exits: ", metrics$exit_stack_exit_count[[1L]])
}

batch_summary <- do.call(rbind, summary_rows)
selected_specs <- do.call(rbind, selected_rows)
path_index <- do.call(rbind, path_rows)

batch_summary <- batch_summary[order(ifelse(is.na(batch_summary$sharpe), -Inf, batch_summary$sharpe), decreasing = TRUE), , drop = FALSE]
selected_specs <- selected_specs[order(selected_specs$symbol, selected_specs$fold_no), , drop = FALSE]
path_index <- path_index[order(path_index$symbol), , drop = FALSE]
rownames(batch_summary) <- NULL
rownames(selected_specs) <- NULL
rownames(path_index) <- NULL

batch_summary_csv <- file.path(batch_dir, paste0(batch_prefix, "_asset_summary.csv"))
selected_specs_csv <- file.path(batch_dir, paste0(batch_prefix, "_selected_specs_by_fold.csv"))
path_index_csv <- file.path(batch_dir, paste0(batch_prefix, "_path_index.csv"))
contact_sheet_index_csv <- file.path(batch_dir, paste0(batch_prefix, "_contact_sheet_index.csv"))
batch_report_md <- file.path(batch_dir, paste0(batch_prefix, "_batch_report.md"))

strategy_contact_sheets <- g5_write_wfa_contact_sheet_pages(contact_items, batch_dir, batch_prefix, chart_type = "strategy", max_facets_per_image = max_facets_per_image)
equity_contact_sheets <- g5_write_wfa_contact_sheet_pages(contact_items, batch_dir, batch_prefix, chart_type = "equity", max_facets_per_image = max_facets_per_image)
contact_sheet_index <- rbind(strategy_contact_sheets, equity_contact_sheets)
rownames(contact_sheet_index) <- NULL

utils::write.csv(batch_summary, batch_summary_csv, row.names = FALSE)
utils::write.csv(selected_specs, selected_specs_csv, row.names = FALSE)
utils::write.csv(path_index, path_index_csv, row.names = FALSE)
utils::write.csv(contact_sheet_index, contact_sheet_index_csv, row.names = FALSE)
g5_write_multi_asset_wfa_batch_report(
  batch_summary,
  selected_specs,
  contact_sheet_index,
  batch_report_md,
  settings = list(
    symbols = symbols,
    as_of_timestamp = as_of_timestamp,
    wfa_start_date = wfa_start_date,
    wfa_end_date = wfa_end_date,
    train_quarters = train_quarters,
    oos_quarters = oos_quarters,
    fold_count = fold_count,
    max_facets_per_image = max_facets_per_image,
    candidate_families = candidate_families,
    max_hold_sessions = max_hold_sessions,
    stop_loss_pcts = stop_loss_pcts,
    take_profit_pcts = take_profit_pcts
  )
)

message("")
message("Batch asset summary:")
print(batch_summary[, c("symbol", "total_return", "sharpe", "max_drawdown", "trade_count", "native_exit_count", "exit_stack_exit_count", "buy_hold_total_return")], row.names = FALSE)
message("")
message("Batch outputs:")
message("  Asset summary CSV: ", normalizePath(batch_summary_csv, winslash = "/", mustWork = FALSE))
message("  Selected specs CSV: ", normalizePath(selected_specs_csv, winslash = "/", mustWork = FALSE))
message("  Path index CSV: ", normalizePath(path_index_csv, winslash = "/", mustWork = FALSE))
message("  Contact sheet index CSV: ", normalizePath(contact_sheet_index_csv, winslash = "/", mustWork = FALSE))
message("  Batch report MD: ", normalizePath(batch_report_md, winslash = "/", mustWork = FALSE))
message("  Contact sheets:")
for (path in contact_sheet_index$path) {
  message("    ", path)
}
