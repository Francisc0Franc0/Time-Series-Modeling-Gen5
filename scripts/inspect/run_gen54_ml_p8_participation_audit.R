# Gen5.4 ML-P8: forensic audit of completed ML-P7 decisions. No model fitting.
root <- normalizePath(file.path("runs", "research_workbench", "gen54_ml_decision_engine", "g54_ml_p7_swing_2020_2024_merged"), winslash = "/", mustWork = TRUE)
out <- file.path(root, "ml_p8_participation_audit"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
read_packet <- function(name) utils::read.csv(file.path(root, paste0("ml_p7_", name, ".csv")), stringsAsFactors = FALSE)
lanes <- c("abs_h1__existing_relative_control", "rel_h10__existing_relative_control")
policy <- "train_forward_return_grid"
actions <- read_packet("actions"); predictions <- read_packet("oos_predictions"); portfolio <- read_packet("portfolio_equity"); summary <- read_packet("summary"); ranking <- read_packet("ranking")
actions <- actions[actions$policy_id == policy & actions$lane_id %in% lanes, , drop = FALSE]
portfolio <- portfolio[portfolio$policy_id == policy & portfolio$lane_id %in% lanes, , drop = FALSE]
summary <- summary[summary$policy_id == policy & summary$lane_id %in% lanes, , drop = FALSE]
ranking <- ranking[ranking$lane_id %in% lanes, , drop = FALSE]
actions$session_date <- as.Date(actions$feature_date); predictions$session_date <- as.Date(predictions$session_date); portfolio$session_date <- as.Date(portfolio$session_date)
prediction_key <- predictions[, c("lane_id", "window_id", "symbol", "session_date", "close", "pred_prob_h3"), drop = FALSE]
actions <- merge(actions, prediction_key, by = c("lane_id", "window_id", "symbol", "session_date"), all.x = TRUE, sort = FALSE)
participation <- aggregate(actions$position_at_close, list(lane_id = actions$lane_id, window_id = actions$window_id, symbol = actions$symbol), mean, na.rm = TRUE)
names(participation)[4] <- "mean_position_rate"
portfolio <- portfolio[order(portfolio$lane_id, portfolio$window_id, portfolio$session_date), , drop = FALSE]
portfolio$benchmark_daily_return <- ave(portfolio$benchmark_mult, portfolio$lane_id, portfolio$window_id, FUN = function(x) c(NA_real_, x[-1] / x[-length(x)] - 1))
bench <- aggregate(portfolio$benchmark_daily_return, list(lane_id = portfolio$lane_id, window_id = portfolio$window_id, session_date = portfolio$session_date), mean, na.rm = TRUE)
names(bench)[4] <- "benchmark_daily_return"
exposure <- aggregate(actions$position_at_close, list(lane_id = actions$lane_id, window_id = actions$window_id, session_date = actions$session_date), mean, na.rm = TRUE)
names(exposure)[4] <- "exposure_rate"
exposure <- merge(exposure, bench, by = c("lane_id", "window_id", "session_date"), all.x = TRUE)
exposure$benchmark_regime <- ifelse(exposure$benchmark_daily_return > 0, "benchmark_up", "benchmark_down_or_flat")
regime <- aggregate(exposure$exposure_rate, list(lane_id = exposure$lane_id, window_id = exposure$window_id, benchmark_regime = exposure$benchmark_regime), mean, na.rm = TRUE)
names(regime)[4] <- "mean_exposure"
rank_summary <- aggregate(ranking[, c("auc", "top_minus_bottom_fwd_ret")], list(lane_id = ranking$lane_id, window_id = ranking$window_id), mean, na.rm = TRUE)
chart_path <- file.path(out, "ml_p8_exposure_by_benchmark_regime.png")
grDevices::png(chart_path, width = 3000, height = 1800, res = 190); graphics::par(mfrow = c(1, 2), mar = c(9, 5, 4, 2))
for (lane in lanes) { x <- regime[regime$lane_id == lane, , drop = FALSE]; key <- paste(x$window_id, x$benchmark_regime, sep = "\n"); graphics::barplot(x$mean_exposure, names.arg = key, las = 2, ylim = c(0, 1), col = ifelse(x$benchmark_regime == "benchmark_up", "#2563EB", "#DC2626"), border = NA, ylab = "Mean long exposure", main = gsub("__", "\n", lane)); graphics::abline(h = 0.5, lty = 2, col = "#6B7280") }; grDevices::dev.off()
tape_path <- file.path(out, "ml_p8_probability_trade_tapes.png")
grDevices::png(tape_path, width = 3000, height = 1800, res = 190); graphics::par(mfrow = c(2, 2), mar = c(4, 5, 3, 2))
examples <- expand.grid(lane_id = lanes, window_id = c("2020Y", "2022Y"), stringsAsFactors = FALSE)
for (i in seq_len(nrow(examples))) { e <- examples[i, ]; x <- actions[actions$lane_id == e$lane_id & actions$window_id == e$window_id & actions$symbol == "AMD", , drop = FALSE]; x <- x[order(x$session_date), ]; if (!nrow(x)) { graphics::plot.new(); next }; graphics::plot(x$session_date, x$close, type = "l", col = "#111827", lwd = 1.7, xlab = "", ylab = "Close", main = paste("AMD", e$window_id, gsub("__", " / ", e$lane_id))); held <- x$position_at_close > 0; graphics::points(x$session_date[held], x$close[held], pch = 16, cex = .35, col = "#2563EB"); graphics::par(new = TRUE); graphics::plot(x$session_date, x$pred_prob_h3, type = "l", col = "#16A34A", lwd = 1.2, axes = FALSE, xlab = "", ylab = "", ylim = c(0, 1)); graphics::axis(4, col.axis = "#16A34A"); graphics::mtext("Probability", side = 4, line = 2, col = "#16A34A") }; grDevices::dev.off()
utils::write.csv(participation, file.path(out, "ml_p8_symbol_participation.csv"), row.names = FALSE); utils::write.csv(regime, file.path(out, "ml_p8_exposure_by_benchmark_regime.csv"), row.names = FALSE); utils::write.csv(rank_summary, file.path(out, "ml_p8_ranking_by_window.csv"), row.names = FALSE); utils::write.csv(summary, file.path(out, "ml_p8_replay_summary.csv"), row.names = FALSE)
writeLines(c("# ML-P8 Participation Attribution Audit", "", "This packet reuses completed ML-P7 decisions. It fits no model and selects no policy.", "", "## Audit focus", "", "- Compare long exposure on benchmark-up versus benchmark-down/flat days.", "- Inspect symbol-level participation and probability/position tapes.", "- Treat ranking and replay diagnostics as explanation evidence, not allocation evidence."), file.path(out, "ml_p8_participation_audit_report.md"))
message("ML-P8 audit: ", normalizePath(out, winslash = "/"))
