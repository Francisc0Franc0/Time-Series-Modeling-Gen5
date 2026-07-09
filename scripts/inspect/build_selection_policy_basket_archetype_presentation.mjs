import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const artifactModule =
  process.env.ARTIFACT_TOOL_MODULE ||
  "C:/Users/Franc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactModule).href);

const runRoot = path.join(repoRoot, "runs", "research_workbench", "selpol_basket", "selpol_basket_20260703");
const presentationDir = path.join(repoRoot, "presentations");
const finalPptx = path.join(presentationDir, "gen5_selection_policy_basket_archetype_screen.pptx");
const inspectPath = path.join(presentationDir, "gen5_selection_policy_basket_archetype_screen.pptx.inspect.ndjson");
const montagePath = path.join(presentationDir, "gen5_selection_policy_basket_archetype_screen_montage.webp");
const slidePreviewDir = path.join(presentationDir, "gen5_selection_policy_basket_archetype_screen_slides");

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
  return rows.filter((r) => r.length === header.length).map((r) => Object.fromEntries(header.map((h, idx) => [h, r[idx]])));
}

async function readCsv(filePath) {
  return parseCsv(await fs.readFile(filePath, "utf8"));
}

function pct(value, digits = 1) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "";
  return `${(n * 100).toFixed(digits)}%`;
}

function num(value, digits = 2) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "";
  return n.toFixed(digits);
}

function shortPolicy(policy) {
  return policy === "asset_state_direct_spec" ? "Direct-spec" : "Pooled-family";
}

function screenLabel(id) {
  return {
    A_live_like: "A: live-like",
    B_high_beta_long_history: "B: high-beta",
    C_etf_sector: "C: ETF/sector",
  }[id] || id;
}

function basketRoleLabel(id) {
  return {
    A_live_like: "Live-like stocks",
    B_high_beta_long_history: "High-beta stocks",
    C_etf_sector: "ETF/sector proxies",
  }[id] || id;
}

function riskContextLabel(row) {
  const symbols = row.context_symbols.split(",");
  const basket = row.symbols.split(",");
  const addOns = symbols.filter((s) => !basket.includes(s));
  return addOns.join(",");
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
    fontSize: style.fontSize || 20,
    color: style.color || "slate-800",
    bold: Boolean(style.bold),
    italic: Boolean(style.italic),
    alignment: style.alignment || "left",
  };
  return shape;
}

function addTitle(slide, title, kicker = "Gen5.1 research inspection") {
  addText(slide, kicker.toUpperCase(), 72, 42, 900, 28, { fontSize: 13, color: "slate-500", bold: true });
  addText(slide, title, 72, 78, 1080, 86, { fontSize: 36, color: "slate-950", bold: true });
  slide.shapes.add({
    geometry: "rect",
    position: { left: 72, top: 174, width: 1136, height: 2 },
    fill: "slate-200",
    line: { style: "solid", fill: "none", width: 0 },
  });
}

function addBullet(slide, text, left, top, width, fontSize = 19) {
  addText(slide, "-", left, top, 20, 24, { fontSize, color: "teal-700", bold: true });
  addText(slide, text, left + 28, top, width - 28, 48, { fontSize, color: "slate-800" });
}

function addMetricCard(slide, label, value, note, left, top, width, height = 116) {
  slide.shapes.add({
    geometry: "roundRect",
    position: { left, top, width, height },
    fill: "white",
    line: { style: "solid", fill: "slate-200", width: 1 },
    borderRadius: "rounded-lg",
  });
  addText(slide, label.toUpperCase(), left + 18, top + 16, width - 36, 18, { fontSize: 11, color: "slate-500", bold: true });
  addText(slide, value, left + 18, top + 40, width - 36, 34, { fontSize: 26, color: "slate-950", bold: true });
  addText(slide, note, left + 18, top + 78, width - 36, height - 82, { fontSize: 14, color: "slate-600" });
}

