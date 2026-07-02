# Build artifact-only visual summaries for a completed Gen5.1 selection-policy paired screen.

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
source(file.path(repo_root, "R", "wfa_ema_cross_poc.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))
source(file.path(repo_root, "R", "selection_policy_screen.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

parse_args <- function(args) {
  out <- list()
  for (arg in args) {
    if (!grepl("^--[^=]+=", arg)) next
    key <- sub("^--", "", sub("=.*$", "", arg))
    value <- sub("^[^=]+=", "", arg)
    out[[gsub("-", "_", key)]] <- value
  }
  out
}

arg <- parse_args(commandArgs(trailingOnly = TRUE))
arg_or_env <- function(arg_name, env_name, default = "") {
  value <- arg[[arg_name]]
  if (!is.null(value) && nzchar(value)) value else env_or(env_name, default)
}

default_screen_dir <- file.path(
  repo_root,
  "runs", "research_workbench", "selection_policy_screens",
  "selection_policy_screen_A5_Q2Q3_20260702"
)
screen_dir <- normalizePath(arg_or_env("screen_dir", "GEN5_SELECTION_POLICY_SCREEN_DIR", default_screen_dir), winslash = "/", mustWork = FALSE)
output_dir <- normalizePath(arg_or_env("output_dir", "GEN5_SELECTION_POLICY_VISUAL_OUTPUT_DIR", file.path(screen_dir, "visual_summary")), winslash = "/", mustWork = FALSE)

message("Gen5.1 selection-policy visual summary")
message("Screen packet: ", screen_dir)
message("Output: ", output_dir)

written <- g5_selection_policy_write_visual_summary(screen_dir, output_dir = output_dir)

message("")
message("Visual summary written:")
print(as.data.frame(written$paths), row.names = FALSE)
message("")
message("Metric summary:")
print(written$metric_summary, row.names = FALSE)
message("")
message("Largest absolute return deltas:")
delta <- written$symbol_delta[order(abs(written$symbol_delta$return_delta_pooled_minus_direct), decreasing = TRUE), , drop = FALSE]
print(delta[seq_len(min(nrow(delta), 10L)), c("window_id", "symbol", "compound_trace_return_direct", "compound_trace_return_pooled", "return_delta_pooled_minus_direct", "position_match", "latest_family_match"), drop = FALSE], row.names = FALSE)
