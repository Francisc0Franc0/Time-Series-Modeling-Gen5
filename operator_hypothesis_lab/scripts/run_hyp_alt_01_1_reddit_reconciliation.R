options(stringsAsFactors = FALSE)

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Expected exactly one --file argument.", call. = FALSE)
script_path <- normalizePath(sub("^--file=", "", script_arg), winslash = "/", mustWork = TRUE)
repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_alt_01_1_reddit_attention.R"))
g5_load_local_renviron(repo_root)

result <- ha011_reconcile_once(ha011_config_from_env(repo_root))
cat("Reconciliation status:", result$status, "\n")
cat("Comments checked:", result$checked, "\n")
cat("Removed contributions purged:", result$purged, "\n")
