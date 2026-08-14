imom_stop <- function(message) stop(paste0("[INTRADAY-MOMENTUM] ", message), call. = FALSE)

imom_contract <- function() list(
  as_of_timestamp="2026-08-13 17:30:00 America/New_York",
  query_start=as.Date("2017-09-01"), development_start=as.Date("2018-01-02"),
  train_end=as.Date("2020-12-31"), development_end=as.Date("2023-12-29"),
  confirmation_start=as.Date("2024-01-02"), leverages=c(1,1.8),
  daily_primary_bps=5, daily_stress_bps=10, intraday_primary_bps=10,
  intraday_stress_bps=20, primary_financing=0.06, stress_financing=0.10,
  maintenance_ratio=0.25, initial_wealth=100000,
  price_anchors=c(65L,130L,260L,520L), chan_L=c(13L,26L,65L,130L,260L),
  chan_H=c(13L,26L,65L), chan_min_pairs=40L, chan_p_max=0.10,
  random_simulations=200L, random_seed=81430L
)

imom_sma <- function(x,n) {
  n <- as.integer(n); out <- rep(NA_real_,length(x))
  if(length(x)>=n) out[n:length(x)] <- stats::filter(x,rep(1/n,n),sides=1)[n:length(x)]
  out
}

imom_max_drawdown <- function(wealth) min(wealth/cummax(wealth)-1,na.rm=TRUE)
imom_underwater <- function(wealth) {
  underwater <- wealth < cummax(wealth)
  runs <- rle(underwater)
  list(fraction=mean(underwater,na.rm=TRUE),
       maximum_bars=if(any(runs$values))max(runs$lengths[runs$values])else 0L)
}
imom_sharpe <- function(wealth,periods) {
  r <- wealth[-1L]/head(wealth,-1L)-1; r <- r[is.finite(r)]
  if(length(r)<2L || stats::sd(r)==0) return(NA_real_)
  sqrt(periods)*mean(r)/stats::sd(r)
}

imom_aggregate_daily <- function(bars) {
  required <- c("symbol","session_date","timestamp_utc","open","high","low","close","volume")
  if(!all(required %in% names(bars))) imom_stop("M30 schema is incomplete.")
  x <- bars[order(bars$symbol,bars$timestamp_utc),,drop=FALSE]
  groups <- split(seq_len(nrow(x)),interaction(x$symbol,x$session_date,drop=TRUE))
  rows <- lapply(groups,function(idx){ y<-x[idx,,drop=FALSE]; data.frame(
    symbol=y$symbol[[1L]], timestamp_utc=min(y$timestamp_utc), session_date=as.Date(y$session_date[[1L]]),
    bar_time_et="DAILY",bar_slot=1L,open=y$open[[1L]],high=max(y$high),low=min(y$low),
    close=tail(y$close,1),volume=sum(y$volume),stringsAsFactors=FALSE) })
  out<-do.call(rbind,rows); out[order(out$symbol,out$session_date),,drop=FALSE]
}

imom_validate_bars <- function(bars,contract=imom_contract()) {
  required<-c("symbol","timestamp_utc","session_date","open","high","low","close","volume")
  if(!is.data.frame(bars)||!all(required%in%names(bars))) imom_stop("Bar schema is incomplete.")
  x<-bars[order(bars$timestamp_utc),,drop=FALSE]; x$session_date<-as.Date(x$session_date)
  if(anyDuplicated(x$timestamp_utc)||any(x$session_date>=contract$confirmation_start)) imom_stop("Duplicate or confirmation bars detected.")
  if(any(!is.finite(x$open)|x$open<=0|!is.finite(x$close)|x$close<=0)) imom_stop("Invalid prices.")
  x
}

