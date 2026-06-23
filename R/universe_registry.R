# Manual universe registry helpers for Gen5 research plumbing.

g5_allowed_universe_roles <- function() {
  c("candidate_universe", "research_universe", "context_universe", "live_basket")
}

g5_load_universe_registry <- function(
  path = file.path("config", "universe_registry.csv")
) {
  if (!file.exists(path)) {
    g5_stop(paste("Universe registry file does not exist:", path))
  }
  registry <- utils::read.csv(path, stringsAsFactors = FALSE)
  g5_validate_universe_registry(registry)
}

g5_validate_universe_registry <- function(registry) {
  if (!is.data.frame(registry)) {
    g5_stop("universe registry must be a data.frame.")
  }
  required <- c("universe_name", "role", "symbol", "description")
  missing <- setdiff(required, names(registry))
  if (length(missing) > 0L) {
    g5_stop(paste("universe registry missing required columns:", paste(missing, collapse = ", ")))
  }
  if (nrow(registry) == 0L) {
    g5_stop("universe registry must include at least one row.")
  }

  registry$universe_name <- trimws(as.character(registry$universe_name))
  registry$role <- trimws(as.character(registry$role))
  registry$symbol <- g5_standardize_symbol(registry$symbol)
  registry$description <- trimws(as.character(registry$description))

  if (any(!nzchar(registry$universe_name))) {
    g5_stop("universe_name values must be non-empty.")
  }
  invalid_roles <- setdiff(unique(registry$role), g5_allowed_universe_roles())
  if (length(invalid_roles) > 0L) {
    g5_stop(paste("Invalid universe role(s):", paste(invalid_roles, collapse = ", ")))
  }
  bad_symbols <- registry$symbol[!grepl("^[A-Z0-9.\\-]+$", registry$symbol)]
  if (length(bad_symbols) > 0L) {
    g5_stop(paste("Invalid universe symbol(s):", paste(unique(bad_symbols), collapse = ", ")))
  }

  key <- paste(registry$universe_name, registry$role, registry$symbol, sep = "|")
  if (any(duplicated(key))) {
    g5_stop("Duplicate universe_name/role/symbol rows detected.")
  }

  registry <- registry[order(registry$universe_name, registry$role, registry$symbol), required, drop = FALSE]
  rownames(registry) <- NULL
  registry
}

g5_universe_symbols <- function(
  registry,
  universe_name = "gen5_v0_1_poc_growth",
  roles = "research_universe"
) {
  registry <- g5_validate_universe_registry(registry)
  universe_name <- trimws(as.character(universe_name[[1L]]))
  roles <- trimws(as.character(roles))
  invalid_roles <- setdiff(roles, g5_allowed_universe_roles())
  if (length(invalid_roles) > 0L) {
    g5_stop(paste("Invalid universe role filter(s):", paste(invalid_roles, collapse = ", ")))
  }
  if (!nzchar(universe_name)) {
    g5_stop("universe_name must be non-empty.")
  }

  selected <- registry[registry$universe_name == universe_name & registry$role %in% roles, , drop = FALSE]
  unique(g5_standardize_symbol(selected$symbol))
}
