test_that("generated data-layer artifacts are ignored by git", {
  repo_root <- normalizePath(test_path("..", ".."), winslash = "/", mustWork = TRUE)
  gitignore_path <- file.path(repo_root, ".gitignore")
  skip_if_not(file.exists(gitignore_path), ".gitignore is not available")

  gitignore_lines <- readLines(gitignore_path, warn = FALSE)

  expect_true("runs/" %in% gitignore_lines)
  expect_true("*.rds" %in% gitignore_lines)
})
