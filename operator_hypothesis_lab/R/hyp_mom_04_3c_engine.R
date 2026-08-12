# Diagnostic-only feature transport helpers for HYP-MOM-04.3C.

h043c_features <- function() h043b_features()

h043c_quarter_metrics <- function(panel, feature, target = "target_sector_relative") {
  do.call(rbind, lapply(unique(panel$signal_quarter), function(quarter) {
    x <- panel[panel$signal_quarter == quarter, , drop = FALSE]
    score <- x[[feature]]; outcome <- x[[target]]
    quartile <- h04_quartile(score)
    decile <- ceiling(10 * rank(score, ties.method = "average") / length(score))
    data.frame(
      feature = feature, signal_quarter = quarter, observations = nrow(x),
      rank_ic = h04_spearman(score, outcome),
      q4_target = mean(outcome[quartile == 4L]),
      q4_minus_q1 = mean(outcome[quartile == 4L]) - mean(outcome[quartile == 1L]),
      d10_target = mean(outcome[decile == 10L]), stringsAsFactors = FALSE
    )
  }))
}

h043c_feature_summary <- function(quarter_metrics) {
  do.call(rbind, lapply(split(quarter_metrics, quarter_metrics$feature), function(x) data.frame(
    feature = x$feature[[1L]], mean_rank_ic = mean(x$rank_ic),
    positive_ic_quarters = sum(x$rank_ic > 0),
    mean_q4_target = mean(x$q4_target), positive_q4_quarters = sum(x$q4_target > 0),
    mean_q4_minus_q1 = mean(x$q4_minus_q1), positive_spread_quarters = sum(x$q4_minus_q1 > 0),
    mean_d10_target = mean(x$d10_target), positive_d10_quarters = sum(x$d10_target > 0),
    stringsAsFactors = FALSE
  )))
}

h043c_quartile_shape <- function(panel, feature, target = "target_sector_relative") {
  cells <- do.call(rbind, lapply(unique(panel$signal_quarter), function(quarter) {
    x <- panel[panel$signal_quarter == quarter, , drop = FALSE]
    q <- h04_quartile(x[[feature]])
    data.frame(feature = feature, signal_quarter = quarter, quartile = 1:4,
      target_mean = vapply(1:4, function(k) mean(x[[target]][q == k]), numeric(1)))
  }))
  out <- aggregate(target_mean ~ feature + quartile, cells, function(x) c(mean = mean(x), positive_quarters = sum(x > 0)))
  out$mean_target <- out$target_mean[, "mean"]
  out$positive_quarters <- out$target_mean[, "positive_quarters"]
  out[c("feature", "quartile", "mean_target", "positive_quarters")]
}

h043c_sector_metrics <- function(panel, feature, target = "target_sector_relative", minimum = 10L) {
  keys <- unique(panel[c("signal_quarter", "sector")])
  cells <- do.call(rbind, lapply(seq_len(nrow(keys)), function(i) {
    x <- panel[panel$signal_quarter == keys$signal_quarter[[i]] & panel$sector == keys$sector[[i]], , drop = FALSE]
    if (nrow(x) < minimum) return(NULL)
    data.frame(feature = feature, signal_quarter = keys$signal_quarter[[i]], sector = keys$sector[[i]],
      observations = nrow(x), rank_ic = h04_spearman(x[[feature]], x[[target]]))
  }))
  out <- aggregate(rank_ic ~ feature + sector, cells, function(x) c(mean = mean(x), positive_quarters = sum(x > 0), quarters = length(x)))
  out$mean_rank_ic <- out$rank_ic[, "mean"]
  out$positive_quarters <- out$rank_ic[, "positive_quarters"]
  out$quarters <- out$rank_ic[, "quarters"]
  out[c("feature", "sector", "mean_rank_ic", "positive_quarters", "quarters")]
}

h043c_audit <- function(panel) {
  q <- do.call(rbind, lapply(h043c_features(), function(f) h043c_quarter_metrics(panel, f)))
  list(
    quarter_metrics = q,
    summary = h043c_feature_summary(q),
    quartile_shape = do.call(rbind, lapply(h043c_features(), function(f) h043c_quartile_shape(panel, f))),
    sector_metrics = do.call(rbind, lapply(h043c_features(), function(f) h043c_sector_metrics(panel, f)))
  )
}
