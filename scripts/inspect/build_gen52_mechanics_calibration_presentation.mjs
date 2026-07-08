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

const packetDir = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "gen4_equivalence",
  "gen4_equivalence_gen52fallbackfull162024q420260708",
);
const auditDir = path.join(packetDir, "trade_tape_audit");
const probeDir = path.join(packetDir, "sofi_ema_cross_semantics_probe");
const outputPptx = path.join(repoRoot, "presentations", "gen5_2_mechanics_and_gen4_calibration.pptx");
const previewDir = path.join(auditDir, "mechanics_deck_preview_final");

const colors = {
  ink: "#101216",
  muted: "#59606A",
  rule: "#C8CDD4",
  panel: "#F0F2F4",
  canvas: "#FFFFFF",
  direct: "#2E86AB",
  pooled: "#9B5DE5",
  fallback: "#D1495B",
  gen4: "#111111",
  hold: "#AEB4BE",
  accent: "#FF6B35",
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
  addText(slide, kicker, { left: 42, top: 34, width: 660, height: 28 }, { fontSize: 16, bold: true, color: colors.muted });
  addText(slide, title, { left: 42, top: 74, width: 1130, height: 88 }, { fontSize: 39, bold: true });
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
  addText(slide, value, { left: position.left, top: position.top, width: position.width, height: 54 }, { fontSize: 38, bold: true, color });
  addText(slide, label, { left: position.left, top: position.top + 58, width: position.width, height: 42 }, { fontSize: 15, color: colors.muted });
}

function addBullets(slide, bullets, left, top, width, fontSize = 20, gap = 52) {
  bullets.forEach((bullet, index) => {
    addText(slide, "-", { left, top: top + index * gap, width: 20, height: 28 }, { fontSize, bold: true, color: bullet.color ?? colors.ink });
    addText(slide, bullet.text, { left: left + 28, top: top + index * gap, width, height: gap }, { fontSize, color: bullet.textColor ?? colors.muted });
  });
}

function findComparison(rows, source, selectionPolicy, groupId) {
  return rows.find((row) => row.source === source && row.selection_policy === selectionPolicy && row.group_id === groupId);
}

function findLane(rows, lane) {
  return rows.find((row) => row.lane === lane);
}

function findSymbol(rows, lane, symbol) {
  return rows.find((row) => row.lane === lane && row.symbol === symbol);
}

const runSpec = (await readCsv(path.join(packetDir, "gen4_equivalence_run_spec.csv")))[0];
const comparisonSummary = await readCsv(path.join(packetDir, "gen4_equivalence_comparison_summary.csv"));
const laneSummary = await readCsv(path.join(auditDir, "cluster3_lane_summary.csv"));
const symbolSummary = await readCsv(path.join(auditDir, "cluster3_symbol_participation_summary.csv"));
const authorityLedger = await readCsv(path.join(auditDir, "sofi_pltr_authority_ledger.csv"));
const semanticsSummary = (await readCsv(path.join(probeDir, "sofi_ema_cross_summary.csv")))[0];
const eventIndex = await readCsv(path.join(probeDir, "sofi_ema_cross_event_index.csv"));

const liveSymbols = runSpec.symbols.split(",").map((x) => x.trim()).filter(Boolean).sort();
const cluster3Symbols = "AMD,NVDA,PLTR,SOFI,TSLA";

const gen4Cluster3 = findComparison(comparisonSummary, "Gen4 artifact", "pooled_family_asset_variant", "cluster_3");
const directCluster3 = findComparison(comparisonSummary, "Gen5.2 replay", "asset_state_direct_spec", "cluster_3");
const pooledCluster3 = findComparison(comparisonSummary, "Gen5.2 replay", "pooled_family_asset_variant", "cluster_3");
const fallbackCluster3 = findComparison(comparisonSummary, "Gen5.2 replay", "pooled_family_asset_variant_state_fallback", "cluster_3");
const gen4Lane = findLane(laneSummary, "Gen4 artifact");
const directLane = findLane(laneSummary, "Gen5.2 direct");
const pooledLane = findLane(laneSummary, "Gen5.2 pooled");
const fallbackLane = findLane(laneSummary, "Gen5.2 fallback");
const sofiFallback = findSymbol(symbolSummary, "Gen5.2 fallback", "SOFI");
const sofiGen4 = findSymbol(symbolSummary, "Gen4 artifact", "SOFI");
const sofiS14Fallback = authorityLedger.find((row) => row.lane === "Gen5.2 fallback" && row.symbol === "SOFI" && row.state_id === "S1_4");

