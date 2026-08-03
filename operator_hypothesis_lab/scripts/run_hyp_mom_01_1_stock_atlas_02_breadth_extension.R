options(stringsAsFactors = FALSE)

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_01_1_two_green_gap_ups.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_01_1_diagnostic_atlas.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_01_1_stock_atlas_02_breadth.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
env_bool <- function(name, default = FALSE) {
  tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
}
write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}
percent <- function(x, digits = 1L) {
  ifelse(is.finite(as.numeric(x)), paste0(formatC(100 * as.numeric(x), digits = digits, format = "f"), "%"), "NA")
}
rbind_fill <- function(...) {
  items <- list(...)
  columns <- unique(unlist(lapply(items, names), use.names = FALSE))
  items <- lapply(items, function(x) {
    missing <- setdiff(columns, names(x))
    for (field in missing) x[[field]] <- NA
    x[columns]
  })
  do.call(rbind, items)
}
add_identity <- function(x, reg) {
  if (is.null(x) || !nrow(x)) return(x)
  identity <- data.frame(
    instance_id = reg$instance_id,
    symbol = reg$symbol,
    cohort = reg$cohort,
    sector = reg$sector,
    stringsAsFactors = FALSE
  )
  cbind(
    identity[rep(1L, nrow(x)), , drop = FALSE],
    x[, setdiff(names(x), "symbol"), drop = FALSE]
  )
}

parent_contract <- hyp_mom011_validate_contract()
diagnostic_contract <- hyp_mom011_da_validate_contract()
breadth_contract <- hyp_mom011_breadth_validate_contract()

original_registry_path <- file.path(
  repo_root, "operator_hypothesis_lab", "registries", "hyp_mom_01_1_discovery_registry.csv"
)
wide_registry_path <- file.path(repo_root, breadth_contract$source_registry)
original_strategy_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "hyp_mom_01_1_two_green_gap_ups_discovery_20260803"
)
original_diagnostic_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "hyp_mom_01_1_diagnostic_atlas_01_20260803"
)
run_id <- env_or(
  "GEN5_HYP_MOM_011_BREADTH_RUN_ID",
  "hyp_mom_01_1_stock_atlas_02_breadth_extension_20260804"
)
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

original_registry <- utils::read.csv(original_registry_path, stringsAsFactors = FALSE)
hyp_mom011_validate_registry(original_registry)
wide_registry <- utils::read.csv(wide_registry_path, stringsAsFactors = FALSE)
wide_registry <- hyp_mom011_breadth_validate_registry(
  wide_registry, original_registry$symbol, breadth_contract
)

cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_HYP_MOM_011_BREADTH_REFRESH", FALSE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = as.Date("2016-01-04"),
  end_date = parent_contract$discovery_end,
  as_of_timestamp = parent_contract$as_of_timestamp,
  symbols = c(wide_registry$symbol, "SPY"),
  universe_name = "hyp_mom_01_1_stock_atlas_02_breadth_extension",
  universe_roles = "frozen_2020_breadth_attention,spy_context",
  refresh = refresh,
  repo_root = repo_root
)
bars_all <- query$bars
bars_all$session_date <- as.Date(bars_all$session_date)
if (any(bars_all$session_date >= parent_contract$confirmation_start)) {
  stop("Confirmation bars entered breadth extension.", call. = FALSE)
}
if (anyDuplicated(bars_all[c("symbol", "session_date")])) {
  stop("Breadth query contains duplicate symbol/session rows.", call. = FALSE)
}
spy_bars <- bars_all[bars_all$symbol == "SPY", , drop = FALSE]
coverage <- hyp_mom011_breadth_coverage(
  bars_all, wide_registry, spy_bars$session_date, parent_contract, breadth_contract
)
eligible_registry <- wide_registry[
  wide_registry$symbol %in% coverage$symbol[coverage$analysis_eligible],
  , drop = FALSE
]
if (!nrow(eligible_registry)) stop("No Atlas 02 identities passed coverage.", call. = FALSE)

