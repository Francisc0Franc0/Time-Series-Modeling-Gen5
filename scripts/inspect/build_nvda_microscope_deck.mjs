import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const moduleRoot = process.env.RUNTIME_NODE_MODULES;
if (!moduleRoot) throw new Error("RUNTIME_NODE_MODULES is required.");
const artifactEntrypoint = path.join(moduleRoot, "@oai", "artifact-tool", "dist", "artifact_tool.mjs");
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactEntrypoint).href);

const repoRoot = process.env.GEN5_REPO_ROOT || process.cwd();
const intradayRoot = path.join(repoRoot, "runs", "research_workbench", "operator_hypothesis_lab", "nvda_intraday_clock_descriptive_20260831");
const dailyRoot = path.join(repoRoot, "runs", "research_workbench", "operator_hypothesis_lab", "nvda_daily_return_microscope_20260831");
const atlasRoot = path.join(repoRoot, "runs", "research_workbench", "operator_hypothesis_lab", "own_asset_return_geometry_atlas_20260826");
const protoRoot = path.join(repoRoot, "runs", "research_workbench", "operator_hypothesis_lab", "nvda_daily_proto_rules_20260831");
const confirmationRoot = path.join(repoRoot, "runs", "research_workbench", "operator_hypothesis_lab", "nvda_daily_proto_rule_confirmation_20260831");
const openingRoot = path.join(repoRoot, "runs", "research_workbench", "operator_hypothesis_lab", "nvda_intraday_opening_response_20260831");
const openingRuleRoot = path.join(repoRoot, "runs", "research_workbench", "operator_hypothesis_lab", "nvda_intraday_opening_rule_20260831");
const openingAtlasRoot = path.join(repoRoot, "runs", "research_workbench", "operator_hypothesis_lab", "intraday_opening_atr_atlas_20260901");
const deckPath = path.join(repoRoot, "operator_hypothesis_lab", "presentations", "nvda_microscope_evidence.pptx");
const qaRoot = path.join(repoRoot, "runs", "research_workbench", "operator_hypothesis_lab", "nvda_microscope_deck_20260831");
const renderRoot = path.join(qaRoot, "rendered");

const img = {
  clock: path.join(intradayRoot, "visuals", "nvda_overnight_and_30min_return_clock.png"),
  scatter: path.join(dailyRoot, "visuals", "nvda_t_minus_1_vs_t_daily_log_return_scatter.png"),
  unfiltered: path.join(dailyRoot, "visuals", "nvda_unfiltered_pearson_heatmap.png"),
  er20: path.join(dailyRoot, "visuals", "nvda_er20_state_pearson_heatmaps.png"),
  atrp: path.join(dailyRoot, "visuals", "nvda_atrp_state_pearson_heatmaps.png"),
  signed: path.join(dailyRoot, "visuals", "nvda_signed_er20_state_pearson_heatmaps.png"),
  sign: path.join(dailyRoot, "visuals", "nvda_unfiltered_prior_sign_heatmaps.png"),
  bands: path.join(atlasRoot, "visuals", "asset_state_bands", "nvda_state_bands.png"),
  protoEntries: path.join(protoRoot, "visuals", "nvda_proto_rule_price_entries.png"),
  protoEquity: path.join(protoRoot, "visuals", "nvda_proto_rule_equity_paths.png"),
  protoDistributions: path.join(protoRoot, "visuals", "nvda_proto_rule_return_distributions.png"),
  protoAnnual: path.join(protoRoot, "visuals", "nvda_proto_rule_annual_context.png"),
  protoTapes: path.join(protoRoot, "visuals", "nvda_proto_rule_representative_tapes.png"),
  confirmationComparison: path.join(confirmationRoot, "visuals", "nvda_rebound_train_confirmation_controls.png"),
  confirmationPrice: path.join(confirmationRoot, "visuals", "nvda_rebound_confirmation_price_trades.png"),
  confirmationEquity: path.join(confirmationRoot, "visuals", "nvda_rebound_confirmation_equity.png"),
  confirmationReturns: path.join(confirmationRoot, "visuals", "nvda_rebound_confirmation_trade_returns.png"),
  confirmationTapes: path.join(confirmationRoot, "visuals", "nvda_rebound_confirmation_trade_tapes.png"),
  openingScatter: path.join(openingRoot, "visuals", "nvda_opening_bar_vs_remainder_scatter.png"),
  openingDistribution: path.join(openingRoot, "visuals", "nvda_opening_bin_remainder_distributions.png"),
  openingPaths: path.join(openingRoot, "visuals", "nvda_opening_bin_remainder_paths.png"),
  openingStates: path.join(openingRoot, "visuals", "nvda_prior_day_state_opening_response.png"),
  openingRuleThreshold: path.join(openingRuleRoot, "visuals", "nvda_opening_rule_rolling_threshold.png"),
  openingRuleControls: path.join(openingRuleRoot, "visuals", "nvda_opening_rule_control_distributions.png"),
  openingRuleAnnual: path.join(openingRuleRoot, "visuals", "nvda_opening_rule_annual_context.png"),
  openingRuleEquity: path.join(openingRuleRoot, "visuals", "nvda_opening_rule_realized_equity.png"),
  openingRuleTapes: path.join(openingRuleRoot, "visuals", "nvda_opening_rule_representative_tapes.png"),
  openingAtlasAssets: path.join(openingAtlasRoot, "visuals", "opening_atr_asset_contrasts.png"),
  openingAtlasEras: path.join(openingAtlasRoot, "visuals", "opening_atr_era_stability.png"),
  openingAtlasResponse: path.join(openingAtlasRoot, "visuals", "opening_atr_asset_response_map.png"),
  openingAtlasSectors: path.join(openingAtlasRoot, "visuals", "opening_atr_sector_context.png"),
  openingAtlasHeatmap: path.join(openingAtlasRoot, "visuals", "opening_atr_asset_era_heatmap.png"),
};

const sources = {
  intradayReport: "Local descriptive packet: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_clock_descriptive_20260831/report.md",
  intradaySpec: "Local run specification: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_clock_descriptive_20260831/run_spec.csv",
  dailyReport: "Local daily microscope packet: runs/research_workbench/operator_hypothesis_lab/nvda_daily_return_microscope_20260831/report.md",
  oneByOne: "Local 1x1 state summary: runs/research_workbench/operator_hypothesis_lab/nvda_daily_return_microscope_20260831/nvda_one_by_one_state_summary.csv",
  stateGrid: "Frozen NVDA state grid: runs/research_workbench/operator_hypothesis_lab/nvda_daily_return_microscope_20260831/nvda_state_grid_cells.csv",
  signGrid: "Frozen NVDA prior-sign grid: runs/research_workbench/operator_hypothesis_lab/nvda_daily_return_microscope_20260831/nvda_prior_sign_cells.csv",
  atlas: "Frozen own-asset atlas packet: runs/research_workbench/operator_hypothesis_lab/own_asset_return_geometry_atlas_20260826/report.md",
  protoReport: "Local executable proto-rule packet: runs/research_workbench/operator_hypothesis_lab/nvda_daily_proto_rules_20260831/report.md",
  protoSummary: "Local proto-rule summary: runs/research_workbench/operator_hypothesis_lab/nvda_daily_proto_rules_20260831/rule_summary.csv",
  protoCalendar: "Local proto-rule annual context: runs/research_workbench/operator_hypothesis_lab/nvda_daily_proto_rules_20260831/calendar_summary.csv",
  protoTrades: "Local non-overlapping trade ledger: runs/research_workbench/operator_hypothesis_lab/nvda_daily_proto_rules_20260831/trade_ledger.csv",
  confirmationReport: "Local one-shot confirmation report: runs/research_workbench/operator_hypothesis_lab/nvda_daily_proto_rule_confirmation_20260831/report.md",
  confirmationGates: "Predeclared confirmation gates: runs/research_workbench/operator_hypothesis_lab/nvda_daily_proto_rule_confirmation_20260831/confirmation_gates.csv",
  confirmationSummary: "Frozen confirmation rule summary: runs/research_workbench/operator_hypothesis_lab/nvda_daily_proto_rule_confirmation_20260831/rule_summary.csv",
  confirmationTrades: "Untouched-period trade ledger: runs/research_workbench/operator_hypothesis_lab/nvda_daily_proto_rule_confirmation_20260831/confirmation_trade_ledger.csv",
  confirmationHealth: "Explicit-as-of query health: runs/research_workbench/operator_hypothesis_lab/nvda_daily_proto_rule_confirmation_20260831/query_health.csv",
  openingReport: "Local intraday opening-response report: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_opening_response_20260831/report.md",
  openingSessionLedger: "Full-session causal ledger: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_opening_response_20260831/session_ledger.csv",
  openingBins: "Opening-bin and prior-state summaries: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_opening_response_20260831/opening_bin_summary.csv",
  openingContrasts: "Descriptive candidate contrasts: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_opening_response_20260831/descriptive_candidate_contrasts.csv",
  openingChecks: "Opening-response construction checks: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_opening_response_20260831/source_checks.csv",
  openingRuleReport: "Causal intraday opening-rule TRAIN report: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_opening_rule_20260831/report.md",
  openingRuleSpec: "Frozen causal rule specification: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_opening_rule_20260831/run_spec.csv",
  openingRuleChecks: "Causal construction checks: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_opening_rule_20260831/construction_checks.csv",
  openingRuleSummary: "Candidate and control summary: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_opening_rule_20260831/rule_summary.csv",
  openingRuleCalendar: "Candidate calendar summary: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_opening_rule_20260831/calendar_summary.csv",
  openingRuleGates: "Frozen TRAIN gates: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_opening_rule_20260831/train_gates.csv",
  openingRuleTrades: "Causal same-day trade ledger: runs/research_workbench/operator_hypothesis_lab/nvda_intraday_opening_rule_20260831/trade_ledger.csv",
  openingAtlasReport: "Cross-asset mechanism-replication report: runs/research_workbench/operator_hypothesis_lab/intraday_opening_atr_atlas_20260901/report.md",
  openingAtlasSpec: "Frozen cross-asset mechanism specification: runs/research_workbench/operator_hypothesis_lab/intraday_opening_atr_atlas_20260901/run_spec.csv",
  openingAtlasChecks: "Cross-asset construction checks: runs/research_workbench/operator_hypothesis_lab/intraday_opening_atr_atlas_20260901/construction_checks.csv",
  openingAtlasAssets: "Asset-level mechanism summary: runs/research_workbench/operator_hypothesis_lab/intraday_opening_atr_atlas_20260901/asset_summary.csv",
  openingAtlasEras: "Era-level mechanism summary: runs/research_workbench/operator_hypothesis_lab/intraday_opening_atr_atlas_20260901/era_summary.csv",
  openingAtlasSectors: "Sector context summary: runs/research_workbench/operator_hypothesis_lab/intraday_opening_atr_atlas_20260901/sector_summary.csv",
  openingAtlasGates: "Frozen mechanism-replication gates: runs/research_workbench/operator_hypothesis_lab/intraday_opening_atr_atlas_20260901/mechanism_gates.csv",
};

const C = {
  white: "#FFFFFF", ink: "#000000", navy: "#24364B", muted: "#667386",
  rule: "#B8BCC4", blue: "#3D8DFF", paleBlue: "#D0EDFA", panel: "#F3F5F7",
  red: "#B44738", paleRed: "#F6E5E1", green: "#14866D", paleGreen: "#E2F1EC",
  amber: "#A86B00", paleAmber: "#FAEBC8",
};

function addText(slide, value, position, style = {}) {
  const shape = slide.shapes.add({ geometry: "textbox", position, fill: "none", line: { style: "solid", fill: "none", width: 0 } });
  shape.text = value;
  shape.text.style = {
    fontFace: "Arial", fontSize: style.fontSize ?? 20, bold: style.bold ?? false,
    color: style.color ?? C.ink, alignment: style.alignment ?? "left",
    verticalAlignment: style.verticalAlignment ?? "top",
  };
  return shape;
}

