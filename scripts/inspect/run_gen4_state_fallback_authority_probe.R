# Authority-level probe for the Gen4 pooled-state fallback mechanic.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))
source(file.path(repo_root, "R", "regime_pca_wfa_poc.R"))
source(file.path(repo_root, "R", "selection_policy_screen.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

parse_csv_env <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (!nzchar(value)) return(default)
  out <- trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
  out[nzchar(out)]
}

read_csv_required <- function(path) {
  if (!file.exists(path)) g5_stop(paste0("Missing required probe input: ", path))
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

first_present <- function(x, default = NA_character_) {
  if (!length(x)) default else as.character(x[[1L]])
}

normalize_state_id <- function(x) {
  x <- as.character(x)
  ifelse(nzchar(x) & !grepl("^S", x), paste0("S", x), x)
}

lane_label <- function(x) {
  x <- as.character(x)
  x[x == "pooled_family_asset_variant"] <- "Pooled Strict"
  x[x == "pooled_family_asset_variant_state_fallback"] <- "Pooled Fallback"
  x
}

stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_FALLBACK_PROBE_STAMP", "20260708"))
calibration_dir <- normalizePath(env_or(
  "GEN5_FALLBACK_PROBE_CALIBRATION_DIR",
  file.path(repo_root, "runs", "research_workbench", "gen4_equivalence", "gen4_equivalence_gen52calfull162024q420260707")
), winslash = "/", mustWork = TRUE)
gen4_root <- normalizePath(env_or(
  "GEN5_FALLBACK_PROBE_GEN4_ROOT",
  "C:/Users/Franc/OneDrive/Documents/Francis/Peltata Project/Time-Series-Modeling/Experiments/FM-002-024-R3_med_16_bins"
), winslash = "/", mustWork = TRUE)
quarter_id <- env_or("GEN5_FALLBACK_PROBE_QUARTER", "2024Q4")
gen4_fold_id <- env_or("GEN5_FALLBACK_PROBE_GEN4_FOLD_ID", "17")
focus_symbols <- parse_csv_env("GEN5_FALLBACK_PROBE_SYMBOLS", c("SOFI", "PLTR"))

out_dir <- file.path(repo_root, "runs", "research_workbench", "gen4_equivalence", paste0("gen4_state_fallback_authority_probe_", stamp))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

phase40_dir <- file.path(gen4_root, "Phase40_WFA_Quarterly_Validation")
train_perf <- read_csv_required(file.path(calibration_dir, "auth", quarter_id, "bridge_train_state_performance.csv"))
strict <- g5_selection_policy_pooled_family_asset_variant(train_perf, min_train_state_rows = 20L)
fallback <- g5_selection_policy_pooled_family_asset_variant_state_fallback(train_perf, min_train_state_rows = 20L)

strict_focus <- strict[as.character(strict$symbol) %in% focus_symbols, , drop = FALSE]
fallback_focus <- fallback[as.character(fallback$symbol) %in% focus_symbols, , drop = FALSE]

key <- function(x) paste(as.character(x$symbol), as.character(x$state_id), sep = "::")
strict_map <- strict_focus[match(key(fallback_focus), key(strict_focus)), , drop = FALSE]
authority_comparison <- data.frame(
  symbol = as.character(fallback_focus$symbol),
  state_id = as.character(fallback_focus$state_id),
  strict_family = as.character(strict_map$strategy_family),
  strict_spec_id = as.character(strict_map$strategy_spec_id),
  strict_reason = as.character(strict_map$selection_reason),
  fallback_family = as.character(fallback_focus$strategy_family),
  fallback_spec_id = as.character(fallback_focus$strategy_spec_id),
  fallback_reason = as.character(fallback_focus$selection_reason),
  fallback_used = as.logical(fallback_focus$fallback_used),
  fallback_source_symbol = as.character(fallback_focus$fallback_source_symbol),
  fallback_source_spec_id = as.character(fallback_focus$fallback_source_strategy_spec_id),
  pooled_selected_family = as.character(fallback_focus$pooled_selected_family),
  stringsAsFactors = FALSE
)
authority_comparison$changed_by_fallback <- authority_comparison$strict_spec_id != authority_comparison$fallback_spec_id |
  authority_comparison$strict_family != authority_comparison$fallback_family

gen4_family <- read_csv_required(file.path(phase40_dir, "state_family_winners.csv"))
gen4_family <- gen4_family[as.character(gen4_family$fold_id) == gen4_fold_id, , drop = FALSE]
gen4_family$state_id <- normalize_state_id(gen4_family$state_id)
gen4_asset <- read_csv_required(file.path(phase40_dir, "state_asset_variant_winners.csv"))
gen4_asset <- gen4_asset[as.character(gen4_asset$fold_id) == gen4_fold_id, , drop = FALSE]
gen4_asset$state_id <- normalize_state_id(gen4_asset$state_id)

gen4_asset_focus <- gen4_asset[as.character(gen4_asset$asset) %in% focus_symbols, , drop = FALSE]
gen4_state_leader <- do.call(rbind, lapply(split(gen4_asset, as.character(gen4_asset$state_id)), function(x) {
  x <- x[order(-suppressWarnings(as.numeric(x$variant_metric)), as.character(x$asset), as.character(x$strategy)), , drop = FALSE]
  x[1L, , drop = FALSE]
}))
if (!is.data.frame(gen4_state_leader)) gen4_state_leader <- gen4_asset[0L, , drop = FALSE]

state_rows <- unique(authority_comparison[, c("symbol", "state_id"), drop = FALSE])
gen4_exact_rows <- do.call(rbind, lapply(seq_len(nrow(state_rows)), function(i) {
  symbol <- as.character(state_rows$symbol[[i]])
  state_id <- as.character(state_rows$state_id[[i]])
  exact <- gen4_asset_focus[as.character(gen4_asset_focus$asset) == symbol & as.character(gen4_asset_focus$state_id) == state_id, , drop = FALSE]
  family <- gen4_family[as.character(gen4_family$state_id) == state_id, , drop = FALSE]
  leader <- gen4_state_leader[as.character(gen4_state_leader$state_id) == state_id, , drop = FALSE]
  data.frame(
    symbol = symbol,
    state_id = state_id,
    gen4_state_family = first_present(family$family, ""),
    gen4_exact_asset_family = first_present(exact$family, ""),
    gen4_exact_asset_strategy = first_present(exact$strategy, ""),
    gen4_exact_asset_present = nrow(exact) > 0L,
    gen4_state_leader_asset = first_present(leader$asset, ""),
    gen4_state_leader_family = first_present(leader$family, ""),
    gen4_state_leader_strategy = first_present(leader$strategy, ""),
    stringsAsFactors = FALSE
  )
}))

authority_comparison <- merge(authority_comparison, gen4_exact_rows, by = c("symbol", "state_id"), all.x = TRUE, sort = FALSE)

replay_path <- file.path(calibration_dir, "gen4_equivalence_replay_oos.csv")
if (file.exists(replay_path)) {
  replay <- read_csv_required(replay_path)
  replay_focus <- replay[as.character(replay$quarter_id) == quarter_id & as.character(replay$symbol) %in% focus_symbols, , drop = FALSE]
  replay_focus <- replay_focus[nzchar(as.character(replay_focus$symbol)) & nzchar(as.character(replay_focus$state_id)), , drop = FALSE]
  oos_states <- as.data.frame(table(
    symbol = as.character(replay_focus$symbol),
    state_id = as.character(replay_focus$state_id)
  ), stringsAsFactors = FALSE)
  names(oos_states)[names(oos_states) == "Freq"] <- "oos_days_in_existing_replay"
  oos_states <- oos_states[oos_states$oos_days_in_existing_replay > 0L, , drop = FALSE]
} else {
  oos_states <- data.frame(symbol = character(), state_id = character(), oos_days_in_existing_replay = integer(), stringsAsFactors = FALSE)
}

oos_authority <- merge(authority_comparison, oos_states, by = c("symbol", "state_id"), all.x = TRUE, sort = FALSE)
oos_authority$oos_days_in_existing_replay[is.na(oos_authority$oos_days_in_existing_replay)] <- 0L
fallback_events <- authority_comparison[authority_comparison$fallback_used | authority_comparison$changed_by_fallback, , drop = FALSE]

paths <- list(
  authority_comparison_csv = file.path(out_dir, "fallback_authority_comparison.csv"),
  fallback_events_csv = file.path(out_dir, "fallback_events.csv"),
  oos_authority_csv = file.path(out_dir, "fallback_oos_authority_context.csv"),
  heatmap_png = file.path(out_dir, "fallback_authority_heatmap.png"),
  report_md = file.path(out_dir, "fallback_authority_probe_report.md")
)

utils::write.csv(authority_comparison, paths$authority_comparison_csv, row.names = FALSE)
utils::write.csv(fallback_events, paths$fallback_events_csv, row.names = FALSE)
utils::write.csv(oos_authority, paths$oos_authority_csv, row.names = FALSE)

states <- sort(unique(as.character(oos_authority$state_id[oos_authority$oos_days_in_existing_replay > 0L])))
if (!length(states)) states <- sort(unique(as.character(authority_comparison$state_id)))
plot_rows <- authority_comparison[as.character(authority_comparison$state_id) %in% states, , drop = FALSE]
row_labels <- unique(paste(plot_rows$symbol, plot_rows$state_id, sep = " / "))
lanes <- c("Pooled Strict", "Pooled Fallback", "Gen4 exact", "Gen4 state leader")
family_palette <- c(
  no_trade = "#D0D5DD",
  no_trade_exit_immediate = "#B8BCC4",
  ema_cross = "#2E86AB",
  ema_trend = "#5DADE2",
  pullback_in_uptrend = "#1B9E77",
  bollinger_touch = "#F4A261",
  bb_touch = "#F4A261",
  rsi_mr = "#9B5DE5",
  zret_mr = "#FF6B35",
  volatility_breakout = "#E76F51",
  breakout = "#E76F51",
  other = "#8A8F99"
)
color_for <- function(family) {
  family <- as.character(family)
  out <- unname(family_palette[family])
  out[!nzchar(family)] <- "#FFFFFF"
  out[is.na(out)] <- family_palette[["other"]]
  out
}

grDevices::png(paths$heatmap_png, width = 2400L, height = max(1000L, 210L * length(row_labels) + 420L), res = 180L)
oldpar <- graphics::par(no.readonly = TRUE)
on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
graphics::par(bg = "#FAF7F0", mar = c(8, 12, 4, 2))
graphics::plot(NA, xlim = c(0.5, length(lanes) + 0.5), ylim = c(0.5, length(row_labels) + 0.5), xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = "Gen4 State-Leader Fallback Authority Probe", col.main = "#172033")
graphics::rect(0.5, 0.5, length(lanes) + 0.5, length(row_labels) + 0.5, col = "#FFFFFF", border = NA)
for (i in seq_len(nrow(plot_rows))) {
  row_label <- paste(plot_rows$symbol[[i]], plot_rows$state_id[[i]], sep = " / ")
  y <- match(row_label, row_labels)
  families <- c(
    plot_rows$strict_family[[i]],
    plot_rows$fallback_family[[i]],
    plot_rows$gen4_exact_asset_family[[i]],
    plot_rows$gen4_state_leader_family[[i]]
  )
  labels <- c(
    plot_rows$strict_spec_id[[i]],
    paste0(plot_rows$fallback_spec_id[[i]], if (isTRUE(plot_rows$fallback_used[[i]])) "\nFB" else ""),
    plot_rows$gen4_exact_asset_strategy[[i]],
    paste0(plot_rows$gen4_state_leader_asset[[i]], "\n", plot_rows$gen4_state_leader_strategy[[i]])
  )
  for (j in seq_along(lanes)) {
    graphics::rect(j - 0.48, y - 0.48, j + 0.48, y + 0.48, col = color_for(families[[j]]), border = "white")
    graphics::text(j, y, labels[[j]], cex = 0.52, col = "#111111")
  }
}
graphics::axis(1, at = seq_along(lanes), labels = lanes, las = 2, cex.axis = 0.8)
graphics::axis(2, at = seq_along(row_labels), labels = row_labels, las = 1, cex.axis = 0.85)
graphics::mtext("Rows are OOS-visited states when existing replay is available; otherwise all focus-symbol states.", side = 3, line = 0.2, cex = 0.82, col = "#5F6673")

fallback_count <- sum(authority_comparison$fallback_used, na.rm = TRUE)
changed_count <- sum(authority_comparison$changed_by_fallback, na.rm = TRUE)
oos_fallback_count <- sum(oos_authority$fallback_used & oos_authority$oos_days_in_existing_replay > 0L, na.rm = TRUE)

report <- c(
  "# Gen4 State-Leader Fallback Authority Probe",
  "",
  paste0("- Calibration directory: `", calibration_dir, "`"),
  paste0("- Gen4 artifact root: `", gen4_root, "`"),
  paste0("- Quarter: `", quarter_id, "`"),
  paste0("- Gen4 fold id: `", gen4_fold_id, "`"),
  paste0("- Focus symbols: `", paste(focus_symbols, collapse = ","), "`"),
  "",
  "## Purpose",
  "",
  "This probe isolates the Gen4 hierarchical fallback mechanic before paying for a full replay. It compares strict Gen5.2 pooled-family authority against a Gen4-style state-leader fallback lane. The fallback lane first tries the asset/state winner inside the pooled winning family; if that asset has no eligible local variant, it uses the best pooled state leader from another asset.",
  "",
  "## Readout",
  "",
  paste0("- Focus asset/state rows inspected: `", nrow(authority_comparison), "`."),
  paste0("- Rows where fallback was used: `", fallback_count, "`."),
  paste0("- Rows changed relative to strict pooled authority: `", changed_count, "`."),
  paste0("- OOS-visited rows where fallback was used, based on the existing replay packet: `", oos_fallback_count, "`."),
  "",
  "## Artifacts",
  "",
  paste0("- Authority comparison: `", paths$authority_comparison_csv, "`"),
  paste0("- Fallback events: `", paths$fallback_events_csv, "`"),
  paste0("- OOS authority context: `", paths$oos_authority_csv, "`"),
  paste0("- Heatmap: `", paths$heatmap_png, "`"),
  "",
  "## Interpretation Guardrail",
  "",
  "This is authority-level evidence only. It validates whether the missing Gen4 mechanic changes selected state authority; it does not by itself prove portfolio alpha or accepted live allocation behavior."
)
writeLines(report, paths$report_md)

message("Fallback authority probe complete: ", out_dir)
message("Report: ", paths$report_md)
