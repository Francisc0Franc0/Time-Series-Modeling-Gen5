options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R", "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R")) source(file.path(repo_root, "R", f))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_05_2_triple_sma_grid_wfa.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
percent <- function(x, digits = 1L) ifelse(is.na(x), "NA", paste0(formatC(100 * x, digits = digits, format = "f"), "%"))
attach_fields <- function(x, fields) {
  if (!nrow(x)) return(cbind(fields[rep(1L, 0L), , drop = FALSE], x))
  cbind(fields[rep(1L, nrow(x)), , drop = FALSE], x, stringsAsFactors = FALSE)
}

contract <- h052_validate_contract(); grid <- h052_grid(contract); blocks <- h052_blocks(); folds <- h052_folds()
original <- utils::read.csv(file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_mom_01_1_discovery_registry.csv"), stringsAsFactors = FALSE)
wide <- utils::read.csv(file.path(repo_root, "literature_studies", "registries", "gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv"), stringsAsFactors = FALSE)
registry <- rbind(
  data.frame(instance_id = original$instance_id, symbol = original$symbol, cohort = "ORIGINAL_22", sector = original$sector, source_registry = original$source_registry),
  data.frame(instance_id = wide$instance_id, symbol = wide$symbol, cohort = wide$cohort, sector = wide$sector, source_registry = wide$source_id)
)
if (nrow(registry) != 122L || anyDuplicated(registry$symbol) || length(unique(registry$sector)) != 11L) stop("Frozen combined registry integrity failed.", call. = FALSE)

run_id <- env_or("GEN5_HYP_MOM_052_RUN_ID", "hyp_mom_05_2_triple_sma_grid_wfa_20260813")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals"); dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
cfg <- g5_load_data_layer_config(repo_root); refresh <- env_bool("GEN5_HYP_MOM_052_REFRESH", FALSE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg, start_date = as.Date("2020-06-01"), end_date = contract$development_end,
  as_of_timestamp = contract$as_of_timestamp, symbols = c(registry$symbol, "SPY"),
  universe_name = "hyp_mom_05_2_triple_sma_grid_wfa", universe_roles = "frozen_combined_122,spy_calendar",
  refresh = refresh, repo_root = repo_root
)
bars_all <- query$bars; bars_all$session_date <- as.Date(bars_all$session_date)
if (any(bars_all$session_date >= contract$confirmation_start)) stop("Confirmation bars entered development.", call. = FALSE)
if (anyDuplicated(bars_all[c("symbol", "session_date")])) stop("Duplicate queried bars.", call. = FALSE)
spy_dates <- sort(unique(bars_all$session_date[bars_all$symbol == "SPY" & bars_all$session_date >= contract$development_start & bars_all$session_date <= contract$development_end]))
if (!length(spy_dates)) stop("SPY development calendar unavailable.", call. = FALSE)

coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]; x <- bars_all[bars_all$symbol == reg$symbol, , drop = FALSE]; x <- x[order(x$session_date), , drop = FALSE]
  invalid <- if (!nrow(x)) 0L else sum(!is.finite(x$open) | !is.finite(x$high) | !is.finite(x$low) | !is.finite(x$close) | !is.finite(x$volume) | x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)
  observed <- x$session_date[x$session_date >= contract$development_start & x$session_date <= contract$development_end]
  missing <- length(setdiff(spy_dates, observed)); prehistory <- sum(x$session_date < contract$development_start)
  status <- if (!nrow(x)) "NO_HISTORY" else if (invalid > 0L) "INVALID_OHLCV" else if (missing > 0L) "DEVELOPMENT_INCOMPLETE" else if (prehistory < contract$prehistory_sessions) "PREHISTORY_INCOMPLETE" else "ELIGIBLE"
  cbind(reg, data.frame(observed_rows = nrow(x), development_missing_sessions = missing, prehistory_sessions = prehistory,
                        invalid_ohlcv_rows = invalid, coverage_status = status, analysis_eligible = status == "ELIGIBLE"))
}))
eligible <- registry[registry$symbol %in% coverage$symbol[coverage$analysis_eligible], , drop = FALSE]
if (!nrow(eligible)) stop("No registered asset passed coverage.", call. = FALSE)

