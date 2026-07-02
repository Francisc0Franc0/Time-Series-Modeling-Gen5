import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const defaultArtifactModule =
  "C:/Users/Franc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";
const artifactModule = process.env.ARTIFACT_TOOL_MODULE || defaultArtifactModule;
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactModule).href);

const presentationDir = path.join(repoRoot, "presentations");
const finalPptx = path.join(presentationDir, "gen5_recent_pca_context_screening_batch.pptx");
const inspectPath = path.join(presentationDir, "gen5_recent_pca_context_screening_batch.pptx.inspect.ndjson");
const montagePath = path.join(presentationDir, "gen5_recent_pca_context_screening_batch_montage.webp");
const slidePreviewDir = path.join(presentationDir, "gen5_recent_pca_context_screening_batch_slides");

const mediumSummaryCsv = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "context_universe_factorials",
  "ctxfac_A5_5f_3u_4s_20260624_20260624173000",
  "context_universe_factorial_summary.csv"
);
const max9SummaryCsv = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "context_universe_factorials",
  "ctxfac_A5_5f_1u_3s_20260624_20260624173000",
  "context_universe_factorial_summary.csv"
);
const max15SummaryCsv = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "context_universe_factorials",
  "ctxfac_A5_5f_1u_3s_automax15_20260624_20260624173000",
  "context_universe_factorial_summary.csv"
);
const temporalSummaryDir = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "context_universe_factorial_temporal_summaries",
  "ctxfac_temporal_context_replication_20241231_20260623"
);
const temporalRankCsv = path.join(temporalSummaryDir, "temporal_context_replication_rank_summary.csv");
const temporalMetricsPng = path.join(temporalSummaryDir, "temporal_context_replication_metrics.png");
const twoWindowSummaryCsv = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "context_universe_factorial_window_comparisons",
  "ctxfac_two_window_state_map_20260331_20260624",
  "two_window_state_map_merged_summary.csv"
);
const twoWindowMetricsPng = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "context_universe_factorial_window_comparisons",
  "ctxfac_two_window_state_map_20260331_20260624",
  "two_window_state_map_metrics.png"
);
const coverageCsv = path.join(repoRoot, "runs", "data_refresh", "alpaca_daily_symbol_coverage_20260623.csv");
const completedOlderWindows = [
  {
    label: "2021-03-31",
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

function num(value, digits = 2) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "";
  return n.toFixed(digits);
}

function surfaceLabel(surfaceId) {
  if (surfaceId.includes("auto_max15")) return "auto k 2..15";
  if (surfaceId.includes("auto_max9")) return "auto k 2..9";
  if (surfaceId.includes("quantile_grid_3x3") || surfaceId.includes("quantile_grid")) return "3x3 quantile";
  if (surfaceId.includes("kmeans_k9") || surfaceId.includes("contextual_snapshot_kmeans") || surfaceId.includes("behavioral_pool_kmeans")) return "fixed k9";
  return surfaceId.replace("behavioral_pool_", "").replace("contextual_snapshot_", "").replaceAll("_", " ");
}

function universeLabel(universeId) {
  return universeId
    .replace("_context", "")
    .replace("active_plus_risk", "active + risk")
    .replace("active_self", "active self")
    .replace("ex_active_market_risk", "ex-active risk");
}

function panelLabel(panelMode) {
  if (panelMode === "pooled_asset_day") return "behavioral pool";
  if (panelMode === "date_aligned_context") return "contextual snapshot";
  return panelMode;
}

function conditionLabel(row) {
  return `${universeLabel(row.universe_id)} / ${panelLabel(row.pca_panel_mode)} / ${surfaceLabel(row.surface_id)}`;
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
  addText(slide, kicker.toUpperCase(), 72, 44, 800, 28, {
    fontSize: 14,
    color: "slate-500",
    bold: true,
  });
  addText(slide, title, 72, 80, 1090, 92, {
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
  addText(slide, text, left + 28, top, width - 28, 50, {
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
    addText(slide, item, left + 4, top + 54 + idx * 66, width - 8, 58, {
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
    fontSize: 27,
    color: "slate-950",
    bold: true,
  });
  addText(slide, note, left + 20, top + 80, width - 40, height - 84, {
    fontSize: 14,
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
      addText(slide, String(cell), x + 8, y + 9, widths[cidx] - 16, 22, {
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

async function loadOlderWindowSummary(windowDef) {
  const csv = path.join(windowDef.dir, "context_universe_factorial_summary.csv");
  const rows = await readCsv(csv);
  return rows
    .map((row) => ({ ...row, window_label: windowDef.label }))
    .sort((a, b) => Number(b.total_return) - Number(a.total_return));
}

function summaryRow(row) {
  return [
    conditionLabel(row),
    pct(row.total_return),
    num(row.sharpe),
    pct(row.max_drawdown),
    row.total_entry_fills,
  ];
}

const mediumRows = await readCsv(mediumSummaryCsv);
const max9Rows = await readCsv(max9SummaryCsv);
const max15Rows = await readCsv(max15SummaryCsv);
const temporalRanks = await readCsv(temporalRankCsv);
const twoWindowRows = await readCsv(twoWindowSummaryCsv);
const coverage = await readCsv(coverageCsv);
const olderRows = await Promise.all(completedOlderWindows.map(loadOlderWindowSummary));
const activeCoverage = coverage.filter((r) => ["AMD", "NVDA", "TSLA", "AAPL", "MSTR"].includes(r.symbol));
const topMedium = [...mediumRows].sort((a, b) => Number(b.total_return) - Number(a.total_return)).slice(0, 6);
const activePlusMedium = mediumRows.filter((r) => r.universe_id === "active_plus_risk_context");
const max9Auto = max9Rows.find((r) => r.surface_id === "behavioral_pool_kmeans_auto_max9");
const max9Fixed = max9Rows.find((r) => r.surface_id === "behavioral_pool_kmeans_k9");
const max9Quantile = max9Rows.find((r) => r.surface_id === "behavioral_pool_quantile_grid_3x3");
const max15Auto = max15Rows.find((r) => r.surface_id === "behavioral_pool_kmeans_auto_max15");
const recentQuantile = temporalRanks.find(
  (r) => r.universe_id === "active_plus_risk_context" && r.surface_id === "behavioral_pool_quantile_grid_3x3"
);
const recentK9 = temporalRanks.find(
  (r) => r.universe_id === "active_plus_risk_context" && r.surface_id === "behavioral_pool_kmeans_k9"
);

await fs.mkdir(presentationDir, { recursive: true });
await fs.mkdir(slidePreviewDir, { recursive: true });
const presentation = Presentation.create({ slideSize: { width: 1280, height: 720 } });

{
  const slide = presentation.slides.add();
  slide.background.fill = "slate-50";
  addText(slide, "Gen5.1 Recent PCA / Context Screening Batch", 72, 82, 1080, 64, {
    fontSize: 43,
    color: "slate-950",
    bold: true,
  });
  addText(slide, "Context universes, PCA panel modes, state-map choices, time windows, and the SIP data repair", 72, 156, 1050, 48, {
    fontSize: 25,
    color: "slate-700",
  });
  addText(
    slide,
    "Purpose: preserve the reasoning trail for the recent screen sequence, including why each test was run, what it answered, and what still belongs to operator judgment.",
    72,
    236,
    980,
    80,
    { fontSize: 23, color: "slate-700" }
  );
  addMetricCard(slide, "Screen family", "PCA context", "Universe composition and panel/state map choices", 72, 394, 320);
  addMetricCard(slide, "Time coverage", "2021-2026", "Recent packet plus older-window stress checks", 426, 394, 320);
  addMetricCard(slide, "Boundary", "Inspection only", "No allocation evidence accepted here", 780, 394, 340);
  addText(slide, "Active sets used: AMD,NVDA,TSLA,COIN/META/AAPL,MSTR depending on history requirements.", 72, 582, 980, 30, {
    fontSize: 18,
    color: "slate-500",
  });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Why this batch existed");
  addRule(slide);
  addNarrativeColumn(slide, "What we knew", [
    "PCA-routed WFA could assign TRAIN-fit states and route OOS decisions without leakage.",
    "Portfolio accounting could replay child packet trades as a downstream inspection layer.",
  ], 78, 226, 350, "teal-700");
  addNarrativeColumn(slide, "What we did not know", [
    "Which context universe should define regime state for a volatile active basket.",
    "Whether 3x3 quantiles, fixed k-means, or auto-k created the cleaner state map.",
  ], 466, 226, 350, "amber-700");
  addNarrativeColumn(slide, "Why these screens", [
    "Each slice changed one research axis while keeping the downstream accounting surface familiar.",
    "The goal was to find robust contenders, not crown a performance winner.",
  ], 854, 226, 350, "indigo-700");
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "The recent screen map");
  addRule(slide);
  addSimpleTable(
    slide,
    ["Slice", "Question", "Scope", "Immediate readout"],
    [
      ["Context factorial", "Which context universe?", "3 contexts x panel/state surfaces", "Active + risk became the lead hypothesis."],
      ["Panel mode", "Wide vs long PCA?", "contextual snapshot vs behavioral pool", "Behavioral pool emerged as the main lane."],
      ["State map triage", "How many states?", "3x3, fixed k9, auto max9, auto max15", "More flexible k helped in one window but was unstable."],
      ["Window comparison", "Does this survive time shifts?", "March vs June 2026", "Window sensitivity was large and informative."],
      ["Temporal replication", "Is the context story recent-only?", "late 2024-mid 2026 plus 2021 retry", "3x3 looked cleaner; context winner not final."],
    ],
    64,
    220,
    [170, 270, 290, 360],
    54,
    13
  );
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Context universe: the first useful simplification");
  addRule(slide);
  addSimpleTable(
    slide,
    ["Top medium-grid condition", "Return", "Sharpe", "Max DD", "Entries"],
    topMedium.map(summaryRow),
    58,
    214,
    [560, 100, 90, 100, 80],
    42,
    13
  );
  addText(slide, "Why this mattered: the system should not only look at the traded assets, and it should not only look away from them. Active-plus-risk became the intuitive lead because it mixes the active basket with broad market/risk context.", 78, 540, 1060, 62, {
    fontSize: 19,
    color: "slate-700",
    bold: true,
  });
  addText(slide, "Caution: ex-active and active-self variants still produced credible pockets, so the context universe remains a research choice, not an accepted allocation rule.", 78, 622, 1060, 34, {
    fontSize: 16,
    color: "slate-500",
  });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "PCA panel mode: behavioral pool became the main lane");
  addRule(slide);
  addSimpleTable(
    slide,
    ["Active-plus-risk surface", "Panel", "State map", "Return", "Sharpe", "Max DD"],
    activePlusMedium.map((r) => [
      surfaceLabel(r.surface_id),
      panelLabel(r.pca_panel_mode),
      r.state_count,
      pct(r.total_return),
      num(r.sharpe),
      pct(r.max_drawdown),
    ]),
    78,
    218,
    [250, 185, 120, 100, 90, 100],
    44,
    13
  );
  addBulletList(
    slide,
    [
      "Behavioral pool lets each asset-day contribute to the PCA state surface, which matched the multi-asset active basket use case.",
      "Contextual snapshot is not discarded; it remains a diagnostic because some ex-active/contextual combinations performed well.",
      "The default next lane is behavioral-pool PCA unless a future slice gives contextual snapshots a specific job.",
    ],
    88,
    440,
    1020,
    19,
    58
  );
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "State-map triage: flexibility helped, then warned us");
  addRule(slide);
  addSimpleTable(
    slide,
    ["June 2026 active-plus-risk state map", "Return", "Sharpe", "Max DD", "Entries"],
    [
      [surfaceLabel(max9Quantile.surface_id), pct(max9Quantile.total_return), num(max9Quantile.sharpe), pct(max9Quantile.max_drawdown), max9Quantile.total_entry_fills],
      [surfaceLabel(max9Fixed.surface_id), pct(max9Fixed.total_return), num(max9Fixed.sharpe), pct(max9Fixed.max_drawdown), max9Fixed.total_entry_fills],
      [surfaceLabel(max9Auto.surface_id), pct(max9Auto.total_return), num(max9Auto.sharpe), pct(max9Auto.max_drawdown), max9Auto.total_entry_fills],
      [surfaceLabel(max15Auto.surface_id), pct(max15Auto.total_return), num(max15Auto.sharpe), pct(max15Auto.max_drawdown), max15Auto.total_entry_fills],
    ],
    84,
    220,
    [390, 110, 100, 110, 90],
    44,
    14
  );
  addMetricCard(slide, "Auto max9 selected", "5,4,5,8,4", "TRAIN-only Calinski-Harabasz fold sequence", 84, 478, 330);
  addMetricCard(slide, "Auto max15 selected", "5,4,13,14,14", "The max9 cap was binding in later folds", 474, 478, 330);
  addText(slide, "Interpretation: auto-k was statistically meaningful, but higher k did not automatically improve the downstream inspection result.", 852, 496, 310, 70, {
    fontSize: 17,
    color: "slate-700",
    bold: true,
  });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Two adjacent 2026 windows told different stories");
  addRule(slide);
  await addImage(slide, twoWindowMetricsPng, 48, 190, 1184, 348, "Two-window state-map comparison metrics", "cover");
  addSimpleTable(
    slide,
    ["Window", "Best return", "Best surface", "Worst return", "Readout"],
    [
      ["2026-06-24", "57.9%", "auto k 2..9", "37.4%", "Many hypotheses worked."],
      ["2026-03-31", "2.8%", "fixed k9", "-9.5%", "Same design, very different tape."],
    ],
    84,
    558,
    [140, 130, 180, 130, 360],
    40,
    13
  );
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Temporal replication broadened the time question");
  addRule(slide);
  await addImage(slide, temporalMetricsPng, 36, 190, 1208, 404, "Temporal context replication metrics chart", "cover");
  addMetricCard(slide, "Active-plus-risk 3x3", pct(recentQuantile.mean_total_return), `Mean Sharpe ${num(recentQuantile.mean_sharpe)}; zero negative windows`, 78, 600, 350, 92);
  addMetricCard(slide, "Active-plus-risk k9", pct(recentK9.mean_total_return), `Mean Sharpe ${num(recentK9.mean_sharpe)}; two negative windows`, 466, 600, 350, 92);
  addText(slide, "The late-2024 to mid-2026 packet kept active-plus-risk alive, but also made 3x3 look cleaner than fixed k9.", 854, 612, 330, 56, {
    fontSize: 17,
    color: "slate-700",
    bold: true,
  });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "The data note: SIP fixed the older-history blocker");
  addRule(slide);
  addBulletList(
    slide,
    [
      "The earlier apparent history limit came from Gen5 using IEX by default, while Gen4 had auto-selected SIP when entitled.",
      "Gen5 now defaults daily research pulls to SIP while preserving explicit ALPACA_DATA_FEED overrides.",
      "AAPL replaced COIN for older-history tests; COIN cannot support 2016-era training windows.",
      "VXX starts on 2018-01-18, so pre-2018 context tests still require a policy decision.",
    ],
    84,
    222,
    1040,
    20,
    62
  );
  addSimpleTable(
    slide,
    ["Symbol", "Rows", "First session", "Latest session"],
    activeCoverage.map((r) => [r.symbol, r.row_count, r.observed_first_session, r.observed_latest_session]),
    84,
    508,
    [120, 120, 190, 190],
    30,
    12
  );
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "The first older-window retry complicated the context story");
  addRule(slide);
  const marchRows = olderRows[0];
  const juneRows = olderRows[1];
  addSimpleTable(
    slide,
    ["2021-03-31 top rows", "Return", "Sharpe", "Max DD"],
    marchRows.slice(0, 3).map((r) => [conditionLabel(r), pct(r.total_return), num(r.sharpe), pct(r.max_drawdown)]),
    54,
    218,
    [460, 90, 80, 90],
    42,
    12
  );
  addSimpleTable(
    slide,
    ["2021-06-30 top rows", "Return", "Sharpe", "Max DD"],
    juneRows.slice(0, 3).map((r) => [conditionLabel(r), pct(r.total_return), num(r.sharpe), pct(r.max_drawdown)]),
    54,
    398,
    [460, 90, 80, 90],
    42,
    12
  );
  addText(slide, "Readout: March 2021 supported active-plus-risk 3x3; June 2021 put ex-active 3x3 first and all 3x3 variants above k9. That is exactly why the context decision stays open.", 790, 250, 350, 130, {
    fontSize: 18,
    color: "slate-700",
    bold: true,
  });
  addText(slide, `VXX warnings: ${completedOlderWindows[0].label} had ${completedOlderWindows[0].vxxRows} rows; ${completedOlderWindows[1].label} had ${completedOlderWindows[1].vxxRows} rows.`, 790, 428, 350, 60, {
    fontSize: 15,
    color: "slate-500",
  });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "What the batch changed in our beliefs");
  addRule(slide);
  addNarrativeColumn(slide, "More confident", [
    "Behavioral-pool PCA is the main lane for the next context/state-map screens.",
    "Active-plus-risk is still the lead context hypothesis, not because it always wins, but because it keeps surviving retests.",
  ], 78, 226, 350, "teal-700");
  addNarrativeColumn(slide, "Less confident", [
    "No single context universe can be accepted from one market regime.",
    "More k-means clusters are not inherently better, even when auto-k wants to use them.",
  ], 466, 226, 350, "amber-700");
  addNarrativeColumn(slide, "Kept open", [
    "3x3 versus fixed k9 as the operational default for the next replication batch.",
    "Whether VXX should be replaced, omitted, or allowed to constrain older context windows.",
  ], 854, 226, 350, "indigo-700");
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Guardrails that kept the screen useful");
  addRule(slide);
  addBulletList(
    slide,
    [
      "Every PCA/state assignment remains TRAIN-fit and OOS-applied; no OOS bars select states, clusters, parameters, or context rules.",
      "Portfolio accounting is the common downstream inspection surface, not allocation approval.",
      "WARNs are evidence: VXX partial history and k-means convergence messages must stay attached to interpretations.",
      "Multiple-comparison discipline matters: treat promising conditions as hypotheses for the next slice, not final winners.",
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
  addMetricCard(slide, "Default next lane", "behavioral pool", "Keep contextual snapshots as diagnostic", 72, 230, 330);
  addMetricCard(slide, "Lead context", "active + risk", "Retest, do not accept yet", 466, 230, 330);
  addMetricCard(slide, "State baseline", "3x3", "Cleaner comparison anchor; k9/auto remain diagnostics", 860, 230, 330);
  addBulletList(
    slide,
    [
      "Resolve VXX policy for older context universes.",
      "Then run the planned 2022 adjacent-window batch, and optionally rerun 2021 with the chosen VXX policy.",
      "Update this deck and the POC log as the durable research memory after each completed screen.",
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
const inspect = await presentation.inspect({ kind: "slide,textbox,shape,image,chart,table,layout", maxChars: 42000 });
await fs.writeFile(inspectPath, inspect.ndjson);
const pptx = await PresentationFile.exportPptx(presentation);
await pptx.save(finalPptx);

console.log(`Wrote ${finalPptx}`);
console.log(`Wrote ${inspectPath}`);
console.log(`Wrote ${montagePath}`);
console.log(`Wrote slide previews to ${slidePreviewDir}`);
