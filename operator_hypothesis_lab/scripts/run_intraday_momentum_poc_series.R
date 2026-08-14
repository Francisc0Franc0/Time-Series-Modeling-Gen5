options(stringsAsFactors=FALSE)
repo<-normalizePath(getwd(),winslash="/",mustWork=TRUE); local_lib<-file.path(repo,".codex_r_libs");if(dir.exists(local_lib)).libPaths(c(local_lib,.libPaths()))
source(file.path(repo,"operator_hypothesis_lab","R","hyp_intraday_alpaca_30min.R"))
source(file.path(repo,"operator_hypothesis_lab","R","hyp_intraday_momentum_engine.R"))
contract<-imom_contract(); registry<-read.csv(file.path(repo,"operator_hypothesis_lab","registries","gen5_intraday_momentum_poc_registry.csv"))
cache_dir<-file.path(repo,"data_cache","alpaca_intraday_30min"); run_dir<-file.path(repo,"runs","research_workbench","operator_hypothesis_lab","intraday_momentum_poc_series_20260813")
visual_dir<-file.path(run_dir,"visuals");dir.create(visual_dir,recursive=TRUE,showWarnings=FALSE)
paths<-file.path(cache_dir,sprintf("intraday_30min_sip_all_%d.rds",2017:2023));if(!all(file.exists(paths)))stop("All 2017-2023 intraday cache years are required.")
bars<-do.call(rbind,lapply(paths,readRDS));bars<-bars[!duplicated(bars[c("symbol","timestamp_utc")]),];bars<-bars[order(bars$symbol,bars$timestamp_utc),];bars<-imom30_apply_rth_calendar(bars);bars<-imom30_apply_archive_exclusions(bars)
audit<-imom30_audit(bars,registry,contract$development_start,contract$development_end,520L)
if(!all(audit$integrity$passed))stop("Intraday integrity failed.")
eligible<-audit$coverage$symbol[audit$coverage$analysis_eligible]; stocks<-intersect(registry$symbol[registry$asset_type=="stock"],eligible)
if(!all(c("AMD","TSLA","SPY")%in%eligible)||length(stocks)<20L)stop("Frozen admission gate failed.")
bars<-bars[bars$symbol%in%eligible,];daily<-imom_aggregate_daily(bars)
write.csv(audit$coverage,file.path(run_dir,"intraday_data_coverage.csv"),row.names=FALSE);write.csv(audit$sessions,file.path(run_dir,"intraday_session_audit.csv"),row.names=FALSE);write.csv(audit$integrity,file.path(run_dir,"intraday_data_integrity.csv"),row.names=FALSE)

scenario_table<-data.frame(scenario=c("GROSS","PRIMARY","STRESS"),daily_bps=c(0,5,10),m30_bps=c(0,10,20),financing=c(0,.06,.10))
years<-2018:2023; fixed_sum<-list();fixed_trades<-list();fixed_paths<-list();z<-1L
for(freq in c("DAILY","M30")) for(sym in eligible) for(year in years) {
  x<-if(freq=="DAILY")daily[daily$symbol==sym,]else bars[bars$symbol==sym,]; start<-as.Date(sprintf("%d-01-01",year));end<-as.Date(sprintf("%d-12-31",year));end<-min(end,contract$development_end)
  if(!any(x$session_date>=start&x$session_date<=end))next
  schedules<-list(SMA8_14=imom_sma_schedule(x,start,end,8,14,0),BUY_HOLD=imom_buy_hold_schedule(x,start,end))
  for(policy in names(schedules)) for(lev in contract$leverages) for(si in seq_len(nrow(scenario_table))) {
    s<-scenario_table[si,];out<-imom_replay(x,start,end,schedules[[policy]],lev,if(freq=="DAILY")s$daily_bps else s$m30_bps,s$financing,s$scenario,if(freq=="DAILY")252L else 3276L,contract)
    q<-out$summary;q$frequency<-freq;q$policy<-policy;q$year<-year;q$delay_bars<-0L;fixed_sum[[z]]<-q
    if(policy=="SMA8_14"&&s$scenario=="PRIMARY") { if(nrow(out$trades)){t<-out$trades;t$frequency<-freq;t$year<-year;t$leverage<-lev;fixed_trades[[length(fixed_trades)+1L]]<-t};if(sym%in%c("AMD","TSLA")&&lev%in%c(1,1.8))fixed_paths[[paste(freq,sym,year,lev,sep="_")]]<-out$path }
    z<-z+1L
  }
  delayed<-imom_sma_schedule(x,start,end,8,14,1);out<-imom_replay(x,start,end,delayed,1,if(freq=="DAILY")5 else 10,.06,"PRIMARY_DELAY1",if(freq=="DAILY")252L else 3276L,contract);q<-out$summary;q$frequency<-freq;q$policy<-"SMA8_14";q$year<-year;q$delay_bars<-1L;fixed_sum[[z]]<-q;z<-z+1L
}
fixed_sum<-do.call(rbind,fixed_sum);fixed_trades<-do.call(rbind,fixed_trades)
fixed_bh<-fixed_sum[fixed_sum$scenario=="PRIMARY"&fixed_sum$policy=="BUY_HOLD"&fixed_sum$delay_bars==0,
  c("symbol","leverage","frequency","year","total_return")]
