# Build comparative visuals for LIT-MR-06.1 / RECENT_WIDE_ATLAS_02.

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
recent_root <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded",
  "lit_mr_06_1_recent_wide_atlas_02_20260730"
)
initial_root <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded",
  "lit_mr_06_1_buy_on_gap_20260730_v2"
)
visual_root <- file.path(recent_root, "visuals")
dir.create(visual_root, recursive = TRUE, showWarnings = FALSE)

read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

with_png <- function(path, width, height, expression) {
  grDevices::png(
    path, width = width, height = height, res = 160,
    bg = "white", type = "cairo"
  )
  on.exit(grDevices::dev.off(), add = TRUE)
  force(expression)
}

recent <- read_csv(file.path(recent_root, "atlas_summary.csv"))
initial <- read_csv(file.path(initial_root, "atlas_summary.csv"))
portfolio <- read_csv(file.path(recent_root, "portfolio_day_tape.csv"))
registry <- read_csv(file.path(
  repo_root, "literature_studies", "registries",
  "gen5_lit_mr_06_1_recent_wide_atlas_02_registry.csv"
))

registry$stock_count <- lengths(strsplit(registry$symbols, ",", fixed = TRUE))
sector <- registry[-1L, , drop = FALSE]
sector <- sector[order(sector$stock_count, sector$category), , drop = FALSE]
with_png(
  file.path(visual_root, "mr06_recent_universe_funnel.png"),
  1800, 900,
  {
    old <- par(mar = c(1, 1, 4, 1))
    on.exit(par(old), add = TRUE)
    plot.new()
    plot.window(xlim = c(0, 100), ylim = c(0, 36))
    box_x <- c(2, 27, 52, 77)
    box_w <- 21
    box_y <- 10
    box_h <- 15
    fills <- c("#E8F2FF", "#F2F2F2", "#F2F2F2", "#E7F4EC")
    headers <- c(
      "OFFICIAL SOURCE", "OUTCOME-BLIND ORDER",
      "COVERAGE SCREEN", "FROZEN ATLAS"
    )
    values <- c(
      "11 sector holdings\nworkbooks",
      "first 40 issuers\nper sector",
      ">=90% daily coverage\nAug 2022-Dec 2024",
      "305 unique stocks\n11 sector panels"
    )
    for (i in seq_along(box_x)) {
      rect(
        box_x[i], box_y, box_x[i] + box_w, box_y + box_h,
        col = fills[i], border = NA
      )
      text(
        box_x[i] + 2, box_y + box_h - 3,
        headers[i], adj = c(0, 0.5), font = 2, cex = 0.82,
        col = if (i == 1) "#3D8DFF" else "#123047"
      )
      text(
        box_x[i] + 2, box_y + 5.4,
        values[i], adj = c(0, 0.5), cex = 0.92
      )
      if (i < length(box_x)) {
        arrows(
          box_x[i] + box_w + 1, box_y + box_h / 2,
          box_x[i + 1] - 1, box_y + box_h / 2,
          length = 0.09, lwd = 2, col = "#94A3B8"
        )
      }
    }
    title("The universe was frozen before strategy outcomes", cex.main = 1.35)
    text(
      50, 4,
      "CUSIP6 issuer deduplication prevents duplicate share classes; current membership bias remains disclosed.",
      cex = 0.82, col = "#475569"
    )
  }
)

with_png(
  file.path(visual_root, "mr06_recent_panel_breadth.png"),
  1800, 1000,
  {
    old <- par(mar = c(6, 12, 4, 2))
    on.exit(par(old), add = TRUE)
    barplot(
      sector$stock_count,
      names.arg = sector$category,
      horiz = TRUE, las = 1,
      col = "#3D8DFF", border = NA,
      xlim = c(0, 34),
      xlab = "Frozen stocks per sector",
      main = "The recent atlas broadens every sector and adds the missing two"
    )
    abline(v = 15, lty = 2, col = "#94A3B8", lwd = 2)
    text(
      sector$stock_count + 0.7, seq_along(sector$stock_count) - 0.5,
      labels = sector$stock_count, adj = 0, cex = 0.85
    )
    legend(
      "bottomright", legend = "Initial sector size: 15",
      lty = 2, lwd = 2, col = "#94A3B8", bty = "n"
    )
  }
)

