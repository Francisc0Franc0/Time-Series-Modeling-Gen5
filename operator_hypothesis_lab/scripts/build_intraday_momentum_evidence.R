options(stringsAsFactors=FALSE)
repo<-normalizePath(getwd(),winslash="/",mustWork=TRUE)
local_lib<-file.path(repo,".codex_r_libs");if(dir.exists(local_lib)).libPaths(c(local_lib,.libPaths()))
source(file.path(repo,"operator_hypothesis_lab","R","hyp_intraday_alpaca_30min.R"))
source(file.path(repo,"operator_hypothesis_lab","R","hyp_intraday_momentum_engine.R"))
contract<-imom_contract();registry<-read.csv(file.path(repo,"operator_hypothesis_lab","registries","gen5_intraday_momentum_poc_registry.csv"))
stocks<-registry$symbol[registry$asset_type=="stock"];run_dir<-file.path(repo,"runs","research_workbench","operator_hypothesis_lab","intraday_momentum_poc_series_20260813")
visual_dir<-file.path(run_dir,"visuals");dir.create(visual_dir,recursive=TRUE,showWarnings=FALSE)
fixed<-read.csv(file.path(run_dir,"fixed_sma_summaries.csv"));fixed_trades<-read.csv(file.path(run_dir,"fixed_sma_trades.csv"))
price<-read.csv(file.path(run_dir,"price_sma_oos_summaries.csv"));price_delay<-read.csv(file.path(run_dir,"price_sma_delay_summaries.csv"));price_sel<-read.csv(file.path(run_dir,"price_sma_selections.csv"))
chan<-read.csv(file.path(run_dir,"chan_oos_summaries.csv"));chan_sel<-read.csv(file.path(run_dir,"chan_selections.csv"))
timing<-read.csv(file.path(run_dir,"timing_control_simulations.csv"));timing_comparison<-read.csv(file.path(run_dir,"timing_control_comparison.csv"))
folds<-imom_quarters();safe_median<-function(x){x<-x[is.finite(x)];if(length(x))median(x)else NA_real_}

lane_rows<-list();z<-1L
add_lane<-function(x,lane,leverage){
  y<-x[x$leverage==leverage&x$symbol%in%stocks,]
  data.frame(lane=lane,leverage=leverage,blocks=nrow(y),active_fraction=mean(y$trade_count>0),median_return=safe_median(y$total_return),positive_fraction=mean(y$total_return>0,na.rm=TRUE),
    median_buy_hold=safe_median(y$buy_hold_return),median_direct_excess=safe_median(y$direct_excess),finite_direct_excess_fraction=mean(is.finite(y$direct_excess)),median_sharpe=safe_median(y$sharpe),
    median_drawdown=safe_median(y$maximum_drawdown),median_exposure=safe_median(y$exposure),median_turnover=safe_median(y$turnover),trades=sum(y$trade_count,na.rm=TRUE),
    hit_rate=safe_median(y$hit_rate),median_trade=safe_median(y$median_trade),median_holding_bars=safe_median(y$median_holding_bars),
    median_underwater_fraction=safe_median(y$underwater_fraction),maintenance_breaches=sum(y$maintenance_breach,na.rm=TRUE))
}
for(lev in contract$leverages){lane_rows[[z]]<-add_lane(fixed[fixed$frequency=="DAILY"&fixed$policy=="SMA8_14"&fixed$scenario=="PRIMARY"&fixed$delay_bars==0,],"HYP-MOM-06.1",lev);z<-z+1L
  lane_rows[[z]]<-add_lane(fixed[fixed$frequency=="M30"&fixed$policy=="SMA8_14"&fixed$scenario=="PRIMARY"&fixed$delay_bars==0,],"HYP-IMOM-01.1",lev);z<-z+1L
  lane_rows[[z]]<-add_lane(price[price$scenario=="PRIMARY",],"HYP-IMOM-02.1",lev);z<-z+1L
  lane_rows[[z]]<-add_lane(chan[chan$scenario=="PRIMARY",],"LIT-IMOM-01.1",lev);z<-z+1L}
