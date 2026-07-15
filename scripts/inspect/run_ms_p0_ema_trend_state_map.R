root <- Sys.getenv("GEN5_MS_P0_ROOT", unset = "runs/research_workbench/wfa_pocs/mawfa_5a_4f_1fam_20180101_20201231_20201231173000")
out <- file.path(root, "ms_p0_candidate_state_map"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
symbols <- c("AMD", "NVDA", "TSLA", "MSTR", "AVGO")
roll_mean <- function(x, n) stats::filter(x, rep(1/n, n), sides = 1)
parts <- list(); thresholds <- list(); k <- 1L
for (sym in symbols) {
  dir <- file.path(root, sym); bars <- read.csv(list.files(dir, "_bars\\.csv$", full.names = TRUE), stringsAsFactors = FALSE); eq <- read.csv(list.files(dir, "_equity\\.csv$", full.names = TRUE), stringsAsFactors = FALSE); folds <- read.csv(list.files(dir, "_folds\\.csv$", full.names = TRUE), stringsAsFactors = FALSE)
  bars$session_date <- as.Date(bars$session_date); eq$session_date <- as.Date(eq$session_date); folds$train_start_date <- as.Date(folds$train_start_date); folds$train_end_date <- as.Date(folds$train_end_date); folds$oos_start_date <- as.Date(folds$oos_start_date); folds$oos_end_date <- as.Date(folds$oos_end_date)
  bars <- bars[order(bars$session_date), ]; bars$ret20 <- bars$close / c(rep(NA,20), head(bars$close,-20)) - 1; bars$logret <- c(NA, diff(log(bars$close))); bars$vol20 <- as.numeric(roll_mean(bars$logret^2,20)^0.5 * sqrt(252))
  eq$buy_hold_daily_return <- c(NA, eq$buy_hold_equity[-1] / eq$buy_hold_equity[-nrow(eq)] - 1); eq$daily_excess <- eq$daily_return - eq$buy_hold_daily_return
  for (i in seq_len(nrow(folds))) {
    f <- folds[i, ]; train <- bars[bars$session_date >= f$train_start_date & bars$session_date <= f$train_end_date, ]; tr <- stats::median(train$ret20, na.rm = TRUE); tv <- stats::median(train$vol20, na.rm = TRUE)
    oos <- merge(eq[eq$session_date >= f$oos_start_date & eq$session_date <= f$oos_end_date, ], bars[,c("session_date","ret20","vol20")], by="session_date", all.x=TRUE)
    oos$trend_state <- ifelse(oos$ret20 > tr, "trend_confirmed", "trend_weak")
    oos$vol_state <- ifelse(oos$vol20 <= tv, "vol_quiet", "vol_elevated")
    oos$state_id <- paste(oos$trend_state, oos$vol_state, sep="__"); oos$symbol <- sym; oos$fold_id <- f$fold_id
    parts[[k]] <- oos; thresholds[[k]] <- data.frame(symbol=sym,fold_id=f$fold_id,train_ret20_median=tr,train_vol20_median=tv); k <- k+1L
  }
}
x <- do.call(rbind, parts); th <- do.call(rbind, thresholds)
state <- aggregate(x[,c("daily_excess","daily_return","buy_hold_daily_return","in_position")], list(state_id=x$state_id), mean, na.rm=TRUE); names(state)[2:5] <- c("mean_daily_excess","mean_strategy_return","mean_hold_return","mean_exposure")
by_symbol <- aggregate(x[,c("daily_excess","in_position")], list(symbol=x$symbol,state_id=x$state_id), mean, na.rm=TRUE); names(by_symbol)[3:4] <- c("mean_daily_excess","mean_exposure")
write.csv(th,file.path(out,"ms_p0_train_state_thresholds.csv"),row.names=FALSE); write.csv(state,file.path(out,"ms_p0_oos_state_summary.csv"),row.names=FALSE); write.csv(by_symbol,file.path(out,"ms_p0_oos_state_by_symbol.csv"),row.names=FALSE); write.csv(x,file.path(out,"ms_p0_oos_state_daily.csv"),row.names=FALSE)
png(file.path(out,"ms_p0_state_excess_and_exposure.png"),width=2600,height=1500,res=180); par(mfrow=c(1,2),mar=c(8,5,4,2)); barplot(state$mean_daily_excess,names.arg=gsub("__","\n",state$state_id),las=2,col=ifelse(state$mean_daily_excess>=0,"#15803D","#B91C1C"),main="OOS daily strategy minus hold return",ylab="Mean daily excess"); abline(h=0,lty=2); barplot(state$mean_exposure,names.arg=gsub("__","\n",state$state_id),las=2,col="#2563EB",ylim=c(0,1),main="OOS EMA trend exposure",ylab="Mean long exposure"); dev.off()
writeLines(c("# MS-P0 Candidate State Map","","TRAIN-only medians define each fold's trend/volatility state cutoffs. This is a raw-strategy diagnostic, not an ML gate or allocation claim."),file.path(out,"ms_p0_state_map_report.md"))
message("MS-P0 state map: ",normalizePath(out,winslash="/"))
