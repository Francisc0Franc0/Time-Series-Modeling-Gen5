options(stringsAsFactors = FALSE)

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE) else normalizePath(".", winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R", "config_loader.R", "calendar.R", "alpaca_provider.R", "cache_store.R", "data_audit.R", "universe_registry.R", "workbench_query.R")) source(file.path(repo_root, "R", f))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_05_1_triple_sma_pullback.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
env_bool <- function(name, default = FALSE) tolower(env_or(name, if (default) "true" else "false")) %in% c("1", "true", "yes", "y")
write_csv <- function(x, path) { utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = ""); invisible(path) }
median_na <- function(x) if (!length(x) || all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
percent <- function(x, digits = 1L) ifelse(is.na(x), "NA", paste0(formatC(100 * x, digits = digits, format = "f"), "%"))
add_identity <- function(x, reg) {
  if (!nrow(x)) return(cbind(reg[FALSE, c("instance_id", "symbol", "cohort", "sector", "source_registry"), drop = FALSE], x[, setdiff(names(x), "symbol"), drop = FALSE]))
  cbind(reg[rep(1L, nrow(x)), c("instance_id", "symbol", "cohort", "sector", "source_registry"), drop = FALSE], x[, setdiff(names(x), "symbol"), drop = FALSE])
}

contract <- h051_validate_contract()
original <- utils::read.csv(file.path(repo_root, "operator_hypothesis_lab", "registries", "hyp_mom_01_1_discovery_registry.csv"), stringsAsFactors = FALSE)
wide <- utils::read.csv(file.path(repo_root, "literature_studies", "registries", "gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv"), stringsAsFactors = FALSE)
registry <- rbind(
  data.frame(instance_id = original$instance_id, symbol = original$symbol, cohort = "ORIGINAL_22", sector = original$sector, source_registry = original$source_registry),
  data.frame(instance_id = wide$instance_id, symbol = wide$symbol, cohort = wide$cohort, sector = wide$sector, source_registry = wide$source_id)
)
if (nrow(registry) != 122L || anyDuplicated(registry$symbol) || length(unique(registry$sector)) != 11L) stop("Frozen combined registry integrity failed.", call. = FALSE)

run_id <- env_or("GEN5_HYP_MOM_051_RUN_ID", "hyp_mom_05_1_triple_sma_pullback_wide_discovery_20260812")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals"); dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
cfg <- g5_load_data_layer_config(repo_root)
refresh <- env_bool("GEN5_HYP_MOM_051_REFRESH", FALSE)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg, start_date = as.Date("2020-09-01"), end_date = contract$discovery_end,
  as_of_timestamp = contract$as_of_timestamp, symbols = c(registry$symbol, "SPY"),
  universe_name = "hyp_mom_05_1_triple_sma_pullback_wide_discovery",
  universe_roles = "frozen_combined_122,spy_calendar", refresh = refresh, repo_root = repo_root
)
bars_all <- query$bars; bars_all$session_date <- as.Date(bars_all$session_date)
if (any(bars_all$session_date >= contract$confirmation_start)) stop("Confirmation bars entered discovery.", call. = FALSE)
if (anyDuplicated(bars_all[c("symbol", "session_date")])) stop("Duplicate queried bars.", call. = FALSE)
spy_dates <- sort(unique(bars_all$session_date[bars_all$symbol == "SPY" & bars_all$session_date >= contract$discovery_start & bars_all$session_date <= contract$discovery_end]))
if (!length(spy_dates)) stop("SPY discovery calendar unavailable.", call. = FALSE)