topline<-do.call(rbind,lane_rows);write.csv(topline,file.path(run_dir,"series_topline.csv"),row.names=FALSE)

sensitivity_rows<-list();z<-1L
for(lane in unique(topline$lane))for(lev in contract$leverages){
  primary<-switch(lane,"HYP-MOM-06.1"=fixed[fixed$frequency=="DAILY"&fixed$policy=="SMA8_14"&fixed$scenario=="PRIMARY"&fixed$delay_bars==0&fixed$leverage==lev&fixed$symbol%in%stocks,],
    "HYP-IMOM-01.1"=fixed[fixed$frequency=="M30"&fixed$policy=="SMA8_14"&fixed$scenario=="PRIMARY"&fixed$delay_bars==0&fixed$leverage==lev&fixed$symbol%in%stocks,],
    "HYP-IMOM-02.1"=price[price$scenario=="PRIMARY"&price$leverage==lev&price$symbol%in%stocks,],"LIT-IMOM-01.1"=chan[chan$scenario=="PRIMARY"&chan$leverage==lev&chan$symbol%in%stocks,])
  stress<-switch(lane,"HYP-MOM-06.1"=fixed[fixed$frequency=="DAILY"&fixed$policy=="SMA8_14"&fixed$scenario=="STRESS"&fixed$delay_bars==0&fixed$leverage==lev&fixed$symbol%in%stocks,],
    "HYP-IMOM-01.1"=fixed[fixed$frequency=="M30"&fixed$policy=="SMA8_14"&fixed$scenario=="STRESS"&fixed$delay_bars==0&fixed$leverage==lev&fixed$symbol%in%stocks,],
    "HYP-IMOM-02.1"=price[price$scenario=="STRESS"&price$leverage==lev&price$symbol%in%stocks,],"LIT-IMOM-01.1"=chan[chan$scenario=="STRESS"&chan$leverage==lev&chan$symbol%in%stocks,])
  delayed<-if(lev!=1)NULL else switch(lane,"HYP-MOM-06.1"=fixed[fixed$frequency=="DAILY"&fixed$policy=="SMA8_14"&fixed$scenario=="PRIMARY_DELAY1"&fixed$symbol%in%stocks,],
    "HYP-IMOM-01.1"=fixed[fixed$frequency=="M30"&fixed$policy=="SMA8_14"&fixed$scenario=="PRIMARY_DELAY1"&fixed$symbol%in%stocks,],
    "HYP-IMOM-02.1"=price_delay[price_delay$symbol%in%stocks,],"LIT-IMOM-01.1"=chan[chan$scenario=="PRIMARY_DELAY1"&chan$symbol%in%stocks,])
  # Chan delay replays are stored only for TRAIN-admitted symbol-folds. Restore
  # the frozen all-cash rows so the delay median has the same denominator as
  # PRIMARY and STRESS; otherwise the sensitivity would silently be active-only.
  if(lane=="LIT-IMOM-01.1"&&!is.null(delayed)){
    delayed<-merge(primary[c("symbol","fold")],delayed[c("symbol","fold","total_return")],by=c("symbol","fold"),all.x=TRUE)
    delayed$total_return[!is.finite(delayed$total_return)]<-0
  }
  sensitivity_rows[[z]]<-data.frame(lane=lane,leverage=lev,primary_median_return=safe_median(primary$total_return),stress_median_return=safe_median(stress$total_return),
    stress_delta=safe_median(stress$total_return)-safe_median(primary$total_return),delay_median_return=if(is.null(delayed))NA_real_ else safe_median(delayed$total_return),
    delay_delta=if(is.null(delayed))NA_real_ else safe_median(delayed$total_return)-safe_median(primary$total_return));z<-z+1L}
sensitivity<-do.call(rbind,sensitivity_rows);write.csv(sensitivity,file.path(run_dir,"series_sensitivity.csv"),row.names=FALSE)

