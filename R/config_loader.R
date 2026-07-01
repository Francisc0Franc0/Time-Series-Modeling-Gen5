# Gen5 data-layer configuration loading.

`%g5||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

g5_repo_root_from_script <- function(script_file, levels_up = 1L) {
  if (!is.null(script_file) && nzchar(script_file)) {
    root <- dirname(normalizePath(script_file, winslash = "/", mustWork = FALSE))
    for (i in seq_len(levels_up)) {
      root <- dirname(root)
    }
    return(normalizePath(root, winslash = "/", mustWork = FALSE))
  }
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

g5_strip_yaml_comment <- function(line) {
  sub("\\s+#.*$", "", line)
}

g5_parse_yaml_scalar <- function(value) {
  value <- trimws(value)
  if (!nzchar(value) || identical(value, "null") || identical(value, "NULL")) {
    return(NULL)
  }
  if (grepl('^".*"$', value) || grepl("^'.*'$", value)) {
    return(substr(value, 2L, nchar(value) - 1L))
  }
  lower <- tolower(value)
  if (lower %in% c("true", "false")) {
    return(identical(lower, "true"))
  }
  value
}

g5_parse_simple_yaml <- function(path) {
  if (!file.exists(path)) {
    g5_stop(paste("Config file does not exist:", path))
  }

  raw_lines <- readLines(path, warn = FALSE)
  cfg <- list()
  current_key <- NULL

  for (raw in raw_lines) {
    line <- g5_strip_yaml_comment(raw)
    if (!nzchar(trimws(line))) {
      next
    }

    indent <- nchar(line) - nchar(sub("^ *", "", line))
    text <- trimws(line)

    if (indent == 0L) {
      parts <- strsplit(text, ":", fixed = TRUE)[[1L]]
      key <- trimws(parts[1L])
      value <- trimws(paste(parts[-1L], collapse = ":"))
      if (!nzchar(key)) {
        g5_stop(paste("Invalid config key in:", path))
      }
      if (!nzchar(value)) {
        cfg[[key]] <- list()
        current_key <- key
      } else {
        cfg[[key]] <- g5_parse_yaml_scalar(value)
        current_key <- NULL
      }
      next
    }

    if (is.null(current_key)) {
      g5_stop(paste("Nested config value without a parent in:", path))
    }

    if (grepl("^-\\s+", text)) {
      item <- g5_parse_yaml_scalar(sub("^-\\s+", "", text))
      existing <- cfg[[current_key]]
      if (length(existing) == 0L) {
        existing <- character()
      } else {
        existing <- as.character(existing)
      }
      cfg[[current_key]] <- c(existing, as.character(item))
      next
    }

    parts <- strsplit(text, ":", fixed = TRUE)[[1L]]
    key <- trimws(parts[1L])
    value <- trimws(paste(parts[-1L], collapse = ":"))
    if (!nzchar(key)) {
      g5_stop(paste("Invalid nested config key in:", path))
    }
    if (!is.list(cfg[[current_key]])) {
      cfg[[current_key]] <- list()
    }
    cfg[[current_key]][[key]] <- g5_parse_yaml_scalar(value)
  }

  cfg
}

g5_recursive_merge <- function(base, override) {
  out <- base
  for (nm in names(override)) {
    if (is.list(out[[nm]]) && is.list(override[[nm]]) && is.null(names(override[[nm]])) == FALSE) {
      out[[nm]] <- g5_recursive_merge(out[[nm]], override[[nm]])
    } else {
      out[[nm]] <- override[[nm]]
    }
  }
  out
}

g5_env_value <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

g5_env_symbols <- function(value, default) {
  if (!nzchar(value)) {
    return(default)
  }
  g5_standardize_symbol(strsplit(value, ",", fixed = TRUE)[[1L]])
}

g5_resolve_repo_path <- function(path, repo_root) {
  path <- as.character(path[[1L]])
  if (!nzchar(path)) {
    g5_stop("path must be non-empty.")
  }
  is_windows_absolute <- grepl("^[A-Za-z]:[/\\\\]", path)
  is_unc <- grepl("^[/\\\\]{2}", path)
  is_unix_absolute <- grepl("^/", path)
  if (is_windows_absolute || is_unc || is_unix_absolute) {
    return(normalizePath(path, winslash = "/", mustWork = FALSE))
  }
  normalizePath(file.path(repo_root, path), winslash = "/", mustWork = FALSE)
}

g5_load_local_renviron <- function(
  repo_root = normalizePath(".", winslash = "/", mustWork = TRUE),
  path = file.path(repo_root, ".Renviron")
) {
  if (!file.exists(path)) {
    return(invisible(FALSE))
  }

  # Support both standard .Renviron KEY=value entries and the Gen4 convention
  # where the file is sourced to create ALPACA_KEY / ALPACA_SECRET objects.
  suppressWarnings(try(readRenviron(path), silent = TRUE))
  suppressWarnings(try(sys.source(path, envir = globalenv(), keep.source = FALSE), silent = TRUE))
  invisible(TRUE)
}

g5_validate_data_layer_config <- function(cfg) {
  if (!is.list(cfg)) {
    g5_stop("Data-layer config must be a list.")
  }
  if (!identical(as.character(cfg$provider %g5||% ""), "alpaca")) {
    g5_stop("Gen5 v0 config provider must be alpaca.")
  }
  if (!identical(as.character(cfg$timeframe %g5||% ""), "1D")) {
    g5_stop("Gen5 v0 config timeframe must be 1D.")
  }
  if (!isTRUE(cfg$adjusted)) {
    g5_stop("Gen5 v0 config adjusted must be true.")
  }
  if (!is.list(cfg$cache) || !nzchar(as.character(cfg$cache$root %g5||% ""))) {
    g5_stop("Data-layer config cache.root is required.")
  }
  if (!identical(as.character(cfg$cache$format %g5||% "rds"), "rds")) {
    g5_stop("Only rds cache format is implemented.")
  }
  if (!is.list(cfg$calendar)) {
    g5_stop("Data-layer config calendar section is required.")
  }
  if (!nzchar(as.character(cfg$calendar$timezone %g5||% ""))) {
    g5_stop("Data-layer config calendar.timezone is required.")
  }
  if (!nzchar(as.character(cfg$calendar$market_close_time %g5||% ""))) {
    g5_stop("Data-layer config calendar.market_close_time is required.")
  }
  cfg$symbols <- g5_standardize_symbol(cfg$symbols)
  if (length(cfg$symbols) == 0L) {
    g5_stop("Data-layer config must include at least one symbol.")
  }
  cfg
}

g5_load_data_layer_config <- function(
  repo_root = normalizePath(".", winslash = "/", mustWork = TRUE),
  example_path = file.path(repo_root, "config", "data_layer.example.yml"),
  local_path = file.path(repo_root, "config", "data_layer.local.yml")
) {
  cfg <- g5_parse_simple_yaml(example_path)
  source_files <- normalizePath(example_path, winslash = "/", mustWork = FALSE)

  if (file.exists(local_path)) {
    cfg <- g5_recursive_merge(cfg, g5_parse_simple_yaml(local_path))
    source_files <- c(source_files, normalizePath(local_path, winslash = "/", mustWork = FALSE))
  }

  cfg$cache$root <- g5_env_value("GEN5_CACHE_ROOT", cfg$cache$root)
  cfg$cache$root <- g5_resolve_repo_path(cfg$cache$root, repo_root)
  cfg$calendar$timezone <- g5_env_value("GEN5_MARKET_TIMEZONE", cfg$calendar$timezone)
  cfg$calendar$market_close_time <- g5_env_value("GEN5_MARKET_CLOSE_TIME", cfg$calendar$market_close_time)
  cfg$feed <- g5_env_value("ALPACA_DATA_FEED", cfg$feed %g5||% "sip")
  cfg$symbols <- g5_env_symbols(Sys.getenv("GEN5_SYMBOLS", unset = ""), cfg$symbols)
  cfg$config_source_files <- source_files

  g5_validate_data_layer_config(cfg)
}