function addRect(slide, position, fill, line = fill, width = 0) {
  return slide.shapes.add({ geometry: "rect", position, fill, line: { style: "solid", fill: line, width } });
}

function addHeader(slide, title, page, kicker = "OPERATOR HYPOTHESIS LAB · NVDA MICROSCOPE") {
  addText(slide, kicker, { left: 48, top: 25, width: 650, height: 20 }, { fontSize: 14, bold: true, color: C.muted });
  addText(slide, title, { left: 48, top: 55, width: 1160, height: 62 }, { fontSize: 39, bold: true });
  addRect(slide, { left: 48, top: 128, width: 1184, height: 2 }, C.rule);
  addText(slide, "Descriptive research · adjusted bars · frozen 2018–2023 window", { left: 48, top: 684, width: 740, height: 17 }, { fontSize: 12, color: C.muted });
  addText(slide, String(page).padStart(2, "0"), { left: 1140, top: 682, width: 92, height: 18 }, { fontSize: 12, color: C.muted, alignment: "right" });
}

function addConfirmationHeader(slide, title, page) {
  addText(slide, "OPERATOR HYPOTHESIS LAB · NVDA CONFIRMATION", { left: 48, top: 25, width: 650, height: 20 }, { fontSize: 14, bold: true, color: C.muted });
  addText(slide, title, { left: 48, top: 55, width: 1160, height: 62 }, { fontSize: 39, bold: true });
  addRect(slide, { left: 48, top: 128, width: 1184, height: 2 }, C.rule);
  addText(slide, "One-shot untouched time · adjusted daily bars · frozen 2024-01-02–2026-06-23", { left: 48, top: 684, width: 820, height: 17 }, { fontSize: 12, color: C.muted });
  addText(slide, String(page).padStart(2, "0"), { left: 1140, top: 682, width: 92, height: 18 }, { fontSize: 12, color: C.muted, alignment: "right" });
}

function addOpeningHeader(slide, title, page) {
  addText(slide, "OPERATOR HYPOTHESIS LAB · NVDA INTRADAY OPENING RESPONSE", { left: 48, top: 25, width: 760, height: 20 }, { fontSize: 14, bold: true, color: C.muted });
  addText(slide, title, { left: 48, top: 55, width: 1160, height: 62 }, { fontSize: 39, bold: true });
  addRect(slide, { left: 48, top: 128, width: 1184, height: 2 }, C.rule);
  addText(slide, "Descriptive research · 1,487 full sessions · frozen 2018-01-02–2023-12-29", { left: 48, top: 684, width: 820, height: 17 }, { fontSize: 12, color: C.muted });
  addText(slide, String(page).padStart(2, "0"), { left: 1140, top: 682, width: 92, height: 18 }, { fontSize: 12, color: C.muted, alignment: "right" });
}

function addOpeningRuleHeader(slide, title, page) {
  addText(slide, "OPERATOR HYPOTHESIS LAB · NVDA INTRADAY OPENING RULE", { left: 48, top: 25, width: 760, height: 20 }, { fontSize: 14, bold: true, color: C.muted });
  addText(slide, title, { left: 48, top: 55, width: 1160, height: 62 }, { fontSize: 39, bold: true });
  addRect(slide, { left: 48, top: 128, width: 1184, height: 2 }, C.rule);
  addText(slide, "Causal TRAIN translation · 2019-01-11–2023-12-29 after prior-252-session warm-up", { left: 48, top: 684, width: 900, height: 17 }, { fontSize: 12, color: C.muted });
  addText(slide, String(page).padStart(2, "0"), { left: 1140, top: 682, width: 92, height: 18 }, { fontSize: 12, color: C.muted, alignment: "right" });
}

function addOpeningAtlasHeader(slide, title, page) {
  addText(slide, "OPERATOR HYPOTHESIS LAB · CROSS-ASSET OPENING MECHANISM", { left: 48, top: 25, width: 840, height: 20 }, { fontSize: 14, bold: true, color: C.muted });
  addText(slide, title, { left: 48, top: 55, width: 1160, height: 62 }, { fontSize: 39, bold: true });
  addRect(slide, { left: 48, top: 128, width: 1184, height: 2 }, C.rule);
  addText(slide, "Mechanism replication · 26 non-NVDA assets · causal outcomes through 2025", { left: 48, top: 684, width: 900, height: 17 }, { fontSize: 12, color: C.muted });
  addText(slide, String(page).padStart(2, "0"), { left: 1140, top: 682, width: 92, height: 18 }, { fontSize: 12, color: C.muted, alignment: "right" });
}

function addNotes(slide, body, sourceList) {
  slide.speakerNotes.textFrame.setText([body, "", "[Sources]", ...sourceList.map((s) => `- ${s}`), "[/Sources]"].join("\n"));
  slide.speakerNotes.setVisible(true);
}

async function addImage(slide, imagePath, position, alt) {
  const bytes = await fs.readFile(imagePath);
  slide.images.add({ blob: bytes, contentType: "image/png", alt, fit: "contain", position });
}

function addBullet(slide, value, left, top, width, accent = C.blue, fontSize = 21, height = 62) {
  addRect(slide, { left, top: top + 9, width: 9, height: 9 }, accent);
  addText(slide, value, { left: left + 24, top, width: width - 24, height }, { fontSize, color: C.navy });
}

function addMetric(slide, value, label, detail, left, top, width, accent = C.blue) {
  addRect(slide, { left, top, width, height: 126 }, C.panel);
  addRect(slide, { left, top, width: 8, height: 126 }, accent);
  addText(slide, value, { left: left + 24, top: top + 14, width: width - 40, height: 42 }, { fontSize: 33, bold: true });
  addText(slide, label, { left: left + 24, top: top + 63, width: width - 40, height: 24 }, { fontSize: 16, bold: true, color: C.navy });
  addText(slide, detail, { left: left + 24, top: top + 92, width: width - 40, height: 22 }, { fontSize: 12, color: C.muted });
}