spy_context <- hyp_mom011_da_spy_context(spy_bars, diagnostic_contract, parent_contract)
analysis_cache_path <- file.path(output_dir, "hyp_mom_01_1_breadth_analysis_cache.rds")
reuse_analysis <- env_bool("GEN5_HYP_MOM_011_BREADTH_REUSE_ANALYSIS", TRUE)
if (reuse_analysis && file.exists(analysis_cache_path)) {
  message("Reusing completed per-asset analysis cache: ", analysis_cache_path)
  cached <- readRDS(analysis_cache_path)
  wide_candidates <- cached$wide_candidates
  wide_trades <- cached$wide_trades
  wide_paths <- cached$wide_paths
  wide_random <- cached$wide_random
  wide_asset_summary <- cached$wide_asset_summary
  wide_features_raw <- cached$wide_features_raw
} else {
  candidate_rows <- trade_rows <- path_rows <- random_rows <- summary_rows <- feature_rows <- list()
  message("HYP-MOM-01.1 Stock Atlas 02 starting: ", nrow(eligible_registry), " eligible assets.")
  for (i in seq_len(nrow(eligible_registry))) {
    reg <- eligible_registry[i, , drop = FALSE]
    symbol <- reg$symbol[[1L]]
    message(sprintf("[%03d/%03d] %s", i, nrow(eligible_registry), symbol))
    bars <- bars_all[bars_all$symbol == symbol, , drop = FALSE]
    analysis <- hyp_mom011_analyze_asset(bars, parent_contract, seed_offset = 22000L + i * 1000L)
    candidate_rows[[i]] <- add_identity(analysis$candidates, reg)
    trade_rows[[i]] <- add_identity(analysis$trades, reg)
    path_rows[[i]] <- add_identity(analysis$daily_path, reg)
    random_rows[[i]] <- add_identity(analysis$random_returns, reg)
    summary_rows[[i]] <- add_identity(analysis$summary, reg)
    features <- hyp_mom011_da_asset_features(bars, spy_context, diagnostic_contract, parent_contract)
    feature_rows[[i]] <- add_identity(features, reg)
  }
  wide_candidates <- do.call(rbind, candidate_rows)
  wide_trades <- do.call(rbind, trade_rows)
  wide_paths <- do.call(rbind, path_rows)
  wide_random <- do.call(rbind, random_rows)
  wide_asset_summary <- do.call(rbind, summary_rows)
  wide_features_raw <- do.call(rbind, feature_rows)
  rownames(wide_candidates) <- rownames(wide_trades) <- rownames(wide_paths) <-
    rownames(wide_random) <- rownames(wide_asset_summary) <- rownames(wide_features_raw) <- NULL
  saveRDS(
    list(
      wide_candidates = wide_candidates,
      wide_trades = wide_trades,
      wide_paths = wide_paths,
      wide_random = wide_random,
      wide_asset_summary = wide_asset_summary,
      wide_features_raw = wide_features_raw
    ),
    analysis_cache_path
  )
}

original_asset_summary <- utils::read.csv(
  file.path(original_strategy_dir, "hyp_mom_01_1_asset_summary.csv"),
  stringsAsFactors = FALSE
)
original_trades <- utils::read.csv(
  file.path(original_strategy_dir, "hyp_mom_01_1_executed_trades.csv"),
  stringsAsFactors = FALSE
)
original_features <- utils::read.csv(
  file.path(original_diagnostic_dir, "hyp_mom_01_1_da_executed_trades.csv"),
  stringsAsFactors = FALSE
)
original_asset_summary$cohort <- "ORIGINAL_22"
original_trades$cohort <- "ORIGINAL_22"
original_features$cohort <- "ORIGINAL_22"

combined_asset_summary <- rbind_fill(original_asset_summary, wide_asset_summary)
combined_trades <- rbind_fill(original_trades, wide_trades)
group_columns <- c(
  "gap_strength_tercile", "body_strength_tercile", "gap_body_cell",
  "above_sma200_state", "momentum_20_state", "momentum_60_state",
  "momentum_120_state", "streak_state", "volume_state", "high60_state",
  "spy_sma200_state", "spy_momentum_60_state"
)
original_features_raw <- original_features[setdiff(names(original_features), group_columns)]
wide_features_raw <- wide_features_raw[setdiff(names(wide_features_raw), group_columns)]
combined_features_raw <- rbind_fill(original_features_raw, wide_features_raw)

panel_summary <- rbind(
  hyp_mom011_breadth_panel_summary(original_asset_summary, original_trades, "ORIGINAL_22"),
  hyp_mom011_breadth_panel_summary(wide_asset_summary, wide_trades, "ATLAS_02"),
  hyp_mom011_breadth_panel_summary(combined_asset_summary, combined_trades, "COMBINED")
)
cohort_summary <- hyp_mom011_breadth_cohort_summary(wide_asset_summary, wide_trades)
sector_summary <- do.call(rbind, lapply(sort(unique(wide_asset_summary$sector)), function(sector) {
  assets <- wide_asset_summary[wide_asset_summary$sector == sector, , drop = FALSE]
  trades <- wide_trades[wide_trades$sector == sector, , drop = FALSE]
  cbind(data.frame(sector = sector, stringsAsFactors = FALSE),
        hyp_mom011_breadth_panel_summary(assets, trades, "ATLAS_02")[-1L])
}))