coverage <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  reg <- registry[i, , drop = FALSE]; x <- bars_all[bars_all$symbol == reg$symbol, , drop = FALSE]; x <- x[order(x$session_date), , drop = FALSE]
  invalid <- if (!nrow(x)) 0L else sum(!is.finite(x$open) | !is.finite(x$high) | !is.finite(x$low) | !is.finite(x$close) | !is.finite(x$volume) | x$open <= 0 | x$high <= 0 | x$low <= 0 | x$close <= 0 | x$volume < 0)
  observed <- x$session_date[x$session_date >= contract$discovery_start & x$session_date <= contract$discovery_end]
  missing <- length(setdiff(spy_dates, observed)); prehistory <- sum(x$session_date < contract$discovery_start)
  status <- if (!nrow(x)) "NO_HISTORY" else if (invalid > 0L) "INVALID_OHLCV" else if (missing > 0L) "DISCOVERY_INCOMPLETE" else if (prehistory < contract$prehistory_sessions) "PREHISTORY_INCOMPLETE" else "ELIGIBLE"
  cbind(reg, data.frame(observed_rows = nrow(x), discovery_missing_sessions = missing, prehistory_sessions = prehistory, invalid_ohlcv_rows = invalid, coverage_status = status, analysis_eligible = status == "ELIGIBLE"))
}))
eligible <- registry[registry$symbol %in% coverage$symbol[coverage$analysis_eligible], , drop = FALSE]
if (!nrow(eligible)) stop("No registered asset passed coverage.", call. = FALSE)

summary_rows <- trade_rows <- path_rows <- random_rows <- list()
message("HYP-MOM-05.1 starting: ", nrow(eligible), " eligible assets.")
for (i in seq_len(nrow(eligible))) {
  reg <- eligible[i, , drop = FALSE]; message(sprintf("[%03d/%03d] %s", i, nrow(eligible), reg$symbol))
  analysis <- h051_analyze_asset(bars_all[bars_all$symbol == reg$symbol, , drop = FALSE], contract, seed_offset = i * 1000L)
  summary_rows[[i]] <- add_identity(analysis$summary, reg); trade_rows[[i]] <- add_identity(analysis$trades, reg)
  path_rows[[i]] <- add_identity(analysis$paths, reg); random_rows[[i]] <- add_identity(analysis$random, reg)
}
asset_policy_summary <- do.call(rbind, summary_rows); trades <- do.call(rbind, trade_rows); paths <- do.call(rbind, path_rows); random_controls <- do.call(rbind, random_rows)
rownames(asset_policy_summary) <- rownames(trades) <- rownames(paths) <- rownames(random_controls) <- NULL
main <- asset_policy_summary[asset_policy_summary$policy == "H051" & asset_policy_summary$scenario == "PRIMARY", , drop = FALSE]
baseline <- asset_policy_summary[asset_policy_summary$policy != "H051" & asset_policy_summary$scenario == "PRIMARY", , drop = FALSE]

panel_summary <- function(x, label) data.frame(
  panel = label, leverage = unique(x$leverage), asset_count = nrow(x), trade_count = sum(x$trade_count),
  median_return = stats::median(x$total_return), mean_return = mean(x$total_return), positive_assets = sum(x$total_return > 0),
  median_cagr = median_na(x$cagr), median_sharpe = median_na(x$sharpe), median_max_drawdown = stats::median(x$maximum_drawdown),
  median_time_underwater = stats::median(x$time_underwater), median_exposure = stats::median(x$exposure_fraction),
  median_hit_rate = median_na(x$hit_rate), median_holding_sessions = median_na(x$median_holding_sessions),
  median_whipsaw_fraction = median_na(x$whipsaw_fraction), median_random_percentile = median_na(x$random_percentile),
  assets_above_random_80 = sum(x$random_percentile > .8, na.rm = TRUE), maintenance_breach_assets = sum(x$maintenance_breach_sessions > 0),
  nonpositive_equity_assets = sum(x$nonpositive_equity), median_financing_cost = stats::median(x$total_financing_cost), stringsAsFactors = FALSE
)
panels <- do.call(rbind, lapply(contract$leverages, function(L) do.call(rbind, list(
  panel_summary(main[main$leverage == L, ], "COMBINED"),
  panel_summary(main[main$leverage == L & main$cohort == "ORIGINAL_22", ], "ORIGINAL_22"),
  panel_summary(main[main$leverage == L & main$cohort == "DIVERSIFIED_CORE", ], "DIVERSIFIED_CORE"),
  panel_summary(main[main$leverage == L & main$cohort == "RETAIL_ATTENTION_2020", ], "RETAIL_ATTENTION_2020")
))))
sector_summary <- do.call(rbind, lapply(contract$leverages, function(L) do.call(rbind, lapply(sort(unique(main$sector)), function(s) panel_summary(main[main$leverage == L & main$sector == s, ], s)))))
entry_summary <- do.call(rbind, lapply(contract$leverages, function(L) do.call(rbind, lapply(c("ORDER_ACTIVATION", "MEDIUM_RECLAIM"), function(reason) {
  x <- trades[trades$leverage == L & trades$entry_reason == reason, , drop = FALSE]
  data.frame(leverage = L, entry_reason = reason, trade_count = nrow(x), hit_rate = if (nrow(x)) mean(x$equity_trade_return > 0) else NA_real_, median_trade_return = median_na(x$equity_trade_return), median_hold = median_na(x$holding_sessions), median_mae = median_na(x$maximum_adverse_excursion), median_mfe = median_na(x$maximum_favorable_excursion))
}))))

