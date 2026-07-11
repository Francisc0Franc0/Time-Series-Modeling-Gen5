import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const artifactModule =
  process.env.ARTIFACT_TOOL_MODULE ||
  "C:/Users/Franc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactModule).href);

const outputPptx = path.join(repoRoot, "presentations", "gen5_3_bull_momentum_specialist_plan.pptx");
const previewDir = path.join(repoRoot, "presentations", "gen5_3_bull_momentum_specialist_plan_slides");
const montagePath = path.join(repoRoot, "presentations", "gen5_3_bull_momentum_specialist_plan_montage.webp");
const inspectPath = path.join(repoRoot, "presentations", "gen5_3_bull_momentum_specialist_plan.pptx.inspect.ndjson");
const resultDir = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "gen53_bull_momentum_specialist",
  "g53_bullmom_20260710features",
);
const resultPaths = {
  summary: path.join(resultDir, "bull_momentum_specialist_summary.csv"),
  aggregate: path.join(resultDir, "bull_momentum_specialist_aggregate.csv"),
  taxonomy: path.join(resultDir, "bull_momentum_specialist_feature_taxonomy.csv"),
  heatmap: path.join(resultDir, "bull_momentum_specialist_alpha_heatmap.png"),
  equity: path.join(resultDir, "bull_momentum_specialist_equity_overlay.png"),
  exposure: path.join(resultDir, "bull_momentum_specialist_exposure_alpha_scatter.png"),
  family: path.join(resultDir, "bull_momentum_specialist_selection_family_heatmap.png"),
  tapes: path.join(resultDir, "bull_momentum_specialist_trade_tape_contact_sheet.png"),
  representativeTapes: path.join(resultDir, "bull_momentum_specialist_representative_trade_tapes.png"),
  report: path.join(resultDir, "bull_momentum_specialist_report.md"),
};

const W = 1280;
const H = 720;
const frame = { left: 64, top: 54, width: 1152, height: 612 };
const colors = {
  ink: "#111827",
  muted: "#5B6472",
  canvas: "#FFFFFF",
  soft: "#F5F7FA",
  line: "#CBD3DD",
  blue: "#2563EB",
  teal: "#0F9F8F",
  amber: "#D97706",
  rose: "#D1495B",
  green: "#177A55",
  violet: "#7C3AED",
};

async function writeBlob(filePath, blob) {
  await fs.writeFile(filePath, new Uint8Array(await blob.arrayBuffer()));
}

function parseCsvLine(line) {
  const out = [];
  let cur = "";
  let quoted = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (ch === "\"") {
      if (quoted && line[i + 1] === "\"") {
        cur += "\"";
        i += 1;
      } else {
        quoted = !quoted;
      }
    } else if (ch === "," && !quoted) {
      out.push(cur);
      cur = "";
    } else {
      cur += ch;
    }
  }
  out.push(cur);
  return out;
}

async function readCsv(filePath) {
  const text = await fs.readFile(filePath, "utf8");
  const lines = text.trim().split(/\r?\n/);
  const headers = parseCsvLine(lines[0]);
  return lines.slice(1).filter(Boolean).map((line) => {
    const values = parseCsvLine(line);
    const row = {};
    headers.forEach((header, index) => {
      row[header] = values[index] ?? "";
    });
    return row;
  });
}

function num(value) {
  const x = Number(value);
  return Number.isFinite(x) ? x : NaN;
}

function pct(value, digits = 1) {
  const x = typeof value === "number" ? value : num(value);
  return Number.isFinite(x) ? `${(100 * x).toFixed(digits)}%` : "NA";
}

function pp(value, digits = 1) {
  const x = typeof value === "number" ? value : num(value);
  return Number.isFinite(x) ? `${x >= 0 ? "+" : ""}${(100 * x).toFixed(digits)} pp` : "NA";
}

async function addImage(slide, imagePath, position, alt) {
  slide.images.add({
    blob: await fs.readFile(imagePath),
    contentType: "image/png",
    alt,
    fit: "contain",
    position,
  });
}

