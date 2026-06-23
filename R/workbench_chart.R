# Gen5 v0.1 static workbench chart helpers.

g5_candlestick_artifact_prefix <- function(as_of_timestamp, symbol) {
  stamp <- gsub("[^0-9A-Za-z]+", "_", as.character(as_of_timestamp))
  stamp <- gsub("_+$", "", stamp)
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  paste("candlestick", symbol, stamp, sep = "_")
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

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height))
  on.exit(grDevices::dev.off(), add = TRUE)

  session_dates <- as.Date(bars$session_date)
  x <- seq_along(session_dates)
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

  graphics::par(mar = c(6, 5, 4, 2))
  graphics::plot(
    x = c(0.5, length(x) + 0.5),
    y = y_limits,
    type = "n",
    xaxt = "n",
    xlab = "Session date",
    ylab = "Adjusted daily price",
    main = title
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

  tick_count <- min(8L, length(x))
  tick_positions <- unique(round(seq(1L, length(x), length.out = tick_count)))
  graphics::axis(1, at = tick_positions, labels = as.character(session_dates[tick_positions]), las = 2)
  graphics::legend(
    "topleft",
    legend = c("close above open", "close below open", "unchanged"),
    fill = c(up_color, down_color, flat_color),
    border = NA,
    bty = "n"
  )
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

  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}
