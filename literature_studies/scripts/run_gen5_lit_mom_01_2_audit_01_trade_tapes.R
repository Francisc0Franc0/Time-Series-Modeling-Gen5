script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(
  repo_root,
  "literature_studies", "R",
  "gen5_lit_mom_01_2_audit_01_trade_tapes.R"
))

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
}

percent <- function(x, digits = 1L) {
  ifelse(
    is.finite(as.numeric(x)),
    paste0(formatC(100 * as.numeric(x), digits = digits, format = "f"), "%"),
    "NA"
  )
}

pretty_archetype <- function(x) {
  tools::toTitleCase(tolower(gsub("_", " ", x)))
}

contract <- g5_mom012t_validate_contract(g5_mom012t_contract())
source_packet <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded",
  contract$source_run_id
)
if (!dir.exists(source_packet)) {
  stop("Audit 01 source packet is missing.", call. = FALSE)
}

run_id <- Sys.getenv(
  "GEN5_LIT_MOM_012_AUDIT01_TAPES_RUN_ID",
  unset = "lit_mom_01_2_audit_01_representative_trade_tapes_20260803"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded", run_id
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

asset_summary <- utils::read.csv(
  file.path(source_packet, "audit01_asset_summary.csv"),
  stringsAsFactors = FALSE
)
selected_trades <- utils::read.csv(
  file.path(source_packet, "audit01_selected_trades.csv"),
  stringsAsFactors = FALSE
)
daily_paths <- utils::read.csv(
  file.path(source_packet, "audit01_daily_paths.csv"),
  stringsAsFactors = FALSE
)
environment_trades <- utils::read.csv(
  file.path(source_packet, "audit01_environment_trades.csv"),
  stringsAsFactors = FALSE
)

selected <- g5_mom012t_select_representatives(
  asset_summary,
  environment_trades,
  contract
)

counter_scores <- g5_mom012t_countercyclical_scores(
  environment_trades,
  contract$countercyclical_minimum_trades_per_state
)
selected <- merge(selected, counter_scores, by = "symbol", all.x = TRUE, sort = FALSE)
selected <- selected[order(selected$archetype_order), , drop = FALSE]

trade_states <- unique(environment_trades[c("symbol", "trade_id", "market_trend")])
selected_trades <- merge(
  selected_trades,
  trade_states,
  by = c("symbol", "trade_id"),
  all.x = TRUE,
  sort = FALSE
)

plot_trade_tape <- function(row, file_path) {
  symbol <- row$symbol[[1L]]
  tape <- g5_mom012t_tape_series(daily_paths, selected_trades, symbol, contract)
  daily <- tape$daily
  trades <- tape$trades
  outcome_colors <- ifelse(trades$trade_return > 0, "#2F855A", "#C53030")
  state_colors <- ifelse(trades$market_trend == "NON_POSITIVE", "#D69E2E", "#2B6CB0")

  png(file_path, width = 1800, height = 1000, res = 150)
  layout(matrix(1:3, ncol = 1L), heights = c(2.8, 1.4, 2.0))
  par(oma = c(1.2, 0.5, 5.2, 0.5))

  par(mar = c(1.5, 5, 2.2, 2))
  wealth_range <- range(c(daily$strategy_wealth, daily$buy_hold_wealth), finite = TRUE)
  plot(
    daily$outcome_date,
    daily$buy_hold_wealth,
    type = "n",
    ylim = wealth_range,
    xlab = "",
    ylab = "Normalized wealth",
    main = "Complete retrospective path and executed holding blocks",
    xaxt = "n"
  )
  usr <- par("usr")
  rect(
    as.numeric(trades$entry_date),
    usr[[3L]],
    as.numeric(trades$exit_date),
    usr[[4L]],
    col = grDevices::adjustcolor(outcome_colors, alpha.f = 0.07),
    border = NA
  )
  lines(daily$outcome_date, daily$buy_hold_wealth, col = "#718096", lwd = 2)
  lines(daily$outcome_date, daily$strategy_wealth, col = "#2B6CB0", lwd = 3)
  grid(col = "#EDF2F7")
  legend(
    "topleft",
    legend = c("Selected policy", "Buy-and-hold", "Profitable hold", "Losing hold"),
    col = c("#2B6CB0", "#718096", "#2F855A", "#C53030"),
    lwd = c(3, 2, 8, 8),
    bty = "n",
    ncol = 2,
    cex = 0.85
  )

  par(mar = c(1.5, 5, 2.2, 2))
  drawdown_range <- range(
    100 * c(daily$strategy_drawdown, daily$buy_hold_drawdown),
    finite = TRUE
  )
  plot(
    daily$outcome_date,
    100 * daily$buy_hold_drawdown,
    type = "l",
    col = "#A0AEC0",
    lwd = 2,
    ylim = drawdown_range,
    xlab = "",
    ylab = "Drawdown (%)",
    main = "Path risk",
    xaxt = "n"
  )
  lines(
    daily$outcome_date,
    100 * daily$strategy_drawdown,
    col = "#2B6CB0",
    lwd = 2.5
  )
  abline(h = 0, col = "#4A5568")
  grid(col = "#EDF2F7")

  par(mar = c(4.5, 5, 2.2, 2))
  trade_values <- 100 * trades$trade_return
  trade_range <- range(c(0, trade_values), finite = TRUE)
  padding <- max(0.5, diff(trade_range) * 0.12)
  plot(
    trades$exit_date,
    trade_values,
    type = "n",
    ylim = trade_range + c(-padding, padding),
    xlab = "Exit date",
    ylab = "Trade return (%)",
    main = "Trade outcomes through time; point fill is SPY trend at signal"
  )
  segments(
    as.numeric(trades$entry_date),
    0,
    as.numeric(trades$exit_date),
    0,
    col = grDevices::adjustcolor(outcome_colors, alpha.f = 0.45),
    lwd = 4
  )
  segments(
    as.numeric(trades$exit_date),
    0,
    as.numeric(trades$exit_date),
    trade_values,
    col = outcome_colors,
    lwd = 1.5
  )
  points(
    trades$exit_date,
    trade_values,
    pch = 21,
    bg = state_colors,
    col = outcome_colors,
    lwd = 1.4,
    cex = 1.15
  )
  abline(h = 0, col = "#1A202C")
  grid(col = "#EDF2F7")
  legend(
    "bottomleft",
    legend = c("Signal: market up", "Signal: market down/flat"),
    pt.bg = c("#2B6CB0", "#D69E2E"),
    col = "#4A5568",
    pch = 21,
    bty = "n",
    ncol = 2,
    cex = 0.8
  )

  title_line <- paste0(
    pretty_archetype(row$archetype_id[[1L]]), " | ", symbol,
    " | ", row$cohort[[1L]], " | ", row$sector[[1L]]
  )
  metric_line <- paste0(
    "L/H ", row$lookback_sessions[[1L]], "/", row$holding_sessions[[1L]],
    "  |  trades ", row$selected_trade_count[[1L]],
    "  |  exposure ", percent(row$calendar_participation[[1L]]),
    "  |  strategy ", percent(row$selected_return[[1L]]),
    "  |  buy-hold ", percent(row$buy_hold_return[[1L]]),
    "  |  excess vs constant ", percent(row$excess_vs_constant_exposure[[1L]]),
    "  |  random pct ", percent(row$observed_random_percentile[[1L]], 0L),
    "  |  MDD ", percent(row$selected_maximum_drawdown[[1L]]),
    "  |  beta ", formatC(row$spy_beta[[1L]], digits = 2, format = "f"),
    "  |  alpha ", percent(row$annualized_alpha[[1L]])
  )
  mtext(title_line, outer = TRUE, side = 3, line = 3.1, cex = 1.45, font = 2)
  mtext(metric_line, outer = TRUE, side = 3, line = 1.5, cex = 0.82)
  mtext(
    "Outcome-aware descriptive example; not selection or filter evidence",
    outer = TRUE,
    side = 3,
    line = 0.2,
    cex = 0.72,
    col = "#718096"
  )
  dev.off()
}

visual_paths <- character(nrow(selected))
for (i in seq_len(nrow(selected))) {
  stem <- paste0(
    "trade_tape_",
    sprintf("%02d", selected$archetype_order[[i]]),
    "_",
    tolower(selected$archetype_id[[i]]),
    "_",
    tolower(selected$symbol[[i]]),
    ".png"
  )
  visual_paths[[i]] <- file.path(visual_dir, stem)
  plot_trade_tape(selected[i, , drop = FALSE], visual_paths[[i]])
}
selected$visual_path <- normalizePath(visual_paths, winslash = "/", mustWork = FALSE)

png(file.path(visual_dir, "trade_tape_archetype_matrix.png"), 1800, 1100, res = 150)
par(mfrow = c(1, 4), mar = c(5, 1, 4, 1), oma = c(1, 15, 3, 1))
matrix_metrics <- list(
  "Strategy return (%)" = 100 * selected$selected_return,
  "Excess vs buy-hold (pp)" = 100 * selected$excess_vs_buy_hold,
  "Random percentile (%)" = 100 * selected$observed_random_percentile,
  "Maximum drawdown (%)" = 100 * selected$selected_maximum_drawdown
)
y <- rev(seq_len(nrow(selected)))
for (j in seq_along(matrix_metrics)) {
  values <- matrix_metrics[[j]]
  x_range <- range(c(0, values), finite = TRUE)
  padding <- max(1, diff(x_range) * 0.12)
  plot(
    values,
    y,
    pch = 19,
    col = ifelse(values >= 0, "#2F855A", "#C53030"),
    xlim = x_range + c(-padding, padding),
    yaxt = "n",
    ylab = "",
    xlab = "",
    main = names(matrix_metrics)[[j]]
  )
  abline(v = 0, lty = 2, col = "#718096")
  grid(col = "#EDF2F7")
  if (j == 1L) {
    axis(
      2,
      at = y,
      labels = paste(selected$symbol, pretty_archetype(selected$archetype_id)),
      las = 1,
      tick = FALSE,
      cex.axis = 0.72
    )
  }
}
mtext("Frozen representative trade-tape sample", outer = TRUE, side = 3, line = 1, cex = 1.45, font = 2)
mtext("Outcome-aware descriptive archetypes; not a frequency estimate", outer = TRUE, side = 1, line = 0, cex = 0.78, col = "#718096")
dev.off()

contract_rows <- data.frame(
  field = names(contract),
  value = vapply(contract, function(x) paste(as.character(x), collapse = ","), character(1)),
  stringsAsFactors = FALSE
)
run_spec <- data.frame(
  review_id = contract$review_id,
  evidence_label = contract$evidence_label,
  source_run_id = contract$source_run_id,
  retrospective_window = paste(contract$retrospective_start, contract$retrospective_end, sep = " to "),
  representative_count = nrow(selected),
  unique_symbol_count = length(unique(selected$symbol)),
  confirmation_excluded = max(as.Date(daily_paths$outcome_date)) < contract$confirmation_start,
  stringsAsFactors = FALSE
)

write_csv(contract_rows, file.path(output_dir, "trade_tape_frozen_contract.csv"))
write_csv(run_spec, file.path(output_dir, "trade_tape_run_spec.csv"))
write_csv(selected, file.path(output_dir, "trade_tape_selection_manifest.csv"))

report_lines <- c(
  "# LIT-MOM-01.2 Audit 01 Representative Trade Tapes",
  "",
  "Status: `RETROSPECTIVE_DESCRIPTIVE_TRADE_TAPE_REVIEW_COMPLETE`.",
  "",
  "The sample is outcome-aware and was selected under the frozen eight-archetype",
  "contract. It is a visual-audit surface, not an incidence estimate or filter",
  "screen.",
  "",
  "## Selected archetypes",
  "",
  vapply(seq_len(nrow(selected)), function(i) {
    paste0(
      "- `", selected$archetype_id[[i]], "`: `", selected$symbol[[i]], "` — ",
      selected$selection_basis[[i]], "."
    )
  }, character(1)),
  "",
  "## Boundary",
  "",
  "No strategy mechanics changed and no 2024+ confirmation observations were used.",
  "The tapes may generate questions, but the 2/11 attribution STOP remains the",
  "governing strategy conclusion."
)
writeLines(report_lines, file.path(output_dir, "trade_tape_report.md"))

message("Representative trade-tape review complete.")
message("Packet: ", output_dir)
for (i in seq_len(nrow(selected))) {
  message(sprintf("%02d %s -> %s", i, selected$archetype_id[[i]], selected$symbol[[i]]))
}