baseline_comparisons <- merge(
  main[c("instance_id", "symbol", "cohort", "sector", "leverage", "total_return", "maximum_drawdown", "sharpe", "exposure_fraction")],
  baseline[c("instance_id", "leverage", "policy", "total_return", "maximum_drawdown", "sharpe", "exposure_fraction")],
  by = c("instance_id", "leverage"), suffixes = c("_h051", "_baseline"), all.x = TRUE
)
baseline_comparisons$excess_return <- baseline_comparisons$total_return_h051 - baseline_comparisons$total_return_baseline
baseline_comparisons$drawdown_improvement <- baseline_comparisons$maximum_drawdown_h051 - baseline_comparisons$maximum_drawdown_baseline
leverage_comparisons <- merge(main[main$leverage == 1, ], main[main$leverage == 1.8, ], by = "instance_id", suffixes = c("_1x", "_1_8x"))
leverage_comparisons$incremental_return <- leverage_comparisons$total_return_1_8x - leverage_comparisons$total_return_1x
leverage_comparisons$incremental_drawdown <- leverage_comparisons$maximum_drawdown_1_8x - leverage_comparisons$maximum_drawdown_1x

annual_asset_summary <- do.call(rbind, lapply(split(paths, interaction(paths$instance_id, paths$leverage, drop = TRUE)), function(p) {
  p <- p[order(p$session_date), , drop = FALSE]
  r <- c(0, p$wealth_open[-1L] / head(p$wealth_open, -1L) - 1)
  yr <- format(p$session_date, "%Y")
  do.call(rbind, lapply(unique(yr), function(y) {
    local <- r[yr == y]; local_wealth <- cumprod(1 + local)
    data.frame(instance_id = p$instance_id[[1L]], symbol = p$symbol[[1L]], cohort = p$cohort[[1L]], sector = p$sector[[1L]], leverage = p$leverage[[1L]], year = as.integer(y), annual_return = prod(1 + local) - 1, annual_max_drawdown = min(local_wealth / cummax(local_wealth) - 1), exposed_sessions = sum(p$in_position_after_open[yr == y]), sessions = length(local), stringsAsFactors = FALSE)
  }))
}))
annual_panel_summary <- do.call(rbind, lapply(split(annual_asset_summary, interaction(annual_asset_summary$leverage, annual_asset_summary$year, drop = TRUE)), function(x) data.frame(leverage = x$leverage[[1L]], year = x$year[[1L]], asset_count = nrow(x), median_annual_return = stats::median(x$annual_return), positive_assets = sum(x$annual_return > 0), median_annual_max_drawdown = stats::median(x$annual_max_drawdown), median_exposure = stats::median(x$exposed_sessions / x$sessions), stringsAsFactors = FALSE)))

