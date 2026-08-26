# Transport the frozen own-asset return-geometry microscope across a balanced
# 30-asset atlas. Full 9 x 9 surfaces are descriptive. HAC inference is limited
# to the seven TSLA-discovered cells frozen before atlas results are read.

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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "tsla_signed_er20_grid.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_1_atr_percent.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "own_asset_return_geometry_atlas.R"))
g5_load_local_renviron(repo_root)

cfg <- g5_load_data_layer_config(repo_root)
contract <- oarga_contract()
registry_path <- file.path(
  repo_root, "operator_hypothesis_lab", "registries", "own_asset_return_geometry_atlas.csv"
)
registry <- oarga_validate_registry(utils::read.csv(
  registry_path, stringsAsFactors = FALSE, check.names = FALSE
), contract)
refresh <- identical(
  tolower(Sys.getenv("GEN5_OWN_ASSET_ATLAS_REFRESH", unset = "false")), "true"
)
as_of_timestamp <- as.POSIXct("2026-08-26 17:30:00", tz = cfg$calendar$timezone)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "own_asset_return_geometry_atlas_20260826"
)
visual_dir <- file.path(output_dir, "visuals")
state_band_dir <- file.path(visual_dir, "asset_state_bands")
dir.create(state_band_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(state_band_dir)) oarga_stop("Could not create atlas output directories.")

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$analysis_end,
  as_of_timestamp = as_of_timestamp,
  symbols = registry$symbol,
  universe_name = "own_asset_return_geometry_atlas_01",
  universe_roles = rep("predeclared_balanced_atlas_member", nrow(registry)),
  refresh = refresh,
  repo_root = repo_root
)
g5_write_workbench_query_artifacts(query, output_dir, "atlas_query")

coverage <- query$symbol_coverage
coverage_ok <- coverage$symbol %in% registry$symbol &
  !coverage$is_empty & coverage$covers_requested_range &
  as.Date(coverage$first_session) <= contract$query_start &
  as.Date(coverage$last_session) >= contract$analysis_end
if (nrow(coverage) != nrow(registry) || !all(coverage_ok) ||
    !identical(sort(as.character(coverage$symbol)), sort(registry$symbol))) {
  failed <- setdiff(registry$symbol, coverage$symbol[coverage_ok])
  oarga_stop(paste(
    "Atlas cache coverage is incomplete; rerun with GEN5_OWN_ASSET_ATLAS_REFRESH=true. Symbols:",
    paste(failed, collapse = ", ")
  ))
}

message("Atlas coverage admitted: ", nrow(registry), " assets across ",
        length(unique(registry$behavior_group)), " balanced groups.")

ledgers <- vector("list", nrow(registry))
names(ledgers) <- registry$symbol
state_results <- vector("list", nrow(registry))
comparison_results <- vector("list", nrow(registry))
sign_results <- vector("list", nrow(registry))
fixed_results <- vector("list", nrow(registry))

for (i in seq_len(nrow(registry))) {
  symbol <- registry$symbol[[i]]
  message(sprintf("[%02d/%02d] %s", i, nrow(registry), symbol))
  ledger <- oarga_build_ledger(query$bars, symbol, contract)
  measured <- oarga_measure_asset(ledger, contract)
  ledgers[[symbol]] <- ledger
  state_results[[i]] <- measured$state
  comparison_results[[i]] <- measured$comparison
  sign_results[[i]] <- measured$sign
  fixed_results[[i]] <- oarga_fixed_inference(ledger, contract)
}

state_cells <- do.call(rbind, state_results)
comparison_cells <- do.call(rbind, comparison_results)
sign_cells <- do.call(rbind, sign_results)
fixed_cells <- do.call(rbind, fixed_results)
rownames(state_cells) <- rownames(comparison_cells) <- rownames(sign_cells) <- rownames(fixed_cells) <- NULL

attach_registry <- function(x) {
  out <- merge(x, registry[c("atlas_order", "symbol", "behavior_group", "instrument_type", "selection_role")],
               by = "symbol", all.x = TRUE, sort = FALSE)
  out[order(out$atlas_order), , drop = FALSE]
}
state_cells <- attach_registry(state_cells)
comparison_cells <- attach_registry(comparison_cells)
sign_cells <- attach_registry(sign_cells)
fixed_cells <- attach_registry(fixed_cells)

fixed_cells$transport_cell_bh_q_value <- NA_real_
for (test_id in unique(fixed_cells$test_id)) {
  rows <- fixed_cells$test_id == test_id & fixed_cells$symbol != "TSLA" & is.finite(fixed_cells$hac_p_value)
  fixed_cells$transport_cell_bh_q_value[rows] <- stats::p.adjust(fixed_cells$hac_p_value[rows], method = "BH")
}
fixed_cells$global_fixed_family_bh_q_value <- NA_real_
estimable_fixed <- is.finite(fixed_cells$hac_p_value)
fixed_cells$global_fixed_family_bh_q_value[estimable_fixed] <-
  stats::p.adjust(fixed_cells$hac_p_value[estimable_fixed], method = "BH")

