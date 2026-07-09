import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const skillDir =
  process.env.GEN5_PRESENTATIONS_SKILL_DIR ||
  "C:\\Users\\Franc\\.codex\\plugins\\cache\\openai-primary-runtime\\presentations\\26.630.12135\\skills\\presentations";
const artifactWorkspace =
  process.env.GEN5_ARTIFACT_WORKSPACE ||
  path.join(os.tmpdir(), "codex-presentations", "gen52-style-diversified-live-capital");
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
  throw new Error(
    `Could not find artifact-tool entrypoint under ${artifactWorkspace}. Run: node "${path.join(skillDir, "container_tools", "setup_artifact_tool_workspace.mjs")}" --workspace "${artifactWorkspace}"`,
  );
}

const { Presentation, PresentationFile } = await import(pathToFileURL(artifactEntrypoint).href);

const packetDir = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "gen52_generalization",
  "style_diversified_live_capital_20260708",
);
const outputPptx = path.join(repoRoot, "presentations", "gen5_2_style_diversified_live_capital_screen.pptx");
const previewDir = path.join(packetDir, "presentation_preview");

const paths = {
  summary: path.join(packetDir, "style_diversified_live_capital_summary.csv"),
  aggregate: path.join(packetDir, "style_diversified_live_capital_aggregate.csv"),
  heatmap: path.join(packetDir, "style_diversified_live_capital_alpha_heatmap.png"),
  equity: path.join(packetDir, "style_diversified_live_capital_equity_overlay.png"),
  scatter: path.join(packetDir, "style_diversified_live_capital_exposure_alpha_scatter.png"),
  report: path.join(packetDir, "style_diversified_live_capital_report.md"),
};

