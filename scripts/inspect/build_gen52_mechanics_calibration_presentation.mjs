import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const artifactWorkspace =
  process.env.GEN5_ARTIFACT_WORKSPACE ||
  path.join(os.tmpdir(), "codex-presentations", "gen52-mechanics-calibration");
const artifactEntrypointCandidates = [
  path.join(artifactWorkspace, "node_modules", "@oai", "artifact-tool", "dist", "node", "artifact_tool.mjs"),
  path.join(artifactWorkspace, "node_modules", "@oai", "artifact-tool", "dist", "artifact_tool.mjs"),
];

let artifactEntrypoint = null;
for (const candidate of artifactEntrypointCandidates) {
  try {
    await fs.access(candidate);
    artifactEntrypoint = candidate;
    break;
  } catch {
    // Try the next supported artifact-tool entrypoint shape.
  }
}
if (!artifactEntrypoint) {
  throw new Error(`Could not find artifact-tool entrypoint under ${artifactWorkspace}`);
}

const { Presentation, PresentationFile } = await import(pathToFileURL(artifactEntrypoint).href);

const calibrationDir = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "gen4_equivalence",
  "gen4_equivalence_gen52calfull162024q420260707",
);
const auditDir = path.join(calibrationDir, "trade_tape_audit");
const outputPptx = path.join(repoRoot, "presentations", "gen5_2_mechanics_and_gen4_calibration.pptx");
const previewDir = path.join(auditDir, "mechanics_deck_preview");

