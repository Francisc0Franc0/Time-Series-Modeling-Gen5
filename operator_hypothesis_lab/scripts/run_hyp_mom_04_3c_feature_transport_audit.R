options(stringsAsFactors = FALSE)
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Expected exactly one --file argument.", call. = FALSE)
script_path <- normalizePath(sub("^--file=", "", script_arg), winslash = "/", mustWork = TRUE)
repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "scripts/lib/repo_local_libs.R")); g5_use_repo_local_libs(repo_root)
for (f in c("data_contract.R","config_loader.R","calendar.R","alpaca_provider.R","cache_store.R","data_audit.R","universe_registry.R","workbench_query.R")) source(file.path(repo_root,"R",f))
for (f in c("hyp_mom_04_1_engine.R","hyp_mom_04_2_engine.R","hyp_mom_04_3a_engine.R","hyp_mom_04_3b_engine.R","hyp_mom_04_3c_engine.R")) source(file.path(repo_root,"operator_hypothesis_lab/R",f))
g5_load_local_renviron(repo_root)
write_csv <- function(x,p) utils::write.csv(as.data.frame(x),p,row.names=FALSE,na="")

run_id <- "hyp_mom_04_3c_feature_transport_audit_20260811"
out <- file.path(repo_root,"runs/research_workbench/operator_hypothesis_lab",run_id)
vis <- file.path(out,"visuals"); dir.create(vis,recursive=TRUE,showWarnings=FALSE)
audit_dir <- file.path(repo_root,"runs/research_workbench/operator_hypothesis_lab/hyp_mom_04_1_deployment_universe_data_audit_20260811")
coverage <- utils::read.csv(file.path(audit_dir,"train_coverage_ledger.csv"),stringsAsFactors=FALSE)
coverage <- coverage[coverage$complete_train,]
registry <- data.frame(instance_id=paste0("SPY_202009_",coverage$source_symbol),symbol=coverage$provider_symbol,sector=coverage$sector,cohort="SPY_2020_09_DEPLOYMENT")

query_start <- as.Date("2020-01-02"); query_end <- as.Date("2023-12-29"); forbidden <- as.Date("2024-01-01")
quarters <- c("2021Q1","2021Q2","2021Q3","2021Q4","2022Q1","2022Q2","2022Q3","2022Q4","2023Q1","2023Q2","2023Q3")
cfg <- g5_load_data_layer_config(repo_root)
symbols <- sort(unique(c(registry$symbol,"SPY"))); groups <- split(symbols,ceiling(seq_along(symbols)/20))
bar_chunks <- list(); health_chunks <- list()
for(i in seq_along(groups)) {
  q <- g5_workbench_query_adjusted_daily_bars(cfg=cfg,start_date=query_start,end_date=query_end,as_of_timestamp="2026-08-07 17:30:00 America/New_York",symbols=groups[[i]],universe_name=paste0("hyp_mom_04_3c_chunk_",i),universe_roles="fixed_2020_cohort,retrospective_diagnostic_only",refresh=FALSE,repo_root=repo_root)
  bar_chunks[[i]] <- q$bars; q$health$chunk <- i; health_chunks[[i]] <- q$health
  message("Chunk ",i,"/",length(groups))
}
bars <- h04_validate_bars(do.call(rbind,bar_chunks),query_end,h04_contract())
health <- do.call(rbind,health_chunks); spy <- bars[bars$symbol=="SPY",]
schedule <- h04_schedule(sort(unique(spy$session_date)),quarters)

ledger <- do.call(rbind,lapply(seq_len(nrow(registry)),function(i){
  id <- registry[i,]; x <- bars[bars$symbol==id$symbol,]; x <- x[order(x$session_date),]
  do.call(rbind,lapply(seq_len(nrow(schedule)),function(j){
    s<-schedule[j,]; t<-match(s$signal_date,x$session_date); entry<-match(s$entry_date,x$session_date); exit<-match(s$exit_date,x$session_date)
    eligible <- !is.na(t) && t>=253L && !is.na(entry)
    data.frame(symbol=id$symbol,sector=id$sector,signal_quarter=s$signal_quarter,signal_date=s$signal_date,entry_date=s$entry_date,exit_date=s$exit_date,signal_feature_eligible=eligible,scheduled_exit_available=!is.na(exit),terminal_unresolved=eligible&&is.na(exit))
  }))
}))
unresolved <- ledger[ledger$terminal_unresolved,]
failure_symbols <- c("FRC","SIVB"); terminal_resolution <- unresolved
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

