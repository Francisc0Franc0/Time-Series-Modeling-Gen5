g5_mr02_case_stop <- function(message) {
  stop(paste0("[Gen5 LIT-MR-02.1 case studies] ", message), call. = FALSE)
}

g5_mr02_reference_contract <- function() {
  contract <- g5_mr02_contract()
  contract$query_start <- as.Date("2006-05-24")
  contract$query_end <- as.Date("2012-04-09")
  contract$as_of_timestamp <- "2026-07-29 17:30:00 America/New_York"
  contract$train_start <- contract$query_start
  contract$train_end <- contract$query_end
  contract$development_start <- contract$query_end + 1L
  contract$development_end <- contract$query_end + 1L
  contract$confirmation_start <- contract$query_end + 2L
  contract$confirmation_end <- contract$query_end + 2L
  contract
}

g5_mr02_yahoo_chart_url <- function(symbol, start_date, end_date) {
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  if (is.na(start_date) || is.na(end_date) || start_date > end_date) {
    g5_mr02_case_stop("Yahoo reference dates must be explicit and ordered.")
  }
  epoch <- as.POSIXct("1970-01-01 00:00:00", tz = "UTC")
  period1 <- as.integer(difftime(
    as.POSIXct(start_date, tz = "UTC"), epoch, units = "secs"
  ))
  period2 <- as.integer(difftime(
    as.POSIXct(end_date + 1L, tz = "UTC"), epoch, units = "secs"
  ))
  paste0(
    "https://query1.finance.yahoo.com/v8/finance/chart/",
    utils::URLencode(toupper(symbol), reserved = TRUE),
    "?period1=", period1,
    "&period2=", period2,
    "&interval=1d&events=history&includeAdjustedClose=true"
  )
}

g5_mr02_json_numeric <- function(values, expected_length, label) {
  if (!is.list(values) || length(values) != expected_length) {
    g5_mr02_case_stop(sprintf(
      "Yahoo field %s had length %s; expected %s.",
      label, length(values), expected_length
    ))
  }
  vapply(values, function(value) {
    if (is.null(value) || !length(value)) return(NA_real_)
    as.numeric(value[[1L]])
  }, numeric(1))
}

g5_mr02_parse_yahoo_chart <- function(payload, symbol, as_of_timestamp) {
  result <- payload$chart$result
  if (is.null(result) || !length(result)) {
    error <- payload$chart$error
    detail <- if (is.null(error)) "no result" else paste(unlist(error), collapse = " ")
    g5_mr02_case_stop(paste("Yahoo returned", detail, "for", symbol))
  }
  result <- result[[1L]]
  timestamps <- result$timestamp
  if (!is.list(timestamps) || !length(timestamps)) {
    g5_mr02_case_stop(paste("Yahoo returned no timestamps for", symbol))
  }
  timestamp <- g5_mr02_json_numeric(
    timestamps, length(timestamps), paste0(symbol, ".timestamp")
  )
  quote <- result$indicators$quote[[1L]]
  adjusted <- result$indicators$adjclose[[1L]]$adjclose
  n <- length(timestamp)
  raw_open <- g5_mr02_json_numeric(quote$open, n, paste0(symbol, ".open"))
  raw_high <- g5_mr02_json_numeric(quote$high, n, paste0(symbol, ".high"))
  raw_low <- g5_mr02_json_numeric(quote$low, n, paste0(symbol, ".low"))
  raw_close <- g5_mr02_json_numeric(quote$close, n, paste0(symbol, ".close"))
  volume <- g5_mr02_json_numeric(quote$volume, n, paste0(symbol, ".volume"))
  adjusted_close <- g5_mr02_json_numeric(
    adjusted, n, paste0(symbol, ".adjclose")
  )
  adjustment_factor <- adjusted_close / raw_close
  out <- data.frame(
    symbol = toupper(symbol),
    session_date = as.Date(
      as.POSIXct(timestamp, origin = "1970-01-01", tz = "UTC")
    ),
    open = raw_open * adjustment_factor,
    high = raw_high * adjustment_factor,
    low = raw_low * adjustment_factor,
    close = adjusted_close,
    volume = volume,
    adjusted = TRUE,
    timeframe = "1D",
    provider = "yahoo_chart_reference_only",
    as_of_timestamp = as.character(as_of_timestamp),
    raw_close = raw_close,
    adjustment_factor = adjustment_factor,
    stringsAsFactors = FALSE
  )
  complete <- is.finite(out$open) & is.finite(out$high) &
    is.finite(out$low) & is.finite(out$close) & is.finite(out$volume) &
    out$open > 0 & out$high > 0 & out$low > 0 & out$close > 0
  out <- out[complete, , drop = FALSE]
  out <- out[!duplicated(out$session_date), , drop = FALSE]
  out[order(out$session_date), , drop = FALSE]
}