expected_state_rows <- nrow(registry) * 81L * 9L
expected_comparison_rows <- nrow(registry) * 81L * 7L
expected_sign_rows <- nrow(registry) * 81L * 9L
expected_fixed_rows <- nrow(registry) * 7L

parity_packet <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "tsla_signed_er20_conditioned_grid_20260826"
)
if (!dir.exists(parity_packet)) oarga_stop("Frozen TSLA signed-ER20 packet is missing for parity validation.")

parity_compare <- function(current, frozen, keys, mapping, check_id) {
  current <- current[current$symbol == "TSLA" & current$condition == "SIGNED_ER20", , drop = FALSE]
  frozen <- utils::read.csv(file.path(parity_packet, frozen), stringsAsFactors = FALSE, check.names = FALSE)
  if ("state" %in% keys && "direction_state" %in% names(frozen)) {
    names(frozen)[names(frozen) == "direction_state"] <- "state"
  }
  for (name in names(mapping)) names(frozen)[names(frozen) == mapping[[name]]] <- name
  columns <- c(keys, names(mapping))
  aligned <- merge(current[columns], frozen[columns], by = keys, suffixes = c("_atlas", "_frozen"), sort = TRUE)
  differences <- unlist(lapply(names(mapping), function(column) {
    abs(aligned[[paste0(column, "_atlas")]] - aligned[[paste0(column, "_frozen")]])
  }))
  data.frame(
    check_id = check_id,
    expected_rows = nrow(frozen), observed_rows = nrow(aligned),
    maximum_absolute_difference = max(differences, na.rm = TRUE),
    passed = nrow(aligned) == nrow(frozen) && max(differences, na.rm = TRUE) < 1e-12,
    stringsAsFactors = FALSE
  )
}

parity_state <- parity_compare(
  state_cells, "state_grid_statistics.csv",
  c("state", "prior_sessions", "forward_sessions"),
  c(
    observations = "observations", pearson_correlation = "pearson_correlation",
    spearman_correlation = "spearman_correlation", ols_slope = "ols_slope",
    mean_forward_return = "mean_forward_return", probability_forward_up = "probability_forward_up"
  ),
  "signed_er20_state_surface_exact"
)
parity_comparison <- parity_compare(
  comparison_cells, "state_pair_comparison_statistics.csv",
  c("reference_state", "contrast_state", "prior_sessions", "forward_sessions"),
  c(
    reference_observations = "reference_observations",
    contrast_observations = "contrast_observations",
    reference_pearson_correlation = "reference_pearson_correlation",
    contrast_pearson_correlation = "contrast_pearson_correlation",
    contrast_minus_reference_pearson = "contrast_minus_reference_pearson",
    contrast_minus_reference_ols_slope = "contrast_minus_reference_ols_slope"
  ),
  "signed_er20_state_comparisons_exact"
)
parity_sign <- parity_compare(
  sign_cells, "state_prior_sign_asymmetry_statistics.csv",
  c("state", "prior_sessions", "forward_sessions"),
  c(
    observations = "observations", negative_observations = "negative_observations",
    positive_observations = "positive_observations",
    negative_pearson_correlation = "negative_pearson_correlation",
    positive_pearson_correlation = "positive_pearson_correlation",
    positive_minus_negative_pearson = "positive_minus_negative_pearson",
    positive_minus_negative_ols_slope = "positive_minus_negative_ols_slope",
    negative_mean_forward_return = "negative_mean_forward_return",
    positive_mean_forward_return = "positive_mean_forward_return"
  ),
  "signed_er20_prior_sign_surface_exact"
)
tsla_parity <- rbind(parity_state, parity_comparison, parity_sign)

