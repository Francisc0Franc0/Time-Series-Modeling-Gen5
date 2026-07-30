# Frozen recent-wide replication batch for the LIT-MR-06.1 causal rule.

g5_mr06_recent_repo_root <- function(start = getwd()) {
  current <- normalizePath(start, winslash = "/", mustWork = TRUE)
  for (i in 0:8) {
    marker <- file.path(
      current, "literature_studies", "registries",
      "gen5_lit_mr_06_1_recent_wide_atlas_02_registry.csv"
    )
    if (file.exists(marker)) return(current)
    parent <- dirname(current)
    if (identical(parent, current)) break
    current <- parent
  }
  g5_mr06_stop("Could not resolve repository root for recent-wide registry.")
}

g5_mr06_recent_wide_registry <- function(
  repo_root = g5_mr06_recent_repo_root()
) {
  path <- file.path(
    repo_root, "literature_studies", "registries",
    "gen5_lit_mr_06_1_recent_wide_atlas_02_registry.csv"
  )
  if (!file.exists(path)) {
    g5_mr06_stop(paste("Recent-wide registry is missing:", path))
  }
  registry <- utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE
  )
  required <- c("order", "instance_id", "category", "benchmark", "symbols")
  if (!identical(names(registry), required) || nrow(registry) != 12L) {
    g5_mr06_stop("Recent-wide registry schema or row count changed.")
  }
  registry$order <- as.integer(registry$order)
  if (!identical(registry$order, 620:631) ||
      anyDuplicated(registry$instance_id)) {
    g5_mr06_stop("Recent-wide registry order or identities changed.")
  }
  parts <- strsplit(registry$symbols, ",", fixed = TRUE)
  if (any(vapply(parts, anyDuplicated, integer(1L)) > 0L)) {
    g5_mr06_stop("Recent-wide registry contains a duplicate panel symbol.")
  }
  if (!identical(sort(parts[[1L]]), sort(unique(unlist(parts[-1L])))) ||
      length(parts[[1L]]) != 305L) {
    g5_mr06_stop("Wide panel is not the frozen 305-symbol sector union.")
  }
  registry
}

g5_mr06_recent_wide_contract <- function(
  repo_root = g5_mr06_recent_repo_root()
) {
  list(
    schema_version = g5_mr06_schema_version(),
    literature_id = "LIT-MR-06.1",
    atlas_id = "RECENT_WIDE_ATLAS_02",
    as_of_timestamp = "2026-07-30 03:55:00 America/New_York",
    query_start = as.Date("2022-08-01"),
    train_start = as.Date("2023-01-03"),
    train_end = as.Date("2024-12-31"),
    development_start = as.Date("2025-01-02"),
    development_end = as.Date("2026-06-30"),
    confirmation_start = as.Date("2026-07-01"),
    volatility_sessions = 90L,
    moving_average_sessions = 20L,
    gap_sigma_multiple = 1,
    top_n = 10L,
    signal_time_et = "09:31:00",
    entry_time_et = "09:32:00",
    primary_round_trip_cost_bps = 10,
    stress_round_trip_cost_bps = 20,
    minimum_entry_coverage = 0.95,
    minimum_stock_events = 60L,
    minimum_portfolio_days = 30L,
    maximum_positive_pnl_concentration = 0.50,
    bootstrap_count = 2000L,
    bootstrap_block_days = 5L,
    bootstrap_seed = 61101L,
    random_control_count = 500L,
    random_control_seed = 61102L,
    registry = g5_mr06_recent_wide_registry(repo_root)
  )
}
