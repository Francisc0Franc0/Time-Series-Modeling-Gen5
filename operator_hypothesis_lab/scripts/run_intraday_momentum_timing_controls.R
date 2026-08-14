options(stringsAsFactors=FALSE)
repo<-normalizePath(getwd(),winslash="/",mustWork=TRUE)
local_lib<-file.path(repo,".codex_r_libs");if(dir.exists(local_lib)).libPaths(c(local_lib,.libPaths()))
source(file.path(repo,"operator_hypothesis_lab","R","hyp_intraday_alpaca_30min.R"))
source(file.path(repo,"operator_hypothesis_lab","R","hyp_intraday_momentum_engine.R"))
contract<-imom_contract();set.seed(contract$random_seed)
registry<-read.csv(file.path(repo,"operator_hypothesis_lab","registries","gen5_intraday_momentum_poc_registry.csv"))
stocks<-registry$symbol[registry$asset_type=="stock"]
cache_dir<-file.path(repo,"data_cache","alpaca_intraday_30min")
run_dir<-file.path(repo,"runs","research_workbench","operator_hypothesis_lab","intraday_momentum_poc_series_20260813")
paths<-file.path(cache_dir,sprintf("intraday_30min_sip_all_%d.rds",2017:2023))
keep_columns<-c("symbol","timestamp_utc","session_date","bar_time_et","bar_slot","open","high","low","close","volume")
chunks<-lapply(paths,function(path){x<-readRDS(path);x[,keep_columns,drop=FALSE]})
bars<-do.call(rbind,chunks);rm(chunks);gc();bars<-bars[!duplicated(bars[c("symbol","timestamp_utc")]),]
bars<-bars[order(bars$symbol,bars$timestamp_utc),];bars<-imom30_apply_rth_calendar(bars);bars<-imom30_apply_archive_exclusions(bars)
daily<-imom_aggregate_daily(bars);folds<-imom_quarters();years<-2018:2023
fixed<-read.csv(file.path(run_dir,"fixed_sma_summaries.csv"));price<-read.csv(file.path(run_dir,"price_sma_oos_summaries.csv"));price_sel<-read.csv(file.path(run_dir,"price_sma_selections.csv"))
chan<-read.csv(file.path(run_dir,"chan_oos_summaries.csv"));chan_sel<-read.csv(file.path(run_dir,"chan_selections.csv"))

shift_for<-function(simulation,block_index,session_count){if(session_count<=1L)return(0L);as.integer((simulation*(2L*block_index+1L)+contract$random_seed)%%(session_count-1L)+1L)}
aggregate_sim<-function(lane,leverage,simulation,returns,bh){data.frame(lane=lane,leverage=leverage,simulation=simulation,blocks=length(returns),median_return=median(returns),positive_fraction=mean(returns>0),median_direct_excess=median(returns-bh))}

run_fixed_lane<-function(frequency){
  lane<-if(frequency=="DAILY")"HYP-MOM-06.1"else"HYP-IMOM-01.1";source_bars<-if(frequency=="DAILY")daily else bars;cost<-if(frequency=="DAILY")5 else 10
  blocks<-list();z<-1L
  for(sym in stocks)for(year in years){x<-source_bars[source_bars$symbol==sym,];start<-as.Date(sprintf("%d-01-01",year));end<-min(as.Date(sprintf("%d-12-31",year)),contract$development_end);w<-x[x$session_date>=start&x$session_date<=end,];blocks[[z]]<-list(symbol=sym,year=year,w=w,schedule=imom_sma_schedule(x,start,end,8,14,0));z<-z+1L}
  out<-list();z<-1L
  for(lev in contract$leverages)for(sim in seq_len(contract$random_simulations)){
    ret<-bh<-numeric(length(blocks))
    for(bi in seq_along(blocks)){b<-blocks[[bi]];shift<-shift_for(sim,bi,length(unique(b$w$session_date)));schedule<-imom_shift_schedule_by_sessions(b$schedule,b$w,shift);ret[[bi]]<-imom_fast_terminal_from_schedule(b$w,schedule,lev,cost,.06,contract);hit<-fixed$symbol==b$symbol&fixed$year==b$year&fixed$frequency==frequency&fixed$policy=="BUY_HOLD"&fixed$scenario=="PRIMARY"&fixed$leverage==lev;bh[[bi]]<-fixed$total_return[which(hit)[[1L]]]}
    out[[z]]<-aggregate_sim(lane,lev,sim,ret,bh);z<-z+1L
  }
  do.call(rbind,out)
}

run_price_lane<-function(){
  blocks<-list();z<-1L
  for(fi in seq_len(nrow(folds))){f<-folds[fi,];sel<-price_sel[price_sel$fold==f$fold,][1L,]
    for(sym in stocks){x<-bars[bars$symbol==sym,];w<-x[x$session_date>=f$test_start&x$session_date<=f$test_end,];blocks[[z]]<-list(symbol=sym,fold=f$fold,w=w,schedule=imom_price_schedule(x,f$test_start,f$test_end,sel$anchor,sel$exit_anchor));z<-z+1L}}
  out<-list();z<-1L
  for(lev in contract$leverages)for(sim in seq_len(contract$random_simulations)){
    ret<-bh<-numeric(length(blocks))
    for(bi in seq_along(blocks)){b<-blocks[[bi]];shift<-shift_for(sim,bi,length(unique(b$w$session_date)));schedule<-imom_shift_schedule_by_sessions(b$schedule,b$w,shift);ret[[bi]]<-imom_fast_terminal_from_schedule(b$w,schedule,lev,10,.06,contract);hit<-price$symbol==b$symbol&price$fold==b$fold&price$scenario=="PRIMARY"&price$leverage==lev;bh[[bi]]<-price$buy_hold_return[which(hit)[[1L]]]}
    out[[z]]<-aggregate_sim("HYP-IMOM-02.1",lev,sim,ret,bh);z<-z+1L
  }
  do.call(rbind,out)
}

