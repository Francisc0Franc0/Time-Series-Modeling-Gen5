script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "workbench_chart.R"))

bind_rows_fill <- function(rows) {
  rows <- rows[vapply(rows, function(x) is.data.frame(x) && nrow(x), logical(1L))]
  if (!length(rows)) return(data.frame())
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  filled <- lapply(rows, function(x) {
    missing <- setdiff(cols, names(x))
    for (col in missing) x[[col]] <- NA
    x[, cols, drop = FALSE]
  })
  do.call(rbind, filled)
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

pct_label <- function(x, digits = 1L) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x) | !is.finite(x), "NA", sprintf(paste0("%.", digits, "f%%"), 100 * x))
}

screen_label <- function(id) {
  labels <- c(
    HB_broad_risk_no_vxx = "HB / broad risk",
    HB_archetype_matched_no_vxx = "HB / matched",
    HB_diverse_behavior_no_vxx = "HB / large diverse",
    HB_size_matched_diverse_no_vxx = "HB / size-matched",
    ETF_broad_risk_no_vxx = "ETF / broad risk",
    ETF_archetype_matched_no_vxx = "ETF / matched",
    ETF_diverse_behavior_no_vxx = "ETF / large diverse",
    ETF_size_matched_diverse_no_vxx = "ETF / size-matched"
  )
  out <- unname(labels[as.character(id)])
  ifelse(is.na(out), as.character(id), out)
}

policy_label <- function(id) {
  labels <- c(asset_state_direct_spec = "Direct", pooled_family_asset_variant = "Pooled")
  out <- unname(labels[as.character(id)])
  ifelse(is.na(out), as.character(id), out)
}

window_label <- function(window_id) {
  x <- as.character(window_id)
  x <- sub("_asof_", "\n", x, fixed = TRUE)
  sub("([0-9]{4})([0-9]{2})([0-9]{2})$", "\\1-\\2-\\3", x)
}

delta_colors <- function(values, positive = "#00A88F", negative = "#F15A5A", neutral = "#FFFDF8") {
  values <- suppressWarnings(as.numeric(values))
  max_abs <- max(abs(values), na.rm = TRUE)
  if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
  vapply(values, function(value) {
    if (!is.finite(value) || value == 0) return(neutral)
    grDevices::adjustcolor(if (value > 0) positive else negative, alpha.f = min(0.95, 0.22 + 0.73 * abs(value) / max_abs))
  }, character(1L))
}

equity_from_replay <- function(replay) {
  required <- c("symbol", "session_date", "close", "model_position_after_replay")
  missing <- setdiff(required, names(replay))
  if (length(missing)) g5_stop(paste0("Replay CSV missing required columns: ", paste(missing, collapse = ",")))
  pieces <- split(replay, as.character(replay$symbol))
  rows <- lapply(pieces, function(x) {
    x <- x[order(as.Date(x$session_date)), , drop = FALSE]
    close <- suppressWarnings(as.numeric(x$close))
    ret <- c(0, close[-1L] / close[-length(close)] - 1)
    ret[!is.finite(ret)] <- 0
    pos <- as.character(x$model_position_after_replay) == "LONG"
    pos_lag <- c(FALSE, pos[-length(pos)])
    data.frame(
      symbol = as.character(x$symbol),
      session_date = as.Date(x$session_date),
      strategy_equity = cumprod(1 + ifelse(pos_lag, ret, 0)),
      benchmark_symbol_equity = cumprod(1 + ret),
      stringsAsFactors = FALSE
    )
  })
  symbol_equity <- bind_rows_fill(rows)
  daily_strategy <- stats::aggregate(strategy_equity ~ session_date, data = symbol_equity, FUN = mean)
  daily_benchmark <- stats::aggregate(benchmark_symbol_equity ~ session_date, data = symbol_equity, FUN = mean)
  daily <- merge(daily_strategy, daily_benchmark, by = "session_date", all = TRUE)
  daily <- daily[order(as.Date(daily$session_date)), , drop = FALSE]
  daily
}

