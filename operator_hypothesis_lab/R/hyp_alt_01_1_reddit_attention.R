ha011_stop <- function(message) {
  stop(paste0("[HYP-ALT-01.1] ", message), call. = FALSE)
}

ha011_utc_string <- function(x = Sys.time()) {
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

ha011_et_date <- function(x) {
  as.Date(format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%d", tz = "America/New_York"))
}

ha011_env_or_object <- function(object_name, env_names, default = "") {
  if (exists(object_name, envir = globalenv(), inherits = FALSE)) {
    value <- as.character(get(object_name, envir = globalenv(), inherits = FALSE)[1L])
    if (!is.na(value) && nzchar(value)) return(value)
  }
  for (name in env_names) {
    value <- Sys.getenv(name, unset = "")
    if (nzchar(value)) return(value)
  }
  default
}

ha011_bool <- function(value, default = FALSE) {
  if (is.null(value) || !length(value) || is.na(value[[1L]]) || !nzchar(trimws(as.character(value[[1L]])))) {
    return(default)
  }
  token <- tolower(trimws(as.character(value[[1L]])))
  if (token %in% c("1", "true", "yes", "y")) return(TRUE)
  if (token %in% c("0", "false", "no", "n")) return(FALSE)
  ha011_stop(paste0("Expected a boolean value, received: ", token))
}

ha011_config_from_env <- function(repo_root = normalizePath(".", winslash = "/", mustWork = TRUE)) {
  storage_default <- file.path(repo_root, "data_cache", "operator_hypothesis_lab", "hyp_alt_01_1_wsb")
  list(
    access_approved = ha011_bool(Sys.getenv("GEN5_REDDIT_ACCESS_APPROVED", unset = "false")),
    client_id = Sys.getenv("GEN5_REDDIT_CLIENT_ID", unset = ""),
    client_secret = Sys.getenv("GEN5_REDDIT_CLIENT_SECRET", unset = ""),
    user_agent = Sys.getenv("GEN5_REDDIT_USER_AGENT", unset = ""),
    subreddit = "wallstreetbets",
    token_url = "https://www.reddit.com/api/v1/access_token",
    api_base_url = "https://oauth.reddit.com",
    storage_root = Sys.getenv("GEN5_REDDIT_STORAGE_ROOT", unset = storage_default),
    ticker_registry_path = Sys.getenv(
      "GEN5_REDDIT_TICKER_REGISTRY_PATH",
      unset = file.path(storage_default, "active_us_equity_registry.csv")
    ),
    max_pages = as.integer(Sys.getenv("GEN5_REDDIT_MAX_PAGES", unset = "10")),
    bootstrap_pages = as.integer(Sys.getenv("GEN5_REDDIT_BOOTSTRAP_PAGES", unset = "1")),
    poll_target_minutes = as.numeric(Sys.getenv("GEN5_REDDIT_POLL_TARGET_MINUTES", unset = "2")),
    poll_grace_minutes = as.numeric(Sys.getenv("GEN5_REDDIT_POLL_GRACE_MINUTES", unset = "3"))
  )
}

ha011_placeholder <- function(value) {
  token <- gsub("[^a-z0-9]+", "_", tolower(trimws(as.character(value[[1L]]))))
  token <- gsub("^_+|_+$", "", token)
  token %in% c("client_id", "client_secret", "change_me", "changeme", "dummy", "example", "placeholder", "replace_me", "test", "your_client_id", "your_client_secret") ||
    grepl("^(your|replace|change|dummy|example|placeholder)_", token)
}

ha011_preflight <- function(config = ha011_config_from_env(), require_registry = TRUE, require_runtime = TRUE) {
  registry_present <- file.exists(config$ticker_registry_path)
  runtime <- c("httr", "jsonlite")
  runtime_present <- vapply(runtime, requireNamespace, logical(1), quietly = TRUE)
  checks <- data.frame(
    check = c(
      "reddit_access_explicitly_approved",
      "oauth_client_id_present",
      "oauth_client_secret_present",
      "descriptive_user_agent_present",
      "credentials_not_placeholders",
      "runtime_packages",
      "ticker_registry",
      "html_scraping_disabled",
      "raw_comment_persistence_disabled"
    ),
    status = c(
      if (isTRUE(config$access_approved)) "PASS" else "FAIL",
      if (nzchar(config$client_id)) "PASS" else "FAIL",
      if (nzchar(config$client_secret)) "PASS" else "FAIL",
      if (nzchar(config$user_agent) && grepl("/u/", config$user_agent, fixed = TRUE)) "PASS" else "FAIL",
      if (nzchar(config$client_id) && nzchar(config$client_secret) && !ha011_placeholder(config$client_id) && !ha011_placeholder(config$client_secret)) "PASS" else "FAIL",
      if (!require_runtime) "SKIP" else if (all(runtime_present)) "PASS" else "FAIL",
      if (!require_registry) "SKIP" else if (registry_present) "PASS" else "FAIL",
      "PASS",
      "PASS"
    ),
    detail = c(
      if (isTRUE(config$access_approved)) "Operator attested that Reddit approved this API use case." else "Set GEN5_REDDIT_ACCESS_APPROVED=true only after Reddit approval.",
      if (nzchar(config$client_id)) "Configured outside source control." else "Set GEN5_REDDIT_CLIENT_ID outside source control.",
      if (nzchar(config$client_secret)) "Configured outside source control." else "Set GEN5_REDDIT_CLIENT_SECRET outside source control.",
      if (nzchar(config$user_agent)) "Configured; must identify the app and contact Reddit account." else "Set GEN5_REDDIT_USER_AGENT, including the associated /u/ account.",
      "Placeholder-like values are rejected.",
      if (all(runtime_present)) "httr and jsonlite are available." else paste("Missing:", paste(runtime[!runtime_present], collapse = ", ")),
      if (registry_present) normalizePath(config$ticker_registry_path, winslash = "/", mustWork = FALSE) else "Generate the Alpaca active-US-equity registry first.",
      "Only oauth.reddit.com endpoints are implemented.",
      "Comment bodies are processed in memory and never written to disk."
    ),
    stringsAsFactors = FALSE
  )
  list(ok = !any(checks$status == "FAIL"), checks = checks)
}

ha011_require_preflight <- function(config = ha011_config_from_env()) {
  result <- ha011_preflight(config)
  if (!result$ok) {
    failed <- result$checks$check[result$checks$status == "FAIL"]
    ha011_stop(paste("Live collection preflight failed:", paste(failed, collapse = ", ")))
  }
  invisible(TRUE)
}

ha011_validate_registry <- function(registry) {
  if (!is.data.frame(registry) || !"symbol" %in% names(registry)) {
    ha011_stop("Ticker registry must be a data frame containing symbol.")
  }
  registry$symbol <- toupper(trimws(as.character(registry$symbol)))
  registry <- registry[!is.na(registry$symbol) & nzchar(registry$symbol), , drop = FALSE]
  if (!nrow(registry)) ha011_stop("Ticker registry is empty.")
  if (anyDuplicated(registry$symbol)) ha011_stop("Ticker registry contains duplicate symbols.")
  if (any(!grepl("^[A-Z][A-Z0-9.-]{0,9}$", registry$symbol))) {
    ha011_stop("Ticker registry contains unsupported symbol syntax.")
  }
  registry[order(registry$symbol), , drop = FALSE]
}

ha011_bare_symbol_denylist <- function() {
  c(
    "A", "AI", "ALL", "AM", "ANY", "ARE", "AS", "AT", "BE", "BIG", "BY", "CAN",
    "CEO", "DD", "DO", "EDIT", "ELSE", "EVEN", "EVER", "FOR", "GO", "GOOD", "HAS",
    "HE", "HOLD", "I", "IF", "IMO", "IN", "IS", "IT", "JUST", "LIKE", "LIVE",
    "LOVE", "ME", "NA", "NEW", "NO", "NOT", "NOW", "OF", "ON", "ONE", "OR", "OUT",
    "POST", "SO", "T", "THE", "TO", "TRUE", "UP", "US", "VERY", "WE", "WELL", "YOU"
  )
}

ha011_regex_tokens <- function(pattern, text) {
  match <- gregexpr(pattern, text, perl = TRUE)[[1L]]
  if (identical(match[[1L]], -1L)) return(character())
  regmatches(text, list(match))[[1L]]
}

ha011_clean_symbol_token <- function(x) {
  gsub("[.-]+$", "", toupper(x))
}

ha011_extract_mentions <- function(text, registry, denylist = ha011_bare_symbol_denylist()) {
  registry <- ha011_validate_registry(registry)
  allowed <- registry$symbol
  text <- enc2utf8(as.character(text[[1L]]))
  if (is.na(text) || !nzchar(text) || text %in% c("[deleted]", "[removed]")) {
    return(data.frame(
      ticker = character(), cashtag_occurrences = integer(), bare_occurrences = integer(),
      total_occurrences = integer(), detection_method = character(), stringsAsFactors = FALSE
    ))
  }

  cashtag_raw <- ha011_regex_tokens("(?<![A-Za-z0-9])\\$[A-Za-z][A-Za-z0-9.-]{0,9}", text)
  cashtags <- ha011_clean_symbol_token(sub("^\\$", "", cashtag_raw))
  cashtags <- cashtags[cashtags %in% allowed]

  without_cashtags <- gsub("(?<![A-Za-z0-9])\\$[A-Za-z][A-Za-z0-9.-]{0,9}", " ", text, perl = TRUE)
  bare <- ha011_clean_symbol_token(ha011_regex_tokens("(?<![A-Za-z0-9])[A-Z][A-Z0-9.-]{0,9}(?![A-Za-z0-9])", without_cashtags))
  bare <- bare[bare %in% allowed & nchar(bare) >= 2L & !bare %in% denylist]

  tickers <- sort(unique(c(cashtags, bare)))
  if (!length(tickers)) {
    return(data.frame(
      ticker = character(), cashtag_occurrences = integer(), bare_occurrences = integer(),
      total_occurrences = integer(), detection_method = character(), stringsAsFactors = FALSE
    ))
  }
  cashtag_n <- vapply(tickers, function(x) sum(cashtags == x), integer(1))
  bare_n <- vapply(tickers, function(x) sum(bare == x), integer(1))
  data.frame(
    ticker = tickers,
    cashtag_occurrences = cashtag_n,
    bare_occurrences = bare_n,
    total_occurrences = cashtag_n + bare_n,
    detection_method = ifelse(cashtag_n > 0L & bare_n > 0L, "BOTH", ifelse(cashtag_n > 0L, "CASHTAG", "BARE_SYMBOL")),
    stringsAsFactors = FALSE
  )
}

ha011_empty_observations <- function() {
  data.frame(
    comment_id = character(), created_at_utc = character(), date_et = as.Date(character()),
    collected_first_at_utc = character(), content_available = logical(),
    last_verified_at_utc = character(), stringsAsFactors = FALSE
  )
}

ha011_empty_mentions <- function() {
  data.frame(
    comment_id = character(), created_at_utc = character(), date_et = as.Date(character()),
    ticker = character(), cashtag_occurrences = integer(), bare_occurrences = integer(),
    total_occurrences = integer(), detection_method = character(),
    collected_first_at_utc = character(), stringsAsFactors = FALSE
  )
}

ha011_map_comment <- function(comment, registry, collected_at_utc) {
  id <- as.character(comment$id %||% "")
  created_epoch <- suppressWarnings(as.numeric(comment$created_utc %||% NA_real_))
  body <- as.character(comment$body %||% "")
  if (!nzchar(id) || !is.finite(created_epoch)) return(NULL)
  created <- as.POSIXct(created_epoch, origin = "1970-01-01", tz = "UTC")
  created_at_utc <- ha011_utc_string(created)
  date_et <- ha011_et_date(created)
  available <- nzchar(body) && !body %in% c("[deleted]", "[removed]")
  obs <- data.frame(
    comment_id = id,
    created_at_utc = created_at_utc,
    date_et = date_et,
    collected_first_at_utc = collected_at_utc,
    content_available = available,
    last_verified_at_utc = collected_at_utc,
    stringsAsFactors = FALSE
  )
  extracted <- ha011_extract_mentions(body, registry)
  if (nrow(extracted)) {
    mentions <- cbind(
      data.frame(comment_id = id, created_at_utc = created_at_utc, date_et = date_et, stringsAsFactors = FALSE),
      extracted,
      data.frame(collected_first_at_utc = collected_at_utc, stringsAsFactors = FALSE)
    )
  } else {
    mentions <- ha011_empty_mentions()
  }
  list(observation = obs, mentions = mentions)
}

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

ha011_parse_listing <- function(parsed, registry, collected_at_utc) {
  children <- parsed$data$children %||% list()
  if (!length(children)) {
    return(list(observations = ha011_empty_observations(), mentions = ha011_empty_mentions(), after = NULL))
  }
  mapped <- lapply(children, function(child) {
    if (!identical(as.character(child$kind %||% ""), "t1")) return(NULL)
    ha011_map_comment(child$data %||% list(), registry, collected_at_utc)
  })
  mapped <- Filter(Negate(is.null), mapped)
  observations <- if (length(mapped)) do.call(rbind, lapply(mapped, `[[`, "observation")) else ha011_empty_observations()
  mention_list <- Filter(function(x) nrow(x) > 0L, lapply(mapped, `[[`, "mentions"))
  mentions <- if (length(mention_list)) do.call(rbind, mention_list) else ha011_empty_mentions()
  list(observations = observations, mentions = mentions, after = parsed$data$after %||% NULL)
}

ha011_daily_attention <- function(observations, mentions) {
  if (!nrow(observations) || !nrow(mentions)) {
    return(data.frame(
      date_et = as.Date(character()), ticker = character(), comments_mentioning = integer(),
      total_occurrences = integer(), cashtag_comments = integer(), bare_symbol_comments = integer(),
      all_wsb_comments = integer(), mention_share = numeric(), attention_rank = integer(),
      stringsAsFactors = FALSE
    ))
  }
  totals <- aggregate(comment_id ~ date_et, observations, function(x) length(unique(x)))
  names(totals)[2L] <- "all_wsb_comments"
  keys <- unique(mentions[c("date_et", "ticker")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    x <- mentions[mentions$date_et == keys$date_et[[i]] & mentions$ticker == keys$ticker[[i]], , drop = FALSE]
    data.frame(
      date_et = keys$date_et[[i]], ticker = keys$ticker[[i]],
      comments_mentioning = length(unique(x$comment_id)),
      total_occurrences = sum(x$total_occurrences),
      cashtag_comments = length(unique(x$comment_id[x$cashtag_occurrences > 0L])),
      bare_symbol_comments = length(unique(x$comment_id[x$bare_occurrences > 0L])),
      stringsAsFactors = FALSE
    )
  })
  out <- merge(do.call(rbind, rows), totals, by = "date_et", all.x = TRUE, sort = FALSE)
  out$mention_share <- out$comments_mentioning / out$all_wsb_comments
  out$attention_rank <- ave(-out$comments_mentioning, out$date_et, FUN = function(x) rank(x, ties.method = "min"))
  out$attention_rank <- as.integer(out$attention_rank)
  out[order(out$date_et, out$attention_rank, out$ticker), , drop = FALSE]
}

ha011_daily_health <- function(run_ledger) {
  if (!nrow(run_ledger)) return(data.frame())
  run_dates <- as.Date(run_ledger$run_date_et)
  date_tokens <- unique(as.character(run_dates))
  do.call(rbind, lapply(date_tokens, function(date_token) {
    date <- as.Date(date_token)
    x <- run_ledger[!is.na(run_dates) & as.character(run_dates) == date_token, , drop = FALSE]
    healthy <- x$status == "PASS_FORWARD_OVERLAP"
    data.frame(
      date_et = date,
      collection_runs = nrow(x),
      healthy_runs = sum(healthy),
      healthy_run_fraction = mean(healthy),
      max_poll_gap_minutes = if (all(is.na(x$prior_poll_gap_minutes))) NA_real_ else max(x$prior_poll_gap_minutes, na.rm = TRUE),
      comments_received = sum(x$comments_received),
      new_comments = sum(x$new_comments),
      page_cap_warnings = sum(x$status == "WARN_PAGE_CAP_WITHOUT_OVERLAP", na.rm = TRUE),
      coverage_status = if (any(x$status == "WARN_PAGE_CAP_WITHOUT_OVERLAP", na.rm = TRUE)) "WARN_POSSIBLE_GAP" else if (all(x$status == "BOOTSTRAP_NO_COVERAGE_AUTHORITY", na.rm = TRUE)) "WARMUP" else if (all(healthy | x$status == "BOOTSTRAP_NO_COVERAGE_AUTHORITY", na.rm = TRUE)) "PASS_AFTER_WARMUP" else "REVIEW",
      stringsAsFactors = FALSE
    )
  }))
}

ha011_atomic_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(pattern = paste0(basename(path), "."), tmpdir = dirname(path))
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  utils::write.csv(x, tmp, row.names = FALSE, na = "")
  if (!file.rename(tmp, path)) {
    if (!file.copy(tmp, path, overwrite = TRUE)) ha011_stop(paste("Could not write", path))
    unlink(tmp)
  }
  invisible(path)
}

ha011_read_csv_or_empty <- function(path, empty) {
  if (!file.exists(path)) return(empty)
  x <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = "")
  if ("date_et" %in% names(x)) x$date_et <- as.Date(x$date_et)
  x
}