grid_checks <- data.frame(
  check_id = c(
    "registry_exact", "coverage_complete", "state_rows_exact", "comparison_rows_exact",
    "sign_rows_exact", "fixed_inference_rows_exact", "horizon_grid_exact",
    "analysis_window_sealed", "tsla_parity_exact", "all_assets_have_all_states",
    "no_full_surface_inferential_scan"
  ),
  passed = c(
    identical(registry, oarga_expected_registry()),
    all(coverage_ok),
    nrow(state_cells) == expected_state_rows,
    nrow(comparison_cells) == expected_comparison_rows,
    nrow(sign_cells) == expected_sign_rows,
    nrow(fixed_cells) == expected_fixed_rows,
    identical(sort(unique(state_cells$prior_sessions)), contract$horizons) &&
      identical(sort(unique(state_cells$forward_sessions)), contract$horizons),
    all(vapply(ledgers, function(x) max(x$session_date) <= contract$analysis_end, logical(1))),
    all(tsla_parity$passed),
    all(vapply(ledgers, function(x) {
      analysis <- x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end
      all(c("RED_SIDEWAYS", "GREEN_TRENDING") %in% unique(x$er20_state[analysis])) &&
        all(c("LOW", "MEDIUM", "HIGH") %in% unique(x$atrp_state[analysis])) &&
        all(c("UP_TREND", "SIDEWAYS", "DOWN_TREND") %in% unique(x$signed_er20_state[analysis]))
    }, logical(1))),
    !any(grepl("p_value|q_value|standard_error|lower_95|upper_95", names(state_cells))) &&
      !any(grepl("p_value|q_value|standard_error|lower_95|upper_95", names(sign_cells)))
  ),
  observed = c(
    "30 assets; six groups; five assets per group",
    paste0(sum(coverage_ok), "/", nrow(registry)),
    paste(nrow(state_cells), expected_state_rows, sep = "/"),
    paste(nrow(comparison_cells), expected_comparison_rows, sep = "/"),
    paste(nrow(sign_cells), expected_sign_rows, sep = "/"),
    paste(nrow(fixed_cells), expected_fixed_rows, sep = "/"),
    paste(contract$horizons, collapse = ","),
    as.character(max(vapply(ledgers, function(x) as.numeric(max(x$session_date)), numeric(1))), origin = "1970-01-01"),
    paste(tsla_parity$maximum_absolute_difference, collapse = ","),
    "ER20, ATRP, and signed ER20 state sets present for every asset",
    "HAC/BH limited to seven frozen TSLA cells"
  ),
  stringsAsFactors = FALSE
)
if (!all(grid_checks$passed)) {
  oarga_stop(paste("Atlas checks failed:", paste(grid_checks$check_id[!grid_checks$passed], collapse = ", ")))
}

split_summary <- function(data, keys, value = "pearson_correlation") {
  groups <- split(data, interaction(data[keys], drop = TRUE, lex.order = TRUE))
  rows <- lapply(groups, function(x) {
    values <- x[[value]][is.finite(x[[value]])]
    base <- x[1L, keys, drop = FALSE]
    base$asset_count <- length(values)
    base$median_value <- if (length(values)) stats::median(values) else NA_real_
    base$mean_value <- if (length(values)) mean(values) else NA_real_
    base$q25_value <- if (length(values)) unname(stats::quantile(values, 0.25)) else NA_real_
    base$q75_value <- if (length(values)) unname(stats::quantile(values, 0.75)) else NA_real_
    base$positive_asset_fraction <- if (length(values)) mean(values > 0) else NA_real_
    base
  })
  out <- do.call(rbind, rows); rownames(out) <- NULL; out
}

cell_summary <- split_summary(
  state_cells[state_cells$estimation_status == "DESCRIBED", , drop = FALSE],
  c("condition", "state", "prior_sessions", "forward_sessions")
)
group_cell_summary <- split_summary(
  state_cells[state_cells$estimation_status == "DESCRIBED", , drop = FALSE],
  c("behavior_group", "condition", "state", "prior_sessions", "forward_sessions")
)

tsla_maps <- state_cells[state_cells$symbol == "TSLA",
  c("condition", "state", "prior_sessions", "forward_sessions", "pearson_correlation")]
names(tsla_maps)[names(tsla_maps) == "pearson_correlation"] <- "tsla_pearson"
transport_maps <- merge(
  state_cells[state_cells$symbol != "TSLA", , drop = FALSE], tsla_maps,
  by = c("condition", "state", "prior_sessions", "forward_sessions"), sort = FALSE
)
transport_maps$same_sign_as_tsla <- sign(transport_maps$pearson_correlation) == sign(transport_maps$tsla_pearson)

map_groups <- split(
  transport_maps,
  interaction(transport_maps$symbol, transport_maps$condition, transport_maps$state, drop = TRUE, lex.order = TRUE)
)
map_similarity <- do.call(rbind, lapply(map_groups, function(x) data.frame(
  symbol = x$symbol[[1L]], behavior_group = x$behavior_group[[1L]],
  condition = x$condition[[1L]], state = x$state[[1L]], cells = nrow(x),
  cellwise_correlation_vs_tsla = stats::cor(x$pearson_correlation, x$tsla_pearson),
  sign_agreement_vs_tsla = mean(x$same_sign_as_tsla),
  median_absolute_cell_difference = stats::median(abs(x$pearson_correlation - x$tsla_pearson)),
  stringsAsFactors = FALSE
)))
rownames(map_similarity) <- NULL

fixed_transport <- fixed_cells[fixed_cells$symbol != "TSLA", , drop = FALSE]
tsla_fixed <- fixed_cells[fixed_cells$symbol == "TSLA", c("test_id", "effect", "descriptive_correlation_effect")]
names(tsla_fixed)[2:3] <- c("tsla_effect", "tsla_correlation_effect")
fixed_transport <- merge(fixed_transport, tsla_fixed, by = "test_id", sort = FALSE)
fixed_transport$same_effect_sign_as_tsla <- sign(fixed_transport$effect) == sign(fixed_transport$tsla_effect)
fixed_transport$same_correlation_sign_as_tsla <-
  sign(fixed_transport$descriptive_correlation_effect) == sign(fixed_transport$tsla_correlation_effect)

