# Expand the frozen cumulative loss-rebound morphology to a sector-balanced
# 129-instrument atlas using a coarse 20-100-session horizon grid. This is a
# descriptive transport/falsification slice, not a strategy or inference run.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "tsla_signed_er20_direction.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_1_atr_percent.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "own_asset_return_geometry_atlas.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "return_geometry_wide_atlas.R"))
g5_load_local_renviron(repo_root)

cfg <- g5_load_data_layer_config(repo_root)
contract <- rgwa_contract()
registry_path <- file.path(
  repo_root, "operator_hypothesis_lab", "registries", "return_geometry_wide_atlas.csv"
)
registry <- rgwa_validate_registry(utils::read.csv(
  registry_path, stringsAsFactors = FALSE, check.names = FALSE
), contract)
refresh <- identical(
  tolower(Sys.getenv("GEN5_RETURN_GEOMETRY_WIDE_ATLAS_REFRESH", unset = "false")), "true"
)
as_of_timestamp <- as.POSIXct("2026-08-27 17:30:00", tz = cfg$calendar$timezone)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_wide_atlas_20260827"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) rgwa_stop("Could not create output directories.")

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$analysis_end,
  as_of_timestamp = as_of_timestamp,
  symbols = registry$symbol,
  universe_name = "return_geometry_wide_atlas_01",
  universe_roles = paste0("frozen_", tolower(registry$atlas_cohort)),
  refresh = refresh,
  repo_root = repo_root
)
g5_write_workbench_query_artifacts(query, output_dir, "wide_atlas_query")

coverage <- merge(
  registry,
  query$symbol_coverage,
  by = "symbol", all.x = TRUE, sort = FALSE
)
coverage <- coverage[order(coverage$atlas_order), , drop = FALSE]
coverage$observed_first_session <- as.Date(coverage$observed_first_session)
coverage$observed_latest_session <- as.Date(coverage$observed_latest_session)
coverage$analysis_eligible <- !is.na(coverage$is_empty) & !coverage$is_empty &
  coverage$row_count >= contract$minimum_total_sessions &
  !is.na(coverage$observed_latest_session) &
  coverage$observed_latest_session >= contract$analysis_end
coverage$full_frozen_history <- coverage$analysis_eligible &
  !is.na(coverage$observed_first_session) &
  coverage$observed_first_session <= contract$query_start
coverage$coverage_class <- ifelse(
  !coverage$analysis_eligible, "INELIGIBLE",
  ifelse(coverage$full_frozen_history, "FULL_2016_2023", "PARTIAL_HISTORY_ADMITTED")
)
utils::write.csv(coverage, file.path(output_dir, "coverage_ledger.csv"), row.names = FALSE, na = "")
utils::write.csv(registry, file.path(output_dir, "frozen_wide_atlas_registry.csv"), row.names = FALSE)

missing_cache <- coverage$symbol[is.na(coverage$is_empty) | coverage$is_empty]
if (length(missing_cache) && !refresh) {
  rgwa_stop(paste(
    "Coverage gate found uncached symbols; rerun with GEN5_RETURN_GEOMETRY_WIDE_ATLAS_REFRESH=true:",
    paste(missing_cache, collapse = ", ")
  ))
}
ineligible <- coverage$symbol[!coverage$analysis_eligible]
if (length(ineligible)) {
  rgwa_stop(paste("Coverage remains analytically ineligible after query:", paste(ineligible, collapse = ", ")))
}
core_coverage <- coverage[coverage$atlas_cohort == "GICS_CORE", , drop = FALSE]
if (!all(core_coverage$full_frozen_history)) {
  rgwa_stop(paste(
    "Sector-balanced core lacks full frozen history:",
    paste(core_coverage$symbol[!core_coverage$full_frozen_history], collapse = ", ")
  ))
}

message(sprintf(
  "Coverage admitted: %d assets (%d full, %d partial-history).",
  nrow(coverage), sum(coverage$full_frozen_history), sum(!coverage$full_frozen_history)
))