checkpoint_dir <- file.path(output_dir, "checkpoints"); dir.create(checkpoint_dir, recursive = TRUE, showWarnings = FALSE)
asset_rows <- vector("list", nrow(grid))
message("HYP-MOM-05.2 grid evaluation: ", nrow(grid), " candidates x ", nrow(eligible), " assets x ", nrow(blocks), " blocks.")
for (g in seq_len(nrow(grid))) {
  candidate <- grid[g, , drop = FALSE]
  checkpoint <- file.path(checkpoint_dir, paste0(candidate$candidate_id, ".rds"))
  if (file.exists(checkpoint)) {
    cached <- readRDS(checkpoint)
    valid <- nrow(cached) == nrow(eligible) * nrow(blocks) * 3L &&
      identical(unique(cached$candidate_id), candidate$candidate_id) &&
      setequal(unique(cached$instance_id), eligible$instance_id)
    if (!valid) stop("Invalid HYP-MOM-05.2 candidate checkpoint: ", candidate$candidate_id, call. = FALSE)
    message(sprintf("[%02d/%02d] %s | checkpoint", g, nrow(grid), candidate$candidate_id))
    asset_rows[[g]] <- cached
    next
  }
  message(sprintf("[%02d/%02d] %s | compute", g, nrow(grid), candidate$candidate_id))
  local_rows <- list(); z <- 0L
  for (i in seq_len(nrow(eligible))) {
    reg <- eligible[i, , drop = FALSE]
    state <- h052_state(bars_all[bars_all$symbol == reg$symbol, , drop = FALSE], candidate, contract)
    for (b in seq_len(nrow(blocks))) {
      block <- blocks[b, , drop = FALSE]
      for (policy in c("H052", "SMA_MEDIUM_ONLY", "ORDERED_STACK_ONLY")) {
        schedule <- h052_schedule(state, block$start_date, block$end_date, policy)
        z <- z + 1L
        fields <- cbind(reg[c("instance_id", "cohort", "sector")], candidate, block["block_id"])
        local_rows[[z]] <- attach_fields(h052_replay_fast_1x(state, schedule, contract$primary_cost_bps), fields)
      }
    }
  }
  asset_rows[[g]] <- do.call(rbind, local_rows); rownames(asset_rows[[g]]) <- NULL
  saveRDS(asset_rows[[g]], checkpoint)
}
grid_asset_metrics <- do.call(rbind, asset_rows); rownames(grid_asset_metrics) <- NULL
selection <- h052_run_selection(grid_asset_metrics, contract)
block_scorecard <- selection$block_scorecard; selection_surface <- selection$selection_surface; selected <- selection$selections

selected$neighbor_count_in_plateau <- vapply(seq_len(nrow(selected)), function(i) {
  neighbors <- h052_grid_neighbors(grid, selected$candidate_id[[i]])
  plateau <- selection_surface$candidate_id[selection_surface$fold == selected$fold[[i]] & selection_surface$in_tolerance_set]
  sum(neighbors %in% plateau)
}, integer(1))
selected$test_block_score <- NA_real_; selected$test_block_percentile <- NA_real_; selected$test_block_best_candidate <- NA_character_
for (i in seq_len(nrow(selected))) {
  test <- block_scorecard[block_scorecard$block_id == selected$test_block[[i]], , drop = FALSE]
  selected$test_block_score[[i]] <- test$block_composite[test$candidate_id == selected$candidate_id[[i]]]
  selected$test_block_percentile[[i]] <- h052_fractional_rank(test$block_composite)[test$candidate_id == selected$candidate_id[[i]]]
  selected$test_block_best_candidate[[i]] <- test$candidate_id[order(-test$block_composite, test$candidate_id)][[1L]]
}

fold_summary_rows <- fold_path_rows <- fold_trade_rows <- random_rows <- list(); sidx <- pidx <- tidx <- ridx <- 0L
scenarios <- data.frame(scenario = c("GROSS", "PRIMARY", "STRESS"), cost_bps = c(0, contract$primary_cost_bps, contract$stress_cost_bps), financing_rate = c(0, contract$primary_financing_rate, contract$stress_financing_rate))
message("HYP-MOM-05.2 selected-policy outer replay.")
for (f in seq_len(nrow(selected))) {
  candidate <- grid[grid$candidate_id == selected$candidate_id[[f]], , drop = FALSE]
  block <- blocks[blocks$block_id == selected$test_block[[f]], , drop = FALSE]
  message(sprintf("Fold %d | %s | %s", selected$fold[[f]], block$block_id, candidate$candidate_id))
  for (i in seq_len(nrow(eligible))) {
    reg <- eligible[i, , drop = FALSE]
    state <- h052_state(bars_all[bars_all$symbol == reg$symbol, , drop = FALSE], candidate, contract)
    fields <- cbind(reg[c("instance_id", "cohort", "sector")], candidate,
                    data.frame(fold = selected$fold[[f]], block_id = block$block_id, stringsAsFactors = FALSE))
    for (policy in c("H052", "SMA_MEDIUM_ONLY", "ORDERED_STACK_ONLY", "BUY_HOLD")) {
      schedule <- h052_schedule(state, block$start_date, block$end_date, policy)
      local_scenarios <- if (policy == "H052") scenarios else scenarios[scenarios$scenario == "PRIMARY", , drop = FALSE]
      for (lev in contract$leverages) for (q in seq_len(nrow(local_scenarios))) {
        scenario <- local_scenarios[q, ]
        replay <- h052_replay(state, schedule, lev, scenario$cost_bps, scenario$financing_rate, contract)
        sidx <- sidx + 1L; pidx <- pidx + 1L; tidx <- tidx + 1L
        summary_fields <- cbind(fields, data.frame(scenario = scenario$scenario, stringsAsFactors = FALSE))
        fold_summary_rows[[sidx]] <- attach_fields(replay$summary, summary_fields)
        fold_path_rows[[pidx]] <- attach_fields(replay$path, summary_fields)
        fold_trade_rows[[tidx]] <- attach_fields(replay$trades, summary_fields)
      }
      if (policy == "H052") for (lev_index in seq_along(contract$leverages)) {
        lev <- contract$leverages[[lev_index]]
        w <- state[schedule$row_index, , drop = FALSE]
        values <- h052_circular_controls(w$open, schedule$target_long, lev, contract,
                                         seed_offset = f * 100000L + i * 1000L + lev_index * 100L)
        ridx <- ridx + 1L
        random_fields <- cbind(reg[c("instance_id", "symbol", "cohort", "sector")], candidate,
                               data.frame(fold = selected$fold[[f]], block_id = block$block_id, stringsAsFactors = FALSE))
        random_rows[[ridx]] <- cbind(random_fields[rep(1L, length(values)), , drop = FALSE],
                                     data.frame(leverage = lev, simulation_id = seq_along(values), fold_return = values))
      }
    }
  }
}
fold_summaries <- do.call(rbind, fold_summary_rows); fold_paths <- do.call(rbind, fold_path_rows)
fold_trades <- do.call(rbind, fold_trade_rows); random_fold_controls <- do.call(rbind, random_rows)
rownames(fold_summaries) <- rownames(fold_paths) <- rownames(fold_trades) <- rownames(random_fold_controls) <- NULL