names(fixed_bh)[names(fixed_bh)=="total_return"]<-"buy_hold_return"
fixed_sum<-merge(fixed_sum,fixed_bh,by=c("symbol","leverage","frequency","year"),all.x=TRUE)
fixed_sum$direct_excess<-fixed_sum$total_return-fixed_sum$buy_hold_return
write.csv(fixed_sum,file.path(run_dir,"fixed_sma_summaries.csv"),row.names=FALSE);write.csv(fixed_trades,file.path(run_dir,"fixed_sma_trades.csv"),row.names=FALSE)

# Price/SMA candidate metrics are computed once per full TRAIN year, then reused causally.
candidates<-do.call(rbind,lapply(contract$price_anchors,function(a)data.frame(candidate_id=c(sprintf("S%03d_SYM",a),sprintf("S%03d_ASYM",a)),anchor=a,exit_anchor=c(a,round(a/4)),exit_family=c("SYMMETRIC","QUARTER_ANCHOR"))))
price_train<-list();z<-1L
for(year in years)for(ci in seq_len(nrow(candidates)))for(sym in stocks){x<-bars[bars$symbol==sym,];start<-as.Date(sprintf("%d-01-01",year));end<-min(as.Date(sprintf("%d-12-31",year)),contract$development_end);sch<-imom_price_schedule(x,start,end,candidates$anchor[[ci]],candidates$exit_anchor[[ci]]);out<-imom_replay(x,start,end,sch,1,10,.06,"PRIMARY",3276L,contract);q<-out$summary;q$year<-year;q$candidate_id<-candidates$candidate_id[[ci]];price_train[[z]]<-q;z<-z+1L}
price_train<-do.call(rbind,price_train)
m30_bh_1x<-fixed_bh[fixed_bh$frequency=="M30"&fixed_bh$leverage==1,c("symbol","year","buy_hold_return")]
price_train<-merge(price_train,m30_bh_1x,by=c("symbol","year"),all.x=TRUE)
price_train$direct_excess<-price_train$total_return-price_train$buy_hold_return
write.csv(price_train,file.path(run_dir,"price_sma_candidate_asset_year.csv"),row.names=FALSE)
folds<-imom_quarters();quarter_bh<-list();qb<-1L
for(fi in seq_len(nrow(folds)))for(sym in eligible)for(lev in contract$leverages)for(si in seq_len(nrow(scenario_table))){f<-folds[fi,];s<-scenario_table[si,];x<-bars[bars$symbol==sym,];out<-imom_replay(x,f$test_start,f$test_end,imom_buy_hold_schedule(x,f$test_start,f$test_end),lev,s$m30_bps,s$financing,s$scenario,3276L,contract);q<-out$summary;q$fold<-f$fold;quarter_bh[[qb]]<-q;qb<-qb+1L}
quarter_bh<-do.call(rbind,quarter_bh);write.csv(quarter_bh,file.path(run_dir,"quarterly_buy_hold_summaries.csv"),row.names=FALSE)
price_sel<-list();price_oos<-list();price_paths<-list();z<-1L
for(fi in seq_len(nrow(folds))){f<-folds[fi,];train_years<-years[as.Date(sprintf("%d-12-31",years))<=f$train_end];year_scores<-list()
  for(y in train_years){m<-price_train[price_train$year==y,];agg<-do.call(rbind,lapply(split(m,m$candidate_id),function(v)data.frame(candidate_id=v$candidate_id[[1]],ret=median(v$total_return),breadth=mean(v$total_return>0),sharpe=median(v$sharpe,na.rm=TRUE),dd=median(v$maximum_drawdown),trades=median(v$trade_count),excess=median(v$direct_excess,na.rm=TRUE))))
    agg$score<-(imom_fractional_rank(agg$ret)+imom_fractional_rank(agg$breadth)+imom_fractional_rank(agg$sharpe)+imom_fractional_rank(agg$dd)+imom_fractional_rank(agg$excess))/5;agg$year<-y;year_scores[[as.character(y)]]<-agg }
  ys<-do.call(rbind,year_scores);cand<-do.call(rbind,lapply(split(ys,ys$candidate_id),function(v)data.frame(candidate_id=v$candidate_id[[1]],mean_score=mean(v$score),se=if(nrow(v)>1)sd(v$score)/sqrt(nrow(v))else 0,median_trades=median(v$trades))))
  best<-cand[which.max(cand$mean_score),];tol<-best$mean_score-best$se;pool<-merge(cand[cand$mean_score>=tol,],candidates,by="candidate_id");pool$exit_pref<-ifelse(pool$exit_family=="SYMMETRIC",0L,1L);pool<-pool[order(pool$median_trades,-pool$anchor,pool$exit_pref),];selected<-pool[1,];selected$fold<-f$fold;selected$train_end<-f$train_end;selected$plateau_size<-nrow(pool);price_sel[[fi]]<-selected
  for(sym in stocks){x<-bars[bars$symbol==sym,];sch<-imom_price_schedule(x,f$test_start,f$test_end,selected$anchor,selected$exit_anchor);for(lev in contract$leverages)for(si in seq_len(nrow(scenario_table))){s<-scenario_table[si,];out<-imom_replay(x,f$test_start,f$test_end,sch,lev,s$m30_bps,s$financing,s$scenario,3276L,contract);q<-out$summary;q$fold<-f$fold;q$candidate_id<-selected$candidate_id;price_oos[[z]]<-q;z<-z+1L;if(sym%in%c("AMD","TSLA")&&s$scenario=="PRIMARY")price_paths[[paste(f$fold,sym,lev,sep="_")]]<-out$path}}
}
price_sel<-do.call(rbind,price_sel);price_oos<-do.call(rbind,price_oos)
qb_key<-quarter_bh[,c("symbol","fold","leverage","scenario","total_return")];names(qb_key)[5]<-"buy_hold_return"
price_oos<-merge(price_oos,qb_key,by=c("symbol","fold","leverage","scenario"),all.x=TRUE);price_oos$direct_excess<-price_oos$total_return-price_oos$buy_hold_return
write.csv(price_sel,file.path(run_dir,"price_sma_selections.csv"),row.names=FALSE);write.csv(price_oos,file.path(run_dir,"price_sma_oos_summaries.csv"),row.names=FALSE)

