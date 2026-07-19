# Gen5.4 cross-sectional asset-selection POC X0/X1.
#
# X0 audits a frozen 24-stock candidate panel and six context anchors.
# X1 measures predeclared univariate cross-sectional relationships. It fits no
# model, selects no top-K portfolio policy, and does not touch live advice.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
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
source(file.path(repo_root, "R", "gen54_cross_sectional_poc.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) g5_stop(paste0("Could not create output directory: ", path))
  invisible(path)
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

annual_coverage <- function(bars, symbols, reference_symbol = "SPY") {
  bars$year <- format(as.Date(bars$session_date), "%Y")
  ref <- bars[bars$symbol == reference_symbol, , drop = FALSE]
  reference <- aggregate(ref$session_date, list(year = ref$year), function(x) length(unique(x)))
  names(reference)[[2L]] <- "reference_sessions"
  rows <- lapply(symbols, function(symbol) {
    part <- bars[bars$symbol == symbol, , drop = FALSE]
    if (nrow(part)) {
      observed <- aggregate(part$session_date, list(year = part$year), function(x) length(unique(x)))
      names(observed)[[2L]] <- "observed_sessions"
    } else {
      observed <- data.frame(year = character(), observed_sessions = integer(), stringsAsFactors = FALSE)
    }
    out <- merge(reference, observed, by = "year", all.x = TRUE)
    out$observed_sessions[is.na(out$observed_sessions)] <- 0L
    out$symbol <- symbol
    out$coverage_ratio <- out$observed_sessions / out$reference_sessions
    out[, c("symbol", "year", "observed_sessions", "reference_sessions", "coverage_ratio")]
  })
  do.call(rbind, rows)
}

universe_manifest <- function(bars, registry, coverage) {
  rows <- lapply(registry$symbol, function(symbol) {
    part <- bars[bars$symbol == symbol, , drop = FALSE]
    coverage_part <- coverage[coverage$symbol == symbol & coverage$year %in% as.character(2018:2024), , drop = FALSE]
    if (!nrow(part)) {
      return(data.frame(
        symbol = symbol,
        economic_group = registry$economic_group[match(symbol, registry$symbol)],
        first_session = as.Date(NA),
        last_session = as.Date(NA),
        minimum_annual_coverage_2018_2024 = 0,
        median_dollar_volume_2018_2024 = NA_real_,
        fixed_panel_status = "REVIEW_REQUIRED",
        stringsAsFactors = FALSE
      ))
    }
    dollar_volume <- part$close * part$volume
    data.frame(
      symbol = symbol,
      economic_group = registry$economic_group[match(symbol, registry$symbol)],
      first_session = min(as.Date(part$session_date)),
      last_session = max(as.Date(part$session_date)),
      minimum_annual_coverage_2018_2024 = min(coverage_part$coverage_ratio, na.rm = TRUE),
      median_dollar_volume_2018_2024 = stats::median(dollar_volume[format(as.Date(part$session_date), "%Y") %in% as.character(2018:2024)], na.rm = TRUE),
      fixed_panel_status = if (
        min(as.Date(part$session_date)) <= as.Date("2017-01-03") &&
        max(as.Date(part$session_date)) >= as.Date("2024-12-31") &&
        min(coverage_part$coverage_ratio, na.rm = TRUE) >= 0.98
      ) "PASS" else "REVIEW_REQUIRED",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

write_coverage_heatmap <- function(coverage, registry, path) {
  years <- as.character(2018:2024)
  symbols <- registry$symbol
  matrix_values <- matrix(NA_real_, nrow = length(symbols), ncol = length(years), dimnames = list(symbols, years))
  for (i in seq_len(nrow(coverage))) {
    if (coverage$symbol[[i]] %in% symbols && coverage$year[[i]] %in% years) {
      matrix_values[coverage$symbol[[i]], coverage$year[[i]]] <- coverage$coverage_ratio[[i]]
    }
  }
  grDevices::png(path, width = 1600, height = 1100, res = 150)
  old <- graphics::par(mar = c(6, 7, 4, 2))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  graphics::image(seq_along(years), seq_along(symbols), t(matrix_values), col = grDevices::colorRampPalette(c("#DC2626", "#FDE68A", "#2563EB"))(100), zlim = c(0.90, 1), axes = FALSE, xlab = "", ylab = "", main = "Historical session coverage is complete across the frozen candidate panel")
  graphics::axis(1, at = seq_along(years), labels = years)
  graphics::axis(2, at = seq_along(symbols), labels = symbols, las = 1, cex.axis = 0.75)
  graphics::box()
}

write_eligible_count <- function(panel, path) {
  counts <- unique(panel[, c("feature_date", "eligible_count")])
  counts <- counts[counts$feature_date >= as.Date("2018-01-01") & counts$feature_date <= as.Date("2024-12-31"), , drop = FALSE]
  counts <- counts[order(counts$feature_date), , drop = FALSE]
  grDevices::png(path, width = 1600, height = 800, res = 150)
  old <- graphics::par(mar = c(5, 5, 4, 2))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  graphics::plot(counts$feature_date, counts$eligible_count, type = "l", lwd = 2, col = "#2563EB", ylim = c(0, 24), xlab = "Feature date", ylab = "Point-in-time eligible candidates", main = "The contemporaneous cross-section remains wide enough for ranking")
  graphics::abline(h = 20, lty = 2, col = "#DC2626")
  graphics::legend("bottomright", legend = c("Eligible candidates", "Frozen minimum = 20"), col = c("#2563EB", "#DC2626"), lty = c(1, 2), lwd = c(2, 1), bty = "n")
}

write_ic_heatmap <- function(fold_summary, path) {
  features <- g5_gen54_xs_feature_names()
  folds <- unique(fold_summary$fold_id)
  values <- matrix(NA_real_, nrow = length(features), ncol = length(folds), dimnames = list(features, folds))
  for (i in seq_len(nrow(fold_summary))) values[fold_summary$feature_name[[i]], fold_summary$fold_id[[i]]] <- fold_summary$mean_daily_rank_ic[[i]]
  limit <- max(abs(values), na.rm = TRUE)
  grDevices::png(path, width = 1900, height = 850, res = 150)
  old <- graphics::par(mar = c(8, 13, 4, 2))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  colors <- grDevices::colorRampPalette(c("#DC2626", "#F8FAFC", "#2563EB"))(101)
  graphics::image(seq_along(folds), seq_along(features), t(values), col = colors, zlim = c(-limit, limit), axes = FALSE, xlab = "", ylab = "", main = "Quarterly cross-sectional rank relationships are the first falsification surface")
  graphics::axis(1, at = seq_along(folds), labels = folds, las = 2, cex.axis = 0.75)
  graphics::axis(2, at = seq_along(features), labels = gsub("_", " ", features), las = 1, cex.axis = 0.8)
  graphics::box()
}

write_ordering_plot <- function(fold_summary, path) {
  features <- g5_gen54_xs_feature_names()
  top <- vapply(features, function(x) mean(fold_summary$top_mean_relative_return_h5[fold_summary$feature_name == x], na.rm = TRUE), numeric(1L))
  middle <- vapply(features, function(x) mean(fold_summary$middle_mean_relative_return_h5[fold_summary$feature_name == x], na.rm = TRUE), numeric(1L))
  bottom <- vapply(features, function(x) mean(fold_summary$bottom_mean_relative_return_h5[fold_summary$feature_name == x], na.rm = TRUE), numeric(1L))
  values <- rbind(Top = top, Middle = middle, Bottom = bottom) * 10000
  grDevices::png(path, width = 1800, height = 900, res = 150)
  old <- graphics::par(mar = c(10, 6, 4, 2))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  graphics::barplot(values, beside = TRUE, col = c("#2563EB", "#94A3B8", "#DC2626"), names.arg = gsub("_", " ", features), las = 2, ylab = "Mean h5 return relative to equal-weight universe (bp)", main = "Fixed cross-sectional bins reveal whether each primitive orders future outcomes")
  graphics::abline(h = 0, col = "#111827")
  graphics::legend("topright", legend = rownames(values), fill = c("#2563EB", "#94A3B8", "#DC2626"), bty = "n")
}

write_verdict_plot <- function(verdict, path) {
  values <- rbind(
    `Positive IC folds` = verdict$positive_ic_folds,
    `Positive ordering folds` = verdict$positive_ordering_folds
  )
  grDevices::png(path, width = 1700, height = 850, res = 150)
  old <- graphics::par(mar = c(10, 6, 4, 2))
  on.exit({ graphics::par(old); grDevices::dev.off() }, add = TRUE)
  graphics::barplot(values, beside = TRUE, col = c("#2563EB", "#7C3AED"), names.arg = gsub("_", " ", verdict$feature_name), las = 2, ylim = c(0, 20), ylab = "Positive quarterly folds out of 20", main = "A primitive must clear both stability gates before model design")
  graphics::abline(h = 12, lty = 2, col = "#DC2626")
  graphics::legend("topright", legend = rownames(values), fill = c("#2563EB", "#7C3AED"), bty = "n")
}

write_report <- function(path, run_spec, manifest, leakage, verdict, paths) {
  passed_symbols <- sum(manifest$fixed_panel_status == "PASS")
  passed_features <- verdict$feature_name[verdict$verdict == "PASS_TO_COMBINATION_DESIGN"]
  lines <- c(
    "# Gen5.4 Cross-Sectional Asset-Selection POC X0/X1",
    "",
    paste0("Status: `", run_spec$overall_status[[1L]], "`"),
    "",
    "## Question",
    "",
    "Can a frozen, diverse, point-in-time eligible panel support stable cross-sectional measurement before any pooled model or top-K portfolio policy is fitted?",
    "",
    "## X0 — Universe integrity",
    "",
    paste0("- Fixed ranked candidates: `", nrow(manifest), "`; fixed-panel coverage PASS: `", passed_symbols, "`.") ,
    "- Candidate identity is frozen for this POC. Daily price, liquidity, and completeness eligibility use information available through the feature date.",
    "- This is a fixed-panel POC with an explicit survivor limitation; it is not a full point-in-time US equity universe simulation.",
    "",
    "## X1 — No-model measurement audit",
    "",
    paste0("- OOS authorities: `", run_spec$fold_count[[1L]], "` quarterly folds with eight preceding TRAIN quarters reserved by contract."),
    "- Features use close-t information; hypothetical execution is next open; the primary target is five-session open-to-open return relative to the same-date equal-weight eligible universe.",
    paste0("- Standalone primitives passing every frozen gate: `", if (length(passed_features)) paste(passed_features, collapse = ", ") else "none", "`."),
    "- No model, threshold search, top-K policy, allocation acceptance, or live behavior was produced.",
    "",
    "## Leakage audit",
    "",
    paste0("- `", leakage$check_id, "`: `", leakage$status, "` — ", leakage$detail),
    "",
    "## Primitive verdicts",
    "",
    paste0("- `", verdict$feature_name, "`: `", verdict$verdict, "`; pooled IC `", sprintf("%.4f", verdict$pooled_mean_daily_rank_ic), "`; positive IC folds `", verdict$positive_ic_folds, "/20`; positive ordering folds `", verdict$positive_ordering_folds, "/20`; top-minus-bottom `", sprintf("%.1f bp", verdict$pooled_top_minus_bottom_h5 * 10000), "`."),
    "",
    "## Next gate",
    "",
    if (length(passed_features) >= 2L) {
      "At least two primitives cleared the standalone measurement gates. The next operator gate is a predeclared pooled linear-ranker design; this packet does not authorize fitting it."
    } else {
      "Fewer than two primitives cleared the standalone measurement gates. Stop before pooled model fitting and revisit the information mechanism or universe contract."
    },
    "",
    "## Key artifacts",
    "",
    paste0("- `", names(paths), "`: `", normalizePath(unlist(paths), winslash = "/", mustWork = FALSE), "`")
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

if (!identical(Sys.getenv("GEN5_GEN54_XS_SOURCE_ONLY", unset = "false"), "true")) {
  message("Gen5.4 cross-sectional POC X0/X1 starting.")
  g5_load_local_renviron(repo_root)
  cfg <- g5_load_data_layer_config(repo_root)
  feed <- env_or("GEN5_GEN54_XS_FEED", as.character(cfg$feed))
  if (nzchar(feed)) cfg$feed <- feed
  refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_XS_REFRESH", "false"), default = FALSE)
  as_of_timestamp <- env_or("GEN5_GEN54_XS_AS_OF", "2024-12-31 17:30:00")
  stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_GEN54_XS_STAMP", "20260719x0x1"))
  output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", paste0("g54_xs_", stamp))
  visual_dir <- file.path(output_dir, "visuals")
  ensure_dir(visual_dir)

  registry <- g5_gen54_xs_candidate_registry()
  context_symbols <- g5_gen54_xs_context_symbols()
  all_symbols <- unique(c(registry$symbol, context_symbols))
  folds <- g5_gen54_xs_build_folds(2020:2024)
  query_start <- as.Date("2016-11-01")
  query_end <- max(folds$oos_end_date)
  query <- g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = query_start,
    end_date = query_end,
    as_of_timestamp = as_of_timestamp,
    symbols = all_symbols,
    universe_name = "gen54_cross_sectional_fixed_panel_v0_1",
    universe_roles = "ranked_candidates,context_anchors",
    refresh = refresh,
    repo_root = repo_root
  )
  if (!nrow(query$bars)) g5_stop("Cross-sectional POC query returned no bars.")
  message("Query complete: ", nrow(query$bars), " bars across ", length(unique(query$bars$symbol)), " symbols.")

  coverage <- annual_coverage(query$bars, all_symbols)
  manifest <- universe_manifest(query$bars, registry, coverage)
  panel <- g5_gen54_xs_build_panel(query$bars, registry, context_symbols)
  message("Aligned cross-sectional panel built: ", nrow(panel), " rows.")
  oos_panel <- g5_gen54_xs_assign_oos(panel, folds)
  message("Quarterly OOS authorities assigned: ", nrow(oos_panel), " rows.")
  daily_ic <- g5_gen54_xs_daily_ic(oos_panel)
  message("Daily rank-IC audit complete: ", nrow(daily_ic), " rows.")
  fold_summary <- g5_gen54_xs_fold_feature_summary(oos_panel, daily_ic)
  message("Fold summaries complete: ", nrow(fold_summary), " rows.")
  verdict <- g5_gen54_xs_feature_verdict(fold_summary, daily_ic)
  leakage <- g5_gen54_xs_leakage_audit(oos_panel)

  overall_status <- if (
    all(manifest$fixed_panel_status == "PASS") &&
    all(leakage$status == "PASS") &&
    sum(verdict$verdict == "PASS_TO_COMBINATION_DESIGN") >= 2L
  ) "PASS_TO_OPERATOR_MODEL_DESIGN_GATE" else "STOP_BEFORE_MODEL_FIT"

  paths <- list(
    run_spec_csv = file.path(output_dir, "xs_run_spec.csv"),
    fold_spec_csv = file.path(output_dir, "xs_fold_spec.csv"),
    universe_registry_csv = file.path(output_dir, "xs_candidate_registry.csv"),
    universe_manifest_csv = file.path(output_dir, "xs_universe_manifest.csv"),
    annual_coverage_csv = file.path(output_dir, "xs_annual_coverage.csv"),
    feature_label_sample_csv = file.path(output_dir, "xs_feature_label_sample.csv"),
    daily_ic_csv = file.path(output_dir, "xs_daily_rank_ic.csv"),
    fold_feature_summary_csv = file.path(output_dir, "xs_fold_feature_summary.csv"),
    feature_verdict_csv = file.path(output_dir, "xs_feature_verdict.csv"),
    leakage_audit_csv = file.path(output_dir, "xs_leakage_audit.csv"),
    report_md = file.path(output_dir, "xs_report.md"),
    coverage_heatmap_png = file.path(visual_dir, "xs_coverage_heatmap.png"),
    eligible_count_png = file.path(visual_dir, "xs_eligible_count.png"),
    ic_heatmap_png = file.path(visual_dir, "xs_rank_ic_heatmap.png"),
    ordering_png = file.path(visual_dir, "xs_outcome_ordering.png"),
    verdict_png = file.path(visual_dir, "xs_verdict.png")
  )
  run_spec <- data.frame(
    schema_version = "gen54_cross_sectional_x0_x1_v0.1",
    wrapper = "scripts/inspect/run_gen54_cross_sectional_measurement_poc.R",
    as_of_timestamp = as_of_timestamp,
    feed = cfg$feed,
    refresh = refresh,
    ranked_candidate_count = nrow(registry),
    context_anchor_count = length(context_symbols),
    fold_count = nrow(folds),
    train_quarters = 8L,
    oos_start = min(folds$oos_start_date),
    oos_end = max(folds$oos_end_date),
    label = "h5_next_open_to_open_minus_same_date_equal_weight_universe",
    minimum_price = 5,
    minimum_trailing_dollar_volume = 2e7,
    minimum_cross_section = 20L,
    required_positive_folds = 12L,
    top_selection_group_concentration_cap = 0.50,
    model_fit_count = 0L,
    overall_status = overall_status,
    output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
    stringsAsFactors = FALSE
  )

  sample_columns <- c(
    "symbol", "economic_group", "feature_date", "execution_date", "label_end_date",
    "cross_section_eligible", "eligible_count", g5_gen54_xs_feature_names(),
    paste0(g5_gen54_xs_feature_names(), "_rank"),
    "absolute_forward_return_h5", "equal_weight_universe_forward_return_h5", "relative_forward_return_h5"
  )
  sample <- oos_panel[oos_panel$cross_section_eligible & oos_panel$label_inside_oos, sample_columns, drop = FALSE]
  sample <- sample[seq_len(min(1000L, nrow(sample))), , drop = FALSE]

  write_coverage_heatmap(coverage, registry, paths$coverage_heatmap_png)
  write_eligible_count(panel, paths$eligible_count_png)
  write_ic_heatmap(fold_summary, paths$ic_heatmap_png)
  write_ordering_plot(fold_summary, paths$ordering_png)
  write_verdict_plot(verdict, paths$verdict_png)

  write_csv(run_spec, paths$run_spec_csv)
  write_csv(folds, paths$fold_spec_csv)
  write_csv(registry, paths$universe_registry_csv)
  write_csv(manifest, paths$universe_manifest_csv)
  write_csv(coverage, paths$annual_coverage_csv)
  write_csv(sample, paths$feature_label_sample_csv)
  write_csv(daily_ic, paths$daily_ic_csv)
  write_csv(fold_summary, paths$fold_feature_summary_csv)
  write_csv(verdict, paths$feature_verdict_csv)
  write_csv(leakage, paths$leakage_audit_csv)
  write_report(paths$report_md, run_spec, manifest, leakage, verdict, paths)

  message("Gen5.4 cross-sectional POC X0/X1 complete.")
  message("Status: ", overall_status)
  message("Output: ", normalizePath(output_dir, winslash = "/", mustWork = FALSE))
  message("Report: ", normalizePath(paths$report_md, winslash = "/", mustWork = FALSE))
}