imom_sma_schedule <- function(bars,start,end,fast=8L,slow=14L,delay_bars=0L) {
  x<-bars; x$fast<-imom_sma(x$close,fast); x$slow<-imom_sma(x$close,slow)
  above<-!is.na(x$slow)&x$fast>x$slow
  cross_up<-above&c(FALSE,!head(above,-1)); cross_down<-!above&c(FALSE,head(above,-1))
  in_block<-x$session_date>=as.Date(start)&x$session_date<=as.Date(end)
  target<-rep(FALSE,nrow(x)); held<-FALSE
  for(i in seq_len(nrow(x))) {
    if(!in_block[[i]]) next
    signal_i<-i-1L-as.integer(delay_bars)
    if(signal_i>=1L) {
      if(!held&&cross_up[[signal_i]]&&x$session_date[[signal_i]]>=as.Date(start)) held<-TRUE
      if(held&&cross_down[[signal_i]]) held<-FALSE
    }
    target[[i]]<-held
  }
  idx<-which(in_block)
  data.frame(target=target[idx],entry_signal=c(FALSE,diff(as.integer(target[idx]))==1),
    exit_signal=c(FALSE,diff(as.integer(target[idx]))==-1),fast=x$fast[idx],slow=x$slow[idx])
}

imom_price_schedule <- function(bars,start,end,anchor,exit_anchor=anchor,delay_bars=0L) {
  x<-bars; x$entry_sma<-imom_sma(x$close,anchor); x$exit_sma<-imom_sma(x$close,exit_anchor)
  above_entry<-!is.na(x$entry_sma)&x$close>x$entry_sma
  cross_up<-above_entry&c(FALSE,!head(above_entry,-1))
  below_exit<-!is.na(x$exit_sma)&x$close<=x$exit_sma
  in_block<-x$session_date>=as.Date(start)&x$session_date<=as.Date(end)
  target<-rep(FALSE,nrow(x)); held<-FALSE
  for(i in seq_len(nrow(x))) {
    if(!in_block[[i]]) next
    s<-i-1L-as.integer(delay_bars)
    if(s>=1L) {
      if(!held&&cross_up[[s]]&&x$session_date[[s]]>=as.Date(start)) held<-TRUE
      else if(held&&below_exit[[s]]) held<-FALSE
    }
    target[[i]]<-held
  }
  idx<-which(in_block)
  data.frame(target=target[idx],entry_signal=c(FALSE,diff(as.integer(target[idx]))==1),
    exit_signal=c(FALSE,diff(as.integer(target[idx]))==-1),fast=x$close[idx],slow=x$entry_sma[idx])
}