chan_admission<-aggregate(admissible~fold,chan_sel,mean);names(chan_admission)[2]<-"admission_fraction"
chan_admission$admitted_assets<-as.integer(round(chan_admission$admission_fraction*length(unique(chan_sel$symbol))))
write.csv(chan_admission,file.path(run_dir,"chan_admission_by_fold.csv"),row.names=FALSE)
write.csv(as.data.frame(table(L=chan_sel$L[chan_sel$admissible],H=chan_sel$H[chan_sel$admissible])),file.path(run_dir,"chan_selected_horizon_counts.csv"),row.names=FALSE)
chan_active<-chan[chan$scenario=="PRIMARY"&chan$symbol%in%stocks&chan$trade_count>0,]
chan_active_topline<-do.call(rbind,lapply(contract$leverages,function(lev){
  x<-chan_active[chan_active$leverage==lev,]
  data.frame(leverage=lev,active_blocks=nrow(x),median_return=safe_median(x$total_return),positive_fraction=mean(x$total_return>0),
    median_direct_excess=safe_median(x$direct_excess),median_sharpe=safe_median(x$sharpe),median_drawdown=safe_median(x$maximum_drawdown),
    median_exposure=safe_median(x$exposure),hit_rate=safe_median(x$hit_rate),median_trade=safe_median(x$median_trade),median_holding_bars=safe_median(x$median_holding_bars))
}))
write.csv(chan_active_topline,file.path(run_dir,"chan_active_topline.csv"),row.names=FALSE)

# Compact bar surface for diagnostics and tapes.
cache_dir<-file.path(repo,"data_cache","alpaca_intraday_30min");keep<-c("symbol","timestamp_utc","session_date","bar_time_et","bar_slot","open","high","low","close","volume")
bars<-do.call(rbind,lapply(file.path(cache_dir,sprintf("intraday_30min_sip_all_%d.rds",2017:2023)),function(path){x<-readRDS(path);x[,keep,drop=FALSE]}))
bars<-bars[!duplicated(bars[c("symbol","timestamp_utc")]),];bars<-bars[order(bars$symbol,bars$timestamp_utc),];bars<-imom30_apply_rth_calendar(bars);bars<-imom30_apply_archive_exclusions(bars)
daily<-imom_aggregate_daily(bars)

component_block<-function(lane,symbol,label,w,target){
  prior_close<-c(NA,head(w$close,-1));prior_target<-c(0,head(target,-1));new_session<-c(FALSE,as.Date(w$session_date[-1])!=as.Date(head(w$session_date,-1)))
  data.frame(lane=lane,symbol=symbol,block=label,intraday=sum(target*(w$close/w$open-1),na.rm=TRUE),overnight=sum(ifelse(new_session,prior_target*(w$open/prior_close-1),0),na.rm=TRUE),
    early_close_intraday=sum(target*(w$close/w$open-1)*(as.Date(w$session_date)%in%imom30_early_close_dates()),na.rm=TRUE),entries=sum(c(FALSE,diff(target)>0)),stringsAsFactors=FALSE)
}
components<-list();entry_rows<-list();z<-1L;e<-1L
for(sym in stocks)for(year in 2018:2023){x<-bars[bars$symbol==sym,];start<-as.Date(sprintf("%d-01-01",year));end<-min(as.Date(sprintf("%d-12-31",year)),contract$development_end);w<-x[x$session_date>=start&x$session_date<=end,];s<-imom_sma_schedule(x,start,end,8,14);components[[z]]<-component_block("HYP-IMOM-01.1",sym,year,w,as.numeric(s$target));z<-z+1L;idx<-which(s$entry_signal);if(length(idx)){entry_rows[[e]]<-data.frame(lane="HYP-IMOM-01.1",bar_time_et=w$bar_time_et[idx]);e<-e+1L}}
for(fi in seq_len(nrow(folds))){f<-folds[fi,];selp<-price_sel[price_sel$fold==f$fold,][1L,]
  for(sym in stocks){x<-bars[bars$symbol==sym,];w<-x[x$session_date>=f$test_start&x$session_date<=f$test_end,];s<-imom_price_schedule(x,f$test_start,f$test_end,selp$anchor,selp$exit_anchor);components[[z]]<-component_block("HYP-IMOM-02.1",sym,f$fold,w,as.numeric(s$target));z<-z+1L;idx<-which(s$entry_signal);if(length(idx)){entry_rows[[e]]<-data.frame(lane="HYP-IMOM-02.1",bar_time_et=w$bar_time_et[idx]);e<-e+1L}
    selc<-chan_sel[chan_sel$fold==f$fold&chan_sel$symbol==sym,][1L,];if(isTRUE(selc$admissible)){signal<-imom_chan_positive_signal(x,f$test_start,f$test_end,selc$L);target<-imom_chan_target(x,f$test_start,f$test_end,selc$L,selc$H);components[[z]]<-component_block("LIT-IMOM-01.1",sym,f$fold,w,target);z<-z+1L;idx<-which(signal);if(length(idx)){entry_rows[[e]]<-data.frame(lane="LIT-IMOM-01.1",bar_time_et=w$bar_time_et[idx]);e<-e+1L}}else{components[[z]]<-component_block("LIT-IMOM-01.1",sym,f$fold,w,rep(0,nrow(w)));z<-z+1L}}}
