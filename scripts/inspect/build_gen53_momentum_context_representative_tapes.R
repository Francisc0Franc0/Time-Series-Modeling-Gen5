# Render representative trade tapes for the Gen5.3 momentum context-size packet
# from saved replay/execution/trade artifacts. This avoids refitting authority
# when only the audit image needs to be rebuilt.

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
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))
source(file.path(repo_root, "R", "live_advice_bridge.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

packet_dir <- env_or(
  "GEN5_GEN53_MOM_CTX_PACKET_DIR",
  file.path(repo_root, "runs", "research_workbench", "gen53_momentum_context_size", "g53_momctx_20260710ctxsize")
)

screen_id <- env_or("GEN5_GEN53_MOM_CTX_TAPE_SCREEN", "hb_risk_aware_18__workhorse_enriched")
window_id <- env_or("GEN5_GEN53_MOM_CTX_TAPE_WINDOW", "2024Y_asof_20241231")
lane_id <- env_or("GEN5_GEN53_MOM_CTX_TAPE_LANE", "pooled_family_asset_variant__state_switch_continuation")
symbols <- trimws(unlist(strsplit(env_or("GEN5_GEN53_MOM_CTX_TAPE_SYMBOLS", "AMD,NVDA,TSLA,MSTR"), ",", fixed = TRUE), use.names = FALSE))
symbols <- symbols[nzchar(symbols)]

paths <- list(
  replay = file.path(packet_dir, "momentum_context_size_replay_oos.csv"),
  executions = file.path(packet_dir, "momentum_context_size_executions.csv"),
  trades = file.path(packet_dir, "momentum_context_size_trades.csv"),
  pending = file.path(packet_dir, "momentum_context_size_pending_actions.csv"),
  output = file.path(packet_dir, "momentum_context_size_representative_trade_tapes.png")
)

for (p in paths[c("replay", "executions", "trades", "pending")]) {
  if (!file.exists(p)) g5_stop(paste0("Missing required packet artifact: ", normalizePath(p, winslash = "/", mustWork = FALSE)))
}

read_artifact <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

replay_all <- read_artifact(paths$replay)
exec_all <- read_artifact(paths$executions)
trades_all <- read_artifact(paths$trades)
pending_all <- read_artifact(paths$pending)

keep_lane <- function(df, symbol = NULL) {
  if (!is.data.frame(df) || !nrow(df)) return(df)
  keep <- df$screen_id == screen_id &
    df$window_id == window_id &
    df$lane_id == lane_id
  if (!is.null(symbol) && "symbol" %in% names(df)) keep <- keep & df$symbol == symbol
  df[keep, , drop = FALSE]
}

symbols <- symbols[symbols %in% unique(replay_all$symbol)]
if (!length(symbols)) g5_stop("No requested symbols are present in the saved replay artifact.")

grDevices::png(paths$output, width = 2600L, height = 1900L, res = 190L)
oldpar <- graphics::par(no.readonly = TRUE)
on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)

graphics::par(mfrow = c(2, 2), mar = c(4, 4, 3, 1), oma = c(0, 0, 2.2, 0))
for (symbol in symbols[seq_len(min(4L, length(symbols)))]) {
  replay <- keep_lane(replay_all, symbol)
  executions <- keep_lane(exec_all, symbol)
  trades <- keep_lane(trades_all, symbol)
  pending <- keep_lane(pending_all, symbol)
  g5_bridge_plot_panel(
    replay,
    executions,
    pending,
    trades,
    main = paste0(symbol, " / risk-aware workhorse / 2024Y continuation")
  )
}

graphics::mtext(
  "Representative Timing Tapes: Risk-Aware Workhorse 2024Y Continuation",
  side = 3,
  outer = TRUE,
  line = 0.6,
  font = 2
)

message("Wrote ", normalizePath(paths$output, winslash = "/", mustWork = FALSE))