imom_replay <- function(bars,start,end,schedule,leverage=1,cost_bps=10,financing=0.06,
                        scenario="PRIMARY",periods=3276L,contract=imom_contract()) {
  w<-bars[bars$session_date>=as.Date(start)&bars$session_date<=as.Date(end),,drop=FALSE]
  if(nrow(w)!=nrow(schedule)) imom_stop("Schedule length mismatch.")
  cash<-contract$initial_wealth; shares<-0; debt<-0; equity<-gross_notional<-equity_ratio<-numeric(nrow(w)); financing_paid<-0;turnover_notional<-0
  entry_equity<-NA_real_; entry_i<-NA_integer_; trades<-list(); z<-1L; cost<-cost_bps/10000
  for(i in seq_len(nrow(w))) {
    if(i>1L&&shares>0&&debt>0) {
      days<-as.numeric(difftime(w$timestamp_utc[[i]],w$timestamp_utc[[i-1L]],units="days"))
      charge<-debt*((1+financing)^(days/365.25)-1); debt<-debt+charge; financing_paid<-financing_paid+charge
    }
    desired<-isTRUE(schedule$target[[i]])
    if(shares>0&&!desired) {
      turnover_notional<-turnover_notional+shares*w$open[[i]]
      proceeds<-shares*w$open[[i]]*(1-cost); cash<-proceeds-debt
      trades[[z]]<-data.frame(symbol=w$symbol[[i]],entry_timestamp=w$timestamp_utc[[entry_i]],exit_timestamp=w$timestamp_utc[[i]],
        entry_date=w$session_date[[entry_i]],exit_date=w$session_date[[i]],holding_bars=i-entry_i,
        net_return=cash/entry_equity-1,entry_bar_time=if("bar_time_et"%in%names(w))w$bar_time_et[[entry_i]] else "DAILY",stringsAsFactors=FALSE)
      z<-z+1L; shares<-0; debt<-0
    }
    if(shares==0&&desired) {
      entry_equity<-cash; entry_i<-i; notional<-leverage*cash; debt<-(leverage-1)*cash
      shares<-notional*(1-cost)/w$open[[i]]; cash<-0
      turnover_notional<-turnover_notional+notional
    }
    if(i==nrow(w)&&shares>0) {
      turnover_notional<-turnover_notional+shares*w$close[[i]]
      proceeds<-shares*w$close[[i]]*(1-cost); cash<-proceeds-debt
      trades[[z]]<-data.frame(symbol=w$symbol[[i]],entry_timestamp=w$timestamp_utc[[entry_i]],exit_timestamp=w$timestamp_utc[[i]],
        entry_date=w$session_date[[entry_i]],exit_date=w$session_date[[i]],holding_bars=i-entry_i,
        net_return=cash/entry_equity-1,entry_bar_time=if("bar_time_et"%in%names(w))w$bar_time_et[[entry_i]] else "DAILY",stringsAsFactors=FALSE)
      z<-z+1L;shares<-0;debt<-0
    }
    equity[[i]]<-if(shares>0) shares*w$close[[i]]-debt else cash
    gross_notional[[i]]<-if(shares>0)shares*w$close[[i]]else 0
    equity_ratio[[i]]<-if(gross_notional[[i]]>0)equity[[i]]/gross_notional[[i]]else Inf
    if(!is.finite(equity[[i]])||equity[[i]]<=0) equity[[i]]<-NA_real_
  }
  path<-data.frame(symbol=w$symbol,timestamp_utc=w$timestamp_utc,session_date=w$session_date,
    bar_time_et=if("bar_time_et"%in%names(w))w$bar_time_et else "DAILY",open=w$open,close=w$close,
    target=schedule$target,equity=equity,gross_notional=gross_notional,equity_ratio=equity_ratio,
    leverage=leverage,scenario=scenario,stringsAsFactors=FALSE)
  t<-if(length(trades))do.call(rbind,trades)else data.frame(symbol=character(),entry_timestamp=as.POSIXct(character()),exit_timestamp=as.POSIXct(character()),entry_date=as.Date(character()),exit_date=as.Date(character()),holding_bars=integer(),net_return=numeric(),entry_bar_time=character())
  r<-path$equity/contract$initial_wealth-1
  uw<-imom_underwater(path$equity)
  summary<-data.frame(symbol=unique(w$symbol),leverage=leverage,scenario=scenario,total_return=tail(r,1),
    sharpe=imom_sharpe(path$equity,periods),maximum_drawdown=imom_max_drawdown(path$equity),
    exposure=mean(schedule$target),trade_count=nrow(t),hit_rate=if(nrow(t))mean(t$net_return>0)else NA_real_,
    median_trade=if(nrow(t))median(t$net_return)else NA_real_,mean_trade=if(nrow(t))mean(t$net_return)else NA_real_,
    median_holding_bars=if(nrow(t))median(t$holding_bars)else NA_real_,financing_paid=financing_paid,
    turnover=turnover_notional/mean(path$equity,na.rm=TRUE),underwater_fraction=uw$fraction,
    maximum_underwater_bars=uw$maximum_bars,minimum_equity=min(path$equity,na.rm=TRUE),
    minimum_equity_ratio=if(any(is.finite(path$equity_ratio)))min(path$equity_ratio[is.finite(path$equity_ratio)],na.rm=TRUE)else 1,
    maintenance_breach=any(path$equity_ratio<contract$maintenance_ratio,na.rm=TRUE),stringsAsFactors=FALSE)
  list(path=path,trades=t,summary=summary)
}

imom_buy_hold_schedule <- function(bars,start,end) {
  n<-sum(bars$session_date>=as.Date(start)&bars$session_date<=as.Date(end)); target<-rep(TRUE,n)
  data.frame(target=target,entry_signal=c(TRUE,rep(FALSE,n-1L)),exit_signal=rep(FALSE,n))
}