summary_specs <- list(
  c("DA01_PATTERN_GAP", "gap_strength_tercile"),
  c("DA02_PATTERN_BODY", "body_strength_tercile"),
  c("DA03_PATTERN_GRID", "gap_body_cell"),
  c("DA04_SMA200", "anchor_state"),
  c("DA04_SMA200_SIMPLE", "above_sma200_state"),
  c("DA05_MOM20", "momentum_20_state"),
  c("DA06_MOM60", "momentum_60_state"),
  c("DA07_MOM120", "momentum_120_state"),
  c("DA08_STREAK", "streak_state"),
  c("DA09_VOLUME", "volume_state"),
  c("DA10_HIGH60", "high60_state"),
  c("DA11_SPY_SMA200", "spy_sma200_state"),
  c("DA12_SPY_MOM60", "spy_momentum_60_state")
)
contrast_specs <- data.frame(
  diagnostic_id = c(
    "DA01_PATTERN_GAP", "DA02_PATTERN_BODY", "DA04_ESTABLISHED_VS_BELOW",
    "DA04_RECLAIM_VS_BELOW", "DA05_MOM20", "DA06_MOM60", "DA07_MOM120",
    "DA08_STREAK", "DA09_VOLUME", "DA10_HIGH60", "DA11_SPY_SMA200", "DA12_SPY_MOM60"
  ),
  group_column = c(
    "gap_strength_tercile", "body_strength_tercile", "anchor_state", "anchor_state",
    "momentum_20_state", "momentum_60_state", "momentum_120_state", "streak_state",
    "volume_state", "high60_state", "spy_sma200_state", "spy_momentum_60_state"
  ),
  positive_group = c(
    "HIGH", "HIGH", "ESTABLISHED_ABOVE", "RECENT_RECLAIM", rep("POSITIVE", 3L),
    "THREE_OR_MORE", "AT_OR_ABOVE_ONE", "NEAR_HIGH", "ABOVE", "POSITIVE"
  ),
  reference_group = c(
    "LOW", "LOW", "BELOW_ANCHOR", "BELOW_ANCHOR", rep("NONPOSITIVE", 3L),
    "EXACTLY_TWO", "BELOW_ONE", "FAR_BELOW_HIGH", "BELOW", "NONPOSITIVE"
  ),
  stringsAsFactors = FALSE
)
continuous_features <- c(
  "gap_strength_z", "body_strength_z", "minimum_gap_z", "minimum_body_z",
  "second_minus_first_strength", "anchor_distance_z", "momentum_20", "momentum_60",
  "momentum_120", "volume_ratio20", "high60_distance_z"
)

analyze_diagnostics <- function(raw, panel_id, seed_offset) {
  grouped <- hyp_mom011_da_add_groups(raw, diagnostic_contract)
  conditional <- do.call(rbind, lapply(summary_specs, function(spec) {
    hyp_mom011_da_group_summary(grouped, spec[[1L]], spec[[2L]])
  }))
  conditional$panel_id <- panel_id
  contrasts <- do.call(rbind, lapply(seq_len(nrow(contrast_specs)), function(i) {
    spec <- contrast_specs[i, , drop = FALSE]
    hyp_mom011_da_asset_contrast(
      grouped, spec$diagnostic_id, spec$group_column, spec$positive_group,
      spec$reference_group, breadth_contract$bootstrap_draws,
      breadth_contract$bootstrap_seed + seed_offset + i * 100L
    )
  }))
  contrasts$panel_id <- panel_id
  correlations <- hyp_mom011_da_asset_correlations(
    grouped, continuous_features, diagnostic_contract$minimum_asset_correlation_trades
  )
  correlation_summary <- do.call(rbind, lapply(split(correlations, correlations$feature), function(x) {
    data.frame(
      feature = unique(x$feature), asset_count = nrow(x),
      mean_asset_spearman_rho = mean(x$spearman_rho),
      median_asset_spearman_rho = stats::median(x$spearman_rho),
      fraction_asset_rhos_positive = mean(x$spearman_rho > 0),
      minimum_asset_rho = min(x$spearman_rho), maximum_asset_rho = max(x$spearman_rho),
      stringsAsFactors = FALSE
    )
  }))
  correlation_summary$panel_id <- panel_id
  checkpoint_rows <- hyp_mom011_da_checkpoint_rows(grouped, parent_contract$holding_sessions)
  checkpoint_summary <- hyp_mom011_da_checkpoint_summary(checkpoint_rows)
  checkpoint_summary$panel_id <- panel_id
  checkpoint_contrasts <- do.call(rbind, lapply(1:4, function(k) {
    x <- checkpoint_rows[checkpoint_rows$checkpoint == k, , drop = FALSE]
    x$primary_trade_return <- x$remaining_return
    hyp_mom011_da_asset_contrast(
      x,
      paste0("CHECKPOINT_", k), "checkpoint_state", "POSITIVE", "NONPOSITIVE",
      breadth_contract$bootstrap_draws,
      breadth_contract$bootstrap_seed + seed_offset + 5000L + k * 100L
    )
  }))
  checkpoint_contrasts$checkpoint <- 1:4
  checkpoint_contrasts$panel_id <- panel_id
  list(
    grouped = grouped, conditional = conditional, contrasts = contrasts,
    correlations = correlations, correlation_summary = correlation_summary,
    checkpoint_rows = checkpoint_rows, checkpoint_summary = checkpoint_summary,
    checkpoint_contrasts = checkpoint_contrasts
  )
}

