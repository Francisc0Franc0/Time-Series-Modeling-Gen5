# Gen5 opt-in Alpaca credential readiness preflight.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))

g5_load_local_renviron(repo_root)

parse_bool_env <- function(value, default = TRUE) {
  if (!nzchar(value)) {
    return(isTRUE(default))
  }
  tolower(trimws(value)) %in% c("1", "true", "yes", "y")
}

require_runtime <- parse_bool_env(
  Sys.getenv("GEN5_ALPACA_PREFLIGHT_REQUIRE_RUNTIME", unset = ""),
  default = TRUE
)

cfg <- g5_alpaca_config_from_env()
result <- g5_alpaca_credential_preflight(
  config = cfg,
  require_runtime = require_runtime
)

message("Gen5 Alpaca credential preflight")
message("Repository: ", repo_root)
message("Runtime package check: ", require_runtime)
message("Network probe: false")
message("Secrets: not printed")
print(result$checks, row.names = FALSE)

if (!isTRUE(result$ok)) {
  g5_stop("Alpaca credential preflight failed. See non-secret check details above.")
}

message("Alpaca credential preflight passed without making a network request.")