stitch_group <- function(p) {
  p <- p[order(p$fold, p$session_date), , drop = FALSE]
  factors <- numeric(nrow(p))
  for (fold in unique(p$fold)) {
    rows <- which(p$fold == fold); local <- p$wealth_open[rows]
    factors[rows] <- c(local[[1L]], local[-1L] / head(local, -1L))
  }
  p$stitched_wealth <- cumprod(factors); p$stitched_drawdown <- h052_drawdown(p$stitched_wealth)
  p
}
path_groups <- split(fold_paths, interaction(fold_paths$instance_id, fold_paths$policy, fold_paths$leverage, fold_paths$scenario, drop = TRUE))
stitched_paths <- do.call(rbind, lapply(path_groups, stitch_group)); rownames(stitched_paths) <- NULL

summary_groups <- split(stitched_paths, interaction(stitched_paths$instance_id, stitched_paths$policy, stitched_paths$leverage, stitched_paths$scenario, drop = TRUE))
stitched_summaries <- do.call(rbind, lapply(summary_groups, function(p) {
  trades <- fold_trades[fold_trades$instance_id == p$instance_id[[1L]] & fold_trades$policy == p$policy[[1L]] &
                          fold_trades$leverage == p$leverage[[1L]] & fold_trades$scenario == p$scenario[[1L]], , drop = FALSE]
  finite_eff <- p$effective_leverage[is.finite(p$effective_leverage)]
  data.frame(instance_id = p$instance_id[[1L]], symbol = p$symbol[[1L]], cohort = p$cohort[[1L]], sector = p$sector[[1L]],
             policy = p$policy[[1L]], leverage = p$leverage[[1L]], scenario = p$scenario[[1L]],
             total_return = tail(p$stitched_wealth, 1L) - 1, sharpe = h052_sharpe(p$stitched_wealth),
             maximum_drawdown = min(p$stitched_drawdown), time_underwater = mean(p$stitched_drawdown < 0),
             exposure_fraction = mean(head(p$target_long, -1L)), trade_count = nrow(trades), turnover_events = 2L * nrow(trades),
             activation_entries = sum(trades$entry_reason == "ORDER_ACTIVATION"), reclaim_entries = sum(trades$entry_reason == "MEDIUM_RECLAIM"),
             hit_rate = if (nrow(trades)) mean(trades$equity_trade_return > 0) else NA_real_,
             median_trade_return = if (nrow(trades)) stats::median(trades$equity_trade_return) else NA_real_,
             median_holding_sessions = if (nrow(trades)) stats::median(trades$holding_sessions) else NA_real_,
             total_financing_cost = sum(trades$financing_cost), minimum_equity = min(p$stitched_wealth),
             maximum_effective_leverage = if (length(finite_eff)) max(finite_eff) else NA_real_,
             maintenance_breach_sessions = sum(p$equity_ratio < contract$maintenance_equity_ratio, na.rm = TRUE),
             nonpositive_equity = any(p$stitched_wealth <= 0), stringsAsFactors = FALSE)
}))
rownames(stitched_summaries) <- NULL

