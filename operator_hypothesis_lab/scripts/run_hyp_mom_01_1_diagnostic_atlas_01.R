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

source(file.path(
  repo_root, "operator_hypothesis_lab", "R",
  "hyp_mom_01_1_two_green_gap_ups.R"
))
source(file.path(
  repo_root, "operator_hypothesis_lab", "R",
  "hyp_mom_01_1_diagnostic_atlas.R"
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

parent_contract <- hyp_mom011_validate_contract(hyp_mom011_contract())
atlas_contract <- hyp_mom011_da_validate_contract(hyp_mom011_da_contract())
base_registry_path <- file.path(
  repo_root, "operator_hypothesis_lab", "registries",
  "hyp_mom_01_1_discovery_registry.csv"
)
diagnostic_registry_path <- file.path(
  repo_root, "operator_hypothesis_lab", "registries",
  "hyp_mom_01_1_diagnostic_atlas_01_registry.csv"
)
source_bars_path <- Sys.getenv(
  "GEN5_HYP_MOM_01_1_SOURCE_BARS",
  unset = file.path(
    repo_root, "runs", "research_workbench", "literature_grounded",
    "lit_mom_01_1_stock_atlas_01_20260731",
    "stock_atlas_01_workbench_query_bars.csv"
  )
)
run_id <- Sys.getenv(
  "GEN5_HYP_MOM_01_1_DA_RUN_ID",
  unset = "hyp_mom_01_1_diagnostic_atlas_01_20260803"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

base_registry <- utils::read.csv(base_registry_path, stringsAsFactors = FALSE)
diagnostic_registry <- utils::read.csv(diagnostic_registry_path, stringsAsFactors = FALSE)
hyp_mom011_validate_registry(base_registry)
if (nrow(diagnostic_registry) != 13L || anyDuplicated(diagnostic_registry$diagnostic_id)) {
  stop("Diagnostic registry must contain thirteen unique frozen rows.", call. = FALSE)
}
if (!file.exists(source_bars_path)) stop("Diagnostic source bars are missing.", call. = FALSE)
bars_all <- utils::read.csv(source_bars_path, stringsAsFactors = FALSE)
bars_all$session_date <- as.Date(bars_all$session_date)

source_checks <- data.frame(
  check_id = c(
    "PARENT_REGISTRY_VALID", "DIAGNOSTIC_REGISTRY_13_ROWS",
    "SOURCE_SYMBOL_COVERAGE", "SOURCE_HISTORY_FOR_SMA200",
    "ALPACA_ADJUSTED_DAILY", "EXPLICIT_AS_OF_TIMESTAMP",
    "DISCOVERY_END_BOUND", "CONFIRMATION_EXCLUDED", "NO_DUPLICATE_BARS"
  ),
  passed = c(
    nrow(base_registry) == 22L && length(unique(base_registry$sector)) == 11L,
    nrow(diagnostic_registry) == 13L,
    all(c(base_registry$symbol, "SPY") %in% unique(bars_all$symbol)),
    all(vapply(
      split(bars_all$session_date, bars_all$symbol),
      function(x) min(x) <= as.Date("2016-01-04"),
      logical(1)
    )),
    all(bars_all$provider == "alpaca" & bars_all$adjusted %in% c(TRUE, "TRUE") & bars_all$timeframe == "1D"),
    all(nzchar(bars_all$as_of_timestamp)),
    max(bars_all$session_date) <= parent_contract$discovery_end,
    all(bars_all$session_date < parent_contract$confirmation_start),
    !anyDuplicated(bars_all[c("symbol", "session_date")])
  ),
  stringsAsFactors = FALSE
)
if (!all(source_checks$passed)) {
  stop(paste(
    "Diagnostic source integrity failed:",
    paste(source_checks$check_id[!source_checks$passed], collapse = ", ")
  ), call. = FALSE)
}

bars_all <- hyp_mom011_validate_bars(
  bars_all[bars_all$symbol %in% c(base_registry$symbol, "SPY"), , drop = FALSE],
  parent_contract
)
spy_context <- hyp_mom011_da_spy_context(
  bars_all[bars_all$symbol == "SPY", , drop = FALSE],
  atlas_contract,
  parent_contract
)

message("HYP-MOM-01.1 Diagnostic Atlas 01 starting: ", nrow(base_registry), " assets.")
feature_rows <- vector("list", nrow(base_registry))
for (i in seq_len(nrow(base_registry))) {
  reg <- base_registry[i, , drop = FALSE]
  symbol <- reg$symbol[[1L]]
  message(sprintf("[%02d/%02d] %s", i, nrow(base_registry), symbol))
  bars <- bars_all[bars_all$symbol == symbol, , drop = FALSE]
  features <- hyp_mom011_da_asset_features(
    bars, spy_context, atlas_contract, parent_contract
  )
  features$instance_id <- reg$instance_id
  features$sector <- reg$sector
  identity <- c("instance_id", "symbol", "sector")
  feature_rows[[i]] <- features[c(identity, setdiff(names(features), identity))]
}
trades <- do.call(rbind, feature_rows)
rownames(trades) <- NULL
trades <- hyp_mom011_da_add_groups(trades, atlas_contract)

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
conditional_summary <- do.call(rbind, lapply(summary_specs, function(spec) {
  hyp_mom011_da_group_summary(trades, spec[[1L]], spec[[2L]])
}))
rownames(conditional_summary) <- NULL

contrast_specs <- data.frame(
  diagnostic_id = c(
    "DA01_PATTERN_GAP", "DA02_PATTERN_BODY",
    "DA04_ESTABLISHED_VS_BELOW", "DA04_RECLAIM_VS_BELOW",
    "DA05_MOM20", "DA06_MOM60", "DA07_MOM120",
    "DA08_STREAK", "DA09_VOLUME", "DA10_HIGH60",
    "DA11_SPY_SMA200", "DA12_SPY_MOM60"
  ),
  group_column = c(
    "gap_strength_tercile", "body_strength_tercile",
    "anchor_state", "anchor_state",
    "momentum_20_state", "momentum_60_state", "momentum_120_state",
    "streak_state", "volume_state", "high60_state",
    "spy_sma200_state", "spy_momentum_60_state"
  ),
  positive_group = c(
    "HIGH", "HIGH", "ESTABLISHED_ABOVE", "RECENT_RECLAIM",
    rep("POSITIVE", 3L), "THREE_OR_MORE", "AT_OR_ABOVE_ONE",
    "NEAR_HIGH", "ABOVE", "POSITIVE"
  ),
  reference_group = c(
    "LOW", "LOW", "BELOW_ANCHOR", "BELOW_ANCHOR",
    rep("NONPOSITIVE", 3L), "EXACTLY_TWO", "BELOW_ONE",
    "FAR_BELOW_HIGH", "BELOW", "NONPOSITIVE"
  ),
  stringsAsFactors = FALSE
)
contrast_rows <- lapply(seq_len(nrow(contrast_specs)), function(i) {
  spec <- contrast_specs[i, , drop = FALSE]
  hyp_mom011_da_asset_contrast(
    trades,
    spec$diagnostic_id,
    spec$group_column,
    spec$positive_group,
    spec$reference_group,
    atlas_contract$bootstrap_draws,
    atlas_contract$bootstrap_seed + i * 100L
  )
})
asset_contrasts <- do.call(rbind, contrast_rows)
rownames(asset_contrasts) <- NULL

continuous_features <- c(
  "gap_strength_z", "body_strength_z", "minimum_gap_z", "minimum_body_z",
  "second_minus_first_strength", "anchor_distance_z",
  "momentum_20", "momentum_60", "momentum_120",
  "volume_ratio20", "high60_distance_z"
)
asset_correlations <- hyp_mom011_da_asset_correlations(
  trades, continuous_features, atlas_contract$minimum_asset_correlation_trades
)
correlation_summary <- do.call(rbind, lapply(
  split(asset_correlations, asset_correlations$feature),
  function(x) data.frame(
    feature = unique(x$feature),
    asset_count = nrow(x),
    mean_asset_spearman_rho = mean(x$spearman_rho),
    median_asset_spearman_rho = stats::median(x$spearman_rho),
    fraction_asset_rhos_positive = mean(x$spearman_rho > 0),
    minimum_asset_rho = min(x$spearman_rho),
    maximum_asset_rho = max(x$spearman_rho),
    stringsAsFactors = FALSE
  )
))
rownames(correlation_summary) <- NULL

checkpoints <- hyp_mom011_da_checkpoint_rows(trades, parent_contract$holding_sessions)
checkpoint_summary <- hyp_mom011_da_checkpoint_summary(checkpoints)
checkpoint_contrasts <- do.call(rbind, lapply(1:4, function(k) {
  x <- checkpoints[checkpoints$checkpoint == k, , drop = FALSE]
  x$primary_trade_return <- x$remaining_return
  hyp_mom011_da_asset_contrast(
    x,
    paste0("DA13_CHECKPOINT_", k),
    "checkpoint_state",
    "POSITIVE",
    "NONPOSITIVE",
    atlas_contract$bootstrap_draws,
    atlas_contract$bootstrap_seed + 2000L + k
  )
}))

path_dimensions <- c(
  gap_strength_tercile = "DA01_PATTERN_GAP",
  body_strength_tercile = "DA02_PATTERN_BODY",
  anchor_state = "DA04_SMA200",
  momentum_20_state = "DA05_MOM20",
  momentum_60_state = "DA06_MOM60",
  momentum_120_state = "DA07_MOM120",
  streak_state = "DA08_STREAK",
  volume_state = "DA09_VOLUME",
  high60_state = "DA10_HIGH60",
  spy_sma200_state = "DA11_SPY_SMA200"
)
path_rows <- list()
path_index <- 0L
for (group_column in names(path_dimensions)) {
  for (group_name in sort(unique(trades[[group_column]]))) {
    x <- trades[trades[[group_column]] == group_name, , drop = FALSE]
    for (horizon in 0:parent_contract$holding_sessions) {
      values <- if (horizon == 0L) rep(0, nrow(x)) else x[[paste0("path_return_", horizon)]]
      path_index <- path_index + 1L
      path_rows[[path_index]] <- data.frame(
        diagnostic_id = unname(path_dimensions[[group_column]]),
        group_column = group_column,
        group = group_name,
        horizon = horizon,
        trade_count = nrow(x),
        asset_count = length(unique(x$symbol)),
        mean_cumulative_gross_return = mean(values),
        median_cumulative_gross_return = stats::median(values),
        stringsAsFactors = FALSE
      )
    }
  }
}
path_profiles <- do.call(rbind, path_rows)

pick_median_trade <- function(x, archetype) {
  if (!nrow(x)) return(NULL)
  med <- stats::median(x$primary_trade_return)
  row <- x[order(abs(x$primary_trade_return - med), x$trade_id)[[1L]], , drop = FALSE]
  row$tape_archetype <- archetype
  row
}
tape_rows <- list(
  pick_median_trade(trades[trades$anchor_state == "ESTABLISHED_ABOVE", ], "ANCHOR_ESTABLISHED_ABOVE_MEDIAN"),
  pick_median_trade(trades[trades$anchor_state == "RECENT_RECLAIM", ], "ANCHOR_RECENT_RECLAIM_MEDIAN"),
  pick_median_trade(trades[trades$anchor_state == "BELOW_ANCHOR", ], "ANCHOR_BELOW_MEDIAN"),
  pick_median_trade(trades[trades$gap_strength_tercile == "LOW" & trades$body_strength_tercile == "LOW", ], "LOW_GAP_LOW_BODY_MEDIAN"),
  pick_median_trade(trades[trades$gap_strength_tercile == "HIGH" & trades$body_strength_tercile == "HIGH", ], "HIGH_GAP_HIGH_BODY_MEDIAN")
)
tape_rows <- Filter(Negate(is.null), tape_rows)
tape_manifest <- do.call(rbind, tape_rows)
tape_manifest$tape_order <- seq_len(nrow(tape_manifest))

blue <- "#2B6CB0"
light_blue <- "#90CDF4"
green <- "#2F855A"
red <- "#C53030"
gray <- "#718096"
dark <- "#1A202C"

# Gap/body joint strength map.
png(file.path(visual_dir, "gap_body_strength_atlas.png"), 1900, 1100, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
plot(
  trades$gap_strength_z, trades$body_strength_z,
  pch = 19,
  col = grDevices::adjustcolor(ifelse(trades$primary_trade_return > 0, green, red), 0.45),
  xlab = "Two-gap strength (lagged-volatility units)",
  ylab = "Two-body strength (lagged-volatility units)",
  main = "Executed signals span a broad shape continuum"
)
gap_breaks <- stats::quantile(trades$gap_strength_z, c(1 / 3, 2 / 3))
body_breaks <- stats::quantile(trades$body_strength_z, c(1 / 3, 2 / 3))
abline(v = gap_breaks, h = body_breaks, lty = 3, col = gray)
legend("topright", c("Positive trade", "Nonpositive trade"), pch = 19, col = c(green, red), bty = "n")

levels <- c("LOW", "MID", "HIGH")
mean_matrix <- count_matrix <- hit_matrix <- matrix(NA_real_, 3, 3, dimnames = list(levels, levels))
for (g in levels) for (b in levels) {
  x <- trades[trades$gap_strength_tercile == g & trades$body_strength_tercile == b, ]
  if (nrow(x)) {
    mean_matrix[g, b] <- mean(x$primary_trade_return)
    count_matrix[g, b] <- nrow(x)
    hit_matrix[g, b] <- mean(x$primary_trade_return > 0)
  }
}
limit <- max(abs(mean_matrix), na.rm = TRUE)
palette <- grDevices::colorRampPalette(c(red, "#FFFFFF", green))(101)
scaled <- mean_matrix
scaled[] <- pmax(-limit, pmin(limit, mean_matrix))
image(1:3, 1:3, t(scaled), col = palette, zlim = c(-limit, limit), axes = FALSE,
      xlab = "Body-strength tercile", ylab = "Gap-strength tercile",
      main = "Mean return by predeclared 3 x 3 cell")
axis(1, 1:3, levels)
axis(2, 1:3, levels, las = 1)
for (i in 1:3) for (j in 1:3) {
  text(j, i, paste0(
    percent(mean_matrix[i, j], 2L), "\n",
    "n=", count_matrix[i, j], " | hit ", percent(hit_matrix[i, j], 0L)
  ), cex = 0.82)
}
dev.off()

# Asset-paired contrast forest.
plot_contrasts <- asset_contrasts[is.finite(asset_contrasts$mean_asset_contrast), ]
plot_contrasts$label <- c(
  "Gap strength: high - low", "Body strength: high - low",
  "Established above - below", "Recent reclaim - below",
  "Momentum 20: positive - nonpositive", "Momentum 60: positive - nonpositive",
  "Momentum 120: positive - nonpositive", "Run length: 3+ - exactly 2",
  "Volume: >= lagged median - below", "Near 60d high - far below",
  "SPY above SMA200 - below", "SPY mom60 positive - nonpositive"
)[match(plot_contrasts$diagnostic_id, contrast_specs$diagnostic_id)]
png(file.path(visual_dir, "asset_paired_contrast_forest.png"), 1700, 1200, res = 150)
par(mar = c(5, 13, 4, 2))
y <- rev(seq_len(nrow(plot_contrasts)))
xlim <- range(100 * c(plot_contrasts$bootstrap_ci_low, plot_contrasts$bootstrap_ci_high), finite = TRUE)
plot(100 * plot_contrasts$mean_asset_contrast, y, pch = 19,
     col = ifelse(plot_contrasts$mean_asset_contrast > 0, green, red),
     xlim = xlim, yaxt = "n", ylab = "", xlab = "Mean within-asset return contrast (percentage points)",
     main = "Each contrast first gives every paired asset one vote")
segments(100 * plot_contrasts$bootstrap_ci_low, y,
         100 * plot_contrasts$bootstrap_ci_high, y, col = gray, lwd = 3)
axis(2, y, paste0(plot_contrasts$label, "  [", plot_contrasts$paired_asset_count, "]"),
     las = 1, tick = FALSE, cex.axis = 0.78)
abline(v = 0, lty = 2, col = dark)
dev.off()

# Slow-anchor behavior and paths.
anchor_summary <- conditional_summary[conditional_summary$diagnostic_id == "DA04_SMA200", ]
anchor_paths <- path_profiles[path_profiles$diagnostic_id == "DA04_SMA200", ]
anchor_order <- c("BELOW_ANCHOR", "RECENT_RECLAIM", "ESTABLISHED_ABOVE")
anchor_colors <- c(BELOW_ANCHOR = red, RECENT_RECLAIM = blue, ESTABLISHED_ABOVE = green)
png(file.path(visual_dir, "slow_anchor_state_behavior.png"), 1800, 1100, res = 150)
par(mfrow = c(1, 2), mar = c(6, 6, 4, 2))
anchor_summary <- anchor_summary[match(anchor_order, anchor_summary$group), ]
bars <- barplot(100 * anchor_summary$mean_primary_return,
                names.arg = c("Below", "Recent\nreclaim", "Established\nabove"),
                col = anchor_colors[anchor_order], ylab = "Mean primary trade return (%)",
                main = "Endpoint return by SMA200 state")
abline(h = 0, col = dark)
text(bars, 100 * anchor_summary$mean_primary_return,
     labels = paste0("n=", anchor_summary$trade_count),
     pos = ifelse(anchor_summary$mean_primary_return >= 0, 3, 1), cex = 0.9)
plot(0:5, rep(0, 6), type = "n", xlab = "Open-to-open session after entry",
     ylab = "Mean cumulative gross return (%)",
     ylim = range(100 * anchor_paths$mean_cumulative_gross_return),
     main = "Average path under the unchanged five-session exit")
for (state in anchor_order) {
  x <- anchor_paths[anchor_paths$group == state, ]
  lines(x$horizon, 100 * x$mean_cumulative_gross_return,
        type = "b", pch = 19, lwd = 3, col = anchor_colors[[state]])
}
abline(h = 0, lty = 2, col = gray)
legend("topleft", c("Below", "Recent reclaim", "Established above"),
       col = anchor_colors[anchor_order], lwd = 3, pch = 19, bty = "n")
dev.off()

# Lookback-momentum behavior.
mom_ids <- c("DA05_MOM20", "DA06_MOM60", "DA07_MOM120")
mom_summary <- conditional_summary[conditional_summary$diagnostic_id %in% mom_ids, ]
png(file.path(visual_dir, "lookback_momentum_behavior.png"), 1800, 1100, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
mean_matrix <- matrix(NA_real_, 2, 3, dimnames = list(c("NONPOSITIVE", "POSITIVE"), c("20", "60", "120")))
count_matrix <- mean_matrix
for (j in seq_along(mom_ids)) for (state in rownames(mean_matrix)) {
  x <- mom_summary[mom_summary$diagnostic_id == mom_ids[[j]] & mom_summary$group == state, ]
  mean_matrix[state, j] <- x$mean_primary_return
  count_matrix[state, j] <- x$trade_count
}
bp <- barplot(100 * mean_matrix, beside = TRUE, col = c(red, green),
              names.arg = c("L=20", "L=60", "L=120"),
              ylab = "Mean primary trade return (%)",
              main = "Prior-return sign at three fixed lookbacks")
abline(h = 0, col = dark)
legend("topleft", c("Nonpositive", "Positive"), fill = c(red, green), bty = "n")
text(bp, 100 * mean_matrix, labels = paste0("n=", as.integer(count_matrix)),
     pos = ifelse(mean_matrix >= 0, 3, 1), cex = 0.75)
mom_contrasts <- asset_contrasts[asset_contrasts$diagnostic_id %in% mom_ids, ]
y <- rev(seq_len(nrow(mom_contrasts)))
xlim <- range(100 * c(mom_contrasts$bootstrap_ci_low, mom_contrasts$bootstrap_ci_high))
plot(100 * mom_contrasts$mean_asset_contrast, y, pch = 19, xlim = xlim,
     yaxt = "n", ylab = "", xlab = "Positive - nonpositive (percentage points)",
     col = ifelse(mom_contrasts$mean_asset_contrast > 0, green, red),
     main = "Asset-paired contrasts remain descriptive")
segments(100 * mom_contrasts$bootstrap_ci_low, y,
         100 * mom_contrasts$bootstrap_ci_high, y, col = gray, lwd = 3)
axis(2, y, c("L=20", "L=60", "L=120"), las = 1, tick = FALSE)
abline(v = 0, lty = 2, col = dark)
dev.off()

# Secondary context.
secondary_ids <- c("DA08_STREAK", "DA09_VOLUME", "DA10_HIGH60", "DA11_SPY_SMA200")
secondary_titles <- c(
  DA08_STREAK = "Fresh versus extended run",
  DA09_VOLUME = "Signal-day volume participation",
  DA10_HIGH60 = "Location versus 60-session high",
  DA11_SPY_SMA200 = "Broad-market SMA200 state"
)
png(file.path(visual_dir, "secondary_context_behavior.png"), 1800, 1200, res = 150)
par(mfrow = c(2, 2), mar = c(7, 5, 4, 2))
for (id in secondary_ids) {
  x <- conditional_summary[conditional_summary$diagnostic_id == id, ]
  x <- x[order(x$group), ]
  values <- 100 * x$mean_primary_return
  bp <- barplot(values, names.arg = gsub("_", "\n", x$group),
                col = ifelse(values >= 0, green, red), las = 1,
                ylab = "Mean return (%)", main = secondary_titles[[id]], cex.names = 0.72)
  abline(h = 0, col = dark)
  text(bp, values, paste0("n=", x$trade_count),
       pos = ifelse(values >= 0, 3, 1), cex = 0.78)
}
dev.off()

# Broad-market slow-anchor distribution and asset breadth.
spy_means <- stats::aggregate(
  trades$primary_trade_return,
  list(symbol = trades$symbol, state = trades$spy_sma200_state),
  mean
)
names(spy_means)[[3L]] <- "mean_return"
spy_wide <- reshape(spy_means, idvar = "symbol", timevar = "state", direction = "wide")
spy_wide$contrast <- spy_wide$mean_return.ABOVE - spy_wide$mean_return.BELOW
spy_wide <- spy_wide[order(spy_wide$contrast), ]
png(file.path(visual_dir, "spy_sma200_tail_and_asset_breadth.png"), 1800, 1100, res = 150)
par(mfrow = c(1, 2), mar = c(6, 5, 4, 2))
boxplot(
  100 * trades$primary_trade_return ~ trades$spy_sma200_state,
  names = c("SPY above", "SPY below"),
  col = c(green, red), outline = TRUE,
  xlab = "",
  ylab = "Primary trade return (%)",
  main = "Below-market-anchor trades had a worse loss tail"
)
abline(h = 0, lty = 2, col = gray)
y <- seq_len(nrow(spy_wide))
plot(100 * spy_wide$contrast, y, pch = 19,
     col = ifelse(spy_wide$contrast > 0, green, red),
     yaxt = "n", ylab = "", xlab = "Above - below mean return (percentage points)",
     main = "Thirteen of twenty-two assets favored SPY above")
axis(2, y, spy_wide$symbol, las = 1, tick = FALSE, cex.axis = 0.82)
abline(v = 0, lty = 2, col = gray)
dev.off()

# Checkpoint recovery/giveback diagnostic.
checkpoint_colors <- c(NONPOSITIVE = red, POSITIVE = green)
png(file.path(visual_dir, "checkpoint_remaining_return.png"), 1750, 1050, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
plot(1:4, rep(0, 4), type = "n", xlab = "Checkpoint after entry (sessions)",
     ylab = "Mean return remaining to day-five exit (%)",
     ylim = range(100 * checkpoint_summary$mean_remaining_return),
     main = "Does early weakness recover before the fixed exit?")
for (state in c("NONPOSITIVE", "POSITIVE")) {
  x <- checkpoint_summary[checkpoint_summary$checkpoint_state == state, ]
  lines(x$checkpoint, 100 * x$mean_remaining_return, type = "b", pch = 19,
        lwd = 3, col = checkpoint_colors[[state]])
  text(x$checkpoint, 100 * x$mean_remaining_return,
       labels = paste0("n=", x$trade_count), pos = 3, cex = 0.75)
}
abline(h = 0, lty = 2, col = gray)
legend("topright", c("Currently nonpositive", "Currently positive"),
       col = checkpoint_colors, lwd = 3, pch = 19, bty = "n")
y <- rev(1:4)
xlim <- range(100 * c(checkpoint_contrasts$bootstrap_ci_low, checkpoint_contrasts$bootstrap_ci_high))
plot(100 * checkpoint_contrasts$mean_asset_contrast, y, pch = 19, xlim = xlim,
     yaxt = "n", ylab = "", xlab = "Positive - nonpositive remaining return (pp)",
     col = ifelse(checkpoint_contrasts$mean_asset_contrast > 0, green, red),
     main = "Asset-paired continuation contrast")
segments(100 * checkpoint_contrasts$bootstrap_ci_low, y,
         100 * checkpoint_contrasts$bootstrap_ci_high, y, col = gray, lwd = 3)
axis(2, y, paste0("Checkpoint ", 1:4), las = 1, tick = FALSE)
abline(v = 0, lty = 2, col = dark)
dev.off()

# Continuous-feature asset correlations.
correlation_summary <- correlation_summary[order(correlation_summary$median_asset_spearman_rho), ]
png(file.path(visual_dir, "continuous_feature_asset_correlations.png"), 1750, 1100, res = 150)
par(mfrow = c(1, 2), mar = c(5, 10, 4, 2))
y <- seq_len(nrow(correlation_summary))
plot(correlation_summary$median_asset_spearman_rho, y, pch = 19,
     col = ifelse(correlation_summary$median_asset_spearman_rho > 0, green, red),
     yaxt = "n", ylab = "", xlab = "Median within-asset Spearman rho",
     xlim = range(c(-0.25, 0.25, correlation_summary$median_asset_spearman_rho)),
     main = "Continuous feature versus trade return")
axis(2, y, gsub("_", " ", correlation_summary$feature), las = 1, tick = FALSE, cex.axis = 0.8)
abline(v = 0, lty = 2, col = gray)
plot(100 * correlation_summary$fraction_asset_rhos_positive, y, pch = 19,
     col = blue, xlim = c(0, 100), yaxt = "n", ylab = "",
     xlab = "Assets with positive rho (%)",
     main = "Cross-asset sign breadth")
axis(2, y, gsub("_", " ", correlation_summary$feature), las = 1, tick = FALSE, cex.axis = 0.8)
abline(v = 50, lty = 2, col = gray)
dev.off()

plot_diagnostic_tape <- function(row, file_path) {
  symbol <- row$symbol[[1L]]
  bars <- bars_all[bars_all$symbol == symbol, , drop = FALSE]
  bars <- bars[order(bars$session_date), ]
  signal_pos <- match(as.Date(row$signal_date), bars$session_date)
  entry_pos <- match(as.Date(row$entry_date), bars$session_date)
  exit_pos <- match(as.Date(row$exit_date), bars$session_date)
  sma200 <- vapply(seq_len(nrow(bars)), function(i) {
    hyp_mom011_da_sma(bars$close, i, atlas_contract$slow_anchor_sessions)
  }, numeric(1))
  broad_lo <- max(1L, signal_pos - 260L)
  broad_hi <- min(nrow(bars), exit_pos + 5L)
  detail_lo <- max(1L, signal_pos - 12L)
  detail_hi <- min(nrow(bars), exit_pos + 5L)
  detail <- bars[detail_lo:detail_hi, ]
  idx <- seq_len(nrow(detail))
  png(file_path, 1800, 1100, res = 150)
  layout(matrix(1:2, ncol = 1), heights = c(1.5, 2.2))
  par(oma = c(1, 0.5, 4.7, 0.5), mar = c(2, 5, 2, 2))
  plot(bars$session_date[broad_lo:broad_hi], bars$close[broad_lo:broad_hi],
       type = "l", col = dark, lwd = 2, xaxt = "n", xlab = "", ylab = "Adjusted close",
       main = "Signal location relative to the 200-session anchor")
  lines(bars$session_date[broad_lo:broad_hi], sma200[broad_lo:broad_hi], col = blue, lwd = 3)
  abline(v = as.Date(row$signal_date), lty = 2, col = red)
  legend("topleft", c("Close", "SMA200", "Signal"), col = c(dark, blue, red),
         lwd = c(2, 3, 1), lty = c(1, 1, 2), bty = "n")
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
  points(match(as.Date(row$entry_date), detail$session_date), row$entry_open,
         pch = 24, bg = blue, cex = 1.5)
  points(match(as.Date(row$exit_date), detail$session_date), row$exit_open,
         pch = 25, bg = "#805AD5", cex = 1.5)
  axis(1, idx, format(detail$session_date, "%Y-%m-%d"), las = 2, cex.axis = 0.72)
  mtext(paste0(
    row$tape_archetype, " | ", symbol, " | ", row$sector
  ), outer = TRUE, side = 3, line = 2.8, font = 2, cex = 1.2)
  mtext(paste0(
    "anchor ", row$anchor_state, " | gap z ", formatC(row$gap_strength_z, 2, format = "f"),
    " | body z ", formatC(row$body_strength_z, 2, format = "f"),
    " | primary ", percent(row$primary_trade_return, 2L)
  ), outer = TRUE, side = 3, line = 1.2, cex = 0.85)
  dev.off()
}

tape_paths <- character(nrow(tape_manifest))
for (i in seq_len(nrow(tape_manifest))) {
  row <- tape_manifest[i, , drop = FALSE]
  path <- file.path(visual_dir, sprintf(
    "diagnostic_tape_%02d_%s_%s.png",
    i, tolower(row$tape_archetype), tolower(row$symbol)
  ))
  plot_diagnostic_tape(row, path)
  tape_paths[[i]] <- normalizePath(path, winslash = "/", mustWork = FALSE)
}
tape_manifest$visual_path <- tape_paths

run_spec <- data.frame(
  atlas_id = atlas_contract$atlas_id,
  parent_hypothesis_id = atlas_contract$parent_hypothesis_id,
  evidence_stage = atlas_contract$evidence_stage,
  as_of_timestamp = parent_contract$as_of_timestamp,
  discovery_start = as.character(parent_contract$discovery_start),
  discovery_end = as.character(parent_contract$discovery_end),
  confirmation_start = as.character(parent_contract$confirmation_start),
  executed_trade_count = nrow(trades),
  volatility_lookback = atlas_contract$volatility_lookback,
  slow_anchor_sessions = atlas_contract$slow_anchor_sessions,
  momentum_lookbacks = paste(atlas_contract$momentum_lookbacks, collapse = ","),
  bootstrap_draws = atlas_contract$bootstrap_draws,
  source_bars_path = normalizePath(source_bars_path, winslash = "/", mustWork = FALSE),
  status = "DIAGNOSTIC_ATLAS_COMPLETE_NO_STRATEGY_AUTHORITY",
  stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "hyp_mom_01_1_da_run_spec.csv"))
write_csv(source_checks, file.path(output_dir, "hyp_mom_01_1_da_integrity.csv"))
write_csv(diagnostic_registry, file.path(output_dir, "hyp_mom_01_1_da_registry.csv"))
write_csv(trades, file.path(output_dir, "hyp_mom_01_1_da_executed_trades.csv"))
write_csv(conditional_summary, file.path(output_dir, "hyp_mom_01_1_da_conditional_summary.csv"))
write_csv(asset_contrasts, file.path(output_dir, "hyp_mom_01_1_da_asset_contrasts.csv"))
write_csv(asset_correlations, file.path(output_dir, "hyp_mom_01_1_da_asset_correlations.csv"))
write_csv(correlation_summary, file.path(output_dir, "hyp_mom_01_1_da_correlation_summary.csv"))
write_csv(checkpoints, file.path(output_dir, "hyp_mom_01_1_da_checkpoint_rows.csv"))
write_csv(checkpoint_summary, file.path(output_dir, "hyp_mom_01_1_da_checkpoint_summary.csv"))
write_csv(checkpoint_contrasts, file.path(output_dir, "hyp_mom_01_1_da_checkpoint_contrasts.csv"))
write_csv(path_profiles, file.path(output_dir, "hyp_mom_01_1_da_path_profiles.csv"))
write_csv(tape_manifest, file.path(output_dir, "hyp_mom_01_1_da_tape_manifest.csv"))

report <- c(
  "# HYP-MOM-01.1 Diagnostic Atlas 01",
  "",
  "Status: `DIAGNOSTIC_ATLAS_COMPLETE_NO_STRATEGY_AUTHORITY`.",
  "",
  paste0("Evidence stage: `", atlas_contract$evidence_stage, "`."),
  "",
  "## Scope",
  "",
  paste0("The atlas retained all ", nrow(trades), " executed parent trades and computed causal pattern-strength, slow-anchor, prior-momentum, participation, price-location, market-context, and checkpoint-path diagnostics."),
  "",
  "## Boundary",
  "",
  "Every comparison uses the already inspected 2021-2023 discovery sample. Asset-paired bootstrap intervals are descriptive, not validation p-values. No cell is a promoted filter, no parent mechanic changed, and 2024+ remained excluded."
)
writeLines(report, file.path(output_dir, "hyp_mom_01_1_da_report.md"), useBytes = TRUE)

message("HYP-MOM-01.1 Diagnostic Atlas 01 complete: ", normalizePath(output_dir, winslash = "/"))
print(asset_contrasts)
print(checkpoint_summary)
