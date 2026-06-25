# Gen5 v0.1 static workbench chart helpers.

g5_chart_aesthetic <- function() {
  list(
    background = "#FFF8EF",
    panel_background = "#FFFDF8",
    grid = "#E8DED2",
    axis = "#3A3442",
    text = "#242033",
    up_candle = "#00A88F",
    down_candle = "#F15A5A",
    flat_candle = "#6E6878",
    native_entry_color = "#2E86AB",
    native_entry_pch = 24L,
    native_exit_color = "#F6C85F",
    native_exit_pch = 25L,
    entry_signal_color = "#00B4D8",
    entry_signal_pch = 21L,
    exit_signal_color = "#FF9F1C",
    exit_signal_pch = 22L,
    non_native_exit_color = "#9B5DE5",
    non_native_exit_pch = 4L,
    trade_win_line = "#00A88F",
    trade_loss_line = "#F15A5A",
    trade_line_lty = 2L
  )
}

g5_candlestick_artifact_prefix <- function(as_of_timestamp, symbol) {
  stamp <- gsub("[^0-9A-Za-z]+", "_", as.character(as_of_timestamp))
  stamp <- gsub("_+$", "", stamp)
  symbol <- gsub("[^0-9A-Za-z_.-]+", "_", g5_standardize_symbol(symbol)[[1L]])
  paste("candlestick", symbol, stamp, sep = "_")
}

g5_axis_date_labels_45 <- function(positions, labels, cex = 0.72, line_offset = 0.075, color = "#3A3442") {
  graphics::axis(1, at = positions, labels = FALSE, col = color, col.ticks = color)
  usr <- graphics::par("usr")
  y <- usr[[3L]] - diff(usr[3:4]) * line_offset
  graphics::text(
    x = positions,
    y = y,
    labels = labels,
    srt = 45,
    adj = 1,
    xpd = NA,
    cex = cex,
    col = color
  )
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
  show_axis_labels = TRUE,
  axis_tick_count = 8L,
  cex_main = 1,
  aesthetic = g5_chart_aesthetic()
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
  up_color <- aesthetic$up_candle
  down_color <- aesthetic$down_candle
  flat_color <- aesthetic$flat_candle
  body_colors <- ifelse(close > open, up_color, ifelse(close < open, down_color, flat_color))

  if (is.null(title)) {
    title <- paste(symbol, "Adjusted Daily Candlestick")
  }

  graphics::plot(
    x = c(0.5, length(x) + 0.5),
    y = y_limits,
    type = "n",
    xaxt = "n",
    xlab = if (isTRUE(show_axis_labels)) "Session date" else "",
    ylab = if (isTRUE(show_axis_labels)) "Adjusted daily price" else "",
    main = title,
    cex.main = cex_main,
    col.axis = aesthetic$axis,
    col.lab = aesthetic$text,
    col.main = aesthetic$text,
    fg = aesthetic$axis
  )
  usr <- graphics::par("usr")
  graphics::rect(usr[[1L]], usr[[3L]], usr[[2L]], usr[[4L]], col = aesthetic$panel_background, border = NA)
  graphics::grid(nx = NA, ny = NULL, col = aesthetic$grid)

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
  g5_axis_date_labels_45(
    positions = tick_positions,
    labels = as.character(session_dates[tick_positions]),
    color = aesthetic$axis
  )
  if (isTRUE(show_legend)) {
    graphics::legend(
      "topleft",
      legend = c("close above open", "close below open", "unchanged"),
      fill = c(up_color, down_color, flat_color),
      border = NA,
      bty = "n",
      text.col = aesthetic$text
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
    cex = 0.85,
    col = aesthetic$text
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
  aesthetic <- g5_chart_aesthetic()
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height))
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(
    mar = c(7.5, 5.2, 4, 2),
    bg = aesthetic$background,
    col.axis = aesthetic$axis,
    col.lab = aesthetic$text,
    col.main = aesthetic$text,
    fg = aesthetic$axis
  )
  g5_draw_candlestick_panel(prepared, symbol = symbol, title = title, show_legend = TRUE, aesthetic = aesthetic)

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
  aesthetic <- g5_chart_aesthetic()
  grDevices::png(filename = path, width = as.integer(width), height = as.integer(height))
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit({
    graphics::par(old_par)
    grDevices::dev.off()
  }, add = TRUE)
  graphics::par(
    mfrow = c(rows, cols),
    mar = c(4.6, 3.6, 3, 1.4),
    oma = c(5.2, 5.2, 3.4, 0.8),
    bg = aesthetic$background,
    col.axis = aesthetic$axis,
    col.lab = aesthetic$text,
    col.main = aesthetic$text,
    fg = aesthetic$axis
  )

  for (sym in symbols) {
    panel_title <- paste(sym, "Adjusted Daily")
    g5_draw_candlestick_panel(
      prepared[[sym]],
      symbol = sym,
      title = panel_title,
      show_legend = FALSE,
      show_axis_labels = FALSE,
      axis_tick_count = 5L,
      cex_main = 0.9,
      aesthetic = aesthetic
    )
  }
  if (!is.null(title)) {
    graphics::mtext(title, outer = TRUE, side = 3, line = 1, cex = 1.1, font = 2, col = aesthetic$text)
  }
  graphics::mtext("Session date", outer = TRUE, side = 1, line = 3.6, cex = 0.95, col = aesthetic$text)
  graphics::mtext("Adjusted daily price", outer = TRUE, side = 2, line = 3.6, cex = 0.95, col = aesthetic$text)

  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}