run_chan_lane<-function(){
  blocks<-list();z<-1L
  for(fi in seq_len(nrow(folds))){f<-folds[fi,]
    for(sym in stocks){x<-bars[bars$symbol==sym,];w<-x[x$session_date>=f$test_start&x$session_date<=f$test_end,];sel<-chan_sel[chan_sel$symbol==sym&chan_sel$fold==f$fold,][1L,];admissible<-isTRUE(sel$admissible);signal<-if(admissible)imom_chan_positive_signal(x,f$test_start,f$test_end,sel$L)else rep(FALSE,nrow(w));blocks[[z]]<-list(symbol=sym,fold=f$fold,w=w,H=sel$H,admissible=admissible,signal=signal,sessions=length(unique(w$session_date)));z<-z+1L}}
  out<-list();z<-1L
  for(lev in contract$leverages)for(sim in seq_len(contract$random_simulations)){
    ret<-bh<-numeric(length(blocks))
    for(bi in seq_along(blocks)){b<-blocks[[bi]];shift<-shift_for(sim,bi,b$sessions);shifted<-if(b$admissible)imom_shift_vector_sessions(b$signal,b$w,shift)else b$signal;ret[[bi]]<-if(b$admissible)imom_chan_fast_terminal_from_signal(b$w,shifted,b$H,lev,10,.06,contract)else 0;hit<-chan$symbol==b$symbol&chan$fold==b$fold&chan$scenario=="PRIMARY"&chan$leverage==lev;bh[[bi]]<-chan$buy_hold_return[which(hit)[[1L]]]}
    out[[z]]<-aggregate_sim("LIT-IMOM-01.1",lev,sim,ret,bh);z<-z+1L
  }
  do.call(rbind,out)
}

checkpoint<-file.path(run_dir,"timing_control_checkpoints");dir.create(checkpoint,recursive=TRUE,showWarnings=FALSE)
jobs<-list(
  list(name="daily",fun=function()run_fixed_lane("DAILY")),
  list(name="m30",fun=function()run_fixed_lane("M30")),
  list(name="price",fun=run_price_lane),list(name="chan",fun=run_chan_lane)
)
for(job in jobs){path<-file.path(checkpoint,paste0(job$name,".rds"));if(file.exists(path)){message(job$name,": CHECKPOINT_HIT");next};message(job$name,": START");result<-job$fun();saveRDS(result,path);rm(result);gc();message(job$name,": COMPLETE")}
controls<-do.call(rbind,lapply(jobs,function(job)readRDS(file.path(checkpoint,paste0(job$name,".rds")))))
write.csv(controls,file.path(run_dir,"timing_control_simulations.csv"),row.names=FALSE)

actual_rows<-list();z<-1L
for(lane in unique(controls$lane))for(lev in contract$leverages){x<-switch(lane,
  "HYP-MOM-06.1"=fixed[fixed$frequency=="DAILY"&fixed$policy=="SMA8_14"&fixed$scenario=="PRIMARY"&fixed$delay_bars==0&fixed$leverage==lev&fixed$symbol%in%stocks,],
  "HYP-IMOM-01.1"=fixed[fixed$frequency=="M30"&fixed$policy=="SMA8_14"&fixed$scenario=="PRIMARY"&fixed$delay_bars==0&fixed$leverage==lev&fixed$symbol%in%stocks,],
  "HYP-IMOM-02.1"=price[price$scenario=="PRIMARY"&price$leverage==lev&price$symbol%in%stocks,],
  "LIT-IMOM-01.1"=chan[chan$scenario=="PRIMARY"&chan$leverage==lev&chan$symbol%in%stocks,])
  null<-controls[controls$lane==lane&controls$leverage==lev,]
  actual_return<-median(x$total_return);actual_excess<-median(x$direct_excess)
  actual_rows[[z]]<-data.frame(lane=lane,leverage=lev,blocks=nrow(x),actual_median_return=actual_return,actual_positive_fraction=mean(x$total_return>0),actual_median_direct_excess=actual_excess,
    null_median_return=median(null$median_return),null_median_direct_excess=median(null$median_direct_excess),return_timing_percentile=(1+sum(null$median_return<=actual_return))/(1+nrow(null)),
    return_upper_tail_p=(1+sum(null$median_return>=actual_return))/(1+nrow(null)),direct_excess_timing_percentile=(1+sum(null$median_direct_excess<=actual_excess))/(1+nrow(null)),stringsAsFactors=FALSE);z<-z+1L}
comparison<-do.call(rbind,actual_rows);write.csv(comparison,file.path(run_dir,"timing_control_comparison.csv"),row.names=FALSE)
writeLines("TIMING_CONTROLS_COMPLETE",file.path(run_dir,"TIMING_STATUS.txt"));print(comparison,row.names=FALSE)
