import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const artifactModule = process.env.ARTIFACT_TOOL_MODULE || "C:/Users/Franc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactModule).href);
const atlasRoot = process.env.GEN5_MS_P0_ATLAS_ROOT || path.join(repoRoot, "runs", "research_workbench", "meta_label_candidate_atlas", "ms_p0_candidate_atlas_2020_2024");
const presentations = path.join(repoRoot, "presentations");
const finalPptx = process.env.GEN5_MS_P0_DECK_OUT || path.join(presentations, "gen5_4_strategy_meta_label_candidate_atlas.pptx");
const previewDir = path.join(presentations, "gen5_4_strategy_meta_label_candidate_atlas_slides");
const montagePath = path.join(presentations, "gen5_4_strategy_meta_label_candidate_atlas_montage.webp");
const inspectPath = path.join(presentations, "gen5_4_strategy_meta_label_candidate_atlas.inspect.ndjson");

function parseCsv(text) {
  const rows = []; let row = []; let field = ""; let quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i]; const next = text[i + 1];
    if (quoted) { if (ch === '"' && next === '"') { field += '"'; i += 1; } else if (ch === '"') quoted = false; else field += ch; }
    else if (ch === '"') quoted = true;
    else if (ch === ",") { row.push(field); field = ""; }
    else if (ch === "\n") { row.push(field); rows.push(row); row = []; field = ""; }
    else if (ch !== "\r") field += ch;
  }
  if (field.length || row.length) { row.push(field); rows.push(row); }
  const header = rows.shift() || [];
  return rows.filter((r) => r.length === header.length).map((r) => Object.fromEntries(header.map((h, i) => [h, r[i]])));
}
async function readCsv(p) { return parseCsv(await fs.readFile(p, "utf8")); }
function num(x) { const n = Number(x); return Number.isFinite(n) ? n : NaN; }
function pct(x, d = 1) { const n = num(x); return Number.isFinite(n) ? `${(100 * n).toFixed(d)}%` : "NA"; }
function pp(x, d = 1) { const n = num(x); return Number.isFinite(n) ? `${(100 * n).toFixed(d)} pp` : "NA"; }
function addText(slide, text, left, top, width, height, style = {}) {
  const shape = slide.shapes.add({ geometry: "textbox", position: { left, top, width, height }, fill: "none", line: { style: "solid", fill: "none", width: 0 } });
  shape.text = text;
  shape.text.style = { fontSize: style.fontSize || 20, color: style.color || "#222222", bold: Boolean(style.bold), italic: Boolean(style.italic), alignment: style.alignment || "left" };
}
function addRule(slide, left = 72, top = 174, width = 1136) { slide.shapes.add({ geometry: "rect", position: { left, top, width, height: 2 }, fill: "#B8BCC4", line: { style: "solid", fill: "none", width: 0 } }); }
function addTitle(slide, title) { addText(slide, "GEN5.4 STRATEGY META-LABEL RESEARCH", 72, 42, 900, 26, { fontSize: 13, color: "#555555", bold: true }); addText(slide, title, 72, 76, 1080, 92, { fontSize: 38, color: "#000000", bold: true }); addRule(slide); }
function addBullet(slide, text, left, top, width, fontSize = 21) { addText(slide, "-", left, top + 1, 20, 26, { fontSize, color: "#FF6B35", bold: true }); addText(slide, text, left + 28, top, width - 28, 58, { fontSize, color: "#222222" }); }
function addMetric(slide, label, value, note, left, top, width) {
  slide.shapes.add({ geometry: "rect", position: { left, top, width, height: 146 }, fill: "#EDEDED", line: { style: "solid", fill: "#B8BCC4", width: 1 } });
  addText(slide, label.toUpperCase(), left + 18, top + 16, width - 36, 18, { fontSize: 12, color: "#555555", bold: true });
  addText(slide, value, left + 18, top + 44, width - 36, 38, { fontSize: 29, color: "#000000", bold: true });
  addText(slide, note, left + 18, top + 88, width - 36, 40, { fontSize: 15, color: "#555555" });
}
async function addImage(slide, file, left, top, width, height, alt) {
  const bytes = await fs.readFile(file);
  slide.images.add({ blob: bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), contentType: "image/png", alt, fit: "contain", position: { left, top, width, height } });
}
function transition(deck, headline, code, subtitle) {
  const slide = deck.slides.add(); slide.background.fill = "#FFFFFF";
  addText(slide, "Transition", 72, 52, 500, 44, { fontSize: 32, color: "#555555", bold: true });
  addText(slide, headline, 72, 154, 810, 130, { fontSize: 48, color: "#000000", bold: true }); addRule(slide, 76, 326, 600);
  addText(slide, subtitle, 76, 364, 790, 138, { fontSize: 24, color: "#222222" });
  slide.shapes.add({ geometry: "rect", position: { left: 924, top: 0, width: 356, height: 720 }, fill: "#F2F2F2", line: { style: "solid", fill: "none", width: 0 } });
  addText(slide, code, 982, 246, 230, 46, { fontSize: 42, color: "#000000", bold: true, alignment: "center" });
  addText(slide, "Candidate atlas", 952, 322, 290, 48, { fontSize: 25, color: "#222222", alignment: "center" });
}

