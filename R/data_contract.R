# Gen5 canonical adjusted daily bar contract.

.g5_required_bar_columns <- c(
  "symbol",
  "session_date",
  "open",
  "high",
  "low",
  "close",
  "volume",
  "adjusted",
  "timeframe",
  "provider",
  "as_of_timestamp",
  "latest_completed_session",
  "fetch_start_date",
  "fetch_end_date",
  "data_version_hash"
)

g5_required_bar_columns <- function() {
  .g5_required_bar_columns
}

g5_stop <- function(message) {
  stop(paste0("[Gen5] ", message), call. = FALSE)
}

g5_standardize_symbol <- function(symbol) {
  x <- toupper(trimws(as.character(symbol)))
  if (any(!nzchar(x))) {
    g5_stop("Symbols must be non-empty strings.")
  }
  x
}

g5_validate_bar_data <- function(bars, require_adjusted = TRUE) {
  if (!is.data.frame(bars)) {
    g5_stop("bars must be a data.frame.")
  }

  missing_cols <- setdiff(g5_required_bar_columns(), names(bars))
  if (length(missing_cols) > 0L) {
    g5_stop(paste("bars missing required columns:", paste(missing_cols, collapse = ", ")))
  }

  bars$symbol <- g5_standardize_symbol(bars$symbol)
  bars$session_date <- as.Date(bars$session_date)
  bars$latest_completed_session <- as.Date(bars$latest_completed_session)
  bars$fetch_start_date <- as.Date(bars$fetch_start_date)
  bars$fetch_end_date <- as.Date(bars$fetch_end_date)

  price_cols <- c("open", "high", "low", "close")
  for (col in price_cols) {
    if (any(!is.finite(as.numeric(bars[[col]])))) {
      g5_stop(paste("Non-finite price values in", col))
    }
  }

  if (any(as.numeric(bars$volume) < 0, na.rm = TRUE)) {
    g5_stop("volume must be non-negative.")
  }

  if (require_adjusted && !all(isTRUE(bars$adjusted) | bars$adjusted == TRUE)) {
    g5_stop("Gen5 v0 requires adjusted daily bars.")
  }

  if (!all(bars$timeframe == "1D")) {
    g5_stop("Gen5 v0 requires timeframe == '1D'.")
  }

  if (any(is.na(bars$data_version_hash) | !nzchar(as.character(bars$data_version_hash)))) {
    g5_stop("data_version_hash must be non-missing and non-empty.")
  }

  key <- paste(bars$symbol, bars$session_date)
  duplicate_n <- sum(duplicated(key))
  if (duplicate_n > 0L) {
    g5_stop(paste("Duplicate symbol/session_date rows detected:", duplicate_n))
  }

  future_rows <- bars$session_date > bars$latest_completed_session
  if (any(future_rows, na.rm = TRUE)) {
    g5_stop("bars include rows after latest_completed_session.")
  }

  bars[order(bars$symbol, bars$session_date), , drop = FALSE]
}

g5_make_data_version_hash <- function(...) {
  values <- paste(..., collapse = "|")
  # Deterministic lightweight hash using base R only. Replace with digest later if needed.
  ints <- utf8ToInt(values)
  hash <- 0
  for (x in ints) {
    hash <- (hash * 131 + x) %% 2147483647
  }
  sprintf("g5_%010d", hash)
}