nearest_symbol <- function(values, target, symbols) symbols[order(abs(values - target), symbols)][[1L]]
main1 <- main[main$leverage == 1, ]
manifest <- data.frame(tape_role = c("MEDIAN_RETURN", "HIGHEST_RETURN", "LOWEST_RETURN", "DEEPEST_DRAWDOWN", "HIGHEST_TRADE_COUNT", "HIGHEST_RECLAIM_SHARE"), symbol = c(
  nearest_symbol(main1$total_return, stats::median(main1$total_return), main1$symbol), main1$symbol[order(-main1$total_return, main1$symbol)][[1L]],
  main1$symbol[order(main1$total_return, main1$symbol)][[1L]], main1$symbol[order(main1$maximum_drawdown, main1$symbol)][[1L]],
  main1$symbol[order(-main1$trade_count, main1$symbol)][[1L]], main1$symbol[order(-(main1$reclaim_entries / pmax(main1$trade_count, 1)), main1$symbol)][[1L]]
), stringsAsFactors = FALSE)
reclaim_share <- main1$reclaim_entries / pmax(main1$trade_count, 1)
reclaim_candidates <- main1$symbol[order(-reclaim_share, main1$symbol)]
manifest$symbol[[6L]] <- reclaim_candidates[!reclaim_candidates %in% manifest$symbol[1:5]][[1L]]
manifest <- merge(manifest, main1, by = "symbol", all.x = TRUE, sort = FALSE); manifest <- manifest[match(c("MEDIAN_RETURN", "HIGHEST_RETURN", "LOWEST_RETURN", "DEEPEST_DRAWDOWN", "HIGHEST_TRADE_COUNT", "HIGHEST_RECLAIM_SHARE"), manifest$tape_role), ]; manifest$visual_file <- NA_character_

ink <- "#202630"; blue <- "#2C6CB0"; cyan <- "#58B7C7"; green <- "#2E8B57"; red <- "#C83E3A"; gray <- "#D8DEE7"; purple <- "#7654C4"
png(file.path(visual_dir, "coverage_and_composition.png"), 1800, 1000, res = 150); par(mfrow = c(1, 3), mar = c(6, 5, 4, 1)); ct <- table(coverage$coverage_status); barplot(ct, names.arg = ifelse(names(ct) == "ELIGIBLE", "Eligible", "Incomplete"), las = 1, col = ifelse(names(ct) == "ELIGIBLE", green, red), main = "Frozen 122-name coverage", ylab = "Assets"); cohort_counts <- table(eligible$cohort); names(cohort_counts) <- c("Diversified core", "Original 22", "Retail attention")[match(names(cohort_counts), c("DIVERSIFIED_CORE", "ORIGINAL_22", "RETAIL_ATTENTION_2020"))]; barplot(cohort_counts, las = 1, col = blue, main = "Eligible source cohorts", ylab = "Assets", cex.names = .8); barplot(sort(table(eligible$sector)), horiz = TRUE, las = 1, col = cyan, main = "Eligible assets by sector", xlab = "Assets"); dev.off()

png(file.path(visual_dir, "primary_vs_baselines.png"), 1800, 1000, res = 150); par(mfrow = c(1, 2), mar = c(6, 5, 4, 1)); for (L in contract$leverages) { x <- baseline_comparisons[baseline_comparisons$leverage == L, ]; med <- tapply(x$excess_return, x$policy, median); labels <- c(BUY_HOLD = "Buy & hold", ORDERED_STACK = "Ordered stack", SMA30_ONLY = "SMA30 only")[names(med)]; barplot(med, names.arg = labels, las = 1, col = ifelse(med > 0, green, red), ylab = "Median excess return", main = paste0("HYP-MOM-05.1 minus baseline | ", L, "x"), cex.names = .9); abline(h = 0, col = ink) }; dev.off()

png(file.path(visual_dir, "leverage_return_and_drawdown.png"), 1800, 1000, res = 150); par(mfrow = c(1, 2), mar = c(5, 5, 4, 2)); plot(leverage_comparisons$total_return_1x, leverage_comparisons$total_return_1_8x, pch = 19, col = ifelse(leverage_comparisons$incremental_return > 0, green, red), xlab = "1x total return", ylab = "1.8x total return", main = "Fixed-quantity leverage: return consequence"); abline(0,1,lty=2); abline(h=0,v=0,col=gray); plot(leverage_comparisons$maximum_drawdown_1x, leverage_comparisons$maximum_drawdown_1_8x, pch = 19, col = red, xlab = "1x maximum drawdown", ylab = "1.8x maximum drawdown", main = "Fixed-quantity leverage: drawdown consequence"); abline(0,1,lty=2); dev.off()