const colors = {
  ink: "#101216",
  muted: "#59606A",
  rule: "#C8CDD4",
  panel: "#F2F4F6",
  canvas: "#FFFFFF",
  direct: "#2E86AB",
  pooled: "#9B5DE5",
  continuation: "#00A88F",
  warn: "#D1495B",
  accent: "#FF9F1C",
  good: "#127A62",
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

function addTitle(slide, title, kicker = "Gen5.2 style-diversified live-capital screen") {
  addText(slide, kicker, { left: 42, top: 34, width: 760, height: 28 }, { fontSize: 16, bold: true, color: colors.muted });
  addText(slide, title, { left: 42, top: 74, width: 1120, height: 88 }, { fontSize: 39, bold: true });
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

function addBullets(slide, bullets, left, top, width, fontSize = 20, gap = 54) {
  bullets.forEach((bullet, index) => {
    addText(slide, "-", { left, top: top + index * gap, width: 18, height: 28 }, { fontSize, bold: true, color: bullet.color ?? colors.ink });
    addText(slide, bullet.text, { left: left + 28, top: top + index * gap, width, height: gap }, { fontSize, color: bullet.textColor ?? colors.muted });
  });
}

function addMetric(slide, label, value, position, color = colors.ink) {
  addText(slide, value, { left: position.left, top: position.top, width: position.width, height: 52 }, { fontSize: 35, bold: true, color });
  addText(slide, label, { left: position.left, top: position.top + 56, width: position.width, height: 44 }, { fontSize: 15, color: colors.muted });
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

function findSummary(rows, basket, policy, semantics, window) {
  return rows.find((row) =>
    row.basket_archetype === basket &&
    row.selection_policy === policy &&
    row.entry_replay_semantics === semantics &&
    row.window_id.startsWith(window)
  );
}

function findAggregate(rows, basket, policy, semantics) {
  return rows.find((row) =>
    row.basket_archetype === basket &&
    row.selection_policy === policy &&
    row.entry_replay_semantics === semantics
  );
}

const summary = await readCsv(paths.summary);
const aggregate = await readCsv(paths.aggregate);

const hbDirectFresh2020 = findSummary(summary, "high_beta_growth", "asset_state_direct_spec", "fresh_signal_only", "2020Q3");
const hbDirectCont2020 = findSummary(summary, "high_beta_growth", "asset_state_direct_spec", "state_switch_continuation", "2020Q3");
const hbPooledCont2022 = findSummary(summary, "high_beta_growth", "pooled_family_asset_variant", "state_switch_continuation", "2022Q1");
const comPooledFresh2020 = findSummary(summary, "energy_commodity", "pooled_family_asset_variant", "fresh_signal_only", "2020Q3");
const defDirectCont2022 = findSummary(summary, "defensive_staples", "asset_state_direct_spec", "state_switch_continuation", "2022Q1");
const hbPooledContAgg = findAggregate(aggregate, "high_beta_growth", "pooled_family_asset_variant", "state_switch_continuation");
const defBestAgg = findAggregate(aggregate, "defensive_staples", "asset_state_direct_spec", "state_switch_continuation");
const comPooledAgg = findAggregate(aggregate, "energy_commodity", "pooled_family_asset_variant", "fresh_signal_only");

const deck = Presentation.create({ slideSize: { width: 1280, height: 720 } });

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addText(slide, "Gen5.2 generalization probe", { left: 42, top: 52, width: 560, height: 44 }, { fontSize: 22, bold: true, color: colors.muted });
  addText(slide, "Can the mechanics find alpha outside one hot high-beta story?", { left: 42, top: 172, width: 1080, height: 190 }, { fontSize: 55, bold: true });
  addText(
    slide,
    "This screen moves from SOFI/AMD calibration into a deliberately style-diversified live-capital replay: high beta, defensive staples, and energy/commodity baskets across one upside window and one stress window.",
    { left: 42, top: 430, width: 930, height: 96 },
    { fontSize: 24, color: colors.muted },
  );
  addFooter(slide, 1);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The experiment separates mimicry from generalization");
  addPanel(slide, { left: 42, top: 218, width: 360, height: 310 });
  addPanel(slide, { left: 460, top: 218, width: 360, height: 310 });
  addPanel(slide, { left: 878, top: 218, width: 360, height: 310 });
  addText(slide, "What we were leaving", { left: 72, top: 250, width: 280, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "The prior thread asked why Gen5.2 did not recreate a memorable Gen4 SOFI/AMD path. Useful, but vulnerable to overfitting one story.", { left: 72, top: 310, width: 285, height: 150 }, { fontSize: 20, color: colors.muted });
  addText(slide, "What we asked now", { left: 490, top: 250, width: 280, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "Do direct-spec, pooled-family, fresh-signal, and continuation mechanics behave sensibly across assets with very different return drivers?", { left: 490, top: 310, width: 285, height: 150 }, { fontSize: 20, color: colors.muted });
  addText(slide, "What was held fixed", { left: 908, top: 250, width: 280, height: 34 }, { fontSize: 26, bold: true });
  addText(slide, "Behavioral-pool PCA, 3x3 quantile states, Gen5.2 scoring, broad anchors, no VXX, and true shared-account live-capital replay.", { left: 908, top: 310, width: 285, height: 150 }, { fontSize: 20, color: colors.muted });
  addFooter(slide, 2);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The baskets were chosen to stress different market physics");
  const panels = [
    ["High beta growth", "AMD, NVDA, TSLA, AAPL, MSTR", "Fast upside, deep drawdowns, high trend sensitivity."],
    ["Defensive staples", "KO, PEP, WMT, COST, XLP", "Slower upside, lower beta, drawdown avoidance matters."],
    ["Energy and metals", "XLE, CVX, XOM, GLD, SLV", "Commodity and rate-sensitive behavior, not tech beta."],
  ];
  panels.forEach((panel, index) => {
    const left = 42 + index * 418;
    addPanel(slide, { left, top: 220, width: 360, height: 300 });
    addText(slide, panel[0], { left: left + 30, top: 252, width: 285, height: 34 }, { fontSize: 25, bold: true });
    addText(slide, panel[1], { left: left + 30, top: 315, width: 285, height: 76 }, { fontSize: 22, bold: true, color: index === 0 ? colors.direct : index === 1 ? colors.continuation : colors.accent });
    addText(slide, panel[2], { left: left + 30, top: 428, width: 285, height: 88 }, { fontSize: 19, color: colors.muted });
  });
  addText(slide, "Each basket used its own symbols plus the same broad anchors: SPY, QQQ, IWM, TLT, GLD. The context recipe was intentionally simple so the first readout focused on asset style and replay mechanics.", { left: 42, top: 590, width: 1030, height: 46 }, { fontSize: 19, color: colors.muted });
  addFooter(slide, 3);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The first answer is not a simple exposure story");
  addPanel(slide, { left: 42, top: 212, width: 360, height: 348 });
  addPanel(slide, { left: 460, top: 212, width: 360, height: 348 });
  addPanel(slide, { left: 878, top: 212, width: 360, height: 348 });
  addMetric(slide, pp(n(hbDirectCont2020?.alpha_vs_active_equal) - n(hbDirectFresh2020?.alpha_vs_active_equal)), "Continuation alpha lift in high-beta 2020Q3 versus direct fresh", { left: 72, top: 250, width: 280 }, colors.continuation);
  addText(slide, `But it still lagged basket hold by ${pp(hbDirectCont2020?.alpha_vs_active_equal)}. More exposure helped, but did not fully capture the rebound.`, { left: 72, top: 380, width: 285, height: 118 }, { fontSize: 19, color: colors.muted });
  addMetric(slide, pp(hbPooledCont2022?.alpha_vs_active_equal), "Pooled continuation alpha in high-beta 2022Q1", { left: 490, top: 250, width: 280 }, colors.pooled);
  addText(slide, "The system beat the falling high-beta basket in the stress window, which is exactly the kind of behavior that pure buy-and-hold cannot provide.", { left: 490, top: 380, width: 285, height: 118 }, { fontSize: 19, color: colors.muted });
  addMetric(slide, pp(comPooledFresh2020?.alpha_vs_active_equal), "Commodity pooled fresh alpha in 2020Q3", { left: 908, top: 250, width: 280 }, colors.accent);
  addText(slide, "Commodity behavior did not mirror high beta: pooled-family helped in one window, but the system badly under-captured the 2022 commodity surge.", { left: 908, top: 380, width: 285, height: 118 }, { fontSize: 19, color: colors.muted });
  addFooter(slide, 4);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Basket-relative alpha is highly regime dependent");
  await addImage(slide, paths.heatmap, { left: 75, top: 198, width: 710, height: 430 }, "Alpha heatmap versus equal-weight basket hold");
  addText(slide, "How to read it", { left: 840, top: 220, width: 260, height: 34 }, { fontSize: 27, bold: true });
  addBullets(slide, [
    { text: "Green means the live-capital replay beat equal-weight buy-and-hold of the same basket." },
    { text: "High beta flipped from deeply negative alpha in 2020Q3 to positive alpha in 2022Q1." },
    { text: "Defensive staples were consistently behind their own basket hold in these two windows." },
    { text: "Energy/commodity pooled-family helped in 2020Q3 but missed the 2022Q1 commodity upside." },
  ], 840, 284, 335, 18, 64);
  addFooter(slide, 5);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Equity paths show protection and under-participation side by side");
  await addImage(slide, paths.equity, { left: 42, top: 190, width: 840, height: 455 }, "Style-diversified live-capital equity overlay");
  addText(slide, "Main visual readout", { left: 920, top: 214, width: 270, height: 34 }, { fontSize: 27, bold: true });
  addBullets(slide, [
    { text: "The high-beta 2020Q3 basket ripped higher faster than the active system participated." },
    { text: "The high-beta 2022Q1 system avoided enough downside to beat the falling basket." },
    { text: "Commodity 2022Q1 is a warning: strong alternative-asset trends can also be under-captured." },
  ], 920, 282, 280, 18, 76);
  addFooter(slide, 6);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "Exposure explains some of the result, but not all of it");
  await addImage(slide, paths.scatter, { left: 60, top: 196, width: 690, height: 435 }, "Exposure versus basket-relative alpha scatter");
  addText(slide, "Interpretation", { left: 815, top: 220, width: 280, height: 34 }, { fontSize: 27, bold: true });
  addBullets(slide, [
    { text: "Continuation generally pushed exposure higher, especially in high beta." },
    { text: "Higher exposure was useful when the state route was directionally right, but it did not guarantee alpha." },
    { text: "The next research question is not simply 'trade more'; it is how to participate more during favorable regimes without giving back stress-window protection." },
  ], 815, 284, 370, 18, 76);
  addFooter(slide, 7);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The result keeps both policy families alive");
  addPanel(slide, { left: 42, top: 214, width: 545, height: 342 });
  addPanel(slide, { left: 650, top: 214, width: 545, height: 342 });
  addText(slide, "What looks promising", { left: 72, top: 246, width: 360, height: 34 }, { fontSize: 27, bold: true });
  addBullets(slide, [
    { text: `High-beta pooled continuation had the best two-window mean alpha among high-beta lanes: ${pp(hbPooledContAgg?.mean_alpha_vs_active_equal)}.` },
    { text: `Defensive direct continuation was the least bad defensive lane: ${pp(defBestAgg?.mean_alpha_vs_active_equal)} mean alpha.` },
    { text: `Commodity pooled-family was the cleanest commodity lane, but still averaged ${pp(comPooledAgg?.mean_alpha_vs_active_equal)}.` },
  ], 72, 306, 445, 17, 62);
  addText(slide, "What is not solved", { left: 680, top: 246, width: 360, height: 34 }, { fontSize: 27, bold: true });
  addBullets(slide, [
    { text: "No lane beat its own basket in both tested windows." },
    { text: "Continuation improved high-beta upside capture, but it also increased drawdown in the same rebound window." },
    { text: "The system still needs a participation mechanism that knows when stronger trend exposure is warranted." },
  ], 680, 306, 445, 17, 62);
  addFooter(slide, 8);
}

{
  const slide = deck.slides.add();
  slide.background.fill = colors.canvas;
  addTitle(slide, "The next minimal test should target participation quality");
  addPanel(slide, { left: 42, top: 214, width: 545, height: 330 });
  addPanel(slide, { left: 650, top: 214, width: 545, height: 330 });
  addText(slide, "Recommended next slice", { left: 72, top: 246, width: 360, height: 34 }, { fontSize: 27, bold: true });
  addBullets(slide, [
    { text: "Stay on the same three baskets and two windows so the comparison remains anchored." },
    { text: "Keep 3x3 behavioral-pool states and the same broad context recipe." },
    { text: "Add one explicit participation factor, such as trend-state entry aggressiveness or a bull-regime exposure gate, rather than expanding the whole factorial." },
  ], 72, 306, 445, 17, 58);
  addText(slide, "STOP decisions before that", { left: 680, top: 246, width: 360, height: 34 }, { fontSize: 27, bold: true });
  addBullets(slide, [
    { text: "Decide whether continuation remains a named factor in the next screen." },
    { text: "Decide whether to test a trend-participation variant inside existing families before adding any new strategy family." },
    { text: "Do not promote a live behavior until it improves basket-relative alpha without merely adding exposure everywhere." },
  ], 680, 306, 445, 17, 58);
  addFooter(slide, 9);
}

await fs.mkdir(path.dirname(outputPptx), { recursive: true });
await fs.mkdir(previewDir, { recursive: true });

for (const [index, slide] of deck.slides.items.entries()) {
  const png = await deck.export({ slide, format: "png", scale: 1 });
  await writeBlob(path.join(previewDir, `slide-${String(index + 1).padStart(2, "0")}.png`), png);
  const layout = await slide.export({ format: "layout" });
  await fs.writeFile(path.join(previewDir, `slide-${String(index + 1).padStart(2, "0")}.layout.json`), await layout.text(), "utf8");
}

const inspect = await deck.inspect({
  kind: "slide,textbox,shape,image,chart,table,layout",
  maxChars: 20000,
});
await fs.writeFile(`${outputPptx}.inspect.ndjson`, inspect.ndjson, "utf8");

const pptx = await PresentationFile.exportPptx(deck);
await pptx.save(outputPptx);

console.log(`Wrote ${outputPptx}`);
console.log(`Preview ${previewDir}`);