original_diag <- analyze_diagnostics(original_features_raw, "ORIGINAL_22", 0L)
wide_diag <- analyze_diagnostics(wide_features_raw, "ATLAS_02", 10000L)
combined_diag <- analyze_diagnostics(combined_features_raw, "COMBINED", 20000L)
diagnostic_conditional <- rbind_fill(original_diag$conditional, wide_diag$conditional, combined_diag$conditional)
diagnostic_contrasts <- rbind_fill(original_diag$contrasts, wide_diag$contrasts, combined_diag$contrasts)
diagnostic_correlations <- rbind_fill(original_diag$correlations, wide_diag$correlations, combined_diag$correlations)
diagnostic_correlation_summary <- rbind_fill(
  original_diag$correlation_summary, wide_diag$correlation_summary, combined_diag$correlation_summary
)
checkpoint_summary <- rbind_fill(
  original_diag$checkpoint_summary, wide_diag$checkpoint_summary, combined_diag$checkpoint_summary
)
checkpoint_contrasts <- rbind_fill(
  original_diag$checkpoint_contrasts, wide_diag$checkpoint_contrasts, combined_diag$checkpoint_contrasts
)

# Frozen tape archetypes.
wide_grouped <- wide_diag$grouped
used <- character()
pick_unique <- function(data, order_index, archetype) {
  candidates <- order_index[!data$trade_id[order_index] %in% used]
  if (!length(candidates)) stop("No unique tape candidate remains.", call. = FALSE)
  row <- data[candidates[[1L]], , drop = FALSE]
  row$tape_archetype <- archetype
  used <<- c(used, row$trade_id)
  row
}
median_order <- order(abs(wide_grouped$primary_trade_return - stats::median(wide_grouped$primary_trade_return)), wide_grouped$trade_id)
tape_rows <- list(
  pick_unique(wide_grouped, median_order, "POOLED_MEDOID_RETURN"),
  pick_unique(wide_grouped, order(-wide_grouped$primary_trade_return, wide_grouped$trade_id), "HIGHEST_PRIMARY_RETURN"),
  pick_unique(wide_grouped, order(wide_grouped$primary_trade_return, wide_grouped$trade_id), "LOWEST_PRIMARY_RETURN")
)
above <- which(wide_grouped$spy_sma200_state == "ABOVE")
below <- which(wide_grouped$spy_sma200_state == "BELOW")
hh <- which(wide_grouped$gap_strength_tercile == "HIGH" & wide_grouped$body_strength_tercile == "HIGH")
tape_rows[[4L]] <- pick_unique(
  wide_grouped, above[order(abs(wide_grouped$primary_trade_return[above] - stats::median(wide_grouped$primary_trade_return[above])), wide_grouped$trade_id[above])],
  "SPY_ABOVE_MEDOID_RETURN"
)
tape_rows[[5L]] <- pick_unique(
  wide_grouped, below[order(abs(wide_grouped$primary_trade_return[below] - stats::median(wide_grouped$primary_trade_return[below])), wide_grouped$trade_id[below])],
  "SPY_BELOW_MEDOID_RETURN"
)
tape_rows[[6L]] <- pick_unique(
  wide_grouped, hh[order(abs(wide_grouped$primary_trade_return[hh] - stats::median(wide_grouped$primary_trade_return[hh])), wide_grouped$trade_id[hh])],
  "HIGH_GAP_HIGH_BODY_MEDOID"
)
tape_manifest <- do.call(rbind, tape_rows)
tape_manifest$tape_order <- seq_len(nrow(tape_manifest))

# Visuals.
blue <- "#2B6CB0"; light_blue <- "#63B3ED"; green <- "#2F855A"
red <- "#C53030"; gray <- "#718096"; dark <- "#1A202C"; pale <- "#EAF5FB"

png(file.path(visual_dir, "breadth_coverage_and_composition.png"), 1800, 1100, res = 150)
par(mfrow = c(1, 2), mar = c(8, 5, 4, 2))
coverage_counts <- table(coverage$coverage_status)
coverage_labels <- c(
  DISCOVERY_INCOMPLETE = "Discovery gap", ELIGIBLE = "Eligible",
  HISTORY_INCOMPLETE = "History gap", INVALID_OHLCV = "Invalid OHLCV"
)[names(coverage_counts)]
barplot(coverage_counts, names.arg = coverage_labels, las = 2,
        col = ifelse(names(coverage_counts) == "ELIGIBLE", green, red),
        ylab = "Registry identities", main = "All 100 frozen identities remain visible")
cohort_counts <- table(wide_registry$cohort, coverage$coverage_status == "ELIGIBLE")
barplot(t(cohort_counts), beside = TRUE, col = c(red, green), las = 2,
        names.arg = c("Diversified core", "2020 attention"),
        ylab = "Identities", main = "Eligibility by frozen source cohort")
legend("topright", c("Not eligible", "Eligible"), fill = c(red, green), bty = "n")
dev.off()

png(file.path(visual_dir, "panel_strategy_comparison.png"), 1800, 1100, res = 150)
par(mfrow = c(1, 2), mar = c(7, 6, 4, 2))
panel_labels <- c("Original 22", "Atlas 02", "Combined")
barplot(100 * panel_summary$mean_primary_trade_return, names.arg = panel_labels,
        col = ifelse(panel_summary$mean_primary_trade_return > 0, green, red), las = 2,
        ylab = "Mean primary trade return (%)", main = "Trade expectancy by panel")