ha011_merge_unique <- function(existing, incoming, keys) {
  if (!nrow(incoming)) return(existing)
  combined <- rbind(existing, incoming)
  key <- do.call(paste, c(combined[keys], sep = "\r"))
  combined[!duplicated(key), , drop = FALSE]
}

ha011_acquire_storage_lock <- function(storage_root) {
  dir.create(storage_root, recursive = TRUE, showWarnings = FALSE)
  lock_path <- file.path(storage_root, ".ha011_write_lock")
  if (!dir.create(lock_path, showWarnings = FALSE)) {
    ha011_stop(paste("Storage is locked by another collector or reconciliation process:", lock_path))
  }
  lock_path
}

ha011_release_storage_lock <- function(lock_path) {
  if (dir.exists(lock_path)) unlink(lock_path, recursive = TRUE, force = TRUE)
  invisible(TRUE)
}

ha011_oauth_token <- function(config) {
  response <- httr::POST(
    config$token_url,
    httr::authenticate(config$client_id, config$client_secret),
    httr::user_agent(config$user_agent),
    body = list(grant_type = "client_credentials"),
    encode = "form"
  )
  text <- httr::content(response, as = "text", encoding = "UTF-8")
  if (httr::http_error(response)) ha011_stop(paste("OAuth token request failed:", httr::status_code(response), substr(text, 1L, 300L)))
  parsed <- jsonlite::fromJSON(text, simplifyVector = TRUE)
  token <- as.character(parsed$access_token %||% "")
  if (!nzchar(token)) ha011_stop("OAuth response did not contain an access token.")
  token
}