imom_fractional_rank <- function(x,higher=TRUE) {
  if(all(!is.finite(x))) return(rep(0,length(x))); y<-x; y[!is.finite(y)]<-if(higher)-Inf else Inf
  if(higher) rank(y,ties.method="average")/length(y) else rank(-y,ties.method="average")/length(y)
}

imom_quarters <- function() {
  starts<-seq(as.Date("2021-01-01"),as.Date("2023-10-01"),by="quarter")
  data.frame(fold=sprintf("%sQ%s",format(starts,"%Y"),as.integer(format(starts,"%m"))%/%3+1L),
    test_start=starts,test_end=as.Date(c(tail(starts,-1L)-1,as.Date("2023-12-29"))),
    train_start=as.Date("2018-01-02"),train_end=starts-1,stringsAsFactors=FALSE)
}

imom_chan_pairs <- function(bars,start,end,L,H) {
  close<-bars$close; past<-close/c(rep(NA,L),head(close,-L))-1
  future<-c(tail(close,-H),rep(NA,H))/close-1
  eligible<-which(bars$session_date>=as.Date(start)&bars$session_date<=as.Date(end)&is.finite(past)&is.finite(future))
  if(!length(eligible)) return(data.frame())
  chosen<-eligible[seq.int(1,length(eligible),by=min(L,H))]
  data.frame(index=chosen,past_return=past[chosen],future_return=future[chosen])
}

imom_chan_screen <- function(bars,start,end,contract=imom_contract()) {
  grid<-expand.grid(L=contract$chan_L,H=contract$chan_H)
  rows<-lapply(seq_len(nrow(grid)),function(i){ p<-imom_chan_pairs(bars,start,end,grid$L[[i]],grid$H[[i]])
    test<-if(nrow(p)>=3&&sd(p$past_return)>0&&sd(p$future_return)>0)cor.test(p$past_return,p$future_return)else NULL
    r<-if(is.null(test))NA_real_ else unname(test$estimate); pv<-if(is.null(test))NA_real_ else test$p.value
    data.frame(L=grid$L[[i]],H=grid$H[[i]],pair_count=nrow(p),correlation=r,p_value=pv,
      t_stat=if(is.finite(r)&&abs(r)<1&&nrow(p)>2)r*sqrt((nrow(p)-2)/(1-r^2))else NA_real_) })
  out<-do.call(rbind,rows); out$admissible<-out$pair_count>=contract$chan_min_pairs&out$correlation>0&out$p_value<=contract$chan_p_max
  out
}

imom_chan_select <- function(screen) {
  x<-screen[screen$admissible&is.finite(screen$t_stat),,drop=FALSE]
  if(!nrow(x)) return(data.frame(L=NA_integer_,H=NA_integer_,pair_count=0,correlation=NA,p_value=NA,t_stat=NA,admissible=FALSE))
  x[order(-x$t_stat,x$H,x$L),,drop=FALSE][1L,,drop=FALSE]
}

imom_chan_target <- function(bars,start,end,L,H,delay_bars=0L) {
  n<-nrow(bars); lookback<-bars$close/c(rep(NA,L),head(bars$close,-L))-1
  in_block<-bars$session_date>=as.Date(start)&bars$session_date<=as.Date(end)
  target<-numeric(n); expiries<-integer()
  for(i in seq_len(n)) {
    expiries<-expiries[expiries>i]
    s<-i-1L-as.integer(delay_bars)
    if(in_block[[i]]&&s>=1L&&bars$session_date[[s]]>=as.Date(start)&&is.finite(lookback[[s]])&&lookback[[s]]>0) expiries<-c(expiries,i+H)
    target[[i]]<-min(1,length(expiries)/H)
  }
  idx<-which(in_block); target[max(idx)]<-0
  target[idx]
}