components<-do.call(rbind,components);write.csv(components,file.path(run_dir,"intraday_return_components_by_block.csv"),row.names=FALSE)
entry_times<-do.call(rbind,entry_rows);entry_summary<-as.data.frame(prop.table(table(entry_times$lane,entry_times$bar_time_et),1));names(entry_summary)<-c("lane","bar_time_et","entry_fraction");write.csv(entry_summary,file.path(run_dir,"intraday_entry_time_distribution.csv"),row.names=FALSE)

png_open<-function(name){png(file.path(visual_dir,name),width=1800,height=1000,res=160);par(bg="#F7F3EA",fg="#17233B",col.axis="#17233B",col.lab="#17233B",col.main="#17233B",family="sans")}
lane_labels<-c("HYP-MOM-06.1"="Daily SMA 8/14","HYP-IMOM-01.1"="30m SMA 8/14","HYP-IMOM-02.1"="30m price/SMA","LIT-IMOM-01.1"="30m Chan sleeves")
palette<-c("1"="#167D8D","1.8"="#E46A47")

png_open("series_topline.png");par(mar=c(6,11,4,2));ord<-order(topline$lane,topline$leverage);v<-topline$median_return[ord]*100;labs<-paste(lane_labels[topline$lane[ord]],paste0(topline$leverage[ord],"x"));cols<-palette[as.character(topline$leverage[ord])];barplot(v,names.arg=labs,horiz=TRUE,las=1,col=cols,border=NA,xlab="Median block return (%)",main="Frequency—not leverage—dominated the result");abline(v=0,lwd=2,col="#17233B");legend("bottomright",fill=palette,legend=c("1x","1.8x"),bty="n");dev.off()

png_open("fixed_frequency_contrast.png");par(mfrow=c(1,2),mar=c(5,5,4,1));d<-fixed[fixed$policy=="SMA8_14"&fixed$scenario=="PRIMARY"&fixed$delay_bars==0&fixed$leverage==1&fixed$symbol%in%stocks,];boxplot(total_return*100~frequency,data=d,col=c("#167D8D","#E46A47"),border="#17233B",ylab="Annual return (%)",main="Same 8/14 numbers, different clock");abline(h=0,lty=2);daily_d<-d[d$frequency=="DAILY",];plot(daily_d$buy_hold_return*100,daily_d$total_return*100,pch=19,col=adjustcolor("#167D8D",.55),xlab="Buy & hold (%)",ylab="Daily SMA 8/14 (%)",main="Daily rule captured less than full drift");abline(0,1,lty=2,col="#E46A47",lwd=2);abline(h=0,v=0,col="#9AA3AD");dev.off()

