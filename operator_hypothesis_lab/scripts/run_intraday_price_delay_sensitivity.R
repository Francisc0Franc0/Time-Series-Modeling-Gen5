options(stringsAsFactors=FALSE)
repo<-normalizePath(getwd(),winslash="/",mustWork=TRUE)
local_lib<-file.path(repo,".codex_r_libs");if(dir.exists(local_lib)).libPaths(c(local_lib,.libPaths()))
source(file.path(repo,"operator_hypothesis_lab","R","hyp_intraday_alpaca_30min.R"))
source(file.path(repo,"operator_hypothesis_lab","R","hyp_intraday_momentum_engine.R"))
contract<-imom_contract();registry<-read.csv(file.path(repo,"operator_hypothesis_lab","registries","gen5_intraday_momentum_poc_registry.csv"))
stocks<-registry$symbol[registry$asset_type=="stock"];cache_dir<-file.path(repo,"data_cache","alpaca_intraday_30min")
run_dir<-file.path(repo,"runs","research_workbench","operator_hypothesis_lab","intraday_momentum_poc_series_20260813")
keep<-c("symbol","timestamp_utc","session_date","bar_time_et","bar_slot","open","high","low","close","volume")
bars<-do.call(rbind,lapply(file.path(cache_dir,sprintf("intraday_30min_sip_all_%d.rds",2017:2023)),function(path){x<-readRDS(path);x[,keep,drop=FALSE]}))
bars<-bars[!duplicated(bars[c("symbol","timestamp_utc")]),];bars<-bars[order(bars$symbol,bars$timestamp_utc),]
bars<-imom30_apply_rth_calendar(bars);bars<-imom30_apply_archive_exclusions(bars)
folds<-imom_quarters();selections<-read.csv(file.path(run_dir,"price_sma_selections.csv"));quarter_bh<-read.csv(file.path(run_dir,"quarterly_buy_hold_summaries.csv"))
rows<-list();z<-1L
for(fi in seq_len(nrow(folds))){f<-folds[fi,];sel<-selections[selections$fold==f$fold,][1L,]
  for(sym in stocks){x<-bars[bars$symbol==sym,];schedule<-imom_price_schedule(x,f$test_start,f$test_end,sel$anchor,sel$exit_anchor,delay_bars=1L)
    out<-imom_replay(x,f$test_start,f$test_end,schedule,1,10,.06,"PRIMARY_DELAY1",3276L,contract);q<-out$summary;q$fold<-f$fold;q$candidate_id<-sel$candidate_id
    bh<-quarter_bh$total_return[quarter_bh$symbol==sym&quarter_bh$fold==f$fold&quarter_bh$leverage==1&quarter_bh$scenario=="PRIMARY"]
    q$buy_hold_return<-if(length(bh))bh[[1L]]else NA_real_;q$direct_excess<-q$total_return-q$buy_hold_return;rows[[z]]<-q;z<-z+1L}}
result<-do.call(rbind,rows);write.csv(result,file.path(run_dir,"price_sma_delay_summaries.csv"),row.names=FALSE)
writeLines("PRICE_DELAY_COMPLETE",file.path(run_dir,"PRICE_DELAY_STATUS.txt"));message("PRICE_DELAY_COMPLETE")
