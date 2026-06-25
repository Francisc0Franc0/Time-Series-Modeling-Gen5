# Gen5 v0.1 static workbench chart helpers.

g5_candlestick_artifact_prefix <- function(as_of_timestamp, symbol) {
  stamp <- gsub("[^0-9A-Za-z]+", "_", as.character(as_of_timestamp))
  stamp <- gsub("_+$", "", stamp)
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  paste("candlestick", symbol, stamp, sep = "_")
}

g5_prepare_candlestick_bars <- function(
  bars,
  symbol,
  start_date = NULL,
  end_date = NULL
) {
  if (!is.data.frame(bars)) {
    g5_stop("bars must be a data.frame.")
  }
  symbol <- g5_standardize_symbol(symbol)
  if (length(symbol) != 1L) {
    g5_stop("Candlestick inspection requires exactly one symbol.")
  }
  if (nrow(bars) == 0L) {
    g5_stop("Candlestick inspection requires non-empty canonical bars.")
  }

  bars <- g5_validate_bar_data(bars)
  bars <- bars[bars$symbol == symbol, , drop = FALSE]
  if (!is.null(start_date)) {
    start_date <- as.Date(start_date)
    if (is.na(start_date)) {
      g5_stop("start_date must be a valid date when supplied.")
    }
    bars <- bars[as.Date(bars$session_date) >= start_date, , drop = FALSE]
  }
  if (!is.null(end_date)) {
    end_date <- as.Date(end_date)
    if (is.na(end_date)) {
      g5_stop("end_date must be a valid date when supplied.")
    }
    bars <- bars[as.Date(bars$session_date) <= end_date, , drop = FALSE]
  }
  if (nrow(bars) == 0L) {
    g5_stop("No canonical bars remain for the requested symbol/date range.")
  }

  bars <- bars[order(as.Date(bars$session_date)), , drop = FALSE]
  open <- as.numeric(bars$open)
  high <- as.numeric(bars$high)
  low <- as.numeric(bars$low)
  close <- as.numeric(bars$close)
  if (any(high < pmax(open, close) | low > pmin(open, close), na.rm = TRUE)) {
    g5_stop("Candlestick bars must satisfy high/low bounds around open and close.")
  }

  bars
}

