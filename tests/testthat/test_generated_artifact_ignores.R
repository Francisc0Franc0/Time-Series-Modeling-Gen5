test_that("generated data-layer artifacts are ignored by git", {
  repo_root <- normalizePath(test_path("..", ".."), winslash = "/", mustWork = TRUE)
  gitignore_path <- file.path(repo_root, ".gitignore")
  skip_if_not(file.exists(gitignore_path), ".gitignore is not available")

  gitignore_lines <- readLines(gitignore_path, warn = FALSE)

  required_ignores <- c(
    ".codex_r_libs/",
    "data_cache/",
    "runs/",
    "artifacts/",
    "logs/",
    "*.parquet",
    "*.duckdb",
    "*.rds",
    ".Renviron",
    ".env",
    "config/*.local.yml"
  )

  expect_setequal(intersect(required_ignores, gitignore_lines), required_ignores)
})