const colors = {
  ink: "#111111",
  muted: "#555555",
  rule: "#B8BCC4",
  panel: "#EDEDED",
  canvas: "#FFFFFF",
  direct: "#2E86AB",
  pooled: "#9B5DE5",
  gen4: "#111111",
  hold: "#AEB4BE",
  highlight: "#FF6B35",
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
    if (ch === '"') {
      if (quoted && line[i + 1] === '"') {
        cur += '"';
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

function n(value) {
  const x = Number(value);
  return Number.isFinite(x) ? x : NaN;
}

function pct(value, digits = 1) {
  const x = typeof value === "number" ? value : n(value);
  return Number.isFinite(x) ? `${(100 * x).toFixed(digits)}%` : "NA";
}

function pp(value, digits = 1) {
  const x = typeof value === "number" ? value : n(value);
  return Number.isFinite(x) ? `${x >= 0 ? "+" : ""}${(100 * x).toFixed(digits)} pp` : "NA";
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
    fontSize: style.fontSize ?? 20,
    color: style.color ?? colors.ink,
    bold: style.bold ?? false,
    alignment: style.alignment,
  };
  return shape;
}

function addTitle(slide, title, kicker = "Gen5.2 mechanics and Gen4 calibration") {
  addText(slide, kicker, { left: 42, top: 34, width: 620, height: 28 }, { fontSize: 16, bold: true, color: colors.muted });
  addText(slide, title, { left: 42, top: 74, width: 1130, height: 92 }, { fontSize: 41, bold: true });
  slide.shapes.add({
    geometry: "rect",
    position: { left: 42, top: 170, width: 1196, height: 1 },
    fill: colors.rule,
    line: { style: "solid", fill: colors.rule, width: 0 },
  });
}

function addFooter(slide, page) {
  addText(slide, "Research inspection only. Not allocation evidence.", { left: 42, top: 676, width: 560, height: 20 }, { fontSize: 12, color: colors.muted });
  addText(slide, String(page), { left: 1200, top: 676, width: 38, height: 20 }, { fontSize: 12, color: colors.muted, alignment: "right" });
}

function addPanel(slide, position, fill = colors.panel) {
  return slide.shapes.add({
    geometry: "rect",
    position,
    fill,
    line: { style: "solid", fill: "none", width: 0 },
  });
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

function addMetric(slide, label, value, position, color = colors.ink) {
  addText(slide, value, { left: position.left, top: position.top, width: position.width, height: 54 }, { fontSize: 40, bold: true, color });
  addText(slide, label, { left: position.left, top: position.top + 58, width: position.width, height: 44 }, { fontSize: 15, color: colors.muted });
}

function addBullets(slide, bullets, left, top, width, fontSize = 20, gap = 48) {
  bullets.forEach((bullet, index) => {
    addText(slide, "■", { left, top: top + index * gap + 4, width: 20, height: 24 }, { fontSize: 11, color: bullet.color ?? colors.ink });
    addText(slide, bullet.text, { left: left + 28, top: top + index * gap, width, height: gap }, { fontSize, color: bullet.textColor ?? colors.muted });
  });
}

function laneRow(rows, lane) {
  return rows.find((row) => row.lane === lane);
}

const runSpec = (await readCsv(path.join(calibrationDir, "gen4_equivalence_run_spec.csv")))[0];
const laneSummary = await readCsv(path.join(auditDir, "cluster3_lane_summary.csv"));
const comparisonSummary = await readCsv(path.join(calibrationDir, "gen4_equivalence_comparison_summary.csv"));
const clusterMap = await readCsv(path.join(
  "C:",
  "Users",
  "Franc",
  "OneDrive",
  "Documents",
  "Francis",
  "Peltata Project",
  "Time-Series-Modeling",
  "Experiments",
  "FM-002-024-R3_med_16_bins",
  "asset_cluster_map.csv",
));

const liveSymbols = runSpec.symbols.split(",").map((x) => x.trim()).filter(Boolean).sort();
const cluster1 = clusterMap.filter((row) => row.cluster_id === "1" && liveSymbols.includes(row.asset)).map((row) => row.asset).sort();
const cluster3 = clusterMap.filter((row) => row.cluster_id === "3" && liveSymbols.includes(row.asset)).map((row) => row.asset).sort();
const cluster2 = clusterMap.filter((row) => row.cluster_id === "2" && liveSymbols.includes(row.asset)).map((row) => row.asset).sort();

const gen4Cluster3 = comparisonSummary.find((row) => row.source === "Gen4 artifact" && row.group_id === "cluster_3");
const directCluster3 = comparisonSummary.find((row) => row.selection_policy === "asset_state_direct_spec" && row.group_id === "cluster_3");
const pooledCluster3 = comparisonSummary.find((row) => row.selection_policy === "pooled_family_asset_variant" && row.group_id === "cluster_3");

const deck = Presentation.create({ slideSize: { width: 1280, height: 720 } });

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addText(slide, "Gen5.2 mechanics and calibration", { left: 42, top: 50, width: 520, height: 50 }, { fontSize: 22, bold: true, color: colors.muted });
  addText(slide, "Making the Gen4 comparison fair enough to learn from", { left: 42, top: 175, width: 1020, height: 205 }, { fontSize: 62, bold: true });
  addText(
    slide,
    "This deck summarizes why Gen5.2 was opened, what Gen4 mechanics were cloned into both Gen5.2 selection lanes, and what the latest trade-tape audit says about the remaining gap.",
    { left: 42, top: 430, width: 870, height: 94 },
    { fontSize: 24, color: colors.muted },
  );
  addText(slide, "2024Q4 Gen4-equivalence calibration", { left: 42, top: 620, width: 420, height: 28 }, { fontSize: 16, bold: true });
  addFooter(slide, 1);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Gen5.2 exists because selection mechanics were a real fork");
  addPanel(slide, { left: 42, top: 218, width: 525, height: 300 });
  addPanel(slide, { left: 610, top: 218, width: 628, height: 300 });
  addText(slide, "The problem", { left: 72, top: 250, width: 400, height: 34 }, { fontSize: 28, bold: true });
  addText(slide, "Earlier Gen5.1 screens compared direct-spec selection against Gen4-style pooled-family selection, but the lanes were not yet sharing all Gen4-faithful eligibility and no-trade mechanics.", { left: 72, top: 312, width: 430, height: 150 }, { fontSize: 21, color: colors.muted });
  addText(slide, "The Gen5.2 response", { left: 642, top: 250, width: 430, height: 34 }, { fontSize: 28, bold: true });
  addText(slide, "Keep both selection philosophies alive, but make their underlying candidate scoring, trade-count eligibility, sparse-state handling, and no-trade behavior consistent before interpreting results.", { left: 642, top: 312, width: 520, height: 150 }, { fontSize: 21, color: colors.muted });
  addFooter(slide, 2);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Both Gen5.2 lanes now share the same Gen4-faithful primitives");
  const items = [
    ["TRAIN-only scoring", "No OOS rows influence state assignment, candidate eligibility, strategy choice, or replay authority."],
    ["Active candidates need trades", "Active rows must clear the shared minimum trade-count gate; no-trade remains allowed as an abstention competitor."],
    ["No-trade can force an exit", "Gen4's no_trade_exit_immediate concept is represented as an explicit force_exit_next_open state override."],
    ["Direct and pooled differ only at selection philosophy", "Direct chooses the best full asset/state spec; pooled chooses a state-level family, then asset-specific params inside it."],
  ];
  items.forEach((item, index) => {
    const left = index % 2 === 0 ? 42 : 650;
    const top = index < 2 ? 218 : 436;
    addPanel(slide, { left, top, width: 545, height: 150 });
    addText(slide, item[0], { left: left + 24, top: top + 22, width: 470, height: 30 }, { fontSize: 25, bold: true });
    addText(slide, item[1], { left: left + 24, top: top + 66, width: 485, height: 64 }, { fontSize: 18, color: colors.muted });
  });
  addFooter(slide, 3);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The calibration holds the live basket identical");
  addPanel(slide, { left: 42, top: 210, width: 550, height: 330 });
  addPanel(slide, { left: 636, top: 210, width: 602, height: 330 });
  addText(slide, "Exact live/reporting basket", { left: 72, top: 242, width: 430, height: 34 }, { fontSize: 28, bold: true });
  addText(slide, liveSymbols.join(", "), { left: 72, top: 302, width: 450, height: 180 }, { fontSize: 23, color: colors.ink });
  addText(slide, "Confirmed parity", { left: 668, top: 242, width: 430, height: 34 }, { fontSize: 28, bold: true });
  addBullets(slide, [
    { text: "Gen4 exported live scope contains the same 16 symbols." },
    { text: "Gen5.2 replay uses the same 16 symbols from the run spec." },
    { text: "The broader 29-symbol research/context universe is used for regime context, not as the live basket." },
  ], 668, 304, 500, 20, 56);
  addFooter(slide, 4);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Cluster 1 and Cluster 3 are reporting lenses, not trade inputs");
  addPanel(slide, { left: 42, top: 218, width: 360, height: 320 });
  addPanel(slide, { left: 460, top: 218, width: 360, height: 320 });
  addPanel(slide, { left: 878, top: 218, width: 360, height: 320 });
  addText(slide, "Cluster 1", { left: 72, top: 250, width: 240, height: 34 }, { fontSize: 28, bold: true });
  addText(slide, cluster1.join(", "), { left: 72, top: 310, width: 285, height: 140 }, { fontSize: 22, color: colors.muted });
  addText(slide, "Cluster 3", { left: 490, top: 250, width: 240, height: 34 }, { fontSize: 28, bold: true });
  addText(slide, cluster3.join(", "), { left: 490, top: 310, width: 285, height: 140 }, { fontSize: 22, color: colors.muted });
  addText(slide, "What this means", { left: 908, top: 250, width: 250, height: 34 }, { fontSize: 28, bold: true });
  addText(slide, "The asset clusters come from a separate Gen4 asset-level PCA/clustering map. They are applied after symbol-level replay to aggregate and visualize equity curves.", { left: 908, top: 310, width: 270, height: 136 }, { fontSize: 20, color: colors.muted });
  addText(slide, "They do not contaminate PCA state fitting, strategy selection, simulated trades, or live basket construction.", { left: 908, top: 472, width: 270, height: 64 }, { fontSize: 19, bold: true, color: colors.highlight });
  addFooter(slide, 5);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The comparison is now scoped to the same quarter");
  addPanel(slide, { left: 42, top: 210, width: 350, height: 330 });
  addPanel(slide, { left: 465, top: 210, width: 350, height: 330 });
  addPanel(slide, { left: 888, top: 210, width: 350, height: 330 });
  addText(slide, "What changed", { left: 70, top: 238, width: 260, height: 30 }, { fontSize: 24, bold: true });
  addText(slide, "Gen4 artifact equity is normalized over 2024-10-01 to 2024-12-31, matching the Gen5.2 replay window.", { left: 70, top: 294, width: 280, height: 116 }, { fontSize: 20, color: colors.muted });
  addText(slide, "Why it matters", { left: 493, top: 238, width: 260, height: 30 }, { fontSize: 24, bold: true });
  addText(slide, "The earlier full-history artifact comparison could exaggerate differences. This slice asks a cleaner behavioral question.", { left: 493, top: 294, width: 280, height: 116 }, { fontSize: 20, color: colors.muted });
  addText(slide, "What remains", { left: 916, top: 238, width: 260, height: 30 }, { fontSize: 24, bold: true });
  addText(slide, "Cluster 1 is close. Cluster 3 still diverges, so the next audit inspected trade timing, exposure, and selected authority.", { left: 916, top: 294, width: 280, height: 140 }, { fontSize: 20, color: colors.muted });
  addFooter(slide, 6);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Cluster 3 remains the informative gap after normalization");
  await addImage(slide, path.join(calibrationDir, "gen4_equivalence_equity_overlay.png"), { left: 42, top: 202, width: 760, height: 405 }, "Gen4 and Gen5.2 equity overlay");
  addMetric(slide, "Gen4 artifact alpha, cluster 3", pp(n(gen4Cluster3.alpha_vs_benchmark)), { left: 860, top: 220, width: 310 }, colors.gen4);
  addMetric(slide, "Gen5.2 direct alpha, cluster 3", pp(n(directCluster3.alpha_vs_benchmark)), { left: 860, top: 340, width: 310 }, colors.direct);
  addMetric(slide, "Gen5.2 pooled alpha, cluster 3", pp(n(pooledCluster3.alpha_vs_benchmark)), { left: 860, top: 460, width: 310 }, colors.pooled);
  addText(slide, "Interpretation: this is not a universal mismatch. It is concentrated where the high-beta subset was rising sharply.", { left: 42, top: 620, width: 930, height: 40 }, { fontSize: 18, color: colors.muted });
  addFooter(slide, 7);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The audit asked whether the gap is exposure, timing, or asset selection");
  const boxes = [
    ["Exposure", "How often each lane was long by symbol."],
    ["Participation", "Whether strategy returns captured each symbol's hold move."],
    ["Trade tape", "When entries and exits occurred, and whether trades lingered."],
    ["Family mix", "Whether the systems leaned on different strategy families."],
  ];
  boxes.forEach((box, i) => {
    const left = 42 + i * 300;
    addPanel(slide, { left, top: 230, width: 260, height: 250 });
    addText(slide, box[0], { left: left + 22, top: 258, width: 216, height: 36 }, { fontSize: 25, bold: true });
    addText(slide, box[1], { left: left + 22, top: 320, width: 208, height: 110 }, { fontSize: 20, color: colors.muted });
  });
  addText(slide, "Audit scope: shared Cluster 3 live symbols in the calibration universe, `AMD,NVDA,PLTR,SOFI,TSLA`, over 2024Q4.", { left: 42, top: 570, width: 1050, height: 38 }, { fontSize: 20, color: colors.muted });
  addFooter(slide, 8);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Exposure diverges by asset, not just by overall caution");
  await addImage(slide, path.join(auditDir, "cluster3_exposure_heatmap.png"), { left: 42, top: 202, width: 760, height: 430 }, "Cluster 3 exposure heatmap");
  addText(slide, "Most important read", { left: 845, top: 218, width: 310, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "Gen4 is long SOFI for 89% of the quarter. Both Gen5.2 lanes are 0% long SOFI. Gen5.2 redirects active time toward PLTR and TSLA instead.", { left: 845, top: 272, width: 335, height: 170 }, { fontSize: 22, color: colors.muted });
  addText(slide, "That makes the gap look like symbol-specific authority divergence inside the same live basket, not merely too little trading everywhere.", { left: 845, top: 470, width: 335, height: 110 }, { fontSize: 20, color: colors.muted });
  addFooter(slide, 9);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The trade tape shows different routes through the same quarter");
  await addImage(slide, path.join(auditDir, "cluster3_trade_tape.png"), { left: 42, top: 190, width: 810, height: 470 }, "Cluster 3 trade tape");
  addText(slide, "What stands out", { left: 895, top: 210, width: 290, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "Gen4 carries SOFI almost continuously. Direct gets a strong TSLA outcome and a partial PLTR outcome. Pooled is active in PLTR but undercaptures the move and also misses SOFI.", { left: 895, top: 268, width: 310, height: 178 }, { fontSize: 21, color: colors.muted });
  addText(slide, "The next forensic layer should inspect selected state/spec rows for SOFI and PLTR, especially no-trade eligibility and family scoring.", { left: 895, top: 488, width: 310, height: 112 }, { fontSize: 20, color: colors.muted });
  addFooter(slide, 10);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The next slice should audit authority before expanding the factorial");
  addPanel(slide, { left: 42, top: 216, width: 525, height: 310 });
  addPanel(slide, { left: 610, top: 216, width: 628, height: 310 });
  addText(slide, "Current takeaway", { left: 72, top: 248, width: 410, height: 34 }, { fontSize: 28, bold: true });
  addText(slide, "The comparison basket is identical, and clusters are only reporting bins. The remaining gap is therefore more likely in selected authority, state assignment, or strategy semantics for specific symbols.", { left: 72, top: 310, width: 438, height: 160 }, { fontSize: 21, color: colors.muted });
  addText(slide, "Recommended next audit", { left: 642, top: 248, width: 500, height: 34 }, { fontSize: 28, bold: true });
  addText(slide, "For SOFI and PLTR in 2024Q4, compare state occupancy, selected family/spec, TRAIN eligibility, no-trade competition, and the Gen4 picked family/params. This should tell us whether the remaining gap is strategy semantics, selection scoring, or state assignment.", { left: 642, top: 310, width: 520, height: 170 }, { fontSize: 21, color: colors.muted });
  addFooter(slide, 11);
}

await fs.mkdir(path.dirname(outputPptx), { recursive: true });
await fs.mkdir(previewDir, { recursive: true });

for (const [index, slide] of deck.slides.items.entries()) {
  const png = await deck.export({ slide, format: "png", scale: 1 });
  await writeBlob(path.join(previewDir, `slide-${String(index + 1).padStart(2, "0")}.png`), png);
  const layout = await slide.export({ format: "layout" });
  await fs.writeFile(path.join(previewDir, `slide-${String(index + 1).padStart(2, "0")}.layout.json`), await layout.text(), "utf8");
}

const montage = await deck.export({ format: "webp", montage: true, scale: 1 });
await writeBlob(path.join(previewDir, "deck_montage.webp"), montage);

const pptx = await PresentationFile.exportPptx(deck);
await pptx.save(outputPptx);

console.log(`Wrote ${outputPptx}`);
console.log(`Preview ${previewDir}`);
