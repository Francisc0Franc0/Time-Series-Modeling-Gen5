import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const artifactModule =
  process.env.ARTIFACT_TOOL_MODULE ||
  "C:/Users/Franc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactModule).href);

const runRoot =
  process.env.GEN5_GEN54_ML_P0_RUN_ROOT ||
  path.join(repoRoot, "runs", "research_workbench", "gen54_ml_decision_engine", "g54_ml_p0_20260713p0");
const visualRoot = path.join(runRoot, "visuals");
const p1RunRoot =
  process.env.GEN5_GEN54_ML_P1_RUN_ROOT ||
  path.join(repoRoot, "runs", "research_workbench", "gen54_ml_decision_engine", "g54_ml_p1_20260713p1");
const p1VisualRoot = path.join(p1RunRoot, "visuals");
const presentationDir = path.join(repoRoot, "presentations");
const finalPptx =
  process.env.GEN5_GEN54_ML_PPTX_OUT ||
  path.join(presentationDir, "gen5_4_ml_decision_engine_incremental_build.pptx");
const montagePath = path.join(presentationDir, "gen5_4_ml_decision_engine_incremental_build_montage.webp");
const slidePreviewDir = path.join(presentationDir, "gen5_4_ml_decision_engine_incremental_build_slides");
const inspectPath = path.join(presentationDir, "gen5_4_ml_decision_engine_incremental_build.inspect.ndjson");

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
    color: style.color || "#222222",
    bold: Boolean(style.bold),
    italic: Boolean(style.italic),
    alignment: style.alignment || "left",
  };
  return shape;
}

function addRule(slide, left, top, width) {
  slide.shapes.add({
    geometry: "rect",
    position: { left, top, width, height: 2 },
    fill: "#B8BCC4",
    line: { style: "solid", fill: "none", width: 0 },
  });
}

function addTitle(slide, title, kicker = "Gen5.4 ML decision engine") {
  addText(slide, kicker.toUpperCase(), 72, 42, 900, 26, { fontSize: 13, color: "#555555", bold: true });
  addText(slide, title, 72, 76, 1080, 92, { fontSize: 38, color: "#000000", bold: true });
  addRule(slide, 72, 174, 1136);
}

function addBullet(slide, text, left, top, width, fontSize = 21) {
  addText(slide, "-", left, top + 1, 20, 26, { fontSize, color: "#FF6B35", bold: true });
  addText(slide, text, left + 28, top, width - 28, 54, { fontSize, color: "#222222" });
}