ha011_fetch_comment_page <- function(config, token, after = NULL, limit = 100L) {
  query <- list(limit = as.integer(limit), raw_json = 1L)
  if (!is.null(after) && nzchar(as.character(after))) query$after <- as.character(after)
  response <- httr::GET(
    paste0(sub("/+$", "", config$api_base_url), "/r/", config$subreddit, "/comments"),
    httr::add_headers(Authorization = paste("bearer", token)),
    httr::user_agent(config$user_agent),
    query = query
  )
  text <- httr::content(response, as = "text", encoding = "UTF-8")
  if (httr::http_error(response)) ha011_stop(paste("Comment listing request failed:", httr::status_code(response), substr(text, 1L, 300L)))
  list(
    parsed = jsonlite::fromJSON(text, simplifyVector = FALSE),
    rate_remaining = suppressWarnings(as.numeric(httr::headers(response)[["x-ratelimit-remaining"]] %||% NA_real_)),
    rate_reset_seconds = suppressWarnings(as.numeric(httr::headers(response)[["x-ratelimit-reset"]] %||% NA_real_))
  )
}

ha011_fetch_info_batch <- function(config, token, comment_ids) {
  if (!length(comment_ids) || length(comment_ids) > 100L) ha011_stop("Info reconciliation requires 1 to 100 comment IDs.")
  fullnames <- paste0("t1_", sub("^t1_", "", comment_ids))
  response <- httr::GET(
    paste0(sub("/+$", "", config$api_base_url), "/api/info"),
    httr::add_headers(Authorization = paste("bearer", token)),
    httr::user_agent(config$user_agent),
    query = list(id = paste(fullnames, collapse = ","), raw_json = 1L)
  )
  text <- httr::content(response, as = "text", encoding = "UTF-8")
  if (httr::http_error(response)) ha011_stop(paste("Comment reconciliation request failed:", httr::status_code(response), substr(text, 1L, 300L)))
  jsonlite::fromJSON(text, simplifyVector = FALSE)
}