results <- vector("list", nrow(registry))
for (i in seq_len(nrow(registry))) {
  symbol <- registry$symbol[[i]]
  message(sprintf("[%03d/%03d] %s", i, nrow(registry), symbol))
  ledger <- rgwa_build_ledger(query$bars, symbol, contract)
  results[[i]] <- rgwa_measure_asset(ledger, contract)
}
cells <- do.call(rbind, results)
rownames(cells) <- NULL
cells <- merge(
  cells, registry,
  by = "symbol", all.x = TRUE, sort = FALSE
)
cells <- cells[order(cells$atlas_order, cells$condition, cells$state,
                     cells$prior_sessions, cells$forward_sessions), , drop = FALSE]

expected_states <- data.frame(
  condition = c("UNFILTERED", "ER20", "ER20", "ATRP", "ATRP", "ATRP", "SIGNED_ER20", "SIGNED_ER20", "SIGNED_ER20"),
  state = c("ALL", "RED_SIDEWAYS", "GREEN_TRENDING", "LOW", "MEDIUM", "HIGH", "UP_TREND", "SIDEWAYS", "DOWN_TREND"),
  state_order = seq_len(9L),
  state_label = c("All", "ER20 sideways", "ER20 trending", "ATR% low", "ATR% medium", "ATR% high", "Signed ER20 up", "Signed ER20 sideways", "Signed ER20 down"),
  stringsAsFactors = FALSE
)
cells <- merge(cells, expected_states, by = c("condition", "state"), all.x = TRUE, sort = FALSE)
cells <- cells[order(cells$atlas_order, cells$state_order,
                     cells$prior_sessions, cells$forward_sessions), , drop = FALSE]
utils::write.csv(cells, file.path(output_dir, "asset_prior_sign_cells.csv"), row.names = FALSE, na = "")

cohort_summary <- rgwa_summarize_cells(
  cells, c("atlas_cohort", "condition", "state", "state_label", "state_order", "prior_sessions", "forward_sessions")
)
all_asset_summary <- rgwa_summarize_cells(
  transform(cells, atlas_scope = "ALL_129"),
  c("atlas_scope", "condition", "state", "state_label", "state_order", "prior_sessions", "forward_sessions")
)
core_cells <- cells[cells$sector_balance_eligible, , drop = FALSE]
sector_summary <- rgwa_summarize_cells(
  core_cells, c("sector", "condition", "state", "state_label", "state_order", "prior_sessions", "forward_sessions")
)
sector_balanced <- rgwa_sector_balanced_summary(sector_summary)
sector_balanced <- merge(
  sector_balanced, expected_states,
  by = c("condition", "state"), all.x = TRUE, sort = FALSE
)
sector_balanced <- sector_balanced[order(
  sector_balanced$state_order, sector_balanced$prior_sessions, sector_balanced$forward_sessions
), , drop = FALSE]

