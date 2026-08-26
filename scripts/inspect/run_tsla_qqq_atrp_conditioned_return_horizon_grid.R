# Run the frozen quasi-external-context variant of the TSLA ATR%-conditioned
# cumulative-return horizon grid. TSLA supplies returns; QQQ supplies only the
# accepted causal HYP-REG-01.1 ATR% state at each anchor close.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

Sys.setenv(GEN5_ATRP_STATE_SYMBOL = "QQQ")
source(file.path(repo_root, "scripts", "inspect", "run_tsla_atrp_conditioned_return_horizon_grid.R"))
