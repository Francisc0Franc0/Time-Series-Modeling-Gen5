import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const artifactModule =
  process.env.ARTIFACT_TOOL_MODULE ||
  "C:/Users/Franc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactModule).href);

const outputPptx = path.join(repoRoot, "presentations", "gen5_3_momentum_context_size_screen.pptx");
const previewDir = path.join(repoRoot, "presentations", "gen5_3_momentum_context_size_screen_slides");
const montagePath = path.join(repoRoot, "presentations", "gen5_3_momentum_context_size_screen_montage.webp");
const inspectPath = path.join(repoRoot, "presentations", "gen5_3_momentum_context_size_screen.pptx.inspect.ndjson");
const resultDir = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "gen53_momentum_context_size",
  "g53_momctx_20260710ctxsize",
);

const resultPaths = {
  summary: path.join(resultDir, "momentum_context_size_summary.csv"),
  aggregate: path.join(resultDir, "momentum_context_size_aggregate.csv"),
  taxonomy: path.join(resultDir, "momentum_context_size_feature_taxonomy.csv"),
  report: path.join(resultDir, "momentum_context_size_report.md"),
  heatmap: path.join(resultDir, "momentum_context_size_alpha_heatmap.png"),
  equity: path.join(resultDir, "momentum_context_size_equity_overlay.png"),
  exposure: path.join(resultDir, "momentum_context_size_exposure_alpha_scatter.png"),
  family: path.join(resultDir, "momentum_context_size_selection_family_heatmap.png"),
  tapes: path.join(resultDir, "momentum_context_size_trade_tape_contact_sheet.png"),
  representativeTapes: path.join(resultDir, "momentum_context_size_representative_trade_tapes.png"),
};

