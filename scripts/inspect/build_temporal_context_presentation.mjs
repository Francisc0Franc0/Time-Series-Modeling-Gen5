import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const defaultArtifactModule =
  "C:/Users/Franc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";
const artifactModule = process.env.ARTIFACT_TOOL_MODULE || defaultArtifactModule;
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactModule).href);

const outDir = path.join(repoRoot, "outputs");
const recentSummaryDir = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "context_universe_factorial_temporal_summaries",
  "ctxfac_temporal_context_replication_20241231_20260623"
);
const recentRankCsv = path.join(recentSummaryDir, "temporal_context_replication_rank_summary.csv");
const recentMetricsPng = path.join(recentSummaryDir, "temporal_context_replication_metrics.png");
const coverageCsv = path.join(repoRoot, "runs", "data_refresh", "alpaca_daily_symbol_coverage_20260623.csv");
const completedWindows = [
  {
    label: "2021-03-31",
    asOf: "2021-03-31 17:30",
    dir: path.join(
      repoRoot,
      "runs",
      "research_workbench",
      "context_universe_factorials",
      "ctxfac_A5_5f_3u_2s_temporalctx_20210331_20210331173000"
    ),
    vxxRows: "806 / 1054",
  },
  {
    label: "2021-06-30",
    asOf: "2021-06-30 17:30",
    dir: path.join(
      repoRoot,
      "runs",
      "research_workbench",
      "context_universe_factorials",
      "ctxfac_A5_5f_3u_2s_temporalctx_20210630_20210630173000"
    ),
    vxxRows: "869 / 1054",
  },
];

const finalPptx = path.join(outDir, "gen5_temporal_context_replication_summary_sip_refresh.pptx");
const inspectPath = path.join(outDir, "gen5_temporal_context_replication_summary_sip_refresh.pptx.inspect.ndjson");
const montagePath = path.join(outDir, "gen5_temporal_context_replication_summary_sip_refresh_montage.webp");
const slidePreviewDir = path.join(outDir, "gen5_temporal_context_replication_summary_sip_refresh_slides");

function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = "";
  let quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    const next = text[i + 1];
    if (quoted) {
      if (ch === '"' && next === '"') {
        field += '"';
        i += 1;
      } else if (ch === '"') {
        quoted = false;
      } else {
        field += ch;
      }
    } else if (ch === '"') {
      quoted = true;
    } else if (ch === ",") {
      row.push(field);
      field = "";
    } else if (ch === "\n") {
      row.push(field);
      rows.push(row);
      row = [];
      field = "";
    } else if (ch !== "\r") {
      field += ch;
    }
  }
  if (field.length || row.length) {
    row.push(field);
    rows.push(row);
  }
  const header = rows.shift();
  if (!header) return [];
  return rows
    .filter((r) => r.length === header.length)
    .map((r) => Object.fromEntries(header.map((h, idx) => [h, r[idx]])));
}

async function readCsv(filePath) {
  return parseCsv(await fs.readFile(filePath, "utf8"));
}

function pct(value, digits = 0) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "";
  return `${(n * 100).toFixed(digits)}%`;
}

function num(value, digits = 2) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "";
  return n.toFixed(digits);
}

function surfaceLabel(surfaceId) {
  if (surfaceId.includes("quantile_grid_3x3")) return "3x3 quantile";
  if (surfaceId.includes("kmeans_k9")) return "k-means k9";
  return surfaceId.replace("behavioral_pool_", "").replaceAll("_", " ");
}

function universeLabel(universeId) {
  return universeId
    .replace("_context", "")
    .replace("active_plus_risk", "active + risk")
    .replace("active_self", "active self")
    .replace("ex_active_market_risk", "ex-active risk");
}

function conditionLabel(row) {
  return `${universeLabel(row.universe_id)} / ${surfaceLabel(row.surface_id)}`;
}

