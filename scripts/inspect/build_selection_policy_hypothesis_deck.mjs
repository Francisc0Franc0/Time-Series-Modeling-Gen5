import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const artifactToolPath = process.env.ARTIFACT_TOOL_ENTRYPOINT ?? "C:/Users/Franc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactToolPath).href);

const repoRoot = path.resolve(process.env.GEN5_REPO_ROOT ?? process.cwd());
const outPath = path.join(repoRoot, "presentations", "gen5_selection_policy_hypothesis.pptx");
const previewDir = path.join(repoRoot, "runs", "presentation_build_tmp", "selection_policy_hypothesis_preview");
const montagePath = path.join(repoRoot, "presentations", "gen5_selection_policy_hypothesis_montage.webp");
const aLiveVisualDir = path.join(repoRoot, "runs", "research_workbench", "selection_policy_screens", "selpol_robust_20260702", "A_live", "visual_summary");
const aLiveHeatmapPath = path.join(aLiveVisualDir, "selection_policy_symbol_return_delta_heatmap.png");
const aLiveMetricPath = path.join(aLiveVisualDir, "selection_policy_metric_delta_dashboard.png");

const W = 1280;
const H = 720;
const C = {
  ink: "#000000",
  muted: "#555555",
  rule: "#B8BCC4",
  panel: "#EDEDED",
  canvas: "#FFFFFF",
  accent: "#FF6B35",
  softAccent: "#FFE1D6",
  green: "#1B7F5A",
  blue: "#1D4ED8",
};

async function writeBlob(filePath, blob) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, new Uint8Array(await blob.arrayBuffer()));
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
    fontSize: 22,
    color: C.ink,
    fontFace: "Helvetica Neue",
    ...style,
  };
  return shape;
}

function addLabel(slide, text, left, top, width = 260) {
  return addText(slide, text, { left, top, width, height: 28 }, {
    fontSize: 16,
    bold: true,
    color: C.muted,
  });
}

function addRule(slide, left, top, width) {
  slide.shapes.add({
    geometry: "rect",
    position: { left, top, width, height: 1.4 },
    fill: C.rule,
    line: { style: "solid", fill: C.rule, width: 0 },
  });
}