png_open("price_selection_oos.png");par(mfrow=c(2,1),mar=c(4,5,3,1));plot(seq_len(nrow(price_sel)),price_sel$anchor,type="b",pch=19,col="#167D8D",xaxt="n",ylab="Selected anchor (bars)",xlab="",main="TRAIN selection moved across a broad tolerance plateau");axis(1,seq_len(nrow(price_sel)),price_sel$fold,las=2,cex.axis=.8);text(seq_len(nrow(price_sel)),price_sel$anchor,labels=ifelse(price_sel$exit_family=="SYMMETRIC","SYM","ASYM"),pos=3,cex=.7);po<-aggregate(cbind(total_return,direct_excess)~fold,price[price$scenario=="PRIMARY"&price$leverage==1&price$symbol%in%stocks,],median);matplot(seq_len(nrow(po)),100*as.matrix(po[,c("total_return","direct_excess")]),type="b",pch=c(19,17),lty=1,col=c("#167D8D","#E46A47"),xaxt="n",ylab="Cross-sectional median (%)",xlab="",main="Selected policies did not stabilize OOS");axis(1,seq_len(nrow(po)),po$fold,las=2,cex.axis=.8);abline(h=0,lty=2);legend("bottomleft",legend=c("Return","Excess vs buy & hold"),col=c("#167D8D","#E46A47"),pch=c(19,17),bty="n");dev.off()

png_open("chan_admission_oos.png");par(mfrow=c(1,2),mar=c(6,5,4,1));barplot(chan_admission$admission_fraction*100,names.arg=chan_admission$fold,las=2,col="#167D8D",border=NA,ylab="Assets admitted (%)",main="TRAIN gate admission was unstable");ca<-chan[chan$scenario=="PRIMARY"&chan$leverage==1&chan$symbol%in%stocks,];boxplot(total_return*100~fold,data=ca,las=2,col="#E6D5B8",border="#17233B",ylab="OOS return (%)",xlab="",main="Cash assignments dominate many quarters");abline(h=0,lty=2);dev.off()

png_open("timing_nulls.png");par(mfrow=c(2,2),mar=c(4,4,3,1));for(lane in names(lane_labels)){n<-timing[timing$lane==lane&timing$leverage==1,];a<-timing_comparison$actual_median_return[timing_comparison$lane==lane&timing_comparison$leverage==1];hist(n$median_return*100,breaks=18,col="#D8E7E8",border="white",main=lane_labels[[lane]],xlab="Shifted panel median return (%)");abline(v=a*100,col="#E46A47",lwd=3);legend("topright",legend="Actual",lwd=3,col="#E46A47",bty="n")};dev.off()

png_open("sensitivity_summary.png");par(mfrow=c(1,2),mar=c(7,5,4,1));s1<-sensitivity[sensitivity$leverage==1,];mat<-100*t(as.matrix(s1[,c("primary_median_return","stress_median_return","delay_median_return")]));barplot(mat,beside=TRUE,names.arg=lane_labels[s1$lane],las=2,col=c("#167D8D","#E46A47","#D3A73A"),border=NA,ylab="Median return (%)",main="Costs and one-bar delay");abline(h=0);legend("topright",fill=c("#167D8D","#E46A47","#D3A73A"),legend=c("Primary","Stress","Delay +1"),bty="n",cex=.8);cmed<-aggregate(cbind(intraday,overnight)~lane,components,median);m30<-cmed[cmed$lane=="HYP-IMOM-01.1",];barplot(100*unlist(m30[c("intraday","overnight")]),names.arg=c("Open→close","Overnight gap"),col=c("#167D8D","#D3A73A"),border=NA,ylab="Median gross component / year (%)",main="30m drift existed before turnover costs");abline(h=0);mtext("Positive raw components did not survive the frozen 10 bp/side cost model",side=3,line=.2,cex=.75,col="#5A6470");dev.off()