g5_draw_candlestick_panel <- function(
  bars,
  symbol,
  title = NULL,
  show_legend = TRUE,
  axis_tick_count = 8L,
  cex_main = 1
) {
  bars <- g5_prepare_candlestick_bars(bars, symbol)
  symbol <- g5_standardize_symbol(symbol)[[1L]]
  session_dates <- as.Date(bars$session_date)
  x <- seq_along(session_dates)
  open <- as.numeric(bars$open)
  high <- as.numeric(bars$high)
  low <- as.numeric(bars$low)
  close <- as.numeric(bars$close)
  y_range <- range(c(low, high), finite = TRUE)
  if (!all(is.finite(y_range))) {
    g5_stop("Candlestick price range could not be determined.")
  }
  padding <- diff(y_range) * 0.06
  if (!is.finite(padding) || padding <= 0) {
    padding <- max(abs(y_range), 1) * 0.02
  }
  y_limits <- y_range + c(-padding, padding)
  candle_width <- 0.62
  up_color <- "#1B9E77"
  down_color <- "#D95F02"
  flat_color <- "#4D4D4D"
  body_colors <- ifelse(close > open, up_color, ifelse(close < open, down_color, flat_color))

  if (is.null(title)) {
    title <- paste(symbol, "Adjusted Daily Candlestick")
  }

  graphics::plot(
    x = c(0.5, length(x) + 0.5),
    y = y_limits,
    type = "n",
    xaxt = "n",
    xlab = "Session date",
    ylab = "Adjusted daily price",
    main = title,
    cex.main = cex_main
  )
  graphics::grid(nx = NA, ny = NULL, col = "gray90")

  graphics::segments(x0 = x, y0 = low, x1 = x, y1 = high, col = body_colors, lwd = 1.2)
  body_bottom <- pmin(open, close)
  body_top <- pmax(open, close)
  flat_body <- body_bottom == body_top
  if (any(!flat_body)) {
    graphics::rect(
      xleft = x[!flat_body] - candle_width / 2,
      ybottom = body_bottom[!flat_body],
      xright = x[!flat_body] + candle_width / 2,
      ytop = body_top[!flat_body],
      col = body_colors[!flat_body],
      border = body_colors[!flat_body]
    )
  }
  if (any(flat_body)) {
    graphics::segments(
      x0 = x[flat_body] - candle_width / 2,
      y0 = close[flat_body],
      x1 = x[flat_body] + candle_width / 2,
      y1 = close[flat_body],
      col = body_colors[flat_body],
      lwd = 2
    )
  }

  tick_count <- min(axis_tick_count, length(x))
  tick_positions <- unique(round(seq(1L, length(x), length.out = tick_count)))
  graphics::axis(1, at = tick_positions, labels = as.character(session_dates[tick_positions]), las = 2)
  if (isTRUE(show_legend)) {
    graphics::legend(
      "topleft",
      legend = c("close above open", "close below open", "unchanged"),
      fill = c(up_color, down_color, flat_color),
      border = NA,
      bty = "n"
    )
  }
  graphics::mtext(
    paste(
      "Rows:",
      nrow(bars),
      "|",
      as.character(min(session_dates)),
      "to",
      as.character(max(session_dates))
    ),
    side = 3,
    line = 0.3,
    cex = 0.85
  )

  invisible(bars)
}

g5_write_static_candlestick_png <- function(
  bars,
  symbol,
  path,
  start_date = NULL,
  end_date = NULL,
  width = 1200L,
  height = 720L,
  title = NULL
) {
  if (!nzchar(path)) {
    g5_stop("path must be a non-empty file path.")
  }
  symbol <- g5_standardize_symbol(symbol)
  prepared <- g5_prepare_candlestick_bars(
    bars,
    symbol = symbol,
    start_date = start_date,
    end_date = end_date
  )

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height))
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(6, 5, 4, 2))
  g5_draw_candlestick_panel(prepared, symbol = symbol, title = title, show_legend = TRUE)

  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_write_multi_symbol_candlestick_png <- function(
  bars,
  symbols,
  path,
  start_date = NULL,
  end_date = NULL,
  width = 1500L,
  height = 1000L,
  title = NULL
) {
  if (!nzchar(path)) {
    g5_stop("path must be a non-empty file path.")
  }
  symbols <- unique(g5_standardize_symbol(symbols))
  if (length(symbols) == 0L) {
    g5_stop("symbols must contain at least one symbol.")
  }
  prepared <- lapply(
    symbols,
    function(sym) g5_prepare_candlestick_bars(
      bars,
      symbol = sym,
      start_date = start_date,
      end_date = end_date
    )
  )
  names(prepared) <- symbols

  panel_count <- length(symbols)
  cols <- ceiling(sqrt(panel_count))
  rows <- ceiling(panel_count / cols)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height))
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit({
    graphics::par(old_par)
    grDevices::dev.off()
  }, add = TRUE)
  graphics::par(mfrow = c(rows, cols), mar = c(5, 4, 3, 1.5), oma = c(0, 0, 3, 0))

  for (sym in symbols) {
    panel_title <- paste(sym, "Adjusted Daily")
    g5_draw_candlestick_panel(
      prepared[[sym]],
      symbol = sym,
      title = panel_title,
      show_legend = FALSE,
      axis_tick_count = 5L,
      cex_main = 0.9
    )
  }
  if (!is.null(title)) {
    graphics::mtext(title, outer = TRUE, side = 3, line = 1, cex = 1.1, font = 2)
  }

  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}