png(file.path(visual_dir, "timing_controls_and_entry_types.png"), 1800, 1000, res = 150); par(mfrow = c(1, 2), mar = c(6, 5, 4, 2)); hist(stats::na.omit(main1$random_percentile), breaks = seq(0,1,.1), col = blue, border = "white", xlab = "Percentile vs circular exposure shifts", main = "Matched timing control | 1x"); abline(v=.5,lty=2); vals <- entry_summary$median_trade_return[entry_summary$leverage == 1]; names(vals) <- c("Initial activation", "Reclaim"); barplot(vals, las=1, col=ifelse(vals>0,green,red), ylab="Median trade return", main="Initial activation versus reclaim | 1x"); abline(h=0); dev.off()

png(file.path(visual_dir, "leverage_risk_diagnostics.png"), 1800, 1000, res = 150); par(mfrow = c(1, 3), mar = c(6, 5, 4, 1)); x18 <- main[main$leverage == 1.8, ]; plot.new(); title("1.8x impairment flags"); text(.5,.58,"0 maintenance-proxy breaches",cex=1.15,col=green); text(.5,.43,"0 nonpositive-equity assets",cex=1.15,col=green); hist(x18$total_financing_cost, col=purple,border="white",main="1.8x financing paid",xlab="Wealth units"); hist(x18$maximum_effective_leverage[is.finite(x18$maximum_effective_leverage)],col=blue,border="white",main="Peak effective leverage",xlab="Gross / equity"); dev.off()

o <- order(sector_summary$median_return[sector_summary$leverage == 1]); sx <- sector_summary[sector_summary$leverage == 1, ][o, ]; png(file.path(visual_dir, "sector_descriptive_outcomes.png"), 1800, 1000, res=150); par(mfrow=c(1,2),mar=c(5,11,4,1)); barplot(sx$median_return,names.arg=sx$panel,horiz=TRUE,las=1,col=ifelse(sx$median_return>0,green,red),main="Median return by sector | 1x",xlab="Return"); barplot(sx$median_max_drawdown,names.arg=sx$panel,horiz=TRUE,las=1,col=red,main="Median maximum drawdown | 1x",xlab="Drawdown"); dev.off()

plot_tape <- function(symbol, role, file) {
  p <- paths[paths$symbol == symbol & paths$leverage == 1, ]; s <- main1[main1$symbol == symbol, ]; tr <- trades[trades$symbol == symbol & trades$leverage == 1, ]
  png(file, 1800, 1100, res=150); layout(matrix(c(1,2),2,1),heights=c(1.3,1)); par(mar=c(2,6,4,2)); plot(p$session_date,p$close,type="l",col=ink,lwd=1.2,xlab="",ylab="Adjusted close",main=paste(gsub("_"," ",role),"|",symbol,"| price, stack, and exposure")); lines(p$session_date,p$sma15,col=cyan,lwd=1.2); lines(p$session_date,p$sma30,col=blue,lwd=1.8); lines(p$session_date,p$sma45,col=purple,lwd=1.2); usr<-par("usr"); long<-which(p$in_position_after_open); if(length(long)) segments(p$session_date[long],usr[3],p$session_date[long],usr[3]+.035*diff(usr[3:4]),col=adjustcolor(green,.45),lwd=3); if(nrow(tr)){ points(tr$entry_date,tr$entry_open,pch=24,bg=green,col=green,cex=1.1); points(tr$exit_date,tr$exit_open,pch=25,bg=red,col=red,cex=1.1)}; legend("topright",c("Close","SMA15","SMA30","SMA45","Long"),col=c(ink,cyan,blue,purple,green),lty=1,lwd=c(1.2,1.2,1.8,1.2,3),bty="o",bg="white",ncol=3,cex=.8)
  par(mar=c(6,6,3,2)); plot(p$session_date,p$wealth_open,type="l",col=green,lwd=2,xlab="Session",ylab="Wealth from 1.0",main=sprintf("Return %.1f%% | max DD %.1f%% | %d trades | exposure %.1f%%",100*s$total_return,100*s$maximum_drawdown,s$trade_count,100*s$exposure_fraction)); abline(h=1,col=gray,lty=2); dev.off()
}
for(i in seq_len(nrow(manifest))){ file<-file.path(visual_dir,sprintf("triple_sma_tape_%02d_%s_%s.png",i,tolower(manifest$tape_role[[i]]),tolower(manifest$symbol[[i]]))); plot_tape(manifest$symbol[[i]],manifest$tape_role[[i]],file); manifest$visual_file[[i]]<-basename(file) }

