import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const artifactModule =
  process.env.ARTIFACT_TOOL_MODULE ||
  "C:/Users/Franc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactModule).href);

const runRoot = path.join(repoRoot, "runs", "research_workbench", "selpol_context", "selpol_context_20260703");
const presentationDir = path.join(repoRoot, "presentations");
const finalPptx = path.join(presentationDir, "gen5_selection_policy_context_philosophy_screen.pptx");
const inspectPath = path.join(presentationDir, "gen5_selection_policy_context_philosophy_screen.pptx.inspect.ndjson");
const montagePath = path.join(presentationDir, "gen5_selection_policy_context_philosophy_screen_montage.webp");
const slidePreviewDir = path.join(presentationDir, "gen5_selection_policy_context_philosophy_screen_slides");

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

function pct(value, digits = 1) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "";
  return `${(n * 100).toFixed(digits)}%`;
}

function pp(value, digits = 1) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "";
  return `${(n * 100).toFixed(digits)} pp`;
}

function screenLabel(id) {
  return {
    HB_broad_risk_no_vxx: "HB / broad risk",
    HB_archetype_matched_no_vxx: "HB / matched",
    HB_diverse_behavior_no_vxx: "HB / large diverse",
    HB_size_matched_diverse_no_vxx: "HB / size-matched",
    ETF_broad_risk_no_vxx: "ETF / broad risk",
    ETF_archetype_matched_no_vxx: "ETF / matched",
    ETF_diverse_behavior_no_vxx: "ETF / large diverse",
    ETF_size_matched_diverse_no_vxx: "ETF / size-matched",
  }[id] || id;
}

function basketLabel(id) {
  return {
    long_history_high_beta_growth: "High-beta long-history",
    etf_sector_tradeable_proxy: "ETF/sector proxy",
  }[id] || id;
}

function contextLabel(id) {
  return {
    broad_risk_no_vxx: "Broad risk",
    archetype_matched_no_vxx: "Archetype matched",
    diverse_behavior_no_vxx: "Large diverse",
    size_matched_diverse_no_vxx: "Size-matched diverse",
  }[id] || id;
}

function policyLabel(id) {
  return {
    asset_state_direct_spec: "Direct",
    pooled_family_asset_variant: "Pooled",
  }[id] || id;
}