random_compounded <- h052_compound_fold_controls(random_fold_controls)
main <- stitched_summaries[stitched_summaries$policy == "H052" & stitched_summaries$scenario == "PRIMARY", , drop = FALSE]
main$random_median_return <- NA_real_; main$random_percentile <- NA_real_
for (i in seq_len(nrow(main))) {
  controls <- random_compounded$total_return[random_compounded$instance_id == main$instance_id[[i]] & random_compounded$leverage == main$leverage[[i]]]
  main$random_median_return[[i]] <- stats::median(controls)
  main$random_percentile[[i]] <- mean(controls <= main$total_return[[i]])
}
stitched_summaries <- merge(stitched_summaries, main[c("instance_id", "leverage", "random_median_return", "random_percentile")], by = c("instance_id", "leverage"), all.x = TRUE)
main <- stitched_summaries[stitched_summaries$policy == "H052" & stitched_summaries$scenario == "PRIMARY", , drop = FALSE]

baseline <- stitched_summaries[stitched_summaries$policy != "H052" & stitched_summaries$scenario == "PRIMARY", , drop = FALSE]
baseline_comparisons <- merge(
  main[c("instance_id", "symbol", "cohort", "sector", "leverage", "total_return", "maximum_drawdown")],
  baseline[c("instance_id", "leverage", "policy", "total_return", "maximum_drawdown")],
  by = c("instance_id", "leverage"), suffixes = c("_h052", "_baseline"), all.x = TRUE
)
baseline_comparisons$excess_return <- baseline_comparisons$total_return_h052 - baseline_comparisons$total_return_baseline
baseline_comparisons$drawdown_improvement <- baseline_comparisons$maximum_drawdown_h052 - baseline_comparisons$maximum_drawdown_baseline

fold_primary <- fold_summaries[fold_summaries$policy == "H052" & fold_summaries$scenario == "PRIMARY", , drop = FALSE]
fold_panel <- do.call(rbind, lapply(split(fold_primary, interaction(fold_primary$fold, fold_primary$leverage, drop = TRUE)), function(x) data.frame(
  fold = x$fold[[1L]], block_id = x$block_id[[1L]], candidate_id = x$candidate_id[[1L]], leverage = x$leverage[[1L]], asset_count = nrow(x),
  median_return = stats::median(x$total_return), positive_assets = sum(x$total_return > 0), median_sharpe = median_na(x$sharpe),
  median_maximum_drawdown = stats::median(x$maximum_drawdown), median_exposure = stats::median(x$exposure_fraction),
  trade_count = sum(x$trade_count), stringsAsFactors = FALSE
)))

panel_summary <- do.call(rbind, lapply(split(main, main$leverage), function(x) data.frame(
  leverage = x$leverage[[1L]], asset_count = nrow(x), trade_count = sum(x$trade_count), median_return = stats::median(x$total_return),
  positive_assets = sum(x$total_return > 0), median_sharpe = median_na(x$sharpe), median_maximum_drawdown = stats::median(x$maximum_drawdown),
  median_time_underwater = stats::median(x$time_underwater), median_exposure = stats::median(x$exposure_fraction),
  median_hit_rate = median_na(x$hit_rate), median_trade_return = median_na(x$median_trade_return),
  median_holding_sessions = median_na(x$median_holding_sessions), median_random_percentile = median_na(x$random_percentile),
  assets_above_random_80 = sum(x$random_percentile > .8), maintenance_breach_assets = sum(x$maintenance_breach_sessions > 0),
  nonpositive_equity_assets = sum(x$nonpositive_equity), median_financing_cost = stats::median(x$total_financing_cost), stringsAsFactors = FALSE
)))
sector_summary <- do.call(rbind, lapply(split(main[main$leverage == 1, ], main$sector[main$leverage == 1]), function(x) data.frame(
  sector = x$sector[[1L]], asset_count = nrow(x), median_return = stats::median(x$total_return), positive_assets = sum(x$total_return > 0),
  median_maximum_drawdown = stats::median(x$maximum_drawdown), median_random_percentile = stats::median(x$random_percentile), stringsAsFactors = FALSE
)))
cohort_summary <- do.call(rbind, lapply(split(main[main$leverage == 1, ], main$cohort[main$leverage == 1]), function(x) data.frame(
  cohort = x$cohort[[1L]], asset_count = nrow(x), median_return = stats::median(x$total_return), positive_assets = sum(x$total_return > 0),
  median_maximum_drawdown = stats::median(x$maximum_drawdown), median_random_percentile = stats::median(x$random_percentile), stringsAsFactors = FALSE
)))
selected_trades <- fold_trades[fold_trades$policy == "H052" & fold_trades$scenario == "PRIMARY", , drop = FALSE]
entry_summary <- do.call(rbind, lapply(split(selected_trades, interaction(selected_trades$leverage, selected_trades$entry_reason, drop = TRUE)), function(x) data.frame(
  leverage = x$leverage[[1L]], entry_reason = x$entry_reason[[1L]], trade_count = nrow(x),
  hit_rate = mean(x$equity_trade_return > 0), median_trade_return = stats::median(x$equity_trade_return),
  median_holding_sessions = stats::median(x$holding_sessions), median_mae = stats::median(x$maximum_adverse_excursion),
  median_mfe = stats::median(x$maximum_favorable_excursion), stringsAsFactors = FALSE
)))
cost_summary <- do.call(rbind, lapply(split(stitched_summaries[stitched_summaries$policy == "H052", ], interaction(stitched_summaries$leverage[stitched_summaries$policy == "H052"], stitched_summaries$scenario[stitched_summaries$policy == "H052"], drop = TRUE)), function(x) data.frame(
  leverage = x$leverage[[1L]], scenario = x$scenario[[1L]], asset_count = nrow(x), median_return = stats::median(x$total_return),
  positive_assets = sum(x$total_return > 0), median_maximum_drawdown = stats::median(x$maximum_drawdown), stringsAsFactors = FALSE
)))