fixed_groups <- split(fixed_transport, fixed_transport$test_id)
fixed_summary <- do.call(rbind, lapply(fixed_groups, function(x) data.frame(
  test_id = x$test_id[[1L]], test_family = x$test_family[[1L]],
  condition = x$condition[[1L]], state = x$state[[1L]],
  prior_sessions = x$prior_sessions[[1L]], forward_sessions = x$forward_sessions[[1L]],
  transport_assets = nrow(x), estimable_assets = sum(is.finite(x$hac_p_value)),
  median_effect = stats::median(x$effect, na.rm = TRUE),
  median_correlation_effect = stats::median(x$descriptive_correlation_effect, na.rm = TRUE),
  same_effect_sign_fraction_vs_tsla = mean(x$same_effect_sign_as_tsla, na.rm = TRUE),
  same_correlation_sign_fraction_vs_tsla = mean(x$same_correlation_sign_as_tsla, na.rm = TRUE),
  raw_p_below_05_assets = sum(x$hac_p_value < 0.05, na.rm = TRUE),
  transport_cell_bh_passes = sum(x$transport_cell_bh_q_value < 0.05, na.rm = TRUE),
  global_fixed_family_bh_passes = sum(x$global_fixed_family_bh_q_value < 0.05, na.rm = TRUE),
  stringsAsFactors = FALSE
)))
rownames(fixed_summary) <- NULL

fixed_group_groups <- split(
  fixed_transport,
  interaction(fixed_transport$test_id, fixed_transport$behavior_group, drop = TRUE, lex.order = TRUE)
)
fixed_group_summary <- do.call(rbind, lapply(fixed_group_groups, function(x) data.frame(
  test_id = x$test_id[[1L]], behavior_group = x$behavior_group[[1L]],
  asset_count = nrow(x), median_effect = stats::median(x$effect, na.rm = TRUE),
  median_correlation_effect = stats::median(x$descriptive_correlation_effect, na.rm = TRUE),
  same_correlation_sign_fraction_vs_tsla = mean(x$same_correlation_sign_as_tsla, na.rm = TRUE),
  stringsAsFactors = FALSE
)))
rownames(fixed_group_summary) <- NULL

