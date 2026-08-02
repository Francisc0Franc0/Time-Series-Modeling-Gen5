# Run LIT-MOM-01.2 from the frozen LIT-MOM-01.1 historical packet.

source(file.path(
  "literature_studies", "R",
  "gen5_lit_mom_01_1_interday_momentum_poc.R"
))
source(file.path(
  "literature_studies", "R",
  "gen5_lit_mom_01_2_single_position_poc.R"
))

options(stringsAsFactors = FALSE)

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
}

contract_to_frame <- function(contract) {
  data.frame(
    field = names(contract),
    value = vapply(contract, function(x) {
      if (inherits(x, "Date")) return(as.character(x))
      paste(x, collapse = ",")
    }, character(1)),
    stringsAsFactors = FALSE
  )
}

ensure_dir <- function(path) {
  if (!dir.exists(path) && !dir.create(path, recursive = TRUE)) {
    stop("Could not create output directory: ", path, call. = FALSE)
  }
  path
}

read_source_bars <- function(packet) {
  path <- file.path(packet, "lit_mom_01_1_workbench_query_bars.csv")
  if (!file.exists(path)) stop("Frozen source bars are missing: ", path, call. = FALSE)
  bars <- utils::read.csv(path, stringsAsFactors = FALSE)
  bars$session_date <- as.Date(bars$session_date)
  bars$adjusted <- as.logical(bars$adjusted)
  bars
}

period_paths <- function(prefix, output_dir, visual_dir) {
  list(
    inference_summary = file.path(output_dir, paste0(prefix, "_inference_summary.csv")),
    inference_pairs = file.path(output_dir, paste0(prefix, "_inference_pairs.csv")),
    step_l_phases = file.path(output_dir, paste0(prefix, "_step_l_phase_offsets.csv")),
    trades = file.path(output_dir, paste0(prefix, "_trades.csv")),
    replay = file.path(output_dir, paste0(prefix, "_bar_replay.csv")),
    metrics = file.path(output_dir, paste0(prefix, "_performance_metrics.csv")),
    calendar = file.path(output_dir, paste0(prefix, "_calendar_years.csv")),
    direction = file.path(output_dir, paste0(prefix, "_direction_audit.csv")),
    equity_png = file.path(visual_dir, paste0(prefix, "_equity_drawdown.png")),
    trade_tape_png = file.path(visual_dir, paste0(prefix, "_trade_tape.png")),
    representative_png = file.path(visual_dir, paste0(prefix, "_representative_trades.png"))
  )
}

write_period <- function(analysis, paths) {
  pairs <- do.call(rbind, analysis$inference$pairs)
  write_csv(analysis$inference$summary, paths$inference_summary)
  write_csv(pairs, paths$inference_pairs)
  write_csv(analysis$inference$step_l_phase_offsets, paths$step_l_phases)
  write_csv(analysis$trade_results, paths$trades)
  write_csv(analysis$replay, paths$replay)
  write_csv(analysis$metrics, paths$metrics)
  write_csv(analysis$calendar_years, paths$calendar)
  write_csv(analysis$direction_audit, paths$direction)
}

regime_colors <- c(
  GROSS = "#64748B",
  PRIMARY = "#3D8DFF",
  STRESS = "#F59E0B"
)

plot_horizon_and_spacing <- function(result, path) {
  screen <- result$horizon_screen
  selected <- result$selected_candidate
  horizons <- sort(unique(c(screen$lookback_sessions, screen$holding_sessions)))
  values <- matrix(
    NA_real_,
    nrow = length(horizons),
    ncol = length(horizons),
    dimnames = list(horizons, horizons)
  )
  for (i in seq_len(nrow(screen))) {
    values[
      match(screen$holding_sessions[[i]], horizons),
      match(screen$lookback_sessions[[i]], horizons)
    ] <- screen$return_correlation[[i]]
  }
  inference <- result$train$inference$summary
  png(path, width = 2200, height = 1050, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(7, 7, 5, 3))
  max_abs <- max(abs(values), na.rm = TRUE)
  image(
    seq_along(horizons),
    seq_along(horizons),
    values,
    axes = FALSE,
    xlab = "Lookback L (sessions)",
    ylab = "Hold H (sessions)",
    main = "The 49-cell selector remains open—and again chooses 60/5",
    col = grDevices::colorRampPalette(c("#B42318", "#F8FAFC", "#177245"))(101),
    zlim = c(-max_abs, max_abs)
  )
  axis(1, at = seq_along(horizons), labels = horizons)
  axis(2, at = seq_along(horizons), labels = horizons, las = 1)
  points(
    match(selected$lookback_sessions, horizons),
    match(selected$holding_sessions, horizons),
    pch = 0,
    cex = 3.2,
    lwd = 4,
    col = "#3D8DFF"
  )
  labels <- c("Chan\nmin(L,H)", "Distinct\nSTEP_L", "Strict\nL+H")
  accuracy <- 100 * inference$direction_accuracy
  bars <- barplot(
    accuracy,
    names.arg = labels,
    col = c("#3D8DFF", "#8B5CF6", "#0F172A"),
    ylim = c(0, 75),
    ylab = "TRAIN sign consistency (%)",
    main = "Spacing changes support more than the point estimate"
  )
  abline(h = 50, lty = 2, lwd = 2, col = "#475569")
  text(
    bars,
    accuracy + 3,
    paste0(
      sprintf("%.1f%%", accuracy),
      "\nn=", inference$pair_count
    ),
    font = 2
  )
  par(old)
  dev.off()
}

