import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const artifactWorkspace =
  process.env.GEN5_ARTIFACT_WORKSPACE ||
  path.join(os.tmpdir(), "codex-presentations", "gen52-gen4-trade-tape-audit");
const artifactEntrypointCandidates = [
  path.join(
    artifactWorkspace,
    "node_modules",
    "@oai",
    "artifact-tool",
    "dist",
    "node",
    "artifact_tool.mjs",
  ),
  path.join(
    artifactWorkspace,
    "node_modules",
    "@oai",
    "artifact-tool",
    "dist",
    "artifact_tool.mjs",
  ),
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
const outputPptx = path.join(repoRoot, "presentations", "gen5_2_gen4_trade_tape_audit.pptx");
const previewDir = path.join(auditDir, "deck_preview");

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

function addTitle(slide, title, kicker = "Gen5.2 / Gen4 Calibration") {
  addText(slide, kicker, { left: 42, top: 34, width: 520, height: 28 }, { fontSize: 16, bold: true, color: colors.muted });
  addText(slide, title, { left: 42, top: 74, width: 1120, height: 92 }, { fontSize: 42, bold: true });
  slide.shapes.add({
    geometry: "rect",
    position: { left: 42, top: 170, width: 1196, height: 1 },
    fill: colors.rule,
    line: { style: "solid", fill: colors.rule, width: 0 },
  });
}

function addFooter(slide, page) {
  addText(slide, "Research inspection only. Not allocation evidence.", { left: 42, top: 676, width: 520, height: 20 }, { fontSize: 12, color: colors.muted });
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
  addText(slide, value, { left: position.left, top: position.top, width: position.width, height: 54 }, { fontSize: 42, bold: true, color });
  addText(slide, label, { left: position.left, top: position.top + 58, width: position.width, height: 44 }, { fontSize: 15, color: colors.muted });
}

function laneRow(rows, lane) {
  return rows.find((row) => row.lane === lane);
}

const laneSummary = await readCsv(path.join(auditDir, "cluster3_lane_summary.csv"));
const comparisonSummary = await readCsv(path.join(calibrationDir, "gen4_equivalence_comparison_summary.csv"));
const gen4Cluster3 = comparisonSummary.find((row) => row.source === "Gen4 artifact" && row.group_id === "cluster_3");
const directCluster3 = comparisonSummary.find((row) => row.selection_policy === "asset_state_direct_spec" && row.group_id === "cluster_3");
const pooledCluster3 = comparisonSummary.find((row) => row.selection_policy === "pooled_family_asset_variant" && row.group_id === "cluster_3");

const deck = Presentation.create({ slideSize: { width: 1280, height: 720 } });

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addText(slide, "Gen5.2 vs Gen4", { left: 42, top: 50, width: 420, height: 50 }, { fontSize: 22, bold: true, color: colors.muted });
  addText(slide, "The remaining gap is now a trade-tape question", { left: 42, top: 180, width: 1010, height: 190 }, { fontSize: 64, bold: true });
  addText(
    slide,
    "A same-window calibration narrowed the mismatch to the high-beta cluster. This audit asks what the systems actually did in 2024Q4.",
    { left: 42, top: 430, width: 820, height: 82 },
    { fontSize: 24, color: colors.muted },
  );
  addText(slide, "2024Q4 cluster-3 audit", { left: 42, top: 620, width: 360, height: 28 }, { fontSize: 16, bold: true });
  addFooter(slide, 1);
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
  addText(slide, "Cluster 1 is close. Cluster 3 still diverges, so the next audit should inspect trade timing, exposure, and selected authority.", { left: 916, top: 294, width: 280, height: 140 }, { fontSize: 20, color: colors.muted });
  addFooter(slide, 2);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Cluster 3 is the gap that still deserves attention");
  await addImage(slide, path.join(calibrationDir, "gen4_equivalence_equity_overlay.png"), { left: 42, top: 202, width: 760, height: 405 }, "Gen4 and Gen5.2 equity overlay");
  addMetric(slide, "Gen4 artifact alpha, cluster 3", pp(n(gen4Cluster3.alpha_vs_benchmark)), { left: 860, top: 220, width: 310 }, colors.gen4);
  addMetric(slide, "Gen5.2 direct alpha, cluster 3", pp(n(directCluster3.alpha_vs_benchmark)), { left: 860, top: 340, width: 310 }, colors.direct);
  addMetric(slide, "Gen5.2 pooled alpha, cluster 3", pp(n(pooledCluster3.alpha_vs_benchmark)), { left: 860, top: 460, width: 310 }, colors.pooled);
  addText(slide, "Interpretation: this is not a universal mismatch. It is concentrated where the basket was rising sharply and the tactical lanes needed to stay engaged.", { left: 42, top: 620, width: 930, height: 40 }, { fontSize: 18, color: colors.muted });
  addFooter(slide, 3);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The audit asks whether the gap is exposure, timing, or asset selection");
  const y = 225;
  const boxes = [
    ["Exposure", "How often each lane was long by symbol."],
    ["Participation", "Whether strategy returns captured the symbol's buy-and-hold move."],
    ["Trade tape", "When entries and exits occurred, and whether trades were short or lingering."],
    ["Family mix", "Whether the systems leaned on meaningfully different strategy families."],
  ];
  boxes.forEach((box, i) => {
    const left = 42 + i * 300;
    addPanel(slide, { left, top: y, width: 260, height: 260 });
    addText(slide, box[0], { left: left + 22, top: y + 28, width: 216, height: 36 }, { fontSize: 26, bold: true });
    addText(slide, box[1], { left: left + 22, top: y + 90, width: 208, height: 120 }, { fontSize: 20, color: colors.muted });
  });
  addText(slide, "Scope: shared cluster-3 symbols in the calibration universe, `AMD,NVDA,PLTR,SOFI,TSLA`, over 2024Q4.", { left: 42, top: 570, width: 980, height: 38 }, { fontSize: 20, color: colors.muted });
  addFooter(slide, 4);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Exposure diverges by asset, not just by overall caution");
  await addImage(slide, path.join(auditDir, "cluster3_exposure_heatmap.png"), { left: 42, top: 202, width: 760, height: 430 }, "Cluster 3 exposure heatmap");
  addText(slide, "Most important read", { left: 845, top: 218, width: 310, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "Gen4 is long SOFI for 89% of the quarter. Both Gen5.2 lanes are 0% long SOFI. Gen5.2 redirects active time toward PLTR and TSLA instead.", { left: 845, top: 272, width: 335, height: 170 }, { fontSize: 22, color: colors.muted });
  addText(slide, "That makes the gap look like asset-specific authority divergence inside the same cluster, not simply too little trading everywhere.", { left: 845, top: 470, width: 335, height: 110 }, { fontSize: 20, color: colors.muted });
  addFooter(slide, 5);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Gen4 tracks the cluster move more closely in the shared-symbol view");
  await addImage(slide, path.join(auditDir, "cluster3_symbol_participation.png"), { left: 42, top: 192, width: 760, height: 455 }, "Symbol participation chart");
  const gen4 = laneRow(laneSummary, "Gen4 artifact");
  const direct = laneRow(laneSummary, "Gen5.2 direct");
  const pooled = laneRow(laneSummary, "Gen5.2 pooled");
  addMetric(slide, "Gen4 mean alpha vs hold", pp(n(gen4.mean_alpha_vs_hold)), { left: 850, top: 214, width: 320 }, colors.gen4);
  addMetric(slide, "Direct mean alpha vs hold", pp(n(direct.mean_alpha_vs_hold)), { left: 850, top: 344, width: 320 }, colors.direct);
  addMetric(slide, "Pooled mean alpha vs hold", pp(n(pooled.mean_alpha_vs_hold)), { left: 850, top: 474, width: 320 }, colors.pooled);
  addFooter(slide, 6);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The trade tape shows different routes through the same quarter");
  await addImage(slide, path.join(auditDir, "cluster3_trade_tape.png"), { left: 42, top: 190, width: 810, height: 470 }, "Cluster 3 trade tape");
  addText(slide, "What stands out", { left: 895, top: 210, width: 290, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "Gen4 carries SOFI almost continuously. Direct gets a strong TSLA outcome and a partial PLTR outcome. Pooled is active in PLTR but undercaptures the move and also misses SOFI.", { left: 895, top: 268, width: 310, height: 178 }, { fontSize: 21, color: colors.muted });
  addText(slide, "The next forensic layer should inspect selected state/spec rows for SOFI and PLTR, especially no-trade eligibility and family scoring.", { left: 895, top: 488, width: 310, height: 112 }, { fontSize: 20, color: colors.muted });
  addFooter(slide, 7);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The next slice should audit authority, not expand the factorial");
  addPanel(slide, { left: 42, top: 216, width: 525, height: 310 });
  addPanel(slide, { left: 610, top: 216, width: 628, height: 310 });
  addText(slide, "Current takeaway", { left: 72, top: 248, width: 410, height: 34 }, { fontSize: 28, bold: true });
  addText(slide, "Gen5.2 is not simply refusing to participate. It is participating in a different set of cluster-3 names, and that is enough to explain much of the alpha gap in this quarter.", { left: 72, top: 310, width: 438, height: 150 }, { fontSize: 22, color: colors.muted });
  addText(slide, "Recommended next audit", { left: 642, top: 248, width: 500, height: 34 }, { fontSize: 28, bold: true });
  addText(slide, "For SOFI and PLTR in 2024Q4, compare state occupancy, selected family/spec, TRAIN eligibility, no-trade competition, and the Gen4 picked family/params. This should tell us whether the remaining gap is strategy semantics, selection scoring, or state assignment.", { left: 642, top: 310, width: 520, height: 170 }, { fontSize: 21, color: colors.muted });
  addFooter(slide, 8);
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
