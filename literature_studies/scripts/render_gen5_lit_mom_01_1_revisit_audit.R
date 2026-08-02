# Render focused teaching/audit visuals from the frozen LIT-MOM-01.1 packet.

parse_named_args <- function(args) {
  out <- list()
  for (arg in args) {
    if (!startsWith(arg, "--") || !grepl("=", arg, fixed = TRUE)) next
    parts <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
    out[[parts[[1L]]]] <- paste(parts[-1L], collapse = "=")
  }
  out
}

stop_audit <- function(message) stop(message, call. = FALSE)

args <- parse_named_args(commandArgs(trailingOnly = TRUE))
packet <- args$packet
if (is.null(packet) || !nzchar(packet)) {
  packet <- file.path(
    "runs", "research_workbench", "literature_grounded",
    "lit_mom_01_1_interday_momentum_20260730_v6"
  )
}
if (!dir.exists(packet)) stop_audit(paste("Packet does not exist:", packet))

visual_dir <- file.path(packet, "visuals")
if (!dir.exists(visual_dir) && !dir.create(visual_dir, recursive = TRUE)) {
  stop_audit(paste("Could not create visual directory:", visual_dir))
}

read_packet_csv <- function(name) {
  path <- file.path(packet, name)
  if (!file.exists(path)) stop_audit(paste("Required packet file is missing:", path))
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

summarize_direction <- function(rows, period) {
  rows$direction_correct <- as.logical(rows$direction_correct)
  groups <- split(rows, rows$direction_label)
  do.call(rbind, lapply(c("LONG", "SHORT"), function(direction) {
    x <- groups[[direction]]
    if (is.null(x) || !nrow(x)) stop_audit(paste("Missing", direction, "rows for", period))
    data.frame(
      period = period,
      direction = direction,
      completed_sleeves = nrow(x),
      direction_accuracy = mean(x$direction_correct),
      mean_gross_return = mean(x$gross_sleeve_return),
      mean_primary_net_return = mean(x$primary_net_sleeve_return),
      mean_stress_net_return = mean(x$stress_net_sleeve_return),
      stringsAsFactors = FALSE
    )
  }))
}

train_sleeves <- read_packet_csv("train_completed_sleeves.csv")
development_sleeves <- read_packet_csv("development_completed_sleeves.csv")
audit <- rbind(
  summarize_direction(train_sleeves, "TRAIN 2017-2020"),
  summarize_direction(development_sleeves, "OOS 2021-2023")
)

audit_csv <- file.path(packet, "lit_mom_01_1_long_short_audit.csv")
utils::write.csv(audit, audit_csv, row.names = FALSE, na = "")

audit_png <- file.path(visual_dir, "lit_mom_01_1_long_short_audit.png")
grDevices::png(audit_png, width = 2200, height = 1100, res = 150)
old_par <- graphics::par(mfrow = c(1, 2), mar = c(8, 7, 5, 2), oma = c(0, 0, 3, 0))
group_labels <- paste(
  ifelse(audit$period == "TRAIN 2017-2020", "TRAIN", "OOS"),
  audit$direction,
  sep = "\n"
)
direction_colors <- ifelse(audit$direction == "LONG", "#177245", "#B42318")
accuracy <- 100 * audit$direction_accuracy
accuracy_bars <- graphics::barplot(
  accuracy,
  names.arg = group_labels,
  col = direction_colors,
  ylim = c(0, 70),
  ylab = "Directional accuracy (%)",
  main = "Prediction: did the subsequent H-session move match the call?",
  las = 1
)
graphics::abline(h = 50, col = "#0F172A", lty = 2, lwd = 2)
graphics::text(
  accuracy_bars,
  accuracy + 2.2,
  paste0(sprintf("%.1f%%", accuracy), "\nn=", audit$completed_sleeves),
  font = 2,
  cex = 0.9
)

return_matrix <- rbind(
  Gross = 10000 * audit$mean_gross_return,
  `Primary net` = 10000 * audit$mean_primary_net_return
)
return_bars <- graphics::barplot(
  return_matrix,
  beside = TRUE,
  names.arg = group_labels,
  col = c("#94A3B8", "#3D8DFF"),
  ylab = "Mean return per completed sleeve (bp)",
  main = "Economics: ordinary costs erased both OOS directions",
  las = 1,
  ylim = c(min(-15, return_matrix - 4), max(10, return_matrix + 4))
)
graphics::abline(h = 0, col = "#0F172A", lwd = 2)
graphics::legend(
  "topright",
  legend = rownames(return_matrix),
  fill = c("#94A3B8", "#3D8DFF"),
  bty = "n"
)
for (i in seq_len(nrow(return_matrix))) {
  for (j in seq_len(ncol(return_matrix))) {
    value <- return_matrix[i, j]
    graphics::text(
      return_bars[i, j],
      value + ifelse(value >= 0, 0.8, -0.8),
      sprintf("%+.1f", value),
      pos = ifelse(value >= 0, 3, 1),
      cex = 0.82,
      font = 2
    )
  }
}
graphics::mtext(
  "LIT-MOM-01.1 selected 60/5 rule | long and short calls audited separately",
  side = 3,
  outer = TRUE,
  line = 0.5,
  font = 2,
  cex = 1.25,
  col = "#0F172A"
)
graphics::par(old_par)
grDevices::dev.off()

development_replay <- read_packet_csv("development_bar_replay.csv")
development_replay <- development_replay[
  development_replay$cost_regime == "PRIMARY",
  ,
  drop = FALSE
]
development_replay$entry_date <- as.Date(development_replay$entry_date)
development_sleeves$entry_date <- as.Date(development_sleeves$entry_date)

# The first 16 causal entry sessions are used deterministically. This period
# contains an early sign reversal and makes the cohort aging mechanics visible
# without selecting a window on P&L.
mechanics <- development_replay[seq_len(min(16L, nrow(development_replay))), , drop = FALSE]
entry_sign <- setNames(
  development_sleeves$direction,
  as.character(development_sleeves$entry_date)
)
mechanics$new_signal <- as.numeric(entry_sign[as.character(mechanics$entry_date)])
mechanics$new_signal[!is.finite(mechanics$new_signal)] <- 0

mechanics_csv <- file.path(packet, "lit_mom_01_1_rolling_cohort_mechanics.csv")
utils::write.csv(
  mechanics[c("entry_date", "new_signal", "position", "long_exposure", "short_exposure")],
  mechanics_csv,
  row.names = FALSE,
  na = ""
)

mechanics_png <- file.path(visual_dir, "lit_mom_01_1_rolling_cohort_mechanics.png")
grDevices::png(mechanics_png, width = 2100, height = 1100, res = 150)
old_par <- graphics::par(
  mfrow = c(2, 1),
  mar = c(1.5, 6, 3.5, 2),
  oma = c(5, 0, 0, 0),
  cex = 1.22
)
x <- seq_len(nrow(mechanics))
graphics::plot(
  x,
  mechanics$new_signal,
  type = "h",
  lwd = 12,
  lend = 1,
  col = ifelse(mechanics$new_signal > 0, "#177245", ifelse(mechanics$new_signal < 0, "#B42318", "#94A3B8")),
  ylim = c(-1.25, 1.25),
  xaxt = "n",
  yaxt = "n",
  xlab = "",
  ylab = "Signal",
  main = "New forecast after each close"
)
graphics::abline(h = 0, col = "#0F172A")
graphics::axis(2, at = c(-1, 0, 1), labels = c("SHORT", "none", "LONG"), las = 1)

graphics::plot(
  x,
  mechanics$position,
  type = "s",
  lwd = 4,
  col = "#3D8DFF",
  ylim = c(-1, 1),
  xaxt = "n",
  xlab = "",
  ylab = "Exposure",
  main = "Net of H active 1/H sleeves"
)
graphics::abline(h = c(-1, 0, 1), col = c("#CBD5E1", "#0F172A", "#CBD5E1"))
graphics::axis(
  1,
  at = x,
  labels = format(mechanics$entry_date, "%b %d"),
  las = 2,
  cex.axis = 0.82
)
graphics::mtext(
  "Actual OOS entry sequence | frozen 60/5 rule | Jan 4–26, 2021",
  side = 1,
  outer = TRUE,
  line = 3.5,
  font = 2,
  cex = 1.05,
  col = "#0F172A"
)
graphics::par(old_par)
grDevices::dev.off()

message("LIT-MOM-01.1 revisit audit complete.")
message("  long/short audit: ", audit_png)
message("  rolling cohorts:  ", mechanics_png)