function addMetric(slide, label, value, note, left, top, width, height = 126) {
  slide.shapes.add({
    geometry: "rect",
    position: { left, top, width, height },
    fill: "#EDEDED",
    line: { style: "solid", fill: "#B8BCC4", width: 1 },
  });
  addText(slide, label.toUpperCase(), left + 18, top + 16, width - 36, 18, { fontSize: 12, color: "#555555", bold: true });
  addText(slide, value, left + 18, top + 42, width - 36, 38, { fontSize: 30, color: "#000000", bold: true });
  addText(slide, note, left + 18, top + 86, width - 36, height - 92, { fontSize: 15, color: "#555555" });
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

function pct(x, digits = 1) {
  const n = Number(x);
  if (!Number.isFinite(n)) return "NA";
  return `${(100 * n).toFixed(digits)}%`;
}

function mean(values) {
  const nums = values.map(Number).filter(Number.isFinite);
  if (!nums.length) return NaN;
  return nums.reduce((a, b) => a + b, 0) / nums.length;
}

async function main() {
  await fs.mkdir(presentationDir, { recursive: true });
  await fs.mkdir(slidePreviewDir, { recursive: true });

  const runSpec = (await readCsv(path.join(runRoot, "ml_p0_run_spec.csv")))[0];
  const labels = await readCsv(path.join(runRoot, "ml_p0_label_summary.csv"));
  const audit = await readCsv(path.join(runRoot, "ml_p0_leakage_audit.csv"));
  let p1Available = false;
  let p1Summary = [];
  let p1ActionAudit = [];
  let p1Leakage = [];
  try {
    await fs.access(path.join(p1RunRoot, "ml_p1_summary.csv"));
    p1Summary = await readCsv(path.join(p1RunRoot, "ml_p1_summary.csv"));
    p1ActionAudit = await readCsv(path.join(p1RunRoot, "ml_p1_action_audit.csv"));
    p1Leakage = await readCsv(path.join(p1RunRoot, "ml_p1_leakage_audit.csv"));
    p1Available = true;
  } catch {
    p1Available = false;
  }

  const oos = labels.filter((r) => r.split === "OOS");
  const oos2020 = oos.filter((r) => r.window_id === "2020Y");
  const oos2022 = oos.filter((r) => r.window_id === "2022Y");
  const allPass = audit.every((r) => r.status === "PASS");
  const usableRows = Number(runSpec.usable_label_rows).toLocaleString("en-US");
  const featureCount = Number(runSpec.selected_feature_count).toLocaleString("en-US");
  const oos2020Up = pct(mean(oos2020.map((r) => r.label_up_rate)));
  const oos2022Up = pct(mean(oos2022.map((r) => r.label_up_rate)));
  const oos2020Ret = pct(mean(oos2020.map((r) => r.mean_fwd_ret_h3)));
  const oos2022Ret = pct(mean(oos2022.map((r) => r.mean_fwd_ret_h3)));

  const deck = Presentation.create({ slideSize: { width: 1280, height: 720 } });

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    addText(slide, "Gen5.4", 72, 48, 300, 54, { fontSize: 30, color: "#555555", bold: true });
    addText(slide, "ML decision engine", 72, 162, 760, 86, { fontSize: 62, color: "#000000", bold: true });
    addText(slide, "Incremental build log: supervised feature and label proof before model fitting.", 76, 286, 700, 90, { fontSize: 25, color: "#222222" });
    addRule(slide, 76, 430, 520);
    addText(slide, "ML-P0 packet: adjusted daily OHLCV -> features through close t -> next-open h3 label.", 76, 462, 690, 70, { fontSize: 20, color: "#555555" });
    slide.shapes.add({
      geometry: "rect",
      position: { left: 854, top: 0, width: 426, height: 720 },
      fill: "#EDEDED",
      line: { style: "solid", fill: "none", width: 0 },
    });
    addText(slide, "Research only", 900, 248, 260, 44, { fontSize: 28, color: "#000000", bold: true });
    addText(slide, "No model fit\nNo live bridge change\nNo allocation evidence", 900, 316, 270, 150, { fontSize: 24, color: "#222222" });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    addTitle(slide, "The PCA work taught us where to aim the ML fork");
    addBullet(slide, "PCA states contained useful exposure information, especially in state-only diagnostics.", 92, 220, 470);
    addBullet(slide, "The same states still overparticipated in 2022 and missed too much early upside in rebound windows.", 92, 310, 470);
    addBullet(slide, "Gen5.4 asks the daily exposure question directly instead of routing through a technical strategy first.", 92, 400, 470);
    slide.shapes.add({ geometry: "rect", position: { left: 650, top: 220, width: 500, height: 64 }, fill: "#EDEDED", line: { style: "solid", fill: "#B8BCC4", width: 1 } });
    slide.shapes.add({ geometry: "rect", position: { left: 650, top: 332, width: 500, height: 64 }, fill: "#EDEDED", line: { style: "solid", fill: "#B8BCC4", width: 1 } });
    slide.shapes.add({ geometry: "rect", position: { left: 650, top: 444, width: 500, height: 64 }, fill: "#EDEDED", line: { style: "solid", fill: "#B8BCC4", width: 1 } });
    addText(slide, "OHLCV feature table", 686, 238, 420, 28, { fontSize: 24, bold: true });
    addText(slide, "Supervised h3 label", 686, 350, 420, 28, { fontSize: 24, bold: true });
    addText(slide, "Daily long/flat policy", 686, 462, 420, 28, { fontSize: 24, bold: true });
    addText(slide, "The first build proves the first two boxes only.", 664, 560, 455, 52, { fontSize: 20, color: "#555555" });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    addTitle(slide, "ML-P0 succeeds only if the table is boringly correct");
    addMetric(slide, "Usable labeled rows", usableRows, "Rows eligible after fold and horizon filters.", 92, 230, 300);
    addMetric(slide, "Selected features", featureCount, "PCA-inspired plus explicit OHLCV additions.", 490, 230, 300);
    addMetric(slide, "Leakage audit", allPass ? "All PASS" : "Review", "TRAIN labels stay inside TRAIN; OOS labels stay inside OOS.", 888, 230, 300);
    addBullet(slide, "Features are known after close t.", 124, 430, 470);
    addBullet(slide, "Hypothetical execution starts at next open.", 124, 490, 470);
    addBullet(slide, "The h3 label ends at close three sessions later.", 650, 430, 470);
    addBullet(slide, "Rows without a complete horizon are excluded from the proof table.", 650, 490, 470);
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    addTitle(slide, "The fold calendar makes the leakage rule visible");
    await addImage(slide, path.join(visualRoot, "ml_p0_fold_calendar_leakage_diagram.png"), 88, 214, 760, 380, "Fold calendar and leakage diagram");
    addText(slide, "Why it matters", 906, 224, 240, 32, { fontSize: 26, bold: true });
    addText(slide, "A TRAIN example is not eligible unless its future h3 label finishes before the TRAIN/OOS boundary. OOS labels are allowed for inspection, but they never feed model fitting or threshold choice.", 906, 276, 250, 210, { fontSize: 22, color: "#222222" });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    addTitle(slide, "OHLCV adds information that close-to-close would discard");
    await addImage(slide, path.join(visualRoot, "ml_p0_feature_coverage_heatmap.png"), 78, 218, 610, 390, "Feature coverage heatmap");
    addText(slide, "The first feature table is complete enough to model from.", 740, 220, 380, 68, { fontSize: 28, color: "#000000", bold: true });
    addBullet(slide, "Candle body, wick, gap, range, and volume features are populated across both windows.", 742, 324, 390, 20);
    addBullet(slide, "This does not prove alpha. It proves the supervised surface is technically usable.", 742, 426, 390, 20);
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    addTitle(slide, "The h3 target is balanced enough for a first model test");
    await addImage(slide, path.join(visualRoot, "ml_p0_label_balance_bars.png"), 76, 218, 530, 360, "Label balance bars");
    await addImage(slide, path.join(visualRoot, "ml_p0_forward_return_distribution.png"), 650, 218, 540, 360, "Forward return distributions");
    addText(slide, `Mean OOS positive-label rate: 2020 ${oos2020Up}; 2022 ${oos2022Up}. Mean OOS h3 return: 2020 ${oos2020Ret}; 2022 ${oos2022Ret}.`, 90, 608, 1050, 42, { fontSize: 18, color: "#555555" });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    addTitle(slide, "The label matches how an after-close system would trade");
    await addImage(slide, path.join(visualRoot, "ml_p0_example_alignment_chart.png"), 92, 220, 760, 380, "Example feature execution label alignment");
    addText(slide, "Read the markers left to right", 906, 224, 260, 32, { fontSize: 25, bold: true });
    addText(slide, "Blue is the feature date. Orange is the next open, where a future model would act. Green is the close three sessions later, where the label is measured.", 906, 280, 260, 210, { fontSize: 22, color: "#222222" });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    addTitle(slide, "Feature strips give us a human audit of what the model will see");
    await addImage(slide, path.join(visualRoot, "ml_p0_feature_behavior_strips.png"), 76, 214, 760, 410, "Feature behavior strips");
    addText(slide, "This is still pre-model evidence.", 900, 224, 275, 34, { fontSize: 25, bold: true });
    addText(slide, "The plot checks that trend, range location, and volume features move in recognizable ways around a hard 2022 tape. The next step is to ask whether a model can combine these signals better than hand-coded states.", 900, 286, 270, 240, { fontSize: 22, color: "#222222" });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    addTitle(slide, "A univariate audit gives early clues without pretending to be a model");
    await addImage(slide, path.join(visualRoot, "ml_p0_univariate_decile_audit.png"), 80, 214, 760, 410, "Univariate decile audit");
    addText(slide, "What to look for", 898, 224, 260, 32, { fontSize: 25, bold: true });
    addText(slide, "Smooth monotonic lines would be encouraging. Noisy or nonmonotonic lines are not fatal, because the first real ML test will learn interactions, but they tell us whether individual features carry any visible directional information.", 898, 280, 282, 250, { fontSize: 21, color: "#222222" });
  }

  {
    const slide = deck.slides.add();
    slide.background.fill = "#FFFFFF";
    addTitle(slide, "The next build tests a deliberately simple model");
    addText(slide, "ML-P0 passed the table-quality gate. ML-P1 asks whether a plain GLM can turn that table into coherent daily long/flat behavior.", 92, 226, 780, 86, { fontSize: 30, color: "#000000", bold: true });
    addBullet(slide, "Fit only on TRAIN rows using frozen transforms.", 124, 360, 520);
    addBullet(slide, "Predict OOS h3 probability after each close.", 124, 430, 520);
    addBullet(slide, "Replay long/flat decisions with fixed thresholds.", 124, 500, 520);
    addBullet(slide, "Compare probability traces, trade tapes, equity, and equal-weight basket hold.", 124, 570, 520);
    slide.shapes.add({ geometry: "rect", position: { left: 812, top: 236, width: 312, height: 312 }, fill: "#EDEDED", line: { style: "solid", fill: "#B8BCC4", width: 1 } });
    addText(slide, "Still research only", 850, 304, 238, 38, { fontSize: 27, bold: true, alignment: "center" });
    addText(slide, "GLM is the plumbing baseline before XGBoost.", 852, 374, 235, 110, { fontSize: 24, color: "#222222", alignment: "center" });
  }

  if (p1Available) {
    const s2020 = p1Summary.find((r) => r.window_id === "2020Y") || {};
    const s2022 = p1Summary.find((r) => r.window_id === "2022Y") || {};
    const flat2020 = p1ActionAudit.find((r) => r.window_id === "2020Y" && r.signal_action === "STAY_FLAT") || {};
    const exposure2020 = pct(s2020.mean_exposure);
    const exposure2022 = pct(s2022.mean_exposure);
    const p1AllPass = p1Leakage.every((r) => r.status === "PASS");

    {
      const slide = deck.slides.add();
      slide.background.fill = "#FFFFFF";
      addText(slide, "Transition", 72, 52, 500, 44, { fontSize: 32, color: "#555555", bold: true });
      addText(slide, "The deck now moves from table safety to model behavior", 72, 168, 900, 92, { fontSize: 52, color: "#000000", bold: true });
      addRule(slide, 76, 326, 600);
      addText(slide, "ML-P1 fits a GLM on TRAIN rows, freezes the model, predicts OOS h3 probability, and replays fixed-threshold long/flat decisions. This is a diagnostic model, not an allocation claim.", 76, 364, 770, 112, { fontSize: 24, color: "#222222" });
      slide.shapes.add({ geometry: "rect", position: { left: 924, top: 0, width: 356, height: 720 }, fill: "#EDEDED", line: { style: "solid", fill: "none", width: 0 } });
      addText(slide, "ML-P1", 982, 246, 230, 46, { fontSize: 42, color: "#000000", bold: true, alignment: "center" });
      addText(slide, "GLM replay", 982, 322, 230, 36, { fontSize: 26, color: "#222222", alignment: "center" });
    }

    {
      const slide = deck.slides.add();
      slide.background.fill = "#FFFFFF";
      addTitle(slide, "The GLM baseline became defensive, not participatory");
      addMetric(slide, "2020 active", pct(s2020.active_return), `Basket hold ${pct(s2020.benchmark_return)}`, 86, 226, 245);
      addMetric(slide, "2020 exposure", exposure2020, `Stayed flat ${pct(flat2020.row_rate)} of decision rows.`, 370, 226, 245);
      addMetric(slide, "2022 active", pct(s2022.active_return), `Basket hold ${pct(s2022.benchmark_return)}`, 654, 226, 245);
      addMetric(slide, "Leakage audit", p1AllPass ? "All PASS" : "Review", "TRAIN fit only; OOS prediction only.", 938, 226, 245);
      addText(slide, "The first GLM replay proves the mechanics, but not the alpha thesis. It missed most of the 2020 rally and was useful mainly as partial 2022 defense.", 112, 430, 980, 84, { fontSize: 28, color: "#000000", bold: true, alignment: "center" });
    }

    {
      const slide = deck.slides.add();
      slide.background.fill = "#FFFFFF";
      addTitle(slide, "The equity curve shows the same participation problem we have been chasing");
      await addImage(slide, path.join(p1VisualRoot, "ml_p1_equity_vs_benchmark.png"), 70, 210, 760, 414, "GLM equity versus equal-weight basket hold");
      addText(slide, "Interpretation", 890, 224, 260, 32, { fontSize: 26, bold: true });
      addText(slide, "In 2020, the model stayed too cautious while the basket compounded aggressively. In 2022, the model preserved capital relative to the falling basket, but it was still not cleanly risk-off.", 890, 282, 270, 220, { fontSize: 22, color: "#222222" });
    }

    {
      const slide = deck.slides.add();
      slide.background.fill = "#FFFFFF";
      addTitle(slide, "Probability trade tapes show what the policy actually did");
      await addImage(slide, path.join(p1VisualRoot, "ml_p1_probability_trade_tapes.png"), 70, 210, 760, 414, "Probability traces and trade markers");
      addText(slide, "What this reveals", 890, 224, 270, 32, { fontSize: 26, bold: true });
      addText(slide, "The probability trace is now an inspectable decision surface. We can see whether missed upside comes from low predicted probabilities, high thresholds, or replay mechanics.", 890, 284, 270, 220, { fontSize: 22, color: "#222222" });
    }

    {
      const slide = deck.slides.add();
      slide.background.fill = "#FFFFFF";
      addTitle(slide, "The diagnostics point to threshold and calibration questions");
      await addImage(slide, path.join(p1VisualRoot, "ml_p1_action_audit.png"), 74, 214, 500, 350, "Action audit");
      await addImage(slide, path.join(p1VisualRoot, "ml_p1_calibration_deciles.png"), 626, 214, 500, 350, "Calibration deciles");
      addText(slide, "Fixed thresholds are intentionally crude. The next improvement should be TRAIN-only threshold selection and probability calibration, not a rush to a more complex model.", 116, 604, 980, 42, { fontSize: 20, color: "#555555", alignment: "center" });
    }

    {
      const slide = deck.slides.add();
      slide.background.fill = "#FFFFFF";
      addTitle(slide, "The coefficient audit keeps the simple model explainable");
      await addImage(slide, path.join(p1VisualRoot, "ml_p1_top_coefficients.png"), 80, 214, 700, 390, "Top GLM coefficients");
      addText(slide, "Why GLM still earns its keep", 850, 224, 300, 34, { fontSize: 26, bold: true });
      addText(slide, "Even when performance is underwhelming, coefficients expose what the model is leaning on. That makes GLM a useful diagnostic bridge before XGBoost.", 850, 288, 286, 210, { fontSize: 22, color: "#222222" });
    }

    {
      const slide = deck.slides.add();
      slide.background.fill = "#FFFFFF";
      addTitle(slide, "The next slice should improve the decision policy before model complexity");
      addText(slide, "ML-P1 worked mechanically and exposed a familiar failure mode: too little upside participation in 2020, partial defense in 2022.", 92, 224, 940, 86, { fontSize: 30, color: "#000000", bold: true });
      addBullet(slide, "Add TRAIN-only threshold selection or calibration before XGBoost.", 128, 362, 720);
      addBullet(slide, "Compare fixed thresholds against a more permissive participation policy.", 128, 432, 720);
      addBullet(slide, "Keep probability trade tapes as the required visual audit for every ML replay.", 128, 502, 720);
      addBullet(slide, "Only then add XGBoost as a nonlinear challenger.", 128, 572, 720);
    }
  }

  const inspect = await deck.inspect({ kind: "slide,textbox,shape,image,chart,table,layout", maxChars: 20000 });
  await fs.writeFile(inspectPath, inspect.ndjson, "utf8");
  for (const [index, slide] of deck.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    const png = await deck.export({ slide, format: "png", scale: 1.5 });
    await fs.writeFile(path.join(slidePreviewDir, `${stem}.png`), new Uint8Array(await png.arrayBuffer()));
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(slidePreviewDir, `${stem}.layout.json`), await layout.text(), "utf8");
  }
  const montage = await deck.export({ format: "webp", montage: true, scale: 1 });
  await fs.writeFile(montagePath, new Uint8Array(await montage.arrayBuffer()));
  const pptx = await PresentationFile.exportPptx(deck);
  await pptx.save(finalPptx);
  console.log(`Wrote ${finalPptx}`);
  console.log(`Montage ${montagePath}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