g5_mr02_fetch_yahoo_reference_bars <- function(
  symbol,
  start_date,
  end_date,
  as_of_timestamp
) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    g5_mr02_case_stop("The existing jsonlite package is required.")
  }
  url <- g5_mr02_yahoo_chart_url(symbol, start_date, end_date)
  payload <- jsonlite::fromJSON(url, simplifyVector = FALSE)
  bars <- g5_mr02_parse_yahoo_chart(payload, symbol, as_of_timestamp)
  attr(bars, "source_url") <- url
  bars
}

g5_mr02_source_signal_states <- function(indicators, contract) {
  state <- integer(nrow(indicators))
  action <- rep("carry_flat", nrow(indicators))
  previous <- 0L
  for (i in seq_len(nrow(indicators))) {
    z <- indicators$z_score[[i]]
    beta <- indicators$beta[[i]]
    valid <- is.finite(z) && is.finite(beta)
    current <- previous
    current_action <- if (previous == 0L) "carry_flat" else "carry_position"
    if (!valid) {
      current <- 0L
      current_action <- if (previous == 0L) "invalid_flat" else "invalid_exit"
    } else if (previous == 0L && z < -contract$entry_z) {
      current <- 1L
      current_action <- "enter_long_spread"
    } else if (previous == 0L && z > contract$entry_z) {
      current <- -1L
      current_action <- "enter_short_spread"
    } else if (previous == 1L && z >= contract$exit_z) {
      current <- 0L
      current_action <- "exit_long_spread"
    } else if (previous == -1L && z <= -contract$exit_z) {
      current <- 0L
      current_action <- "exit_short_spread"
    }
    state[[i]] <- current
    action[[i]] <- current_action
    previous <- current
  }
  indicators$target_state <- state
  indicators$signal_action <- action
  indicators
}