write_alpha_heatmap <- function(summary, basket_archetype, path, title) {
  aesthetic <- g5_chart_aesthetic()
  x <- summary[as.character(summary$basket_archetype) == basket_archetype, , drop = FALSE]
  row_ids <- unique(paste(screen_label(x$screen_id), policy_label(x$selection_policy), sep = " / "))
  windows <- unique(as.character(x$window_id))
  values <- matrix(NA_real_, nrow = length(row_ids), ncol = length(windows), dimnames = list(row_ids, windows))
  for (i in seq_len(nrow(x))) {
    r <- paste(screen_label(x$screen_id[[i]]), policy_label(x$selection_policy[[i]]), sep = " / ")
    values[r, as.character(x$window_id[[i]])] <- as.numeric(x$excess_return[[i]])
  }
  colors <- delta_colors(as.vector(values))
  dim(colors) <- dim(values)

  grDevices::png(path, width = 2800L, height = 1150L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mar = c(6.8, 12, 3.8, 2))
  graphics::plot(NA, xlim = c(0.5, ncol(values) + 0.5), ylim = c(0.5, nrow(values) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = title, col.main = aesthetic$text, fg = aesthetic$axis)
  graphics::rect(0.5, 0.5, ncol(values) + 0.5, nrow(values) + 0.5, col = aesthetic$panel_background, border = NA)
  for (r in seq_len(nrow(values))) {
    for (c in seq_len(ncol(values))) {
      graphics::rect(c - 0.5, nrow(values) - r + 0.5, c + 0.5, nrow(values) - r + 1.5, col = colors[r, c], border = aesthetic$grid)
      graphics::text(c, nrow(values) - r + 1, labels = pct_label(values[r, c]), cex = 0.78, col = aesthetic$text)
    }
  }
  graphics::axis(1, at = seq_along(windows), labels = window_label(windows), las = 1, cex.axis = 0.72, col.axis = aesthetic$axis)
  graphics::axis(2, at = rev(seq_along(row_ids)), labels = row_ids, las = 1, cex.axis = 0.68, col.axis = aesthetic$axis)
  graphics::mtext("Strategy replay proxy minus equal-weight buy-and-hold of the same basket. Green beat benchmark; red lagged benchmark.", side = 1, line = 5.7, cex = 0.76, col = aesthetic$text)
  invisible(path)
}

write_scorecard <- function(scorecard, path) {
  aesthetic <- g5_chart_aesthetic()
  scorecard$lane <- paste(screen_label(scorecard$screen_id), policy_label(scorecard$selection_policy), sep = " / ")
  split_rows <- split(scorecard, as.character(scorecard$basket_archetype))
  grDevices::png(path, width = 2800L, height = 1150L, res = 180L)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(bg = aesthetic$background, mfrow = c(1, 2), mar = c(5, 12, 3.2, 2), oma = c(0, 0, 2.4, 0))
  colors <- c(asset_state_direct_spec = "#2E86AB", pooled_family_asset_variant = "#9B5DE5")
  for (basket in names(split_rows)) {
    x <- split_rows[[basket]]
    x <- x[order(as.numeric(x$mean_excess_return), decreasing = FALSE), , drop = FALSE]
    values <- as.numeric(x$mean_excess_return) * 100
    bar_cols <- colors[as.character(x$selection_policy)]
    xlim <- range(c(values, 0), na.rm = TRUE)
    pad <- diff(xlim) * 0.15
    if (!is.finite(pad) || pad == 0) pad <- 2
    bp <- graphics::barplot(
      values,
      names.arg = x$lane,
      horiz = TRUE,
      las = 1,
      cex.names = 0.67,
      col = bar_cols,
      border = NA,
      xlim = xlim + c(-pad, pad),
      xlab = "Mean excess return, percentage points",
      main = if (basket == "long_history_high_beta_growth") "High-beta basket" else "ETF/sector basket",
      col.axis = aesthetic$axis,
      col.lab = aesthetic$text,
      col.main = aesthetic$text
    )
    graphics::abline(v = 0, col = aesthetic$axis, lty = 2)
    graphics::grid(nx = NULL, ny = NA, col = aesthetic$grid)
    label_x <- values * 0.52
    labels <- sprintf("%.1f pp, %s/%s beat", values, x$beat_windows, x$windows)
    graphics::text(label_x, bp, labels = labels, adj = 0.5, cex = 0.7, col = "white")
  }
  graphics::mtext("Alpha Scorecard vs Equal-Weight Basket Hold   |   Blue = direct, purple = pooled-family", side = 3, outer = TRUE, line = 1, font = 2, col = aesthetic$text)
  invisible(path)
}

run_root <- normalizePath(file.path(repo_root, "runs", "research_workbench", "selpol_context", "selpol_context_20260703"), winslash = "/", mustWork = TRUE)
output_dir <- file.path(run_root, "benchmark_visuals")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

packet_index <- utils::read.csv(file.path(run_root, "selection_policy_context_philosophy_packet_index.csv"), stringsAsFactors = FALSE)

daily_rows <- list()
summary_rows <- list()
for (i in seq_len(nrow(packet_index))) {
  replay <- utils::read.csv(packet_index$replay_csv[[i]], stringsAsFactors = FALSE)
  daily <- equity_from_replay(replay)
  if (!nrow(daily)) next
  daily$screen_id <- as.character(packet_index$screen_id[[i]])
  daily$basket_archetype <- as.character(packet_index$basket_archetype[[i]])
  daily$context_philosophy <- as.character(packet_index$context_philosophy[[i]])
  daily$window_id <- as.character(packet_index$window_id[[i]])
  daily$selection_policy <- as.character(packet_index$selection_policy[[i]])
  daily$excess_equity <- as.numeric(daily$strategy_equity) - as.numeric(daily$benchmark_symbol_equity)
  daily_rows[[length(daily_rows) + 1L]] <- daily
  tail_row <- daily[nrow(daily), , drop = FALSE]
  summary_rows[[length(summary_rows) + 1L]] <- data.frame(
    screen_id = as.character(packet_index$screen_id[[i]]),
    basket_archetype = as.character(packet_index$basket_archetype[[i]]),
    context_philosophy = as.character(packet_index$context_philosophy[[i]]),
    window_id = as.character(packet_index$window_id[[i]]),
    selection_policy = as.character(packet_index$selection_policy[[i]]),
    start_date = min(as.Date(daily$session_date), na.rm = TRUE),
    end_date = max(as.Date(daily$session_date), na.rm = TRUE),
    session_count = nrow(daily),
    strategy_return = as.numeric(tail_row$strategy_equity[[1L]]) - 1,
    benchmark_return = as.numeric(tail_row$benchmark_symbol_equity[[1L]]) - 1,
    excess_return = as.numeric(tail_row$excess_equity[[1L]]),
    beat_benchmark = as.numeric(tail_row$excess_equity[[1L]]) > 0,
    stringsAsFactors = FALSE
  )
}

daily_equity <- bind_rows_fill(daily_rows)
benchmark_summary <- bind_rows_fill(summary_rows)
scorecard <- do.call(rbind, lapply(split(benchmark_summary, paste(benchmark_summary$screen_id, benchmark_summary$selection_policy, sep = "::")), function(x) {
  data.frame(
    screen_id = as.character(x$screen_id[[1L]]),
    basket_archetype = as.character(x$basket_archetype[[1L]]),
    context_philosophy = as.character(x$context_philosophy[[1L]]),
    selection_policy = as.character(x$selection_policy[[1L]]),
    windows = nrow(x),
    beat_windows = sum(as.logical(x$beat_benchmark), na.rm = TRUE),
    mean_strategy_return = mean(as.numeric(x$strategy_return), na.rm = TRUE),
    mean_benchmark_return = mean(as.numeric(x$benchmark_return), na.rm = TRUE),
    mean_excess_return = mean(as.numeric(x$excess_return), na.rm = TRUE),
    worst_excess_return = min(as.numeric(x$excess_return), na.rm = TRUE),
    best_excess_return = max(as.numeric(x$excess_return), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
scorecard <- scorecard[order(as.character(scorecard$basket_archetype), as.character(scorecard$context_philosophy), as.character(scorecard$selection_policy)), , drop = FALSE]

paths <- list(
  daily_equity_csv = file.path(output_dir, "selection_policy_context_benchmark_daily_equity.csv"),
  benchmark_summary_csv = file.path(output_dir, "selection_policy_context_benchmark_summary.csv"),
  scorecard_csv = file.path(output_dir, "selection_policy_context_benchmark_scorecard.csv"),
  high_beta_heatmap_png = file.path(output_dir, "selection_policy_context_alpha_heatmap_high_beta.png"),
  etf_heatmap_png = file.path(output_dir, "selection_policy_context_alpha_heatmap_etf.png"),
  scorecard_png = file.path(output_dir, "selection_policy_context_alpha_scorecard.png"),
  report_md = file.path(output_dir, "selection_policy_context_benchmark_report.md")
)

write_csv(daily_equity, paths$daily_equity_csv)
write_csv(benchmark_summary, paths$benchmark_summary_csv)
write_csv(scorecard, paths$scorecard_csv)
write_alpha_heatmap(benchmark_summary, "long_history_high_beta_growth", paths$high_beta_heatmap_png, "High-Beta Strategy Alpha vs Equal-Weight Basket Hold")
write_alpha_heatmap(benchmark_summary, "etf_sector_tradeable_proxy", paths$etf_heatmap_png, "ETF/Sector Strategy Alpha vs Equal-Weight Basket Hold")
write_scorecard(scorecard, paths$scorecard_png)

scorecard_print <- scorecard
scorecard_print$mean_strategy_return <- pct_label(scorecard_print$mean_strategy_return)
scorecard_print$mean_benchmark_return <- pct_label(scorecard_print$mean_benchmark_return)
scorecard_print$mean_excess_return <- pct_label(scorecard_print$mean_excess_return)
scorecard_print$worst_excess_return <- pct_label(scorecard_print$worst_excess_return)
scorecard_print$best_excess_return <- pct_label(scorecard_print$best_excess_return)

md_table <- function(df, cols) {
  df <- df[, cols, drop = FALSE]
  df[] <- lapply(df, as.character)
  c(
    paste0("| ", paste(cols, collapse = " | "), " |"),
    paste0("| ", paste(rep("---", length(cols)), collapse = " | "), " |"),
    apply(df, 1L, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  )
}

report <- c(
  "# Selection-Policy Context Benchmark Visuals",
  "",
  "## Purpose",
  "",
  "This artifact-only benchmark layer compares each strategy replay proxy against an equal-weight buy-and-hold benchmark built from the same basket symbols and the same replay dates. It does not rerun data pulls, PCA fitting, authority selection, or OOS replay.",
  "",
  "The benchmark is not an allocation decision. It is an alpha-oriented inspection lens: did the selected strategy lane add value beyond simply holding the allowed basket through the same test interval?",
  "",
  "## Artifacts",
  "",
  paste0("- Daily equity CSV: `", normalizePath(paths$daily_equity_csv, winslash = "/", mustWork = FALSE), "`"),
  paste0("- Benchmark summary CSV: `", normalizePath(paths$benchmark_summary_csv, winslash = "/", mustWork = FALSE), "`"),
  paste0("- Scorecard CSV: `", normalizePath(paths$scorecard_csv, winslash = "/", mustWork = FALSE), "`"),
  paste0("- High-beta heatmap: `", normalizePath(paths$high_beta_heatmap_png, winslash = "/", mustWork = FALSE), "`"),
  paste0("- ETF heatmap: `", normalizePath(paths$etf_heatmap_png, winslash = "/", mustWork = FALSE), "`"),
  paste0("- Scorecard chart: `", normalizePath(paths$scorecard_png, winslash = "/", mustWork = FALSE), "`"),
  "",
  "## Scorecard",
  "",
  md_table(scorecard_print, c("screen_id", "selection_policy", "windows", "beat_windows", "mean_strategy_return", "mean_benchmark_return", "mean_excess_return", "worst_excess_return", "best_excess_return")),
  "",
  "## Guardrails",
  "",
  "- Strategy equity is the existing equal-symbol replay proxy derived from model position and close-to-close movement.",
  "- Benchmark equity is equal-weight buy-and-hold of the same replay symbols over the same replay dates.",
  "- Previous-quarter continuity rows remain in the replay interval when the screen used them; this keeps benchmark and strategy on the same observable period.",
  "- This is inspection-only and should not be treated as accepted allocation evidence."
)
writeLines(unlist(report), paths$report_md, useBytes = TRUE)

message("Benchmark visuals complete:")
print(data.frame(paths), row.names = FALSE)