const W = 1280;
const H = 720;
const page = { left: 54, top: 44, width: 1172, height: 626 };
const colors = {
  ink: "#000000",
  muted: "#555555",
  soft: "#EDEDED",
  softer: "#F7F7F7",
  rule: "#B8BCC4",
  orange: "#FF6B35",
  red: "#B42318",
  green: "#067647",
  blue: "#175CD3",
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

function text(slide, value, position, style = {}) {
  const shape = slide.shapes.add({
    geometry: "textbox",
    position,
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = value;
  shape.text.style = {
    fontSize: style.fontSize ?? 20,
    color: style.color ?? colors.ink,
    bold: style.bold ?? false,
    alignment: style.alignment,
  };
  return shape;
}

function rect(slide, position, fill = colors.soft, line = "none") {
  return slide.shapes.add({
    geometry: "rect",
    position,
    fill,
    line: { style: "solid", fill: line, width: line === "none" ? 0 : 1 },
  });
}

function title(slide, value, kicker = "GEN5.3 MOMENTUM CONTEXT-SIZE SCREEN") {
  text(slide, kicker, { left: page.left, top: 28, width: 620, height: 24 }, { fontSize: 14, bold: true, color: colors.muted });
  text(slide, value, { left: page.left, top: 66, width: 1080, height: 104 }, { fontSize: 38, bold: true });
  rect(slide, { left: page.left, top: 170, width: page.width, height: 1 }, colors.rule, colors.rule);
}

function footer(slide, value = "Research/inspection only. Not allocation evidence or live-advice behavior.") {
  text(slide, value, { left: page.left, top: 680, width: page.width, height: 22 }, { fontSize: 12, color: colors.muted });
}

function bullets(slide, items, position, opts = {}) {
  const lineHeight = opts.lineHeight ?? 34;
  items.forEach((item, index) => {
    const y = position.top + index * lineHeight;
    rect(slide, { left: position.left, top: y + 10, width: 8, height: 8 }, opts.dotColor ?? colors.orange, opts.dotColor ?? colors.orange);
    text(slide, item, { left: position.left + 22, top: y, width: position.width - 22, height: lineHeight + 6 }, {
      fontSize: opts.fontSize ?? 19,
      color: opts.color ?? colors.ink,
    });
  });
}

async function image(slide, filePath, position, alt) {
  slide.images.add({
    blob: await fs.readFile(filePath),
    contentType: "image/png",
    alt,
    fit: "contain",
    position,
  });
}

function metric(slide, label, value, x, y, w, color = colors.ink) {
  rect(slide, { left: x, top: y, width: w, height: 112 }, colors.soft, colors.rule);
  text(slide, value, { left: x + 16, top: y + 18, width: w - 32, height: 46 }, { fontSize: 34, bold: true, color, alignment: "center" });
  text(slide, label, { left: x + 14, top: y + 70, width: w - 28, height: 34 }, { fontSize: 15, color: colors.muted, alignment: "center" });
}

function contextLabel(id) {
  if (id === "hb_self_5") return "Live basket only";
  if (id === "hb_peer_12") return "Live + high-beta peers";
  if (id === "hb_risk_aware_18") return "Live + peers + risk anchors";
  return id;
}

function shortReplay(value) {
  return value === "state_switch_continuation" ? "continuation" : "fresh";
}

function addTopTable(slide, rows) {
  const x = 78;
  const y = 250;
  const widths = [230, 230, 122, 118, 118, 112, 108];
  const headers = ["Context", "Feature", "Replay", "Win years", "Mean ret.", "Mean alpha", "Exposure"];
  let left = x;
  headers.forEach((header, index) => {
    rect(slide, { left, top: y, width: widths[index], height: 36 }, colors.soft, colors.rule);
    text(slide, header, { left: left + 8, top: y + 8, width: widths[index] - 16, height: 22 }, { fontSize: 14, bold: true });
    left += widths[index];
  });
  rows.slice(0, 5).forEach((row, rowIndex) => {
    left = x;
    const yy = y + 36 + rowIndex * 54;
    const vals = [
      contextLabel(row.context_id),
      row.feature_set_label,
      shortReplay(row.entry_replay_semantics),
      `${row.windows_beating_basket}/4`,
      pct(row.mean_total_return),
      pp(row.mean_alpha_vs_active_equal),
      pct(row.mean_exposure),
    ];
    vals.forEach((value, index) => {
      rect(slide, { left, top: yy, width: widths[index], height: 54 }, rowIndex % 2 ? "#FFFFFF" : colors.softer, colors.rule);
      text(slide, value, { left: left + 8, top: yy + 13, width: widths[index] - 16, height: 28 }, { fontSize: 15, color: index === 5 ? colors.red : colors.ink });
      left += widths[index];
    });
  });
}

async function createDeck() {
  const deck = Presentation.create({ slideSize: { width: W, height: H } });
  const aggregate = await readCsv(resultPaths.aggregate);
  const summary = await readCsv(resultPaths.summary);
  const topRows = [...aggregate].sort((a, b) => num(b.mean_alpha_vs_active_equal) - num(a.mean_alpha_vs_active_equal));
  const best = topRows[0];
  const best2019 = summary.find((x) => x.context_id === "hb_risk_aware_18" && x.feature_set_id === "workhorse_enriched" && x.entry_replay_semantics === "state_switch_continuation" && x.window_id === "2019Y_asof_20191231");
  const best2020 = summary.find((x) => x.context_id === "hb_risk_aware_18" && x.feature_set_id === "workhorse_enriched" && x.entry_replay_semantics === "state_switch_continuation" && x.window_id === "2020Y_asof_20201231");
  const best2022 = summary.find((x) => x.context_id === "hb_risk_aware_18" && x.feature_set_id === "workhorse_enriched" && x.entry_replay_semantics === "state_switch_continuation" && x.window_id === "2022Y_asof_20221231");
  const best2024 = summary.find((x) => x.context_id === "hb_risk_aware_18" && x.feature_set_id === "workhorse_enriched" && x.entry_replay_semantics === "state_switch_continuation" && x.window_id === "2024Y_asof_20241231");

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    text(slide, "GEN5.3 RESEARCH SCREEN", { left: 60, top: 60, width: 520, height: 26 }, { fontSize: 15, bold: true, color: colors.muted });
    text(slide, "Annual windows made the momentum-specialist question sharper", { left: 60, top: 130, width: 900, height: 126 }, { fontSize: 54, bold: true });
    text(slide, "The first one-year context-size screen suggests the best current lane is not the newest feature set. It is broader risk-aware context, the existing workhorse PCA surface, and continuation replay.", { left: 64, top: 310, width: 820, height: 92 }, { fontSize: 25, color: colors.muted });
    rect(slide, { left: 64, top: 512, width: 1030, height: 1 }, colors.rule, colors.rule);
    text(slide, "Packet: runs/research_workbench/gen53_momentum_context_size/g53_momctx_20260710ctxsize", { left: 64, top: 542, width: 990, height: 28 }, { fontSize: 16, color: colors.muted });
    footer(slide);
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    title(slide, "The test changed because one quarter was too sparse");
    text(slide, "The prior slices were useful for mechanics, but they did not give much OOS surface area: a five-symbol live basket can easily look good or bad from a handful of trades in one quarter.", { left: 76, top: 212, width: 540, height: 132 }, { fontSize: 25 });
    rect(slide, { left: 702, top: 206, width: 444, height: 106 }, colors.soft, colors.rule);
    rect(slide, { left: 702, top: 356, width: 444, height: 146 }, colors.soft, colors.rule);
    text(slide, "Before", { left: 732, top: 228, width: 160, height: 26 }, { fontSize: 22, bold: true, color: colors.red });
    text(slide, "One OOS quarter. Faster, but low resolution for alpha and trade behavior.", { left: 732, top: 262, width: 350, height: 34 }, { fontSize: 18, color: colors.muted });
    text(slide, "Now", { left: 732, top: 380, width: 160, height: 26 }, { fontSize: 22, bold: true, color: colors.green });
    text(slide, "Four independent quarterly TRAIN authorities stitched into a one-year OOS/accounting window.", { left: 732, top: 416, width: 350, height: 52 }, { fontSize: 18, color: colors.muted });
    text(slide, "This keeps the leakage boundary while making each condition easier to judge.", { left: 108, top: 582, width: 1040, height: 44 }, { fontSize: 28, bold: true, alignment: "center" });
    footer(slide);
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    title(slide, "The screen isolates a narrow EMA-only participation hypothesis");
    const cols = [
      ["Live basket", "AMD, NVDA, TSLA, MSTR, AVGO"],
      ["Context axis", "5 self assets; 12 with high-beta peers; 18 with peers and risk anchors"],
      ["Feature axis", "Workhorse enriched; momentum participation; momentum plus stress; market-relative momentum"],
      ["Strategy pool", "EMA cross, EMA trend, no-trade, no-trade exit-immediate"],
    ];
    cols.forEach(([head, body], index) => {
      const x = 74 + index * 286;
      rect(slide, { left: x, top: 222, width: 250, height: 244 }, colors.soft, colors.rule);
      text(slide, head, { left: x + 18, top: 246, width: 210, height: 30 }, { fontSize: 23, bold: true });
      text(slide, body, { left: x + 18, top: 308, width: 208, height: 112 }, { fontSize: 19, color: colors.muted });
    });
    text(slide, "Selection policy stayed fixed at pooled-family asset-variant, so this slice asks about feature design, context size, and replay semantics rather than reopening the whole Gen4-vs-Gen5 selection debate.", { left: 100, top: 558, width: 1040, height: 58 }, { fontSize: 21, bold: true, alignment: "center" });
    footer(slide);
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    title(slide, "The best aggregate lane was risk-aware context plus the workhorse feature set");
    rect(slide, { left: 78, top: 196, width: 1038, height: 38 }, colors.soft, colors.rule);
    text(slide, `Best lane: ${contextLabel(best.context_id)} + ${best.feature_set_label} + ${shortReplay(best.entry_replay_semantics)}. Mean return ${pct(best.mean_total_return)}, mean alpha ${pp(best.mean_alpha_vs_active_equal)}, exposure ${pct(best.mean_exposure)}.`, { left: 96, top: 205, width: 1000, height: 22 }, { fontSize: 17, bold: true });
    addTopTable(slide, topRows);
    text(slide, "Even the best lane did not beat equal-weight high-beta hold on average. The signal is subtler: broader risk-aware context made the specialist less bad against a very hard benchmark and produced positive alpha in two annual windows.", { left: 92, top: 592, width: 1060, height: 50 }, { fontSize: 21, bold: true, alignment: "center" });
    footer(slide);
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    title(slide, "The annual heatmap shows why this is not a simple feature-set win");
    await image(slide, resultPaths.heatmap, { left: 44, top: 178, width: 690, height: 486 }, "Alpha heatmap versus equal-weight basket hold");
    rect(slide, { left: 790, top: 214, width: 360, height: 284 }, colors.soft, colors.rule);
    text(slide, "What matters", { left: 822, top: 242, width: 260, height: 32 }, { fontSize: 26, bold: true });
    bullets(slide, [
      "2020 remains punishing because basket hold returned about 227%.",
      "2022 rewards staying out of a falling high-beta basket.",
      "2024 is the clean positive clue for risk-aware workhorse continuation.",
      "New momentum feature sets did not become the aggregate default.",
    ], { left: 824, top: 302, width: 286, height: 170 }, { fontSize: 16, lineHeight: 44, dotColor: colors.orange });
    footer(slide);
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    title(slide, "The best lane still tells a mixed window-by-window story");
    const years = [
      ["2019", pp(best2019.alpha_vs_active_equal), pct(best2019.total_return), pct(best2019.active_equal_return)],
      ["2020", pp(best2020.alpha_vs_active_equal), pct(best2020.total_return), pct(best2020.active_equal_return)],
      ["2022", pp(best2022.alpha_vs_active_equal), pct(best2022.total_return), pct(best2022.active_equal_return)],
      ["2024", pp(best2024.alpha_vs_active_equal), pct(best2024.total_return), pct(best2024.active_equal_return)],
    ];
    years.forEach(([year, alpha, ret, hold], index) => {
      const x = 86 + index * 286;
      rect(slide, { left: x, top: 220, width: 242, height: 240 }, colors.soft, colors.rule);
      text(slide, year, { left: x + 22, top: 244, width: 180, height: 38 }, { fontSize: 32, bold: true });
      text(slide, alpha, { left: x + 22, top: 306, width: 190, height: 44 }, { fontSize: 31, bold: true, color: alpha.startsWith("+") ? colors.green : colors.red });
      text(slide, "alpha vs basket", { left: x + 24, top: 356, width: 170, height: 24 }, { fontSize: 15, color: colors.muted });
      text(slide, `strategy ${ret}`, { left: x + 24, top: 402, width: 170, height: 24 }, { fontSize: 17 });
      text(slide, `basket ${hold}`, { left: x + 24, top: 430, width: 170, height: 24 }, { fontSize: 17, color: colors.muted });
    });
    text(slide, "Annual windows reveal a useful profile: strong 2024 participation and decent 2022 defense, but still serious undercapture in 2019 and 2020 high-beta upside.", { left: 118, top: 570, width: 1010, height: 56 }, { fontSize: 23, bold: true, alignment: "center" });
    footer(slide);
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    title(slide, "Exposure helps, but simply being long more is not the whole answer");
    await image(slide, resultPaths.exposure, { left: 70, top: 178, width: 700, height: 460 }, "Exposure versus basket-relative alpha scatter");
    rect(slide, { left: 828, top: 238, width: 330, height: 256 }, colors.soft, colors.rule);
    text(slide, "Readout", { left: 858, top: 268, width: 240, height: 32 }, { fontSize: 26, bold: true });
    text(slide, "Continuation generally lifts exposure, and the better lanes cluster at moderate-to-high participation. But many high-exposure points are still deeply negative versus basket hold, so timing and state discrimination still matter.", { left: 858, top: 326, width: 260, height: 118 }, { fontSize: 19, color: colors.muted });
    footer(slide);
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    title(slide, "The best lane beats in 2022 and 2024, but misses the big upside years");
    slide.charts.add("bar", {
      position: { left: 88, top: 210, width: 690, height: 378 },
      categories: ["2019", "2020", "2022", "2024"],
      series: [
        {
          name: "Strategy",
          values: [num(best2019.total_return) * 100, num(best2020.total_return) * 100, num(best2022.total_return) * 100, num(best2024.total_return) * 100],
          fill: colors.orange,
        },
        {
          name: "Basket hold",
          values: [num(best2019.active_equal_return) * 100, num(best2020.active_equal_return) * 100, num(best2022.active_equal_return) * 100, num(best2024.active_equal_return) * 100],
          fill: colors.ink,
        },
      ],
      hasLegend: true,
      yAxis: {
        majorGridlines: { style: "solid", fill: colors.rule, width: 1 },
      },
      dataLabels: { showValue: true, position: "outEnd" },
    });
    rect(slide, { left: 846, top: 226, width: 306, height: 292 }, colors.soft, colors.rule);
    text(slide, "What the chart adds", { left: 876, top: 256, width: 240, height: 32 }, { fontSize: 24, bold: true });
    bullets(slide, [
      "In 2020, the benchmark was too strong for a timing layer to catch.",
      "In 2022, the system's partial exposure was valuable.",
      "In 2024, the same lane finally beat the high-beta basket while still trading selectively.",
    ], { left: 878, top: 318, width: 232, height: 158 }, { fontSize: 16, lineHeight: 50, dotColor: colors.orange });
    footer(slide);
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    title(slide, "The authority map is cash-dominant, which explains part of the underparticipation");
    await image(slide, resultPaths.family, { left: 62, top: 188, width: 700, height: 430 }, "Selected strategy family by asset and PCA state");
    rect(slide, { left: 812, top: 228, width: 338, height: 268 }, colors.soft, colors.rule);
    text(slide, "Sanity check", { left: 842, top: 258, width: 240, height: 32 }, { fontSize: 26, bold: true });
    text(slide, "Across the full annual screen, no-trade remains the dominant selected authority in many asset-state cells. That is philosophically clean for a specialist, but it also means missed upside is expected unless the favorable states are timely and persistent.", { left: 842, top: 320, width: 270, height: 128 }, { fontSize: 19, color: colors.muted });
    footer(slide);
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    title(slide, "Representative tapes show both the promise and the weakness");
    await image(slide, resultPaths.representativeTapes, { left: 42, top: 172, width: 780, height: 500 }, "Representative trade tapes for risk-aware workhorse 2024 continuation");
    rect(slide, { left: 866, top: 210, width: 300, height: 336 }, colors.soft, colors.rule);
    text(slide, "Visual audit", { left: 896, top: 240, width: 220, height: 32 }, { fontSize: 26, bold: true });
    bullets(slide, [
      "AMD shows churn and missed/stopped participation.",
      "NVDA, TSLA, and MSTR show the lane can ride substantial trends.",
      "Open exit signals at year end should be inspected in the next tape audit.",
    ], { left: 898, top: 306, width: 236, height: 176 }, { fontSize: 16, lineHeight: 54, dotColor: colors.orange });
    footer(slide);
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    title(slide, "The annual screen changes the next research question");
    rect(slide, { left: 86, top: 210, width: 470, height: 286 }, colors.soft, colors.rule);
    rect(slide, { left: 676, top: 210, width: 470, height: 286 }, colors.soft, colors.rule);
    text(slide, "Do not chase yet", { left: 122, top: 244, width: 320, height: 34 }, { fontSize: 28, bold: true, color: colors.red });
    bullets(slide, [
      "Do not promote the new momentum feature sets as defaults.",
      "Do not treat positive 2024 alpha as allocation evidence.",
      "Do not widen the strategy grid until the state layer looks cleaner.",
    ], { left: 124, top: 310, width: 360, height: 138 }, { fontSize: 18, lineHeight: 44, dotColor: colors.red });
    text(slide, "Do probe next", { left: 712, top: 244, width: 320, height: 34 }, { fontSize: 28, bold: true, color: colors.green });
    bullets(slide, [
      "Use risk-aware context plus workhorse as the near-term control.",
      "Audit full trade tapes for 2024 and missed upside in 2020.",
      "Test whether annual windows need true cross-quarter continuity, not only stitched quarterly authorities.",
    ], { left: 714, top: 310, width: 360, height: 138 }, { fontSize: 18, lineHeight: 44, dotColor: colors.green });
    text(slide, "The core lesson is methodological: longer OOS windows are now the default for alpha-oriented screens because sparse one-quarter results were too easy to overread.", { left: 122, top: 584, width: 1016, height: 54 }, { fontSize: 23, bold: true, alignment: "center" });
    footer(slide);
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
