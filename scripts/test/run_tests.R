# Gen5 local test runner.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

setwd(repo_root)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)

message("Gen5 test runner")
message("Repository: ", repo_root)
message("R: ", R.version.string)
message("Library paths:")
for (path in .libPaths()) {
  message("  - ", path)
}

run_step <- function(label, expr) {
  message("")
  message("== ", label, " ==")
  force(expr)
  message("OK: ", label)
}

run_step("scaffold smoke test", {
  source(file.path(repo_root, "tests", "smoke_test.R"))
})

run_step("data-layer validation", {
  source(file.path(repo_root, "scripts", "validate", "validate_data_layer.R"))
})

run_step("testthat non-network tests", {
  if (!requireNamespace("testthat", quietly = TRUE)) {
    stop(
      paste(
        "testthat is not installed.",
        "Install it into .codex_r_libs or another active R library before running tests."
      ),
      call. = FALSE
    )
  }
  testthat::test_dir(file.path(repo_root, "tests", "testthat"))
})

run_step("literature-study non-network tests", {
  testthat::test_dir(
    file.path(repo_root, "literature_studies", "tests", "testthat")
  )
})

run_step("operator-hypothesis-lab non-network tests", {
  testthat::test_dir(
    file.path(repo_root, "operator_hypothesis_lab", "tests", "testthat")
  )
})

message("")
message("Gen5 local tests passed.")
