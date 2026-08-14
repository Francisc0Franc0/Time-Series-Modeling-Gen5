options(stringsAsFactors=FALSE)
repo<-normalizePath(getwd(),winslash="/",mustWork=TRUE)
local_lib<-file.path(repo,".codex_r_libs");if(dir.exists(local_lib)).libPaths(c(local_lib,.libPaths()))
source(file.path(repo,"operator_hypothesis_lab","R","hyp_intraday_alpaca_30min.R"))
source(file.path(repo,"operator_hypothesis_lab","R","hyp_intraday_momentum_engine.R"))
contract<-imom_contract()
registry<-read.csv(file.path(repo,"operator_hypothesis_lab","registries","gen5_intraday_momentum_poc_registry.csv"))
cache_dir<-file.path(repo,"data_cache","alpaca_intraday_30min")
run_dir<-file.path(repo,"runs","research_workbench","operator_hypothesis_lab","intraday_momentum_poc_series_20260813")
checkpoint_dir<-file.path(run_dir,"chan_checkpoints");dir.create(checkpoint_dir,recursive=TRUE,showWarnings=FALSE)
paths<-file.path(cache_dir,sprintf("intraday_30min_sip_all_%d.rds",2017:2023))
bars<-do.call(rbind,lapply(paths,readRDS));bars<-bars[!duplicated(bars[c("symbol","timestamp_utc")]),]
bars<-bars[order(bars$symbol,bars$timestamp_utc),];bars<-imom30_apply_rth_calendar(bars);bars<-imom30_apply_archive_exclusions(bars)
stocks<-registry$symbol[registry$asset_type=="stock"]
folds<-imom_quarters();scenario_table<-data.frame(scenario=c("GROSS","PRIMARY","STRESS"),m30_bps=c(0,10,20),financing=c(0,.06,.10))
quarter_bh<-read.csv(file.path(run_dir,"quarterly_buy_hold_summaries.csv"))
qb_key<-quarter_bh[,c("symbol","fold","leverage","scenario","total_return")];names(qb_key)[5]<-"buy_hold_return"

for(fi in seq_len(nrow(folds))){
  f<-folds[fi,];checkpoint<-file.path(checkpoint_dir,paste0(f$fold,".rds"))
  if(file.exists(checkpoint)){message(f$fold,": CHECKPOINT_HIT");next}
  message(f$fold,": START")
  fold_sel<-list();fold_oos<-list();fold_paths<-list();z<-1L
  for(sym in c(stocks,"SPY","QQQ")){
    x<-bars[bars$symbol==sym,]
    screen<-imom_chan_screen(x,f$train_start,f$train_end,contract);sel<-imom_chan_select(screen)
    sel$symbol<-sym;sel$fold<-f$fold;sel$train_end<-f$train_end;fold_sel[[length(fold_sel)+1L]]<-sel
    if(!isTRUE(sel$admissible)){
      for(lev in contract$leverages)for(si in seq_len(nrow(scenario_table))){s<-scenario_table[si,]
        fold_oos[[z]]<-data.frame(symbol=sym,L=NA_integer_,H=NA_integer_,leverage=lev,scenario=s$scenario,total_return=0,
          sharpe=NA_real_,maximum_drawdown=0,exposure=0,trade_count=0,hit_rate=NA_real_,median_trade=NA_real_,mean_trade=NA_real_,
          median_holding_bars=NA_real_,financing_paid=0,turnover=0,underwater_fraction=0,maximum_underwater_bars=0,
          minimum_equity=contract$initial_wealth,minimum_equity_ratio=1,maintenance_breach=FALSE,fold=f$fold);z<-z+1L}
      next
    }
    for(lev in contract$leverages)for(si in seq_len(nrow(scenario_table))){s<-scenario_table[si,]
      out<-imom_chan_sleeve_replay(x,f$test_start,f$test_end,sel$L,sel$H,lev,s$m30_bps,s$financing,0,s$scenario,contract)
      q<-out$summary;q$fold<-f$fold;fold_oos[[z]]<-q;z<-z+1L
      if(sym%in%c("AMD","TSLA")&&s$scenario=="PRIMARY")fold_paths[[paste(f$fold,sym,lev,sep="_")]]<-out$path
    }
    out<-imom_chan_sleeve_replay(x,f$test_start,f$test_end,sel$L,sel$H,1,10,.06,1,"PRIMARY_DELAY1",contract)
    q<-out$summary;q$fold<-f$fold;fold_oos[[z]]<-q;z<-z+1L
  }
  saveRDS(list(selection=do.call(rbind,fold_sel),oos=do.call(rbind,fold_oos),paths=fold_paths),checkpoint)
  message(f$fold,": COMPLETE")
}

packets<-lapply(folds$fold,function(fold)readRDS(file.path(checkpoint_dir,paste0(fold,".rds"))))
chan_sel<-do.call(rbind,lapply(packets,`[[`,"selection"));chan_oos<-do.call(rbind,lapply(packets,`[[`,"oos"))
chan_paths<-unlist(lapply(packets,`[[`,"paths"),recursive=FALSE)
chan_oos<-merge(chan_oos,qb_key,by=c("symbol","fold","leverage","scenario"),all.x=TRUE)
chan_oos$direct_excess<-chan_oos$total_return-chan_oos$buy_hold_return
write.csv(chan_sel,file.path(run_dir,"chan_selections.csv"),row.names=FALSE)
write.csv(chan_oos,file.path(run_dir,"chan_oos_summaries.csv"),row.names=FALSE)
saveRDS(chan_paths,file.path(run_dir,"chan_canonical_paths.rds"))
writeLines("CHAN_LANE_COMPLETE",file.path(run_dir,"CHAN_STATUS.txt"))
message("CHAN_LANE_COMPLETE")
