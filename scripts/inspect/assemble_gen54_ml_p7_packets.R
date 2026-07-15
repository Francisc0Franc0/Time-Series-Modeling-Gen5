script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE) else normalizePath(".", winslash = "/", mustWork = TRUE)
root <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine")
dirs <- list.dirs(root, recursive = FALSE, full.names = TRUE)
dirs <- dirs[grepl("g54_ml_p7_swing_20(20|21|22|23|24)_.*__(existing_relative_control|compact_swing)_20[2-9][0-9]Q[1-4]$", dirs)]
if (!length(dirs)) stop("No ML-P7 fold packets found.")
out <- file.path(root, "g54_ml_p7_swing_2020_2024_merged")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
files <- c("summary", "policy_thresholds", "ranking", "calibration", "importance", "oos_predictions", "actions", "trade_ledger", "portfolio_equity")
for (name in files) {
  paths <- file.path(dirs, paste0("ml_p7_", name, ".csv"))
  paths <- paths[file.exists(paths)]
  if (!length(paths)) next
  parts <- lapply(paths, function(path) utils::read.csv(path, stringsAsFactors = FALSE))
  columns <- unique(unlist(lapply(parts, names), use.names = FALSE))
  parts <- lapply(parts, function(x) { missing <- setdiff(columns, names(x)); for (col in missing) x[[col]] <- NA; x[, columns, drop = FALSE] })
  x <- do.call(rbind, parts)
  utils::write.csv(x, file.path(out, paste0("ml_p7_", name, ".csv")), row.names = FALSE)
}
utils::write.csv(data.frame(packet_dir = normalizePath(dirs, winslash = "/")), file.path(out, "ml_p7_child_packet_index.csv"), row.names = FALSE)
message("Merged ML-P7 packets: ", normalizePath(out, winslash = "/"))