imom_chan_sleeve_replay <- function(bars,start,end,L,H,leverage=1,cost_bps=10,
                                    financing=0.06,delay_bars=0L,scenario="PRIMARY",
                                    contract=imom_contract(),signal_shift_sessions=0L) {
  w<-bars[bars$session_date>=as.Date(start)&bars$session_date<=as.Date(end),,drop=FALSE]
  pre_idx<-which(bars$session_date<as.Date(start)); offset<-if(length(pre_idx))max(pre_idx)else 0L
  lookback<-bars$close/c(rep(NA,L),head(bars$close,-L))-1
  sleeve_cash<-rep(contract$initial_wealth/H,H); shares<-debt<-rep(0,H)
  entry_i<-rep(NA_integer_,H); entry_equity<-rep(NA_real_,H); financing_paid<-0
  equity<-exposure<-gross_notional<-equity_ratio<-numeric(nrow(w)); trades<-list(); z<-1L; cost<-cost_bps/10000;turnover_notional<-0
  positive_signal<-vapply(seq_len(nrow(w)),function(i){s<-offset+i-1L-as.integer(delay_bars);s>=1L&&bars$session_date[[s]]>=as.Date(start)&&is.finite(lookback[[s]])&&lookback[[s]]>0},logical(1))
  if(signal_shift_sessions!=0L)positive_signal<-imom_shift_vector_sessions(positive_signal,w,signal_shift_sessions)
  for(i in seq_len(nrow(w))) {
    global_i<-offset+i
    k<-(i-1L)%%H+1L
    if(i>1L) {
      days<-as.numeric(difftime(w$timestamp_utc[[i]],w$timestamp_utc[[i-1L]],units="days"))
      active<-shares>0&debt>0;charge<-debt[active]*((1+financing)^(days/365.25)-1);debt[active]<-debt[active]+charge;financing_paid<-financing_paid+sum(charge)
    }
    if(shares[[k]]>0) {
      turnover_notional<-turnover_notional+shares[[k]]*w$open[[i]]
      cash_new<-shares[[k]]*w$open[[i]]*(1-cost)-debt[[k]]
      trades[[z]]<-data.frame(symbol=w$symbol[[i]],sleeve=k,entry_timestamp=w$timestamp_utc[[entry_i[[k]]]],
        exit_timestamp=w$timestamp_utc[[i]],entry_date=w$session_date[[entry_i[[k]]]],exit_date=w$session_date[[i]],
        holding_bars=i-entry_i[[k]],net_return=cash_new/entry_equity[[k]]-1,
        entry_bar_time=w$bar_time_et[[entry_i[[k]]]],stringsAsFactors=FALSE)
      z<-z+1L; sleeve_cash[[k]]<-cash_new; shares[[k]]<-0; debt[[k]]<-0
    }
    positive<-positive_signal[[i]]
    if(positive&&i<nrow(w)) {
      entry_i[[k]]<-i; entry_equity[[k]]<-sleeve_cash[[k]]; notional<-leverage*sleeve_cash[[k]]
      debt[[k]]<-(leverage-1)*sleeve_cash[[k]]; shares[[k]]<-notional*(1-cost)/w$open[[i]]; sleeve_cash[[k]]<-0
      turnover_notional<-turnover_notional+notional
    }
    if(i==nrow(w)) for(j in seq_len(H)) if(shares[[j]]>0) {
      turnover_notional<-turnover_notional+shares[[j]]*w$close[[i]]
      cash_new<-shares[[j]]*w$close[[i]]*(1-cost)-debt[[j]]
      trades[[z]]<-data.frame(symbol=w$symbol[[i]],sleeve=j,entry_timestamp=w$timestamp_utc[[entry_i[[j]]]],
        exit_timestamp=w$timestamp_utc[[i]],entry_date=w$session_date[[entry_i[[j]]]],exit_date=w$session_date[[i]],
        holding_bars=i-entry_i[[j]],net_return=cash_new/entry_equity[[j]]-1,
        entry_bar_time=w$bar_time_et[[entry_i[[j]]]],stringsAsFactors=FALSE)
      z<-z+1L;sleeve_cash[[j]]<-cash_new;shares[[j]]<-0;debt[[j]]<-0
    }
    values<-ifelse(shares>0,shares*w$close[[i]]-debt,sleeve_cash)
    equity[[i]]<-sum(values); exposure[[i]]<-sum(shares>0)/H;gross_notional[[i]]<-sum(shares*w$close[[i]])
    equity_ratio[[i]]<-if(gross_notional[[i]]>0)equity[[i]]/gross_notional[[i]]else Inf
  }
  t<-if(length(trades))do.call(rbind,trades)else data.frame(symbol=character(),sleeve=integer(),entry_timestamp=as.POSIXct(character()),exit_timestamp=as.POSIXct(character()),entry_date=as.Date(character()),exit_date=as.Date(character()),holding_bars=integer(),net_return=numeric(),entry_bar_time=character())
  path<-data.frame(symbol=w$symbol,timestamp_utc=w$timestamp_utc,session_date=w$session_date,bar_time_et=w$bar_time_et,
    open=w$open,close=w$close,target=exposure,equity=equity,gross_notional=gross_notional,equity_ratio=equity_ratio,
    leverage=leverage,scenario=scenario,stringsAsFactors=FALSE)
  uw<-imom_underwater(equity)
  summary<-data.frame(symbol=unique(w$symbol),L=L,H=H,leverage=leverage,scenario=scenario,
    total_return=tail(equity,1)/contract$initial_wealth-1,sharpe=imom_sharpe(equity,3276L),
    maximum_drawdown=imom_max_drawdown(equity),exposure=mean(exposure),trade_count=nrow(t),
    hit_rate=if(nrow(t))mean(t$net_return>0)else NA_real_,median_trade=if(nrow(t))median(t$net_return)else NA_real_,
    mean_trade=if(nrow(t))mean(t$net_return)else NA_real_,median_holding_bars=if(nrow(t))median(t$holding_bars)else NA_real_,
    financing_paid=financing_paid,turnover=turnover_notional/mean(equity,na.rm=TRUE),underwater_fraction=uw$fraction,
    maximum_underwater_bars=uw$maximum_bars,minimum_equity=min(equity,na.rm=TRUE),
    minimum_equity_ratio=if(any(is.finite(equity_ratio)))min(equity_ratio[is.finite(equity_ratio)],na.rm=TRUE)else 1,
    maintenance_breach=any(equity_ratio<contract$maintenance_ratio,na.rm=TRUE),stringsAsFactors=FALSE)
  list(path=path,trades=t,summary=summary)
}