function addOnSymbols(row) {
  const symbols = row.symbols.split(",");
  return row.context_symbols.split(",").filter((s) => !symbols.includes(s)).join(",");
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
  addText(slide, text, left + 28, top, width - 28, 56, { fontSize, color: "slate-800" });
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

function addSimpleTable(slide, columns, rows, left, top, widths, rowHeight = 38, fontSize = 12) {
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
      addText(slide, String(cell), x + 7, y + 8, widths[cidx] - 14, rowHeight - 14, { fontSize, color: "slate-800" });
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

function summarizeScreen(rows, screenId) {
  const screenRows = rows.filter((r) => r.screen_id === screenId);
  const windows = [...new Set(screenRows.map((r) => r.window_id))];
  let directWins = 0;
  let pooledWins = 0;
  for (const window of windows) {
    const pair = screenRows.filter((r) => r.window_id === window);
    const direct = pair.find((r) => r.selection_policy === "asset_state_direct_spec");
    const pooled = pair.find((r) => r.selection_policy === "pooled_family_asset_variant");
    if (!direct || !pooled) continue;
    const delta =
      Number(pooled.equal_symbol_mean_compound_trace_return) -
      Number(direct.equal_symbol_mean_compound_trace_return);
    if (delta > 0) pooledWins += 1;
    else directWins += 1;
  }
  const means = {};
  for (const policy of ["asset_state_direct_spec", "pooled_family_asset_variant"]) {
    const vals = screenRows
      .filter((r) => r.selection_policy === policy)
      .map((r) => Number(r.equal_symbol_mean_compound_trace_return))
      .filter(Number.isFinite);
    means[policy] = vals.reduce((a, b) => a + b, 0) / vals.length;
  }
  return {
    windows: windows.length,
    directWins,
    pooledWins,
    directMean: means.asset_state_direct_spec,
    pooledMean: means.pooled_family_asset_variant,
  };
}

const runSpec = await readCsv(path.join(runRoot, "selection_policy_context_philosophy_run_spec.csv"));
const portfolio = await readCsv(path.join(runRoot, "selection_policy_context_philosophy_portfolio_proxy_summary.csv"));
const agreement = await readCsv(path.join(runRoot, "selection_policy_context_philosophy_agreement_summary.csv"));
const benchmarkScorecard = await readCsv(path.join(runRoot, "benchmark_visuals", "selection_policy_context_benchmark_scorecard.csv"));
const benchmarkPaths = {
  highBetaHeatmap: path.join(runRoot, "benchmark_visuals", "selection_policy_context_alpha_heatmap_high_beta.png"),
  etfHeatmap: path.join(runRoot, "benchmark_visuals", "selection_policy_context_alpha_heatmap_etf.png"),
  scorecard: path.join(runRoot, "benchmark_visuals", "selection_policy_context_alpha_scorecard.png"),
};
const auditDir = path.join(runRoot, "performance_audit", "HB_broad_risk_no_vxx");
const auditPaths = {
  directTape: path.join(auditDir, "performance_audit_tape_2020Q3_direct.png"),
  pooledTape: path.join(auditDir, "performance_audit_tape_2020Q3_pooled.png"),
  missedFlatHeatmap: path.join(auditDir, "performance_audit_missed_flat_heatmap.png"),
  tradeDurationScatter: path.join(auditDir, "performance_audit_trade_duration_scatter.png"),
  stateAccountability: path.join(auditDir, "performance_audit_state_accountability.png"),
};
const auditExposure = await readCsv(path.join(auditDir, "performance_audit_exposure_participation.csv"));
const auditTradeShape = await readCsv(path.join(auditDir, "performance_audit_trade_shape.csv"));
const screenIds = [
  "HB_broad_risk_no_vxx",
  "HB_archetype_matched_no_vxx",
  "HB_diverse_behavior_no_vxx",
  "HB_size_matched_diverse_no_vxx",
  "ETF_broad_risk_no_vxx",
  "ETF_archetype_matched_no_vxx",
  "ETF_diverse_behavior_no_vxx",
  "ETF_size_matched_diverse_no_vxx",
];
const screenSummaries = Object.fromEntries(screenIds.map((id) => [id, summarizeScreen(portfolio, id)]));
function meanNumber(rows, field) {
  const vals = rows.map((r) => Number(r[field])).filter(Number.isFinite);
  if (!vals.length) return NaN;
  return vals.reduce((a, b) => a + b, 0) / vals.length;
}
const benchmarkBestRows = ["long_history_high_beta_growth", "etf_sector_tradeable_proxy"].map((basketId) => {
  const rows = benchmarkScorecard
    .filter((r) => r.basket_archetype === basketId)
    .sort((a, b) => Number(b.mean_excess_return) - Number(a.mean_excess_return));
  const best = rows[0] || {};
  return [
    basketId === "long_history_high_beta_growth" ? "High-beta" : "ETF/sector",
    screenLabel(best.screen_id),
    policyLabel(best.selection_policy),
    pp(best.mean_excess_return),
    `${best.beat_windows || ""}/${best.windows || ""}`,
  ];
});
const audit2020Direct = auditExposure.filter((r) => r.window_id === "2020Q3_asof_20200930" && r.selection_policy === "asset_state_direct_spec");
const audit2020Pooled = auditExposure.filter((r) => r.window_id === "2020Q3_asof_20200930" && r.selection_policy === "pooled_family_asset_variant");
const audit2020TradeRows = auditTradeShape.filter((r) => r.window_id === "2020Q3_asof_20200930");

await fs.mkdir(presentationDir, { recursive: true });
await fs.mkdir(slidePreviewDir, { recursive: true });

const presentation = Presentation.create({ slideSize: { width: 1280, height: 720 } });

{
  const slide = presentation.slides.add();
  slide.background.fill = "slate-50";
  addText(slide, "Gen5.1 Context Philosophy Screen", 72, 84, 1060, 58, { fontSize: 40, color: "slate-950", bold: true });
  addText(slide, "Selection policy, basket archetype, and regime-context construction in one deliberate research packet", 72, 154, 1040, 60, { fontSize: 24, color: "slate-700" });
  addText(slide, "Why: earlier screens made active-plus-risk / behavioral-pool / 3x3 look promising, but they did not fully separate whether success came from the traded basket, the extra context assets, the selection policy, or one favorable market window.", 72, 250, 1040, 118, { fontSize: 22, color: "slate-700" });
  addMetricCard(slide, "PCA surface", "behavioral pool", "3x3 quantile states", 72, 424, 330);
  addMetricCard(slide, "Policy factor", "2 lanes", "Direct-spec vs pooled-family selection", 452, 424, 330);
  addMetricCard(slide, "Context factor", "4 recipes", "Broad risk, matched, large diverse, size-matched diverse", 832, 424, 330);
  addText(slide, "Inspection only: portfolio/replay summaries are not accepted allocation evidence.", 72, 618, 1040, 30, { fontSize: 17, color: "slate-500", bold: true });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "How We Got Here");
  addBullet(slide, "We first found that active-plus-risk context and 3x3 quantile states were a focused near-term lane after wider context-universe and binning screens.", 84, 220, 1040);
  addBullet(slide, "The Gen4 bridge then exposed a fine architectural fork: direct full-spec authority versus pooled-family authority with asset-level parameters.", 84, 300, 1040);
  addBullet(slide, "A basket-archetype pilot was useful, but it included a SOFI/PLTR recent-history lane and VXX in behavioral-pool context, which made it less clean for long-history generalization.", 84, 380, 1040);
  addBullet(slide, "This screen keeps the good question, removes those confounds, and asks whether context philosophy itself changes the answer.", 84, 482, 1040);
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Question And Design");
  addBullet(slide, "What we know: long behavioral-pool PCA uses the context symbols as behavioral peers, not just external sensors.", 84, 220, 1040);
  addBullet(slide, "What we do not know: whether generic market/risk context, style-matched peers, or mixed diverse behavior produces better frozen authority.", 84, 300, 1040);
  addBullet(slide, "Design choice: use two long-history baskets, four no-VXX context recipes, two selection policies, and the same replay windows.", 84, 380, 1040);
  addText(slide, "Each lane uses 6 replay windows and 12 frozen authority quarters.", 84, 446, 1040, 26, { fontSize: 15, color: "slate-500", bold: true });
  addSimpleTable(
    slide,
    ["Screen", "Basket", "Context recipe", "Size"],
    runSpec.map((r) => [screenLabel(r.screen_id), basketLabel(r.basket_archetype), contextLabel(r.context_philosophy), r.context_size]),
    70,
    482,
    [220, 300, 300, 80],
    26,
    10
  );
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Why The Assets Were Shuffled");
  addSimpleTable(
    slide,
    ["Basket", "Research / tradeable symbols", "Reason"],
    [
      ["High-beta", "AMD,NVDA,TSLA,AAPL,MSTR", "Aggressive single-name behavior with enough history for the selected windows."],
      ["ETF/sector", "QQQ,SMH,XLK,XLE,XLF", "Tests whether the machinery works on liquid sector/proxy instruments."],
      ["Removed lane", "SOFI/PLTR live-like", "Useful live context, but recent history and redundancy would spend compute without clarifying this question."],
    ],
    70,
    228,
    [160, 340, 590],
    64,
    13
  );
  addBullet(slide, "VXX is excluded because this long PCA surface treats context assets as behavioral examples; VXX is more defensible as a wide-PCA risk sensor than as a normal behavioral peer.", 92, 492, 1040, 18);
  addBullet(slide, "The old pilot remains as a superseded reference packet. It is not deleted, but this screen is the cleaner evidence surface.", 92, 586, 1040, 18);
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Context Recipes");
  addSimpleTable(
    slide,
    ["Recipe", "Idea", "What It Tests"],
    [
      ["Broad risk", "Basket plus market, rate, gold, and sector anchors", "Does generic risk context remain enough once VXX is removed?"],
      ["Archetype matched", "Basket plus assets that behave like that basket", "Does like-for-like behavioral pooling sharpen states?"],
      ["Large diverse", "Basket plus many high-beta, ETF, market, rate, and gold behaviors", "Does a large mixed library generalize across basket types?"],
      ["Size-matched diverse", "A smaller representative slice of the diverse library", "Does diversity help after reducing the size confound?"],
    ],
    68,
    218,
    [190, 430, 470],
    70,
    13
  );
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Exact Screen Matrix");
  addSimpleTable(
    slide,
    ["Screen", "Symbols", "Added context"],
    runSpec.map((r) => [screenLabel(r.screen_id), r.symbols, addOnSymbols(r)]),
    82,
    222,
    [210, 300, 600],
    38,
    10
  );
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Top-Level Readout");
  const rows = screenIds.map((id) => {
    const s = screenSummaries[id];
    return [screenLabel(id), `${s.pooledWins}-${s.directWins}`, pct(s.directMean), pct(s.pooledMean), pct(s.pooledMean - s.directMean)];
  });
  addSimpleTable(slide, ["Lane", "Pooled-Direct windows", "Direct mean", "Pooled mean", "Pooled minus direct"], rows, 76, 224, [260, 190, 145, 145, 180], 42, 12);
  addBullet(slide, "Read this as an inspection map, not a final allocation ranking. The goal is to see which hypotheses survive enough windows to deserve deeper testing.", 92, 606, 1040, 18);
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Selection Maps Did Not Match Perfectly");
  const allRows = agreement.filter((r) => r.quarter_id === "ALL");
  addSimpleTable(
    slide,
    ["Lane", "Rows", "Family match", "Spec match"],
    allRows.map((r) => [screenLabel(r.screen_id), r.state_asset_rows, pct(r.family_match_rate), pct(r.spec_match_rate)]),
    110,
    218,
    [330, 120, 170, 170],
    42,
    13
  );
  addBullet(slide, "Direct and pooled-family maps overlap enough to be related, but not enough to be interchangeable.", 110, 594, 940, 18);
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
  await addImage(slide, path.join(runRoot, "HB_archetype_matched_no_vxx", "visual_summary", "selection_policy_symbol_return_delta_heatmap.png"), 48, 200, 570, 360, "High-beta matched heatmap", "contain");
  await addImage(slide, path.join(runRoot, "ETF_archetype_matched_no_vxx", "visual_summary", "selection_policy_symbol_return_delta_heatmap.png"), 660, 200, 570, 360, "ETF matched heatmap", "contain");
  addText(slide, "Heatmaps show pooled minus direct by symbol/window. The matched-context lanes are a useful first visual check for whether like-for-like context helps both basket types or only one.", 78, 594, 1080, 52, { fontSize: 18, color: "slate-700", bold: true });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Benchmark Reframes This As Alpha");
  addBullet(slide, "The raw replay proxy asks whether a policy made money. The benchmark lens asks the harder question: did it beat simply holding the same live basket?", 84, 218, 1040);
  addBullet(slide, "Benchmark definition: equal capital into the same basket symbols, buy-and-hold from the first replay date to the last replay date in each policy packet.", 84, 300, 1040);
  addBullet(slide, "This uses existing bridge replay artifacts only. No new data pull, no authority rerun, and no OOS information is fed back into TRAIN selection.", 84, 382, 1040);
  addBullet(slide, "Readout: positive strategy returns are not automatically alpha. Strong upside windows can make the basket hold benchmark difficult to beat.", 84, 464, 1040);
  addSimpleTable(
    slide,
    ["Basket", "Best lane by mean excess", "Policy", "Mean excess", "Beat windows"],
    benchmarkBestRows,
    92,
    560,
    [140, 330, 120, 150, 150],
    38,
    12
  );
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "High-Beta Alpha Was Mostly Negative");
  await addImage(slide, benchmarkPaths.highBetaHeatmap, 60, 196, 1160, 410, "High-beta benchmark excess heatmap", "contain");
  addText(slide, "Each cell is strategy replay proxy minus equal-weight buy-and-hold of AMD,NVDA,TSLA,AAPL,MSTR over the same replay interval. Green beat the basket hold; red lagged it.", 86, 632, 1080, 38, { fontSize: 17, color: "slate-700", bold: true });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "ETF Alpha Was Cleaner But Still Uneven");
  await addImage(slide, benchmarkPaths.etfHeatmap, 60, 196, 1160, 410, "ETF benchmark excess heatmap", "contain");
  addText(slide, "The ETF/sector basket had smaller benchmark gaps than high beta, but the alpha evidence is still inconsistent. Several lanes made money while still failing to beat equal-weight hold.", 86, 632, 1080, 38, { fontSize: 17, color: "slate-700", bold: true });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Scorecard: Participation Is The Problem");
  await addImage(slide, benchmarkPaths.scorecard, 36, 196, 1210, 414, "Benchmark alpha scorecard", "contain");
  addText(slide, "Across this screen, every lane had negative mean excess return versus equal-weight basket hold. The next narrow slice should diagnose whether the strategy is too often flat during bull regimes, selecting weak specs, or avoiding enough downside to justify the cash drag.", 76, 628, 1120, 48, { fontSize: 17, color: "slate-700", bold: true });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Performance Audit Looks Inside One Lane");
  addBullet(slide, "The benchmark view says the strategy lagged the local hold benchmark. The audit asks what the model was actually doing while that happened.", 84, 212, 1040);
  addBullet(slide, "Focus lane: high-beta basket with broad risk context, because it is closest in spirit to the temporary live bridge's high-beta plus market-risk setup.", 84, 292, 1040);
  addBullet(slide, "Scope: both direct-spec and pooled-family policies, all six windows, with the 2020Q3 tape highlighted because the basket itself rallied hard.", 84, 372, 1040);
  addBullet(slide, "This is artifact-only inspection. It reads existing replay, trade, execution, and state files; it does not rerun PCA, authority selection, or WFA replay.", 84, 452, 1040);
  addMetricCard(slide, "Direct exposure in 2020Q3", pct(meanNumber(audit2020Direct, "exposure_ratio")), `Missed-flat mean ${pp(meanNumber(audit2020Direct, "missed_flat_return"))}`, 116, 548, 300, 112);
  addMetricCard(slide, "Pooled exposure in 2020Q3", pct(meanNumber(audit2020Pooled, "exposure_ratio")), `Missed-flat mean ${pp(meanNumber(audit2020Pooled, "missed_flat_return"))}`, 490, 548, 300, 112);
  addMetricCard(slide, "Tape window", "2020Q3", "High-upside stress case", 864, 548, 300, 112);
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Direct Caught Pieces But Missed The Full Surge");
  await addImage(slide, auditPaths.directTape, 270, 194, 740, 430, "Direct policy 2020Q3 trade tape", "contain");
  const directTrade = audit2020TradeRows.find((r) => r.selection_policy === "asset_state_direct_spec") || {};
  addText(slide, `Direct had ${directTrade.win_count || ""} wins and ${directTrade.loss_count || ""} losses in 2020Q3, so the problem was not a total trade failure. The tape shows partial participation: AMD and NVDA caught useful stretches, but AAPL was almost entirely flat and TSLA captured only part of a much larger basket move.`, 76, 632, 1120, 44, { fontSize: 16, color: "slate-700", bold: true });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Pooled Found A Bigger TSLA Hold But Still Lagged");
  await addImage(slide, auditPaths.pooledTape, 270, 194, 740, 430, "Pooled policy 2020Q3 trade tape", "contain");
  const pooledTrade = audit2020TradeRows.find((r) => r.selection_policy === "pooled_family_asset_variant") || {};
  addText(slide, `Pooled had ${pooledTrade.win_count || ""} wins and ${pooledTrade.loss_count || ""} losses in 2020Q3 and caught a long TSLA run. But it still lagged the basket hold because AMD/NVDA/AAPL participation was incomplete and MSTR added noisy, small-ticket behavior.`, 76, 632, 1120, 44, { fontSize: 16, color: "slate-700", bold: true });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Flat Time Explains Much Of The Gap");
  await addImage(slide, auditPaths.missedFlatHeatmap, 42, 196, 1196, 410, "Missed flat return heatmap", "contain");
  addText(slide, "Cells show return that happened while the model was flat, plus the long-day exposure. Red is missed upside. The biggest red cells cluster in high-upside windows, especially 2020Q3, which means benchmark underperformance was often an exposure problem before it was a trade-quality problem.", 76, 626, 1120, 54, { fontSize: 17, color: "slate-700", bold: true });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Trade Shape Was Mixed, Not Catastrophic");
  await addImage(slide, auditPaths.tradeDurationScatter, 64, 198, 1150, 400, "Trade duration and return scatter", "contain");
  addText(slide, "Most trades were short and clustered near zero, with a few long-duration outliers driving much of the story. That suggests the next alpha slice should measure whether the system needs a participation floor or trend-carry behavior, not merely a smaller loss filter.", 76, 624, 1120, 54, { fontSize: 17, color: "slate-700", bold: true });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Only A Few States Added Value");
  await addImage(slide, auditPaths.stateAccountability, 100, 198, 1080, 400, "State accountability heatmap", "contain");
  addText(slide, "The state accountability view is narrow but useful: most states show negative mean daily excess versus holding, while S2_1 is positive in both policies. This points the next investigation toward state-level participation and family selection, rather than treating all states as equally useful.", 76, 624, 1120, 54, { fontSize: 17, color: "slate-700", bold: true });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Guardrails And Next Decision");
  addBullet(slide, "All authority selection remains TRAIN-only; OOS replay consumes frozen maps.", 90, 226, 1040);
  addBullet(slide, "All context recipes omit VXX because this is long behavioral-pool PCA, not wide sensor PCA.", 90, 296, 1040);
  addBullet(slide, "This deck compares inspection proxies, not accepted allocation evidence or live trading authority.", 90, 366, 1040);
  addBullet(slide, "Benchmark lens: equal-weight basket hold is a local alpha benchmark, not an allocation approval threshold or final objective function.", 90, 436, 1040);
  addBullet(slide, "Next decision: run a narrow alpha-diagnostic slice before adding more factorial breadth. Separate exposure, upside participation, downside avoidance, state accountability, and selection-policy effects.", 90, 526, 1040);
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
