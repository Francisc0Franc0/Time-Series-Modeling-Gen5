# Build a focused Gen5.3 bullish-participation trade-tape audit from an existing
# momentum context-size packet. This is artifact-only; it does not refit
# authority, rescore states, or replay trades.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "workbench_chart.R"))
source(file.path(repo_root, "R", "strategy_ema_cross.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))
source(file.path(repo_root, "R", "regime_pca_poc.R"))
source(file.path(repo_root, "R", "live_advice_bridge.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

safe_read_csv <- function(path) {
  if (!file.exists(path) || file.info(path)$size == 0L) return(data.frame())
  utils::read.csv(path, stringsAsFactors = FALSE)
}

packet_dir <- env_or(
  "GEN5_GEN53_MOM_CTX_PACKET_DIR",
  file.path(repo_root, "runs", "research_workbench", "gen53_momentum_context_size", "g53_momctx_20260711continuity")
)
packet_dir <- normalizePath(packet_dir, winslash = "/", mustWork = FALSE)

output_path <- env_or(
  "GEN5_GEN53_MOM_CTX_BULL_PARTICIPATION_TAPES",
  file.path(packet_dir, "momentum_context_size_bullish_participation_audit_tapes.png")
)

screen_id <- env_or("GEN5_GEN53_MOM_CTX_BULL_AUDIT_SCREEN", "hb_risk_aware_18__workhorse_enriched")
window_id <- env_or("GEN5_GEN53_MOM_CTX_BULL_AUDIT_WINDOW", "2020Y_asof_20201231")
lane_id <- env_or("GEN5_GEN53_MOM_CTX_BULL_AUDIT_LANE", "pooled_family_asset_variant__state_switch_continuation")
symbols <- strsplit(env_or("GEN5_GEN53_MOM_CTX_BULL_AUDIT_SYMBOLS", "TSLA,AMD,NVDA,MSTR"), ",", fixed = TRUE)[[1L]]
symbols <- g5_standardize_symbol(trimws(symbols[nzchar(trimws(symbols))]))

replay <- safe_read_csv(file.path(packet_dir, "momentum_context_size_replay_oos.csv"))
executions <- safe_read_csv(file.path(packet_dir, "momentum_context_size_executions.csv"))
trades <- safe_read_csv(file.path(packet_dir, "momentum_context_size_trades.csv"))
pending <- safe_read_csv(file.path(packet_dir, "momentum_context_size_pending_actions.csv"))

if (!nrow(replay)) g5_stop(paste0("No replay rows found in packet: ", packet_dir))

filter_rows <- function(x, symbol) {
  if (!is.data.frame(x) || !nrow(x)) return(data.frame())
  keep <- x$symbol == symbol & x$screen_id == screen_id & x$window_id == window_id & x$lane_id == lane_id
  x[keep, , drop = FALSE]
}

symbols <- symbols[vapply(symbols, function(symbol) nrow(filter_rows(replay, symbol)) > 0L, logical(1L))]
if (!length(symbols)) {
  g5_stop("No requested symbols have replay rows for the configured bullish-participation audit lane.")
}

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
grDevices::png(output_path, width = 3000L, height = 2200L, res = 220L)
oldpar <- graphics::par(no.readonly = TRUE)
on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)

graphics::par(mfrow = c(2, 2), mar = c(4.2, 4.2, 3.6, 1), oma = c(0, 0, 2.4, 0))
for (symbol in symbols[seq_len(min(4L, length(symbols)))]) {
  g5_bridge_plot_panel(
    filter_rows(replay, symbol),
    filter_rows(executions, symbol),
    filter_rows(pending, symbol),
    filter_rows(trades, symbol),
    main = paste0(symbol, " / 2020 risk-aware workhorse continuation"),
    ema_overlay = TRUE
  )
}

if (length(symbols) < 4L) {
  for (i in seq_len(4L - length(symbols))) {
    graphics::plot.new()
    graphics::text(0.5, 0.5, "No configured symbol rows")
  }
}

graphics::mtext(
  "Bullish Participation Audit: 2020 Risk-Aware Workhorse Continuation",
  side = 3,
  outer = TRUE,
  line = 0.7,
  font = 2
)

message("Wrote bullish participation audit tapes: ", normalizePath(output_path, winslash = "/", mustWork = FALSE))