imom_shift_schedule_sessions <- function(schedule,shift_sessions,bars_per_session=13L) {
  shift<-as.integer(shift_sessions)*as.integer(bars_per_session); n<-nrow(schedule)
  rotated<-schedule; rotated$target<-schedule$target[((seq_len(n)-shift-1L)%%n)+1L]
  rotated$entry_signal<-c(FALSE,diff(as.numeric(rotated$target))>0)
  rotated$exit_signal<-c(FALSE,diff(as.numeric(rotated$target))<0); rotated
}

imom_shift_vector_sessions <- function(signal,bars,shift_sessions) {
  sessions<-unique(as.character(bars$session_date));rank<-match(as.character(bars$session_date),sessions)
  source_rank<-((rank-as.integer(shift_sessions)-1L)%%length(sessions))+1L
  slot<-if("bar_slot"%in%names(bars))bars$bar_slot else ave(seq_len(nrow(bars)),bars$session_date,FUN=seq_along)
  width<-max(slot);lookup<-rep(NA,length(sessions)*width);lookup[(rank-1L)*width+slot]<-as.logical(signal)
  out<-lookup[(source_rank-1L)*width+slot];out[is.na(out)]<-FALSE;out
}

imom_shift_schedule_by_sessions <- function(schedule,bars,shift_sessions) {
  rotated<-schedule;rotated$target<-imom_shift_vector_sessions(schedule$target,bars,shift_sessions)
  rotated$entry_signal<-c(FALSE,diff(as.numeric(rotated$target))>0)
  rotated$exit_signal<-c(FALSE,diff(as.numeric(rotated$target))<0);rotated
}