# Chan selection is per asset, exactly as the original literature exercise.
chan_sel<-list();chan_oos<-list();chan_paths<-list();z<-1L
for(fi in seq_len(nrow(folds))){f<-folds[fi,];for(sym in c(stocks,"SPY","QQQ")){x<-bars[bars$symbol==sym,];screen<-imom_chan_screen(x,f$train_start,f$train_end,contract);sel<-imom_chan_select(screen);sel$symbol<-sym;sel$fold<-f$fold;sel$train_end<-f$train_end;chan_sel[[length(chan_sel)+1L]]<-sel;if(!isTRUE(sel$admissible)){for(lev in contract$leverages)for(si in seq_len(nrow(scenario_table))){s<-scenario_table[si,];nblock<-sum(x$session_date>=f$test_start&x$session_date<=f$test_end);chan_oos[[z]]<-data.frame(symbol=sym,L=NA_integer_,H=NA_integer_,leverage=lev,scenario=s$scenario,total_return=0,sharpe=NA_real_,maximum_drawdown=0,exposure=0,trade_count=0,hit_rate=NA_real_,median_trade=NA_real_,mean_trade=NA_real_,median_holding_bars=NA_real_,financing_paid=0,turnover=0,underwater_fraction=0,maximum_underwater_bars=0,minimum_equity=contract$initial_wealth,minimum_equity_ratio=1,maintenance_breach=FALSE,fold=f$fold);z<-z+1L};next}
    for(lev in contract$leverages)for(si in seq_len(nrow(scenario_table))){s<-scenario_table[si,];out<-imom_chan_sleeve_replay(x,f$test_start,f$test_end,sel$L,sel$H,lev,s$m30_bps,s$financing,0,s$scenario,contract);q<-out$summary;q$fold<-f$fold;chan_oos[[z]]<-q;z<-z+1L;if(sym%in%c("AMD","TSLA")&&s$scenario=="PRIMARY")chan_paths[[paste(f$fold,sym,lev,sep="_")]]<-out$path}
    out<-imom_chan_sleeve_replay(x,f$test_start,f$test_end,sel$L,sel$H,1,10,.06,1,"PRIMARY_DELAY1",contract);q<-out$summary;q$fold<-f$fold;chan_oos[[z]]<-q;z<-z+1L
  }}
