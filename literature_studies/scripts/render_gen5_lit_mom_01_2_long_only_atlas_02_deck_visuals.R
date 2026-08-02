options(stringsAsFactors = FALSE)

packet <- file.path(
  "runs", "research_workbench", "literature_grounded",
  "lit_mom_01_2_long_only_stock_atlas_02_2020_breadth_attention_20260802"
)
visual_dir <- file.path(packet, "visuals")
summary <- utils::read.csv(
  file.path(packet, "stock_atlas_02_summary.csv"),
  stringsAsFactors = FALSE
)
registry <- utils::read.csv(
  file.path(packet, "stock_atlas_02_registry.csv"),
  stringsAsFactors = FALSE
)
coverage <- utils::read.csv(
  file.path(packet, "stock_atlas_02_coverage.csv"),
  stringsAsFactors = FALSE
)
replay <- utils::read.csv(
  file.path(packet, "stock_atlas_02_retrospective_bar_replay.csv"),
  stringsAsFactors = FALSE
)
replay$outcome_date <- as.Date(replay$outcome_date)

cohort_label <- function(x) {
  ifelse(x == "DIVERSIFIED_CORE", "Diversified core", "Retail attention")
}

png(
  file.path(visual_dir, "stock_atlas_02_design_and_coverage_deck.png"),
  width = 2100, height = 1050, res = 150
)
old <- par(mfrow = c(1, 3))
cohort_counts <- table(cohort_label(registry$cohort))
par(mar = c(8, 6, 5, 1))
barplot(
  cohort_counts,
  col = c("#2563EB", "#F59E0B"), border = NA, las = 2,
  ylab = "Frozen registry rows", main = "100 names frozen before replay"
)
core <- registry[registry$cohort == "DIVERSIFIED_CORE", , drop = FALSE]
sector_counts <- sort(table(core$sector))
par(mar = c(6, 12, 5, 1))
barplot(
  sector_counts, horiz = TRUE, las = 1,
  col = "#3D8DFF", border = NA,
  xlab = "Core names", main = "All 11 sectors represented",
  cex.names = 0.75
)
coverage_counts <- table(
  cohort_label(coverage$cohort),
  ifelse(coverage$analysis_eligible, "Eligible", "Coverage STOP")
)
par(mar = c(8, 6, 5, 4))
barplot(
  t(coverage_counts), beside = FALSE,
  col = c("#B42318", "#177245"), border = NA, las = 2,
  ylab = "Registry rows", main = "Nine failures remain visible"
)
legend(
  "topright", c("Coverage STOP", "Eligible"),
  fill = c("#B42318", "#177245"), bty = "n", cex = 0.8
)
par(old)
dev.off()

png(
  file.path(visual_dir, "stock_atlas_02_cohort_return_and_accuracy_deck.png"),
  width = 2100, height = 1050, res = 150
)
old <- par(mfrow = c(1, 2), mar = c(7, 7, 5, 2))
cohort_x <- ifelse(summary$cohort == "DIVERSIFIED_CORE", 1, 2)
colors <- ifelse(cohort_x == 1, "#2563EB", "#F59E0B")
set.seed(1201)
plot(
  jitter(cohort_x, amount = 0.12),
  100 * summary$retrospective_primary_return,
  pch = 19, col = colors, xaxt = "n", xlim = c(0.5, 2.5),
  xlab = "Frozen cohort", ylab = "2021-2023 primary return (%)",
  main = "Core breadth transferred better"
)
axis(1, 1:2, c("Diversified core", "Retail attention"))
abline(h = 0, lty = 2, col = "#0F172A")
medians <- tapply(
  summary$retrospective_primary_return,
  summary$cohort,
  stats::median
)
segments(
  c(0.72, 1.72),
  100 * medians[c("DIVERSIFIED_CORE", "RETAIL_ATTENTION_2020")],
  c(1.28, 2.28),
  100 * medians[c("DIVERSIFIED_CORE", "RETAIL_ATTENTION_2020")],
  lwd = 4, col = "#0F172A"
)
plot(
  100 * summary$train_long_accuracy,
  100 * summary$retrospective_long_accuracy,
  pch = 19, col = colors, xlim = c(0, 100), ylim = c(0, 100),
  xlab = "TRAIN long-call accuracy (%)",
  ylab = "Retrospective long-call accuracy (%)",
  main = "Positive-call accuracy was not stable"
)
abline(h = 50, v = 50, lty = 2, col = "#64748B")
legend(
  "bottomleft", c("Diversified core", "Retail attention"),
  pch = 19, col = c("#2563EB", "#F59E0B"), bty = "n", cex = 0.8
)
par(old)
dev.off()

primary <- replay[replay$regime_id == "PRIMARY", , drop = FALSE]
dates <- sort(unique(primary$outcome_date))
symbols <- unique(summary$symbol)
wealth_matrix <- matrix(
  1, nrow = length(dates), ncol = length(symbols),
  dimnames = list(as.character(dates), symbols)
)
for (j in seq_along(symbols)) {
  x <- primary[primary$symbol == symbols[[j]], , drop = FALSE]
  x <- x[order(x$outcome_date), , drop = FALSE]
  indices <- findInterval(dates, x$outcome_date)
  keep <- indices > 0L
  wealth_matrix[keep, j] <- x$wealth[indices[keep]]
}

envelope <- function(cohort) {
  cohort_symbols <- summary$symbol[summary$cohort == cohort]
  values <- wealth_matrix[, cohort_symbols, drop = FALSE]
  data.frame(
    outcome_date = dates,
    q25 = apply(values, 1, stats::quantile, probs = 0.25, na.rm = TRUE),
    median = apply(values, 1, stats::median, na.rm = TRUE),
    q75 = apply(values, 1, stats::quantile, probs = 0.75, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

core_envelope <- envelope("DIVERSIFIED_CORE")
attention_envelope <- envelope("RETAIL_ATTENTION_2020")
png(
  file.path(visual_dir, "stock_atlas_02_cohort_equity_envelopes_deck.png"),
  width = 2000, height = 1050, res = 150
)
old <- par(mfrow = c(1, 2), mar = c(6, 7, 5, 2))
for (spec in list(
  list(x = core_envelope, title = "Diversified core: 74 eligible", color = "#2563EB"),
  list(x = attention_envelope, title = "Retail attention: 17 eligible", color = "#F59E0B")
)) {
  x <- spec$x
  ylim <- range(c(x$q25, x$q75, 1), finite = TRUE)
  plot(
    x$outcome_date, x$median, type = "n", ylim = ylim,
    xlab = "", ylab = "Growth of $1",
    main = spec$title
  )
  polygon(
    c(x$outcome_date, rev(x$outcome_date)),
    c(x$q25, rev(x$q75)),
    col = grDevices::adjustcolor(spec$color, alpha.f = 0.18),
    border = NA
  )
  lines(x$outcome_date, x$median, col = spec$color, lwd = 3)
  abline(h = 1, lty = 2, col = "#64748B")
}
par(old)
dev.off()

message("LIT-MOM-01.2 long-only Atlas02 deck visuals complete: ", visual_dir)