function addPanel(slide, left, top, width, height, fill = C.panel) {
  return slide.shapes.add({
    geometry: "rect",
    position: { left, top, width, height },
    fill,
    line: { style: "solid", fill: "none", width: 0 },
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

function addFooter(slide, n) {
  addRule(slide, 42, 666, 1196);
  addText(slide, "Gen5.1 selection-policy hypothesis", { left: 42, top: 680, width: 460, height: 24 }, {
    fontSize: 14,
    color: C.muted,
  });
  addText(slide, String(n).padStart(2, "0"), { left: 1184, top: 678, width: 54, height: 28 }, {
    fontSize: 16,
    bold: true,
    color: C.muted,
    alignment: "right",
  });
}

function bulletText(items) {
  return items.map((x) => `• ${x}`).join("\n");
}

function addPolicyBox(slide, left, title, label, bullets, color) {
  addPanel(slide, left, 182, 548, 360, "#F6F6F6");
  addText(slide, title, { left: left + 28, top: 210, width: 480, height: 46 }, {
    fontSize: 31,
    bold: true,
  });
  addText(slide, label, { left: left + 28, top: 262, width: 470, height: 36 }, {
    fontSize: 17,
    bold: true,
    color,
  });
  addRule(slide, left + 28, 314, 492);
  addText(slide, bulletText(bullets), { left: left + 28, top: 338, width: 490, height: 168 }, {
    fontSize: 20,
    color: "#222222",
  });
}

async function createDeck() {
  const p = Presentation.create({ slideSize: { width: W, height: H } });

  let slide = p.slides.add();
  slide.background.fill = C.canvas;
  addLabel(slide, "METHODOLOGY FORK", 42, 42);
  addText(slide, "Selection policy may be the hidden difference between Gen4 and Gen5.1", { left: 42, top: 162, width: 980, height: 210 }, {
    fontSize: 56,
    bold: true,
  });
  addText(slide, "The next screen should isolate how state-level winners are chosen before we change the live bridge or rerun broader research.", { left: 42, top: 430, width: 740, height: 82 }, {
    fontSize: 25,
    color: "#222222",
  });
  addPanel(slide, 910, 112, 286, 420, "#F4F4F4");
  addText(slide, "Same data.\nSame PCA.\nSame grid.\nDifferent winner selection.", { left: 944, top: 158, width: 220, height: 260 }, {
    fontSize: 35,
    bold: true,
  });
  addText(slide, "July 2026", { left: 944, top: 464, width: 220, height: 30 }, {
    fontSize: 18,
    color: C.muted,
  });
  addFooter(slide, 1);

  slide = p.slides.add();
  slide.background.fill = C.canvas;
  addLabel(slide, "THE DISCOVERY", 42, 42);
  addText(slide, "Matching the visible settings did not recreate Gen4 authority", { left: 42, top: 88, width: 980, height: 64 }, {
    fontSize: 40,
    bold: true,
  });
  addText(slide, "The temporary bridge matched the Gen4-like basket, context universe, PCA mode, 5x5 state grid, and daily_default strategy grid. The selected state maps still diverged sharply.", { left: 42, top: 164, width: 1020, height: 70 }, {
    fontSize: 22,
    color: "#222222",
  });
  addPanel(slide, 72, 282, 320, 170, "#F4F4F4");
  addText(slide, "3", { left: 96, top: 302, width: 110, height: 68 }, { fontSize: 62, bold: true, color: C.accent });
  addText(slide, "exact model matches across five symbols and 25 states each", { left: 96, top: 382, width: 250, height: 52 }, { fontSize: 20 });
  addPanel(slide, 480, 282, 320, 170, "#F4F4F4");
  addText(slide, "3", { left: 504, top: 302, width: 110, height: 68 }, { fontSize: 62, bold: true, color: C.accent });
  addText(slide, "family matches where parameters still differed", { left: 504, top: 382, width: 250, height: 52 }, { fontSize: 20 });
  addPanel(slide, 888, 282, 320, 170, "#F4F4F4");
  addText(slide, "1", { left: 912, top: 302, width: 110, height: 68 }, { fontSize: 62, bold: true, color: C.accent });
  addText(slide, "field that explained it: Gen4 selection_mode", { left: 912, top: 382, width: 250, height: 52 }, { fontSize: 20 });
  addText(slide, "The difference is not just live replay. It is a winner-selection policy embedded in the research architecture.", { left: 156, top: 526, width: 900, height: 58 }, {
    fontSize: 27,
    bold: true,
  });
  addFooter(slide, 2);

  slide = p.slides.add();
  slide.background.fill = C.canvas;
  addLabel(slide, "TWO POLICIES", 42, 42);
  addText(slide, "The fork is family-first versus full-spec-first", { left: 42, top: 88, width: 1000, height: 64 }, {
    fontSize: 40,
    bold: true,
  });
  addPolicyBox(slide, 72, "Gen4 style", "pooled_family_asset_variant", [
    "Choose the state’s best family from pooled evidence.",
    "Then choose asset-specific parameters inside that family.",
    "Lower variance, clearer state meaning, possible asset-level constraint.",
  ], C.green);
  addPolicyBox(slide, 660, "Gen5.1 style", "asset_state_direct_spec", [
    "Choose the full asset/state spec directly.",
    "Family and parameters are selected together.",
    "More asset-specific flexibility, possible sparse-state overfit.",
  ], C.blue);
  addFooter(slide, 3);

  slide = p.slides.add();
  slide.background.fill = C.canvas;
  addLabel(slide, "WHY IT MATTERS", 42, 42);
  addText(slide, "A live-signal mismatch can be a methodology mismatch", { left: 42, top: 88, width: 1020, height: 64 }, {
    fontSize: 40,
    bold: true,
  });
  addText(slide, "If Gen4’s family-first policy is more robust, the bridge and some research screens may need to support it. If Gen5.1’s direct policy is stronger, signal differences may be acceptable rather than bugs.", { left: 42, top: 164, width: 1060, height: 82 }, {
    fontSize: 23,
    color: "#222222",
  });
  const y = 302;
  addPanel(slide, 82, y, 316, 184, C.softAccent);
  addText(slide, "Do not convert the bridge just for fidelity.", { left: 110, top: y + 30, width: 260, height: 88 }, {
    fontSize: 26,
    bold: true,
  });
  addText(slide, "First determine whether fidelity improves robustness.", { left: 110, top: y + 126, width: 250, height: 40 }, {
    fontSize: 18,
    color: "#333333",
  });
  addPanel(slide, 482, y, 316, 184, "#F4F4F4");
  addText(slide, "Do not keep Gen5.1 direct selection by assumption.", { left: 510, top: y + 30, width: 260, height: 88 }, {
    fontSize: 26,
    bold: true,
  });
  addText(slide, "Its flexibility may help or overfit depending on state depth.", { left: 510, top: y + 126, width: 250, height: 40 }, {
    fontSize: 18,
    color: "#333333",
  });
  addPanel(slide, 882, y, 316, 184, "#F4F4F4");
  addText(slide, "Make selection policy a declared factor.", { left: 910, top: y + 30, width: 260, height: 88 }, {
    fontSize: 26,
    bold: true,
  });
  addText(slide, "Then live and research outputs can be compared honestly.", { left: 910, top: y + 126, width: 250, height: 40 }, {
    fontSize: 18,
    color: "#333333",
  });
  addFooter(slide, 4);

  slide = p.slides.add();
  slide.background.fill = C.canvas;
  addLabel(slide, "PAIRED SCREEN", 42, 42);
  addText(slide, "The first test should vary only the selection policy", { left: 42, top: 88, width: 1030, height: 64 }, {
    fontSize: 40,
    bold: true,
  });
  addText(slide, "Hold the rest of the Gen4-like bridge surface constant so the comparison answers one question.", { left: 42, top: 164, width: 980, height: 48 }, {
    fontSize: 23,
    color: "#222222",
  });
  addText(slide, "Hold constant", { left: 80, top: 262, width: 260, height: 34 }, { fontSize: 24, bold: true });
  addText(slide, bulletText([
    "AMD,NVDA,PLTR,TSLA,SOFI",
    "Gen4 RESEARCH_ASSETS context",
    "pooled asset-day PCA",
    "5x5 quantile states",
    "Gen4 daily_default implemented grid",
    "entry-state owns trade until exit",
  ]), { left: 80, top: 310, width: 480, height: 210 }, { fontSize: 20, color: "#222222" });
  addText(slide, "Vary only", { left: 700, top: 262, width: 260, height: 34 }, { fontSize: 24, bold: true });
  addPanel(slide, 700, 316, 396, 72, "#F4F4F4");
  addText(slide, "asset_state_direct_spec", { left: 724, top: 338, width: 348, height: 30 }, { fontSize: 24, bold: true, color: C.blue });
  addPanel(slide, 700, 416, 396, 72, "#F4F4F4");
  addText(slide, "pooled_family_asset_variant", { left: 724, top: 438, width: 348, height: 30 }, { fontSize: 24, bold: true, color: C.green });
  addText(slide, "Start with Q2 and Q3 2026, then add adjacent quarters only if the first readout shows a meaningful difference.", { left: 700, top: 528, width: 424, height: 64 }, { fontSize: 20 });
  addFooter(slide, 5);

  slide = p.slides.add();
  slide.background.fill = C.canvas;
  addLabel(slide, "DECISION GATE", 42, 42);
  addText(slide, "The output should support a policy decision, not a leaderboard", { left: 42, top: 88, width: 1060, height: 64 }, {
    fontSize: 40,
    bold: true,
  });
  addText(slide, "Evidence to inspect", { left: 70, top: 202, width: 300, height: 34 }, { fontSize: 25, bold: true });
  addText(slide, bulletText([
    "Selected-state agreement and disagreement",
    "State coverage and sparse-state forcing",
    "Family stability across quarters",
    "Trade behavior and drawdown",
    "Portfolio accounting as inspection only",
  ]), { left: 70, top: 258, width: 500, height: 210 }, { fontSize: 22 });
  addText(slide, "Stop before changing", { left: 700, top: 202, width: 330, height: 34 }, { fontSize: 25, bold: true });
  addText(slide, bulletText([
    "the live bridge selection policy",
    "accepted default research settings",
    "prior context-universe conclusions",
    "daily automation confidence",
  ]), { left: 700, top: 258, width: 430, height: 184 }, { fontSize: 22 });
  addPanel(slide, 70, 526, 1070, 72, C.softAccent);
  addText(slide, "Next step: implement the paired selection-policy wrapper, then decide whether Gen5.1 should preserve direct spec selection or add Gen4-style pooled family selection as a first-class policy.", { left: 96, top: 548, width: 1010, height: 34 }, {
    fontSize: 20,
    bold: true,
  });
  addFooter(slide, 6);

  slide = p.slides.add();
  slide.background.fill = C.canvas;
  addLabel(slide, "FIRST READOUT", 42, 42);
  addText(slide, "The policies were closer than the Gen4 file comparison implied", { left: 42, top: 88, width: 1060, height: 92 }, {
    fontSize: 37,
    bold: true,
  });
  addText(slide, "Inside the Gen5.1 bridge surface, direct and pooled-family authority maps matched on 321 of 375 asset-state rows across Q1-Q3 2026. Replay still diverged because a few state/spec changes can alter entries, exits, and quarter handoff.", { left: 42, top: 194, width: 1060, height: 92 }, {
    fontSize: 23,
    color: "#222222",
  });
  addPanel(slide, 88, 330, 306, 150, "#F4F4F4");
  addText(slide, "85.6%", { left: 114, top: 348, width: 220, height: 64 }, { fontSize: 54, bold: true, color: C.accent });
  addText(slide, "selected map agreement", { left: 114, top: 424, width: 230, height: 34 }, { fontSize: 21 });
  addPanel(slide, 486, 330, 306, 150, "#F4F4F4");
  addText(slide, "AMD", { left: 512, top: 348, width: 220, height: 64 }, { fontSize: 54, bold: true, color: C.green });
  addText(slide, "drove much of the Q3 pooled advantage", { left: 512, top: 424, width: 230, height: 48 }, { fontSize: 20 });
  addPanel(slide, 884, 330, 306, 150, "#F4F4F4");
  addText(slide, "NVDA + TSLA", { left: 910, top: 360, width: 250, height: 46 }, { fontSize: 35, bold: true, color: C.blue });
  addText(slide, "favored direct in both tested windows", { left: 910, top: 424, width: 230, height: 48 }, { fontSize: 20 });
  addText(slide, "Meaning: do not convert the bridge just for fidelity, but do not dismiss the pooled-family hypothesis either.", { left: 108, top: 552, width: 990, height: 44 }, {
    fontSize: 24,
    bold: true,
  });
  addFooter(slide, 7);

  slide = p.slides.add();
  slide.background.fill = C.canvas;
  addLabel(slide, "BROADER TEST", 42, 42);
  addText(slide, "The next comparison needs two clearly labeled evidence lanes", { left: 42, top: 88, width: 1060, height: 64 }, {
    fontSize: 40,
    bold: true,
  });
  addPanel(slide, 72, 190, 520, 320, "#F4F4F4");
  addText(slide, "Screen A", { left: 104, top: 216, width: 200, height: 42 }, { fontSize: 30, bold: true, color: C.blue });
  addText(slide, "Current live basket", { left: 104, top: 268, width: 420, height: 36 }, { fontSize: 24, bold: true });
  addText(slide, bulletText([
    "AMD,NVDA,PLTR,TSLA,SOFI",
    "Gen4 RESEARCH_ASSETS context",
    "Best evidence for live bridge policy",
    "History limited by newer symbols",
  ]), { left: 104, top: 326, width: 430, height: 142 }, { fontSize: 20, color: "#222222" });
  addPanel(slide, 688, 190, 520, 320, "#F4F4F4");
  addText(slide, "Screen B", { left: 720, top: 216, width: 200, height: 42 }, { fontSize: 30, bold: true, color: C.green });
  addText(slide, "Historical substitute basket", { left: 720, top: 268, width: 420, height: 36 }, { fontSize: 24, bold: true });
  addText(slide, bulletText([
    "AMD,NVDA,TSLA,AAPL,MSTR",
    "Long-history active-plus-risk context",
    "Older-regime robustness evidence",
    "Not a literal live-basket replication",
  ]), { left: 720, top: 326, width: 430, height: 142 }, { fontSize: 20, color: "#222222" });
  addText(slide, "The results should be read side by side, not collapsed into one leaderboard.", { left: 132, top: 558, width: 1010, height: 40 }, {
    fontSize: 24,
    bold: true,
  });
  addFooter(slide, 8);

  slide = p.slides.add();
  slide.background.fill = C.canvas;
  addLabel(slide, "A-LIVE RESULT", 42, 42);
  addText(slide, "The live-basket lane favors direct selection, with one AMD-heavy exception", { left: 42, top: 88, width: 1060, height: 96 }, {
    fontSize: 36,
    bold: true,
  });
  addText(slide, "The completed A-live packet spans 2025Q4 through 2026Q3 on AMD,NVDA,PLTR,TSLA,SOFI with the Gen4 RESEARCH_ASSETS context. It is still inspection evidence, not allocation acceptance.", { left: 42, top: 204, width: 1060, height: 82 }, {
    fontSize: 23,
    color: "#222222",
  });
  addPanel(slide, 82, 322, 250, 140, "#F4F4F4");
  addText(slide, "85.92%", { left: 110, top: 342, width: 190, height: 56 }, { fontSize: 43, bold: true, color: C.accent });
  addText(slide, "asset-state map agreement", { left: 110, top: 410, width: 190, height: 34 }, { fontSize: 19 });
  addPanel(slide, 390, 322, 250, 140, "#F4F4F4");
  addText(slide, "3 of 4", { left: 418, top: 342, width: 190, height: 56 }, { fontSize: 43, bold: true, color: C.blue });
  addText(slide, "windows favored direct on mean trace return", { left: 418, top: 410, width: 190, height: 46 }, { fontSize: 18 });
  addPanel(slide, 698, 322, 250, 140, "#F4F4F4");
  addText(slide, "4 of 4", { left: 726, top: 342, width: 190, height: 56 }, { fontSize: 43, bold: true, color: C.blue });
  addText(slide, "windows favored direct on win rate and Sharpe proxy", { left: 726, top: 410, width: 190, height: 46 }, { fontSize: 18 });
  addPanel(slide, 1006, 322, 170, 140, "#F4F4F4");
  addText(slide, "AMD", { left: 1032, top: 350, width: 120, height: 48 }, { fontSize: 36, bold: true, color: C.green });
  addText(slide, "drove pooled Q3", { left: 1032, top: 410, width: 116, height: 34 }, { fontSize: 18 });
  addText(slide, "Meaning", { left: 96, top: 512, width: 240, height: 34 }, { fontSize: 25, bold: true });
  addText(slide, "The live-basket screen does not justify switching the bridge default to pooled-family. It does justify keeping pooled-family as a research contender because the AMD/Q3 behavior is too interesting to discard.", { left: 96, top: 554, width: 980, height: 56 }, { fontSize: 21 });
  addFooter(slide, 9);

  slide = p.slides.add();
  slide.background.fill = C.canvas;
  addLabel(slide, "NEXT GATE", 42, 42);
  addText(slide, "The next decision is whether more history is worth changing the basket", { left: 42, top: 88, width: 1060, height: 96 }, {
    fontSize: 36,
    bold: true,
  });
  addText(slide, "B_hist would swap SOFI and PLTR for AAPL and MSTR to reach older regimes. That is useful robustness evidence, but it is no longer a literal live-basket test.", { left: 42, top: 204, width: 1060, height: 72 }, {
    fontSize: 23,
    color: "#222222",
  });
  addText(slide, "Reason to run B_hist", { left: 96, top: 318, width: 330, height: 34 }, { fontSize: 25, bold: true });
  addText(slide, bulletText([
    "Test whether pooled-family behaves better in older market regimes.",
    "Decide whether selection policy belongs in future factorial screens.",
    "Build collaborator-facing evidence beyond the recent live basket.",
  ]), { left: 96, top: 370, width: 500, height: 132 }, { fontSize: 21 });
  addText(slide, "Reason to pause", { left: 700, top: 318, width: 330, height: 34 }, { fontSize: 25, bold: true });
  addText(slide, bulletText([
    "A_live already favors keeping direct as the bridge default.",
    "B_hist is compute-heavy and changes the traded basket.",
    "It should not be merged into one winner table with A_live.",
  ]), { left: 700, top: 370, width: 500, height: 132 }, { fontSize: 21 });
  addPanel(slide, 92, 552, 1096, 54, C.softAccent);
  addText(slide, "Recommended posture: keep direct as default, preserve pooled-family as an optional research factor, and run B_hist only if older-regime robustness is the next decision.", { left: 120, top: 568, width: 1030, height: 26 }, {
    fontSize: 20,
    bold: true,
  });
  addFooter(slide, 10);

  const hasALiveVisuals = await fs.access(aLiveHeatmapPath).then(() => true).catch(() => false);
  if (hasALiveVisuals) {
    slide = p.slides.add();
    slide.background.fill = C.canvas;
    addLabel(slide, "VISUAL EVIDENCE", 42, 42);
    addText(slide, "The A-live charts show steady direct advantage plus one pooled AMD outlier", { left: 42, top: 88, width: 1060, height: 96 }, {
      fontSize: 34,
      bold: true,
    });
    addText(slide, "Green cells favor pooled-family; red cells favor direct. The metric dashboard shows direct leading win rate and Sharpe proxy across all four windows.", { left: 42, top: 204, width: 1060, height: 46 }, {
      fontSize: 21,
      color: "#222222",
    });
    await addImage(slide, aLiveHeatmapPath, 70, 270, 540, 315, "A-live pooled-minus-direct symbol return delta heatmap");
    await addImage(slide, aLiveMetricPath, 670, 270, 500, 315, "A-live selection policy metric dashboard");
    addFooter(slide, 11);
  }

  return p;
}

async function main() {
  await fs.mkdir(previewDir, { recursive: true });
  await fs.mkdir(path.dirname(outPath), { recursive: true });
  const presentation = await createDeck();

  for (const [index, slide] of presentation.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    await writeBlob(path.join(previewDir, `${stem}.png`), await presentation.export({ slide, format: "png", scale: 1 }));
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(previewDir, `${stem}.layout.json`), await layout.text());
  }

  await writeBlob(montagePath, await presentation.export({ format: "webp", montage: true, scale: 1 }));
  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(outPath);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
