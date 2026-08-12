options(stringsAsFactors = FALSE)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Expected exactly one --file argument.", call. = FALSE)
script_path <- normalizePath(sub("^--file=", "", script_arg), winslash = "/", mustWork = TRUE)
repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "scripts/lib/repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R","config_loader.R","calendar.R","alpaca_provider.R","cache_store.R","data_audit.R","universe_registry.R","workbench_query.R")) source(file.path(repo_root,"R",f))
for (f in c("hyp_mom_04_1_engine.R","hyp_mom_04_2_engine.R","hyp_mom_04_3a_engine.R","hyp_mom_04_3b_engine.R")) source(file.path(repo_root,"operator_hypothesis_lab/R",f))
g5_load_local_renviron(repo_root)
env_bool <- function(name, default=FALSE) tolower(Sys.getenv(name, if(default) "true" else "false")) %in% c("1","true","yes")
write_csv <- function(x,p) utils::write.csv(as.data.frame(x),p,row.names=FALSE,na="")

run_id <- "hyp_mom_04_3b_sector_relative_replication_20260811"
out <- file.path(repo_root,"runs/research_workbench/operator_hypothesis_lab",run_id); vis <- file.path(out,"visuals")
dir.create(vis,recursive=TRUE,showWarnings=FALSE)
source_dir <- file.path(repo_root,"runs/research_workbench/operator_hypothesis_lab/hyp_mom_04_2_feature_atlas_train_20260811")
audit_dir <- file.path(repo_root,"runs/research_workbench/operator_hypothesis_lab/hyp_mom_04_1_deployment_universe_data_audit_20260811")
train <- utils::read.csv(file.path(source_dir,"hyp_mom_04_2_feature_panel.csv"),stringsAsFactors=FALSE)
train <- h043a_build_targets(train)
coverage <- utils::read.csv(file.path(audit_dir,"train_coverage_ledger.csv"),stringsAsFactors=FALSE)
coverage <- coverage[coverage$complete_train,]
registry <- data.frame(instance_id=paste0("SPY_202009_",coverage$source_symbol),symbol=coverage$provider_symbol,sector=coverage$sector,cohort="SPY_2020_09_DEPLOYMENT")

query_start <- as.Date("2020-01-02"); query_end <- as.Date("2023-12-29"); forbidden <- as.Date("2024-01-01")
quarters <- c("2021Q1","2021Q2","2021Q3","2021Q4","2022Q1","2022Q2","2022Q3","2022Q4","2023Q1","2023Q2","2023Q3")
cfg <- g5_load_data_layer_config(repo_root); refresh <- env_bool("GEN5_HYP_MOM_043B_REFRESH",FALSE)
symbols <- sort(unique(c(registry$symbol,"SPY"))); groups <- split(symbols,ceiling(seq_along(symbols)/20))
bar_chunks <- list(); health_chunks <- list()
for(i in seq_along(groups)) {
 q <- g5_workbench_query_adjusted_daily_bars(cfg=cfg,start_date=query_start,end_date=query_end,as_of_timestamp="2026-08-07 17:30:00 America/New_York",symbols=groups[[i]],universe_name=paste0("hyp_mom_04_3b_chunk_",i),universe_roles="fixed_2020_cohort,development_only",refresh=refresh,repo_root=repo_root)
 bar_chunks[[i]] <- q$bars; q$health$chunk <- i; health_chunks[[i]] <- q$health; message("Chunk ",i,"/",length(groups))
}
bars <- h04_validate_bars(do.call(rbind,bar_chunks),query_end,h04_contract()); health <- do.call(rbind,health_chunks)
spy <- bars[bars$symbol=="SPY",]; calendar <- sort(unique(spy$session_date)); schedule <- h04_schedule(calendar,quarters)

# Audit every signal-eligible identity before allowing completed rows to define the sample.
ledger <- do.call(rbind,lapply(seq_len(nrow(registry)),function(i){
 id <- registry[i,]; x <- bars[bars$symbol==id$symbol,]; x <- x[order(x$session_date),]
 do.call(rbind,lapply(seq_len(nrow(schedule)),function(j){s<-schedule[j,]; t<-match(s$signal_date,x$session_date); entry<-match(s$entry_date,x$session_date); exit<-match(s$exit_date,x$session_date)
  eligible <- !is.na(t) && t>=253L && !is.na(entry)
  data.frame(symbol=id$symbol,sector=id$sector,signal_quarter=s$signal_quarter,signal_date=s$signal_date,entry_date=s$entry_date,exit_date=s$exit_date,signal_feature_eligible=eligible,scheduled_exit_available=!is.na(exit),terminal_unresolved=eligible&&is.na(exit))}))}))