main1 <- main[main$leverage == 1, ]; comparisons1 <- baseline_comparisons[baseline_comparisons$leverage == 1, ]
baseline_medians <- aggregate(excess_return ~ policy, comparisons1, stats::median)
fold1 <- fold_panel[fold_panel$leverage == 1, ]
integrity <- data.frame(
  check = c("registered_122", "unique_symbols", "eleven_sectors", "grid_27", "six_blocks", "four_outer_folds", "explicit_as_of",
            "confirmation_excluded", "full_development_calendar", "prehistory_130", "no_replacements", "global_selection",
            "selection_uses_1x", "block_cash_start", "block_boundary_cash", "all_candidates_scored", "random_controls_500"),
  passed = c(nrow(registry) == 122L, !anyDuplicated(registry$symbol), length(unique(registry$sector)) == 11L, nrow(grid) == 27L,
             nrow(blocks) == 6L, length(folds) == 4L, nzchar(contract$as_of_timestamp), !any(bars_all$session_date >= contract$confirmation_start),
             all(coverage$development_missing_sessions[coverage$analysis_eligible] == 0L),
             all(coverage$prehistory_sessions[coverage$analysis_eligible] >= contract$prehistory_sessions),
             nrow(eligible) == sum(coverage$analysis_eligible), nrow(selected) == 4L && !anyDuplicated(selected$fold),
             all(grid_asset_metrics$leverage == 1),
             all(!fold_paths$in_position_after_open[
               !duplicated(interaction(fold_paths$instance_id, fold_paths$policy, fold_paths$leverage, fold_paths$scenario, fold_paths$fold)) & fold_paths$policy != "BUY_HOLD"
             ]),
             all(!fold_paths$in_position_after_open[!duplicated(interaction(fold_paths$instance_id, fold_paths$policy, fold_paths$leverage, fold_paths$scenario, fold_paths$fold), fromLast = TRUE)]),
             nrow(block_scorecard) == nrow(grid) * nrow(blocks),
             all(table(random_compounded$instance_id, random_compounded$leverage) == contract$random_simulations))
)
if (!all(integrity$passed)) stop(paste("HYP-MOM-05.2 integrity failed:", paste(integrity$check[!integrity$passed], collapse = ", ")), call. = FALSE)

gate_table <- data.frame(
  gate = c("integrity", "positive_median_return", "positive_asset_majority", "three_of_four_positive_folds",
           "beats_all_direct_baselines", "matched_timing_control", "broad_training_plateau"),
  passed = c(all(integrity$passed), stats::median(main1$total_return) > 0, sum(main1$total_return > 0) > nrow(main1) / 2,
             sum(fold1$median_return > 0) >= contract$minimum_positive_folds,
             all(baseline_medians$excess_return > 0),
             stats::median(main1$random_percentile) > .5 && mean(main1$random_percentile > .8) >= contract$minimum_high_random_fraction,
             all(selected$plateau_size >= contract$minimum_plateau_size)),
  estimate = c(1, stats::median(main1$total_return), mean(main1$total_return > 0), sum(fold1$median_return > 0),
               min(baseline_medians$excess_return), stats::median(main1$random_percentile), min(selected$plateau_size)),
  threshold = c(1, 0, .5, contract$minimum_positive_folds, 0, .5, contract$minimum_plateau_size), stringsAsFactors = FALSE
)
status <- if (all(gate_table$passed)) "DEVELOPMENT_WFA_PASSED_AWAIT_CONFIRMATION_DECISION" else "STOP_DEVELOPMENT_WFA_FAILED_CONFIRMATION_NOT_RUN"

nearest_symbol <- function(values, target, symbols) symbols[order(abs(values - target), symbols)][[1L]]
manifest <- data.frame(tape_role = c("MEDIAN_RETURN", "HIGHEST_RETURN", "LOWEST_RETURN", "HIGHEST_TRADE_COUNT"),
                       symbol = c(nearest_symbol(main1$total_return, stats::median(main1$total_return), main1$symbol),
                                  main1$symbol[order(-main1$total_return, main1$symbol)][[1L]],
                                  main1$symbol[order(main1$total_return, main1$symbol)][[1L]],
                                  main1$symbol[order(-main1$trade_count, main1$symbol)][[1L]]), stringsAsFactors = FALSE)
