# Sector-relative temporal replication helpers for HYP-MOM-04.3B.

h043b_features <- function() c("sector_relative126", "trend_r2_63", "recovery_from_low252", "positive_month_fraction12")

h043b_sector_target <- function(panel, minimum_sector_members = 3L) {
  key <- interaction(panel$signal_quarter, panel$sector, drop = TRUE)
  count <- ave(panel$target_return, key, FUN = length)
  out <- panel[count >= minimum_sector_members, , drop = FALSE]
  key <- interaction(out$signal_quarter, out$sector, drop = TRUE)
  out$target_sector_relative <- out$target_return - ave(out$target_return, key, FUN = mean)
  out
}

h043b_fit_score <- function(train, validation, target, lambda, features = h043b_features()) {
  columns <- paste0(features, "_rn")
  scaler <- h04_scaler_fit(train, columns)
  fit <- h04_ridge_fit(h04_scaler_apply(train, columns, scaler), target, lambda)
  list(score = h04_ridge_predict(fit, h04_scaler_apply(validation, columns, scaler)), fit = fit, scaler = scaler)
}

h043b_metrics <- function(panel, score, target) {
  do.call(rbind, lapply(unique(panel$signal_quarter), function(quarter) {
    local <- panel$signal_quarter == quarter
    quartile <- h04_quartile(score[local])
    data.frame(signal_quarter = quarter, observations = sum(local),
      rank_ic = h04_spearman(score[local], target[local]),
      top_quartile_target = mean(target[local][quartile == 4L]),
      top_minus_bottom = mean(target[local][quartile == 4L]) - mean(target[local][quartile == 1L]),
      stringsAsFactors = FALSE)
  }))
}

h043b_select_lambda <- function(panel, lambdas = c(.01, .1, 1, 10, 100), features = h043b_features()) {
  quarters <- unique(panel$signal_quarter)
  folds <- list(c(6L, 7L, 9L), c(9L, 10L, 12L), c(12L, 13L, 15L))
  rows <- list(); k <- 0L
  for (lambda in lambdas) for (f in folds) {
    tr <- panel$signal_quarter %in% quarters[seq_len(f[[1L]])]
    va <- panel$signal_quarter %in% quarters[f[[2L]]:f[[3L]]]
    fit <- h043b_fit_score(panel[tr, ], panel[va, ], panel$target_sector_relative[tr], lambda, features)
    m <- h043b_metrics(panel[va, ], fit$score, panel$target_sector_relative[va])
    k <- k + 1L; rows[[k]] <- data.frame(lambda = lambda, train_quarters = f[[1L]], m)
  }
  details <- do.call(rbind, rows)
  summary <- do.call(rbind, lapply(split(details, details$lambda), function(x) data.frame(
    lambda = x$lambda[[1L]], mean_rank_ic = mean(x$rank_ic), positive_fraction = mean(x$rank_ic > 0))))
  summary <- summary[order(-summary$mean_rank_ic, -summary$lambda), ]
  list(selected_lambda = summary$lambda[[1L]], details = details, summary = summary)
}

h043b_score_comparators <- function(train, development, lambda) {
  primary <- h043b_fit_score(train, development, train$target_sector_relative, lambda)
  fixed <- rowMeans(as.matrix(development[paste0(h043b_features(), "_rn")]))
  momentum <- development$sector_relative126_rn
  list(primary = primary, fixed = fixed, momentum = momentum)
}

h043b_gate_matrix <- function(primary_metrics, fixed_metrics, momentum_metrics, predictions) {
  positive <- pmax(predictions$target_sector_relative[predictions$quartile == 4L], 0)
  sectors <- predictions$sector[predictions$quartile == 4L]
  shares <- if (sum(positive) > 0) tapply(positive, sectors, sum) / sum(positive) else 1
  max_share <- max(shares)
  mean_ic <- mean(primary_metrics$rank_ic)
  mean_top <- mean(primary_metrics$top_quartile_target)
  data.frame(gate_id = c("MEAN_IC", "POSITIVE_IC_QUARTERS", "MEAN_TOP_QUARTILE", "POSITIVE_TOP_QUARTERS", "BEAT_COMPARATORS", "SECTOR_CONCENTRATION"),
    passed = c(mean_ic > 0, sum(primary_metrics$rank_ic > 0) >= 7L, mean_top > 0,
      sum(primary_metrics$top_quartile_target > 0) >= 7L,
      mean_ic > mean(fixed_metrics$rank_ic) && mean_ic > mean(momentum_metrics$rank_ic), max_share <= .35),
    estimate = c(mean_ic, sum(primary_metrics$rank_ic > 0), mean_top,
      sum(primary_metrics$top_quartile_target > 0), mean_ic - max(mean(fixed_metrics$rank_ic), mean(momentum_metrics$rank_ic)), max_share),
    threshold = c(">0", ">=7/11", ">0", ">=7/11", "> both comparators", "<=0.35"), stringsAsFactors = FALSE)
}
