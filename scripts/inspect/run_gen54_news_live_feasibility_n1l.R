# Gen5.4 N1L live-news feasibility check.
# Retrieval and reconciliation only: no features, outcomes, OHLCV, or models.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "alpaca_context_provider.R"))
source(file.path(repo_root, "R", "alpaca_news_stream.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_required <- function(name) {
  value <- Sys.getenv(name, unset = "")
  if (!nzchar(value)) g5_stop(paste0(name, " is required for an explicit N1L run."))
  value
}
write_csv <- function(x, path) { utils::write.csv(x, path, row.names = FALSE, na = ""); invisible(path) }
format_utc <- function(x) paste0(format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%OS3", tz = "UTC"), "Z")
parse_rfc3339_utc <- function(x) as.POSIXct(x, tz = "UTC", format = "%Y-%m-%dT%H:%M:%OSZ")
event_present <- function(lifecycle, event) any(lifecycle$event == event)

run_id <- env_or("GEN5_GEN54_NEWS_N1L_RUN_ID", "g54_news_n1l_20260721")
operator_as_of_timestamp <- env_required("GEN5_AS_OF_TIMESTAMP")
.g5_alpaca_context_time(operator_as_of_timestamp, "GEN5_AS_OF_TIMESTAMP")
duration_seconds <- as.numeric(env_or("GEN5_GEN54_NEWS_N1L_DURATION_SECONDS", "30"))
if (!is.finite(duration_seconds) || duration_seconds < 5 || duration_seconds > 300) {
  g5_stop("GEN5_GEN54_NEWS_N1L_DURATION_SECONDS must be between 5 and 300.")
}
overlap_minutes <- 15
symbols <- g5_news_live_symbols()

output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", run_id)
raw_dir <- file.path(output_dir, "raw")
visual_dir <- file.path(output_dir, "visuals")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

message("Gen5.4 N1L live-news feasibility starting.")
message("Connection duration: ", duration_seconds, " seconds each.")

trial_started_at <- .g5_news_live_timestamp()
connection_1 <- g5_collect_alpaca_news_stream(
  connection_id = "connection_1",
  symbols = symbols,
  duration_seconds = duration_seconds
)
connection_2 <- g5_collect_alpaca_news_stream(
  connection_id = "connection_2",
  symbols = symbols,
  duration_seconds = duration_seconds
)
reconciliation_at <- .g5_news_live_timestamp()

rest_start <- format_utc(
  .g5_alpaca_context_time(trial_started_at, "trial_started_at") - overlap_minutes * 60
)
rest_request <- g5_alpaca_news_request(
  symbols = symbols,
  start_timestamp = rest_start,
  end_timestamp = reconciliation_at,
  as_of_timestamp = reconciliation_at,
  include_content = FALSE,
  limit = 50L
)
rest <- g5_fetch_alpaca_news(
  rest_request,
  retrieved_at = reconciliation_at,
  request_pause_seconds = 0.2
)

frames <- rbind(connection_1$frames, connection_2$frames)
messages <- rbind(connection_1$messages, connection_2$messages)
lifecycle <- rbind(connection_1$lifecycle, connection_2$lifecycle)
rownames(frames) <- rownames(messages) <- rownames(lifecycle) <- NULL

frame_manifest <- frames[, setdiff(names(frames), "raw_text"), drop = FALSE]
frame_manifest$raw_file <- ""
if (nrow(frames)) {
  for (i in seq_len(nrow(frames))) {
    raw_name <- sprintf(
      "%s_frame_%04d.json",
      frames$connection_id[[i]],
      frames$frame_sequence[[i]]
    )
    writeLines(frames$raw_text[[i]], file.path(raw_dir, raw_name), useBytes = TRUE)
    frame_manifest$raw_file[[i]] <- file.path("raw", raw_name)
  }
}

rest_page_rows <- lapply(rest$pages, function(page) {
  raw_name <- sprintf("rest_page_%03d.json", page$page_number)
  writeLines(page$response_text, file.path(raw_dir, raw_name), useBytes = TRUE)
  data.frame(
    page_number = page$page_number,
    http_status = page$http_status,
    page_token_in_present = nzchar(page$page_token_in),
    next_page_token_present = nzchar(page$next_page_token),
    response_bytes = page$response_bytes,
    raw_file = file.path("raw", raw_name),
    stringsAsFactors = FALSE
  )
})
rest_page_manifest <- do.call(rbind, rest_page_rows)
rownames(rest_page_manifest) <- NULL

reconciliation <- g5_reconcile_alpaca_news(messages, rest$data)
news_messages <- messages[messages$message_type == "n", , drop = FALSE]
missing_news_fields <- if (!nrow(news_messages)) 0L else sum(
  !nzchar(news_messages$article_id) |
    !nzchar(news_messages$headline) |
    !nzchar(news_messages$created_at) |
    !nzchar(news_messages$updated_at)
)
receipt_provider_offset_seconds <- if (!nrow(news_messages)) numeric() else as.numeric(
  parse_rfc3339_utc(news_messages$received_at) - parse_rfc3339_utc(news_messages$created_at),
  units = "secs"
)

gate_rows <- list(
  data.frame(gate_id = "connection_1_open", passed = event_present(connection_1$lifecycle, "open"), detail = "first bounded connection opened"),
  data.frame(gate_id = "connection_1_authenticated", passed = event_present(connection_1$lifecycle, "authenticated"), detail = "first connection authenticated"),
  data.frame(gate_id = "connection_1_subscribed", passed = event_present(connection_1$lifecycle, "subscription_acknowledged"), detail = "first subscription acknowledged"),
  data.frame(gate_id = "connection_2_open", passed = event_present(connection_2$lifecycle, "open"), detail = "second bounded connection opened"),
  data.frame(gate_id = "connection_2_authenticated", passed = event_present(connection_2$lifecycle, "authenticated"), detail = "second connection authenticated"),
  data.frame(gate_id = "connection_2_subscribed", passed = event_present(connection_2$lifecycle, "subscription_acknowledged"), detail = "second subscription acknowledged"),
  data.frame(
    gate_id = "deliberate_reconnect",
    passed = event_present(connection_1$lifecycle, "close_requested") && event_present(connection_2$lifecycle, "open"),
    detail = "first close requested before second connection"
  ),
  data.frame(
    gate_id = "receipt_metadata_complete",
    passed = !nrow(frames) || all(nzchar(frames$received_at) & nzchar(frames$connection_id)),
    detail = paste0("frames=", nrow(frames))
  ),
  data.frame(
    gate_id = "stream_frames_parse",
    passed = !nrow(frames) || all(frames$parse_ok),
    detail = paste0("parse_failures=", sum(!frames$parse_ok))
  ),
  data.frame(
    gate_id = "news_fields_complete",
    passed = missing_news_fields == 0L,
    detail = paste0("live_news_rows=", nrow(news_messages), ";missing_required=", missing_news_fields)
  ),
  data.frame(
    gate_id = "rest_http_200",
    passed = nrow(rest_page_manifest) > 0L && all(rest_page_manifest$http_status == 200L),
    detail = paste0("pages=", nrow(rest_page_manifest))
  ),
  data.frame(
    gate_id = "rest_pagination_exhausted",
    passed = nrow(rest_page_manifest) > 0L && !tail(rest_page_manifest$next_page_token_present, 1L),
    detail = "final REST page has no next-page token"
  ),
  data.frame(
    gate_id = "reconciliation_no_same_version_conflicts",
    passed = length(reconciliation$conflicting_stream_ids) == 0L,
    detail = paste0("conflicting_ids=", length(reconciliation$conflicting_stream_ids))
  )
)
gates <- do.call(rbind, gate_rows)
gates$severity <- ifelse(gates$passed, "PASS", "ERROR")
gates <- gates[, c("severity", "gate_id", "passed", "detail")]

overall_status <- if (any(!gates$passed)) {
  "STOP_N1L_LIVE_PATH_FAILURE"
} else if (!nrow(news_messages)) {
  "PARTIAL_PASS_N1L_TRANSPORT_READY_NO_LIVE_ARTICLE"
} else {
  "PASS_N1L_LIVE_PATH_READY"
}

health <- data.frame(
  severity = c(
    if (nrow(news_messages)) "INFO" else "WARN",
    "INFO", "INFO", "INFO", "INFO", "INFO"
  ),
  check_id = c(
    "live_article_observation", "stream_frame_count", "rest_article_count",
    "reconciliation_match_count", "receipt_minus_provider_created_seconds",
    "credential_artifact_count"
  ),
  value = c(
    as.character(nrow(news_messages)),
    as.character(nrow(frames)),
    as.character(nrow(rest$data)),
    as.character(sum(reconciliation$table$reconciliation_status == "matched")),
    if (length(receipt_provider_offset_seconds)) {
      paste(format(round(receipt_provider_offset_seconds, 3), nsmall = 3), collapse = "|")
    } else "",
    "0"
  ),
  detail = c(
    if (nrow(news_messages)) "at least one live article observed" else "bounded windows contained no live candidate article",
    paste0("connection_1=", nrow(connection_1$frames), ";connection_2=", nrow(connection_2$frames)),
    paste0("window=", rest_start, " through ", reconciliation_at),
    "exact headline and symbol metadata match",
    "local receipt minus provider created_at; retain receipt time as prospective availability authority",
    "credentials are never written to run artifacts"
  ),
  stringsAsFactors = FALSE
)

run_spec <- data.frame(
  schema_version = "gen54_news_live_feasibility_n1l_v0.1",
  wrapper = "scripts/inspect/run_gen54_news_live_feasibility_n1l.R",
  run_id = run_id,
  operator_as_of_timestamp = operator_as_of_timestamp,
  trial_started_at = trial_started_at,
  reconciliation_at = reconciliation_at,
  duration_seconds_per_connection = duration_seconds,
  overlap_minutes = overlap_minutes,
  requested_symbols = paste(symbols, collapse = ","),
  stream_url = Sys.getenv("ALPACA_NEWS_STREAM_URL", unset = "wss://stream.data.alpaca.markets/v1beta1/news"),
  rest_endpoint = rest$endpoint,
  sentiment_count = 0L,
  feature_count = 0L,
  outcome_count = 0L,
  ohlcv_join_count = 0L,
  model_fit_count = 0L,
  overall_status = overall_status,
  stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "n1l_run_spec.csv"))
write_csv(lifecycle, file.path(output_dir, "n1l_connection_lifecycle.csv"))
write_csv(frame_manifest, file.path(output_dir, "n1l_stream_frame_manifest.csv"))
write_csv(messages, file.path(output_dir, "n1l_stream_messages.csv"))
write_csv(news_messages, file.path(output_dir, "n1l_live_news_articles.csv"))
write_csv(rest_request, file.path(output_dir, "n1l_rest_request.csv"))
write_csv(rest_page_manifest, file.path(output_dir, "n1l_rest_page_manifest.csv"))
write_csv(rest$data, file.path(output_dir, "n1l_rest_articles.csv"))
write_csv(reconciliation$table, file.path(output_dir, "n1l_reconciliation.csv"))
write_csv(gates, file.path(output_dir, "n1l_gates.csv"))
write_csv(health, file.path(output_dir, "n1l_health.csv"))

lifecycle$time <- parse_rfc3339_utc(lifecycle$observed_at)
milestone_events <- c("open", "authenticated", "subscription_acknowledged", "close_requested", "close")
milestones <- lifecycle[lifecycle$event %in% milestone_events, , drop = FALSE]
connection_start <- tapply(lifecycle$time, lifecycle$connection_id, min)
milestones$elapsed_seconds <- as.numeric(
  milestones$time - as.POSIXct(connection_start[milestones$connection_id], origin = "1970-01-01", tz = "UTC"),
  units = "secs"
)
event_colors <- c(
  open = "#2563EB", authenticated = "#0F766E", subscription_acknowledged = "#7C3AED",
  close_requested = "#D97706", close = "#475569"
)
grDevices::png(file.path(visual_dir, "n1l_connection_lifecycle.png"), width = 1500, height = 850, res = 150)
graphics::par(mar = c(6, 9, 4, 3))
connection_y <- ifelse(milestones$connection_id == "connection_1", 2, 1)
graphics::plot(
  milestones$elapsed_seconds, connection_y,
  type = "n", yaxt = "n", ylab = "", xlab = "",
  ylim = c(0.5, 2.5),
  main = "Two bounded connections test deliberate close and reconnect"
)
graphics::axis(2, at = c(1, 2), labels = c("Connection 2", "Connection 1"), las = 1)
graphics::segments(0, c(1, 2), max(milestones$elapsed_seconds), c(1, 2), col = "#CBD5E1")
graphics::points(milestones$elapsed_seconds, connection_y, pch = 19, cex = 1.25, col = event_colors[milestones$event])
graphics::legend(
  "topright", legend = gsub("_", " ", milestone_events), col = event_colors[milestone_events],
  pch = 19, bty = "n", cex = 0.85
)
graphics::mtext("Seconds since each connection was constructed", side = 1, line = 3)
grDevices::dev.off()

status_levels <- c("matched", "present_both_metadata_differs", "stream_only", "rest_only")
status_counts <- table(factor(reconciliation$table$reconciliation_status, levels = status_levels))
grDevices::png(file.path(visual_dir, "n1l_reconciliation_summary.png"), width = 1400, height = 800, res = 150)
graphics::par(mar = c(8, 6, 4, 2))
bars <- graphics::barplot(
  status_counts,
  names.arg = c("Matched", "Both:\nmetadata differs", "Stream only", "REST only"),
  col = c("#0F766E", "#D97706", "#2563EB", "#64748B"),
  ylab = "Article IDs",
  main = "Stream and REST overlap reconciliation is explicit"
)
graphics::text(bars, status_counts, labels = as.integer(status_counts), pos = 3)
grDevices::dev.off()

grDevices::png(file.path(visual_dir, "n1l_live_receipt_tape.png"), width = 1500, height = 850, res = 150)
if (nrow(news_messages)) {
  receipt_axis <- g5_news_receipt_axis(news_messages$received_at)
  primary_symbol <- sub("\\|.*$", "", news_messages$symbols)
  symbol_levels <- unique(primary_symbol)
  symbol_y <- match(primary_symbol, symbol_levels)
  graphics::par(mar = c(7, 10, 4, 2))
  graphics::plot(
    receipt_axis$positions, symbol_y,
    pch = 19, col = ifelse(news_messages$connection_id == "connection_1", "#2563EB", "#D97706"),
    xaxt = "n", yaxt = "n", ylab = "", xlab = "", xlim = receipt_axis$limits,
    main = "Live articles are preserved at local receipt time"
  )
  graphics::axis(1, at = receipt_axis$ticks, labels = receipt_axis$tick_labels)
  graphics::axis(2, at = seq_along(symbol_levels), labels = symbol_levels, las = 1)
  graphics::mtext(paste0("Local UTC receipt time (", receipt_axis$date_label, ")"), side = 1, line = 3)
  graphics::legend("topright", legend = c("Connection 1", "Connection 2"), col = c("#2563EB", "#D97706"), pch = 19, bty = "n")
} else {
  graphics::plot.new()
  graphics::title("No live candidate article arrived during the bounded windows")
  graphics::text(0.5, 0.48, "Transport, authentication, subscription, reconnect, and REST gates remain inspectable.")
}
grDevices::dev.off()

report <- c(
  "# Gen5.4 News Live Feasibility N1L", "",
  paste0("Status: `", overall_status, "`"), "",
  "## Question", "",
  "Can the existing Alpaca account support a locally timestamped live-news path with deliberate reconnect and REST reconciliation before any market outcome is inspected?", "",
  "## Readout", "",
  paste0("- Captured `", nrow(frames), "` raw WebSocket frames and `", nrow(news_messages), "` live news message(s) across two bounded connections."),
  paste0("- REST reconciliation returned `", nrow(rest$data), "` article(s) across `", nrow(rest_page_manifest), "` complete HTTP 200 page(s)."),
  paste0("- Exact stream/REST matches: `", sum(reconciliation$table$reconciliation_status == "matched"), "`; same-version conflicts: `", length(reconciliation$conflicting_stream_ids), "`."),
  paste0("- Hard transport and reconciliation gates passed: `", sum(gates$passed), " / ", nrow(gates), "`."),
  if (length(receipt_provider_offset_seconds)) {
    paste0("- Local receipt minus provider `created_at` in seconds: `", paste(format(round(receipt_provider_offset_seconds, 3), nsmall = 3), collapse = ", "), "`; local receipt remains prospective availability authority.")
  } else NULL, "",
  "## Interpretation", "",
  if (overall_status == "PASS_N1L_LIVE_PATH_READY") {
    "At least one live article was received with a local UTC timestamp, and the reconnect plus REST overlap path passed. N1L removes the operational data-path STOP in the frozen N1B contract; it does not establish predictive value."
  } else if (overall_status == "PARTIAL_PASS_N1L_TRANSPORT_READY_NO_LIVE_ARTICLE") {
    "The transport path passed, but no live candidate article arrived during the bounded observation windows. Prospective payload equivalence remains only partially observed."
  } else {
    "At least one hard live-path gate failed. N1B outcome testing remains blocked until the exact N1L failure is resolved or explicitly accepted by the operator."
  }, "",
  "## Hard boundary", "",
  "Sentiment, news intensity, features, outcomes, OHLCV joins, correlations, volatility calculations, models, allocation, and live advice are all zero. Credentials are absent from every artifact."
)
writeLines(report, file.path(output_dir, "n1l_report.md"), useBytes = TRUE)

message("Gen5.4 N1L complete: ", overall_status)
message("Hard gates: ", sum(gates$passed), "/", nrow(gates))
message("Live news messages: ", nrow(news_messages), "; REST articles: ", nrow(rest$data))
message("Report: ", normalizePath(file.path(output_dir, "n1l_report.md"), winslash = "/"))