for (i in 2:nrow(manifest)) if (manifest$symbol[[i]] %in% manifest$symbol[seq_len(i - 1L)]) {
  candidates <- main1$symbol[order(if (i == 2L) -main1$total_return else if (i == 3L) main1$total_return else -main1$trade_count, main1$symbol)]
  manifest$symbol[[i]] <- candidates[!candidates %in% manifest$symbol[seq_len(i - 1L)]][[1L]]
}
manifest <- merge(manifest, main1, by = "symbol", all.x = TRUE, sort = FALSE)
manifest <- manifest[match(c("MEDIAN_RETURN", "HIGHEST_RETURN", "LOWEST_RETURN", "HIGHEST_TRADE_COUNT"), manifest$tape_role), ]; manifest$visual_file <- NA_character_

ink <- "#202630"; blue <- "#2C6CB0"; cyan <- "#58B7C7"; green <- "#2E8B57"; red <- "#C83E3A"; gray <- "#D8DEE7"; purple <- "#7654C4"
png(file.path(visual_dir, "coverage_and_design.png"), 1800, 1000, res = 150); par(mfrow = c(1, 3), mar = c(6, 5, 4, 1)); ct <- table(factor(coverage$coverage_status, levels = c("DEVELOPMENT_INCOMPLETE", "PREHISTORY_INCOMPLETE", "ELIGIBLE"))); names(ct) <- c("History incomplete", "Prehistory short", "Eligible"); barplot(ct, col = c(red, red, green), las = 2, main = "Frozen registry coverage", ylab = "Assets"); barplot(sort(table(eligible$sector)), horiz = TRUE, las = 1, col = blue, main = "Eligible assets by sector", xlab = "Assets"); plot.new(); title("Frozen search design"); text(.5, .67, "27 triplets", cex = 1.5, col = purple); text(.5, .50, "6 half-year blocks", cex = 1.35, col = blue); text(.5, .33, "4 causal test folds", cex = 1.35, col = green); dev.off()

latest_fold <- max(selection_surface$fold); latest <- selection_surface[selection_surface$fold == latest_fold, ]
png(file.path(visual_dir, "latest_training_surface.png"), 1800, 1000, res = 150); par(mfrow = c(1, 3), mar = c(4, 3.5, 4, 1), oma = c(2, 2, 0, 0));
for (slow in contract$slow_grid) {
  x <- latest[latest$slow == slow, ]; z <- matrix(NA_real_, nrow = length(contract$fast_grid), ncol = length(contract$medium_grid), dimnames = list(contract$fast_grid, contract$medium_grid))
  for (i in seq_len(nrow(x))) z[as.character(x$fast[[i]]), as.character(x$medium[[i]])] <- x$mean_score[[i]]
  image(seq_along(contract$medium_grid), seq_along(contract$fast_grid), t(z), col = colorRampPalette(c("#F2D7D5", "#FFF7E6", "#D7EBF7", "#2C6CB0"))(30), axes = FALSE, xlab = "", ylab = "", main = paste0("Slow SMA = ", slow)); axis(1, seq_along(contract$medium_grid), contract$medium_grid, cex.axis = .85); axis(2, seq_along(contract$fast_grid), contract$fast_grid, cex.axis = .85)
  for (fi in seq_along(contract$fast_grid)) for (mi in seq_along(contract$medium_grid)) text(mi, fi, sprintf("%.2f", z[fi, mi]), cex = .85)
}
mtext("Medium SMA", side = 1, outer = TRUE, line = .4); mtext("Fast SMA", side = 2, outer = TRUE, line = .4)
dev.off()

png(file.path(visual_dir, "fold_selection_and_transport.png"), 1800, 1000, res = 150); par(mfrow = c(1, 2), mar = c(8, 5, 4, 1)); barplot(selected$mean_score, names.arg = paste0("F", selected$fold, "\n", selected$candidate_id), las = 2, col = blue, ylab = "TRAIN composite", main = "Selected from one-SE plateau"); plot(selected$fold, selected$test_block_percentile, type = "b", pch = 19, lwd = 2, col = ifelse(selected$test_block_percentile > .5, green, red), xaxt = "n", ylim = c(0, 1), xlab = "Test block", ylab = "Selected triplet percentile", main = "Transport into the next half-year"); axis(1, selected$fold, selected$test_block); abline(h = .5, lty = 2, col = gray); dev.off()