leave_one_out <- do.call(rbind, lapply(fixed_groups, function(x) do.call(rbind, lapply(x$symbol, function(held_out) {
  kept <- x[x$symbol != held_out, , drop = FALSE]
  data.frame(
    test_id = x$test_id[[1L]], held_out_symbol = held_out,
    remaining_assets = nrow(kept), median_effect = stats::median(kept$effect, na.rm = TRUE),
    median_correlation_effect = stats::median(kept$descriptive_correlation_effect, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))))
rownames(leave_one_out) <- NULL

pooled_down <- do.call(rbind, lapply(registry$symbol, function(symbol) {
  surface <- oarga_construct_surface(ledgers[[symbol]], 20L, 20L, contract)
  x <- surface[surface$signed_er20_state == "DOWN_TREND", , drop = FALSE]
  x$behavior_group <- registry$behavior_group[registry$symbol == symbol]
  x
}))
rownames(pooled_down) <- NULL

occupancy <- do.call(rbind, lapply(registry$symbol, function(symbol) {
  x <- ledgers[[symbol]]
  x <- x[x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end, , drop = FALSE]
  make <- function(condition, values, levels) {
    counts <- table(factor(values, levels = levels))
    data.frame(symbol = symbol, condition = condition, state = levels,
               sessions = as.integer(counts), fraction = as.integer(counts) / sum(counts), stringsAsFactors = FALSE)
  }
  rbind(
    make("ER20", x$er20_state, c("RED_SIDEWAYS", "GREEN_TRENDING")),
    make("ATRP", x$atrp_state, c("LOW", "MEDIUM", "HIGH")),
    make("SIGNED_ER20", x$signed_er20_state, c("UP_TREND", "SIDEWAYS", "DOWN_TREND"))
  )
}))
occupancy <- attach_registry(occupancy)

write_csv <- function(x, name) utils::write.csv(x, file.path(output_dir, name), row.names = FALSE, na = "NA")
write_csv(registry, "frozen_atlas_registry.csv")
write_csv(grid_checks, "atlas_checks.csv")
write_csv(tsla_parity, "tsla_parity_checks.csv")
write_csv(state_cells, "asset_state_grid_cells.csv")
write_csv(comparison_cells, "asset_state_comparison_cells.csv")
write_csv(sign_cells, "asset_prior_sign_cells.csv")
write_csv(fixed_cells, "frozen_replication_inference.csv")
write_csv(cell_summary, "equal_asset_cell_summary.csv")
write_csv(group_cell_summary, "behavior_group_cell_summary.csv")
write_csv(map_similarity, "asset_map_similarity_to_tsla.csv")
write_csv(fixed_summary, "frozen_replication_summary.csv")
write_csv(fixed_group_summary, "frozen_replication_group_summary.csv")
write_csv(leave_one_out, "frozen_replication_leave_one_asset_out.csv")
write_csv(pooled_down, "pooled_signed_er20_down_p20_f20_scatter.csv")
write_csv(occupancy, "asset_state_occupancy.csv")

run_spec <- data.frame(
  field = c(
    "atlas_id", "asset_count", "group_count", "assets_per_group", "provider", "bar_type",
    "query_start", "analysis_start", "analysis_end", "as_of_timestamp", "returns",
    "horizons", "er20", "atrp", "signed_er20", "full_surface_inference",
    "frozen_inference_cells", "pooling", "fine_horizon_search", "post_2023_data", "trading_calculation"
  ),
  value = c(
    contract$atlas_id, nrow(registry), length(unique(registry$behavior_group)), contract$assets_per_group,
    "Alpaca SIP", "adjusted daily OHLCV", as.character(contract$query_start),
    as.character(contract$analysis_start), as.character(contract$analysis_end),
    format(as_of_timestamp, tz = cfg$calendar$timezone), "cumulative log close-to-close",
    paste(contract$horizons, collapse = ","), "absolute signed ER20; cutoff 0.30",
    "Wilder ATR14/close; prior-252 percentile; 30/40 and 60/70 hysteresis",
    "signed ER20; cutoff +/-0.30", "none; descriptive morphology only",
    "four unfiltered sign cells plus signed-ER20 DOWN 20/20 state, DOWN-minus-SIDEWAYS 20/20, and DOWN sign 5/20",
    "equal asset weighting; raw pooled rows shown only with same-date dependence warning",
    "none; 6-9 sessions remain closed", "none", "none"
  ),
  stringsAsFactors = FALSE
)
write_csv(run_spec, "run_spec.csv")

group_colors <- c(
  "Operator high beta" = "#C74C4C", "Mature growth" = "#2E78B7",
  "Cyclical or value" = "#C28D2C", "Defensive equity" = "#4B9B75",
  "Equity ETF" = "#7A64B5", "Non-equity proxy" = "#6D7A86"
)
signed_colors <- c(UP_TREND = "#2A9D6F", SIDEWAYS = "#B9C0C8", DOWN_TREND = "#C64B4B")
er_colors <- c(RED_SIDEWAYS = "#D66A6A", GREEN_TRENDING = "#58A87A")
atr_colors <- c(LOW = "#74A7E8", MEDIUM = "#D6B85E", HIGH = "#DD7777")

state_spans <- function(dates, states) {
  keep <- !is.na(states)
  dates <- dates[keep]; states <- states[keep]
  groups <- split(seq_along(dates), cumsum(c(TRUE, states[-1L] != states[-length(states)])))
  do.call(rbind, lapply(groups, function(i) data.frame(
    state = states[[min(i)]], start = dates[[min(i)]], end = dates[[max(i)]], stringsAsFactors = FALSE
  )))
}
draw_bands <- function(spans, colors, y_min, y_max) {
  for (i in seq_len(nrow(spans))) graphics::rect(
    spans$start[[i]], y_min, spans$end[[i]] + 1, y_max,
    col = grDevices::adjustcolor(colors[spans$state[[i]]], alpha.f = 0.25), border = NA
  )
}
for (symbol in registry$symbol) {
  x <- ledgers[[symbol]]
  x <- x[x$session_date >= contract$analysis_start & x$session_date <= contract$analysis_end, , drop = FALSE]
  grDevices::png(file.path(state_band_dir, paste0(tolower(symbol), "_state_bands.png")), width = 1900, height = 1200, res = 170)
  graphics::par(mfrow = c(3L, 1L), mar = c(2.3, 4.5, 3.3, 1.2), oma = c(2.0, 0, 2.0, 0), family = "sans")
  yr <- range(x$close)
  graphics::plot(x$session_date, x$close, type = "n", xlab = "", ylab = "Adjusted close", main = paste(symbol, "signed ER20 direction"))
  draw_bands(state_spans(x$session_date, x$signed_er20_state), signed_colors, yr[[1L]], yr[[2L]])
  graphics::lines(x$session_date, x$close, col = "#25364B", lwd = 1.2)
  graphics::plot(x$session_date, x$er20, type = "n", ylim = c(0, 1), xlab = "", ylab = "ER20", main = "Path efficiency: red sideways / green trending")
  draw_bands(state_spans(x$session_date, x$er20_state), er_colors, 0, 1)
  graphics::lines(x$session_date, x$er20, col = "#25364B", lwd = 0.9); graphics::abline(h = contract$er_cutoff, lty = 2, col = "#59687A")
  graphics::plot(x$session_date, x$atr_percentile, type = "n", ylim = c(0, 1), xlab = "Session", ylab = "ATR% percentile", main = "Movement capacity: causal prior-252 ATR% state")
  draw_bands(state_spans(x$session_date, x$atrp_state), atr_colors, 0, 1)
  graphics::lines(x$session_date, x$atr_percentile, col = "#25364B", lwd = 0.9)
  graphics::abline(h = c(.3, .4, .6, .7), lty = 3, col = "#7A8795")
  graphics::mtext("Frozen 2018-2023 template | Colors are state labels, not return forecasts", outer = TRUE, side = 1, line = 0.5, cex = 0.82, col = "#5D6978")
  grDevices::dev.off()
}

matrix_from <- function(data, value, condition, state) {
  x <- data[data$condition == condition & data$state == state, , drop = FALSE]
  out <- matrix(NA_real_, nrow = length(contract$horizons), ncol = length(contract$horizons),
                dimnames = list(contract$horizons, contract$horizons))
  for (i in seq_len(nrow(x))) out[as.character(x$prior_sessions[[i]]), as.character(x$forward_sessions[[i]])] <- x[[value]][[i]]
  out
}
draw_heat <- function(values, title, limit, annotate = FALSE) {
  palette <- grDevices::colorRampPalette(c("#C64B4B", "#F7F8FA", "#2A79C5"))(201)
  graphics::image(seq_along(contract$horizons), seq_along(contract$horizons), t(values),
    col = palette, zlim = c(-limit, limit), axes = FALSE, xlab = "Following", ylab = "Prior", main = title)
  graphics::axis(1, at = seq_along(contract$horizons), labels = contract$horizons, tick = FALSE, cex.axis = .62)
  graphics::axis(2, at = seq_along(contract$horizons), labels = contract$horizons, tick = FALSE, las = 1, cex.axis = .62)
  if (annotate) for (r in seq_along(contract$horizons)) for (c in seq_along(contract$horizons)) {
    graphics::text(c, r, sprintf("%+.2f", values[r, c]), cex = .58,
      col = if (abs(values[r, c]) > .55 * limit) "white" else "#26364A")
  }
  graphics::box(col = "#C8CED6")
}

down_cells <- state_cells[state_cells$condition == "SIGNED_ER20" & state_cells$state == "DOWN_TREND", , drop = FALSE]
atlas_limit <- max(abs(down_cells$pearson_correlation), na.rm = TRUE)
grDevices::png(file.path(visual_dir, "signed_er20_down_asset_heatmap_atlas.png"), width = 3000, height = 3500, res = 180)
graphics::par(mfrow = c(6L, 5L), mar = c(3.1, 3.4, 3.0, .6), oma = c(2.0, 2.0, 3.2, 0), family = "sans")
for (symbol in registry$symbol) {
  values <- matrix_from(down_cells[down_cells$symbol == symbol, , drop = FALSE], "pearson_correlation", "SIGNED_ER20", "DOWN_TREND")
  draw_heat(values, symbol, atlas_limit, FALSE)
}
graphics::mtext("Signed-ER20 DOWN-state prior-versus-forward Pearson maps | one common scale", outer = TRUE, side = 3, line = 1.1, cex = 1.25, font = 2)
grDevices::dev.off()

median_down <- matrix_from(cell_summary, "median_value", "SIGNED_ER20", "DOWN_TREND")
grDevices::png(file.path(visual_dir, "signed_er20_down_equal_asset_median_heatmap.png"), width = 1450, height = 1250, res = 180)
graphics::par(mar = c(5.0, 5.3, 4.8, 1.2), family = "sans")
draw_heat(median_down, "Equal-asset median Pearson correlation in signed-ER20 DOWN states", max(abs(median_down), na.rm = TRUE), TRUE)
graphics::mtext("Thirty assets; every asset receives one vote per cell", side = 3, line = .5, cex = .82, col = "#617083")
grDevices::dev.off()

island <- down_cells[down_cells$prior_sessions == 20L & down_cells$forward_sessions == 20L, , drop = FALSE]
island <- island[order(island$behavior_group, island$pearson_correlation), , drop = FALSE]
grDevices::png(file.path(visual_dir, "signed_er20_down_p20_f20_asset_effects.png"), width = 1700, height = 1500, res = 180)
graphics::par(mar = c(5.0, 11.0, 4.8, 1.5), family = "sans")
graphics::plot(island$pearson_correlation, seq_len(nrow(island)), pch = 19,
  col = group_colors[island$behavior_group], xlim = range(c(0, island$pearson_correlation)),
  yaxt = "n", ylab = "", xlab = "Pearson correlation", main = "Does TSLA's DOWN-state 20/20 rebound shape transport?")
graphics::axis(2, at = seq_len(nrow(island)), labels = island$symbol, las = 1, tick = FALSE, cex.axis = .72)
graphics::abline(v = 0, col = "#66717F", lty = 2)
graphics::points(island$pearson_correlation[island$symbol == "TSLA"], which(island$symbol == "TSLA"), pch = 21, bg = "white", col = "#111827", cex = 1.5, lwd = 1.8)
graphics::legend("bottomright", legend = names(group_colors), col = group_colors, pch = 19, cex = .67, bty = "n")
grDevices::dev.off()

grDevices::png(file.path(visual_dir, "pooled_signed_er20_down_p20_f20_scatter.png"), width = 1800, height = 1400, res = 180)
graphics::par(mar = c(5.2, 5.5, 4.8, 1.2), family = "sans")
graphics::plot(pooled_down$prior_cumulative_log_return, pooled_down$forward_cumulative_log_return,
  pch = 16, cex = .45, col = grDevices::adjustcolor(group_colors[pooled_down$behavior_group], alpha.f = .28),
  xlab = "Prior 20-session cumulative log return", ylab = "Following 20-session cumulative log return",
  main = "Raw pooled DOWN-state 20/20 observations")
graphics::abline(h = 0, v = 0, col = "#ABB3BD", lty = 3)
graphics::legend("topright", legend = names(group_colors), col = group_colors, pch = 19, cex = .75, bty = "n")
graphics::mtext("Visual morphology only: same-date asset rows are dependent and are not independent replications", side = 3, line = .45, cex = .78, col = "#9B3D3D")
grDevices::dev.off()

breadth_matrix <- matrix(NA_real_, nrow = nrow(fixed_summary), ncol = length(unique(registry$behavior_group)),
  dimnames = list(fixed_summary$test_id, unique(registry$behavior_group)))
for (i in seq_len(nrow(fixed_group_summary))) breadth_matrix[
  fixed_group_summary$test_id[[i]], fixed_group_summary$behavior_group[[i]]
] <- fixed_group_summary$same_correlation_sign_fraction_vs_tsla[[i]]
grDevices::png(file.path(visual_dir, "frozen_replication_group_breadth.png"), width = 1900, height = 1200, res = 180)
graphics::par(mar = c(11.0, 15.0, 4.7, 1.0), family = "sans")
graphics::image(seq_len(ncol(breadth_matrix)), seq_len(nrow(breadth_matrix)), t(breadth_matrix),
  col = grDevices::colorRampPalette(c("#F5F6F8", "#2A79C5"))(101), zlim = c(0, 1), axes = FALSE,
  xlab = "", ylab = "", main = "Same-sign breadth versus the frozen TSLA effects")
graphics::axis(1, at = seq_len(ncol(breadth_matrix)), labels = colnames(breadth_matrix), las = 2, tick = FALSE, cex.axis = .72)
graphics::axis(2, at = seq_len(nrow(breadth_matrix)), labels = rownames(breadth_matrix), las = 1, tick = FALSE, cex.axis = .62)
for (r in seq_len(nrow(breadth_matrix))) for (c in seq_len(ncol(breadth_matrix))) graphics::text(c, r, sprintf("%.0f%%", 100 * breadth_matrix[r, c]), cex = .72, col = if (breadth_matrix[r, c] > .62) "white" else "#24364B")
graphics::box(col = "#C7CDD5")
grDevices::dev.off()

down_transport <- island[island$symbol != "TSLA", , drop = FALSE]
down_same_sign <- mean(sign(down_transport$pearson_correlation) == sign(island$pearson_correlation[island$symbol == "TSLA"]))
down_negative_fraction <- mean(down_transport$pearson_correlation < 0)
down_median <- stats::median(down_transport$pearson_correlation)
median_down_rows <- cell_summary[cell_summary$condition == "SIGNED_ER20" & cell_summary$state == "DOWN_TREND", , drop = FALSE]
top_median_down <- median_down_rows[which.max(abs(median_down_rows$median_value)), , drop = FALSE]
signed_map_similarity <- map_similarity[map_similarity$condition == "SIGNED_ER20", , drop = FALSE]
median_map_similarity <- stats::median(signed_map_similarity$cellwise_correlation_vs_tsla, na.rm = TRUE)
fixed_down_state <- fixed_summary[fixed_summary$test_id == "SIGNED_ER20_DOWN_STATE_P20_F20", , drop = FALSE]
fixed_down_sign <- fixed_summary[fixed_summary$test_id == "SIGNED_ER20_DOWN_SIGN_P5_F20", , drop = FALSE]

status <- if (down_negative_fraction >= 0.60) {
  "DESCRIPTIVE_ATLAS_COMPLETE_DOWN_REBOUND_TRANSPORTS_BROADLY_STOP_BEFORE_FINE_GRID"
} else {
  "DESCRIPTIVE_ATLAS_COMPLETE_DOWN_REBOUND_TSLA_CONCENTRATED_STOP_BEFORE_FINE_GRID"
}

report <- c(
  "# Own-Asset Return-Geometry Atlas",
  "",
  "## Question",
  "",
  "Does the frozen TSLA return-geometry microscope reveal similar shapes across a predeclared balanced atlas, before any finer horizon grid is opened?",
  "",
  "## Frozen Atlas",
  "",
  paste0("- Thirty assets in six equal five-asset groups: `", paste(unique(registry$behavior_group), collapse = "`, `"), "`."),
  "- Asset membership and ordering were committed to the registry before atlas results were read.",
  "- TSLA remains the discovery reference; the other 29 assets are transport observations, not fresh independent time samples.",
  "",
  "## Frozen Microscope",
  "",
  paste0("- Prior and following horizons remain `", paste(contract$horizons, collapse = ", "), "` sessions. The proposed 6-9-session refinement was not run."),
  "- Every asset receives the same unfiltered, ER20, ATR%, signed-ER20, and prior-sign branch surfaces.",
  "- Full 9 x 9 maps are descriptive morphology. HAC and BH calculations are restricted to seven TSLA-discovered cells frozen before transport.",
  "- The TSLA signed-ER20 state, comparison, and prior-sign surfaces reproduce the preceding packet exactly (maximum numeric difference below 1e-12).",
  "",
  "## Principal Transport Readout",
  "",
  sprintf("- At signed-ER20 DOWN prior 20 / following 20, `%d/29` transport assets have negative correlations, matching the TSLA rebound sign in `%.1f%%` of assets. The equal-asset median correlation is `%+.4f`.", sum(down_transport$pearson_correlation < 0), 100 * down_same_sign, down_median),
  sprintf("- The strongest equal-asset median DOWN-state cell is prior `%d` / following `%d`, with median Pearson `%+.4f` across `%d` assets.", top_median_down$prior_sessions, top_median_down$forward_sessions, top_median_down$median_value, top_median_down$asset_count),
  sprintf("- Across the full signed-ER20 maps, the median asset-level cell-map correlation with TSLA is `%+.4f`. This measures shape similarity, not predictive performance.", median_map_similarity),
  sprintf("- For the frozen DOWN 20/20 state-slope test, the transport median slope is `%+.4f`; `%.1f%%` of assets share TSLA's correlation sign, and `%d/29` survive BH within that fixed cell.", fixed_down_state$median_effect, 100 * fixed_down_state$same_correlation_sign_fraction_vs_tsla, fixed_down_state$transport_cell_bh_passes),
  sprintf("- For the frozen DOWN prior-sign 5/20 interaction, the transport median slope contrast is `%+.4f`; `%.1f%%` share TSLA's correlation-difference sign, and `%d/29` survive BH within that fixed cell.", fixed_down_sign$median_effect, 100 * fixed_down_sign$same_correlation_sign_fraction_vs_tsla, fixed_down_sign$transport_cell_bh_passes),
  "",
  "## Interpretation",
  "",
  "- A repeated broad neighborhood is more informative than one asset's darkest cell. The atlas therefore reports equal-asset medians, same-sign breadth, group summaries, map similarity, and leave-one-asset-out summaries.",
  "- The raw pooled scatter is a visualization only. Same-date observations share market shocks and must not be treated as independent replications.",
  "- Signed ER20 and prior return remain mechanically related trailing-path variables in every asset. Cross-asset repetition can weaken a TSLA-idiosyncrasy explanation, but it cannot remove conditioning geometry.",
  "- No asset-specific horizon, state cutoff, or best cell was selected. No post-2023 data, strategy rule, cost model, or performance calculation was opened.",
  "",
  "## Decision",
  "",
  paste0("Status: `", status, "`."),
  "",
  "Keep 6-9-session horizons closed until the operator reviews whether the transported shape is broad and coherent enough to justify one separately frozen local refinement. The next decision is interpretation, not automatic optimization.",
  "",
  "## Key Artifacts",
  "",
  "- `frozen_atlas_registry.csv`: exact predeclared asset membership and groups.",
  "- `asset_state_grid_cells.csv`, `asset_state_comparison_cells.csv`, and `asset_prior_sign_cells.csv`: complete descriptive microscope surfaces.",
  "- `frozen_replication_inference.csv` and `frozen_replication_summary.csv`: the seven predeclared transport tests.",
  "- `equal_asset_cell_summary.csv`, `behavior_group_cell_summary.csv`, `asset_map_similarity_to_tsla.csv`, and leave-one-asset-out summaries: cross-asset shape evidence.",
  "- `visuals/asset_state_bands/`: one consistent metric/state chart per asset.",
  "- Other files in `visuals/`: signed-DOWN atlas, equal-asset heatmap, fixed-cell effect plot, pooled scatter, and group breadth map."
)
writeLines(report, file.path(output_dir, "report.md"))
write_csv(data.frame(status = status, stringsAsFactors = FALSE), "atlas_status.csv")

cat("Own-asset return-geometry atlas complete.\n")
cat("Status:", status, "\n")
cat(sprintf("DOWN P20/F20: %d/29 negative; transport median r=%+.4f.\n", sum(down_transport$pearson_correlation < 0), down_median))
cat("Artifacts:", normalizePath(output_dir, winslash = "/"), "\n")