function addText(slide, text, position, style = {}) {
  const shape = slide.shapes.add({
    geometry: "textbox",
    position,
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = text;
  shape.text.style = {
    fontSize: style.fontSize ?? 19,
    color: style.color ?? colors.ink,
    bold: style.bold ?? false,
    alignment: style.alignment,
  };
  return shape;
}

function addTitle(slide, title, kicker = "GEN5.3 PCA RESEARCH PIVOT") {
  addText(slide, kicker, { left: frame.left, top: 32, width: 560, height: 22 }, {
    fontSize: 13,
    bold: true,
    color: colors.blue,
  });
  addText(slide, title, { left: frame.left, top: 68, width: 980, height: 92 }, {
    fontSize: 37,
    bold: true,
    color: colors.ink,
  });
  slide.shapes.add({
    geometry: "rect",
    position: { left: frame.left, top: 156, width: 1110, height: 1 },
    fill: colors.line,
    line: { style: "solid", fill: colors.line, width: 0 },
  });
}

function addPanel(slide, position, opts = {}) {
  return slide.shapes.add({
    geometry: "roundRect",
    position,
    fill: opts.fill ?? colors.soft,
    line: { style: "solid", fill: opts.line ?? colors.line, width: 1 },
    borderRadius: "rounded-lg",
  });
}

function addBulletList(slide, items, position, style = {}) {
  const lineHeight = style.lineHeight ?? 31;
  items.forEach((item, index) => {
    const y = position.top + index * lineHeight;
    slide.shapes.add({
      geometry: "ellipse",
      position: { left: position.left, top: y + 9, width: 8, height: 8 },
      fill: style.dotColor ?? colors.blue,
      line: { style: "solid", fill: "none", width: 0 },
    });
    addText(slide, item, {
      left: position.left + 22,
      top: y,
      width: position.width - 22,
      height: lineHeight + 4,
    }, {
      fontSize: style.fontSize ?? 18,
      color: style.color ?? colors.ink,
    });
  });
}

function addSmallLabel(slide, text, x, y, w, color) {
  addText(slide, text, { left: x, top: y, width: w, height: 26 }, {
    fontSize: 14,
    bold: true,
    color,
    alignment: "center",
  });
}

function addFlowNode(slide, text, x, y, w, h, fill, color = colors.ink) {
  addPanel(slide, { left: x, top: y, width: w, height: h }, { fill, line: fill });
  addText(slide, text, { left: x + 16, top: y + 14, width: w - 32, height: h - 20 }, {
    fontSize: 18,
    bold: true,
    color,
    alignment: "center",
  });
}

function addArrow(slide, x1, y1, x2) {
  slide.shapes.add({
    geometry: "chevron",
    position: { left: x1, top: y1, width: x2 - x1, height: 28 },
    fill: colors.line,
    line: { style: "solid", fill: "none", width: 0 },
  });
}

async function createDeck() {
  const deck = Presentation.create({ slideSize: { width: W, height: H } });
  const summary = await readCsv(resultPaths.summary);
  const aggregate = await readCsv(resultPaths.aggregate);
  const row = (featureSetId, windowId, semantics) => summary.find((x) => x.feature_set_id === featureSetId && x.window_id === windowId && x.entry_replay_semantics === semantics) ?? {};
  const workhorseCont2020 = row("workhorse_enriched", "2020Q3_asof_20200930", "state_switch_continuation");
  const stressCont2020 = row("momentum_plus_stress", "2020Q3_asof_20200930", "state_switch_continuation");
  const workhorseCont2022 = row("workhorse_enriched", "2022Q1_asof_20220331", "state_switch_continuation");
  const stressCont2022 = row("momentum_plus_stress", "2022Q1_asof_20220331", "state_switch_continuation");
  const aggStressCont = aggregate.find((x) => x.feature_set_id === "momentum_plus_stress" && x.entry_replay_semantics === "state_switch_continuation") ?? {};
  const aggWorkhorseCont = aggregate.find((x) => x.feature_set_id === "workhorse_enriched" && x.entry_replay_semantics === "state_switch_continuation") ?? {};

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addText(slide, "GEN5.3 PLANNING BRIEF", { left: 72, top: 60, width: 420, height: 28 }, {
      fontSize: 14,
      bold: true,
      color: colors.blue,
    });
    addText(slide, "Bullish Momentum Specialist", { left: 72, top: 132, width: 820, height: 122 }, {
      fontSize: 54,
      bold: true,
      color: colors.ink,
    });
    addText(
      slide,
      "Narrow the PCA engine before expanding it: first test whether a high-beta bullish participation specialist can beat the simple act of holding strong assets.",
      { left: 76, top: 282, width: 760, height: 88 },
      { fontSize: 24, color: colors.muted },
    );
    addPanel(slide, { left: 76, top: 452, width: 1040, height: 106 }, { fill: "#EEF6FF", line: "#B7D5FF" });
    addText(slide, "Core shift", { left: 106, top: 476, width: 160, height: 28 }, {
      fontSize: 18,
      bold: true,
      color: colors.blue,
    });
    addText(
      slide,
      "Use PCA less as a universal market-regime oracle and more as a participation filter around a narrow momentum hypothesis set.",
      { left: 260, top: 470, width: 810, height: 54 },
      { fontSize: 23, color: colors.ink },
    );
    addText(slide, "Research only. Not allocation evidence or live-execution approval.", { left: 76, top: 642, width: 740, height: 26 }, {
      fontSize: 15,
      color: colors.muted,
    });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "The broad engine is asking one PCA layer to solve too many market types");
    addPanel(slide, { left: 76, top: 206, width: 510, height: 318 }, { fill: "#FFF7ED", line: "#F2C48D" });
    addText(slide, "Current broad ambition", { left: 104, top: 232, width: 380, height: 32 }, {
      fontSize: 24,
      bold: true,
      color: colors.amber,
    });
    addBulletList(slide, [
      "Dynamic bull markets",
      "Quiet bull markets",
      "Sideways mean reversion",
      "Turbulent ranges and breakouts",
      "Rallies inside downtrends",
    ], { left: 108, top: 290, width: 420, height: 180 }, { dotColor: colors.amber, fontSize: 19 });

    addPanel(slide, { left: 662, top: 206, width: 486, height: 318 }, { fill: "#F3F4F6", line: "#D1D5DB" });
    addText(slide, "Observed bottleneck", { left: 690, top: 232, width: 360, height: 32 }, {
      fontSize: 24,
      bold: true,
      color: colors.ink,
    });
    addBulletList(slide, [
      "Positive tactical trades can still lag basket hold",
      "Upside windows expose underparticipation",
      "Large strategy grids make interpretation noisy",
      "Feature quality is hard to judge through one universal score",
    ], { left: 694, top: 292, width: 392, height: 180 }, { dotColor: colors.rose, fontSize: 19 });

    addText(
      slide,
      "The next useful question is not whether PCA can trade everything. It is whether PCA can help us participate better when the target opportunity is already defined.",
      { left: 102, top: 586, width: 1040, height: 62 },
      { fontSize: 25, bold: true, color: colors.ink, alignment: "center" },
    );
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "The specialist narrows the mandate to bullish high-beta participation");
    const y = 292;
    addFlowNode(slide, "Curate bullish high-beta assets", 90, y, 230, 92, "#E0F2FE", colors.blue);
    addArrow(slide, 332, y + 32, 402);
    addFlowNode(slide, "Build PCA participation states", 414, y, 230, 92, "#DCFCE7", colors.green);
    addArrow(slide, 656, y + 32, 726);
    addFlowNode(slide, "Route momentum-only hypotheses", 738, y, 230, 92, "#F3E8FF", colors.violet);
    addArrow(slide, 980, y + 32, 1050);
    addFlowNode(slide, "Audit against basket hold", 1062, y, 130, 92, "#FEF3C7", colors.amber);

    addPanel(slide, { left: 92, top: 460, width: 1100, height: 106 }, { fill: colors.soft, line: colors.line });
    addText(slide, "The specialization is intentional", { left: 122, top: 484, width: 390, height: 32 }, {
      fontSize: 24,
      bold: true,
      color: colors.ink,
    });
    addText(
      slide,
      "The engine can stay out of non-bullish conditions because an earlier selection layer has already chosen assets where upside participation is the point.",
      { left: 516, top: 480, width: 626, height: 60 },
      { fontSize: 22, color: colors.muted },
    );
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "The same PCA machinery gets a different job");
    addPanel(slide, { left: 82, top: 216, width: 522, height: 336 }, { fill: "#F8FAFC", line: "#CAD5E2" });
    addPanel(slide, { left: 676, top: 216, width: 522, height: 336 }, { fill: "#F0FDF4", line: "#A7F3D0" });
    addText(slide, "Universal router", { left: 120, top: 246, width: 380, height: 34 }, {
      fontSize: 27,
      bold: true,
      color: colors.ink,
    });
    addText(slide, "Momentum specialist", { left: 714, top: 246, width: 390, height: 34 }, {
      fontSize: 27,
      bold: true,
      color: colors.green,
    });
    addBulletList(slide, [
      "Each state may imply trend, mean reversion, breakout, risk-off, or noise",
      "Many strategy families compete downstream",
      "A state can be useful even when simple forward return looks poor",
      "Interpretation comes late and can be messy",
    ], { left: 122, top: 316, width: 404, height: 180 }, { dotColor: colors.muted, fontSize: 18 });
    addBulletList(slide, [
      "Each state asks whether bullish participation is favorable, stalled, extended, or risky",
      "Only momentum-compatible families compete",
      "Forward path metrics become more directly relevant",
      "Interpretation is narrower and easier to falsify",
    ], { left: 716, top: 316, width: 404, height: 180 }, { dotColor: colors.green, fontSize: 18 });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "This resembles how a real momentum trader narrows the problem");
    addPanel(slide, { left: 76, top: 212, width: 338, height: 318 }, { fill: "#EFF6FF", line: "#BFDBFE" });
    addPanel(slide, { left: 472, top: 212, width: 338, height: 318 }, { fill: "#F0FDF4", line: "#BBF7D0" });
    addPanel(slide, { left: 868, top: 212, width: 338, height: 318 }, { fill: "#FFF7ED", line: "#FED7AA" });
    addText(slide, "Screen first", { left: 104, top: 246, width: 250, height: 32 }, { fontSize: 25, bold: true, color: colors.blue });
    addText(slide, "Trade a list of liquid, strong, volatile assets rather than the whole market.", { left: 104, top: 308, width: 250, height: 112 }, { fontSize: 21, color: colors.ink });
    addText(slide, "Filter exposure", { left: 500, top: 246, width: 250, height: 32 }, { fontSize: 25, bold: true, color: colors.green });
    addText(slide, "Use trend, breadth, volatility, and risk context to decide when participation is still healthy.", { left: 500, top: 308, width: 250, height: 130 }, { fontSize: 21, color: colors.ink });
    addText(slide, "Benchmark honestly", { left: 896, top: 246, width: 260, height: 32 }, { fontSize: 25, bold: true, color: colors.amber });
    addText(slide, "A bullish specialist must compete with simply holding the bullish basket.", { left: 896, top: 308, width: 250, height: 112 }, { fontSize: 21, color: colors.ink });
    addText(slide, "The narrowing does not make the system less serious. It makes the hypothesis test cleaner.", { left: 148, top: 596, width: 984, height: 40 }, {
      fontSize: 26,
      bold: true,
      alignment: "center",
      color: colors.ink,
    });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "Feature sets should be audited through participation, not only point-to-point return");
    const cols = [
      ["State mechanics", ["Population", "Persistence", "Fold stability", "State transitions"], colors.blue],
      ["Forward path", ["Return", "Volatility", "Favorable excursion", "Adverse excursion"], colors.teal],
      ["Momentum fit", ["Family by state", "Spec stability", "Trend exposure", "No-trade discipline"], colors.violet],
      ["Portfolio replay", ["Live capital", "Basket alpha", "Time in market", "Trade tapes"], colors.amber],
    ];
    cols.forEach(([title, items, color], index) => {
      const x = 72 + index * 296;
      addPanel(slide, { left: x, top: 220, width: 260, height: 324 }, { fill: "#F8FAFC", line: "#D9E0EA" });
      addSmallLabel(slide, title, x + 20, 246, 220, color);
      addBulletList(slide, items, { left: x + 26, top: 312, width: 214, height: 160 }, { dotColor: color, fontSize: 18, lineHeight: 34 });
    });
    addText(slide, "The final judge remains strategy-conditioned replay, but cheaper diagnostics should explain why a feature set did or did not help.", { left: 126, top: 604, width: 1028, height: 54 }, {
      fontSize: 24,
      bold: true,
      alignment: "center",
      color: colors.ink,
    });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "The first run should be small enough to fail clearly");
    addPanel(slide, { left: 82, top: 206, width: 500, height: 360 }, { fill: "#F8FAFC", line: "#D7DEE8" });
    addPanel(slide, { left: 662, top: 206, width: 500, height: 360 }, { fill: "#F8FAFC", line: "#D7DEE8" });
    addText(slide, "Recommended baseline", { left: 116, top: 236, width: 340, height: 34 }, { fontSize: 27, bold: true, color: colors.ink });
    addBulletList(slide, [
      "Basket: AMD, NVDA, TSLA, AAPL, MSTR",
      "PCA: behavioral pool, 3x3 quantile states",
      "Context: active-plus-risk",
      "Families: implemented momentum candidates plus no-trade",
      "Accounting: true live-capital replay",
    ], { left: 118, top: 304, width: 390, height: 190 }, { dotColor: colors.blue, fontSize: 18, lineHeight: 34 });
    addText(slide, "Success diagnostics", { left: 696, top: 236, width: 340, height: 34 }, { fontSize: 27, bold: true, color: colors.green });
    addBulletList(slide, [
      "Benchmark-relative alpha versus equal-weight hold",
      "Upside capture during bullish windows",
      "Downside avoidance during stalls",
      "State and family heatmaps",
      "Representative trade tapes",
    ], { left: 698, top: 304, width: 390, height: 190 }, { dotColor: colors.green, fontSize: 18, lineHeight: 34 });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "The narrow specialist has clear weaknesses that should stay visible");
    addPanel(slide, { left: 80, top: 214, width: 526, height: 334 }, { fill: "#FFF1F2", line: "#FDA4AF" });
    addText(slide, "Main risks", { left: 116, top: 242, width: 300, height: 34 }, { fontSize: 27, bold: true, color: colors.rose });
    addBulletList(slide, [
      "Overfits to high-beta bull windows",
      "Exits too often and lags hold",
      "Selects assets after momentum is exhausted",
      "Fails in slow or range-bound markets",
      "Concentrates risk in a few themes",
    ], { left: 118, top: 306, width: 404, height: 184 }, { dotColor: colors.rose, fontSize: 18, lineHeight: 33 });
    addPanel(slide, { left: 674, top: 214, width: 526, height: 334 }, { fill: "#EFF6FF", line: "#BFDBFE" });
    addText(slide, "Guardrails", { left: 710, top: 242, width: 300, height: 34 }, { fontSize: 27, bold: true, color: colors.blue });
    addBulletList(slide, [
      "Keep benchmark hold as the primary comparator",
      "Separate curation, PCA states, and replay",
      "Do not add SMA or mean reversion yet",
      "Report failures as useful falsification",
      "Keep live bridge walled off",
    ], { left: 712, top: 306, width: 404, height: 184 }, { dotColor: colors.blue, fontSize: 18, lineHeight: 38 });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "The next decision is a research gate, not a performance conclusion");
    addPanel(slide, { left: 84, top: 218, width: 1090, height: 124 }, { fill: "#F0FDF4", line: "#A7F3D0" });
    addText(slide, "Default next slice", { left: 118, top: 244, width: 300, height: 32 }, { fontSize: 27, bold: true, color: colors.green });
    addText(slide, "Run the small momentum-specialist baseline and compare it to equal-weight basket hold with participation and trade-tape diagnostics.", { left: 420, top: 242, width: 700, height: 64 }, { fontSize: 23, color: colors.ink });

    addPanel(slide, { left: 84, top: 380, width: 1090, height: 210 }, { fill: "#F8FAFC", line: "#D7DEE8" });
    addText(slide, "STOP decisions before implementation", { left: 118, top: 416, width: 440, height: 32 }, { fontSize: 25, bold: true, color: colors.ink });
    addBulletList(slide, [
      "Confirm Gen5.3 naming for this research lane",
      "Exclude mean-reversion families from the first specialist baseline",
      "Defer SMA until EMA and breakout-only evidence exists",
      "Use hand-picked basket first, then add TRAIN-only curation",
    ], { left: 122, top: 464, width: 940, height: 120 }, { dotColor: colors.amber, fontSize: 18, lineHeight: 31 });

    addText(slide, "If the specialist cannot improve participation in its own chosen domain, the broader universal router should not be trusted to solve it by accident.", { left: 132, top: 626, width: 1016, height: 44 }, {
      fontSize: 24,
      bold: true,
      alignment: "center",
      color: colors.ink,
    });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "The feature-set screen keeps the mechanics fixed and changes only the PCA inputs");
    addPanel(slide, { left: 74, top: 204, width: 520, height: 350 }, { fill: "#EFF6FF", line: "#BFDBFE" });
    addText(slide, "Held fixed", { left: 108, top: 236, width: 360, height: 32 }, { fontSize: 27, bold: true, color: colors.blue });
    addBulletList(slide, [
      "High-beta basket: AMD, NVDA, TSLA, AAPL, MSTR",
      "Context: basket + SPY/QQQ/IWM/SMH/TLT/GLD",
      "PCA: behavioral-pool, 3x3 quantile states",
      "Policy: pooled-family asset-variant",
      "Families: EMA, breakout, pullback, volatility breakout, no-trade",
    ], { left: 110, top: 298, width: 410, height: 200 }, { dotColor: colors.blue, fontSize: 18, lineHeight: 34 });

    addPanel(slide, { left: 682, top: 204, width: 520, height: 350 }, { fill: "#F0FDF4", line: "#A7F3D0" });
    addText(slide, "Varied deliberately", { left: 716, top: 236, width: 360, height: 32 }, { fontSize: 27, bold: true, color: colors.green });
    addBulletList(slide, [
      "Workhorse enriched",
      "Momentum participation",
      "Momentum plus stress",
      "Same strategy grid and replay semantics for every lane",
      "Same equal-weight basket-hold benchmark",
    ], { left: 718, top: 306, width: 410, height: 176 }, { dotColor: colors.green, fontSize: 18, lineHeight: 34 });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "Each feature set asks a different question about bullish participation");
    const featureCards = [
      ["Workhorse enriched", "Can the existing broad Gen5 state surface do the job without modification?", "#EFF6FF", colors.blue],
      ["Momentum participation", "Can trend strength, impulse, persistence, range location, drawdown, and recovery sharpen entries?", "#ECFDF5", colors.green],
      ["Momentum plus stress", "Can the participation surface improve upside while keeping volatility and stress context for drawdown windows?", "#FFF7ED", colors.amber],
    ];
    featureCards.forEach(([title, body, fill, color], index) => {
      const x = 74 + index * 394;
      addPanel(slide, { left: x, top: 218, width: 342, height: 286 }, { fill, line: "#D7DEE8" });
      addText(slide, title, { left: x + 26, top: 246, width: 286, height: 54 }, { fontSize: 25, bold: true, color });
      addText(slide, body, { left: x + 26, top: 326, width: 286, height: 126 }, { fontSize: 20, color: colors.ink });
    });
    addText(slide, "The feature taxonomy CSV records the exact columns used in each lane, so the interpretation does not depend on memory.", { left: 130, top: 592, width: 1020, height: 44 }, { fontSize: 23, bold: true, color: colors.ink, alignment: "center" });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "Momentum plus stress improved upside capture without losing the stress-window protection");
    addPanel(slide, { left: 72, top: 210, width: 270, height: 140 }, { fill: "#FFF1F2", line: "#FDA4AF" });
    addText(slide, pp(stressCont2020.alpha_vs_active_equal), { left: 96, top: 238, width: 210, height: 46 }, { fontSize: 34, bold: true, color: colors.rose, alignment: "center" });
    addText(slide, "Momentum+stress continuation alpha in 2020Q3", { left: 98, top: 292, width: 210, height: 48 }, { fontSize: 16, color: colors.muted, alignment: "center" });
    addPanel(slide, { left: 72, top: 390, width: 270, height: 140 }, { fill: "#ECFDF5", line: "#A7F3D0" });
    addText(slide, pp(stressCont2022.alpha_vs_active_equal), { left: 96, top: 418, width: 210, height: 46 }, { fontSize: 34, bold: true, color: colors.green, alignment: "center" });
    addText(slide, "Momentum+stress continuation alpha in 2022Q1", { left: 98, top: 472, width: 210, height: 48 }, { fontSize: 16, color: colors.muted, alignment: "center" });
    addPanel(slide, { left: 374, top: 210, width: 270, height: 140 }, { fill: "#F8FAFC", line: "#CBD5E1" });
    addText(slide, pct(stressCont2020.mean_open_position_fraction), { left: 398, top: 238, width: 210, height: 46 }, { fontSize: 34, bold: true, color: colors.teal, alignment: "center" });
    addText(slide, "Momentum+stress exposure in 2020Q3", { left: 400, top: 292, width: 210, height: 48 }, { fontSize: 16, color: colors.muted, alignment: "center" });
    addPanel(slide, { left: 374, top: 390, width: 270, height: 140 }, { fill: "#F8FAFC", line: "#CBD5E1" });
    addText(slide, pct(stressCont2022.mean_open_position_fraction), { left: 398, top: 418, width: 210, height: 46 }, { fontSize: 34, bold: true, color: colors.teal, alignment: "center" });
    addText(slide, "Momentum+stress exposure in 2022Q1", { left: 400, top: 472, width: 210, height: 48 }, { fontSize: 16, color: colors.muted, alignment: "center" });
    await addImage(slide, resultPaths.heatmap, { left: 682, top: 190, width: 500, height: 392 }, "Gen5.3 alpha heatmap versus equal-weight basket hold");
    addText(slide, `Against workhorse continuation, momentum+stress improved mean alpha from ${pp(aggWorkhorseCont.mean_alpha_vs_active_equal)} to ${pp(aggStressCont.mean_alpha_vs_active_equal)}. It is still not benchmark-beating, but the feature layer moved in the desired direction.`, { left: 104, top: 596, width: 1060, height: 58 }, { fontSize: 21, bold: true, color: colors.ink, alignment: "center" });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "The audit points to participation timing, not just strategy availability");
    await addImage(slide, resultPaths.equity, { left: 46, top: 190, width: 650, height: 430 }, "Gen5.3 bullish momentum specialist equity overlay");
    await addImage(slide, resultPaths.family, { left: 722, top: 196, width: 500, height: 340 }, "Selected strategy family by asset and PCA state");
    addText(slide, "The challenger improved participation but still lagged basket hold. That means the feature layer is probably relevant, but not sufficient by itself. The next useful tests should confirm across more windows and inspect whether entries remain late.", { left: 742, top: 554, width: 440, height: 86 }, { fontSize: 18, color: colors.muted });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "Representative trade tapes show the system joined the move but did not stay with enough of it");
    await addImage(slide, resultPaths.representativeTapes, { left: 50, top: 178, width: 780, height: 455 }, "Representative Gen5.3 2020Q3 continuation trade tapes");
    addPanel(slide, { left: 864, top: 206, width: 320, height: 338 }, { fill: "#F8FAFC", line: "#D7DEE8" });
    addText(slide, "What to look for", { left: 894, top: 236, width: 250, height: 30 }, { fontSize: 25, bold: true, color: colors.ink });
    addBulletList(slide, [
      "Blue markers are entries; yellow markers are exits.",
      "Dashed lines trace completed or open trades.",
      "State bands often change after the trend is underway.",
      "Continuation helps, but it still misses part of the move.",
    ], { left: 896, top: 296, width: 248, height: 210 }, { dotColor: colors.amber, fontSize: 15, lineHeight: 52 });
    addText(slide, "For exploratory POCs, include representative trade tapes whenever timing, participation, or state behavior is central.", { left: 118, top: 648, width: 980, height: 30 }, { fontSize: 18, bold: true, color: colors.ink, alignment: "center" });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = colors.canvas;
    addTitle(slide, "Next Gen5.3 slice: confirm the feature signal before widening the grid");
    addPanel(slide, { left: 82, top: 214, width: 1090, height: 330 }, { fill: "#F8FAFC", line: "#D7DEE8" });
    addText(slide, "Recommended next question", { left: 120, top: 248, width: 430, height: 34 }, { fontSize: 27, bold: true, color: colors.ink });
    addText(slide, "The first challenger moved in the right direction, but it still did not beat the high-beta basket hold. The next question is whether that improvement survives more windows and whether the trade tapes show earlier participation.", { left: 120, top: 312, width: 940, height: 78 }, { fontSize: 25, color: colors.ink });
    addBulletList(slide, [
      "Keep momentum plus stress as the leading feature challenger.",
      "Add several adjacent and non-adjacent high-beta windows before changing strategy parameters.",
      "Use representative trade tapes to verify whether entries actually move earlier.",
    ], { left: 124, top: 430, width: 940, height: 100 }, { dotColor: colors.amber, fontSize: 18, lineHeight: 32 });
    addText(slide, "A wider strategy grid is still a later confirmation tool. Right now the higher-signal question is whether the state features consistently improve timing.", { left: 128, top: 610, width: 1010, height: 42 }, { fontSize: 20, bold: true, color: colors.ink, alignment: "center" });
  }

  return deck;
}

await fs.mkdir(path.dirname(outputPptx), { recursive: true });
await fs.mkdir(previewDir, { recursive: true });
const deck = await createDeck();

for (const [index, slide] of deck.slides.items.entries()) {
  const stem = `slide-${String(index + 1).padStart(2, "0")}`;
  await writeBlob(path.join(previewDir, `${stem}.png`), await deck.export({ slide, format: "png", scale: 1 }));
  const layout = await slide.export({ format: "layout" });
  await fs.writeFile(path.join(previewDir, `${stem}.layout.json`), await layout.text(), "utf8");
}

await writeBlob(montagePath, await deck.export({ format: "webp", montage: true, scale: 1 }));
const inspect = await deck.inspect({ kind: "slide,textbox,shape,chart,table,image", maxChars: 20000 });
await fs.writeFile(inspectPath, inspect.ndjson, "utf8");
const pptx = await PresentationFile.exportPptx(deck);
await pptx.save(outputPptx);

console.log(`Wrote ${outputPptx}`);
console.log(`Wrote ${montagePath}`);
console.log(`Wrote ${inspectPath}`);