function addText(slide, text, left, top, width, height, style = {}) {
  const shape = slide.shapes.add({
    geometry: "textbox",
    position: { left, top, width, height },
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = text;
  shape.text.style = {
    fontSize: style.fontSize || 22,
    color: style.color || "slate-800",
    bold: Boolean(style.bold),
    italic: Boolean(style.italic),
    alignment: style.alignment || "left",
  };
  return shape;
}

function addTitle(slide, title, kicker = "Gen5.1 research inspection") {
  addText(slide, kicker.toUpperCase(), 72, 44, 780, 28, {
    fontSize: 14,
    color: "slate-500",
    bold: true,
  });
  addText(slide, title, 72, 80, 1040, 90, {
    fontSize: 37,
    color: "slate-950",
    bold: true,
  });
}

function addRule(slide) {
  slide.shapes.add({
    geometry: "rect",
    position: { left: 72, top: 178, width: 1136, height: 2 },
    fill: "slate-200",
    line: { style: "solid", fill: "none", width: 0 },
  });
}

function addBodyLine(slide, text, left, top, width, fontSize = 19, color = "slate-800") {
  addText(slide, "-", left, top, 20, 26, {
    fontSize,
    color: "teal-700",
    bold: true,
  });
  addText(slide, text, left + 28, top, width - 28, 44, {
    fontSize,
    color,
  });
}

function addBulletList(slide, items, left, top, width, fontSize = 20, gap = 56) {
  items.forEach((item, idx) => addBodyLine(slide, item, left, top + idx * gap, width, fontSize));
}

function addNarrativeColumn(slide, label, items, left, top, width, accent = "teal-700") {
  slide.shapes.add({
    geometry: "rect",
    position: { left, top, width, height: 36 },
    fill: "slate-100",
    line: { style: "solid", fill: "slate-200", width: 1 },
  });
  addText(slide, label.toUpperCase(), left + 14, top + 9, width - 28, 20, {
    fontSize: 12,
    color: accent,
    bold: true,
  });
  items.forEach((item, idx) => {
    addText(slide, item, left + 4, top + 54 + idx * 64, width - 8, 52, {
      fontSize: 17,
      color: "slate-800",
    });
  });
}

function addMetricCard(slide, label, value, note, left, top, width, height = 118) {
  slide.shapes.add({
    geometry: "roundRect",
    position: { left, top, width, height },
    fill: "white",
    line: { style: "solid", fill: "slate-200", width: 1 },
    borderRadius: "rounded-lg",
  });
  addText(slide, label.toUpperCase(), left + 20, top + 18, width - 40, 20, {
    fontSize: 12,
    color: "slate-500",
    bold: true,
  });
  addText(slide, value, left + 20, top + 42, width - 40, 36, {
    fontSize: 28,
    color: "slate-950",
    bold: true,
  });
  addText(slide, note, left + 20, top + 82, width - 40, height - 88, {
    fontSize: 15,
    color: "slate-600",
  });
}

function addSimpleTable(slide, columns, rows, left, top, widths, rowHeight = 38, fontSize = 13) {
  const totalWidth = widths.reduce((a, b) => a + b, 0);
  slide.shapes.add({
    geometry: "rect",
    position: { left, top, width: totalWidth, height: rowHeight },
    fill: "slate-100",
    line: { style: "solid", fill: "slate-200", width: 1 },
  });
  let x = left;
  columns.forEach((col, idx) => {
    addText(slide, col, x + 8, top + 9, widths[idx] - 16, 20, {
      fontSize,
      color: "slate-600",
      bold: true,
    });
    x += widths[idx];
  });
  rows.forEach((row, ridx) => {
    const y = top + rowHeight * (ridx + 1);
    slide.shapes.add({
      geometry: "rect",
      position: { left, top: y, width: totalWidth, height: rowHeight },
      fill: ridx % 2 === 0 ? "white" : "slate-50",
      line: { style: "solid", fill: "slate-200", width: 1 },
    });
    x = left;
    row.forEach((cell, cidx) => {
      addText(slide, String(cell), x + 8, y + 9, widths[cidx] - 16, 20, {
        fontSize,
        color: "slate-800",
      });
      x += widths[cidx];
    });
  });
}

async function addImage(slide, imagePath, left, top, width, height, alt, fit = "contain") {
  const bytes = await fs.readFile(imagePath);
  slide.images.add({
    blob: bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength),
    contentType: "image/png",
    alt,
    fit,
    position: { left, top, width, height },
  });
}

async function loadWindowSummary(windowDef) {
  const csv = path.join(windowDef.dir, "context_universe_factorial_summary.csv");
  const rows = await readCsv(csv);
  return rows
    .map((row) => ({ ...row, window_label: windowDef.label }))
    .sort((a, b) => Number(b.total_return) - Number(a.total_return));
}

const recentRanks = await readCsv(recentRankCsv);
const coverage = await readCsv(coverageCsv);
const byRank = [...recentRanks].sort((a, b) => Number(a.mean_return_rank) - Number(b.mean_return_rank));
const recentQuantile = recentRanks.find(
  (r) => r.universe_id === "active_plus_risk_context" && r.surface_id === "behavioral_pool_quantile_grid_3x3"
);
const recentK9 = recentRanks.find(
  (r) => r.universe_id === "active_plus_risk_context" && r.surface_id === "behavioral_pool_kmeans_k9"
);
const activeCoverage = coverage.filter((r) => ["AMD", "NVDA", "TSLA", "AAPL", "MSTR"].includes(r.symbol));
const windowRows = await Promise.all(completedWindows.map(loadWindowSummary));
const marchRows = windowRows[0];
const juneRows = windowRows[1];

await fs.mkdir(outDir, { recursive: true });
await fs.mkdir(slidePreviewDir, { recursive: true });
const presentation = Presentation.create({ slideSize: { width: 1280, height: 720 } });

{
  const slide = presentation.slides.add();
  slide.background.fill = "slate-50";
  addText(slide, "Gen5.1 Temporal Context Replication", 72, 84, 1040, 62, {
    fontSize: 44,
    color: "slate-950",
    bold: true,
  });
  addText(slide, "SIP refresh plus two completed 2021 context-universe windows", 72, 156, 960, 52, {
    fontSize: 27,
    color: "slate-700",
  });
  addText(
    slide,
    "This deck is meant to preserve the reasoning trail: what we knew, what was still unknown, why the next test was shaped this way, and what the new evidence did or did not answer.",
    72,
    238,
    960,
    86,
    { fontSize: 23, color: "slate-700" }
  );
  addMetricCard(slide, "Recent packet", "7 windows", "Late 2024 through mid 2026", 72, 398, 300);
  addMetricCard(slide, "New packet", "2 windows", "March and June 2021 completed", 406, 398, 320);
  addMetricCard(slide, "Boundary", "Inspection only", "No allocation evidence accepted here", 760, 398, 360);
  addText(slide, "Active set: AMD, NVDA, TSLA, AAPL, MSTR", 72, 582, 880, 28, {
    fontSize: 18,
    color: "slate-500",
  });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Before SIP, the question was too narrow");
  addRule(slide);
  addNarrativeColumn(slide, "What we knew", [
    "The late-2024 to mid-2026 temporal packet favored active-plus-risk context.",
    "The 3x3 quantile state map looked cleaner than k9, even when k9 sometimes showed higher return.",
  ], 78, 226, 350, "teal-700");
  addNarrativeColumn(slide, "What we did not know", [
    "Whether the result was a recent-market-regime artifact.",
    "Whether older windows could be tested without changing the research wrapper.",
  ], 466, 226, 350, "amber-700");
  addNarrativeColumn(slide, "Why ask next", [
    "A robust context-universe choice should survive a move away from the most recent tape.",
    "The first blocker to older tests was data provenance, not model design.",
  ], 854, 226, 350, "indigo-700");
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "The data repair changed what we could test");
  addRule(slide);
  addBulletList(
    slide,
    [
      "Gen4 had selected SIP when the entitlement check passed; Gen5 had been falling back to IEX unless explicitly overridden.",
      "Gen5 now defaults the Alpaca daily research feed to SIP while preserving the override path.",
      "AAPL replaced COIN for older-history tests because COIN cannot support a 2016-era training window.",
      "VXX still begins on 2018-01-18, so early context windows carry a real partial-history warning.",
    ],
    84,
    228,
    1040,
    21,
    66
  );
  addSimpleTable(
    slide,
    ["Symbol", "Rows", "First session", "Latest session"],
    activeCoverage.map((r) => [r.symbol, r.row_count, r.observed_first_session, r.observed_latest_session]),
    84,
    500,
    [120, 120, 190, 190],
    30,
    12
  );
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "The retry was bounded on purpose");
  addRule(slide);
  addNarrativeColumn(slide, "Test shape", [
    "Same active set and candidate set: AMD, NVDA, TSLA, AAPL, MSTR.",
    "Three context universes: active self, active plus risk, and ex-active risk.",
  ], 78, 222, 350, "teal-700");
  addNarrativeColumn(slide, "State surface", [
    "Behavioral-pool PCA only.",
    "Two state maps: 3x3 quantile grid and fixed k-means k9.",
  ], 466, 222, 350, "indigo-700");
  addNarrativeColumn(slide, "Stop rule", [
    "Complete two adjacent 2021 windows, then pause before a long 2022 batch.",
    "Treat partial 2022 child artifacts as non-evidence until their top-level packet completes.",
  ], 854, 222, 350, "amber-700");
  addText(slide, "Why: this was the smallest useful check of whether the recent-window story survives older adjacent OOS windows.", 84, 620, 1050, 38, {
    fontSize: 20,
    color: "slate-700",
    bold: true,
  });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "The recent-window result still matters, but it was not enough");
  addRule(slide);
  await addImage(slide, recentMetricsPng, 36, 190, 1208, 404, "Recent temporal context replication metrics chart", "cover");
  addMetricCard(slide, "Active-plus-risk 3x3", pct(recentQuantile.mean_total_return, 1), `Mean Sharpe ${num(recentQuantile.mean_sharpe)}; zero negative windows`, 78, 600, 350, 92);
  addMetricCard(slide, "Active-plus-risk k9", pct(recentK9.mean_total_return, 1), `Mean Sharpe ${num(recentK9.mean_sharpe)}; two negative windows`, 466, 600, 350, 92);
  addText(slide, "This is why the next question was temporal generalization, not another recent-window refinement.", 854, 614, 330, 54, {
    fontSize: 17,
    color: "slate-700",
    bold: true,
  });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "March 2021: active-plus-risk survived, with 3x3 on top");
  addRule(slide);
  addSimpleTable(
    slide,
    ["Condition", "Return", "Sharpe", "Max DD", "Entries"],
    marchRows.map((r) => [conditionLabel(r), pct(r.total_return, 1), num(r.sharpe, 2), pct(r.max_drawdown, 1), r.total_entry_fills]),
    72,
    218,
    [475, 110, 100, 110, 90],
    44,
    14
  );
  addText(slide, "What this answered: the active-plus-risk intuition was not purely a 2025-2026 artifact. But k9 did not improve the top result, and ex-active risk still looked competitive.", 72, 560, 1080, 56, {
    fontSize: 20,
    color: "slate-700",
    bold: true,
  });
  addText(slide, `VXX context coverage warning: ${completedWindows[0].vxxRows} rows versus the full window panel.`, 72, 636, 880, 30, {
    fontSize: 16,
    color: "slate-500",
  });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "June 2021: the simple context story broke in a useful way");
  addRule(slide);
  addSimpleTable(
    slide,
    ["Condition", "Return", "Sharpe", "Max DD", "Entries"],
    juneRows.map((r) => [conditionLabel(r), pct(r.total_return, 1), num(r.sharpe, 2), pct(r.max_drawdown, 1), r.total_entry_fills]),
    72,
    218,
    [475, 110, 100, 110, 90],
    44,
    14
  );
  addText(slide, "What this answered: active-plus-risk is not a universal winner. The three 3x3 conditions occupied the top three rows, while ex-active risk led this adjacent window.", 72, 560, 1080, 56, {
    fontSize: 20,
    color: "slate-700",
    bold: true,
  });
  addText(slide, `VXX context coverage warning: ${completedWindows[1].vxxRows} rows versus the full window panel.`, 72, 636, 880, 30, {
    fontSize: 16,
    color: "slate-500",
  });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "The new evidence changed the decision surface");
  addRule(slide);
  addNarrativeColumn(slide, "Answered", [
    "SIP plus the AAPL basket can reach the older history needed for broader temporal tests.",
    "Across both completed 2021 windows, 3x3 beat fixed k9 on total return.",
  ], 78, 226, 350, "teal-700");
  addNarrativeColumn(slide, "Not answered", [
    "Which context universe is globally best.",
    "Whether the 2022 window behaves like 2021 or like the recent 2024-2026 packet.",
  ], 466, 226, 350, "amber-700");
  addNarrativeColumn(slide, "Implication", [
    "3x3 is the cleaner default for the next batch.",
    "Context-universe selection should stay open until more time windows are complete.",
  ], 854, 226, 350, "indigo-700");
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Warnings are part of the result, not bookkeeping");
  addRule(slide);
  addBulletList(
    slide,
    [
      "VXX partial history is real: it can influence any context universe that includes VXX before its 2018 start.",
      "Fixed k9 continued to show k-means convergence / Quick-TRANSfer warnings, so it remains diagnostic rather than a clean default.",
      "The run entered 2022 before being stopped; only completed top-level 2021 packets are included in this deck.",
      "The portfolio accounting layer is used as downstream inspection only. Performance does not approve an allocation.",
    ],
    84,
    228,
    1040,
    21,
    70
  );
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Recommended next move");
  addRule(slide);
  addMetricCard(slide, "Default state map", "3x3", "Use as the clean baseline for the next batch", 78, 230, 330);
  addMetricCard(slide, "Open design choice", "VXX policy", "Replace, omit, or accept 2018+ comparability", 470, 230, 330);
  addMetricCard(slide, "Next evidence", "2022 windows", "Run after the VXX choice or with the warning accepted", 862, 230, 330);
  addBulletList(
    slide,
    [
      "Do not declare a winning context universe from the current evidence.",
      "Use the next batch to separate context composition from temporal regime sensitivity.",
      "Keep updating this deck and the POC log at each completed research checkpoint.",
    ],
    96,
    430,
    1040,
    21,
    62
  );
}

const montage = await presentation.export({ format: "webp", montage: true, scale: 1 });
await fs.writeFile(montagePath, new Uint8Array(await montage.arrayBuffer()));
for (const [index, slide] of presentation.slides.items.entries()) {
  const preview = await presentation.export({ slide, format: "png", scale: 1 });
  const slidePath = path.join(slidePreviewDir, `slide-${String(index + 1).padStart(2, "0")}.png`);
  await fs.writeFile(slidePath, new Uint8Array(await preview.arrayBuffer()));
}
const inspect = await presentation.inspect({ kind: "slide,textbox,shape,image,chart,table,layout", maxChars: 36000 });
await fs.writeFile(inspectPath, inspect.ndjson);
const pptx = await PresentationFile.exportPptx(presentation);
await pptx.save(finalPptx);

console.log(`Wrote ${finalPptx}`);
console.log(`Wrote ${inspectPath}`);
console.log(`Wrote ${montagePath}`);
console.log(`Wrote slide previews to ${slidePreviewDir}`);