unresolved <- ledger[ledger$terminal_unresolved,]

failure_symbols <- c("FRC","SIVB")
terminal_resolution <- unresolved
if(nrow(terminal_resolution)) {
 terminal_resolution$resolution_method <- ifelse(terminal_resolution$symbol %in% failure_symbols,"ZERO_RECOVERY_RECEIVERSHIP","FINAL_AVAILABLE_ADJUSTED_CLOSE")
 terminal_resolution$terminal_date <- as.Date(NA); terminal_resolution$terminal_value <- NA_real_; terminal_resolution$resolved <- FALSE
 for(i in seq_len(nrow(terminal_resolution))) {
  local <- bars[bars$symbol==terminal_resolution$symbol[[i]] & bars$session_date>=as.Date(terminal_resolution$entry_date[[i]]) & bars$session_date<=as.Date(terminal_resolution$exit_date[[i]]),,drop=FALSE]
  if(!nrow(local)) next
  last <- local[which.max(local$session_date),,drop=FALSE]
  terminal_resolution$terminal_date[[i]] <- last$session_date[[1L]]
  terminal_resolution$terminal_value[[i]] <- if(terminal_resolution$resolution_method[[i]]=="ZERO_RECOVERY_RECEIVERSHIP") 0 else last$close[[1L]]
  terminal_resolution$resolved[[i]] <- TRUE
 }
}
data_gates <- data.frame(gate_id=c("NO_2024_ACCESS","ALL_11_QUARTERS","AT_LEAST_400_SIGNAL_IDENTITIES","ALL_TERMINALS_RESOLVED"),
 passed=c(max(bars$session_date)<forbidden,identical(unique(ledger$signal_quarter),quarters),length(unique(ledger$symbol[ledger$signal_feature_eligible]))>=400,!nrow(terminal_resolution)||all(terminal_resolution$resolved)),
 estimate=c(as.character(max(bars$session_date)),length(unique(ledger$signal_quarter)),length(unique(ledger$symbol[ledger$signal_feature_eligible])),paste0(sum(terminal_resolution$resolved),"/",nrow(terminal_resolution))),threshold=c("<2024-01-01","11",">=400","all"))
write_csv(health,file.path(out,"query_health.csv")); write_csv(ledger,file.path(out,"development_coverage_ledger.csv")); write_csv(unresolved,file.path(out,"unresolved_terminal_ledger.csv")); write_csv(terminal_resolution,file.path(out,"terminal_resolution_ledger.csv")); write_csv(data_gates,file.path(out,"data_gate_matrix.csv"))
if(!all(data_gates$passed)) {status<-"STOP_DEVELOPMENT_DATA_GATES_FAILED_MODEL_NOT_RUN";writeLines(status,file.path(out,"status.txt"));cat("Status:",status,"\n");print(data_gates);quit(save="no",status=0)}

