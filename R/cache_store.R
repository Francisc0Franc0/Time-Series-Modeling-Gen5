# Simple deterministic local cache helpers.

g5_cache_symbol_path <- function(cache_root, provider, timeframe, symbol, format = "rds") {
  if (!nzchar(cache_root)) {
    g5_stop("cache_root must be a non-empty path.")
  }
  if (!format %in% c("rds")) {
    g5_stop("Only rds cache format is implemented in the v0 scaffold.")
  }

  safe_symbol <- gsub("[^A-Za-z0-9_.-]", "_", g5_standardize_symbol(symbol))
  file.path(cache_root, provider, timeframe, paste0(safe_symbol, ".", format))
}

g5_write_bars_cache <- function(bars, cache_root, provider = "alpaca", timeframe = "1D") {
  bars <- g5_validate_bar_data(bars)
  symbols <- unique(bars$symbol)
  written <- character()

  for (sym in symbols) {
    out_path <- g5_cache_symbol_path(cache_root, provider, timeframe, sym)
    dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
    saveRDS(bars[bars$symbol == sym, , drop = FALSE], out_path)
    written <- c(written, out_path)
  }

  data.frame(symbol = symbols, path = written, stringsAsFactors = FALSE)
}

g5_read_bars_cache <- function(symbols, cache_root, provider = "alpaca", timeframe = "1D") {
  symbols <- g5_standardize_symbol(symbols)
  frames <- list()
  missing <- character()

  for (sym in symbols) {
    path <- g5_cache_symbol_path(cache_root, provider, timeframe, sym)
    if (!file.exists(path)) {
      missing <- c(missing, sym)
    } else {
      frames[[sym]] <- readRDS(path)
    }
  }

  if (length(missing) > 0L) {
    g5_stop(paste("Missing cache files for symbols:", paste(missing, collapse = ", ")))
  }

  bars <- do.call(rbind, frames)
  rownames(bars) <- NULL
  g5_validate_bar_data(bars)
}