utils::write.csv(cohort_summary, file.path(output_dir, "cohort_cell_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(all_asset_summary, file.path(output_dir, "equal_asset_cell_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(sector_summary, file.path(output_dir, "core_sector_cell_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(sector_balanced, file.path(output_dir, "equal_sector_cell_summary.csv"), row.names = FALSE, na = "")

diagonal <- cells[cells$prior_sessions == cells$forward_sessions, , drop = FALSE]
diagonal_cohort <- cohort_summary[cohort_summary$prior_sessions == cohort_summary$forward_sessions, , drop = FALSE]
diagonal_all <- all_asset_summary[all_asset_summary$prior_sessions == all_asset_summary$forward_sessions, , drop = FALSE]
diagonal_sector <- sector_summary[sector_summary$prior_sessions == sector_summary$forward_sessions, , drop = FALSE]
diagonal_sector_balanced <- sector_balanced[sector_balanced$prior_sessions == sector_balanced$forward_sessions, , drop = FALSE]
utils::write.csv(diagonal, file.path(output_dir, "asset_horizon_diagonal.csv"), row.names = FALSE, na = "")
utils::write.csv(diagonal_cohort, file.path(output_dir, "cohort_horizon_diagonal.csv"), row.names = FALSE, na = "")
utils::write.csv(diagonal_all, file.path(output_dir, "equal_asset_horizon_diagonal.csv"), row.names = FALSE, na = "")
utils::write.csv(diagonal_sector, file.path(output_dir, "sector_horizon_diagonal.csv"), row.names = FALSE, na = "")
utils::write.csv(diagonal_sector_balanced, file.path(output_dir, "equal_sector_horizon_diagonal.csv"), row.names = FALSE, na = "")

# Exact parity against the original 30-asset atlas at overlapping 20/25 cells.
old_path <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "own_asset_return_geometry_atlas_20260826", "asset_prior_sign_cells.csv"
)
old <- utils::read.csv(old_path, stringsAsFactors = FALSE, check.names = FALSE)
overlap_symbols <- intersect(old$symbol, cells$symbol)
old_overlap <- old[old$symbol %in% overlap_symbols & old$prior_sessions %in% c(20L, 25L) &
                     old$forward_sessions %in% c(20L, 25L), , drop = FALSE]
new_overlap <- cells[cells$symbol %in% overlap_symbols & cells$prior_sessions %in% c(20L, 25L) &
                       cells$forward_sessions %in% c(20L, 25L), , drop = FALSE]
parity_keys <- c("symbol", "condition", "state", "prior_sessions", "forward_sessions")
parity <- merge(
  old_overlap[c(parity_keys, "negative_pearson_correlation", "positive_pearson_correlation")],
  new_overlap[c(parity_keys, "negative_pearson_correlation", "positive_pearson_correlation")],
  by = parity_keys, suffixes = c("_old", "_new"), all = TRUE
)
parity$negative_abs_difference <- abs(parity$negative_pearson_correlation_old - parity$negative_pearson_correlation_new)
parity$positive_abs_difference <- abs(parity$positive_pearson_correlation_old - parity$positive_pearson_correlation_new)
utils::write.csv(parity, file.path(output_dir, "original_atlas_parity.csv"), row.names = FALSE, na = "")
parity_max <- max(c(parity$negative_abs_difference, parity$positive_abs_difference), na.rm = TRUE)

checks <- data.frame(
  check_id = c(
    "registry_exact", "cohort_counts_exact", "core_sector_balance_exact",
    "coverage_all_eligible", "core_full_history", "horizon_grid_exact",
    "state_vocabulary_exact", "cell_rows_exact", "original_atlas_parity",
    "no_post_2023_bars", "adjusted_daily_only", "partial_history_reported"
  ),
  status = c(
    "PASS", "PASS", "PASS",
    if (all(coverage$analysis_eligible)) "PASS" else "FAIL",
    if (all(core_coverage$full_frozen_history)) "PASS" else "FAIL",
    if (identical(sort(unique(cells$prior_sessions)), contract$horizons) &&
        identical(sort(unique(cells$forward_sessions)), contract$horizons)) "PASS" else "FAIL",
    if (identical(sort(unique(cells$state_order)), seq_len(9L))) "PASS" else "FAIL",
    if (nrow(cells) == contract$expected_assets * length(contract$horizons)^2L * 9L) "PASS" else "FAIL",
    if (is.finite(parity_max) && parity_max < 1e-12) "PASS" else "FAIL",
    if (max(as.Date(query$bars$session_date)) <= contract$analysis_end) "PASS" else "FAIL",
    if (all(as.logical(query$bars$adjusted)) && all(query$bars$timeframe == "1D")) "PASS" else "FAIL",
    if (all(coverage$coverage_class[!coverage$full_frozen_history] == "PARTIAL_HISTORY_ADMITTED")) "PASS" else "FAIL"
  ),
  detail = c(
    paste(nrow(registry), "fixed identities"),
    paste(names(table(registry$atlas_cohort)), as.integer(table(registry$atlas_cohort)), collapse = "; "),
    "11 sectors x 8 stocks; only GICS_CORE enters equal-sector summaries",
    paste(sum(coverage$analysis_eligible), "of", nrow(coverage)),
    paste(sum(core_coverage$full_frozen_history), "of", nrow(core_coverage)),
    paste(contract$horizons, collapse = ","),
    paste(expected_states$state_label, collapse = "; "),
    paste(nrow(cells), "of", contract$expected_assets * length(contract$horizons)^2L * 9L),
    format(parity_max, scientific = TRUE),
    as.character(max(as.Date(query$bars$session_date))),
    "Alpaca adjusted 1D bars",
    paste(sum(!coverage$full_frozen_history), "partial-history assets explicitly retained")
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(checks, file.path(output_dir, "wide_atlas_checks.csv"), row.names = FALSE)
if (any(checks$status != "PASS")) rgwa_stop("One or more wide-atlas checks failed.")

write_matrix_heat <- function(data, value_field, title, path, limit = NULL) {
  horizons <- contract$horizons
  matrix_values <- matrix(NA_real_, nrow = length(horizons), ncol = length(horizons),
                          dimnames = list(horizons, horizons))
  for (i in seq_len(nrow(data))) {
    matrix_values[as.character(data$prior_sessions[[i]]), as.character(data$forward_sessions[[i]])] <- data[[value_field]][[i]]
  }
  if (is.null(limit)) limit <- max(abs(matrix_values), na.rm = TRUE)
  display_values <- matrix_values
  display_values[] <- pmax(-limit, pmin(limit, matrix_values))
  grDevices::png(path, width = 1500, height = 1250, res = 170)
  graphics::par(mar = c(5, 5, 4, 2))
  palette <- grDevices::colorRampPalette(c("#8B1E3F", "#F7F3E8", "#0E7490"))(201)
  graphics::image(seq_along(horizons), seq_along(horizons), t(display_values),
                  col = palette, zlim = c(-limit, limit), axes = FALSE,
                  xlab = "Following sessions", ylab = "Prior sessions", main = title)
  graphics::axis(1, at = seq_along(horizons), labels = horizons)
  graphics::axis(2, at = seq_along(horizons), labels = horizons, las = 1)
  for (r in seq_along(horizons)) for (c in seq_along(horizons)) {
    value <- matrix_values[r, c]
    if (is.finite(value)) graphics::text(c, r, sprintf("%+.2f", value), cex = 0.72)
  }
  grDevices::dev.off()
}

for (i in seq_len(nrow(expected_states))) {
  state_row <- expected_states[i, , drop = FALSE]
  x <- sector_balanced[
    sector_balanced$condition == state_row$condition & sector_balanced$state == state_row$state,
    , drop = FALSE
  ]
  filename <- paste0("equal_sector_", tolower(state_row$condition), "_", tolower(state_row$state), "_heatmap.png")
  write_matrix_heat(
    x, "equal_sector_median_negative_pearson",
    paste("Equal-sector loss-branch correlation |", state_row$state_label),
    file.path(visual_dir, filename), limit = 0.40
  )
}

signed_down_sector <- diagonal_sector[
  diagonal_sector$condition == "SIGNED_ER20" & diagonal_sector$state == "DOWN_TREND",
  , drop = FALSE
]
sector_levels <- sort(unique(signed_down_sector$sector))
sector_matrix <- matrix(NA_real_, nrow = length(sector_levels), ncol = length(contract$horizons),
                        dimnames = list(sector_levels, contract$horizons))
for (i in seq_len(nrow(signed_down_sector))) {
  sector_matrix[signed_down_sector$sector[[i]], as.character(signed_down_sector$prior_sessions[[i]])] <-
    signed_down_sector$median_negative_pearson[[i]]
}
grDevices::png(file.path(visual_dir, "signed_down_sector_diagonal.png"), width = 1800, height = 1150, res = 170)
graphics::par(mar = c(5, 15, 4, 2))
palette <- grDevices::colorRampPalette(c("#8B1E3F", "#F7F3E8", "#0E7490"))(201)
sector_display <- sector_matrix
sector_display[] <- pmax(-0.65, pmin(0.65, sector_matrix))
graphics::image(seq_along(contract$horizons), seq_along(sector_levels), t(sector_display),
                col = palette, zlim = c(-0.65, 0.65), axes = FALSE,
                xlab = "Equal prior / following horizon (sessions)", ylab = "", main = "Signed-down loss rebound by GICS sector")
graphics::axis(1, at = seq_along(contract$horizons), labels = contract$horizons)
graphics::axis(2, at = seq_along(sector_levels), labels = sector_levels, las = 1)
for (r in seq_along(sector_levels)) for (c in seq_along(contract$horizons)) {
  value <- sector_matrix[r, c]
  if (is.finite(value)) graphics::text(c, r, sprintf("%+.2f", value), cex = 0.68)
}
grDevices::dev.off()

signed_down_cohort <- diagonal_cohort[
  diagonal_cohort$condition == "SIGNED_ER20" & diagonal_cohort$state == "DOWN_TREND",
  , drop = FALSE
]
cohort_colors <- c(
  GICS_CORE = "#2563EB", ATTENTION_SUPPLEMENT = "#D97706",
  EQUITY_ETF_CONTROL = "#059669", NON_EQUITY_CONTROL = "#7C3AED"
)
grDevices::png(file.path(visual_dir, "signed_down_cohort_diagonal.png"), width = 1700, height = 1050, res = 170)
graphics::par(mar = c(5, 5, 4, 2))
graphics::plot(NA, xlim = range(contract$horizons), ylim = c(-0.65, 0.10),
               xlab = "Equal prior / following horizon (sessions)", ylab = "Median loss-branch Pearson r",
               main = "Signed-down loss rebound across frozen cohorts")
graphics::abline(h = c(0, -0.10), col = c("#64748B", "#CBD5E1"), lty = c(1, 2))
for (cohort in names(cohort_colors)) {
  x <- signed_down_cohort[signed_down_cohort$atlas_cohort == cohort, , drop = FALSE]
  x <- x[order(x$prior_sessions), , drop = FALSE]
  graphics::lines(x$prior_sessions, x$median_negative_pearson, type = "o", lwd = 3,
                  pch = 16, col = cohort_colors[[cohort]])
}
graphics::legend("topright", legend = gsub("_", " ", names(cohort_colors)),
                 col = cohort_colors, lwd = 3, pch = 16, bty = "n")
grDevices::dev.off()

attention <- diagonal[
  diagonal$atlas_cohort == "ATTENTION_SUPPLEMENT" & diagonal$condition == "SIGNED_ER20" &
    diagonal$state == "DOWN_TREND", , drop = FALSE
]
attention_symbols <- registry$symbol[registry$atlas_cohort == "ATTENTION_SUPPLEMENT"]
attention_matrix <- matrix(NA_real_, nrow = length(attention_symbols), ncol = length(contract$horizons),
                           dimnames = list(attention_symbols, contract$horizons))
for (i in seq_len(nrow(attention))) {
  attention_matrix[attention$symbol[[i]], as.character(attention$prior_sessions[[i]])] <-
    attention$negative_pearson_correlation[[i]]
}
grDevices::png(file.path(visual_dir, "signed_down_attention_diagonal.png"), width = 1650, height = 1250, res = 170)
graphics::par(mar = c(5, 7, 4, 2))
attention_display <- attention_matrix
attention_display[] <- pmax(-0.70, pmin(0.70, attention_matrix))
graphics::image(seq_along(contract$horizons), seq_along(attention_symbols), t(attention_display),
                col = palette, zlim = c(-0.70, 0.70), axes = FALSE,
                xlab = "Equal prior / following horizon (sessions)", ylab = "", main = "Attention supplement: signed-down loss branch")
graphics::axis(1, at = seq_along(contract$horizons), labels = contract$horizons)
graphics::axis(2, at = seq_along(attention_symbols), labels = attention_symbols, las = 1)
for (r in seq_along(attention_symbols)) for (c in seq_along(contract$horizons)) {
  value <- attention_matrix[r, c]
  if (is.finite(value)) graphics::text(c, r, sprintf("%+.2f", value), cex = 0.60)
}
grDevices::dev.off()

state_matrix <- matrix(
  NA_real_, nrow = nrow(expected_states), ncol = length(contract$horizons),
  dimnames = list(expected_states$state_label, contract$horizons)
)
for (i in seq_len(nrow(diagonal_sector_balanced))) {
  row <- diagonal_sector_balanced[i, , drop = FALSE]
  state_matrix[row$state_label, as.character(row$prior_sessions)] <-
    row$equal_sector_median_negative_pearson
}
state_display <- state_matrix
state_display[] <- pmax(-0.50, pmin(0.50, state_matrix))
grDevices::png(file.path(visual_dir, "all_states_equal_sector_diagonal.png"), width = 1750, height = 1100, res = 170)
graphics::par(mar = c(5, 11, 4, 2))
graphics::image(seq_along(contract$horizons), seq_len(nrow(expected_states)), t(state_display),
                col = palette, zlim = c(-0.50, 0.50), axes = FALSE,
                xlab = "Equal prior / following horizon (sessions)", ylab = "",
                main = "All frozen filters | equal-sector loss-branch correlation")
graphics::axis(1, at = seq_along(contract$horizons), labels = contract$horizons)
graphics::axis(2, at = seq_len(nrow(expected_states)), labels = expected_states$state_label, las = 1)
for (r in seq_len(nrow(expected_states))) for (c in seq_along(contract$horizons)) {
  value <- state_matrix[r, c]
  graphics::text(c, r, if (is.finite(value)) sprintf("%+.2f", value) else "sparse", cex = 0.66)
}
grDevices::dev.off()

headline <- diagonal_sector_balanced[
  diagonal_sector_balanced$condition == "SIGNED_ER20" & diagonal_sector_balanced$state == "DOWN_TREND",
  , drop = FALSE
]
core_asset <- diagonal_cohort[
  diagonal_cohort$atlas_cohort == "GICS_CORE" & diagonal_cohort$condition == "SIGNED_ER20" &
    diagonal_cohort$state == "DOWN_TREND", , drop = FALSE
]
attention_asset <- diagonal_cohort[
  diagonal_cohort$atlas_cohort == "ATTENTION_SUPPLEMENT" & diagonal_cohort$condition == "SIGNED_ER20" &
    diagonal_cohort$state == "DOWN_TREND", , drop = FALSE
]
headline <- merge(
  headline,
  core_asset[c("prior_sessions", "median_negative_pearson", "negative_asset_fraction", "described_negative_assets")],
  by = "prior_sessions", all.x = TRUE, suffixes = c("", "_core")
)
headline <- merge(
  headline,
  attention_asset[c("prior_sessions", "median_negative_pearson", "negative_asset_fraction", "described_negative_assets")],
  by = "prior_sessions", all.x = TRUE, suffixes = c("_core", "_attention")
)
utils::write.csv(headline, file.path(output_dir, "headline_signed_down_diagonal.csv"), row.names = FALSE, na = "")

run_spec <- data.frame(
  field = c(
    "atlas_id", "provider", "bar_contract", "query_start", "analysis_window", "as_of_timestamp",
    "assets", "core_design", "attention_design", "controls", "horizons", "returns", "filter_states",
    "primary_branch", "primary_aggregation", "secondary_aggregation", "inference", "post_2023_data",
    "selection", "trading_calculation", "gics_definition_source", "gics_methodology_source"
  ),
  value = c(
    contract$atlas_id, "Alpaca SIP", "adjusted daily OHLCV", as.character(contract$query_start),
    paste(contract$analysis_start, contract$analysis_end, sep = " to "),
    format(as_of_timestamp, tz = cfg$calendar$timezone), nrow(registry),
    "88 stocks; 11 GICS sectors; 8 frozen names per sector; current research labels, not point-in-time membership",
    "16 separately labeled attention/meme challengers; never treated as a sector or sector-balanced input",
    "15 equity ETFs plus 10 non-equity proxies", paste(contract$horizons, collapse = ","),
    "cumulative log close-to-close", paste(expected_states$state_label, collapse = "; "),
    "negative-prior branch; positive branch retained as comparator", "equal-sector core summary",
    "equal-asset cohort and all-instrument summaries", "none; descriptive transport only", "sealed",
    "no asset-specific horizon/state selection", "none",
    "https://www.spglobal.com/spdji/en/landing/topic/gics/",
    "https://www.spglobal.com/spdji/en/documents/methodologies/methodology-gics.pdf?force_download=true"
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)

format_line <- function(row) {
  sprintf(
    "- **%d/%d:** equal-sector median `%+.3f`; mean `%+.3f`; negative-sector breadth `%.1f%%`; core median `%+.3f` across `%d` assets; attention median `%+.3f` across `%d` assets.",
    row$prior_sessions, row$prior_sessions,
    row$equal_sector_median_negative_pearson, row$equal_sector_mean_negative_pearson,
    100 * row$negative_sector_fraction,
    row$median_negative_pearson_core, row$described_negative_assets_core,
    row$median_negative_pearson_attention, row$described_negative_assets_attention
  )
}
headline <- headline[order(headline$prior_sessions), , drop = FALSE]
report <- c(
  "# Wide-Atlas Coarse-Horizon Return Geometry (2018-2023)", "",
  "## Question", "",
  "Does the cumulative loss-rebound plateau observed in the frozen 30-asset atlas survive a much wider, sector-balanced atlas through 100 sessions when the complete existing filter vocabulary is retained?", "",
  "## Frozen design", "",
  "- 129 instruments: 88 core stocks (eight in each of 11 GICS sectors), 16 attention/meme challengers, 15 equity ETF controls, and 10 non-equity proxies.",
  "- Coarse prior and following grid: 20, 25, 30, 35, 40, 50, 75, and 100 sessions (64 cells per state).",
  "- Nine state views: unfiltered; ER20 sideways/trending; ATR% low/medium/high; signed-ER20 up/sideways/down.",
  "- Negative-prior branch is primary; the positive-prior branch remains in the artifact as a comparator.",
  "- Equal-sector summaries use only the 88-stock core. Attention names and controls cannot alter the sector-balanced headline.",
  "- The roster is a frozen current research atlas, not point-in-time historical GICS membership. No inference, parameter selection, post-2023 outcomes, or trading calculation is included.", "",
  "## Coverage", "",
  sprintf("- `%d/%d` instruments were admitted; `%d` have full 2016-2023 query coverage and `%d` are explicitly labeled partial-history observations.", sum(coverage$analysis_eligible), nrow(coverage), sum(coverage$full_frozen_history), sum(!coverage$full_frozen_history)),
  sprintf("- The sector-balanced core is full-history for `%d/%d` stocks. Partial histories occur only outside the equal-sector core.", sum(core_coverage$full_frozen_history), nrow(core_coverage)), "",
  "## Signed-down loss-branch diagonal", "",
  unlist(lapply(seq_len(nrow(headline)), function(i) format_line(headline[i, , drop = FALSE]))), "",
  "## Interpretation boundary", "",
  "- A negative correlation within the negative-prior branch describes stronger preceding losses being associated with stronger subsequent cumulative returns. It remains behavior, not an executable edge.",
  "- Overlapping cumulative horizons are nested. Persistence through 100 sessions does not show when rebound return accrues or imply a 100-session holding period.",
  "- Sector breadth weakens a single-name or single-sector explanation. It does not establish causality, independence, temporal transport, or net profitability.",
  "- Current GICS labels are descriptive balancing metadata. They are not point-in-time constituent histories.", "",
  "## Artifacts", "",
  "- `asset_prior_sign_cells.csv`: full 129 x 64 x 9 descriptive sign-branch surface.",
  "- `equal_sector_cell_summary.csv`: primary sector-balanced surface.",
  "- `cohort_cell_summary.csv`, `core_sector_cell_summary.csv`, and diagonal extracts: breadth and heterogeneity views.",
  "- `coverage_ledger.csv`, `wide_atlas_checks.csv`, and `original_atlas_parity.csv`: audit surface.",
  "- `visuals/`: equal-sector state heatmaps plus sector, cohort, and attention views.", "",
  "## STOP / next gate", "",
  "Stop at the descriptive wide-atlas result. Do not choose a best horizon or state from this surface. The next defensible gate, if opened by the operator, is either incremental-forward-block decomposition or a separately frozen temporal transport window."
)
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)

status <- data.frame(
  atlas_id = contract$atlas_id,
  status = "DESCRIPTIVE_WIDE_ATLAS_COMPLETE_STOP_BEFORE_TEMPORAL_OR_INCREMENTAL_GATE",
  checks_passed = sum(checks$status == "PASS"),
  checks_total = nrow(checks),
  assets = nrow(registry),
  core_assets = nrow(core_coverage),
  partial_history_assets = sum(!coverage$full_frozen_history),
  rows = nrow(cells),
  parity_max_abs_difference = parity_max,
  stringsAsFactors = FALSE
)
utils::write.csv(status, file.path(output_dir, "wide_atlas_status.csv"), row.names = FALSE)
message("Wide return-geometry atlas complete: ", normalizePath(output_dir, winslash = "/"))