ha011_active_ids_from_info <- function(parsed) {
  children <- parsed$data$children %||% list()
  if (!length(children)) return(character())
  ids <- vapply(children, function(child) {
    data <- child$data %||% list()
    id <- as.character(data$id %||% "")
    body <- as.character(data$body %||% "")
    if (!identical(as.character(child$kind %||% ""), "t1") || !nzchar(id) || !nzchar(body) || body %in% c("[deleted]", "[removed]")) "" else id
  }, character(1))
  unique(ids[nzchar(ids)])
}

ha011_collect_once <- function(
  config = ha011_config_from_env(),
  now = Sys.time(),
  fetch_page = ha011_fetch_comment_page,
  token_fetch = ha011_oauth_token
) {
  ha011_require_preflight(config)
  registry <- ha011_validate_registry(utils::read.csv(config$ticker_registry_path, stringsAsFactors = FALSE, na.strings = ""))
  lock_path <- ha011_acquire_storage_lock(config$storage_root)
  on.exit(ha011_release_storage_lock(lock_path), add = TRUE)
  paths <- list(
    observations = file.path(config$storage_root, "comment_observation_ledger.csv"),
    mentions = file.path(config$storage_root, "comment_ticker_ledger.csv"),
    runs = file.path(config$storage_root, "collection_run_ledger.csv"),
    attention = file.path(config$storage_root, "daily_ticker_attention.csv"),
    health = file.path(config$storage_root, "daily_collection_health.csv")
  )
  observations <- ha011_read_csv_or_empty(paths$observations, ha011_empty_observations())
  mentions <- ha011_read_csv_or_empty(paths$mentions, ha011_empty_mentions())
  runs <- if (file.exists(paths$runs)) utils::read.csv(paths$runs, stringsAsFactors = FALSE) else data.frame()
  known_ids <- observations$comment_id
  first_run <- !length(known_ids)
  pages_allowed <- if (first_run) config$bootstrap_pages else config$max_pages
  if (!is.finite(pages_allowed) || pages_allowed < 1L) ha011_stop("Page limit must be at least one.")

  collected_at <- ha011_utc_string(now)
  token <- token_fetch(config)
  after <- NULL
  page_results <- list()
  overlap_found <- FALSE
  page_cap_hit <- FALSE
  rate_remaining <- NA_real_
  rate_reset <- NA_real_
  for (page_index in seq_len(pages_allowed)) {
    response <- fetch_page(config, token, after = after, limit = 100L)
    rate_remaining <- response$rate_remaining
    rate_reset <- response$rate_reset_seconds
    mapped <- ha011_parse_listing(response$parsed, registry, collected_at)
    page_results[[page_index]] <- mapped
    if (!first_run && any(mapped$observations$comment_id %in% known_ids)) {
      overlap_found <- TRUE
      break
    }
    after <- mapped$after
    if (is.null(after) || !nzchar(as.character(after))) break
    if (page_index == pages_allowed) page_cap_hit <- TRUE
  }

  page_obs <- Filter(function(x) nrow(x) > 0L, lapply(page_results, `[[`, "observations"))
  incoming_obs <- if (length(page_obs)) do.call(rbind, page_obs) else ha011_empty_observations()
  incoming_obs <- incoming_obs[!duplicated(incoming_obs$comment_id), , drop = FALSE]
  page_mentions <- Filter(function(x) nrow(x) > 0L, lapply(page_results, `[[`, "mentions"))
  incoming_mentions <- if (length(page_mentions)) do.call(rbind, page_mentions) else ha011_empty_mentions()
  incoming_mentions <- incoming_mentions[!duplicated(paste(incoming_mentions$comment_id, incoming_mentions$ticker, sep = "\r")), , drop = FALSE]
  new_ids <- setdiff(incoming_obs$comment_id, known_ids)
  observations <- ha011_merge_unique(observations, incoming_obs, "comment_id")
  mentions <- ha011_merge_unique(mentions, incoming_mentions[incoming_mentions$comment_id %in% new_ids, , drop = FALSE], c("comment_id", "ticker"))

  previous_time <- if (nrow(runs)) suppressWarnings(as.POSIXct(tail(runs$run_finished_at_utc, 1L), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) else as.POSIXct(NA)
  prior_gap <- if (is.na(previous_time)) NA_real_ else as.numeric(difftime(as.POSIXct(now, tz = "UTC"), previous_time, units = "mins"))
  status <- if (first_run) {
    "BOOTSTRAP_NO_COVERAGE_AUTHORITY"
  } else if (overlap_found && (is.na(prior_gap) || prior_gap <= config$poll_target_minutes + config$poll_grace_minutes)) {
    "PASS_FORWARD_OVERLAP"
  } else if (page_cap_hit && !overlap_found) {
    "WARN_PAGE_CAP_WITHOUT_OVERLAP"
  } else if (overlap_found) {
    "WARN_LATE_POLL_OVERLAP_RECOVERED"
  } else {
    "WARN_NO_OVERLAP"
  }
  finished <- Sys.time()
  run_row <- data.frame(
    run_id = paste0(gsub("[-:TZ]", "", collected_at), "_", Sys.getpid()),
    run_started_at_utc = collected_at,
    run_finished_at_utc = ha011_utc_string(finished),
    run_date_et = ha011_et_date(now),
    status = status,
    pages_fetched = length(page_results),
    comments_received = nrow(incoming_obs),
    new_comments = length(new_ids),
    overlap_found = overlap_found,
    prior_poll_gap_minutes = prior_gap,
    oldest_comment_utc = if (nrow(incoming_obs)) min(incoming_obs$created_at_utc) else NA_character_,
    newest_comment_utc = if (nrow(incoming_obs)) max(incoming_obs$created_at_utc) else NA_character_,
    rate_remaining = rate_remaining,
    rate_reset_seconds = rate_reset,
    registry_symbols = nrow(registry),
    stringsAsFactors = FALSE
  )
  runs <- if (nrow(runs)) rbind(runs, run_row) else run_row
  attention <- ha011_daily_attention(observations, mentions)
  health <- ha011_daily_health(runs)
  ha011_atomic_write_csv(observations, paths$observations)
  ha011_atomic_write_csv(mentions, paths$mentions)
  ha011_atomic_write_csv(runs, paths$runs)
  ha011_atomic_write_csv(attention, paths$attention)
  ha011_atomic_write_csv(health, paths$health)
  list(status = status, run = run_row, paths = paths, daily_attention = attention, daily_health = health)
}

ha011_reconcile_once <- function(
  config = ha011_config_from_env(),
  now = Sys.time(),
  max_batches = as.integer(Sys.getenv("GEN5_REDDIT_RECONCILE_MAX_BATCHES", unset = "50")),
  fetch_info = ha011_fetch_info_batch,
  token_fetch = ha011_oauth_token
) {
  ha011_require_preflight(config)
  lock_path <- ha011_acquire_storage_lock(config$storage_root)
  on.exit(ha011_release_storage_lock(lock_path), add = TRUE)
  paths <- list(
    observations = file.path(config$storage_root, "comment_observation_ledger.csv"),
    mentions = file.path(config$storage_root, "comment_ticker_ledger.csv"),
    runs = file.path(config$storage_root, "collection_run_ledger.csv"),
    attention = file.path(config$storage_root, "daily_ticker_attention.csv"),
    health = file.path(config$storage_root, "daily_collection_health.csv"),
    reconciliation = file.path(config$storage_root, "deletion_reconciliation_ledger.csv")
  )
  observations <- ha011_read_csv_or_empty(paths$observations, ha011_empty_observations())
  mentions <- ha011_read_csv_or_empty(paths$mentions, ha011_empty_mentions())
  if (!nrow(observations)) {
    return(list(status = "NO_COMMENTS_TO_RECONCILE", checked = 0L, purged = 0L, paths = paths))
  }
  if (!is.finite(max_batches) || max_batches < 1L) ha011_stop("Reconciliation batch limit must be at least one.")
  order_key <- ifelse(is.na(observations$last_verified_at_utc) | !nzchar(observations$last_verified_at_utc), "", observations$last_verified_at_utc)
  candidates <- observations$comment_id[order(order_key, observations$created_at_utc)]
  candidates <- head(candidates, 100L * max_batches)
  batches <- split(candidates, ceiling(seq_along(candidates) / 100L))
  token <- token_fetch(config)
  active <- character()
  checked <- character()
  for (ids in batches) {
    parsed <- fetch_info(config, token, ids)
    active <- c(active, ha011_active_ids_from_info(parsed))
    checked <- c(checked, ids)
  }
  checked <- unique(checked)
  active <- unique(active)
  removed <- setdiff(checked, active)
  checked_at <- ha011_utc_string(now)
  observations$last_verified_at_utc[observations$comment_id %in% active] <- checked_at
  if (length(removed)) {
    observations <- observations[!observations$comment_id %in% removed, , drop = FALSE]
    mentions <- mentions[!mentions$comment_id %in% removed, , drop = FALSE]
  }
  attention <- ha011_daily_attention(observations, mentions)
  runs <- if (file.exists(paths$runs)) utils::read.csv(paths$runs, stringsAsFactors = FALSE) else data.frame()
  health <- if (nrow(runs)) ha011_daily_health(runs) else data.frame()
  reconciliation <- if (file.exists(paths$reconciliation)) utils::read.csv(paths$reconciliation, stringsAsFactors = FALSE) else data.frame()
  row <- data.frame(
    reconciled_at_utc = checked_at,
    comments_checked = length(checked),
    comments_active = length(intersect(checked, active)),
    comments_purged = length(removed),
    batches = length(batches),
    status = if (length(removed)) "PASS_PURGED_REMOVED_CONTENT" else "PASS_NO_REMOVALS_FOUND",
    stringsAsFactors = FALSE
  )
  reconciliation <- if (nrow(reconciliation)) rbind(reconciliation, row) else row
  ha011_atomic_write_csv(observations, paths$observations)
  ha011_atomic_write_csv(mentions, paths$mentions)
  ha011_atomic_write_csv(attention, paths$attention)
  if (nrow(health)) ha011_atomic_write_csv(health, paths$health)
  ha011_atomic_write_csv(reconciliation, paths$reconciliation)
  list(status = row$status, checked = length(checked), purged = length(removed), paths = paths)
}

ha011_alpaca_registry <- function(key_id, secret_key, as_of = Sys.time(), base_url = "https://api.alpaca.markets") {
  if (!nzchar(key_id) || !nzchar(secret_key)) ha011_stop("Alpaca credentials are required to generate the symbol registry.")
  response <- httr::GET(
    paste0(sub("/+$", "", base_url), "/v2/assets"),
    httr::add_headers(`APCA-API-KEY-ID` = key_id, `APCA-API-SECRET-KEY` = secret_key),
    query = list(status = "active", asset_class = "us_equity")
  )
  text <- httr::content(response, as = "text", encoding = "UTF-8")
  if (httr::http_error(response)) ha011_stop(paste("Alpaca asset-registry request failed:", httr::status_code(response), substr(text, 1L, 300L)))
  assets <- jsonlite::fromJSON(text, simplifyDataFrame = TRUE)
  if (is.data.frame(assets) && "class" %in% names(assets) && !"asset_class" %in% names(assets)) {
    names(assets)[names(assets) == "class"] <- "asset_class"
  }
  required <- c("symbol", "name", "exchange", "asset_class", "status", "tradable")
  if (!is.data.frame(assets) || !all(required %in% names(assets))) ha011_stop("Alpaca asset response is missing required fields.")
  assets <- assets[assets$status == "active" & assets$asset_class == "us_equity", , drop = FALSE]
  keep <- intersect(c("symbol", "name", "exchange", "asset_class", "status", "tradable", "marginable", "shortable", "easy_to_borrow", "fractionable"), names(assets))
  registry <- assets[keep]
  registry$registry_as_of_utc <- ha011_utc_string(as_of)
  ha011_validate_registry(registry)
}