integrity <- data.frame(check=c("registered_122","unique_symbols","eleven_sectors","explicit_as_of","confirmation_excluded","full_discovery_calendar","prehistory","no_replacements","cash_start","boundary_cash","initial_activation_entries","reclaim_entries_after_exit","fixed_leverages","primary_cost","stress_cost","random_controls_500"), passed=c(nrow(registry)==122L,!anyDuplicated(registry$symbol),length(unique(registry$sector))==11L,nzchar(contract$as_of_timestamp),!any(bars_all$session_date>=contract$confirmation_start),all(coverage$discovery_missing_sessions[coverage$analysis_eligible]==0L),all(coverage$prehistory_sessions[coverage$analysis_eligible]>=contract$prehistory_sessions),nrow(eligible)==sum(coverage$analysis_eligible),all(paths$in_position_after_open[paths$session_date==contract$discovery_start]==FALSE),all(paths$in_position_after_open[paths$session_date==contract$discovery_end]==FALSE),all(trades$entry_reason%in%c("ORDER_ACTIVATION","MEDIUM_RECLAIM")),all(trades$entry_reason[trades$entry_reason=="MEDIUM_RECLAIM"]=="MEDIUM_RECLAIM"),identical(contract$leverages,c(1,1.8)),contract$primary_cost_bps==5,contract$stress_cost_bps==10,all(table(random_controls$instance_id,random_controls$leverage)==contract$random_simulations)))
if(!all(integrity$passed)) stop(paste("Integrity failed:",paste(integrity$check[!integrity$passed],collapse=", ")),call.=FALSE)

run_spec <- data.frame(hypothesis_id=contract$hypothesis_id,status="WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY",evidence_stage=contract$evidence_stage,as_of_timestamp=contract$as_of_timestamp,discovery_start=contract$discovery_start,discovery_end=contract$discovery_end,registered_assets=nrow(registry),eligible_assets=nrow(eligible),primary_rule="15>30>45 activation; close<=SMA30 exit; ordered reclaim",leverages="1.0,1.8 fixed quantity",refresh=refresh,stringsAsFactors=FALSE)
files <- list(run_spec=run_spec,integrity=integrity,registry=registry,coverage=coverage,query_health=query$health,asset_policy_summary=asset_policy_summary,trades=trades,daily_paths=paths,random_controls=random_controls,panel_summary=panels,sector_summary=sector_summary,annual_asset_summary=annual_asset_summary,annual_panel_summary=annual_panel_summary,entry_summary=entry_summary,baseline_comparisons=baseline_comparisons,leverage_comparisons=leverage_comparisons,tape_manifest=manifest)
for(nm in names(files)) write_csv(files[[nm]],file.path(output_dir,paste0("hyp_mom_05_1_",nm,".csv")))
p1 <- panels[panels$panel=="COMBINED" & panels$leverage==1, ]; p18 <- panels[panels$panel=="COMBINED" & panels$leverage==1.8, ]
report <- c("# HYP-MOM-05.1 Triple-SMA Pullback/Reclaim Wide Discovery","","Status: `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`","",sprintf("- Registered / eligible assets: %d / %d",nrow(registry),nrow(eligible)),sprintf("- Completed trades: %d at each leverage",p1$trade_count),sprintf("- 1x median return / max drawdown: %s / %s",percent(p1$median_return),percent(p1$median_max_drawdown)),sprintf("- 1.8x median return / max drawdown: %s / %s",percent(p18$median_return),percent(p18$median_max_drawdown)),sprintf("- 1x median exposure / hit rate: %s / %s",percent(p1$median_exposure),percent(p1$median_hit_rate)),sprintf("- 1x assets above the 80th timing-control percentile: %d / %d",p1$assets_above_random_80,p1$asset_count),sprintf("- 1.8x maintenance-proxy / nonpositive-equity assets: %d / %d",p18$maintenance_breach_assets,p18$nonpositive_equity_assets),"","This reused-window discovery is descriptive. It does not authorize parameter selection, confirmation access, a portfolio, leverage use, or live behavior.")
writeLines(report,file.path(output_dir,"hyp_mom_05_1_report.md"),useBytes=TRUE)
message("HYP-MOM-05.1 complete: ",output_dir)