shade_positions<-function(w,target){r<-rle(target>0);ends<-cumsum(r$lengths);starts<-c(1,head(ends,-1)+1);for(i in which(r$values))rect(w$timestamp_utc[starts[i]],par("usr")[3],w$timestamp_utc[ends[i]],par("usr")[4],col=adjustcolor("#67B7A5",.18),border=NA)}
plot_binary_tape<-function(x,start,end,schedule,title){w<-x[x$session_date>=start&x$session_date<=end,];yr<-range(c(w$close,schedule$fast,schedule$slow),na.rm=TRUE);plot(w$timestamp_utc,w$close,type="n",ylim=yr,xlab="",ylab="Price",main=title);shade_positions(w,schedule$target);lines(w$timestamp_utc,w$close,col="#17233B",lwd=1);lines(w$timestamp_utc,schedule$fast,col="#E46A47",lwd=1);lines(w$timestamp_utc,schedule$slow,col="#167D8D",lwd=2)}
fm<-fixed[fixed$frequency=="M30"&fixed$policy=="SMA8_14"&fixed$scenario=="PRIMARY"&fixed$delay_bars==0&fixed$leverage==1&fixed$symbol%in%stocks,]
pick<-rbind(fm[which.max(fm$total_return),],fm[which.min(fm$total_return),],fm[which.max(fm$trade_count),],fm[which.max(fm$median_holding_bars),],fm[which.max(ifelse(fm$symbol=="AMD",fm$total_return,-Inf)),],fm[which.max(ifelse(fm$symbol=="TSLA",fm$total_return,-Inf)),]);pick$case<-c("Winner","Loser","Whipsaw","Extended hold","AMD audit","TSLA audit")
png_open("fixed_m30_trade_tapes.png");par(mfrow=c(3,2),mar=c(3,4,3,1));fixed_tape_trades<-list();for(i in seq_len(nrow(pick))){x<-bars[bars$symbol==pick$symbol[[i]],];start<-as.Date(sprintf("%d-01-01",pick$year[[i]]));end<-min(as.Date(sprintf("%d-12-31",pick$year[[i]])),contract$development_end);s<-imom_sma_schedule(x,start,end,8,14);plot_binary_tape(x,start,end,s,paste(pick$case[[i]],pick$symbol[[i]],pick$year[[i]],sprintf("%+.1f%%",100*pick$total_return[[i]])));o<-imom_replay(x,start,end,s,1,10,.06);if(nrow(o$trades)){t<-o$trades;t$case<-pick$case[[i]];fixed_tape_trades[[i]]<-t}};dev.off();write.csv(do.call(rbind,fixed_tape_trades),file.path(run_dir,"fixed_representative_trade_tapes.csv"),row.names=FALSE)

pp<-price[price$scenario=="PRIMARY"&price$leverage==1&price$symbol%in%stocks,];pickp<-rbind(pp[which.max(pp$total_return),],pp[which.min(pp$total_return),],pp[which.max(ifelse(pp$symbol=="AMD",pp$total_return,-Inf)),],pp[which.max(ifelse(pp$symbol=="TSLA",pp$total_return,-Inf)),]);pickp$case<-c("Winner","Loser","AMD audit","TSLA audit")
png_open("price_sma_trade_tapes.png");par(mfrow=c(2,2),mar=c(3,4,3,1));price_tape_trades<-list();for(i in seq_len(nrow(pickp))){f<-folds[folds$fold==pickp$fold[[i]],][1L,];sel<-price_sel[price_sel$fold==pickp$fold[[i]],][1L,];x<-bars[bars$symbol==pickp$symbol[[i]],];s<-imom_price_schedule(x,f$test_start,f$test_end,sel$anchor,sel$exit_anchor);plot_binary_tape(x,f$test_start,f$test_end,s,paste(pickp$case[[i]],pickp$symbol[[i]],pickp$fold[[i]],sprintf("%+.1f%%",100*pickp$total_return[[i]])));o<-imom_replay(x,f$test_start,f$test_end,s,1,10,.06);if(nrow(o$trades)){t<-o$trades;t$case<-pickp$case[[i]];t$fold<-pickp$fold[[i]];price_tape_trades[[i]]<-t}};dev.off();if(length(price_tape_trades))write.csv(do.call(rbind,price_tape_trades),file.path(run_dir,"price_representative_trade_tapes.csv"),row.names=FALSE)