chan_sel<-do.call(rbind,chan_sel);chan_oos<-if(length(chan_oos))do.call(rbind,chan_oos)else data.frame()
chan_oos<-merge(chan_oos,qb_key,by=c("symbol","fold","leverage","scenario"),all.x=TRUE);chan_oos$direct_excess<-chan_oos$total_return-chan_oos$buy_hold_return
write.csv(chan_sel,file.path(run_dir,"chan_selections.csv"),row.names=FALSE);write.csv(chan_oos,file.path(run_dir,"chan_oos_summaries.csv"),row.names=FALSE)

saveRDS(list(fixed=fixed_paths,price=price_paths,chan=chan_paths),file.path(run_dir,"canonical_paths.rds"))
write.csv(registry,file.path(run_dir,"registry.csv"),row.names=FALSE);write.csv(folds,file.path(run_dir,"outer_folds.csv"),row.names=FALSE)

summarize_lane<-function(x,lane){if(!nrow(x))return(data.frame());p<-x[x$scenario=="PRIMARY"&x$leverage%in%c(1,1.8),];do.call(rbind,lapply(split(p,p$leverage),function(v)data.frame(lane=lane,leverage=unique(v$leverage),observations=nrow(v),median_return=median(v$total_return),positive_fraction=mean(v$total_return>0),median_sharpe=median(v$sharpe,na.rm=TRUE),median_drawdown=median(v$maximum_drawdown),median_exposure=median(v$exposure),trades=sum(v$trade_count))))}
fixed_lane<-fixed_sum[fixed_sum$frequency=="M30"&fixed_sum$policy=="SMA8_14"&fixed_sum$delay_bars==0,];daily_lane<-fixed_sum[fixed_sum$frequency=="DAILY"&fixed_sum$policy=="SMA8_14"&fixed_sum$delay_bars==0,]
topline<-rbind(summarize_lane(daily_lane,"HYP-MOM-06.1"),summarize_lane(fixed_lane,"HYP-IMOM-01.1"),summarize_lane(price_oos,"HYP-IMOM-02.1"),summarize_lane(chan_oos,"LIT-IMOM-01.1"));write.csv(topline,file.path(run_dir,"series_topline.csv"),row.names=FALSE)
writeLines(c("POC_SERIES_COMPLETE_REGIME_DISCUSSION_REQUIRED",paste("eligible",length(eligible),"stocks",length(stocks))),file.path(run_dir,"STATUS.txt"))
message("POC_SERIES_COMPLETE_REGIME_DISCUSSION_REQUIRED");print(topline,row.names=FALSE)