function addSimpleTable(slide, columns, rows, left, top, widths, rowHeight = 36, fontSize = 12) {
  const totalWidth = widths.reduce((a, b) => a + b, 0);
  slide.shapes.add({
    geometry: "rect",
    position: { left, top, width: totalWidth, height: rowHeight },
    fill: "slate-100",
    line: { style: "solid", fill: "slate-200", width: 1 },
  });
  let x = left;
  columns.forEach((col, idx) => {
    addText(slide, col, x + 7, top + 8, widths[idx] - 14, 18, { fontSize, color: "slate-600", bold: true });
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
      addText(slide, String(cell), x + 7, y + 8, widths[cidx] - 14, 20, { fontSize, color: "slate-800" });
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

function rowsForScreen(rows, screenId) {
  return rows.filter((r) => r.screen_id === screenId);
}

function summarizeScreen(rows, screenId) {
  const screenRows = rowsForScreen(rows, screenId);
  const directWins = [];
  const pooledWins = [];
  const windows = [...new Set(screenRows.map((r) => r.window_id))];
  for (const window of windows) {
    const pair = screenRows.filter((r) => r.window_id === window);
    const direct = pair.find((r) => r.selection_policy === "asset_state_direct_spec");
    const pooled = pair.find((r) => r.selection_policy === "pooled_family_asset_variant");
    if (!direct || !pooled) continue;
    const delta = Number(pooled.equal_symbol_mean_compound_trace_return) - Number(direct.equal_symbol_mean_compound_trace_return);
    if (delta > 0) pooledWins.push(window);
    else directWins.push(window);
  }
  const means = {};
  for (const policy of ["asset_state_direct_spec", "pooled_family_asset_variant"]) {
    const vals = screenRows.filter((r) => r.selection_policy === policy).map((r) => Number(r.equal_symbol_mean_compound_trace_return)).filter(Number.isFinite);
    means[policy] = vals.reduce((a, b) => a + b, 0) / vals.length;
  }
  return { windows: windows.length, directWins: directWins.length, pooledWins: pooledWins.length, directMean: means.asset_state_direct_spec, pooledMean: means.pooled_family_asset_variant };
}

const runSpec = await readCsv(path.join(runRoot, "selection_policy_basket_archetype_run_spec.csv"));
const portfolio = await readCsv(path.join(runRoot, "selection_policy_basket_archetype_portfolio_proxy_summary.csv"));
const agreement = await readCsv(path.join(runRoot, "selection_policy_basket_archetype_agreement_summary.csv"));
const screenIds = ["A_live_like", "B_high_beta_long_history", "C_etf_sector"];
const screenSummaries = Object.fromEntries(screenIds.map((id) => [id, summarizeScreen(portfolio, id)]));

await fs.mkdir(presentationDir, { recursive: true });
await fs.mkdir(slidePreviewDir, { recursive: true });

const presentation = Presentation.create({ slideSize: { width: 1280, height: 720 } });

{
  const slide = presentation.slides.add();
  slide.background.fill = "slate-50";
  addText(slide, "Gen5.1 Selection Policy x Basket Archetype Screen", 72, 84, 1060, 58, { fontSize: 40, color: "slate-950", bold: true });
  addText(slide, "Direct-spec versus pooled-family selection across live-like, high-beta, and ETF/sector baskets", 72, 154, 1040, 48, { fontSize: 24, color: "slate-700" });
  addText(slide, "Why: the Gen4 bridge and current Gen5.1 research engine select strategy authority differently. This packet asks whether that difference is an AMD/live-basket artifact, a high-beta single-name phenomenon, or a more general regime-selection behavior.", 72, 242, 1040, 96, { fontSize: 22, color: "slate-700" });
  addMetricCard(slide, "PCA surface", "behavioral pool", "Active-plus-risk context; 3x3 quantile states", 72, 424, 330);
  addMetricCard(slide, "Policy factor", "2 lanes", "Direct-spec vs pooled-family selection", 452, 424, 330);
  addMetricCard(slide, "Basket factor", "3 archetypes", "Live-like, high-beta, ETF/sector", 832, 424, 330);
  addText(slide, "Inspection only: portfolio/replay summaries are not accepted allocation evidence.", 72, 618, 1040, 30, { fontSize: 17, color: "slate-500", bold: true });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Question And Design");
  addBullet(slide, "What we knew: active-plus-risk context, behavioral-pool PCA, and 3x3 quantile states had become the cleanest near-term research lane.", 84, 226, 1040);
  addBullet(slide, "What we did not know: whether direct full-spec selection or Gen4-style pooled-family selection is structurally better, or whether each has a basket-specific niche.", 84, 306, 1040);
  addBullet(slide, "Design choice: keep context/PCA/state/grid fixed, then vary only basket archetype and selection policy.", 84, 386, 1040);
  addSimpleTable(
    slide,
    ["Screen", "Traded/research basket", "Regime context construction", "Windows"],
    runSpec.map((r) => [
      screenLabel(r.screen_id),
      r.symbols,
      `Basket plus ${riskContextLabel(r)}`,
      r.replay_windows.split(",").length,
    ]),
    82,
    500,
    [140, 320, 520, 90],
    38,
    12
  );
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Each Basket Had Its Own Matching Context Universe");
  addText(slide, "This was not one context universe reused across all tests. Each screen traded and researched one basket, then built PCA regimes from that same basket plus market/risk context symbols.", 86, 214, 1040, 56, { fontSize: 21, color: "slate-700", bold: true });
  addSimpleTable(
    slide,
    ["Screen", "Basket role", "Research / tradeable basket", "Added risk context"],
    runSpec.map((r) => [screenLabel(r.screen_id), basketRoleLabel(r.screen_id), r.symbols, riskContextLabel(r)]),
    70,
    318,
    [140, 190, 330, 420],
    44,
    12
  );
  addBullet(slide, "Recent live-like screen includes VXX in the risk add-on because the date range is recent enough.", 92, 548, 1040, 18);
  addBullet(slide, "Older-history high-beta and ETF/sector screens omit VXX so the 2019-forward tests are not distorted by VXX’s later start date.", 92, 610, 1040, 18);
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Top-Level Readout");
  const rows = screenIds.map((id) => {
    const s = screenSummaries[id];
    return [screenLabel(id), `${s.pooledWins}-${s.directWins}`, pct(s.directMean), pct(s.pooledMean), pct(s.pooledMean - s.directMean)];
  });
  addSimpleTable(slide, ["Basket", "Pooled-Direct windows", "Direct mean", "Pooled mean", "Pooled minus direct"], rows, 100, 232, [230, 190, 150, 150, 180], 48, 14);
  addBullet(slide, "Pooled-family led the mean proxy in the live-like and ETF/sector lanes, but the high-beta long-history lane was sharply mixed and AMD/TSLA-sensitive.", 100, 536, 1020, 19);
  addBullet(slide, "The result argues against prematurely retiring either policy. It supports treating selection policy as a declared factor in future focused screens.", 100, 600, 1020, 19);
}

for (const screenId of screenIds) {
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, `${screenLabel(screenId)} Metric Dashboard`);
  await addImage(
    slide,
    path.join(runRoot, screenId, "visual_summary", "selection_policy_metric_delta_dashboard.png"),
    58,
    196,
    1164,
    420,
    `${screenLabel(screenId)} metric dashboard`,
    "contain"
  );
  const s = screenSummaries[screenId];
  addText(slide, `Mean replay proxy: Direct ${pct(s.directMean)} vs Pooled ${pct(s.pooledMean)}. Pooled led ${s.pooledWins} of ${s.windows} windows.`, 90, 632, 1050, 32, { fontSize: 17, color: "slate-700", bold: true });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Where The Difference Concentrated");
  await addImage(slide, path.join(runRoot, "B_high_beta_long_history", "visual_summary", "selection_policy_symbol_return_delta_heatmap.png"), 48, 200, 570, 360, "High-beta symbol delta heatmap", "contain");
  await addImage(slide, path.join(runRoot, "C_etf_sector", "visual_summary", "selection_policy_symbol_return_delta_heatmap.png"), 660, 200, 570, 360, "ETF sector symbol delta heatmap", "contain");
  addText(slide, "Heatmaps show pooled minus direct by symbol/window. The high-beta lane contains larger single-name effects; the ETF lane is more compact, which is useful generalization context.", 78, 594, 1080, 52, { fontSize: 18, color: "slate-700", bold: true });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Selection Maps Did Not Match Perfectly");
  const allRows = agreement.filter((r) => r.quarter_id === "ALL");
  addSimpleTable(
    slide,
    ["Basket", "Rows", "Family match", "Spec match"],
    allRows.map((r) => [screenLabel(r.screen_id), r.state_asset_rows, pct(r.family_match_rate), pct(r.spec_match_rate)]),
    120,
    228,
    [300, 130, 180, 180],
    52,
    15
  );
  addBullet(slide, "Direct and pooled-family maps overlap enough to be related, but not enough to be interchangeable.", 120, 466, 940, 20);
  addBullet(slide, "ETF/sector had the lowest overall match rate, which suggests the policy factor changes behavior even outside the volatile single-name basket.", 120, 536, 940, 20);
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Guardrails And Next Decision");
  addBullet(slide, "All authority selection remains TRAIN-only; OOS replay consumes frozen maps.", 90, 226, 1040);
  addBullet(slide, "Older-history lanes omit VXX from active-plus-risk context to avoid pre-2018 partial-history contamination.", 90, 296, 1040);
  addBullet(slide, "This deck compares inspection proxies, not accepted allocation evidence or live trading authority.", 90, 366, 1040);
  addBullet(slide, "Recommended next slice: keep active-plus-risk / behavioral-pool / 3x3 fixed and test selection policy as an explicit factor on a narrower active basket with full portfolio accounting review.", 90, 456, 1040);
}

const montage = await presentation.export({ format: "webp", montage: true, scale: 1 });
await fs.writeFile(montagePath, new Uint8Array(await montage.arrayBuffer()));
for (const [index, slide] of presentation.slides.items.entries()) {
  const preview = await presentation.export({ slide, format: "png", scale: 1 });
  await fs.writeFile(path.join(slidePreviewDir, `slide-${String(index + 1).padStart(2, "0")}.png`), new Uint8Array(await preview.arrayBuffer()));
}
const inspect = await presentation.inspect({ kind: "slide,textbox,shape,image,chart,table,layout", maxChars: 42000 });
await fs.writeFile(inspectPath, inspect.ndjson);
const pptx = await PresentationFile.exportPptx(presentation);
await pptx.save(finalPptx);

console.log(`Wrote ${finalPptx}`);
console.log(`Wrote ${inspectPath}`);
console.log(`Wrote ${montagePath}`);
console.log(`Wrote slide previews to ${slidePreviewDir}`);