g5_mr02_source_close_replay <- function(indicators) {
  if (nrow(indicators) < 2L) {
    g5_mr02_case_stop("Source-style replay requires two sessions.")
  }
  rows <- vector("list", nrow(indicators) - 1L)
  for (i in seq_len(nrow(indicators) - 1L)) {
    state <- indicators$target_state[[i]]
    beta <- indicators$beta[[i]]
    valid <- state != 0L && is.finite(beta)
    if (valid) {
      shares_x <- -state * beta
      shares_y <- state
      gross <- abs(shares_x * indicators$close_x[[i]]) +
        abs(shares_y * indicators$close_y[[i]])
      pnl <- shares_x * (
        indicators$close_x[[i + 1L]] - indicators$close_x[[i]]
      ) + shares_y * (
        indicators$close_y[[i + 1L]] - indicators$close_y[[i]]
      )
      return <- if (is.finite(gross) && gross > 0) pnl / gross else 0
    } else {
      shares_x <- shares_y <- 0
      gross <- 0
      return <- 0
    }
    rows[[i]] <- data.frame(
      signal_date = indicators$session_date[[i]],
      return_date = indicators$session_date[[i + 1L]],
      target_state = state,
      beta = beta,
      shares_x = shares_x,
      shares_y = shares_y,
      gross_market_value = gross,
      source_gross_return = return,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

g5_mr02_performance_metrics <- function(returns, periods_per_year = 252) {
  returns <- as.numeric(returns)
  returns <- returns[is.finite(returns)]
  if (!length(returns)) {
    return(data.frame(
      bars = 0L, cumulative_return = NA_real_, apr = NA_real_,
      naive_sharpe = NA_real_, maximum_drawdown = NA_real_
    ))
  }
  equity <- cumprod(1 + returns)
  running_peak <- cummax(c(1, equity))[-1L]
  data.frame(
    bars = length(returns),
    cumulative_return = tail(equity, 1L) - 1,
    apr = tail(equity, 1L)^(periods_per_year / length(returns)) - 1,
    naive_sharpe = if (stats::sd(returns) > 0) {
      mean(returns) / stats::sd(returns) * sqrt(periods_per_year)
    } else {
      NA_real_
    },
    maximum_drawdown = min(equity / running_peak - 1)
  )
}

g5_mr02_case_2018_summary <- function(replay, trades) {
  year_replay <- replay[
    format(as.Date(replay$execution_date), "%Y") == "2018",
    ,
    drop = FALSE
  ]
  year_trades <- trades[
    trades$completed & format(as.Date(trades$exit_date), "%Y") == "2018",
    ,
    drop = FALSE
  ]
  metrics <- g5_mr02_performance_metrics(year_replay$primary_net_return)
  metrics$gross_return <- prod(1 + year_replay$gross_return) - 1
  metrics$stress_return <- prod(1 + year_replay$stress_net_return) - 1
  metrics$completed_trades <- nrow(year_trades)
  metrics$wins <- sum(year_trades$primary_net_additive_return > 0)
  metrics$hit_rate <- mean(year_trades$primary_net_additive_return > 0)
  metrics$long_trades <- sum(year_trades$direction_label == "LONG_SPREAD")
  metrics$short_trades <- sum(year_trades$direction_label == "SHORT_SPREAD")
  metrics$mean_net_trade_return <- mean(
    year_trades$primary_net_additive_return
  )
  metrics$median_net_trade_return <- stats::median(
    year_trades$primary_net_additive_return
  )
  metrics
}

g5_mr02_write_png <- function(path, draw, width = 1800, height = 1050) {
  grDevices::png(
    filename = path, width = width, height = height, res = 150,
    bg = "white", type = if (.Platform$OS.type == "windows") "windows" else "cairo"
  )
  on.exit(grDevices::dev.off(), add = TRUE)
  draw()
  invisible(path)
}

g5_mr02_plot_2018_anatomy <- function(indicators, replay, output_path) {
  ind <- indicators[format(indicators$session_date, "%Y") == "2018", , drop = FALSE]
  rep <- replay[format(as.Date(replay$execution_date), "%Y") == "2018", , drop = FALSE]
  equity <- cumprod(1 + rep$primary_net_return)
  drawdown <- equity / cummax(c(1, equity))[-1L] - 1
  g5_mr02_write_png(output_path, function() {
    old <- graphics::par(
      mfrow = c(3, 1), mar = c(2.2, 4.3, 2.8, 1.2),
      oma = c(2.2, 0, 2.8, 0), las = 1, family = "sans"
    )
    on.exit(graphics::par(old), add = TRUE)
    x <- ind$session_date
    graphics::plot(
      x, ind$spread, type = "l", col = "#1F2937", lwd = 1.5,
      xlab = "", ylab = "Adaptive spread", xaxt = "n",
      main = "The spread repeatedly moved away from, then back toward, its rolling mean"
    )
    graphics::lines(x, ind$spread_mean, col = "#1478FF", lwd = 1.4)
    graphics::lines(x, ind$spread_mean + ind$spread_sd, col = "#94A3B8", lty = 2)
    graphics::lines(x, ind$spread_mean - ind$spread_sd, col = "#94A3B8", lty = 2)
    graphics::legend(
      "topleft", c("spread", "rolling mean", "+/-1 rolling SD"),
      col = c("#1F2937", "#1478FF", "#94A3B8"),
      lty = c(1, 1, 2), lwd = c(1.5, 1.4, 1), bty = "n", horiz = TRUE
    )
    graphics::plot(
      x, ind$z_score, type = "l", col = "#334155", lwd = 1.2,
      xlab = "", ylab = "z-score", xaxt = "n", ylim = range(c(-3, 3, ind$z_score), na.rm = TRUE),
      main = "Entries occurred beyond +/-1; exits waited for a zero crossing"
    )
    graphics::abline(h = c(-1, 0, 1), col = c("#0F7A4F", "#64748B", "#D33F49"), lty = c(2, 1, 2))
    entries_long <- ind$signal_action == "enter_long_spread"
    entries_short <- ind$signal_action == "enter_short_spread"
    exits <- grepl("^exit_", ind$signal_action)
    graphics::points(x[entries_long], ind$z_score[entries_long], pch = 24, bg = "#0F7A4F", cex = 1.2)
    graphics::points(x[entries_short], ind$z_score[entries_short], pch = 25, bg = "#D33F49", cex = 1.2)
    graphics::points(x[exits], ind$z_score[exits], pch = 21, bg = "#1478FF", cex = 1)
    graphics::plot(
      as.Date(rep$next_execution_date), equity - 1, type = "l",
      col = "#1478FF", lwd = 2.2, xlab = "", ylab = "Cumulative return",
      ylim = range(c(equity - 1, drawdown, 0)),
      main = "The cost-aware equity path finished positive despite a late drawdown"
    )
    graphics::polygon(
      c(as.Date(rep$next_execution_date), rev(as.Date(rep$next_execution_date))),
      c(rep(0, nrow(rep)), rev(drawdown)),
      col = grDevices::adjustcolor("#D33F49", alpha.f = 0.16), border = NA
    )
    graphics::lines(as.Date(rep$next_execution_date), equity - 1, col = "#1478FF", lwd = 2.2)
    graphics::abline(h = 0, col = "#94A3B8")
    graphics::mtext(
      "LIT-MR-02.1 / CASESTUDY_2018 - exact frozen mechanics",
      outer = TRUE, side = 3, line = 1, font = 2, cex = 1.25
    )
    graphics::mtext(
      "Adjusted daily Alpaca bars; signal after close; next-open execution; 5 bp per one-way weight change",
      outer = TRUE, side = 1, line = 1, cex = 0.82, col = "#475569"
    )
  })
}

g5_mr02_plot_2018_trades <- function(trades, output_path) {
  x <- trades[
    trades$completed & format(as.Date(trades$exit_date), "%Y") == "2018",
    ,
    drop = FALSE
  ]
  x <- x[order(x$entry_date), , drop = FALSE]
  g5_mr02_write_png(output_path, function() {
    old <- graphics::par(mar = c(4.7, 5.2, 4.4, 2.2), family = "sans", las = 1)
    on.exit(graphics::par(old), add = TRUE)
    y <- seq_len(nrow(x))
    colors <- ifelse(x$direction_label == "LONG_SPREAD", "#1478FF", "#D33F49")
    graphics::plot(
      range(c(as.Date(x$entry_date), as.Date(x$exit_date))), range(y),
      type = "n", xlab = "2018 calendar", ylab = "", yaxt = "n",
      main = "Thirteen two-sided trades made the positive year visible trade by trade"
    )
    graphics::axis(2, at = y, labels = paste0("T", x$trade_id), las = 1)
    graphics::segments(
      as.Date(x$entry_date), y, as.Date(x$exit_date), y,
      col = colors, lwd = 5
    )
    graphics::points(as.Date(x$entry_date), y, pch = 21, bg = "white", col = colors, cex = 1)
    graphics::points(as.Date(x$exit_date), y, pch = 21, bg = colors, col = colors, cex = 1)
    label <- sprintf("%+.1f%%", 100 * x$primary_net_additive_return)
    graphics::text(
      as.Date(x$exit_date) + 5, y, labels = label, pos = 4,
      col = ifelse(x$primary_net_additive_return > 0, "#0F7A4F", "#B42318"),
      font = 2, cex = 0.86, xpd = NA
    )
    graphics::legend(
      "bottomright", c("long spread", "short spread"),
      col = c("#1478FF", "#D33F49"), lwd = 5, bty = "n"
    )
    graphics::mtext(
      "Open circle = entry; filled circle = exit; label = primary-cost net trade return",
      side = 3, line = 0.7, cex = 0.86, col = "#475569"
    )
  })
}

g5_mr02_plot_2018_trade_economics <- function(trades, output_path) {
  x <- trades[
    trades$completed & format(as.Date(trades$exit_date), "%Y") == "2018",
    ,
    drop = FALSE
  ]
  x <- x[order(x$entry_date), , drop = FALSE]
  gross <- x$gross_additive_return
  net <- x$primary_net_additive_return
  g5_mr02_write_png(output_path, function() {
    old <- graphics::par(
      mfrow = c(1, 2), mar = c(5, 4.3, 4.2, 1.2), family = "sans", las = 1
    )
    on.exit(graphics::par(old), add = TRUE)
    mids <- graphics::barplot(
      rbind(gross, net), beside = TRUE,
      col = c("#CBD5E1", "#1478FF"), border = NA,
      names.arg = paste0("T", x$trade_id), las = 2,
      ylab = "Additive return", main = "Costs reduced returns, but did not erase the year"
    )
    graphics::abline(h = 0, col = "#64748B")
    graphics::legend(
      "topleft", c("gross", "net after primary costs"),
      fill = c("#CBD5E1", "#1478FF"), bty = "n"
    )
    direction <- factor(x$direction_label, levels = c("LONG_SPREAD", "SHORT_SPREAD"))
    graphics::plot(
      x$holding_bars, 100 * net,
      pch = ifelse(direction == "LONG_SPREAD", 21, 24),
      bg = ifelse(direction == "LONG_SPREAD", "#1478FF", "#D33F49"),
      col = "white", cex = 1.45,
      xlab = "Holding period (bars)", ylab = "Net trade return (%)",
      main = "Both directions produced winners"
    )
    graphics::abline(h = 0, col = "#64748B")
    graphics::legend(
      "topright", c("long spread", "short spread"),
      pch = c(21, 24), pt.bg = c("#1478FF", "#D33F49"), bty = "n"
    )
  })
}

g5_mr02_plot_year_context <- function(year_summary, output_path) {
  g5_mr02_write_png(output_path, function() {
    old <- graphics::par(mar = c(4.8, 4.6, 4.5, 1.2), family = "sans", las = 1)
    on.exit(graphics::par(old), add = TRUE)
    colors <- ifelse(
      year_summary$calendar_year == 2018, "#1478FF",
      ifelse(year_summary$primary_net_return > 0, "#86BDFD", "#D33F49")
    )
    mids <- graphics::barplot(
      100 * year_summary$primary_net_return,
      names.arg = year_summary$calendar_year, col = colors, border = NA,
      ylim = c(
        min(100 * year_summary$primary_net_return) - 1.5,
        max(100 * year_summary$primary_net_return) + 2
      ),
      ylab = "Primary-cost calendar return (%)",
      main = "2018 is a real working regime - not a reversal of the five-year STOP"
    )
    graphics::abline(h = 0, col = "#64748B")
    graphics::text(
      mids, 100 * year_summary$primary_net_return,
      labels = sprintf("%+.1f%%", 100 * year_summary$primary_net_return),
      pos = ifelse(year_summary$primary_net_return >= 0, 3, 1),
      font = 2, cex = 1.05
    )
    graphics::mtext(
      "The selected year is shown beside every other opened TRAIN year to keep the retrospective selection visible.",
      side = 3, line = 0.7, cex = 0.86, col = "#475569"
    )
  })
}

g5_mr02_plot_source_reproduction <- function(
  source_replay,
  gen5_replay,
  output_path
) {
  source_equity <- cumprod(1 + source_replay$source_gross_return)
  gen5_equity <- cumprod(1 + gen5_replay$primary_net_return)
  source_dd <- source_equity / cummax(c(1, source_equity))[-1L] - 1
  gen5_dd <- gen5_equity / cummax(c(1, gen5_equity))[-1L] - 1
  g5_mr02_write_png(output_path, function() {
    old <- graphics::par(
      mfrow = c(2, 1), mar = c(3.5, 4.5, 3.5, 1.2),
      oma = c(3.2, 0, 2.5, 0), family = "sans", las = 1
    )
    on.exit(graphics::par(old), add = TRUE)
    graphics::plot(
      as.Date(source_replay$return_date), source_equity - 1,
      type = "l", col = "#1478FF", lwd = 2,
      xlab = "", ylab = "Cumulative return",
      main = "Source-style close-to-close accounting versus Gen5 execution realism"
    )
    graphics::lines(
      as.Date(gen5_replay$next_execution_date), gen5_equity - 1,
      col = "#D33F49", lwd = 2
    )
    graphics::abline(h = 0, col = "#94A3B8")
    graphics::legend(
      "topleft",
      c("book-style: close-to-close, no costs", "Gen5: next-open, primary costs"),
      col = c("#1478FF", "#D33F49"), lwd = 2, bty = "n"
    )
    graphics::plot(
      as.Date(source_replay$return_date), 100 * source_dd,
      type = "l", col = "#1478FF", lwd = 1.7,
      xlab = "", ylab = "Drawdown (%)",
      main = "Execution assumptions change both return and drawdown"
    )
    graphics::lines(
      as.Date(gen5_replay$next_execution_date), 100 * gen5_dd,
      col = "#D33F49", lwd = 1.7
    )
    graphics::abline(h = 0, col = "#94A3B8")
    graphics::mtext(
      "Chan Example 3.2 reference period: 24 May 2006 - 9 Apr 2012",
      outer = TRUE, side = 3, line = 0.9, font = 2, cex = 1.2
    )
  })
}

g5_mr02_plot_source_signal_tape <- function(indicators, output_path) {
  g5_mr02_write_png(output_path, function() {
    old <- graphics::par(
      mfrow = c(2, 1), mar = c(3, 4.5, 3.4, 1.2),
      oma = c(1.4, 0, 2.2, 0), family = "sans", las = 1
    )
    on.exit(graphics::par(old), add = TRUE)
    graphics::plot(
      indicators$session_date, indicators$z_score,
      type = "l", col = "#334155", lwd = 1,
      xlab = "", ylab = "z-score",
      main = "The published rule repeatedly entered beyond +/-1 and exited at zero"
    )
    graphics::abline(h = c(-1, 0, 1), col = c("#0F7A4F", "#64748B", "#D33F49"), lty = c(2, 1, 2))
    graphics::plot(
      indicators$session_date, indicators$beta,
      type = "l", col = "#1478FF", lwd = 1,
      xlab = "Source interval", ylab = "Rolling OLS beta",
      main = "The adaptive hedge ratio changed materially through the sample"
    )
    graphics::abline(h = 0, col = "#94A3B8")
    graphics::mtext(
      "Yahoo adjusted daily reference bars; reference-only, not canonical Gen5 provider data",
      outer = TRUE, side = 3, line = 0.7, cex = 0.88, col = "#475569"
    )
  })
}