plot_equity_drawdown <- function(analysis, old_packet, old_prefix, path) {
  replay <- analysis$replay
  old_primary <- utils::read.csv(
    file.path(old_packet, paste0(old_prefix, "_bar_replay.csv")),
    stringsAsFactors = FALSE
  )
  old_primary <- old_primary[old_primary$cost_regime == "PRIMARY", , drop = FALSE]
  old_primary$outcome_date <- as.Date(old_primary$outcome_date)
  png(path, width = 2200, height = 1150, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 3))
  primary <- replay[replay$regime_id == "PRIMARY", , drop = FALSE]
  plot(
    range(replay$outcome_date),
    range(c(replay$wealth, old_primary$wealth), na.rm = TRUE),
    type = "n",
    xlab = "",
    ylab = "Growth of $1",
    main = "One full position compounds—but costs still matter"
  )
  for (id in names(regime_colors)) {
    x <- replay[replay$regime_id == id, , drop = FALSE]
    lines(x$outcome_date, x$wealth, col = regime_colors[[id]], lwd = if (id == "PRIMARY") 3 else 2)
  }
  lines(
    old_primary$outcome_date,
    old_primary$wealth,
    col = "#8B5CF6",
    lwd = 2,
    lty = 3
  )
  legend(
    "topleft",
    legend = c("01.2 gross", "01.2 primary", "01.2 stress", "01.1 primary sleeves"),
    col = c(regime_colors, "#8B5CF6"),
    lty = c(1, 1, 1, 3),
    lwd = c(2, 3, 2, 2),
    bty = "n",
    ncol = 2
  )
  plot(
    primary$outcome_date,
    100 * primary$drawdown,
    type = "h",
    lwd = 2,
    col = "#B42318",
    xlab = "",
    ylab = "Drawdown (%)",
    main = "Primary-cost drawdown of the fixed-unit strategy"
  )
  abline(h = 0, col = "#0F172A")
  par(old)
  dev.off()
}

plot_trade_tape <- function(analysis, bars, path) {
  primary <- analysis$replay[analysis$replay$regime_id == "PRIMARY", , drop = FALSE]
  primary <- primary[seq_len(min(90L, nrow(primary))), , drop = FALSE]
  dates <- unique(c(primary$interval_entry_date, tail(primary$outcome_date, 1)))
  shy <- bars[bars$symbol == "SHY" & bars$session_date %in% dates, , drop = FALSE]
  shy <- shy[order(shy$session_date), , drop = FALSE]
  png(path, width = 2200, height = 1100, res = 150)
  old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 3))
  plot(
    shy$session_date,
    100 * shy$open / shy$open[[1L]],
    type = "l",
    lwd = 3,
    col = "#0F172A",
    xlab = "",
    ylab = "SHY open index",
    main = "Each block keeps one direction and one fixed quantity for H sessions"
  )
  boundaries <- unique(primary$trade_entry_date)
  abline(v = boundaries, col = "#CBD5E1", lty = 3)
  plot(
    primary$interval_entry_date,
    primary$effective_exposure,
    type = "s",
    lwd = 3,
    col = "#3D8DFF",
    xlab = "",
    ylab = "Effective exposure",
    main = "No pyramiding: exposure drifts because units are not rebalanced"
  )
  abline(h = c(-1, 0, 1), col = c("#CBD5E1", "#0F172A", "#CBD5E1"))
  abline(v = boundaries, col = "#CBD5E1", lty = 3)
  par(old)
  dev.off()
}