data_gates <- data.frame(
  gate_id=c("NO_2024_ACCESS","ALL_11_QUARTERS","AT_LEAST_400_SIGNAL_IDENTITIES","ALL_TERMINALS_RESOLVED"),
  passed=c(max(bars$session_date)<forbidden,identical(unique(ledger$signal_quarter),quarters),length(unique(ledger$symbol[ledger$signal_feature_eligible]))>=400,all(terminal_resolution$resolved)),
  estimate=c(as.character(max(bars$session_date)),length(unique(ledger$signal_quarter)),length(unique(ledger$symbol[ledger$signal_feature_eligible])),paste0(sum(terminal_resolution$resolved),"/",nrow(terminal_resolution))),
  threshold=c("<2024-01-01","11",">=400","all")
)
write_csv(health,file.path(out,"query_health.csv")); write_csv(ledger,file.path(out,"coverage_ledger.csv")); write_csv(terminal_resolution,file.path(out,"terminal_resolution_ledger.csv"))
if(!all(data_gates$passed)) {write_csv(data_gates,file.path(out,"data_gate_matrix.csv"));writeLines("STOP_DATA_GATE_FAILED_AUDIT_NOT_RUN",file.path(out,"status.txt"));quit(save="no",status=0)}

rows <- lapply(seq_len(nrow(registry)),function(i){id<-registry[i,];h042_asset_rows(bars[bars$symbol==id$symbol,],spy,schedule,id)})
rows <- Filter(function(x)nrow(x)>0,rows); dev <- do.call(rbind,rows)
dev$scheduled_exit_date <- dev$exit_date; dev$target_resolution <- "SCHEDULED_EXIT_OPEN"
terminal_rows <- lapply(seq_len(nrow(terminal_resolution)),function(i){
  resolution <- terminal_resolution[i,,drop=FALSE]; identity <- registry[registry$symbol==resolution$symbol,,drop=FALSE]
  local_schedule <- schedule[schedule$signal_quarter==resolution$signal_quarter,,drop=FALSE]
  local_bars <- bars[bars$symbol==resolution$symbol,]; proxy <- local_bars[which.max(local_bars$session_date),,drop=FALSE]
  proxy$session_date <- local_schedule$exit_date; local_bars <- rbind(local_bars,proxy)
  row <- h042_asset_rows(local_bars,spy,local_schedule,identity)
  if(nrow(row)!=1L) stop("Terminal resolution row failure: ",resolution$symbol," ",resolution$signal_quarter)
  row$scheduled_exit_date <- as.Date(resolution$exit_date); row$exit_date <- as.Date(resolution$terminal_date); row$target_resolution <- resolution$resolution_method
  row$target_return <- resolution$terminal_value/row$entry_open-1; row
})
dev <- rbind(dev,do.call(rbind,terminal_rows)); expected_rows <- sum(ledger$signal_feature_eligible)
data_gates <- rbind(data_gates,data.frame(gate_id="ALL_ELIGIBLE_ROWS_REALIZED",passed=nrow(dev)==expected_rows,estimate=paste0(nrow(dev),"/",expected_rows),threshold="all"))
write_csv(data_gates,file.path(out,"data_gate_matrix.csv"))
if(!all(data_gates$passed)) {writeLines("STOP_DATA_GATE_FAILED_AUDIT_NOT_RUN",file.path(out,"status.txt"));quit(save="no",status=0)}

key <- interaction(dev$signal_quarter,dev$sector,drop=TRUE)
dev$sector_relative126 <- dev$return126_raw-ave(dev$return126_raw,key,FUN=mean)
dev <- h043b_sector_target(dev); dev$terminal_policy_row <- dev$target_resolution!="SCHEDULED_EXIT_OPEN"
write_csv(dev[c("symbol","sector","signal_quarter","signal_date","entry_date","exit_date","scheduled_exit_date","target_resolution","target_return","target_sector_relative",h043c_features())],file.path(out,"feature_panel.csv"))

