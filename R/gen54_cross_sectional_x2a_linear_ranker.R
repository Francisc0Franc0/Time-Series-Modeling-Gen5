g5_gen54_x2a_method_names <- function() {
  c(
    "group_relative_momentum_20",
    "intraday_minus_overnight_20",
    "fixed_50_50_composite",
    "pooled_linear_ranker"
  )
}

g5_gen54_x2a_build_folds <- function() {
  folds <- g5_gen54_xs_build_folds(2025:2026, train_quarters = 8L)
  folds[folds$fold_id %in% c(
    "2025Q1", "2025Q2", "2025Q3", "2025Q4", "2026Q1", "2026Q2"
  ), , drop = FALSE]
}

g5_gen54_x2a_usable_rows <- function(panel) {
  panel$cross_section_eligible &
    is.finite(panel$group_relative_20_rank) &
    is.finite(panel$intraday_minus_overnight_20_rank) &
    is.finite(panel$relative_forward_return_h5) &
    !is.na(panel$label_end_date)
}

g5_gen54_x2a_rank_by_date <- function(values, dates) {
  out <- rep(NA_real_, length(values))
  keep <- is.finite(values) & !is.na(dates)
  groups <- split(which(keep), dates[keep])
  for (indices in groups) out[indices] <- g5_gen54_xs_rank01(values[indices])
  out
}

g5_gen54_x2a_fit_fold <- function(panel, fold) {
  usable <- g5_gen54_x2a_usable_rows(panel)
  train_keep <- usable &
    panel$feature_date >= fold$train_start_date &
    panel$feature_date <= fold$train_end_date &
    panel$label_end_date <= fold$train_end_date
  oos_keep <- usable &
    panel$feature_date >= fold$oos_start_date &
    panel$feature_date <= fold$oos_end_date &
    panel$label_end_date <= fold$oos_end_date

  train <- panel[train_keep, , drop = FALSE]
  oos <- panel[oos_keep, , drop = FALSE]
  if (!nrow(train)) g5_gen54_xs_stop(paste0("X2a fold ", fold$fold_id, " has no TRAIN rows."))
  if (!nrow(oos)) g5_gen54_xs_stop(paste0("X2a fold ", fold$fold_id, " has no OOS rows."))

  fit <- stats::lm(
    relative_forward_return_h5 ~ group_relative_20_rank + intraday_minus_overnight_20_rank,
    data = train
  )
  coefficients <- stats::coef(fit)
  if (length(coefficients) != 3L || any(!is.finite(coefficients))) {
    g5_gen54_xs_stop(paste0("X2a fold ", fold$fold_id, " produced invalid linear coefficients."))
  }

  score_values <- list(
    group_relative_momentum_20 = oos$group_relative_20_rank,
    intraday_minus_overnight_20 = oos$intraday_minus_overnight_20_rank,
    fixed_50_50_composite = 0.5 * oos$group_relative_20_rank +
      0.5 * oos$intraday_minus_overnight_20_rank,
    pooled_linear_ranker = as.numeric(stats::predict(fit, newdata = oos))
  )
  scored <- do.call(rbind, lapply(names(score_values), function(method) {
    out <- oos[, c(
      "symbol", "economic_group", "feature_date", "execution_date",
      "label_end_date", "relative_forward_return_h5",
      "group_relative_20_rank", "intraday_minus_overnight_20_rank"
    ), drop = FALSE]
    out$fold_id <- fold$fold_id
    out$method <- method
    out$raw_score <- score_values[[method]]
    out$score_rank <- g5_gen54_x2a_rank_by_date(out$raw_score, out$feature_date)
    out
  }))
  rownames(scored) <- NULL

  coefficient_rows <- data.frame(
    fold_id = fold$fold_id,
    term = names(coefficients),
    estimate = as.numeric(coefficients),
    train_rows = nrow(train),
    train_dates = length(unique(train$feature_date)),
    oos_rows = nrow(oos),
    oos_dates = length(unique(oos$feature_date)),
    train_first_feature_date = min(train$feature_date),
    train_last_feature_date = max(train$feature_date),
    train_last_label_end_date = max(train$label_end_date),
    oos_first_feature_date = min(oos$feature_date),
    oos_last_feature_date = max(oos$feature_date),
    oos_last_label_end_date = max(oos$label_end_date),
    stringsAsFactors = FALSE
  )
  list(scored = scored, coefficients = coefficient_rows)
}