const event = (type) => eventIndex.find((row) => row.event_type === type)?.event_date ?? "NA";

const deck = Presentation.create({ slideSize: { width: 1280, height: 720 } });

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addText(slide, "Gen5.2 mechanics and calibration", { left: 42, top: 52, width: 560, height: 44 }, { fontSize: 22, bold: true, color: colors.muted });
  addText(slide, "Why the Gen4 gap is now a state-gated timing question", { left: 42, top: 172, width: 1050, height: 190 }, { fontSize: 56, bold: true });
  addText(
    slide,
    "This update folds in the Gen4-style fallback lane, trade-tape audit, and SOFI EMA timing probe from the 2024Q4 calibration packet.",
    { left: 42, top: 430, width: 900, height: 82 },
    { fontSize: 24, color: colors.muted },
  );
  addText(slide, "Live basket held constant across Gen4 and Gen5.2", { left: 42, top: 620, width: 560, height: 28 }, { fontSize: 16, bold: true });
  addFooter(slide, 1);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The question we were trying to make fair");
  addPanel(slide, { left: 42, top: 218, width: 360, height: 310 });
  addPanel(slide, { left: 460, top: 218, width: 360, height: 310 });
  addPanel(slide, { left: 878, top: 218, width: 360, height: 310 });
  addText(slide, "What we knew", { left: 72, top: 250, width: 260, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "Gen4 had strong 2024Q4 alpha in the high-beta reporting subset, especially through SOFI. Gen5.1/5.2 was not reproducing it.", { left: 72, top: 310, width: 285, height: 142 }, { fontSize: 20, color: colors.muted });
  addText(slide, "What was suspect", { left: 490, top: 250, width: 260, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "Gen4 pooled strategy families by state, then selected asset-specific params. Gen5 direct picked the full spec per asset/state.", { left: 490, top: 310, width: 285, height: 142 }, { fontSize: 20, color: colors.muted });
  addText(slide, "What Gen5.2 did", { left: 908, top: 250, width: 260, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "It kept direct and pooled lanes, then added Gen4-faithful eligibility, no-trade behavior, and a fallback lane that borrows the pooled state winner when an asset/state cell is sparse.", { left: 908, top: 310, width: 285, height: 172 }, { fontSize: 20, color: colors.muted });
  addFooter(slide, 2);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The live basket and reporting scope are controlled");
  addPanel(slide, { left: 42, top: 214, width: 500, height: 320 });
  addPanel(slide, { left: 610, top: 214, width: 628, height: 320 });
  addText(slide, "Exact live basket", { left: 72, top: 246, width: 360, height: 34 }, { fontSize: 27, bold: true });
  addText(slide, liveSymbols.join(", "), { left: 72, top: 306, width: 405, height: 164 }, { fontSize: 21, color: colors.ink });
  addText(slide, "Reporting subset under audit", { left: 642, top: 246, width: 430, height: 34 }, { fontSize: 27, bold: true });
  addText(slide, cluster3Symbols, { left: 642, top: 306, width: 500, height: 48 }, { fontSize: 24, bold: true, color: colors.accent });
  addBullets(slide, [
    { text: "Cluster labels are reporting lenses inherited from Gen4 artifact summaries." },
    { text: "They do not feed the PCA state fit, strategy selection, replay trades, or portfolio accounting." },
    { text: "This lets us isolate mechanics before reopening basket design." },
  ], 642, 386, 510, 18, 52);
  addFooter(slide, 3);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "What 'no asset plus state winner' means mechanically");
  addPanel(slide, { left: 42, top: 216, width: 365, height: 330 });
  addPanel(slide, { left: 458, top: 216, width: 365, height: 330 });
  addPanel(slide, { left: 874, top: 216, width: 365, height: 330 });
  addText(slide, "State family winner", { left: 72, top: 248, width: 280, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "The pooled lane can decide that a state wants a family such as ema_cross, based on the pooled TRAIN evidence for that state.", { left: 72, top: 306, width: 290, height: 138 }, { fontSize: 20, color: colors.muted });
  addText(slide, "Asset params still matter", { left: 488, top: 248, width: 280, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "For each asset in that same state, Gen5.2 still needs a qualifying variant inside the chosen family, such as f1/s10.", { left: 488, top: 306, width: 290, height: 138 }, { fontSize: 20, color: colors.muted });
  addText(slide, "How it can be empty", { left: 904, top: 248, width: 280, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "The asset/state slice may be sparse, may not generate enough trades, or may have only no-trade eligible rows. Strict pooled abstains; fallback borrows the pooled state leader.", { left: 904, top: 306, width: 290, height: 166 }, { fontSize: 20, color: colors.muted });
  addText(slide, "In the latest SOFI case, fallback solved the empty-cell problem, but not the timing problem.", { left: 42, top: 594, width: 930, height: 38 }, { fontSize: 21, bold: true, color: colors.accent });
  addFooter(slide, 4);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The fallback lane fired, but it did not close the alpha gap");
  await addImage(slide, path.join(packetDir, "gen4_equivalence_alpha_scorecard.png"), { left: 42, top: 202, width: 760, height: 430 }, "Gen4 and Gen5.2 alpha scorecard");
  addMetric(slide, "Gen4 cluster 3 alpha", pp(gen4Cluster3.alpha_vs_benchmark), { left: 850, top: 214, width: 330 }, colors.gen4);
  addMetric(slide, "Gen5.2 direct alpha", pp(directCluster3.alpha_vs_benchmark), { left: 850, top: 326, width: 330 }, colors.direct);
  addMetric(slide, "Gen5.2 strict pooled alpha", pp(pooledCluster3.alpha_vs_benchmark), { left: 850, top: 438, width: 330 }, colors.pooled);
  addMetric(slide, "Gen5.2 fallback alpha", pp(fallbackCluster3.alpha_vs_benchmark), { left: 850, top: 550, width: 330 }, colors.fallback);
  addFooter(slide, 5);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The equity overlay shows the gap is concentrated, not universal");
  await addImage(slide, path.join(packetDir, "gen4_equivalence_equity_overlay.png"), { left: 42, top: 202, width: 800, height: 420 }, "Gen4 and Gen5.2 equity overlay");
  addText(slide, "Interpretation", { left: 888, top: 216, width: 290, height: 34 }, { fontSize: 27, bold: true });
  addBullets(slide, [
    { text: "Cluster 1 remains close enough that the system is not globally broken." },
    { text: "Cluster 3 diverges during a high-beta upside window." },
    { text: "The useful audit question is which assets and trades drove that divergence." },
  ], 888, 282, 305, 20, 74);
  addFooter(slide, 6);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Trade tapes show the SOFI miss clearly");
  await addImage(slide, path.join(auditDir, "cluster3_trade_tape.png"), { left: 42, top: 190, width: 820, height: 470 }, "Cluster 3 trade tape");
  addText(slide, "Readout", { left: 900, top: 214, width: 280, height: 34 }, { fontSize: 27, bold: true });
  addText(
    slide,
    `Gen4 held SOFI for ${pct(sofiGen4.exposure)} of the quarter and captured a large early move. Fallback held SOFI for only ${pct(sofiFallback.exposure)} and only generated the two late losing round trips.`,
    { left: 900, top: 280, width: 305, height: 170 },
    { fontSize: 21, color: colors.muted },
  );
  addText(
    slide,
    "That says fallback changed selected authority, but did not reproduce Gen4's practical entry timing.",
    { left: 900, top: 488, width: 305, height: 92 },
    { fontSize: 21, bold: true, color: colors.accent },
  );
  addFooter(slide, 7);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Exposure and participation confirm SOFI is the sharpest failure mode");
  await addImage(slide, path.join(auditDir, "cluster3_exposure_heatmap.png"), { left: 42, top: 202, width: 570, height: 410 }, "Cluster 3 exposure heatmap");
  await addImage(slide, path.join(auditDir, "cluster3_symbol_participation.png"), { left: 646, top: 202, width: 592, height: 410 }, "Cluster 3 symbol participation chart");
  addText(slide, "SOFI went from a major Gen4 contributor to flat or late-losing in Gen5.2. PLTR and TSLA differences matter too, but SOFI gives the cleanest forensic path because the fallback lane eventually selected the same `ema_cross_f1_s10` spec.", { left: 54, top: 628, width: 1080, height: 36 }, { fontSize: 17, color: colors.muted });
  addFooter(slide, 8);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Authority heatmaps show fallback solved one problem");
  await addImage(slide, path.join(auditDir, "sofi_pltr_oos_authority_heatmap.png"), { left: 42, top: 192, width: 800, height: 455 }, "SOFI and PLTR OOS authority heatmap");
  addText(slide, "Key distinction", { left: 890, top: 212, width: 280, height: 34 }, { fontSize: 27, bold: true });
  addText(
    slide,
    `Strict pooled had no active SOFI winner in S1_4. Fallback borrowed the pooled state leader, giving SOFI ${sofiS14Fallback?.strategy_family ?? "ema_cross"} / ${sofiS14Fallback?.strategy_spec_id ?? "f1/s10"} on ${sofiS14Fallback?.oos_days ?? "53"} OOS days.`,
    { left: 890, top: 272, width: 310, height: 168 },
    { fontSize: 20, color: colors.muted },
  );
  addText(
    slide,
    "So the remaining gap is downstream of authority availability: when was that authority active relative to the signal event?",
    { left: 890, top: 494, width: 310, height: 98 },
    { fontSize: 20, bold: true, color: colors.accent },
  );
  addFooter(slide, 9);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "SOFI timing probe: the right signal arrived before the right state");
  await addImage(slide, path.join(probeDir, "sofi_ema_cross_signal_timeline.png"), { left: 42, top: 192, width: 790, height: 440 }, "SOFI EMA cross signal timing versus Gen5.2 state routing");
  addMetric(slide, "First f1/s10 cross above", semanticsSummary.first_q4_cross_above_signal, { left: 875, top: 214, width: 310 }, colors.direct);
  addMetric(slide, "Gen4 entry execution", semanticsSummary.gen4_first_entry_execution, { left: 875, top: 326, width: 310 }, colors.gen4);
  addMetric(slide, "Fallback first ema_cross state", semanticsSummary.gen52_fallback_first_ema_cross_state_date, { left: 875, top: 438, width: 310 }, colors.pooled);
  addMetric(slide, "Fallback first entry execution", semanticsSummary.gen52_fallback_first_entry_execution, { left: 875, top: 550, width: 310 }, colors.fallback);
  addFooter(slide, 10);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The practical difference is stale-signal handling");
  addPanel(slide, { left: 42, top: 218, width: 530, height: 300 });
  addPanel(slide, { left: 650, top: 218, width: 530, height: 300 });
  addText(slide, "Gen4 behavior observed", { left: 72, top: 250, width: 390, height: 34 }, { fontSize: 27, bold: true });
  addText(
    slide,
    `The asset-level Gen4 SOFI authority was already ` +
      `ema_cross_f1_s10 when the ${event("ema_cross_signal")} signal fired, so it entered on ${event("gen4_entry")} and rode the trend until ${event("ema_cross_exit_signal")}.`,
    { left: 72, top: 310, width: 430, height: 142 },
    { fontSize: 20, color: colors.muted },
  );
  addText(slide, "Gen5.2 fallback behavior observed", { left: 680, top: 250, width: 420, height: 34 }, { fontSize: 27, bold: true });
  addText(
    slide,
    `State routing did not switch SOFI to ema_cross until ${event("gen5_state_switch")}. Because Gen5.2 only enters on a fresh cross while flat, it ignored the already-active trend and waited until ${event("gen5_entry_signal")}.`,
    { left: 680, top: 310, width: 430, height: 142 },
    { fontSize: 20, color: colors.muted },
  );
  addText(slide, "This is a mechanistic explanation, not a verdict that Gen4 is better. It identifies the next thing to A/B test.", { left: 42, top: 590, width: 980, height: 42 }, { fontSize: 21, bold: true, color: colors.accent });
  addFooter(slide, 11);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "What the fallback iteration answered");
  addPanel(slide, { left: 42, top: 214, width: 360, height: 320 });
  addPanel(slide, { left: 460, top: 214, width: 360, height: 320 });
  addPanel(slide, { left: 878, top: 214, width: 360, height: 320 });
  addText(slide, "Selection hierarchy", { left: 72, top: 246, width: 280, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "The Gen4-style fallback can be represented in Gen5.2. It changes authority rows and produces SOFI trades.", { left: 72, top: 306, width: 290, height: 130 }, { fontSize: 20, color: colors.muted });
  addText(slide, "Alpha gap", { left: 490, top: 246, width: 280, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "The fallback lane did not converge to Gen4 performance in 2024Q4. In Cluster 3 it remained behind both Gen4 and direct-spec.", { left: 490, top: 306, width: 290, height: 150 }, { fontSize: 20, color: colors.muted });
  addText(slide, "Next issue", { left: 908, top: 246, width: 280, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "The most concrete residual gap is how state-gated replay handles a strategy that becomes selected after its entry signal already fired.", { left: 908, top: 306, width: 290, height: 150 }, { fontSize: 20, color: colors.muted });
  addFooter(slide, 12);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Recommended next narrow probe");
  addPanel(slide, { left: 42, top: 214, width: 545, height: 330 });
  addPanel(slide, { left: 650, top: 214, width: 545, height: 330 });
  addText(slide, "A/B stale-signal entry semantics", { left: 72, top: 246, width: 430, height: 34 }, { fontSize: 27, bold: true });
  addBullets(slide, [
    { text: "Baseline: current Gen5.2 enters only on a fresh signal while flat." },
    { text: "Probe: when a state switches into a trend-following family, allow entry if the family is already in an active long condition." },
    { text: "Keep TRAIN, selected specs, context universe, PCA, basket, and portfolio accounting fixed." },
  ], 72, 310, 440, 19, 58);
  addText(slide, "Why this is narrow enough", { left: 680, top: 246, width: 430, height: 34 }, { fontSize: 27, bold: true });
  addBullets(slide, [
    { text: "It directly targets the SOFI October miss without reopening all research design choices." },
    { text: "It can be run as an additional replay lane using existing authority artifacts." },
    { text: "Success would mean convergence in trade timing; failure would point us back to Gen4 signal semantics or portfolio accounting." },
  ], 680, 310, 440, 19, 58);
  addFooter(slide, 13);
}

await fs.mkdir(path.dirname(outputPptx), { recursive: true });
await fs.mkdir(previewDir, { recursive: true });

for (const [index, slide] of deck.slides.items.entries()) {
  const png = await deck.export({ slide, format: "png", scale: 1 });
  await writeBlob(path.join(previewDir, `slide-${String(index + 1).padStart(2, "0")}.png`), png);
  const layout = await slide.export({ format: "layout" });
  await fs.writeFile(path.join(previewDir, `slide-${String(index + 1).padStart(2, "0")}.layout.json`), await layout.text(), "utf8");
}

const pptx = await PresentationFile.exportPptx(deck);
await pptx.save(outputPptx);

console.log(`Wrote ${outputPptx}`);
console.log(`Preview ${previewDir}`);