async function main() {
  const catalog = await readCsv(path.join(atlasRoot, "ms_p0_candidate_atlas_run_catalog.csv"));
  const available = catalog.filter((r) => r.available === "TRUE");
  if (available.length !== 40) throw new Error(`Atlas is incomplete: ${available.length} of 40 packets are available.`);
  const family = await readCsv(path.join(atlasRoot, "ms_p0_candidate_atlas_family_summary.csv"));
  const windows = await readCsv(path.join(atlasRoot, "ms_p0_candidate_atlas_window_summary.csv"));
  const tapes = await readCsv(path.join(atlasRoot, "ms_p0_candidate_atlas_trade_tape_index.csv"));
  const leaders = [...family].sort((a, b) => num(b.mean_total_return_excess) - num(a.mean_total_return_excess));
  const strongest = leaders[0];
  const weak = leaders[leaders.length - 1];
  const tapeRows = [...tapes].sort((a, b) => {
    const aw = windows.find((r) => r.family === a.family && r.oos_window === a.oos_window);
    const bw = windows.find((r) => r.family === b.family && r.oos_window === b.oos_window);
    return num(bw?.mean_total_return_excess) - num(aw?.mean_total_return_excess);
  }).filter((r, i, a) => i === 0 || r.family !== a[0].family || r.oos_window !== a[0].oos_window).slice(0, 2);

  await fs.mkdir(presentations, { recursive: true }); await fs.mkdir(previewDir, { recursive: true });
  const deck = Presentation.create({ slideSize: { width: 1280, height: 720 } });

  { const s = deck.slides.add(); s.background.fill = "#FFFFFF";
    addText(s, "Gen5.4", 72, 48, 300, 54, { fontSize: 30, color: "#555555", bold: true });
    addText(s, "Strategy meta-label candidate atlas", 72, 158, 720, 138, { fontSize: 54, color: "#000000", bold: true });
    addText(s, "A raw-strategy sanity check before we ask ML to gate any candidate signal.", 76, 324, 690, 72, { fontSize: 25, color: "#222222" }); addRule(s, 76, 442, 540);
    addText(s, "Research only: no live bridge change, no allocation evidence, and no model fit in this stage.", 76, 476, 650, 72, { fontSize: 20, color: "#555555" });
    s.shapes.add({ geometry: "rect", position: { left: 854, top: 0, width: 426, height: 720 }, fill: "#EDEDED", line: { style: "solid", fill: "none", width: 0 } });
    addText(s, "MS-P0", 928, 248, 260, 50, { fontSize: 38, color: "#000000", bold: true, alignment: "center" });
    addText(s, "Raw candidate behavior\nacross five windows", 908, 326, 300, 88, { fontSize: 25, color: "#222222", alignment: "center" }); }

  transition(deck, "From direct price prediction to strategy-conditioned evidence", "MS-P0", "The direct ML work did not show enough daily ranking separation. Here, a strategy still creates the entry/exit candidate; the later ML question is only whether the current context should permit it.");

  { const s = deck.slides.add(); s.background.fill = "#FFFFFF"; addTitle(s, "The test holds the WFA contract fixed");
    addMetric(s, "Symbols", "5", "AMD, NVDA, TSLA, MSTR, AVGO", 82, 222, 250); addMetric(s, "TRAIN", "8 quarters", "Fold-local selection and thresholds", 392, 222, 250); addMetric(s, "OOS", "4 folds", "Four fixed 91-day authorities", 702, 222, 250); addMetric(s, "Packets", "40", "8 candidate families x 5 windows", 1012, 222, 200);
    addBullet(s, "Each family is run alone, alongside both abstention competitors: no_trade and no_trade_exit_immediate.", 110, 440, 940);
    addBullet(s, "The state map is diagnostic only: fold-local TRAIN medians classify OOS trend and realized volatility after the strategy has been selected.", 110, 516, 940);
    addBullet(s, "No result can alter live advice, execution, leverage, or allocation in this POC.", 110, 592, 940); }

  { const s = deck.slides.add(); s.background.fill = "#FFFFFF"; addTitle(s, "The state map asks a deliberately simple conditional question");
    s.shapes.add({ geometry: "rect", position: { left: 150, top: 244, width: 396, height: 126 }, fill: "#EAF4EA", line: { style: "solid", fill: "#9AB89A", width: 1 } });
    s.shapes.add({ geometry: "rect", position: { left: 594, top: 244, width: 396, height: 126 }, fill: "#F9E8E8", line: { style: "solid", fill: "#D79D9D", width: 1 } });
    s.shapes.add({ geometry: "rect", position: { left: 150, top: 410, width: 396, height: 126 }, fill: "#F9E8E8", line: { style: "solid", fill: "#D79D9D", width: 1 } });
    s.shapes.add({ geometry: "rect", position: { left: 594, top: 410, width: 396, height: 126 }, fill: "#EAF4EA", line: { style: "solid", fill: "#9AB89A", width: 1 } });
    addText(s, "Confirmed trend\nQuiet volatility", 188, 272, 320, 68, { fontSize: 27, bold: true, alignment: "center" }); addText(s, "Confirmed trend\nElevated volatility", 632, 272, 320, 68, { fontSize: 27, bold: true, alignment: "center" });
    addText(s, "Weak trend\nQuiet volatility", 188, 438, 320, 68, { fontSize: 27, bold: true, alignment: "center" }); addText(s, "Weak trend\nElevated volatility", 632, 438, 320, 68, { fontSize: 27, bold: true, alignment: "center" });
    addText(s, "TRAIN-only median 20-session return defines trend; TRAIN-only median 20-session realized volatility defines the risk split. The plots compare raw strategy return with hold and raw long exposure in each OOS cell.", 130, 594, 970, 64, { fontSize: 21, color: "#555555", alignment: "center" }); }

  { const s = deck.slides.add(); s.background.fill = "#FFFFFF"; addTitle(s, "The candidate list is intentionally broad, but not a model search");
    addText(s, "Trend and breakout", 104, 228, 350, 34, { fontSize: 26, bold: true }); addText(s, "EMA cross, EMA trend, breakout, pullback in uptrend", 104, 278, 440, 92, { fontSize: 23, color: "#222222" });
    addText(s, "Mean reversion", 630, 228, 350, 34, { fontSize: 26, bold: true }); addText(s, "Bollinger touch, Bollinger mid-reversion, RSI mean reversion, z-return mean reversion", 630, 278, 470, 110, { fontSize: 23, color: "#222222" });
    addRule(s, 96, 430, 1060); addText(s, "EMA trend receives a wider but predeclared grid: fast 1, 5, 10, 15, 20 against slow 10, 15, 20, 50, 75, valid fast < slow pairs only.", 108, 472, 1000, 60, { fontSize: 23, color: "#222222" });
    addText(s, "The aim is not to crown a winner from a large search. It is to check whether any familiar candidate has a coherent conditional behavior before adding an ML gate on top of it.", 108, 572, 1010, 66, { fontSize: 22, color: "#555555" }); }

  transition(deck, "Now we read the cross-family evidence", "MS-P0", "The summary shows raw strategy-minus-hold results across the same five annual windows, followed by the common state-map view. These are inspection findings, not a promotion decision.");

  { const s = deck.slides.add(); s.background.fill = "#FFFFFF"; addTitle(s, "Raw strategy-versus-hold results vary by family and window");
    await addImage(s, path.join(atlasRoot, "ms_p0_family_window_total_return_excess.png"), 56, 202, 840, 480, "Family window mean strategy total-return excess heatmap");
    addText(s, "How to read it", 936, 226, 250, 32, { fontSize: 26, bold: true });
    addText(s, "Each cell averages the five individual asset returns after independently selecting that family inside each fold. Green is raw strategy return above buy-and-hold; red is below.", 928, 282, 270, 160, { fontSize: 21, color: "#222222" });
    addText(s, `Highest mean family: ${strongest.family} (${pp(strongest.mean_total_return_excess)}). Lowest: ${weak.family} (${pp(weak.mean_total_return_excess)}). These averages are descriptive, not selection evidence.`, 928, 492, 270, 126, { fontSize: 20, color: "#555555" }); }

  { const s = deck.slides.add(); s.background.fill = "#FFFFFF"; addTitle(s, "The common state map exposes whether a family has a coherent conditional mechanism");
    await addImage(s, path.join(atlasRoot, "ms_p0_family_state_excess_heatmap.png"), 60, 204, 550, 420, "Family state daily excess heatmap");
    await addImage(s, path.join(atlasRoot, "ms_p0_family_state_exposure_heatmap.png"), 658, 204, 550, 420, "Family state exposure heatmap");
    addText(s, "Left: mean daily strategy minus hold return. Right: mean raw long exposure. A meta-label candidate needs a story that is stable across windows, not simply a positive green cell.", 100, 646, 1060, 38, { fontSize: 19, color: "#555555", alignment: "center" }); }

  { const s = deck.slides.add(); s.background.fill = "#FFFFFF"; addTitle(s, "Representative tapes keep the aggregate charts honest");
    await addImage(s, tapeRows[0].strategy_chart_png, 52, 204, 570, 416, `${tapeRows[0].family} ${tapeRows[0].oos_window} ${tapeRows[0].symbol} trade tape`);
    await addImage(s, tapeRows[1].strategy_chart_png, 658, 204, 570, 416, `${tapeRows[1].family} ${tapeRows[1].oos_window} ${tapeRows[1].symbol} trade tape`);
    addText(s, `${tapeRows[0].family} | ${tapeRows[0].oos_window} | ${tapeRows[0].symbol}`, 70, 638, 520, 26, { fontSize: 18, color: "#555555", alignment: "center" });
    addText(s, `${tapeRows[1].family} | ${tapeRows[1].oos_window} | ${tapeRows[1].symbol}`, 676, 638, 520, 26, { fontSize: 18, color: "#555555", alignment: "center" }); }

  { const s = deck.slides.add(); s.background.fill = "#FFFFFF"; addTitle(s, "What would justify a true meta-label POC next?");
    addBullet(s, "A family must show an understandable state-level relative edge that repeats across more than one window and does not rest on a single symbol.", 110, 230, 960, 23);
    addBullet(s, "The apparent edge must correspond to a usable action: permit, veto, or reduce confidence in an existing strategy signal. It should not invent a second opaque entry rule.", 110, 330, 960, 23);
    addBullet(s, "If no family clears that bar, stop. Diagnose the raw strategy and benchmark relationship rather than adding ML complexity to noise.", 110, 430, 960, 23);
    addBullet(s, "Any future MS-P1 gate remains research-only and must preserve fold-local fitting, next-open alignment, and the frozen live bridge boundary.", 110, 530, 960, 23); }

  const inspect = await deck.inspect({ kind: "slide,textbox,shape,image,layout", maxChars: 20000 }); await fs.writeFile(inspectPath, inspect.ndjson, "utf8");
  for (const [i, slide] of deck.slides.items.entries()) { const png = await deck.export({ slide, format: "png", scale: 1.5 }); await fs.writeFile(path.join(previewDir, `slide-${String(i + 1).padStart(2, "0")}.png`), new Uint8Array(await png.arrayBuffer())); }
  const montage = await deck.export({ format: "webp", montage: true, scale: 1 }); await fs.writeFile(montagePath, new Uint8Array(await montage.arrayBuffer()));
  const pptx = await PresentationFile.exportPptx(deck); await pptx.save(finalPptx); console.log(`Wrote ${finalPptx}`);
}
main().catch((err) => { console.error(err); process.exitCode = 1; });