png(file.path(visual_dir, "plateau_and_parameter_stability.png"), 1800, 1000, res = 150); par(mfrow = c(1, 2), mar = c(6, 5, 4, 1)); barplot(selected$plateau_size, names.arg = selected$test_block, col = ifelse(selected$plateau_size >= contract$minimum_plateau_size, green, red), ylab = "Candidates in tolerance set", main = "One-SE plateau breadth"); matplot(selected$fold, selected[c("fast", "medium", "slow")], type = "b", pch = 19, lty = 1, lwd = 2, col = c(cyan, blue, purple), xaxt = "n", xlab = "Test block", ylab = "Sessions", main = "Selected horizons across folds"); axis(1, selected$fold, selected$test_block); legend("topleft", c("Fast", "Medium", "Slow"), col = c(cyan, blue, purple), lty = 1, pch = 19, bty = "n"); dev.off()

png(file.path(visual_dir, "oos_baselines_and_folds.png"), 1800, 1000, res = 150); par(mfrow = c(1, 2), mar = c(7, 5, 4, 1));
for (lev in contract$leverages) {
  x <- stitched_summaries[stitched_summaries$leverage == lev & stitched_summaries$scenario == "PRIMARY", ]; med <- tapply(x$total_return, x$policy, stats::median); labels <- c(BUY_HOLD = "Buy & hold", H052 = "Selected H05.2", ORDERED_STACK_ONLY = "Ordered stack", SMA_MEDIUM_ONLY = "Medium SMA")[names(med)]; barplot(med, names.arg = labels, las = 2, col = ifelse(med > 0, green, red), ylab = "Median compounded return", main = paste0("Outer-test result | ", lev, "x")); abline(h = 0, col = ink)
}
dev.off()

png(file.path(visual_dir, "fold_breadth_and_timing_controls.png"), 1800, 1000, res = 150); par(mfrow = c(1, 2), mar = c(5, 5, 4, 1)); barplot(fold1$median_return, names.arg = fold1$block_id, las = 1, col = ifelse(fold1$median_return > 0, green, red), ylab = "Median asset return", main = "Causal half-year transport | 1x"); abline(h = 0); hist(main1$random_percentile, breaks = seq(0, 1, .1), col = blue, border = "white", xlab = "Percentile versus matched shifts", main = "Compounded timing control | 1x"); abline(v = .5, lty = 2); dev.off()

png(file.path(visual_dir, "asset_and_sector_breadth.png"), 1800, 1000, res = 150); par(mfrow = c(1, 2), mar = c(5, 5, 4, 1)); bh <- comparisons1[comparisons1$policy == "BUY_HOLD", ]; plot(bh$total_return_baseline, bh$total_return_h052, pch = 19, col = ifelse(bh$excess_return > 0, green, red), xlab = "Buy-and-hold return", ylab = "Selected H05.2 return", main = "Every dot is one asset | 1x"); abline(0, 1, lty = 2); abline(h = 0, v = 0, col = gray); sx <- sector_summary[order(sector_summary$median_return), ]; barplot(sx$median_return, names.arg = sx$sector, horiz = TRUE, las = 1, col = ifelse(sx$median_return > 0, green, red), xlab = "Median compounded return", main = "Sector breadth | 1x"); abline(v = 0); dev.off()

png(file.path(visual_dir, "cost_and_leverage_diagnostics.png"), 1800, 1000, res = 150); par(mfrow = c(1, 2), mar = c(7, 5, 4, 1)); key <- paste0(cost_summary$leverage, "x\n", cost_summary$scenario); barplot(cost_summary$median_return, names.arg = key, las = 2, col = ifelse(cost_summary$median_return > 0, green, red), ylab = "Median compounded return", main = "Cost and financing sensitivity"); abline(h = 0); x1 <- main[main$leverage == 1, ]; x18 <- main[main$leverage == 1.8, ]; x18 <- x18[match(x1$instance_id, x18$instance_id), ]; plot(x1$total_return, x18$total_return, pch = 19, col = ifelse(x18$total_return > x1$total_return, green, red), xlab = "1x return", ylab = "1.8x return", main = "Fixed-quantity leverage consequence"); abline(0, 1, lty = 2); abline(h = 0, v = 0, col = gray); dev.off()