plot_direction_audit <- function(train, retrospective, path) {
  audit <- rbind(train$direction_audit, retrospective$direction_audit)
  labels <- paste(
    ifelse(audit$period_id == "TRAIN", "TRAIN", "RETRO"),
    audit$direction,
    sep = "\n"
  )
  colors <- ifelse(audit$direction == "LONG", "#177245", "#B42318")
  png(path, width = 2200, height = 1050, res = 150)
  old <- par(mfrow = c(1, 2), mar = c(8, 7, 5, 2), oma = c(0, 0, 2, 0))
  accuracy <- 100 * audit$direction_accuracy
  bars <- barplot(
    accuracy,
    names.arg = labels,
    col = colors,
    ylim = c(0, 75),
    ylab = "Direction accuracy (%)",
    main = "Did the H-session move match the call?"
  )
  abline(h = 50, lty = 2, lwd = 2, col = "#0F172A")
  text(
    bars,
    accuracy + 3,
    paste0(sprintf("%.1f%%", accuracy), "\nn=", audit$trade_count),
    font = 2
  )
  returns <- 100 * audit$mean_primary_trade_return
  bars <- barplot(
    returns,
    names.arg = labels,
    col = colors,
    ylim = range(c(-1, 1, returns * 1.25)),
    ylab = "Mean primary trade return (%)",
    main = "Was the call profitable after ordinary costs?"
  )
  abline(h = 0, lwd = 2, col = "#0F172A")
  text(
    bars,
    returns,
    sprintf("%+.3f%%", returns),
    pos = ifelse(returns >= 0, 3, 1),
    font = 2
  )
  mtext(
    "LIT-MOM-01.2 | non-overlapping full-capital trades",
    side = 3,
    outer = TRUE,
    font = 2,
    line = 0.2
  )
  par(old)
  dev.off()
}

plot_representative_trades <- function(analysis, bars, path) {
  primary <- analysis$trade_results[
    analysis$trade_results$regime_id == "PRIMARY",
    ,
    drop = FALSE
  ]
  ordered <- primary[order(primary$trade_return), , drop = FALSE]
  indices <- unique(round(seq(1, nrow(ordered), length.out = min(6L, nrow(ordered)))))
  chosen <- ordered[indices, , drop = FALSE]
  shy <- bars[bars$symbol == "SHY", , drop = FALSE]
  shy <- shy[order(shy$session_date), , drop = FALSE]
  png(path, width = 2300, height = 1450, res = 150)
  old <- par(mfrow = c(2, 3), mar = c(6, 5, 4, 2))
  for (i in seq_len(6L)) {
    if (i > nrow(chosen)) {
      plot.new()
      next
    }
    trade <- chosen[i, , drop = FALSE]
    lo <- max(1L, trade$entry_index - 3L)
    hi <- min(nrow(shy), trade$exit_index + 3L)
    part <- shy[lo:hi, , drop = FALSE]
    index <- 100 * part$open / trade$entry_open
    plot(
      part$session_date,
      index,
      type = "l",
      lwd = 3,
      col = "#0F172A",
      xlab = "",
      ylab = "Open index",
      main = paste0(
        trade$direction_label, " ", trade$entry_date, "\n",
        "primary ", sprintf("%+.3f%%", 100 * trade$trade_return)
      )
    )
    abline(h = 100, col = "#CBD5E1")
    abline(v = c(trade$entry_date, trade$exit_date), col = c("#3D8DFF", "#F59E0B"), lty = 2)
  }
  par(old)
  dev.off()
}

build_variant_comparison <- function(result, old_packet) {
  old <- utils::read.csv(
    file.path(old_packet, "development_performance_metrics.csv"),
    stringsAsFactors = FALSE
  )
  old <- data.frame(
    variant = "LIT-MOM-01.1 rolling sleeves",
    regime_id = old$strategy_id,
    cumulative_return = old$cumulative_return,
    maximum_drawdown = old$maximum_drawdown,
    annualized_volatility = old$annualized_volatility,
    sharpe = old$autocorrelation_adjusted_sharpe,
    trade_or_sleeve_count = c(
      nrow(utils::read.csv(file.path(old_packet, "development_completed_sleeves.csv"))),
      nrow(utils::read.csv(file.path(old_packet, "development_completed_sleeves.csv"))),
      nrow(utils::read.csv(file.path(old_packet, "development_completed_sleeves.csv")))
    ),
    stringsAsFactors = FALSE
  )
  current <- result$retrospective$metrics
  current <- data.frame(
    variant = "LIT-MOM-01.2 single position",
    regime_id = current$regime_id,
    cumulative_return = current$cumulative_return,
    maximum_drawdown = current$maximum_drawdown,
    annualized_volatility = current$annualized_volatility,
    sharpe = current$naive_sharpe,
    trade_or_sleeve_count = current$trade_count,
    stringsAsFactors = FALSE
  )
  rbind(old, current)
}