imom_trade_multiplier <- function(entry_price,exit_price,entry_timestamp,exit_timestamp,
                                  leverage,cost_bps,financing) {
  cost<-cost_bps/10000
  days<-as.numeric(difftime(exit_timestamp,entry_timestamp,units="days"))
  leverage*(1-cost)^2*(exit_price/entry_price)-(leverage-1)*(1+financing)^(days/365.25)
}

imom_fast_terminal_return <- function(bars,start,end,schedule,leverage=1,cost_bps=10,
                                      financing=.06,contract=imom_contract()) {
  w<-bars[bars$session_date>=as.Date(start)&bars$session_date<=as.Date(end),,drop=FALSE]
  imom_fast_terminal_from_schedule(w,schedule,leverage,cost_bps,financing,contract)
}

imom_fast_terminal_from_schedule <- function(w,schedule,leverage=1,cost_bps=10,
                                             financing=.06,contract=imom_contract()) {
  if(nrow(w)!=nrow(schedule))imom_stop("Fast replay schedule length mismatch.")
  target<-as.logical(schedule$target);starts<-which(target&!c(FALSE,head(target,-1L)))
  open_exits<-which(!target&c(FALSE,head(target,-1L)))
  wealth<-contract$initial_wealth
  for(k in seq_along(starts)){entry<-starts[[k]];forced<-k>length(open_exits)
    exit<-if(forced)nrow(w)else open_exits[[k]];exit_price<-if(forced)w$close[[exit]]else w$open[[exit]]
    wealth<-wealth*imom_trade_multiplier(w$open[[entry]],exit_price,w$timestamp_utc[[entry]],w$timestamp_utc[[exit]],leverage,cost_bps,financing)
  }
  wealth/contract$initial_wealth-1
}

imom_chan_positive_signal <- function(bars,start,end,L,delay_bars=0L,shift_sessions=0L) {
  w<-bars[bars$session_date>=as.Date(start)&bars$session_date<=as.Date(end),,drop=FALSE]
  pre_idx<-which(bars$session_date<as.Date(start));offset<-if(length(pre_idx))max(pre_idx)else 0L
  lookback<-bars$close/c(rep(NA,L),head(bars$close,-L))-1
  signal<-vapply(seq_len(nrow(w)),function(i){s<-offset+i-1L-as.integer(delay_bars);s>=1L&&bars$session_date[[s]]>=as.Date(start)&&is.finite(lookback[[s]])&&lookback[[s]]>0},logical(1))
  if(shift_sessions!=0L)signal<-imom_shift_vector_sessions(signal,w,shift_sessions)
  signal
}

imom_chan_fast_terminal_return <- function(bars,start,end,L,H,leverage=1,cost_bps=10,
                                           financing=.06,delay_bars=0L,shift_sessions=0L,
                                           contract=imom_contract()) {
  w<-bars[bars$session_date>=as.Date(start)&bars$session_date<=as.Date(end),,drop=FALSE]
  signal<-imom_chan_positive_signal(bars,start,end,L,delay_bars,shift_sessions)
  imom_chan_fast_terminal_from_signal(w,signal,H,leverage,cost_bps,financing,contract)
}

imom_chan_fast_terminal_from_signal <- function(w,signal,H,leverage=1,cost_bps=10,
                                                financing=.06,contract=imom_contract()) {
  if(nrow(w)!=length(signal))imom_stop("Chan fast signal length mismatch.")
  entries<-which(as.logical(signal)&seq_along(signal)<nrow(w))
  if(!length(entries))return(0)
  exits<-pmin(entries+H,nrow(w));forced<-entries+H>nrow(w)
  exit_prices<-w$open[exits];exit_prices[forced]<-tail(w$close,1L)
  days<-as.numeric(difftime(w$timestamp_utc[exits],w$timestamp_utc[entries],units="days"))
  cost<-cost_bps/10000
  multipliers<-leverage*(1-cost)^2*(exit_prices/w$open[entries])-(leverage-1)*(1+financing)^(days/365.25)
  sleeves<-((entries-1L)%%H)+1L;products<-rep(1,H)
  compounded<-tapply(multipliers,sleeves,prod)
  products[as.integer(names(compounded))]<-as.numeric(compounded)
  mean(products)-1
}