recent$mean_day_bps <- 10000 * recent$mean_portfolio_day_return
colors <- ifelse(
  recent$gates_passed >= 7, "#177245",
  ifelse(recent$gates_passed >= 5, "#3D8DFF", "#94A3B8")
)
with_png(
  file.path(visual_root, "mr06_recent_support_return_map.png"),
  1800, 1050,
  {
    old <- par(mar = c(6, 6, 4, 2))
    on.exit(par(old), add = TRUE)
    plot(
      recent$stock_events, recent$mean_day_bps,
      pch = 19, cex = pmax(1.5, sqrt(recent$portfolio_days) / 2.2),
      col = colors,
      xlab = "Selected stock-events",
      ylab = "Mean primary-cost portfolio-day return (bp)",
      main = "Breadth solved event support only for the combined panel"
    )
    abline(h = 0, v = 60, lty = 2, col = "#64748B")
    labels <- sub("^W[0-9]+_", "", recent$instance_id)
    label_x <- recent$stock_events + 2
    label_y <- recent$mean_day_bps
    label_adj <- rep(0, length(labels))
    label_x[labels == "INDUSTRIALS"] <- 17
    label_y[labels == "INDUSTRIALS"] <- 5.25
    label_adj[labels == "INDUSTRIALS"] <- 1
    label_x[labels == "HEALTH_CARE"] <- 21
    label_y[labels == "HEALTH_CARE"] <- 6.65
    label_adj[labels == "HEALTH_CARE"] <- 1
    label_x[labels == "TECHNOLOGY"] <- 34
    label_y[labels == "TECHNOLOGY"] <- 6.25
    text(
      label_x, label_y,
      labels = labels, adj = label_adj, cex = 0.72, xpd = TRUE
    )
    legend(
      "bottomright",
      legend = c("7/8 gates", "5-6/8 gates", "<5/8 gates"),
      pch = 19, col = c("#177245", "#3D8DFF", "#94A3B8"),
      bty = "n"
    )
  }
)

initial_primary <- initial[initial$instance_id == "G01_BROAD_US", , drop = FALSE]
recent_primary <- recent[recent$instance_id == "W01_WIDE_US", , drop = FALSE]
comparison <- rbind(
  c(
    initial_primary$stock_events,
    initial_primary$portfolio_days,
    100 * initial_primary$cumulative_return,
    100 * initial_primary$stress_cumulative_return,
    100 * initial_primary$up_down_accuracy,
    initial_primary$gates_passed
  ),
  c(
    recent_primary$stock_events,
    recent_primary$portfolio_days,
    100 * recent_primary$cumulative_return,
    100 * recent_primary$stress_cumulative_return,
    100 * recent_primary$up_down_accuracy,
    recent_primary$gates_passed
  )
)
colnames(comparison) <- c(
  "Stock-events", "Portfolio days", "Primary return (%)",
  "Stress return (%)", "Direction accuracy (%)", "Gates passed"
)
rownames(comparison) <- c("2019-2020 small", "2023-2024 wide")
with_png(
  file.path(visual_root, "mr06_initial_recent_comparison.png"),
  1900, 1050,
  {
    old <- par(
      mfrow = c(2, 3), mar = c(5, 5, 3, 2),
      oma = c(0, 0, 4, 0)
    )
    on.exit(par(old), add = TRUE)
    for (j in seq_len(ncol(comparison))) {
      values <- comparison[, j]
      upper <- max(values, 0) * 1.25
      lower <- min(values, 0) * 1.25
      if (upper == lower) upper <- lower + 1
      bars <- barplot(
        values,
        names.arg = rownames(comparison),
        col = c("#94A3B8", "#3D8DFF"),
        border = NA, las = 2,
        ylim = c(lower, upper),
        main = colnames(comparison)[j]
      )
      abline(h = 0, col = "#123047")
      text(
        bars, values,
        labels = format(round(values, 2), trim = TRUE),
        pos = ifelse(values >= 0, 3, 1), cex = 0.8
      )
    }
    mtext(
      "The wide recent replication improved every primary diagnostic",
      outer = TRUE, side = 3, line = 1.2, font = 2, cex = 1.25
    )
  }
)

wide_days <- portfolio[portfolio$instance_id == "W01_WIDE_US", , drop = FALSE]
wide_days$session_date <- as.Date(wide_days$session_date)
wide_days$month <- format(wide_days$session_date, "%Y-%m")
monthly <- aggregate(
  cbind(
    event_days = rep(1, nrow(wide_days)),
    selected_stocks = wide_days$selected_count,
    primary_return = wide_days$primary_net_return
  ),
  by = list(month = wide_days$month),
  FUN = sum
)
with_png(
  file.path(visual_root, "mr06_recent_monthly_behavior.png"),
  1900, 1100,
  {
    old <- par(mfrow = c(2, 1), mar = c(5, 7, 4, 2))
    on.exit(par(old), add = TRUE)
    barplot(
      monthly$selected_stocks,
      names.arg = monthly$month,
      col = "#3D8DFF", border = NA, las = 2,
      ylab = "Selected stock-events",
      main = "Wide-panel signals remain episodic rather than continuous"
    )
    colors <- ifelse(monthly$primary_return >= 0, "#177245", "#B42318")
    barplot(
      100 * monthly$primary_return,
      names.arg = monthly$month,
      col = colors, border = NA, las = 2,
      ylab = "Additive primary return (%)",
      main = "Monthly contribution changes sign despite positive total return"
    )
    abline(h = 0, col = "#123047")
  }
)

message("Recent-wide comparative visuals: ", visual_root)