plot_tape <- function(symbol, role, file) {
  p <- stitched_paths[stitched_paths$symbol == symbol & stitched_paths$policy == "H052" & stitched_paths$leverage == 1 & stitched_paths$scenario == "PRIMARY", ]; p <- p[order(p$fold, p$session_date), ]
  s <- main1[main1$symbol == symbol, ]; tr <- fold_trades[fold_trades$symbol == symbol & fold_trades$policy == "H052" & fold_trades$leverage == 1 & fold_trades$scenario == "PRIMARY", ]
  png(file, 1800, 1100, res = 150); layout(matrix(c(1, 2), 2, 1), heights = c(1.25, 1)); par(mar = c(2, 6, 4, 2)); plot(p$session_date, p$close, type = "l", col = ink, lwd = 1.2, xlab = "", ylab = "Adjusted close", main = paste(gsub("_", " ", role), "|", symbol, "| selected triplet changes only at fold boundaries")); lines(p$session_date, p$sma_fast, col = cyan); lines(p$session_date, p$sma_medium, col = blue, lwd = 1.7); lines(p$session_date, p$sma_slow, col = purple); usr <- par("usr"); long <- which(p$in_position_after_open); if (length(long)) segments(p$session_date[long], usr[[3L]], p$session_date[long], usr[[3L]] + .035 * diff(usr[3:4]), col = adjustcolor(green, .45), lwd = 3); if (nrow(tr)) { points(tr$entry_date, tr$entry_open, pch = 24, bg = green, col = green); points(tr$exit_date, tr$exit_open, pch = 25, bg = red, col = red) }; abline(v = as.Date(c("2022-07-01", "2023-01-03", "2023-07-03")), lty = 3, col = gray); legend("topright", c("Close", "Fast", "Medium", "Slow", "Long"), col = c(ink, cyan, blue, purple, green), lty = 1, lwd = c(1.2, 1, 1.7, 1, 3), bty = "o", bg = "white", ncol = 3, cex = .8)
  par(mar = c(6, 6, 3, 2)); plot(p$session_date, p$stitched_wealth, type = "l", col = green, lwd = 2, xlab = "Session", ylab = "Wealth from 1.0", main = sprintf("Return %.1f%% | max DD %.1f%% | %d trades | hit rate %.1f%%", 100*s$total_return, 100*s$maximum_drawdown, s$trade_count, 100*s$hit_rate)); abline(h = 1, col = gray, lty = 2); dev.off()
}
for (i in seq_len(nrow(manifest))) { file <- file.path(visual_dir, sprintf("grid_wfa_tape_%02d_%s_%s.png", i, tolower(manifest$tape_role[[i]]), tolower(manifest$symbol[[i]]))); plot_tape(manifest$symbol[[i]], manifest$tape_role[[i]], file); manifest$visual_file[[i]] <- basename(file) }

run_spec <- data.frame(hypothesis_id = contract$hypothesis_id, status = status, evidence_stage = contract$evidence_stage,
                       as_of_timestamp = contract$as_of_timestamp, development_start = contract$development_start,
                       development_end = contract$development_end, confirmation_start = contract$confirmation_start,
                       registered_assets = nrow(registry), eligible_assets = nrow(eligible), grid_candidates = nrow(grid),
                       outer_folds = nrow(selected), refresh = refresh, stringsAsFactors = FALSE)
files <- list(run_spec = run_spec, integrity = integrity, gates = gate_table, registry = registry, coverage = coverage,
              query_health = query$health, grid = grid, blocks = blocks, grid_asset_metrics = grid_asset_metrics,
              block_scorecard = block_scorecard, selection_surface = selection_surface, selections = selected,
              fold_summaries = fold_summaries, fold_panel = fold_panel, fold_trades = fold_trades,
              stitched_summaries = stitched_summaries, baseline_comparisons = baseline_comparisons,
              panel_summary = panel_summary, sector_summary = sector_summary, cohort_summary = cohort_summary,
              entry_summary = entry_summary, cost_summary = cost_summary,
              random_compounded = random_compounded, tape_manifest = manifest)
for (name in names(files)) write_csv(files[[name]], file.path(output_dir, paste0("hyp_mom_05_2_", name, ".csv")))

p1 <- panel_summary[panel_summary$leverage == 1, ]; p18 <- panel_summary[panel_summary$leverage == 1.8, ]
report <- c("# HYP-MOM-05.2 Triple-SMA Grid Walk-Forward", "", paste0("Status: `", status, "`"), "",
            sprintf("- Registered / eligible assets: %d / %d", nrow(registry), nrow(eligible)),
            paste0("- Selected triplets: ", paste(paste0(selected$test_block, "=", selected$candidate_id), collapse = "; ")),
            sprintf("- 1x median compounded return / max drawdown: %s / %s", percent(p1$median_return), percent(p1$median_maximum_drawdown)),
            sprintf("- 1x positive assets: %d / %d", p1$positive_assets, p1$asset_count),
            sprintf("- Positive outer test blocks: %d / 4", sum(fold1$median_return > 0)),
            sprintf("- 1x median timing-control percentile: %s; assets above 80th: %d / %d", percent(p1$median_random_percentile), p1$assets_above_random_80, p1$asset_count),
            sprintf("- 1.8x median return / max drawdown: %s / %s", percent(p18$median_return), percent(p18$median_maximum_drawdown)), "",
            paste0("- Gates passed: ", sum(gate_table$passed), " / ", nrow(gate_table), "."),
            "", "This reused-window walk-forward test evaluates the frozen selection policy. It does not authorize grid revision, confirmation access, a portfolio, leverage use, or live behavior.")
writeLines(report, file.path(output_dir, "hyp_mom_05_2_report.md"), useBytes = TRUE)
message("HYP-MOM-05.2 complete: ", output_dir)