abline(h = 0, lty = 2, col = gray)
plot(100 * panel_summary$primary_hit_rate, 100 * panel_summary$median_random_percentile,
     pch = 19, cex = 2, col = c(blue, green, dark), xlim = c(45, 60), ylim = c(0, 100),
     xlab = "Trade hit rate (%)", ylab = "Median matched-random percentile (%)",
     main = "Winning frequency versus timing control")
text(100 * panel_summary$primary_hit_rate, 100 * panel_summary$median_random_percentile,
     labels = panel_labels, pos = c(1, 3, 1), cex = 0.9)
abline(h = 50, v = 50, lty = 2, col = gray)
dev.off()

png(file.path(visual_dir, "wide_asset_ownership_and_random_controls.png"), 1800, 1100, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
plot(100 * wide_asset_summary$buy_hold_primary_return,
     100 * wide_asset_summary$primary_compounded_return,
     pch = 19, col = ifelse(wide_asset_summary$cohort == "DIVERSIFIED_CORE", blue, "#805AD5"),
     xlab = "Buy-and-hold return (%)", ylab = "HYP-MOM-01.1 return (%)",
     main = "Asset path versus ownership")
abline(0, 1, lty = 2, col = gray); abline(h = 0, v = 0, lty = 3, col = gray)
hist(100 * wide_asset_summary$observed_random_percentile, breaks = seq(0, 100, 10),
     col = pale, border = "white", xlab = "Matched-random percentile (%)",
     main = "Timing rank across the wide atlas")
abline(v = c(50, 80), lty = c(2, 3), col = c(gray, green))
dev.off()

contrast_labels <- c(
  DA01_PATTERN_GAP = "Gap high - low", DA02_PATTERN_BODY = "Body high - low",
  DA04_ESTABLISHED_VS_BELOW = "Established above - below",
  DA04_RECLAIM_VS_BELOW = "Recent reclaim - below",
  DA05_MOM20 = "Momentum 20 + - non+", DA06_MOM60 = "Momentum 60 + - non+",
  DA07_MOM120 = "Momentum 120 + - non+", DA08_STREAK = "Run 3+ - exactly 2",
  DA09_VOLUME = "Volume high - low", DA10_HIGH60 = "Near high - far below",
  DA11_SPY_SMA200 = "SPY above - below", DA12_SPY_MOM60 = "SPY mom60 + - non+"
)
png(file.path(visual_dir, "diagnostic_contrast_panel_comparison.png"), 1900, 1300, res = 150)
par(mar = c(5, 12, 4, 2))
order_ids <- names(contrast_labels)
panel_order <- c("ORIGINAL_22", "ATLAS_02", "COMBINED")
plot_keys <- unlist(lapply(order_ids, function(id) paste(id, panel_order, sep = "||")))
plot_rows <- diagnostic_contrasts[match(
  plot_keys,
  paste(diagnostic_contrasts$diagnostic_id, diagnostic_contrasts$panel_id, sep = "||")
), ]
plot_rows <- plot_rows[!is.na(plot_rows$diagnostic_id), ]
y_base <- rep(rev(seq_along(order_ids)), each = 3)
offset <- rep(c(0.22, 0, -0.22), times = length(order_ids))
colors <- c(ORIGINAL_22 = blue, ATLAS_02 = green, COMBINED = dark)
plot(100 * plot_rows$mean_asset_contrast, y_base + offset, pch = 19,
     col = colors[plot_rows$panel_id], yaxt = "n", ylab = "",
     xlab = "Mean within-asset return contrast (percentage points)",
     xlim = range(100 * c(plot_rows$bootstrap_ci_low, plot_rows$bootstrap_ci_high), finite = TRUE),
     main = "Does each diagnostic persist as breadth increases?")
segments(100 * plot_rows$bootstrap_ci_low, y_base + offset,
         100 * plot_rows$bootstrap_ci_high, y_base + offset,
         col = colors[plot_rows$panel_id], lwd = 2)
axis(2, rev(seq_along(order_ids)), contrast_labels[order_ids], las = 1, tick = FALSE, cex.axis = 0.8)
abline(v = 0, lty = 2, col = gray)
legend("bottomright", names(colors), col = colors, pch = 19, lwd = 2, bty = "n")
dev.off()

combined_cells <- combined_diag$conditional[combined_diag$conditional$diagnostic_id == "DA03_PATTERN_GRID", ]
gap_levels <- c("LOW", "MID", "HIGH"); body_levels <- c("LOW", "MID", "HIGH")
cell_matrix <- matrix(NA_real_, 3, 3, dimnames = list(gap_levels, body_levels))
cell_n <- matrix(0L, 3, 3, dimnames = list(gap_levels, body_levels))
for (i in seq_len(nrow(combined_cells))) {
  parts <- strsplit(as.character(combined_cells$group[[i]]), "_GAP__BODY_", fixed = TRUE)[[1L]]
  cell_matrix[parts[[1L]], parts[[2L]]] <- 100 * combined_cells$mean_primary_return[[i]]
  cell_n[parts[[1L]], parts[[2L]]] <- combined_cells$trade_count[[i]]
}
png(file.path(visual_dir, "combined_gap_body_heatmap.png"), 1500, 1100, res = 150)
par(mar = c(5, 6, 4, 2))
cell_limit <- max(abs(cell_matrix), na.rm = TRUE)
image(1:3, 1:3, cell_matrix,
      zlim = c(-cell_limit, cell_limit),
      col = grDevices::colorRampPalette(c("#C53030", "#F7FAFC", "#2F855A"))(101),
      axes = FALSE, xlab = "Gap-strength tercile", ylab = "Body-strength tercile",
      main = "Combined 3 x 3 pattern-strength surface")
axis(1, 1:3, gap_levels); axis(2, 1:3, body_levels, las = 1)
for (i in 1:3) for (j in 1:3) text(i, j, sprintf("%+.2f%%\nn=%d", cell_matrix[i, j], cell_n[i, j]), cex = 1.1)
dev.off()

spy_rows <- diagnostic_contrasts[diagnostic_contrasts$diagnostic_id == "DA11_SPY_SMA200", ]
png(file.path(visual_dir, "spy_sma200_persistence.png"), 1800, 1100, res = 150)
par(mfrow = c(1, 2), mar = c(6, 5, 4, 2))
spy_mid <- barplot(100 * spy_rows$mean_asset_contrast, names.arg = panel_labels,
        col = colors[spy_rows$panel_id], las = 2,
        ylab = "Above - below mean return (pp)", main = "SPY SMA200 point estimate")
arrows(spy_mid, 100 * spy_rows$bootstrap_ci_low,
       spy_mid, 100 * spy_rows$bootstrap_ci_high,
       angle = 90, code = 3, length = 0.05, col = gray)
abline(h = 0, lty = 2, col = gray)
barplot(100 * spy_rows$fraction_asset_contrasts_positive, names.arg = panel_labels,
        col = colors[spy_rows$panel_id], las = 2, ylim = c(0, 100),
        ylab = "Assets favoring SPY above (%)", main = "Cross-asset sign breadth")
abline(h = 50, lty = 2, col = gray)
dev.off()

png(file.path(visual_dir, "checkpoint_persistence.png"), 1800, 1100, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
plot(1:4, rep(0, 4), type = "n", xlab = "Checkpoint after entry",
     ylab = "Positive - nonpositive remaining return (pp)",
     ylim = range(100 * c(checkpoint_contrasts$bootstrap_ci_low, checkpoint_contrasts$bootstrap_ci_high)),
     main = "Remaining return by early state")
for (panel in names(colors)) {
  rows <- checkpoint_contrasts[checkpoint_contrasts$panel_id == panel, ]
  lines(rows$checkpoint, 100 * rows$mean_asset_contrast, type = "b", pch = 19,
        col = colors[[panel]], lwd = 2)
}
abline(h = 0, lty = 2, col = gray); legend("bottomright", names(colors), col = colors, lwd = 2, pch = 19, bty = "n")
combined_check <- combined_diag$checkpoint_summary
mat <- tapply(100 * combined_check$mean_final_primary_return,
              list(combined_check$checkpoint_state, combined_check$checkpoint), mean)
matplot(1:4, t(mat), type = "b", pch = 19, lwd = 2, col = c(red, green),
        xlab = "Checkpoint after entry", ylab = "Mean final primary return (%)",
        main = "Final outcome by current state")
abline(h = 0, lty = 2, col = gray)
legend("bottomleft", rownames(mat), col = c(red, green), lwd = 2, pch = 19, bty = "n")
dev.off()

png(file.path(visual_dir, "cohort_and_sector_outcomes.png"), 1900, 1200, res = 150)
par(mfrow = c(1, 2), mar = c(9, 5, 4, 2))
barplot(100 * cohort_summary$mean_primary_trade_return,
        names.arg = c("Diversified core", "2020 attention"),
        col = c(blue, "#805AD5"), las = 2, ylab = "Mean primary trade return (%)",
        main = "Frozen source cohorts")
abline(h = 0, lty = 2, col = gray)
ordered_sector <- sector_summary[order(sector_summary$mean_primary_trade_return), ]
barplot(100 * ordered_sector$mean_primary_trade_return, names.arg = ordered_sector$sector,
        col = ifelse(ordered_sector$mean_primary_trade_return > 0, green, red), las = 2,
        ylab = "Mean primary trade return (%)", main = "Sector descriptions—not selections")
abline(h = 0, lty = 2, col = gray)
dev.off()

plot_tape <- function(row, file_path) {
  symbol <- row$symbol[[1L]]
  bars <- bars_all[bars_all$symbol == symbol, , drop = FALSE]
  bars <- bars[order(bars$session_date), ]
  signal_pos <- match(as.Date(row$signal_date), bars$session_date)
  exit_pos <- match(as.Date(row$exit_date), bars$session_date)
  sma200 <- vapply(seq_len(nrow(bars)), function(i) hyp_mom011_da_sma(bars$close, i, diagnostic_contract$slow_anchor_sessions), numeric(1))
  broad_lo <- max(1L, signal_pos - 260L); broad_hi <- min(nrow(bars), exit_pos + 5L)
  detail_lo <- max(1L, signal_pos - 12L); detail_hi <- min(nrow(bars), exit_pos + 5L)
  detail <- bars[detail_lo:detail_hi, ]; idx <- seq_len(nrow(detail))
  png(file_path, 1800, 1100, res = 150)
  layout(matrix(1:2, ncol = 1), heights = c(1.5, 2.2))
  par(oma = c(1, 0.5, 4.7, 0.5), mar = c(2, 5, 2, 2))
  plot(bars$session_date[broad_lo:broad_hi], bars$close[broad_lo:broad_hi], type = "l",
       col = dark, lwd = 2, xaxt = "n", xlab = "", ylab = "Adjusted close",
       main = "Signal location relative to the 200-session anchor")
  lines(bars$session_date[broad_lo:broad_hi], sma200[broad_lo:broad_hi], col = blue, lwd = 3)
  abline(v = as.Date(row$signal_date), lty = 2, col = red)
  legend("topleft", c("Close", "SMA200", "Signal"), col = c(dark, blue, red), lwd = c(2, 3, 1), lty = c(1, 1, 2), bty = "n")
  par(mar = c(7, 5, 2, 2))
  plot(idx, detail$close, type = "n", xaxt = "n", xlab = "", ylab = "Adjusted price",
       main = "Completed pattern and unchanged five-session trade")
  pattern_idx <- match(as.Date(c(row$first_pattern_date, row$signal_date)), detail$session_date)
  abline(v = pattern_idx, col = light_blue, lwd = 10)
  rect(match(as.Date(row$entry_date), detail$session_date), par("usr")[[3L]],
       match(as.Date(row$exit_date), detail$session_date), par("usr")[[4L]],
       col = grDevices::adjustcolor(ifelse(row$primary_trade_return > 0, green, red), 0.08), border = NA)
  segments(idx, detail$low, idx, detail$high, col = gray)
  candle_color <- ifelse(detail$close >= detail$open, green, red)
  segments(idx, detail$open, idx, detail$close, col = candle_color, lwd = 6)
  points(match(as.Date(row$entry_date), detail$session_date), row$entry_open, pch = 24, bg = blue, cex = 1.5)
  points(match(as.Date(row$exit_date), detail$session_date), row$exit_open, pch = 25, bg = "#805AD5", cex = 1.5)
  axis(1, idx, format(detail$session_date, "%Y-%m-%d"), las = 2, cex.axis = 0.72)
  mtext(paste0(row$tape_archetype, " | ", symbol, " | ", row$sector), outer = TRUE, side = 3, line = 2.8, font = 2, cex = 1.2)
  mtext(paste0("SPY ", row$spy_sma200_state, " | gap z ", formatC(row$gap_strength_z, 2, format = "f"),
               " | body z ", formatC(row$body_strength_z, 2, format = "f"),
               " | primary ", percent(row$primary_trade_return, 2L)),
        outer = TRUE, side = 3, line = 1.2, cex = 0.85)
  dev.off()
}
tape_paths <- character(nrow(tape_manifest))
for (i in seq_len(nrow(tape_manifest))) {
  file_path <- file.path(visual_dir, sprintf("breadth_tape_%02d_%s_%s.png", i,
    tolower(tape_manifest$tape_archetype[[i]]), tolower(tape_manifest$symbol[[i]])))
  plot_tape(tape_manifest[i, , drop = FALSE], file_path)
  tape_paths[[i]] <- normalizePath(file_path, winslash = "/", mustWork = FALSE)
}
tape_manifest$visual_path <- tape_paths

integrity <- data.frame(
  check_id = c(
    "WIDE_REGISTRY_100", "ZERO_OVERLAP_ORIGINAL_22", "ELEVEN_SECTORS",
    "COHORT_COUNTS_75_25", "ALPACA_ADJUSTED_DAILY", "EXPLICIT_AS_OF_TIMESTAMP",
    "CONFIRMATION_EXCLUDED", "NO_DUPLICATE_BARS", "ORIGINAL_ASSETS_22",
    "COMBINED_ASSET_COUNT_MATCHES", "DIAGNOSTIC_TRADE_COUNT_MATCHES"
  ),
  passed = c(
    nrow(wide_registry) == 100L,
    !length(intersect(wide_registry$symbol, original_registry$symbol)),
    length(unique(wide_registry$sector)) == 11L,
    sum(wide_registry$cohort == "DIVERSIFIED_CORE") == 75L && sum(wide_registry$cohort == "RETAIL_ATTENTION_2020") == 25L,
    all(bars_all$provider == "alpaca" & bars_all$adjusted %in% c(TRUE, "TRUE") & bars_all$timeframe == "1D"),
    all(nzchar(bars_all$as_of_timestamp)),
    max(bars_all$session_date) < parent_contract$confirmation_start,
    !anyDuplicated(bars_all[c("symbol", "session_date")]),
    nrow(original_asset_summary) == 22L,
    nrow(combined_asset_summary) == nrow(original_asset_summary) + nrow(wide_asset_summary),
    nrow(combined_diag$grouped) == nrow(original_diag$grouped) + nrow(wide_diag$grouped)
  ),
  stringsAsFactors = FALSE
)
if (!all(integrity$passed)) {
  stop(paste("Breadth integrity failed:", paste(integrity$check_id[!integrity$passed], collapse = ", ")), call. = FALSE)
}

run_spec <- data.frame(
  atlas_id = breadth_contract$atlas_id,
  evidence_stage = breadth_contract$evidence_stage,
  as_of_timestamp = parent_contract$as_of_timestamp,
  discovery_start = as.character(parent_contract$discovery_start),
  discovery_end = as.character(parent_contract$discovery_end),
  original_asset_count = nrow(original_asset_summary),
  atlas_registry_count = nrow(wide_registry),
  atlas_eligible_count = nrow(wide_asset_summary),
  combined_asset_count = nrow(combined_asset_summary),
  combined_trade_count = nrow(combined_trades),
  refresh = refresh,
  status = "DISCOVERY_BREADTH_EXTENSION_COMPLETE_NO_STRATEGY_AUTHORITY",
  stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "hyp_mom_01_1_breadth_run_spec.csv"))
write_csv(integrity, file.path(output_dir, "hyp_mom_01_1_breadth_integrity.csv"))
write_csv(wide_registry, file.path(output_dir, "hyp_mom_01_1_breadth_registry.csv"))
write_csv(coverage, file.path(output_dir, "hyp_mom_01_1_breadth_coverage.csv"))
write_csv(query$health, file.path(output_dir, "hyp_mom_01_1_breadth_query_health.csv"))
write_csv(wide_candidates, file.path(output_dir, "hyp_mom_01_1_breadth_signal_candidates.csv"))
write_csv(wide_trades, file.path(output_dir, "hyp_mom_01_1_breadth_executed_trades.csv"))
write_csv(wide_paths, file.path(output_dir, "hyp_mom_01_1_breadth_daily_paths.csv"))
write_csv(wide_random, file.path(output_dir, "hyp_mom_01_1_breadth_random_controls.csv"))
write_csv(wide_asset_summary, file.path(output_dir, "hyp_mom_01_1_breadth_asset_summary.csv"))
write_csv(panel_summary, file.path(output_dir, "hyp_mom_01_1_breadth_panel_summary.csv"))
write_csv(cohort_summary, file.path(output_dir, "hyp_mom_01_1_breadth_cohort_summary.csv"))
write_csv(sector_summary, file.path(output_dir, "hyp_mom_01_1_breadth_sector_summary.csv"))
write_csv(wide_diag$grouped, file.path(output_dir, "hyp_mom_01_1_breadth_diagnostic_trades.csv"))
write_csv(diagnostic_conditional, file.path(output_dir, "hyp_mom_01_1_breadth_diagnostic_conditional.csv"))
write_csv(diagnostic_contrasts, file.path(output_dir, "hyp_mom_01_1_breadth_diagnostic_contrasts.csv"))
write_csv(diagnostic_correlations, file.path(output_dir, "hyp_mom_01_1_breadth_diagnostic_correlations.csv"))
write_csv(diagnostic_correlation_summary, file.path(output_dir, "hyp_mom_01_1_breadth_diagnostic_correlation_summary.csv"))
write_csv(checkpoint_summary, file.path(output_dir, "hyp_mom_01_1_breadth_checkpoint_summary.csv"))
write_csv(checkpoint_contrasts, file.path(output_dir, "hyp_mom_01_1_breadth_checkpoint_contrasts.csv"))
write_csv(tape_manifest, file.path(output_dir, "hyp_mom_01_1_breadth_tape_manifest.csv"))

report <- c(
  "# HYP-MOM-01.1 Stock Atlas 02 Breadth Extension",
  "",
  "Status: `DISCOVERY_BREADTH_EXTENSION_COMPLETE_NO_STRATEGY_AUTHORITY`.",
  "",
  paste0("Frozen identities: 100; eligible Atlas 02 assets: ", nrow(wide_asset_summary),
         "; combined assets: ", nrow(combined_asset_summary), "."),
  "",
  paste0("Combined executed trades: ", nrow(combined_trades), "."),
  "",
  "The packet reports original, incremental, and combined panels separately. The known 2021-2023 window remains discovery-only, coverage failures were not replaced, and 2024+ was not queried."
)
writeLines(report, file.path(output_dir, "hyp_mom_01_1_breadth_report.md"))

print(panel_summary)
print(diagnostic_contrasts[diagnostic_contrasts$diagnostic_id %in% c("DA01_PATTERN_GAP", "DA04_ESTABLISHED_VS_BELOW", "DA11_SPY_SMA200"),
                           c("panel_id", "diagnostic_id", "paired_asset_count", "mean_asset_contrast", "bootstrap_ci_low", "bootstrap_ci_high", "fraction_asset_contrasts_positive")])
message("HYP-MOM-01.1 breadth extension complete: ", output_dir)