plot_variant_comparison <- function(comparison, path) {
  primary <- comparison[comparison$regime_id == "PRIMARY", , drop = FALSE]
  stress <- comparison[comparison$regime_id == "STRESS", , drop = FALSE]
  labels <- c("01.1\nrolling sleeves", "01.2\nsingle position")
  png(path, width = 2200, height = 1050, res = 150)
  old <- par(mfrow = c(1, 3), mar = c(8, 7, 5, 2))
  values <- 100 * rbind(primary$cumulative_return, stress$cumulative_return)
  bars <- barplot(
    values,
    beside = TRUE,
    names.arg = labels,
    col = c("#3D8DFF", "#F59E0B"),
    ylab = "Cumulative return (%)",
    main = "Same signal, different capital deployment"
  )
  abline(h = 0, col = "#0F172A")
  legend("topright", legend = c("Primary", "Stress"), fill = c("#3D8DFF", "#F59E0B"), bty = "n")
  bars <- barplot(
    100 * primary$maximum_drawdown,
    names.arg = labels,
    col = "#B42318",
    ylab = "Maximum drawdown (%)",
    main = "Full allocation concentrates path risk"
  )
  abline(h = 0, col = "#0F172A")
  bars <- barplot(
    primary$trade_or_sleeve_count,
    names.arg = labels,
    col = c("#8B5CF6", "#177245"),
    ylab = "Completed decisions",
    main = "Block trades use fewer distinct bets"
  )
  text(bars, primary$trade_or_sleeve_count, primary$trade_or_sleeve_count, pos = 3, font = 2)
  par(old)
  dev.off()
}

write_report <- function(path, result, comparison, output_dir) {
  selected <- result$selected_candidate
  train_primary <- result$train$metrics[
    result$train$metrics$regime_id == "PRIMARY",
    ,
    drop = FALSE
  ]
  retro_primary <- result$retrospective$metrics[
    result$retrospective$metrics$regime_id == "PRIMARY",
    ,
    drop = FALSE
  ]
  retro_stress <- result$retrospective$metrics[
    result$retrospective$metrics$regime_id == "STRESS",
    ,
    drop = FALSE
  ]
  retro_chan <- result$retrospective$inference$summary[
    result$retrospective$inference$summary$sampling_id == "CHAN_MIN_STEP",
    ,
    drop = FALSE
  ]
  retro_step <- result$retrospective$inference$summary[
    result$retrospective$inference$summary$sampling_id == "STEP_L",
    ,
    drop = FALSE
  ]
  lines <- c(
    "# LIT-MOM-01.2 Single-Position Momentum Retrospective",
    "",
    paste0("Status: `", result$overall_status, "`"),
    "",
    "## Boundary",
    "",
    "This is a retrospective execution experiment on an already inspected",
    "2021-2023 window. It is not fresh OOS confirmation and does not revise",
    "the LIT-MOM-01.1 STOP recommendation.",
    "",
    "## Frozen change",
    "",
    "- Keep the 49-cell TRAIN horizon selector.",
    "- Replace daily 1/H sleeves with one fixed-quantity, fully invested trade.",
    "- Hold exactly H open-to-open intervals with no pyramiding or rebalance.",
    "- Compound the next trade from current equity.",
    "",
    "## Selected horizon",
    "",
    paste0(
      "TRAIN again selected `", selected$lookback_sessions, "/",
      selected$holding_sessions, "` from the open 49-cell grid."
    ),
    "",
    "## TRAIN",
    "",
    paste0("- Completed trades: `", train_primary$trade_count, "`."),
    paste0("- Primary cumulative return: `", sprintf("%+.2f%%", 100 * train_primary$cumulative_return), "`."),
    paste0("- Primary maximum drawdown: `", sprintf("%.2f%%", 100 * train_primary$maximum_drawdown), "`."),
    "",
    "## Retrospective 2021-2023",
    "",
    paste0("- CHAN_MIN_STEP: n=", retro_chan$pair_count, ", r=", sprintf("%.4f", retro_chan$return_correlation), ", accuracy=", sprintf("%.1f%%", 100 * retro_chan$direction_accuracy), "."),
    paste0("- STEP_L: n=", retro_step$pair_count, ", r=", sprintf("%.4f", retro_step$return_correlation), ", accuracy=", sprintf("%.1f%%", 100 * retro_step$direction_accuracy), "."),
    paste0("- Completed trades: `", retro_primary$trade_count, "`."),
    paste0("- Primary cumulative return: `", sprintf("%+.2f%%", 100 * retro_primary$cumulative_return), "`."),
    paste0("- Primary maximum drawdown: `", sprintf("%.2f%%", 100 * retro_primary$maximum_drawdown), "`."),
    paste0("- Stress cumulative return: `", sprintf("%+.2f%%", 100 * retro_stress$cumulative_return), "`."),
    "",
    "## Interpretation",
    "",
    "The mechanical comparison asks whether concentrating the same sign signal",
    "into sequential full-capital blocks changes the observed path. It cannot",
    "establish fresh alpha because the replay window was already known.",
    "",
    "## Packet",
    "",
    paste0("`", output_dir, "`")
  )
  writeLines(lines, path, useBytes = TRUE)
}

