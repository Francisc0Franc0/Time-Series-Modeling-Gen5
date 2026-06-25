# Backward-compatible wrapper for the renamed multi-signal WFA POC runner.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
script_dir <- if (!is.null(script_path) && nzchar(script_path)) dirname(script_path) else file.path(".", "scripts", "inspect")
source(file.path(script_dir, "run_multi_signal_wfa_poc.R"))