dev_contract <- h042_contract(); dev_contract$train_query_end<-query_end; dev_contract$train_signal_quarters<-quarters
# Construct with frozen feature mechanics while bypassing the H04.2 identity check on the changed time window.
rows <- lapply(seq_len(nrow(registry)),function(i){id<-registry[i,];h042_asset_rows(bars[bars$symbol==id$symbol,],spy,schedule,id)})
rows <- Filter(function(x)nrow(x)>0,rows); dev <- do.call(rbind,rows)
dev$scheduled_exit_date <- dev$exit_date; dev$target_resolution <- "SCHEDULED_EXIT_OPEN"
if(nrow(terminal_resolution)) {
 terminal_rows <- lapply(seq_len(nrow(terminal_resolution)),function(i){
 resolution <- terminal_resolution[i,,drop=FALSE]
  identity <- registry[registry$symbol==resolution$symbol,,drop=FALSE]
  local_schedule <- schedule[schedule$signal_quarter==resolution$signal_quarter,,drop=FALSE]
  local_bars <- bars[bars$symbol==resolution$symbol,]
  proxy <- local_bars[which.max(local_bars$session_date),,drop=FALSE]
  proxy$session_date <- local_schedule$exit_date
  local_bars <- rbind(local_bars,proxy)
  row <- h042_asset_rows(local_bars,spy,local_schedule,identity)
  if(nrow(row)!=1L) stop("Terminal resolution did not produce exactly one feature row for ",resolution$symbol," ",resolution$signal_quarter)
  row$scheduled_exit_date <- as.Date(resolution$exit_date); row$exit_date <- as.Date(resolution$terminal_date); row$target_resolution <- resolution$resolution_method
  row$target_return <- resolution$terminal_value/row$entry_open-1
  row
 })
 dev <- rbind(dev,do.call(rbind,terminal_rows))
}
expected_rows <- sum(ledger$signal_feature_eligible)
realized_gate <- data.frame(gate_id="ALL_ELIGIBLE_ROWS_REALIZED",passed=nrow(dev)==expected_rows,estimate=paste0(nrow(dev),"/",expected_rows),threshold="all")
data_gates <- rbind(data_gates,realized_gate); write_csv(data_gates,file.path(out,"data_gate_matrix.csv"))
if(!realized_gate$passed) {status<-"STOP_DEVELOPMENT_DATA_GATES_FAILED_MODEL_NOT_RUN";writeLines(status,file.path(out,"status.txt"));cat("Status:",status,"\n");print(data_gates);quit(save="no",status=0)}
key <- interaction(dev$signal_quarter,dev$sector,drop=TRUE); dev$sector_relative126<-dev$return126_raw-ave(dev$return126_raw,key,FUN=mean)
dev <- h043b_sector_target(dev); for(f in h043b_features()) dev[[paste0(f,"_rn")]]<-ave(dev[[f]],dev$signal_quarter,FUN=h04_rank_normal)
selection <- h043b_select_lambda(train); scored <- h043b_score_comparators(train,dev,selection$selected_lambda)
primary_m <- h043b_metrics(dev,scored$primary$score,dev$target_sector_relative); fixed_m<-h043b_metrics(dev,scored$fixed,dev$target_sector_relative); momentum_m<-h043b_metrics(dev,scored$momentum,dev$target_sector_relative)
quartile <- ave(scored$primary$score,dev$signal_quarter,FUN=h04_quartile); predictions<-data.frame(dev[c("symbol","sector","signal_quarter","entry_date","exit_date","scheduled_exit_date","target_resolution","target_return","target_sector_relative")],score=scored$primary$score,quartile=quartile)
gates <- h043b_gate_matrix(primary_m,fixed_m,momentum_m,predictions); status<-if(all(gates$passed))"DEVELOPMENT_REPLICATION_PASS_CONFIRMATION_STILL_LOCKED" else "STOP_DEVELOPMENT_REPLICATION_FAILED_CONFIRMATION_NOT_RUN"
write_csv(selection$details,file.path(out,"train_lambda_details.csv"));write_csv(selection$summary,file.path(out,"train_lambda_summary.csv"));write_csv(primary_m,file.path(out,"development_primary_metrics.csv"));write_csv(fixed_m,file.path(out,"development_fixed_metrics.csv"));write_csv(momentum_m,file.path(out,"development_momentum_metrics.csv"));write_csv(predictions,file.path(out,"development_predictions.csv"));write_csv(gates,file.path(out,"replication_gate_matrix.csv"));writeLines(status,file.path(out,"status.txt"))
png(file.path(vis,"development_replication.png"),1900,1100,res=160);par(mfrow=c(1,2),mar=c(7,5,4,1));plot(primary_m$rank_ic,type="b",pch=19,xaxt="n",col=ifelse(primary_m$rank_ic>0,"#2AA876","#D1495B"),xlab="Quarter",ylab="Rank IC",main="Fresh sector-relative replication");axis(1,1:11,primary_m$signal_quarter,las=2);abline(h=0,col="gray");plot(100*primary_m$top_quartile_target,type="b",pch=19,xaxt="n",col=ifelse(primary_m$top_quartile_target>0,"#2AA876","#D1495B"),xlab="Quarter",ylab="Top-quartile sector-relative return (pp)",main="Within-sector winner behavior");axis(1,1:11,primary_m$signal_quarter,las=2);abline(h=0,col="gray");dev.off()
cat("Status:",status,"\nSelected lambda:",selection$selected_lambda,"\n");print(gates)