message("LIT-MOM-01.2 retrospective starting.")
contract <- g5_mom012_contract()
source_packet <- contract$source_packet
output_dir <- Sys.getenv(
  "GEN5_LIT_MOM_01_2_OUTPUT_DIR",
  unset = file.path(
    "runs", "research_workbench", "literature_grounded",
    "lit_mom_01_2_single_position_retrospective_20260802"
  )
)
visual_dir <- ensure_dir(file.path(output_dir, "visuals"))
ensure_dir(output_dir)

bars <- read_source_bars(source_packet)
result <- g5_mom012_run(bars, contract)

train_paths <- period_paths("train", output_dir, visual_dir)
retro_paths <- period_paths("retrospective", output_dir, visual_dir)
write_period(result$train, train_paths)
write_period(result$retrospective, retro_paths)

write_csv(contract_to_frame(contract), file.path(output_dir, "lit_mom_01_2_frozen_contract.csv"))
write_csv(result$horizon_screen, file.path(output_dir, "lit_mom_01_2_train_horizon_screen.csv"))
write_csv(result$selected_candidate, file.path(output_dir, "lit_mom_01_2_selected_candidate.csv"))
write_csv(result$integrity_audit, file.path(output_dir, "lit_mom_01_2_integrity_audit.csv"))

run_spec <- data.frame(
  schema_version = g5_mom012_schema_version(),
  literature_id = contract$literature_id,
  parent_literature_id = contract$parent_literature_id,
  evidence_label = contract$evidence_label,
  source_packet = source_packet,
  as_of_timestamp = contract$as_of_timestamp,
  selected_lookback_sessions = result$selected_candidate$lookback_sessions,
  selected_holding_sessions = result$selected_candidate$holding_sessions,
  overall_status = result$overall_status,
  stringsAsFactors = FALSE
)
write_csv(run_spec, file.path(output_dir, "lit_mom_01_2_run_spec.csv"))

comparison <- build_variant_comparison(result, source_packet)
write_csv(comparison, file.path(output_dir, "lit_mom_01_2_variant_comparison.csv"))

plot_horizon_and_spacing(
  result,
  file.path(visual_dir, "lit_mom_01_2_horizon_and_spacing.png")
)
plot_equity_drawdown(result$train, source_packet, "train", train_paths$equity_png)
plot_equity_drawdown(result$retrospective, source_packet, "development", retro_paths$equity_png)
plot_trade_tape(result$train, bars, train_paths$trade_tape_png)
plot_trade_tape(result$retrospective, bars, retro_paths$trade_tape_png)
plot_direction_audit(
  result$train,
  result$retrospective,
  file.path(visual_dir, "lit_mom_01_2_direction_audit.png")
)
plot_representative_trades(result$train, bars, train_paths$representative_png)
plot_representative_trades(result$retrospective, bars, retro_paths$representative_png)
plot_variant_comparison(
  comparison,
  file.path(visual_dir, "lit_mom_01_2_variant_comparison.png")
)

write_report(
  file.path(output_dir, "lit_mom_01_2_report.md"),
  result,
  comparison,
  output_dir
)

message("LIT-MOM-01.2 complete: ", result$overall_status)
message("Packet: ", output_dir)