main <- h043c_audit(dev)
write_csv(main$quarter_metrics,file.path(out,"feature_quarter_metrics.csv")); write_csv(main$summary,file.path(out,"feature_summary.csv"))
write_csv(main$quartile_shape,file.path(out,"feature_quartile_shape.csv")); write_csv(main$sector_metrics,file.path(out,"feature_sector_metrics.csv"))
sector_breadth <- do.call(rbind,lapply(split(main$sector_metrics,main$sector_metrics$feature),function(x)data.frame(feature=x$feature[[1L]],positive_mean_ic_sectors=sum(x$mean_rank_ic>0),sectors=nrow(x),median_sector_ic=median(x$mean_rank_ic))))
write_csv(sector_breadth,file.path(out,"feature_sector_breadth.csv"))

train_path <- file.path(repo_root,"runs/research_workbench/operator_hypothesis_lab/hyp_mom_04_2_feature_atlas_train_20260811/hyp_mom_04_2_feature_panel.csv")
train <- h043a_build_targets(utils::read.csv(train_path,stringsAsFactors=FALSE))
frozen_fit <- h043b_fit_score(train,train,train$target_sector_relative,10)$fit
coefficient_transport <- data.frame(
  feature=h043c_features(),
  frozen_train_coefficient=as.numeric(frozen_fit$coefficients[paste0(h043c_features(),"_rn")]),
  development_mean_ic=main$summary$mean_rank_ic[match(h043c_features(),main$summary$feature)]
)
coefficient_transport$sign_agrees <- sign(coefficient_transport$frozen_train_coefficient)==sign(coefficient_transport$development_mean_ic)
write_csv(coefficient_transport,file.path(out,"frozen_coefficient_transport.csv"))

variants <- list(MAIN=dev,EXCLUDE_ALL_TERMINALS=dev[!dev$terminal_policy_row,],EXCLUDE_ZERO_RECOVERY=dev[dev$target_resolution!="ZERO_RECOVERY_RECEIVERSHIP",])
sensitivity <- do.call(rbind,lapply(names(variants),function(name){x<-h043c_audit(variants[[name]])$summary;x$variant<-name;x$observations<-nrow(variants[[name]]);x}))
sensitivity <- sensitivity[c("variant","observations","feature",setdiff(names(sensitivity),c("variant","observations","feature")))]
write_csv(sensitivity,file.path(out,"terminal_sensitivity_summary.csv"))

status <- "FEATURE_TRANSPORT_AUDIT_COMPLETE_NO_PROMOTION_AUTHORITY"
writeLines(status,file.path(out,"status.txt"))

features <- h043c_features(); qm <- main$quarter_metrics
png(file.path(vis,"feature_transport_heatmap.png"),1900,1050,res=160)
par(mar=c(6,13,4,2))
z <- matrix(qm$rank_ic,nrow=length(features),byrow=TRUE)
image(seq_len(ncol(z)),seq_len(nrow(z)),t(z),col=colorRampPalette(c("#D1495B","white","#2AA876"))(101),zlim=c(-max(abs(z)),max(abs(z))),axes=FALSE,xlab="Signal quarter",ylab="Feature",main="Quarterly sector-relative rank IC")
axis(1,seq_len(11),quarters); axis(2,seq_along(features),c("Sector momentum","Trend R2","Recovery from low","Positive months"),las=2); abline(v=seq(.5,11.5,1),h=seq(.5,4.5,1),col="white")
dev.off()

png(file.path(vis,"feature_quartile_shapes.png"),1900,1050,res=160)
par(mfrow=c(2,2),mar=c(5,5,3,1))
short_names <- c("Sector momentum","Trend R2","Recovery from low","Positive months")
for(i in seq_along(features)){f<-features[[i]];x<-main$quartile_shape[main$quartile_shape$feature==f,];plot(x$quartile,100*x$mean_target,type="b",pch=19,col="#2979FF",xaxt="n",xlab="Feature quartile",ylab="Mean sector-relative return (pp)",main=short_names[[i]],cex.lab=.85,cex.axis=.85);axis(1,1:4,paste0("Q",1:4));abline(h=0,col="gray")}
dev.off()
cat("Status:",status,"\n");print(main$summary);print(sector_breadth);print(coefficient_transport)
