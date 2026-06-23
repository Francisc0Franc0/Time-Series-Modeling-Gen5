# Shared operator-script library setup.

g5_use_repo_local_libs <- function(repo_root) {
  if (!is.character(repo_root) || length(repo_root) != 1L || !nzchar(repo_root)) {
    stop("repo_root must be a single non-empty path.", call. = FALSE)
  }

  local_lib <- file.path(repo_root, ".codex_r_libs")
  if (!dir.exists(local_lib)) {
    return(invisible(NULL))
  }

  local_lib <- normalizePath(local_lib, winslash = "/", mustWork = TRUE)
  current_libs <- normalizePath(.libPaths(), winslash = "/", mustWork = FALSE)
  .libPaths(c(local_lib, current_libs[current_libs != local_lib]))
  invisible(local_lib)
}