active_chan<-chan[chan$scenario=="PRIMARY"&chan$leverage==1&chan$symbol%in%stocks&chan$trade_count>0,];pickc<-rbind(active_chan[which.max(active_chan$total_return),],active_chan[which.min(active_chan$total_return),],active_chan[which.max(ifelse(active_chan$symbol=="AMD",active_chan$total_return,-Inf)),],active_chan[which.max(ifelse(active_chan$symbol=="TSLA",active_chan$total_return,-Inf)),]);pickc$case<-c("Winner","Loser","AMD audit","TSLA audit")
png_open("chan_trade_tapes.png");par(mfrow=c(2,2),mar=c(3,4,3,1));chan_tape_trades<-list();for(i in seq_len(nrow(pickc))){f<-folds[folds$fold==pickc$fold[[i]],][1L,];x<-bars[bars$symbol==pickc$symbol[[i]],];w<-x[x$session_date>=f$test_start&x$session_date<=f$test_end,];target<-imom_chan_target(x,f$test_start,f$test_end,pickc$L[[i]],pickc$H[[i]]);yr<-range(w$close);plot(w$timestamp_utc,w$close,type="l",col="#17233B",xlab="",ylab="Price",main=paste(pickc$case[[i]],pickc$symbol[[i]],pickc$fold[[i]],paste0("L",pickc$L[[i]],"/H",pickc$H[[i]]),sprintf("%+.1f%%",100*pickc$total_return[[i]])));lines(w$timestamp_utc,yr[1]+target*diff(yr),col="#E46A47",lwd=2);legend("topleft",legend=c("Price","Sleeve exposure (scaled)"),col=c("#17233B","#E46A47"),lty=1,lwd=c(1,2),bty="n",cex=.65);o<-imom_chan_sleeve_replay(x,f$test_start,f$test_end,pickc$L[[i]],pickc$H[[i]],1,10,.06);if(nrow(o$trades)){t<-o$trades;t$case<-pickc$case[[i]];t$fold<-pickc$fold[[i]];chan_tape_trades[[i]]<-t}};dev.off();if(length(chan_tape_trades))write.csv(do.call(rbind,chan_tape_trades),file.path(run_dir,"chan_representative_trade_tapes.csv"),row.names=FALSE)

# Data-admission visual includes the corrected early-close interpretation and final exclusions.
gap_session<-read.csv(file.path(repo,"runs","research_workbench","operator_hypothesis_lab","intraday_momentum_feed_comparison_20260813","sip_iex_session_comparison.csv"))
yahoo<-read.csv(file.path(repo,"runs","research_workbench","operator_hypothesis_lab","intraday_momentum_feed_comparison_20260813","yahoo_30min_gap_probe.csv"))
png_open("data_admission.png");par(mfrow=c(1,2),mar=c(5,5,4,1));barplot(c(26,26,0),names.arg=c("Frozen\nuniverse","SIP after\n10 exclusions","IEX fills of\nSIP gaps"),col=c("#17233B","#167D8D","#E46A47"),border=NA,ylab="Assets / filled bars",main="Admission preserved the full atlas");barplot(c(10,sum(yahoo$returned_bars)),names.arg=c("Globally excluded\nsessions","Yahoo 30m\nreplacement bars"),col=c("#D3A73A","#E46A47"),border=NA,ylab="Count",main="No bars were synthesized");dev.off()

writeLines(c("EVIDENCE_COMPLETE_REGIME_DISCUSSION_REQUIRED",paste("visuals",length(list.files(visual_dir,pattern="\\.png$")))),file.path(run_dir,"EVIDENCE_STATUS.txt"))
print(topline,row.names=FALSE)