g5_gen54_x2a_run_folds <- function(panel, folds = g5_gen54_x2a_build_folds()) {
  results <- lapply(seq_len(nrow(folds)), function(i) {
    g5_gen54_x2a_fit_fold(panel, folds[i, , drop = FALSE])
  })
  list(
    scored = do.call(rbind, lapply(results, `[[`, "scored")),
    coefficients = do.call(rbind, lapply(results, `[[`, "coefficients"))
  )
}

g5_gen54_x2a_daily_ic <- function(scored) {
  keys <- unique(scored[, c("fold_id", "feature_date", "method"), drop = FALSE])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, , drop = FALSE]
    part <- scored[
      scored$fold_id == key$fold_id &
        scored$feature_date == key$feature_date &
        scored$method == key$method,
      , drop = FALSE
    ]
    keep <- is.finite(part$score_rank) & is.finite(part$relative_forward_return_h5)
    data.frame(
      fold_id = key$fold_id,
      feature_date = key$feature_date,
      method = key$method,
      eligible_count = sum(keep),
      rank_ic = if (sum(keep) >= 5L) {
        suppressWarnings(stats::cor(
          part$score_rank[keep],
          part$relative_forward_return_h5[keep],
          method = "spearman"
        ))
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_gen54_x2a_fold_summary <- function(scored, daily_ic) {
  keys <- unique(scored[, c("fold_id", "method"), drop = FALSE])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, , drop = FALSE]
    part <- scored[
      scored$fold_id == key$fold_id & scored$method == key$method,
      , drop = FALSE
    ]
    part$bucket <- ifelse(
      part$score_rank >= 0.80, "top",
      ifelse(part$score_rank <= 0.20, "bottom", "middle")
    )
    top <- part[part$bucket == "top", , drop = FALSE]
    bottom <- part[part$bucket == "bottom", , drop = FALSE]
    group_share <- if (nrow(top)) max(table(top$economic_group)) / nrow(top) else NA_real_
    symbol_share <- if (nrow(top)) max(table(top$symbol)) / nrow(top) else NA_real_
    ic <- daily_ic[
      daily_ic$fold_id == key$fold_id & daily_ic$method == key$method,
      , drop = FALSE
    ]
    top_mean <- if (nrow(top)) mean(top$relative_forward_return_h5) else NA_real_
    bottom_mean <- if (nrow(bottom)) mean(bottom$relative_forward_return_h5) else NA_real_
    data.frame(
      fold_id = key$fold_id,
      method = key$method,
      decision_dates = length(unique(part$feature_date)),
      mean_daily_rank_ic = mean(ic$rank_ic, na.rm = TRUE),
      median_daily_rank_ic = stats::median(ic$rank_ic, na.rm = TRUE),
      top_mean_relative_return_h5 = top_mean,
      bottom_mean_relative_return_h5 = bottom_mean,
      top_minus_bottom_h5 = top_mean - bottom_mean,
      top_selection_max_group_share = group_share,
      top_selection_max_symbol_share = symbol_share,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_gen54_x2a_method_summary <- function(fold_summary, daily_ic) {
  methods <- g5_gen54_x2a_method_names()
  rows <- lapply(methods, function(method) {
    folds <- fold_summary[fold_summary$method == method, , drop = FALSE]
    ic <- daily_ic[daily_ic$method == method, , drop = FALSE]
    data.frame(
      method = method,
      mean_oos_daily_rank_ic = mean(ic$rank_ic, na.rm = TRUE),
      positive_ic_quarters = sum(folds$mean_daily_rank_ic > 0, na.rm = TRUE),
      overall_top_minus_bottom_h5 = mean(folds$top_minus_bottom_h5, na.rm = TRUE),
      positive_ordering_quarters = sum(folds$top_minus_bottom_h5 > 0, na.rm = TRUE),
      maximum_top_selection_group_share = max(folds$top_selection_max_group_share, na.rm = TRUE),
      maximum_top_selection_symbol_share = max(folds$top_selection_max_symbol_share, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_gen54_x2a_gate_audit <- function(method_summary, fold_summary, leakage_audit) {
  model <- method_summary[method_summary$method == "pooled_linear_ranker", , drop = FALSE]
  nonmodel <- method_summary[method_summary$method != "pooled_linear_ranker", , drop = FALSE]
  best_nonmodel <- nonmodel[which.max(nonmodel$mean_oos_daily_rank_ic), , drop = FALSE]
  model_folds <- fold_summary[fold_summary$method == "pooled_linear_ranker", , drop = FALSE]
  comparator_fold <- aggregate(
    fold_summary$mean_daily_rank_ic[fold_summary$method != "pooled_linear_ranker"],
    list(fold_id = fold_summary$fold_id[fold_summary$method != "pooled_linear_ranker"]),
    max,
    na.rm = TRUE
  )
  names(comparator_fold)[[2L]] <- "best_nonmodel_mean_ic"
  improvement <- merge(
    model_folds[, c("fold_id", "mean_daily_rank_ic"), drop = FALSE],
    comparator_fold,
    by = "fold_id",
    all.x = TRUE
  )
  improvement$linear_minus_best_nonmodel_ic <- improvement$mean_daily_rank_ic -
    improvement$best_nonmodel_mean_ic
  mean_lift <- model$mean_oos_daily_rank_ic - best_nonmodel$mean_oos_daily_rank_ic
  integrity_pass <- nrow(leakage_audit) > 0L && all(leakage_audit$status == "PASS")

  gates <- data.frame(
    gate_id = c(
      "integrity_and_leakage",
      "positive_mean_oos_ic",
      "positive_ic_at_least_4_of_6",
      "positive_overall_top_bottom",
      "positive_ordering_at_least_4_of_6",
      "mean_ic_lift_at_least_0_005",
      "positive_improvement_at_least_4_of_6",
      "maximum_group_share_at_most_0_50",
      "maximum_symbol_share_at_most_0_25"
    ),
    observed = c(
      if (integrity_pass) 1 else 0,
      model$mean_oos_daily_rank_ic,
      model$positive_ic_quarters,
      model$overall_top_minus_bottom_h5,
      model$positive_ordering_quarters,
      mean_lift,
      sum(improvement$linear_minus_best_nonmodel_ic > 0, na.rm = TRUE),
      model$maximum_top_selection_group_share,
      model$maximum_top_selection_symbol_share
    ),
    threshold = c(1, 0, 4, 0, 4, 0.005, 4, 0.50, 0.25),
    comparison = c("==", ">", ">=", ">", ">=", ">=", ">=", "<=", "<="),
    status = c(
      if (integrity_pass) "PASS" else "FAIL",
      if (model$mean_oos_daily_rank_ic > 0) "PASS" else "FAIL",
      if (model$positive_ic_quarters >= 4L) "PASS" else "FAIL",
      if (model$overall_top_minus_bottom_h5 > 0) "PASS" else "FAIL",
      if (model$positive_ordering_quarters >= 4L) "PASS" else "FAIL",
      if (mean_lift >= 0.005) "PASS" else "FAIL",
      if (sum(improvement$linear_minus_best_nonmodel_ic > 0, na.rm = TRUE) >= 4L) "PASS" else "FAIL",
      if (model$maximum_top_selection_group_share <= 0.50) "PASS" else "FAIL",
      if (model$maximum_top_selection_symbol_share <= 0.25) "PASS" else "FAIL"
    ),
    stringsAsFactors = FALSE
  )

  composite <- method_summary[
    method_summary$method == "fixed_50_50_composite",
    , drop = FALSE
  ]
  composite_works <- composite$mean_oos_daily_rank_ic > 0 &&
    composite$positive_ic_quarters >= 4L &&
    composite$overall_top_minus_bottom_h5 > 0 &&
    composite$positive_ordering_quarters >= 4L &&
    composite$maximum_top_selection_group_share <= 0.50 &&
    composite$maximum_top_selection_symbol_share <= 0.25
  overall_status <- if (all(gates$status == "PASS")) {
    "PASS_X2A_TO_TOP5_POLICY_THEORY"
  } else if (integrity_pass && composite_works) {
    "RETAIN_FIXED_COMPOSITE_CLOSE_ML_COMPLEXITY"
  } else {
    "STOP_X2A_MULTIVARIATE_RANKING"
  }
  list(
    gates = gates,
    improvement = improvement,
    best_nonmodel_method = best_nonmodel$method,
    mean_ic_lift = mean_lift,
    overall_status = overall_status
  )
}

g5_gen54_x2a_leakage_audit <- function(panel, folds, coefficients) {
  base_oos <- g5_gen54_xs_assign_oos(panel, folds)
  base <- g5_gen54_xs_leakage_audit(base_oos)
  coef_by_fold <- split(coefficients, coefficients$fold_id)
  checks <- do.call(rbind, lapply(names(coef_by_fold), function(fold_id) {
    part <- coef_by_fold[[fold_id]]
    fold <- folds[folds$fold_id == fold_id, , drop = FALSE]
    data.frame(
      check_id = c(
        paste0(fold_id, "_train_labels_purged"),
        paste0(fold_id, "_oos_labels_inside_quarter"),
        paste0(fold_id, "_train_precedes_oos")
      ),
      status = c(
        if (all(part$train_last_label_end_date <= fold$train_end_date)) "PASS" else "FAIL",
        if (all(part$oos_last_label_end_date <= fold$oos_end_date)) "PASS" else "FAIL",
        if (all(part$train_last_feature_date < part$oos_first_feature_date)) "PASS" else "FAIL"
      ),
      detail = c(
        paste0("Latest TRAIN label endpoint is ", part$train_last_label_end_date[[1L]], "."),
        paste0("Latest OOS label endpoint is ", part$oos_last_label_end_date[[1L]], "."),
        "The pooled linear model is fit only on the preceding eight-quarter TRAIN window."
      ),
      stringsAsFactors = FALSE
    )
  }))
  extra <- data.frame(
    check_id = c(
      "exact_two_feature_formula",
      "same_date_oos_ranking",
      "no_model_selection_or_hyperparameters",
      "no_portfolio_or_live_authority"
    ),
    status = "PASS",
    detail = c(
      "The only predictive inputs are group-relative momentum rank and intraday-minus-overnight rank.",
      "Every raw prediction is converted to a rank using only contemporaneously eligible names.",
      "OLS uses an intercept and two main effects; no interactions, symbol effects, group effects, or tuned parameters.",
      "This packet contains ranking diagnostics only: no strategy PnL, exposure, allocation, costs, or live behavior."
    ),
    stringsAsFactors = FALSE
  )
  rbind(base, checks, extra)
}

g5_gen54_x2a_representative_tapes <- function(scored) {
  model <- scored[scored$method == "pooled_linear_ranker", , drop = FALSE]
  folds <- unique(model$fold_id)
  rows <- lapply(folds, function(fold_id) {
    part <- model[model$fold_id == fold_id, , drop = FALSE]
    dates <- sort(unique(part$feature_date))
    chosen <- dates[[ceiling(length(dates) / 2)]]
    tape <- part[part$feature_date == chosen, , drop = FALSE]
    tape <- tape[order(-tape$score_rank, tape$symbol), , drop = FALSE]
    tape$rank_position <- seq_len(nrow(tape))
    tape[tape$rank_position <= 5L, c(
      "fold_id", "feature_date", "rank_position", "symbol", "economic_group",
      "score_rank", "group_relative_20_rank",
      "intraday_minus_overnight_20_rank", "relative_forward_return_h5"
    ), drop = FALSE]
  })
  do.call(rbind, rows)
}