async function main() {
  await fs.mkdir(path.dirname(deckPath), { recursive: true });
  await fs.mkdir(renderRoot, { recursive: true });
  await fs.writeFile(path.join(qaRoot, "source-notes.txt"), Object.values(sources).join("\n"), "utf8");
  for (const imagePath of Object.values(img)) await fs.access(imagePath);

  const p = Presentation.create({ slideSize: { width: 1280, height: 720 } });

  // 1 — cover
  {
    const s = p.slides.add(); s.background.fill = C.white;
    addRect(s, { left: 0, top: 0, width: 24, height: 720 }, C.blue);
    addText(s, "OPERATOR HYPOTHESIS LAB · ONE-ASSET MICROSCOPE", { left: 72, top: 70, width: 760, height: 28 }, { fontSize: 16, bold: true, color: C.muted });
    addText(s, "NVDA\nmicroscope", { left: 72, top: 142, width: 690, height: 190 }, { fontSize: 78, bold: true });
    addText(s, "From the intraday return clock to causal rules and cross-asset mechanism tests.", { left: 76, top: 370, width: 790, height: 86 }, { fontSize: 28, color: C.navy });
    addRect(s, { left: 914, top: 120, width: 264, height: 264 }, C.navy);
    addText(s, "30m", { left: 934, top: 170, width: 224, height: 74 }, { fontSize: 58, bold: true, color: C.white, alignment: "center" });
    addText(s, "+", { left: 1004, top: 250, width: 84, height: 50 }, { fontSize: 30, color: C.paleBlue, alignment: "center" });
    addText(s, "1D", { left: 934, top: 302, width: 224, height: 56 }, { fontSize: 40, bold: true, color: C.white, alignment: "center" });
    addRect(s, { left: 72, top: 532, width: 1106, height: 2 }, C.rule);
    addText(s, "Research posture", { left: 72, top: 562, width: 210, height: 26 }, { fontSize: 17, bold: true, color: C.blue });
    addText(s, "Observe first. Separate descriptive clues, executable TRAIN translation, and one-shot confirmation.", { left: 300, top: 554, width: 850, height: 64 }, { fontSize: 23, color: C.navy });
    addText(s, "RESEARCH DECK · DAILY CONFIRMATION STOP · INTRADAY OPENING RULE STOP", { left: 72, top: 666, width: 760, height: 20 }, { fontSize: 13, bold: true, color: C.red });
    addNotes(s, "This deck begins the NVDA one-asset microscope and records the first two views: unconditional intraday clock behavior and the established daily return-geometry template.", [sources.intradayReport, sources.dailyReport]);
  }

  // 2 — legitimacy and burden
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "One asset is a legitimate research object", 2);
    addRect(s, { left: 58, top: 164, width: 540, height: 430 }, C.paleBlue);
    addText(s, "What specialization buys", { left: 86, top: 194, width: 470, height: 38 }, { fontSize: 28, bold: true });
    addBullet(s, "A focused view of NVDA’s own liquidity, attention, overnight, and time-of-day structure.", 88, 260, 460, C.blue, 22, 86);
    addBullet(s, "A tractable laboratory for operator-facing visual sanity checks.", 88, 374, 460, C.blue, 22, 74);
    addBullet(s, "A strategy may trade one asset if its validation remains honest and causal.", 88, 472, 460, C.blue, 22, 80);
    addRect(s, { left: 640, top: 164, width: 582, height: 430 }, C.panel);
    addText(s, "What specialization costs", { left: 672, top: 194, width: 500, height: 38 }, { fontSize: 28, bold: true });
    addBullet(s, "Greater risk that a pattern describes one historical path rather than a durable mechanism.", 674, 260, 500, C.red, 22, 86);
    addBullet(s, "No cross-asset breadth to rescue weak causal reasoning.", 674, 374, 500, C.red, 22, 74);
    addBullet(s, "Untouched time, realistic execution, and explicit baselines become even more important.", 674, 472, 500, C.red, 22, 80);
    addText(s, "The design target is not asset-agnosticism. It is falsifiable specialization.", { left: 58, top: 620, width: 1164, height: 38 }, { fontSize: 26, bold: true, color: C.navy, alignment: "center" });
    addNotes(s, "A one-asset strategy is not methodologically disqualified. It simply cannot borrow confidence from universality; the evidence must come from causal construction, stability over time, execution realism, and untouched confirmation.", [sources.intradayReport, sources.dailyReport]);
  }

  // 3 — intraday clock
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "The first microscope: NVDA’s return clock", 3);
    await addImage(s, img.clock, { left: 42, top: 146, width: 910, height: 500 }, "NVDA overnight gap and regular-session 30-minute open-to-close return distributions, 2018-2023");
    addRect(s, { left: 974, top: 158, width: 258, height: 468 }, C.panel);
    addText(s, "How to read it", { left: 998, top: 184, width: 214, height: 30 }, { fontSize: 23, bold: true });
    addBullet(s, "Each dot is one observed return.", 998, 238, 214, C.blue, 18, 56);
    addBullet(s, "The overnight gap sits left of the first bar.", 998, 312, 214, C.blue, 18, 72);
    addBullet(s, "Median ticks are tiny relative to the tails.", 998, 404, 214, C.blue, 18, 70);
    addBullet(s, "No filter, model, or trade rule is present.", 998, 496, 214, C.red, 18, 70);
    addNotes(s, "This is the unconditional distribution of NVDA returns by clock position. It is a map of where variation lives, not evidence that any position is predictable.", [sources.intradayReport, sources.intradaySpec]);
  }

  // 4 — clock readings
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "The clock is structured—even before prediction", 4);
    addMetric(s, "1,499", "sessions", "Frozen research window", 58, 166, 260, C.blue);
    addMetric(s, "19,415", "30-minute bars", "Regular-session observations", 338, 166, 260, C.green);
    addMetric(s, "1,490", "overnight gaps", "Valid close-to-open observations", 618, 166, 260, C.amber);
    addMetric(s, "2024+", "intraday unread", "Daily confirmation is documented later", 898, 166, 324, C.red);
    addRect(s, { left: 58, top: 330, width: 1164, height: 252 }, C.panel);
    addText(s, "Visible pattern", { left: 86, top: 360, width: 260, height: 32 }, { fontSize: 25, bold: true });
    addBullet(s, "The overnight gap has the broadest return distribution.", 88, 416, 500, C.amber, 22, 70);
    addBullet(s, "The first 30 minutes are the widest regular-session bar; midday compresses; the close widens again.", 88, 494, 500, C.blue, 22, 86);
    addText(s, "What remains unknown", { left: 672, top: 360, width: 300, height: 32 }, { fontSize: 25, bold: true });
    addBullet(s, "Whether prior information predicts which tail will occur.", 674, 416, 496, C.red, 22, 70);
    addBullet(s, "Whether any conditional difference survives costs and untouched time.", 674, 494, 496, C.red, 22, 86);
    addNotes(s, "The distribution changes across the clock. That justifies conditioning questions, but it does not yet justify a trading action.", [sources.intradayReport, sources.intradaySpec]);
  }

  // 5 — transition
  {
    const s = p.slides.add(); s.background.fill = C.navy;
    addText(s, "SECOND MICROSCOPE", { left: 72, top: 94, width: 420, height: 30 }, { fontSize: 17, bold: true, color: C.paleBlue });
    addText(s, "Move up one level:\ndaily return geometry", { left: 72, top: 170, width: 900, height: 170 }, { fontSize: 64, bold: true, color: C.white });
    addText(s, "The same frozen 2018–2023 NVDA history is viewed through prior-versus-forward cumulative log returns, then split by path efficiency, volatility, direction, and prior-return sign.", { left: 76, top: 408, width: 1040, height: 112 }, { fontSize: 28, color: C.paleBlue });
    addText(s, "Fixed horizons: 1, 2, 3, 4, 5, 10, 15, 20, 25 sessions", { left: 76, top: 602, width: 900, height: 32 }, { fontSize: 20, bold: true, color: C.white });
    addText(s, "05", { left: 1134, top: 672, width: 90, height: 20 }, { fontSize: 12, color: C.paleBlue, alignment: "right" });
    addNotes(s, "This section reuses the predeclared atlas vocabulary. It does not choose new horizons after seeing NVDA.", [sources.dailyReport, sources.atlas]);
  }

  // 6 — scatter
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "Adjacent daily returns mostly form a cloud", 6);
    await addImage(s, img.scatter, { left: 48, top: 146, width: 850, height: 508 }, "NVDA prior-day versus next-day adjusted log-return scatterplot, 2018-2023");
    addRect(s, { left: 922, top: 158, width: 300, height: 470 }, C.panel);
    addText(s, "First reading", { left: 948, top: 186, width: 250, height: 30 }, { fontSize: 24, bold: true });
    addText(s, "−0.075", { left: 948, top: 244, width: 250, height: 58 }, { fontSize: 44, bold: true, color: C.red });
    addText(s, "unfiltered 1×1 Pearson r", { left: 948, top: 306, width: 250, height: 34 }, { fontSize: 17, bold: true, color: C.navy });
    addBullet(s, "A slight adjacent-day reversal tilt.", 948, 374, 244, C.red, 19, 64);
    addBullet(s, "Large tails exist in every directional quadrant.", 948, 452, 244, C.blue, 19, 76);
    addBullet(s, "The cloud alone is not a rule.", 948, 544, 244, C.red, 19, 60);
    addNotes(s, "The adjacent-session view is visually noisy, with a small negative Pearson correlation. The next question is whether longer windows or causal states reveal coherent regions.", [sources.dailyReport, sources.oneByOne]);
  }

  // 7 — unfiltered grid
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "The unfiltered surface is weak and mixed", 7);
    await addImage(s, img.unfiltered, { left: 56, top: 144, width: 760, height: 510 }, "NVDA unfiltered 9 by 9 prior-versus-forward daily return correlation heatmap");
    addRect(s, { left: 846, top: 166, width: 376, height: 436 }, C.panel);
    addText(s, "Geometry, not a winner cell", { left: 874, top: 194, width: 320, height: 62 }, { fontSize: 25, bold: true });
    addBullet(s, "Short prior windows lean slightly negative into short forward windows.", 876, 282, 316, C.red, 20, 82);
    addBullet(s, "Longer prior and forward windows drift mildly positive.", 876, 382, 316, C.blue, 20, 78);
    addBullet(s, "Magnitude is small without a state split.", 876, 482, 316, C.red, 20, 70);
    addText(s, "This is a descriptive map. No multiplicity claim is made.", { left: 846, top: 622, width: 376, height: 36 }, { fontSize: 15, bold: true, color: C.muted, alignment: "center" });
    addNotes(s, "The full surface prevents us from over-reading the adjacent-day point. Without state conditioning, the grid remains close to zero and changes sign gradually across horizons.", [sources.stateGrid, sources.dailyReport]);
  }

  // 8 — state bands
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "The filters are observable states—not forecasts", 8);
    await addImage(s, img.bands, { left: 44, top: 148, width: 900, height: 492 }, "NVDA price with signed ER20, ER20, and ATR-percent state bands, 2018-2023");
    addRect(s, { left: 970, top: 160, width: 252, height: 462 }, C.panel);
    addText(s, "Vocabulary", { left: 994, top: 188, width: 208, height: 30 }, { fontSize: 23, bold: true });
    addBullet(s, "ER20: sideways vs efficient path", 994, 248, 208, C.blue, 18, 78);
    addBullet(s, "ATR%: low, medium, high volatility", 994, 344, 208, C.amber, 18, 78);
    addBullet(s, "Signed ER20: down, sideways, up", 994, 440, 208, C.green, 18, 78);
    addText(s, "Each label is assigned from information available at the anchor session.", { left: 994, top: 548, width: 208, height: 58 }, { fontSize: 16, bold: true, color: C.navy });
    addNotes(s, "The state-band plot is the sanity check: the numerical filters should correspond to recognizable price-path and volatility regimes. They remain descriptive labels, not forecasts.", [sources.atlas, sources.stateGrid]);
  }

  // 9 — ER20
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "ER20 separates two different surfaces", 9);
    await addImage(s, img.er20, { left: 42, top: 148, width: 900, height: 490 }, "NVDA daily return correlation heatmaps split by ER20 sideways and efficient states");
    addRect(s, { left: 968, top: 160, width: 254, height: 458 }, C.panel);
    addText(s, "Visual clue", { left: 992, top: 188, width: 210, height: 30 }, { fontSize: 23, bold: true });
    addBullet(s, "Sideways: correlations stay near zero with mild negative longer-forward patches.", 992, 246, 210, C.red, 18, 110);
    addBullet(s, "Efficient: a positive long-prior / long-forward region appears.", 992, 382, 210, C.blue, 18, 92);
    addText(s, "ER20 alone does not say whether the efficient path is up or down.", { left: 992, top: 520, width: 210, height: 74 }, { fontSize: 17, bold: true, color: C.navy });
    addNotes(s, "The efficient-state heatmap contains a coherent positive region at longer horizons, while the sideways state remains flatter. Direction is still aggregated here, so signed ER20 is needed next.", [sources.stateGrid, sources.dailyReport]);
  }

  // 10 — ATR
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "ATR% reveals a sharp short-horizon contrast", 10);
    await addImage(s, img.atrp, { left: 42, top: 148, width: 900, height: 490 }, "NVDA daily return correlation heatmaps split by prior-252-session ATR-percent state");
    addRect(s, { left: 968, top: 160, width: 254, height: 458 }, C.panel);
    addText(s, "1×1 Pearson r", { left: 992, top: 188, width: 210, height: 28 }, { fontSize: 22, bold: true });
    addText(s, "+0.013", { left: 992, top: 244, width: 110, height: 38 }, { fontSize: 28, bold: true, color: C.blue });
    addText(s, "low", { left: 1110, top: 250, width: 90, height: 26 }, { fontSize: 17, color: C.muted });
    addText(s, "+0.043", { left: 992, top: 300, width: 110, height: 38 }, { fontSize: 28, bold: true, color: C.blue });
    addText(s, "medium", { left: 1110, top: 306, width: 90, height: 26 }, { fontSize: 17, color: C.muted });
    addText(s, "−0.174", { left: 992, top: 356, width: 110, height: 38 }, { fontSize: 28, bold: true, color: C.red });
    addText(s, "high", { left: 1110, top: 362, width: 90, height: 26 }, { fontSize: 17, color: C.muted });
    addBullet(s, "High volatility concentrates the adjacent-day reversal clue.", 992, 436, 210, C.red, 18, 92);
    addText(s, "Longer-horizon geometry still changes sign; this is not a universal reversal label.", { left: 992, top: 548, width: 210, height: 66 }, { fontSize: 16, bold: true, color: C.navy });
    addNotes(s, "At the adjacent-day point, low and medium ATR states are near zero to slightly positive, while the high ATR state is materially more negative. Across longer windows, the surface remains mixed.", [sources.oneByOne, sources.stateGrid]);
  }

  // 11 — signed ER20
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "Direction explains part of the efficient-state mixture", 11);
    await addImage(s, img.signed, { left: 42, top: 148, width: 900, height: 490 }, "NVDA daily return correlation heatmaps split by signed ER20 down, sideways, and up states");
    addRect(s, { left: 968, top: 160, width: 254, height: 458 }, C.panel);
    addText(s, "Down state", { left: 992, top: 190, width: 210, height: 30 }, { fontSize: 23, bold: true, color: C.red });
    addBullet(s, "Strongest negative short/mid-horizon region.", 992, 242, 210, C.red, 18, 78);
    addBullet(s, "Long forward windows turn positive for some prior windows.", 992, 334, 210, C.blue, 18, 86);
    addText(s, "Up state", { left: 992, top: 448, width: 210, height: 30 }, { fontSize: 23, bold: true, color: C.green });
    addBullet(s, "Smaller short-horizon reversal and modest long-forward continuation patches.", 992, 496, 210, C.green, 18, 102);
    addNotes(s, "Signed ER20 shows that efficient up and efficient down paths should not be aggregated. The down state carries the strongest negative short-horizon dependence and a later positive region; the up state is milder.", [sources.stateGrid, sources.oneByOne]);
  }

  // 12 — sign asymmetry
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "Prior-return sign changes the long-horizon story", 12);
    await addImage(s, img.sign, { left: 42, top: 148, width: 900, height: 490 }, "NVDA unfiltered negative-prior, positive-prior, and positive-minus-negative daily return correlation heatmaps");
    addRect(s, { left: 968, top: 160, width: 254, height: 458 }, C.panel);
    addText(s, "Descriptive contrast", { left: 992, top: 188, width: 210, height: 54 }, { fontSize: 23, bold: true });
    addBullet(s, "After negative long-window returns, forward long-window correlations become positive.", 992, 266, 210, C.blue, 18, 106);
    addBullet(s, "After positive priors, the same region is mostly mild negative.", 992, 392, 210, C.red, 18, 92);
    addText(s, "The negative delta at long-long cells reads more like rebound asymmetry than classical continuation.", { left: 992, top: 514, width: 210, height: 84 }, { fontSize: 17, bold: true, color: C.navy });
    addNotes(s, "The positive-minus-negative panel asks whether the same prior magnitude has different forward dependence depending on its sign. For NVDA, the long-horizon contrast leans toward stronger rebound-like behavior after negative priors.", [sources.signGrid, sources.dailyReport]);
  }

  // 13 — intraday conditioning design
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "Daily states can cleanly condition intraday returns", 13);
    addRect(s, { left: 58, top: 164, width: 552, height: 430 }, C.paleBlue);
    addText(s, "Primary next slice", { left: 86, top: 194, width: 480, height: 34 }, { fontSize: 27, bold: true });
    addText(s, "Completed daily state at t−1", { left: 88, top: 264, width: 460, height: 38 }, { fontSize: 27, bold: true, color: C.blue });
    addText(s, "↓", { left: 280, top: 310, width: 80, height: 44 }, { fontSize: 32, bold: true, color: C.muted, alignment: "center" });
    addText(s, "Today’s overnight gap + each 30-minute bar", { left: 88, top: 368, width: 460, height: 72 }, { fontSize: 26, bold: true, color: C.navy, alignment: "center" });
    addBullet(s, "Causal at the open", 88, 480, 460, C.green, 20, 50);
    addBullet(s, "Directly answers whether the return clock differs by known regime", 88, 532, 460, C.green, 20, 64);
    addRect(s, { left: 646, top: 164, width: 576, height: 430 }, C.panel);
    addText(s, "Separate later experiment", { left: 674, top: 194, width: 500, height: 34 }, { fontSize: 27, bold: true });
    addText(s, "Completed intraday window", { left: 676, top: 264, width: 468, height: 38 }, { fontSize: 27, bold: true, color: C.amber });
    addText(s, "↓", { left: 876, top: 310, width: 80, height: 44 }, { fontSize: 32, bold: true, color: C.muted, alignment: "center" });
    addText(s, "Later bars in the same session", { left: 676, top: 368, width: 468, height: 50 }, { fontSize: 26, bold: true, color: C.navy, alignment: "center" });
    addBullet(s, "Requires a separately declared bar window", 676, 472, 468, C.amber, 20, 62);
    addBullet(s, "Strictly prevents later bars from entering the state", 676, 542, 468, C.red, 20, 62);
    addNotes(s, "Daily ATR% and ER can be used as causal gates for intraday outcomes when they are computed through the prior completed session. This is the clean recommended first conditioning experiment.", [sources.intradayReport, sources.dailyReport]);
  }

  // 14 — scaling answer and next gate
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "Do not mechanically multiply ER20 by 13", 14);
    addRect(s, { left: 58, top: 164, width: 1164, height: 136 }, C.navy);
    addText(s, "A daily 20-session ER asks about roughly one trading month. A 260-bar ER asks about a different object: the path through thousands of within-session micro-moves.", { left: 86, top: 198, width: 1108, height: 72 }, { fontSize: 27, bold: true, color: C.white, alignment: "center" });
    addText(s, "Recommended sequence", { left: 58, top: 346, width: 340, height: 38 }, { fontSize: 29, bold: true });
    addText(s, "1", { left: 74, top: 424, width: 48, height: 48 }, { fontSize: 32, bold: true, color: C.blue, alignment: "center" });
    addText(s, "Use prior-day daily ATR% / ER20 / signed ER20 to split the existing gap-and-clock plot.", { left: 142, top: 418, width: 950, height: 60 }, { fontSize: 23, color: C.navy });
    addText(s, "2", { left: 74, top: 504, width: 48, height: 48 }, { fontSize: 32, bold: true, color: C.amber, alignment: "center" });
    addText(s, "Only if that view is informative, open a distinct intraday-state experiment with a small predeclared window set and strict bar timing.", { left: 142, top: 498, width: 950, height: 72 }, { fontSize: 23, color: C.navy });
    addText(s, "3", { left: 74, top: 596, width: 48, height: 48 }, { fontSize: 32, bold: true, color: C.red, alignment: "center" });
    addText(s, "Keep every first plot descriptive; promote only a concrete causal pattern to a falsification slice.", { left: 142, top: 590, width: 950, height: 58 }, { fontSize: 23, color: C.navy });
    addText(s, "CURRENT STATUS: OPENING-RESPONSE CONDITIONING ADDED ON SLIDES 29–34", { left: 58, top: 660, width: 1164, height: 20 }, { fontSize: 13, bold: true, color: C.red, alignment: "center" });
    addNotes(s, "Mechanical scaling assumes that the daily and intraday paths are the same object. They are not. The first clean test is to hold the daily state definition fixed and ask whether the intraday outcome distribution changes.", [sources.intradayReport, sources.dailyReport, sources.stateGrid]);
  }

  // 15 — proto-rule transition
  {
    const s = p.slides.add(); s.background.fill = C.navy;
    addText(s, "THIRD MICROSCOPE", { left: 72, top: 94, width: 420, height: 30 }, { fontSize: 17, bold: true, color: C.paleBlue });
    addText(s, "Can the geometry survive\nexecutable timing?", { left: 72, top: 170, width: 960, height: 170 }, { fontSize: 64, bold: true, color: C.white });
    addText(s, "Two fixed 20/20 clues are converted into next-open, open-to-open rules. The purpose is not to optimize them; it is to see which descriptive pattern remains visible after causal timing, no-overlap, costs, and simple controls.", { left: 76, top: 408, width: 1080, height: 126 }, { fontSize: 27, color: C.paleBlue });
    addText(s, "2018–2023 TRAIN only · one-shot confirmation follows", { left: 76, top: 602, width: 900, height: 32 }, { fontSize: 20, bold: true, color: C.white });
    addText(s, "15", { left: 1134, top: 672, width: 90, height: 20 }, { fontSize: 12, color: C.paleBlue, alignment: "right" });
    addNotes(s, "This section translates two already-observed NVDA 20/20 geometry clues into executable rules without changing the horizon or searching thresholds. It is a TRAIN construction test, not confirmation.", [sources.protoReport, sources.protoSummary]);
  }

  // 16 — exact rules
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "Two clues, two frozen rule translations", 16, "OPERATOR HYPOTHESIS LAB · NVDA PROTO-RULES");
    addRect(s, { left: 58, top: 164, width: 550, height: 352 }, C.paleBlue);
    addText(s, "Efficient-up continuation", { left: 86, top: 192, width: 480, height: 38 }, { fontSize: 29, bold: true, color: C.blue });
    addText(s, "At close t", { left: 88, top: 258, width: 130, height: 28 }, { fontSize: 18, bold: true, color: C.muted });
    addText(s, "R20 > 0  AND  ER20 ≥ 0.30", { left: 88, top: 294, width: 470, height: 44 }, { fontSize: 28, bold: true, color: C.navy });
    addText(s, "Thesis", { left: 88, top: 372, width: 130, height: 28 }, { fontSize: 18, bold: true, color: C.muted });
    addText(s, "An efficient upward path may continue after the signal is observable.", { left: 88, top: 408, width: 470, height: 76 }, { fontSize: 23, color: C.navy });
    addRect(s, { left: 640, top: 164, width: 582, height: 352 }, C.paleGreen);
    addText(s, "Calm-pullback rebound", { left: 670, top: 192, width: 500, height: 38 }, { fontSize: 29, bold: true, color: C.green });
    addText(s, "At close t", { left: 672, top: 258, width: 130, height: 28 }, { fontSize: 18, bold: true, color: C.muted });
    addText(s, "R20 < 0  AND  ATR% state = LOW or MEDIUM", { left: 672, top: 294, width: 500, height: 70 }, { fontSize: 26, bold: true, color: C.navy });
    addText(s, "Thesis", { left: 672, top: 372, width: 130, height: 28 }, { fontSize: 18, bold: true, color: C.muted });
    addText(s, "A loss in a non-high-volatility environment may be more recoverable than one inside a volatility shock.", { left: 672, top: 408, width: 500, height: 86 }, { fontSize: 22, color: C.navy });
    addRect(s, { left: 58, top: 548, width: 1164, height: 82 }, C.panel);
    addText(s, "Both: enter next open · exit open t+21 · 20 open-to-open intervals · no overlapping positions · 10 bps round trip", { left: 80, top: 572, width: 1120, height: 38 }, { fontSize: 22, bold: true, color: C.navy, alignment: "center" });
    addNotes(s, "The rules differ only in their causal entry condition. Timing, holding period, overlap policy, and cost are held fixed so the translation comparison remains intelligible.", [sources.protoReport, sources.protoSummary]);
  }

  // 17 — price windows
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "The rules select visibly different parts of NVDA history", 17, "OPERATOR HYPOTHESIS LAB · NVDA PROTO-RULES");
    await addImage(s, img.protoEntries, { left: 44, top: 144, width: 1180, height: 514 }, "NVDA adjusted price with entry-to-exit windows for efficient-up continuation and calm-pullback rebound rules");
    addNotes(s, "The price overlays are a sanity check on participation. Efficient-up continuation is active during many rising paths but also remains exposed to the 2022 breakdown. Calm-pullback rebound fires after losses only when the prior ATR-percent state is not high.", [sources.protoReport, sources.protoTrades]);
  }

  // 18 — primary readout
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "Only the rebound clears the narrow TRAIN translation gate", 18, "OPERATOR HYPOTHESIS LAB · NVDA PROTO-RULES");
    await addImage(s, img.protoEquity, { left: 42, top: 154, width: 790, height: 452 }, "Realized equity paths for the two NVDA proto-rules with normalized NVDA close as a visual reference");
    addRect(s, { left: 856, top: 160, width: 366, height: 214 }, C.panel);
    addText(s, "Efficient-up continuation", { left: 882, top: 184, width: 314, height: 32 }, { fontSize: 23, bold: true, color: C.blue });
    addText(s, "39 trades", { left: 882, top: 236, width: 138, height: 40 }, { fontSize: 29, bold: true });
    addText(s, "2.59% mean net", { left: 1030, top: 236, width: 166, height: 40 }, { fontSize: 24, bold: true });
    addText(s, "61.5% profitable · −0.29 pp vs drift", { left: 882, top: 298, width: 314, height: 34 }, { fontSize: 18, bold: true, color: C.red });
    addText(s, "STOP: weaker than unconditional drift and all three simple controls.", { left: 882, top: 338, width: 314, height: 28 }, { fontSize: 15, color: C.navy });
    addRect(s, { left: 856, top: 396, width: 366, height: 230 }, C.paleGreen);
    addText(s, "Calm-pullback rebound", { left: 882, top: 420, width: 314, height: 32 }, { fontSize: 23, bold: true, color: C.green });
    addText(s, "27 trades", { left: 882, top: 472, width: 138, height: 40 }, { fontSize: 29, bold: true });
    addText(s, "6.33% mean net", { left: 1030, top: 472, width: 166, height: 40 }, { fontSize: 24, bold: true });
    addText(s, "74.1% profitable · +3.45 pp vs drift", { left: 882, top: 534, width: 314, height: 34 }, { fontSize: 18, bold: true, color: C.green });
    addText(s, "PASS TRAIN translation only—not confirmation and not edge authority.", { left: 882, top: 576, width: 314, height: 40 }, { fontSize: 15, bold: true, color: C.navy });
    addNotes(s, "The continuation rule averages 2.59% net versus 2.88% unconditional gross drift. The rebound rule averages 6.33% net and exceeds drift by 3.45 percentage points. Realized equity is shown only when trades exit; the dotted buy-and-hold line uses a separate right axis and is a visual context reference, not a matched-risk baseline.", [sources.protoSummary, sources.protoReport]);
  }

  // 19 — controls
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "The joint rebound condition adds discrimination", 19, "OPERATOR HYPOTHESIS LAB · NVDA PROTO-RULES");
    await addImage(s, img.protoDistributions, { left: 34, top: 142, width: 930, height: 520 }, "Net return distributions for each NVDA primary proto-rule and three simple controls");
    addRect(s, { left: 986, top: 160, width: 236, height: 458 }, C.panel);
    addText(s, "Mean net return", { left: 1008, top: 184, width: 192, height: 28 }, { fontSize: 21, bold: true });
    addText(s, "6.33%", { left: 1008, top: 238, width: 192, height: 46 }, { fontSize: 36, bold: true, color: C.green });
    addText(s, "joint rebound", { left: 1008, top: 282, width: 192, height: 24 }, { fontSize: 16, color: C.muted });
    addText(s, "4.53%", { left: 1008, top: 334, width: 192, height: 38 }, { fontSize: 29, bold: true });
    addText(s, "ATR state only", { left: 1008, top: 372, width: 192, height: 24 }, { fontSize: 16, color: C.muted });
    addText(s, "3.85%", { left: 1008, top: 418, width: 192, height: 38 }, { fontSize: 29, bold: true });
    addText(s, "same calm state after gains", { left: 1008, top: 456, width: 192, height: 48 }, { fontSize: 15, color: C.muted });
    addText(s, "2.77%", { left: 1008, top: 524, width: 192, height: 38 }, { fontSize: 29, bold: true });
    addText(s, "negative R20 only", { left: 1008, top: 562, width: 192, height: 24 }, { fontSize: 16, color: C.muted });
    addText(s, "The sign and volatility state work better together than either alone in TRAIN.", { left: 986, top: 630, width: 236, height: 40 }, { fontSize: 14, bold: true, color: C.navy, alignment: "center" });
    addNotes(s, "The primary rebound rule has a higher mean and median than negative-R20-only, low/medium-ATR-only, and the positive-R20 opposite inside the same ATR states. This is the strongest reason to retain it as a confirmation candidate, while recognizing that all comparisons come from the discovery sample.", [sources.protoSummary, sources.protoTrades]);
  }

  // 20 — annual context
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "Calendar slices reveal the burden of one-asset evidence", 20, "OPERATOR HYPOTHESIS LAB · NVDA PROTO-RULES");
    await addImage(s, img.protoAnnual, { left: 48, top: 146, width: 840, height: 500 }, "Annual mean net trade returns and counts for the two NVDA primary proto-rules");
    addRect(s, { left: 916, top: 162, width: 306, height: 446 }, C.panel);
    addText(s, "What matters", { left: 944, top: 190, width: 250, height: 30 }, { fontSize: 24, bold: true });
    addBullet(s, "Continuation suffers a concentrated 2022 failure.", 944, 252, 250, C.red, 19, 76);
    addBullet(s, "Rebound is positive in five of six years, but 2018 is approximately flat.", 944, 346, 250, C.green, 19, 96);
    addBullet(s, "Only 3–6 rebound trades appear in any year.", 944, 462, 250, C.amber, 19, 76);
    addText(s, "Years are context, not independent replications. The next honest evidence must come from untouched time.", { left: 944, top: 554, width: 250, height: 58 }, { fontSize: 15, bold: true, color: C.navy });
    addNotes(s, "The annual view helps detect whether a full-period mean is carried by one isolated episode. Rebound is not purely a single-year artifact, but the yearly samples are tiny and correlated; they do not replace OOS confirmation.", [sources.protoCalendar, sources.protoSummary]);
  }

  // 21 — representative trades
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "Representative paths keep the trade-level reality visible", 21, "OPERATOR HYPOTHESIS LAB · NVDA PROTO-RULES");
    await addImage(s, img.protoTapes, { left: 40, top: 142, width: 1188, height: 518 }, "Worst, median-nearest, and best 20-session open paths for both NVDA proto-rules");
    addNotes(s, "The representative tapes show that neither rule creates a smooth conditional path. The continuation worst case loses roughly 41%, and the rebound worst case loses roughly 31%. The median rebound path is more consistent with the original thesis: an initially quiet path that develops into a recovery across the holding window.", [sources.protoTrades, sources.protoReport]);
  }

  // 22 — decision
  {
    const s = p.slides.add(); s.background.fill = C.white; addHeader(s, "One rule stops; one earns untouched confirmation", 22, "OPERATOR HYPOTHESIS LAB · NVDA PROTO-RULES");
    addRect(s, { left: 58, top: 166, width: 540, height: 228 }, C.paleRed);
    addText(s, "STOP", { left: 86, top: 194, width: 120, height: 42 }, { fontSize: 31, bold: true, color: C.red });
    addText(s, "Efficient-up continuation", { left: 86, top: 254, width: 462, height: 38 }, { fontSize: 28, bold: true });
    addText(s, "The exact ER20-plus-positive-R20 translation adds no incremental value in TRAIN.", { left: 86, top: 316, width: 462, height: 60 }, { fontSize: 21, color: C.navy });
    addRect(s, { left: 640, top: 166, width: 582, height: 228 }, C.paleGreen);
    addText(s, "RETAIN", { left: 670, top: 194, width: 150, height: 42 }, { fontSize: 31, bold: true, color: C.green });
    addText(s, "Calm-pullback rebound", { left: 670, top: 254, width: 500, height: 38 }, { fontSize: 28, bold: true });
    addText(s, "The joint loss-plus-not-high-ATR rule clears drift and its simple controls in TRAIN.", { left: 670, top: 316, width: 500, height: 60 }, { fontSize: 21, color: C.navy });
    addText(s, "What this does—and does not—mean", { left: 58, top: 446, width: 530, height: 38 }, { fontSize: 28, bold: true });
    addBullet(s, "It proves the descriptive rebound clue can survive next-open timing, costs, and no-overlap construction.", 72, 510, 1100, C.green, 21, 62);
    addBullet(s, "It does not prove generalization, robustness to nearby definitions, capacity, or live edge.", 72, 582, 1100, C.red, 21, 62);
    addText(s, "NEXT GATE: freeze this exact rule, then read the untouched 2024+ period once—without rescue tuning.", { left: 58, top: 652, width: 1164, height: 26 }, { fontSize: 17, bold: true, color: C.navy, alignment: "center" });
    addNotes(s, "The next methodological gate is a one-shot confirmation of the frozen calm-pullback rebound rule on untouched 2024+ data. Any later robustness or neighboring-definition work must be declared separately and cannot rewrite the original confirmation result.", [sources.protoReport, sources.protoSummary, sources.protoTrades]);
  }

  // 23 — confirmation transition
  {
    const s = p.slides.add(); s.background.fill = C.navy;
    addText(s, "FOURTH MICROSCOPE", { left: 72, top: 94, width: 420, height: 30 }, { fontSize: 17, bold: true, color: C.paleBlue });
    addText(s, "The candidate meets\nuntouched time", { left: 72, top: 170, width: 960, height: 170 }, { fontSize: 64, bold: true, color: C.white });
    addText(s, "The calm-pullback rebound rule is read once on 2024-01-02 through 2026-06-23. The signal, ATR% states, timing, 20-session hold, no-overlap rule, 10-bps cost, controls, and gates remain exactly frozen.", { left: 76, top: 408, width: 1080, height: 126 }, { fontSize: 27, color: C.paleBlue });
    addText(s, "This period is now evidence—not a new tuning surface.", { left: 76, top: 602, width: 900, height: 32 }, { fontSize: 20, bold: true, color: C.white });
    addText(s, "23", { left: 1134, top: 672, width: 90, height: 20 }, { fontSize: 12, color: C.paleBlue, alignment: "right" });
    addNotes(s, "This is the irreversible confirmation read. The exact TRAIN-selected candidate is evaluated on the previously sealed period. A failure stops the exact rule without rescue tuning.", [sources.confirmationReport, sources.confirmationGates, sources.confirmationHealth]);
  }

  // 24 — scorecard
  {
    const s = p.slides.add(); s.background.fill = C.white; addConfirmationHeader(s, "The TRAIN advantage does not replicate", 24);
    await addImage(s, img.confirmationComparison, { left: 36, top: 144, width: 850, height: 514 }, "TRAIN and untouched-confirmation mean net returns for the frozen rebound rule and its controls");
    addRect(s, { left: 910, top: 158, width: 312, height: 468 }, C.paleRed);
    addText(s, "STOP", { left: 938, top: 186, width: 256, height: 44 }, { fontSize: 34, bold: true, color: C.red });
    addText(s, "1.56%", { left: 938, top: 248, width: 256, height: 54 }, { fontSize: 42, bold: true });
    addText(s, "confirmation mean net", { left: 938, top: 302, width: 256, height: 28 }, { fontSize: 17, bold: true, color: C.navy });
    addBullet(s, "9 trades; minimum gate was 10", 938, 362, 252, C.red, 18, 56);
    addBullet(s, "−2.88 pp versus 4.44% unconditional drift", 938, 430, 252, C.red, 18, 72);
    addBullet(s, "Below every ingredient control; strongest = 5.12%", 938, 516, 252, C.red, 18, 82);
    addNotes(s, "TRAIN showed a 6.33% mean net return for the joint condition. Untouched confirmation produced 1.56%, below 4.44% unconditional gross drift and below all three frozen controls. The exact rule therefore fails confirmation.", [sources.confirmationReport, sources.confirmationGates, sources.confirmationSummary]);
  }

  // 25 — every trade
  {
    const s = p.slides.add(); s.background.fill = C.white; addConfirmationHeader(s, "A positive median is not enough to beat the baseline", 25);
    await addImage(s, img.confirmationReturns, { left: 42, top: 148, width: 882, height: 490 }, "Every frozen confirmation trade return in chronological order");
    addRect(s, { left: 950, top: 164, width: 272, height: 438 }, C.panel);
    addText(s, "What survived", { left: 974, top: 190, width: 224, height: 30 }, { fontSize: 23, bold: true });
    addText(s, "+2.19%", { left: 974, top: 246, width: 224, height: 46 }, { fontSize: 35, bold: true, color: C.green });
    addText(s, "median net", { left: 974, top: 290, width: 224, height: 24 }, { fontSize: 16, color: C.muted });
    addText(s, "6 / 9", { left: 974, top: 344, width: 224, height: 46 }, { fontSize: 35, bold: true, color: C.green });
    addText(s, "profitable trades", { left: 974, top: 388, width: 224, height: 24 }, { fontSize: 16, color: C.muted });
    addText(s, "What failed", { left: 974, top: 452, width: 224, height: 30 }, { fontSize: 23, bold: true, color: C.red });
    addText(s, "The sequence's average was too weak to overcome ordinary NVDA drift or the simpler controls.", { left: 974, top: 500, width: 224, height: 82 }, { fontSize: 18, bold: true, color: C.navy });
    addNotes(s, "The rule was right more often than wrong and had a positive median, but those facts are subordinate to the economic comparison. The average result lagged what NVDA produced unconditionally over the same 20-session horizon.", [sources.confirmationTrades, sources.confirmationSummary, sources.confirmationGates]);
  }

  // 26 — participation and realized equity
  {
    const s = p.slides.add(); s.background.fill = C.white; addConfirmationHeader(s, "Participation was sparse—and the path depended on late winners", 26);
    await addImage(s, img.confirmationPrice, { left: 38, top: 146, width: 592, height: 470 }, "NVDA price and the nine non-overlapping confirmation trade windows");
    await addImage(s, img.confirmationEquity, { left: 650, top: 146, width: 592, height: 470 }, "Realized confirmation equity and normalized NVDA close reference");
    addText(s, "The rule spent much of 2025 underwater, then recovered on a +21.6% late trade. A final equity level above 1 does not establish incremental edge.", { left: 84, top: 628, width: 1112, height: 44 }, { fontSize: 18, bold: true, color: C.navy, alignment: "center" });
    addNotes(s, "The participation chart shows only nine non-overlapping entries. The realized-equity path remained below its starting level through much of the confirmation period before a late large winner. This visual reinforces why the drift and ingredient-control comparisons are decisive.", [sources.confirmationTrades, sources.confirmationSummary]);
  }

  // 27 — path tapes
  {
    const s = p.slides.add(); s.background.fill = C.white; addConfirmationHeader(s, "The trade paths do not reveal a stable rebound shape", 27);
    await addImage(s, img.confirmationTapes, { left: 40, top: 144, width: 1188, height: 514 }, "All nine confirmation paths and the worst, median-nearest, and best examples");
    addNotes(s, "The all-path panel shows considerable dispersion rather than a repeated recovery trajectory. The worst trade lost 18.6%, the median-nearest trade gained 2.2%, and the best gained 21.6%. These are descriptive trade tapes, not independent confirmations.", [sources.confirmationTrades, sources.confirmationReport]);
  }

  // 28 — final confirmation decision
  {
    const s = p.slides.add(); s.background.fill = C.white; addConfirmationHeader(s, "The exact calm-pullback rebound rule stops", 28);
    addRect(s, { left: 58, top: 164, width: 1164, height: 96 }, C.paleRed);
    addText(s, "STOP_CONFIRMATION_GATES_FAILED", { left: 86, top: 190, width: 1108, height: 44 }, { fontSize: 31, bold: true, color: C.red, alignment: "center" });
    addText(s, "Predeclared gates", { left: 58, top: 304, width: 350, height: 38 }, { fontSize: 28, bold: true });
    const gates = [
      ["FAIL", "Minimum sample", "9 trades; required 10"],
      ["FAIL", "Beat drift", "1.56% vs 4.44%"],
      ["PASS", "Positive median", "+2.19%"],
      ["PASS", "Majority profitable", "66.7%"],
      ["FAIL", "Beat each control", "strongest control 5.12%"],
    ];
    gates.forEach(([status, label, detail], i) => {
      const top = 360 + i * 50;
      const pass = status === "PASS";
      addRect(s, { left: 72, top, width: 92, height: 34 }, pass ? C.paleGreen : C.paleRed);
      addText(s, status, { left: 78, top: top + 7, width: 80, height: 20 }, { fontSize: 14, bold: true, color: pass ? C.green : C.red, alignment: "center" });
      addText(s, label, { left: 186, top: top + 5, width: 270, height: 26 }, { fontSize: 19, bold: true });
      addText(s, detail, { left: 462, top: top + 6, width: 230, height: 24 }, { fontSize: 17, color: C.muted });
    });
    addRect(s, { left: 738, top: 304, width: 484, height: 340 }, C.panel);
    addText(s, "What we learned", { left: 766, top: 332, width: 428, height: 34 }, { fontSize: 27, bold: true });
    addBullet(s, "A descriptive clue can survive TRAIN execution and still vanish in new time.", 768, 394, 420, C.blue, 20, 76);
    addBullet(s, "Win rate and median can look encouraging while average opportunity cost is unfavorable.", 768, 486, 420, C.amber, 20, 84);
    addText(s, "No rescue tuning. Any future variation must be declared as a new hypothesis and cannot overwrite this result.", { left: 766, top: 568, width: 428, height: 66 }, { fontSize: 18, bold: true, color: C.red, alignment: "center" });
    addNotes(s, "The exact one-asset rule is stopped. The confirmation period has now been consumed and cannot be reused as untouched evidence. A later variation may be researched only as a new hypothesis with a newly protected confirmation boundary.", [sources.confirmationGates, sources.confirmationReport, sources.confirmationHealth]);
  }

  // 29 — opening-response transition
  {
    const s = p.slides.add(); s.background.fill = C.navy;
    addText(s, "FIFTH MICROSCOPE", { left: 72, top: 94, width: 420, height: 30 }, { fontSize: 17, bold: true, color: C.paleBlue });
    addText(s, "After the opening bar,\nwhat happens next?", { left: 72, top: 170, width: 980, height: 170 }, { fontSize: 64, bold: true, color: C.white });
    addText(s, "At 10:00 ET, the first 30-minute return is complete and therefore observable. The remaining 10:00-to-16:00 return is still ahead. This section asks whether the first move carries directional information into that tradable remainder.", { left: 76, top: 408, width: 1080, height: 126 }, { fontSize: 27, color: C.paleBlue });
    addText(s, "1,487 full sessions · 12 early closes excluded · no rule or P&L", { left: 76, top: 602, width: 980, height: 32 }, { fontSize: 20, bold: true, color: C.white });
    addText(s, "29", { left: 1134, top: 672, width: 90, height: 20 }, { fontSize: 12, color: C.paleBlue, alignment: "right" });
    addNotes(s, "The causal clock is fixed before looking at outcomes: use the completed 09:30-10:00 log return as the predictor and the 10:00-16:00 log return as the outcome. Only full 13-bar sessions are eligible.", [sources.openingReport, sources.openingChecks, sources.intradayReport]);
  }

  // 30 — raw scatter
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningHeader(s, "The opening bar carries only a weak unconditional signal", 30);
    await addImage(s, img.openingScatter, { left: 38, top: 144, width: 856, height: 514 }, "NVDA completed opening-bar return versus still-tradeable remainder-of-day return, 2018-2023");
    addRect(s, { left: 916, top: 158, width: 306, height: 464 }, C.panel);
    addText(s, "+0.050", { left: 942, top: 190, width: 254, height: 52 }, { fontSize: 40, bold: true, color: C.blue });
    addText(s, "Pearson correlation", { left: 942, top: 244, width: 254, height: 28 }, { fontSize: 18, bold: true, color: C.navy });
    addText(s, "−0.979%", { left: 942, top: 314, width: 122, height: 42 }, { fontSize: 28, bold: true, color: C.red });
    addText(s, "+1.070%", { left: 1072, top: 314, width: 124, height: 42 }, { fontSize: 28, bold: true, color: C.green });
    addText(s, "sample-wide 20th / 80th cutoffs", { left: 942, top: 358, width: 254, height: 42 }, { fontSize: 15, color: C.muted, alignment: "center" });
    addBullet(s, "The cloud dominates the relationship.", 942, 432, 250, C.red, 18, 58);
    addBullet(s, "The tails lean slightly in the direction of the opening move.", 942, 508, 250, C.green, 18, 78);
    addNotes(s, "The unfiltered opening-to-remainder Pearson correlation is +0.050. The vertical lines are the single sample-wide 20th and 80th percentile cutoffs. They are descriptive bins, not yet causal rolling thresholds.", [sources.openingReport, sources.openingSessionLedger, sources.openingBins]);
  }

  // 31 — broad-bin distributions
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningHeader(s, "Tail averages separate, but individual outcomes overlap heavily", 31);
    await addImage(s, img.openingDistribution, { left: 48, top: 144, width: 1180, height: 514 }, "Remainder-of-day return distributions after bottom-20, middle-60, and top-20 percent NVDA opening bars");
    addNotes(s, "Bottom-20% opening sessions average -0.15% over the remainder with 45.1% positive outcomes. Middle-60% sessions average -0.02% with 50.6% positive. Top-20% sessions average +0.21% with 57.6% positive. The heavy overlap is the central caution.", [sources.openingReport, sources.openingBins]);
  }

  // 32 — median paths
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningHeader(s, "The directional tilt develops gradually after 10:00", 32);
    await addImage(s, img.openingPaths, { left: 48, top: 144, width: 1180, height: 514 }, "Median cumulative 10:00-to-close NVDA paths and interquartile bands by opening-return bin");
    addNotes(s, "The median paths separate gradually rather than through one isolated bar. Top-tail sessions end with a positive median remainder, while bottom-tail sessions end slightly negative. Interquartile bands remain broad and overlapping; this is a conditional path summary, not an equity curve.", [sources.openingReport, sources.openingSessionLedger]);
  }

  // 33 — prior-day states
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningHeader(s, "Prior-day ATR% is the clearest descriptive discriminator", 33);
    await addImage(s, img.openingStates, { left: 34, top: 144, width: 900, height: 500 }, "Mean remainder-of-day return by opening bin and lagged signed-ER20 or ATR-percent state");
    addRect(s, { left: 956, top: 158, width: 266, height: 464 }, C.panel);
    addText(s, "Top 20% opening", { left: 980, top: 184, width: 218, height: 30 }, { fontSize: 22, bold: true });
    addText(s, "+0.38%", { left: 980, top: 238, width: 218, height: 44 }, { fontSize: 34, bold: true, color: C.green });
    addText(s, "LOW / MEDIUM ATR%", { left: 980, top: 284, width: 218, height: 24 }, { fontSize: 16, bold: true, color: C.navy });
    addText(s, "61.8% up · n=186", { left: 980, top: 314, width: 218, height: 24 }, { fontSize: 16, color: C.muted });
    addText(s, "−0.07%", { left: 980, top: 370, width: 218, height: 44 }, { fontSize: 34, bold: true, color: C.red });
    addText(s, "HIGH ATR%", { left: 980, top: 416, width: 218, height: 24 }, { fontSize: 16, bold: true, color: C.navy });
    addText(s, "50.5% up · n=111", { left: 980, top: 446, width: 218, height: 24 }, { fontSize: 16, color: C.muted });
    addRect(s, { left: 980, top: 502, width: 218, height: 2 }, C.rule);
    addText(s, "Bottom-20% opening inside HIGH ATR% averages −0.48%; only 39.3% finish the remainder positive.", { left: 980, top: 526, width: 218, height: 78 }, { fontSize: 17, bold: true, color: C.navy });
    addNotes(s, "The cleanest long-side descriptive contrast is a top-20% opening after a prior-day LOW or MEDIUM ATR-percent state: +0.377% mean remainder, +0.519% median, 61.8% positive, n=186. The same opening tail in HIGH ATR% averages -0.072% with 50.5% positive, n=111. Signed-ER20 down plus a top-tail opening averages +0.48% but has only 24 observations and is not promoted here.", [sources.openingReport, sources.openingBins, sources.openingContrasts]);
  }

  // 34 — candidate and next translation
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningHeader(s, "ATR% conditions a candidate for the next TRAIN test", 34);
    addRect(s, { left: 58, top: 164, width: 544, height: 406 }, C.paleGreen);
    addText(s, "Descriptive candidate", { left: 88, top: 192, width: 480, height: 36 }, { fontSize: 28, bold: true, color: C.green });
    addText(s, "Before the open", { left: 90, top: 258, width: 190, height: 26 }, { fontSize: 17, bold: true, color: C.muted });
    addText(s, "Prior-day ATR% = LOW or MEDIUM", { left: 90, top: 292, width: 466, height: 42 }, { fontSize: 26, bold: true, color: C.navy });
    addText(s, "At 10:00", { left: 90, top: 366, width: 190, height: 26 }, { fontSize: 17, bold: true, color: C.muted });
    addText(s, "Opening return is in its positive tail", { left: 90, top: 400, width: 466, height: 42 }, { fontSize: 26, bold: true, color: C.navy });
    addText(s, "Observed remainder: +0.38% mean · +0.52% median · 61.8% up · n=186", { left: 90, top: 486, width: 466, height: 58 }, { fontSize: 19, bold: true, color: C.green, alignment: "center" });
    addRect(s, { left: 640, top: 164, width: 582, height: 406 }, C.panel);
    addText(s, "Recommended causal translation", { left: 670, top: 192, width: 500, height: 36 }, { fontSize: 28, bold: true });
    addBullet(s, "Compute the opening-tail cutoff from the prior 252 full sessions only.", 674, 258, 500, C.blue, 20, 72);
    addBullet(s, "If the first bar clears that cutoff and yesterday's ATR% was not HIGH, enter at 10:00 and exit at 16:00.", 674, 344, 500, C.green, 20, 94);
    addBullet(s, "Compare with opening-tail-only, ATR-state-only, HIGH-ATR opposite, and unconditional 10:00-to-close controls.", 674, 454, 500, C.amber, 20, 92);
    addText(s, "THIS TRANSLATION IS EXECUTED ON SLIDES 35–41", { left: 58, top: 622, width: 1164, height: 26 }, { fontSize: 17, bold: true, color: C.red, alignment: "center" });
    addNotes(s, "The current +1.070% cutoff was computed from the entire descriptive sample and therefore must not be used retrospectively as though it had been known each day. The next section converts the same rank concept into a rolling prior-252-session threshold and tests the 10:00-to-close long rule with the predeclared ingredient controls.", [sources.openingReport, sources.openingContrasts, sources.openingChecks, sources.openingRuleSpec]);
  }

  // 35 — causal opening-rule transition
  {
    const s = p.slides.add(); s.background.fill = C.navy;
    addText(s, "SIXTH MICROSCOPE", { left: 72, top: 94, width: 420, height: 30 }, { fontSize: 17, bold: true, color: C.paleBlue });
    addText(s, "Can the clue survive\ncausal timing?", { left: 72, top: 170, width: 980, height: 170 }, { fontSize: 64, bold: true, color: C.white });
    addText(s, "At 10:00, compare the completed opening return with a threshold learned from the prior 252 full sessions. Trade only when yesterday's ATR% was LOW or MEDIUM; exit at 16:00. The rule must beat every simpler control after 10 bps round trip.", { left: 76, top: 408, width: 1080, height: 132 }, { fontSize: 27, color: C.paleBlue });
    addText(s, "TRAIN only · 2024+ intraday data remain unread", { left: 76, top: 602, width: 980, height: 32 }, { fontSize: 20, bold: true, color: C.white });
    addText(s, "35", { left: 1134, top: 672, width: 90, height: 20 }, { fontSize: 12, color: C.paleBlue, alignment: "right" });
    addNotes(s, "This is a new causal TRAIN hypothesis, not a continuation of the retrospective bin. The current opening is compared with the prior 252 complete openings only; the ATR-percent state comes from the preceding completed daily session; the position begins at 10:00 and ends at 16:00.", [sources.openingRuleSpec, sources.openingRuleChecks]);
  }

  // 36 — rolling threshold
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningRuleHeader(s, "Every signal is knowable at 10:00 without future data", 36);
    await addImage(s, img.openingRuleThreshold, { left: 48, top: 144, width: 1180, height: 514 }, "NVDA opening returns, causal prior-252-session 80th-percentile threshold, and candidate or HIGH-ATR tail events");
    addNotes(s, "The first 252 full sessions are warm-up only. Beginning 2019-01-11, each opening return is compared with the prior 252 complete openings using a type-8 80th percentile. Green dots meet the opening threshold after a LOW or MEDIUM prior-day ATR-percent state; red triangles meet the same threshold after HIGH ATR-percent.", [sources.openingRuleSpec, sources.openingRuleChecks, sources.openingRuleTrades]);
  }

  // 37 — controls
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningRuleHeader(s, "ATR% performs real discrimination inside TRAIN", 37);
    await addImage(s, img.openingRuleControls, { left: 48, top: 144, width: 1180, height: 514 }, "Net NVDA 10:00-to-close return distributions for the causal candidate and four predeclared controls");
    addNotes(s, "The candidate produces 157 trades with +0.204% mean net, +0.430% median net, and 59.9% profitable. Opening-tail-only produces +0.062% mean net. LOW/MEDIUM-ATR-only produces -0.019%. The same opening tail after HIGH ATR produces -0.192%. Unconditional 10:00-to-close after costs produces -0.068%. The candidate clears every aggregate and simpler-control gate.", [sources.openingRuleReport, sources.openingRuleSummary, sources.openingRuleTrades]);
  }

  // 38 — calendar gate
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningRuleHeader(s, "The aggregate result fails temporal breadth", 38);
    await addImage(s, img.openingRuleAnnual, { left: 42, top: 144, width: 850, height: 514 }, "Annual mean net return and trade counts for the causal NVDA opening-tail LOW-MEDIUM ATR candidate");
    addRect(s, { left: 918, top: 158, width: 304, height: 464 }, C.panel);
    addText(s, "2 / 5", { left: 944, top: 190, width: 252, height: 56 }, { fontSize: 44, bold: true, color: C.red });
    addText(s, "positive years", { left: 944, top: 246, width: 252, height: 28 }, { fontSize: 19, bold: true, color: C.navy });
    addText(s, "Gate required at least 3", { left: 944, top: 278, width: 252, height: 24 }, { fontSize: 15, color: C.muted });
    addRect(s, { left: 944, top: 332, width: 252, height: 2 }, C.rule);
    addText(s, "89.9%", { left: 944, top: 364, width: 252, height: 50 }, { fontSize: 38, bold: true, color: C.amber });
    addText(s, "of cumulative net log return came from 2023", { left: 944, top: 416, width: 252, height: 58 }, { fontSize: 18, bold: true, color: C.navy, alignment: "center" });
    addText(s, "2019, 2020, and 2022 had negative mean net returns.", { left: 944, top: 520, width: 252, height: 62 }, { fontSize: 18, color: C.red, alignment: "center" });
    addNotes(s, "Only 2021 and 2023 have positive annual mean net return; the frozen calendar-breadth gate requires at least three positive years. The 2023 candidate trades contribute 0.2876 of the total 0.3201 cumulative net log return, or 89.9%. The failure is not weak sample size or weak aggregate economics; it is concentration in late sample time.", [sources.openingRuleCalendar, sources.openingRuleGates, sources.openingRuleReport]);
  }

  // 39 — realized equity
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningRuleHeader(s, "Most realized gains arrive late in the sample", 39);
    await addImage(s, img.openingRuleEquity, { left: 48, top: 144, width: 1180, height: 514 }, "Realized causal NVDA opening-rule equity, flat between same-day trades, during TRAIN");
    addNotes(s, "Sequential same-day candidate trades compound $1 to about $1.38 after 10 bps round trip, but the path spends much of 2019-2022 around or below its start and rises sharply in 2023. This is a realized TRAIN path, not confirmation and not deployable authority.", [sources.openingRuleReport, sources.openingRuleTrades, sources.openingRuleCalendar]);
  }

  // 40 — representative tapes
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningRuleHeader(s, "A positive typical trade still contains severe same-day risk", 40);
    await addImage(s, img.openingRuleTapes, { left: 48, top: 144, width: 1180, height: 514 }, "Worst, median-nearest, and best intraday paths for the causal NVDA opening-rule candidate");
    addNotes(s, "The worst candidate day loses 6.58% net from 10:00 to 16:00; the median-nearest day gains 0.43%; the best gains 6.04% net. These tapes make the distribution concrete and show that the filter does not imply low-volatility trades even when the prior-day ATR-percent state is LOW or MEDIUM.", [sources.openingRuleTrades, sources.openingRuleReport]);
  }

  // 41 — final causal opening-rule decision
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningRuleHeader(s, "The mechanism is promising; the exact rule still stops", 41);
    addRect(s, { left: 58, top: 164, width: 1164, height: 88 }, C.paleRed);
    addText(s, "STOP_TRAIN_TRANSLATION_GATES_FAILED", { left: 86, top: 186, width: 1108, height: 44 }, { fontSize: 31, bold: true, color: C.red, alignment: "center" });
    addText(s, "Frozen gates", { left: 58, top: 292, width: 350, height: 38 }, { fontSize: 28, bold: true });
    const openingGates = [
      ["PASS", "Support", "157 trades; minimum 100"],
      ["PASS", "Positive mean", "+0.204% net"],
      ["PASS", "Typical trade", "+0.430% median; 59.9% up"],
      ["PASS", "Beat controls", "strongest control +0.062%"],
      ["FAIL", "Calendar breadth", "2 positive years; required 3"],
    ];
    openingGates.forEach(([status, label, detail], i) => {
      const top = 342 + i * 48;
      const pass = status === "PASS";
      addRect(s, { left: 72, top, width: 92, height: 32 }, pass ? C.paleGreen : C.paleRed);
      addText(s, status, { left: 78, top: top + 6, width: 80, height: 20 }, { fontSize: 14, bold: true, color: pass ? C.green : C.red, alignment: "center" });
      addText(s, label, { left: 186, top: top + 4, width: 238, height: 26 }, { fontSize: 18, bold: true });
      addText(s, detail, { left: 430, top: top + 5, width: 280, height: 24 }, { fontSize: 16, color: C.muted });
    });
    addRect(s, { left: 752, top: 292, width: 470, height: 334 }, C.panel);
    addText(s, "What survives the STOP", { left: 780, top: 320, width: 414, height: 34 }, { fontSize: 27, bold: true });
    addBullet(s, "A strong opening behaves differently after calm versus HIGH-ATR prior days.", 782, 382, 406, C.green, 19, 72);
    addBullet(s, "The joint filter beats both ingredients, the opposite state, and drift inside TRAIN.", 782, 468, 406, C.blue, 19, 78);
    addText(s, "The exact rule cannot advance because its gains are concentrated in 2023. No threshold, state, clock, or cost rescue is allowed from this packet.", { left: 780, top: 558, width: 414, height: 62 }, { fontSize: 17, bold: true, color: C.red, alignment: "center" });
    addNotes(s, "Four of five predeclared TRAIN gates pass. The calendar-breadth gate fails, so the exact rule stops and 2024+ intraday data remain unread. The scientifically useful residue is the signed ATR-state contrast: top-tail openings continue after LOW/MEDIUM ATR but fade after HIGH ATR. That mechanism can motivate a separately declared future study, but this parameterization cannot be rescue-tuned.", [sources.openingRuleGates, sources.openingRuleSummary, sources.openingRuleCalendar, sources.openingRuleReport]);
  }

  // 42 — cross-asset mechanism transition
  {
    const s = p.slides.add(); s.background.fill = C.navy;
    addText(s, "SEVENTH MICROSCOPE", { left: 72, top: 94, width: 420, height: 30 }, { fontSize: 17, bold: true, color: C.paleBlue });
    addText(s, "Does the mechanism\ntravel?", { left: 72, top: 170, width: 980, height: 170 }, { fontSize: 64, bold: true, color: C.white });
    addText(s, "Repeat the same causal opening-tail / prior-day ATR contrast across a pre-existing 26-asset atlas and three eras. This is a mechanism-replication test, not a strategy backtest and not a search for favorable symbols.", { left: 76, top: 408, width: 1080, height: 132 }, { fontSize: 27, color: C.paleBlue });
    addText(s, "NVDA excluded · its 2024+ intraday confirmation window remains unread", { left: 76, top: 602, width: 1040, height: 32 }, { fontSize: 20, bold: true, color: C.white });
    addText(s, "42", { left: 1134, top: 672, width: 90, height: 20 }, { fontSize: 12, color: C.paleBlue, alignment: "right" });
    addNotes(s, "The exact NVDA rule stopped, but its ATR-dependent response suggested a separately declared mechanism question. This section asks whether that response appears broadly across assets and eras. NVDA is excluded so its later period remains available for a separate one-asset confirmation decision.", [sources.openingAtlasSpec, sources.openingAtlasChecks, sources.openingRuleReport]);
  }

  // 43 — frozen atlas contract
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningAtlasHeader(s, "Breadth is tested without changing the original mechanism", 43);
    addRect(s, { left: 58, top: 164, width: 544, height: 438 }, C.paleBlue);
    addText(s, "Frozen causal question", { left: 88, top: 194, width: 480, height: 36 }, { fontSize: 28, bold: true, color: C.navy });
    addText(s, "At 10:00", { left: 90, top: 258, width: 190, height: 26 }, { fontSize: 17, bold: true, color: C.muted });
    addText(s, "Opening return clears its own prior-252-session 80th percentile", { left: 90, top: 292, width: 466, height: 66 }, { fontSize: 24, bold: true, color: C.navy });
    addText(s, "Compare", { left: 90, top: 388, width: 190, height: 26 }, { fontSize: 17, bold: true, color: C.muted });
    addText(s, "Mean 10:00-to-close response after HIGH versus LOW/MEDIUM prior-day ATR%", { left: 90, top: 422, width: 466, height: 76 }, { fontSize: 23, bold: true, color: C.navy });
    addText(s, "Negative HIGH-minus-LOW/MED supports the mechanism", { left: 90, top: 526, width: 466, height: 42 }, { fontSize: 18, bold: true, color: C.green, alignment: "center" });
    addRect(s, { left: 640, top: 164, width: 582, height: 438 }, C.panel);
    addText(s, "Evidence boundary", { left: 670, top: 194, width: 500, height: 36 }, { fontSize: 28, bold: true });
    addBullet(s, "26 pre-existing stocks and ETFs; no symbol was added because it looked favorable.", 674, 258, 500, C.blue, 20, 82);
    addBullet(s, "Causal 30-minute outcomes span 2018–2025, with 2017 used only for warm-up.", 674, 354, 500, C.green, 20, 78);
    addBullet(s, "Pass requires at least 60% negative assets, a negative median contrast, and the same sign in every era.", 674, 446, 500, C.amber, 20, 98);
    addText(s, "No costs, portfolio construction, or trade authority", { left: 670, top: 558, width: 500, height: 25 }, { fontSize: 17, bold: true, color: C.red, alignment: "center" });
    addNotes(s, "The mechanism is unchanged from the NVDA clue: each asset uses its own causal prior-252 opening threshold, the ATR-percent state comes from the prior completed session, and the outcome is the still-tradeable 10:00-to-close log return. The atlas and gates were frozen before inspecting the result.", [sources.openingAtlasSpec, sources.openingAtlasChecks, sources.openingAtlasReport]);
  }

  // 44 — asset breadth
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningAtlasHeader(s, "The NVDA direction is a minority pattern across assets", 44);
    await addImage(s, img.openingAtlasAssets, { left: 40, top: 148, width: 860, height: 500 }, "Asset-level HIGH-minus-LOW-MED opening response contrasts across the 26-asset atlas");
    addRect(s, { left: 918, top: 158, width: 304, height: 464 }, C.panel);
    addText(s, "9 / 26", { left: 944, top: 190, width: 252, height: 56 }, { fontSize: 44, bold: true, color: C.red });
    addText(s, "assets support the sign", { left: 944, top: 246, width: 252, height: 28 }, { fontSize: 18, bold: true, color: C.navy });
    addText(s, "Frozen gate required 60%", { left: 944, top: 278, width: 252, height: 24 }, { fontSize: 15, color: C.muted });
    addRect(s, { left: 944, top: 332, width: 252, height: 2 }, C.rule);
    addText(s, "+0.093%", { left: 944, top: 364, width: 252, height: 50 }, { fontSize: 36, bold: true, color: C.red });
    addText(s, "median asset contrast", { left: 944, top: 416, width: 252, height: 28 }, { fontSize: 18, bold: true, color: C.navy, alignment: "center" });
    addText(s, "The typical asset continues more—not less—after a HIGH-ATR strong opening.", { left: 944, top: 500, width: 252, height: 76 }, { fontSize: 18, color: C.red, alignment: "center" });
    addNotes(s, "Only nine of 26 eligible assets have a negative HIGH-minus-LOW/MED response. The asset-median contrast is +0.093%, the opposite of the proposed mechanism. All 26 assets satisfy the predeclared support requirement, so this is a behavioral failure rather than a sample-coverage failure.", [sources.openingAtlasAssets, sources.openingAtlasGates, sources.openingAtlasReport]);
  }

  // 45 — era stability
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningAtlasHeader(s, "The one supportive era does not persist", 45);
    await addImage(s, img.openingAtlasEras, { left: 40, top: 148, width: 880, height: 500 }, "Pooled strong-opening remainder and asset-median ATR contrast across three eras");
    addRect(s, { left: 942, top: 158, width: 280, height: 464 }, C.panel);
    addText(s, "2018–20", { left: 966, top: 190, width: 232, height: 30 }, { fontSize: 20, bold: true, color: C.red });
    addText(s, "+0.085% median contrast", { left: 966, top: 226, width: 232, height: 28 }, { fontSize: 17, color: C.navy });
    addText(s, "2021–23", { left: 966, top: 294, width: 232, height: 30 }, { fontSize: 20, bold: true, color: C.green });
    addText(s, "−0.038% median contrast", { left: 966, top: 330, width: 232, height: 28 }, { fontSize: 17, color: C.navy });
    addText(s, "2024–25", { left: 966, top: 398, width: 232, height: 30 }, { fontSize: 20, bold: true, color: C.red });
    addText(s, "+0.083% median contrast", { left: 966, top: 434, width: 232, height: 28 }, { fontSize: 17, color: C.navy });
    addRect(s, { left: 966, top: 492, width: 232, height: 2 }, C.rule);
    addText(s, "The clue is time-local, not era-stable.", { left: 966, top: 520, width: 232, height: 62 }, { fontSize: 19, bold: true, color: C.red, alignment: "center" });
    addNotes(s, "The asset-median contrast is negative only during 2021-2023, and even there just 53.8% of assets are negative. It is positive in 2018-2020 and again in the newly added 2024-2025 period. This fails the predeclared every-era sign gate and shows that the apparent mechanism is time-local.", [sources.openingAtlasEras, sources.openingAtlasGates, sources.openingAtlasReport]);
  }

  // 46 — asset response map
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningAtlasHeader(s, "Assets occupy different response geometries", 46);
    await addImage(s, img.openingAtlasResponse, { left: 36, top: 145, width: 900, height: 510 }, "Low-medium versus high ATR strong-opening mean remainder for every atlas asset");
    addRect(s, { left: 954, top: 160, width: 268, height: 452 }, C.panel);
    addText(s, "How to read it", { left: 978, top: 188, width: 220, height: 32 }, { fontSize: 24, bold: true });
    addBullet(s, "Below the diagonal supports weaker continuation in HIGH ATR.", 978, 254, 220, C.green, 17, 74);
    addBullet(s, "Above it contradicts that mechanism.", 978, 350, 220, C.red, 17, 62);
    addBullet(s, "Large labels mark contrast magnitude—not chosen winners.", 978, 438, 220, C.blue, 17, 76);
    addText(s, "AMD, MSFT, and GOOGL look different from TSLA, AMT, and HD—but this atlas cannot convert that post-hoc split into a rule.", { left: 978, top: 532, width: 220, height: 64 }, { fontSize: 15, color: C.muted, alignment: "center" });
    addNotes(s, "This map retains both state-conditioned means instead of collapsing each asset to one contrast. Points below the diagonal support the proposed mechanism; points above it contradict it. The labeled assets have the largest absolute contrasts, which exposes heterogeneity but does not authorize choosing those symbols after seeing the outcome.", [sources.openingAtlasAssets, sources.openingAtlasReport]);
  }

  // 47 — sector context
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningAtlasHeader(s, "Sector structure is a clue, not a permission slip", 47);
    await addImage(s, img.openingAtlasSectors, { left: 40, top: 148, width: 880, height: 500 }, "Sector-median HIGH-minus-LOW-MED response across the frozen atlas");
    addRect(s, { left: 942, top: 158, width: 280, height: 464 }, C.panel);
    addText(s, "Pockets of support", { left: 966, top: 190, width: 232, height: 32 }, { fontSize: 23, bold: true, color: C.green });
    addText(s, "Technology, communication services, materials, and part of energy lean negative.", { left: 966, top: 242, width: 232, height: 92 }, { fontSize: 18, color: C.navy });
    addRect(s, { left: 966, top: 360, width: 232, height: 2 }, C.rule);
    addText(s, "But most groups have only two representatives, and the sector split was not a selection rule.", { left: 966, top: 394, width: 232, height: 96 }, { fontSize: 18, color: C.red });
    addText(s, "This can motivate a new predeclared sector hypothesis; it cannot rescue the broad mechanism.", { left: 966, top: 522, width: 232, height: 62 }, { fontSize: 17, bold: true, color: C.red, alignment: "center" });
    addNotes(s, "Technology and communication-services representatives are uniformly negative in this atlas, while many defensive and consumer groups are positive. Those differences are scientifically useful for hypothesis generation, but the groups are small and were not predeclared as a selection rule. The broad mechanism remains stopped.", [sources.openingAtlasSectors, sources.openingAtlasAssets, sources.openingAtlasReport]);
  }

  // 48 — asset-era heatmap
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningAtlasHeader(s, "Even supportive assets can change sign through time", 48);
    await addImage(s, img.openingAtlasHeatmap, { left: 46, top: 142, width: 760, height: 520 }, "Asset-by-era heatmap of HIGH-minus-LOW-MED opening response contrasts");
    addRect(s, { left: 842, top: 160, width: 380, height: 452 }, C.panel);
    addText(s, "The instability is two-dimensional", { left: 870, top: 190, width: 324, height: 64 }, { fontSize: 25, bold: true });
    addBullet(s, "Across rows: assets disagree about the sign.", 872, 286, 320, C.blue, 19, 62);
    addBullet(s, "Across columns: the same asset can reverse between eras.", 872, 368, 320, C.amber, 19, 74);
    addBullet(s, "A broad static ATR gate therefore lacks transportability.", 872, 462, 320, C.red, 19, 72);
    addText(s, "A future niche study must predeclare both the universe and the time-validation design.", { left: 870, top: 554, width: 324, height: 42 }, { fontSize: 16, bold: true, color: C.navy, alignment: "center" });
    addNotes(s, "The heatmap makes the failure visible at the asset-era level. Some assets have negative contrasts in one era and positive contrasts in another. This rules out treating prior-day ATR as a broad, static permission gate for strong-opening continuation without a newly declared universe and validation design.", [sources.openingAtlasEras, sources.openingAtlasAssets, sources.openingAtlasReport]);
  }

  // 49 — cross-asset mechanism verdict
  {
    const s = p.slides.add(); s.background.fill = C.white; addOpeningAtlasHeader(s, "The broad mechanism stops; NVDA remains separate", 49);
    addRect(s, { left: 58, top: 164, width: 1164, height: 88 }, C.paleRed);
    addText(s, "STOP_MECHANISM_REPLICATION_GATES_FAILED", { left: 86, top: 186, width: 1108, height: 44 }, { fontSize: 31, bold: true, color: C.red, alignment: "center" });
    addText(s, "Frozen gates", { left: 58, top: 292, width: 350, height: 38 }, { fontSize: 28, bold: true });
    const atlasGates = [
      ["PASS", "Asset support", "26 eligible; minimum 24"],
      ["FAIL", "Median contrast", "+0.093%; required negative"],
      ["FAIL", "Asset breadth", "34.6% negative; required 60%"],
      ["FAIL", "Era stability", "negative only in 2021–2023"],
      ["FAIL", "HIGH-ATR fade", "+0.040% pooled; required nonpositive"],
    ];
    atlasGates.forEach(([status, label, detail], i) => {
      const top = 342 + i * 48;
      const pass = status === "PASS";
      addRect(s, { left: 72, top, width: 92, height: 32 }, pass ? C.paleGreen : C.paleRed);
      addText(s, status, { left: 78, top: top + 6, width: 80, height: 20 }, { fontSize: 14, bold: true, color: pass ? C.green : C.red, alignment: "center" });
      addText(s, label, { left: 186, top: top + 4, width: 238, height: 26 }, { fontSize: 18, bold: true });
      addText(s, detail, { left: 430, top: top + 5, width: 292, height: 24 }, { fontSize: 16, color: C.muted });
    });
    addRect(s, { left: 752, top: 292, width: 470, height: 334 }, C.panel);
    addText(s, "What survives the STOP", { left: 780, top: 320, width: 414, height: 34 }, { fontSize: 27, bold: true });
    addBullet(s, "The NVDA result is not evidence for an asset-agnostic ATR gate.", 782, 382, 406, C.red, 19, 72);
    addBullet(s, "Technology and communication pockets can motivate a new, predeclared niche hypothesis.", 782, 468, 406, C.blue, 19, 82);
    addText(s, "NVDA's 2024+ data remain unread. The one-asset thesis may still be tested on its own terms, but it cannot borrow confidence from this atlas.", { left: 780, top: 558, width: 414, height: 62 }, { fontSize: 17, bold: true, color: C.navy, alignment: "center" });
    addNotes(s, "Only the support gate passes. The median asset contrast, asset breadth, every-era sign, and pooled HIGH-ATR fade gates all fail. The broad mechanism therefore stops. This does not retroactively answer the separate single-NVDA confirmation question, because NVDA was excluded and its 2024+ intraday data remain unread.", [sources.openingAtlasGates, sources.openingAtlasAssets, sources.openingAtlasEras, sources.openingAtlasReport]);
  }

  for (const [index, slide] of p.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    const png = await p.export({ slide, format: "png", scale: 2 });
    await fs.writeFile(path.join(renderRoot, `${stem}.png`), Buffer.from(await png.arrayBuffer()));
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(renderRoot, `${stem}.layout.json`), await layout.text());
  }
  const montage = await p.export({ format: "webp", montage: true, scale: 1 });
  await fs.writeFile(path.join(qaRoot, "montage.webp"), Buffer.from(await montage.arrayBuffer()));
  const inspect = await p.inspect({ kind: "slide,textbox,shape,image,chart,table,layout", maxChars: 200000 });
  await fs.writeFile(path.join(qaRoot, "nvda_microscope_evidence.inspect.ndjson"), inspect.ndjson);
  await fs.writeFile(`${deckPath}.inspect.ndjson`, inspect.ndjson);
  const pptx = await PresentationFile.exportPptx(p);
  await pptx.save(deckPath);
  console.log(deckPath);
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
