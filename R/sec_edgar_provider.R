# Minimal SEC EDGAR provider helpers for the Gen5.4 fundamentals F0 audit.
# Provider-specific URLs, request headers, and response parsing stay here.

g5_sec_validate_cik <- function(cik) {
  cik <- as.character(cik)
  if (length(cik) != 1L || !grepl("^[0-9]{1,10}$", cik)) {
    stop("SEC CIK must contain 1 to 10 digits.", call. = FALSE)
  }
  sprintf("%010d", as.integer(cik))
}

g5_sec_default_user_agent <- function() {
  Sys.getenv(
    "GEN5_SEC_USER_AGENT",
    unset = paste0(
      "Time-Series-Modeling-Gen5/0.1 ",
      "Francisc0Franc0@users.noreply.github.com ",
      "github.com/Francisc0Franc0/Time-Series-Modeling-Gen5"
    )
  )
}

g5_sec_url <- function(kind, cik = NULL, file_name = NULL) {
  if (identical(kind, "submissions")) {
    return(sprintf("https://data.sec.gov/submissions/CIK%s.json", g5_sec_validate_cik(cik)))
  }
  if (identical(kind, "companyfacts")) {
    return(sprintf("https://data.sec.gov/api/xbrl/companyfacts/CIK%s.json", g5_sec_validate_cik(cik)))
  }
  if (identical(kind, "submissions_file")) {
    if (length(file_name) != 1L || !grepl("^CIK[0-9]{10}-submissions-[0-9]{3}\\.json$", file_name)) {
      stop("Unexpected SEC submissions history file name.", call. = FALSE)
    }
    return(sprintf("https://data.sec.gov/submissions/%s", file_name))
  }
  stop("Unsupported SEC request kind.", call. = FALSE)
}

g5_sec_fetch_json <- function(url, destination, user_agent = g5_sec_default_user_agent()) {
  if (!nzchar(user_agent)) stop("SEC requests require a declared user agent.", call. = FALSE)
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(destination, ".partial")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  utils::download.file(
    url,
    destfile = tmp,
    mode = "wb",
    quiet = TRUE,
    headers = c(
      "User-Agent" = user_agent,
      "Accept-Encoding" = "gzip, deflate",
      "Host" = "data.sec.gov"
    )
  )
  if (!file.exists(tmp) || file.info(tmp)$size <= 0) stop("SEC returned an empty response.", call. = FALSE)
  if (!file.rename(tmp, destination)) stop("Could not finalize SEC response file.", call. = FALSE)
  destination
}

g5_sec_read_json <- function(path, simplify = TRUE) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to parse SEC JSON.", call. = FALSE)
  }
  jsonlite::fromJSON(path, simplifyVector = simplify)
}

g5_sec_submission_frame <- function(x) {
  if (is.null(x)) return(data.frame())
  if (is.data.frame(x)) return(x)
  if (is.list(x) && length(x)) {
    lengths <- vapply(x, length, integer(1L))
    if (length(unique(lengths)) == 1L) return(as.data.frame(x, stringsAsFactors = FALSE))
  }
  stop("Unexpected SEC submissions response shape.", call. = FALSE)
}

g5_sec_parse_acceptance <- function(x) {
  x <- as.character(x)
  normalized <- ifelse(
    grepl("Z$|[+-][0-9]{2}:[0-9]{2}$", x),
    x,
    paste0(x, "-04:00")
  )
  as.POSIXct(normalized, tz = "UTC", tryFormats = c(
    "%Y-%m-%dT%H:%M:%OS%z",
    "%Y%m%d%H%M%S%z",
    "%Y-%m-%d %H:%M:%S%z"
  ))
}

g5_sec_companyfacts_long <- function(payload, symbol, cik) {
  facts <- payload$facts
  if (is.null(facts) || !length(facts)) return(data.frame())
  rows <- list()
  index <- 0L
  for (taxonomy in names(facts)) {
    for (concept in names(facts[[taxonomy]])) {
      item <- facts[[taxonomy]][[concept]]
      units <- item$units
      if (is.null(units) || !length(units)) next
      for (unit in names(units)) {
        part <- g5_sec_submission_frame(units[[unit]])
        if (!nrow(part)) next
        part$symbol <- symbol
        part$cik <- g5_sec_validate_cik(cik)
        part$taxonomy <- taxonomy
        part$concept <- concept
        part$label <- if (!is.null(item$label)) item$label else concept
        part$unit <- unit
        index <- index + 1L
        rows[[index]] <- part
      }
    }
  }
  if (!length(rows)) return(data.frame())
  all_names <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(x) {
    missing <- setdiff(all_names, names(x))
    for (name in missing) x[[name]] <- NA
    x[, all_names, drop = FALSE]
  })
  do.call(rbind, rows)
}
