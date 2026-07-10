import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const artifactToolPath = path.join(
  process.env.NODE_PATH || "",
  "@oai",
  "artifact-tool",
  "dist",
  "artifact_tool.mjs"
);
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactToolPath).href);

const ROOT = process.cwd();
const OUT_DIR = path.join(ROOT, "presentations");
const STEM = "gen5_3_pca_feature_alpha_diagnostics_pivot";
const DECK_PATH = path.join(OUT_DIR, `${STEM}.pptx`);
const INSPECT_PATH = path.join(OUT_DIR, `${STEM}.pptx.inspect.ndjson`);
const MONTAGE_PATH = path.join(OUT_DIR, `${STEM}_montage.webp`);
const RENDER_DIR = path.join(OUT_DIR, `${STEM}_slides`);
const SMOKE_DIR = path.join(ROOT, "runs", "research_workbench", "g53", "feat_smoke_20260708a");
const SMOKE_HEATMAP = path.join(SMOKE_DIR, "style_diversified_live_capital_alpha_heatmap.png");
const SMOKE_ALPHA_BAR = path.join(SMOKE_DIR, "style_diversified_live_capital_alpha_bar.png");
const SMOKE_EQUITY = path.join(SMOKE_DIR, "style_diversified_live_capital_equity_overlay.png");
const SMOKE_SCATTER = path.join(SMOKE_DIR, "style_diversified_live_capital_exposure_alpha_scatter.png");
const FULL_DIR = path.join(ROOT, "runs", "research_workbench", "g53", "feat_full5w_20260709a");
const FULL_HEATMAP = path.join(FULL_DIR, "style_diversified_live_capital_alpha_heatmap.png");
const FULL_ALPHA_BAR = path.join(FULL_DIR, "style_diversified_live_capital_alpha_bar.png");
const FULL_EQUITY = path.join(FULL_DIR, "style_diversified_live_capital_equity_overlay.png");
const FULL_SCATTER = path.join(FULL_DIR, "style_diversified_live_capital_exposure_alpha_scatter.png");
const AUDIT_DIR = path.join(FULL_DIR, "feature_audit");
const AUDIT_TAPES = path.join(AUDIT_DIR, "gen53_representative_trade_tapes.png");
const AUDIT_STATE = path.join(AUDIT_DIR, "gen53_state_discrimination_diagnostics.png");
const AUDIT_ALIGNMENT = path.join(AUDIT_DIR, "gen53_action_alignment_diagnostics.png");
const AUDIT_FAMILY = path.join(AUDIT_DIR, "gen53_selected_family_mix_heatmap.png");

const SLIDE = { width: 1280, height: 720 };
const PAGE = { left: 64, top: 48, width: 1152, height: 624 };
const COLORS = {
  bg: "slate-50",
  ink: "slate-950",
  muted: "slate-600",
  line: "slate-200",
  soft: "white",
  blue: "sky-700",
  blueSoft: "sky-100",
  green: "emerald-700",
  greenSoft: "emerald-100",
  amber: "amber-700",
  amberSoft: "amber-100",
  rose: "rose-700",
  roseSoft: "rose-100",
  violet: "violet-700",
  violetSoft: "violet-100",
};

async function writeBlob(filePath, blob) {
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
    color: COLORS.ink,
    fit: "shrink",
    ...style,
  };
  return shape;
}

function addFooter(slide, index) {
  addText(slide, "Gen5.3 planning brief | PCA feature alpha diagnostics", {
    left: PAGE.left,
    top: 686,
    width: 620,
    height: 18,
  }, { fontSize: 11, color: "slate-400" });
  addText(slide, String(index).padStart(2, "0"), {
    left: 1168,
    top: 684,
    width: 48,
    height: 20,
  }, { fontSize: 11, color: "slate-400", bold: true });
}

function addTitle(slide, eyebrow, title, subtitle) {
  addText(slide, eyebrow, {
    left: PAGE.left,
    top: PAGE.top,
    width: 720,
    height: 24,
  }, { fontSize: 12, color: COLORS.blue, bold: true });
  addText(slide, title, {
    left: PAGE.left,
    top: PAGE.top + 52,
    width: 980,
    height: 102,
  }, { fontSize: 34, bold: true, color: COLORS.ink });
  if (subtitle) {
    addText(slide, subtitle, {
      left: PAGE.left,
      top: PAGE.top + 160,
      width: 900,
      height: 56,
    }, { fontSize: 18, color: COLORS.muted });
  }
}

function addCard(slide, { x, y, w, h, title, body, accent = COLORS.blue, fill = COLORS.soft }) {
  slide.shapes.add({
    geometry: "roundRect",
    position: { left: x, top: y, width: w, height: h },
    fill,
    line: { style: "solid", fill: COLORS.line, width: 1 },
    borderRadius: "rounded-lg",
    shadow: "shadow-sm",
  });
  slide.shapes.add({
    geometry: "rect",
    position: { left: x, top: y, width: 6, height: h },
    fill: accent,
    line: { style: "solid", fill: accent, width: 0 },
  });
  const compact = h <= 92;
  addText(slide, title, {
    left: x + 24,
    top: y + (compact ? 12 : 20),
    width: w - 48,
    height: compact ? 22 : 34,
  }, { fontSize: compact ? 16.5 : 19, bold: true, color: COLORS.ink });
  addText(slide, body, {
    left: x + 24,
    top: y + (compact ? 40 : 62),
    width: w - 48,
    height: compact ? h - 44 : h - 78,
  }, { fontSize: compact ? 12.8 : 15.5, color: COLORS.muted });
}

function addPill(slide, text, x, y, w, fill, color) {
  slide.shapes.add({
    geometry: "roundRect",
    position: { left: x, top: y, width: w, height: 30 },
    fill,
    line: { style: "solid", fill, width: 0 },
    borderRadius: "rounded-full",
  });
  addText(slide, text, { left: x + 14, top: y + 6, width: w - 28, height: 18 }, {
    fontSize: 11,
    bold: true,
    color,
  });
}

function addBullets(slide, items, x, y, w, lineHeight = 34, options = {}) {
  items.forEach((item, idx) => {
    const top = y + idx * lineHeight;
    slide.shapes.add({
      geometry: "ellipse",
      position: { left: x, top: top + 8, width: 8, height: 8 },
      fill: options.dot || COLORS.blue,
      line: { style: "solid", fill: options.dot || COLORS.blue, width: 0 },
    });
    addText(slide, item, {
      left: x + 22,
      top,
      width: w - 22,
      height: lineHeight,
    }, { fontSize: options.fontSize || 18, color: options.color || COLORS.ink });
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

function newSlide(presentation, index) {
  const slide = presentation.slides.add();
  slide.background.fill = COLORS.bg;
  addFooter(slide, index);
  return slide;
}

async function buildDeck() {
  const presentation = Presentation.create({ slideSize: SLIDE });

  let slide = newSlide(presentation, 1);
  addTitle(
    slide,
    "STRATEGIC PIVOT",
    "Gen5.3 should test whether PCA is being fed the right features",
    "The last round answered a useful question: cloning Gen4 is a calibration exercise, not the destination. The next question is whether PCA 3x3 can become a stronger alpha engine by improving the feature layer."
  );
  addPill(slide, "Research-only", 64, 288, 132, COLORS.blueSoft, COLORS.blue);
  addPill(slide, "PCA 3x3 stays fixed", 214, 288, 170, COLORS.greenSoft, COLORS.green);
  addPill(slide, "Live bridge untouched", 402, 288, 168, COLORS.amberSoft, COLORS.amber);
  addCard(slide, {
    x: 64, y: 352, w: 540, h: 170,
    title: "Communication job",
    body: "By the end, future us should remember why we stopped judging Gen5.x mainly by Gen4 similarity and started asking whether better PCA inputs can create better benchmark-relative trades.",
    accent: COLORS.blue,
  });
  addCard(slide, {
    x: 632, y: 352, w: 520, h: 170,
    title: "Operator question captured",
    body: "Are we barking up the wrong tree, or is the right move to get everything we can out of PCA before jumping to a new regime model?",
    accent: COLORS.violet,
  });

  slide = newSlide(presentation, 2);
  addTitle(
    slide,
    "THE TENSION",
    "The Gen4 clone goal was useful, but it became too narrow",
    "Gen5.2 taught us that matching old mechanics is not the same as building the strongest research system."
  );
  addCard(slide, {
    x: 64, y: 260, w: 338, h: 250,
    title: "What felt wrong",
    body: "Even with increasingly Gen4-faithful mechanics, Gen5.x did not fully recreate the strongest Gen4 equity curves.",
    accent: COLORS.rose,
  });
  addCard(slide, {
    x: 426, y: 260, w: 338, h: 250,
    title: "What broader screens exposed",
    body: "Outside the familiar high-beta winners, many lanes struggled against equal-weight buy-and-hold benchmarks.",
    accent: COLORS.amber,
  });
  addCard(slide, {
    x: 788, y: 260, w: 338, h: 250,
    title: "What that does not prove",
    body: "It does not prove PCA is a dead end. It proves we need to inspect the whole causal chain instead of only the selection policy.",
    accent: COLORS.green,
  });

  slide = newSlide(presentation, 3);
  addTitle(
    slide,
    "THE REFRAME",
    "Gen4 is a reference instrument, not the instrument we are trying to build",
    "The durable lesson is to separate mechanical parity from research quality."
  );
  addBullets(slide, [
    "Gen4 parity helps identify missing mechanics, accounting differences, and accidental assumptions.",
    "Benchmark-relative alpha is the real objective for the research engine.",
    "PCA 3x3 is mature enough to be tested seriously before moving to HMMs.",
    "The next layer to interrogate is the feature set that creates the states."
  ], 92, 262, 980, 48, { dot: COLORS.blue, fontSize: 21 });
  addCard(slide, {
    x: 92, y: 500, w: 980, h: 92,
    title: "Working conclusion",
    body: "If the features do not describe participation, fragility, and relative strength, even a clean PCA map can produce states that are elegant but not trade-useful.",
    accent: COLORS.violet,
  });

  slide = newSlide(presentation, 4);
  addTitle(
    slide,
    "WHY PCA FIRST",
    "We should get the most out of PCA before buying a new regime engine",
    "A new model can add power later, but it can also hide uncertainty. PCA still gives us a clean inspection surface."
  );
  const reasons = [
    ["Auditable", "We can inspect states, scatter plots, bands, and trade tapes."],
    ["Stable", "The 3x3 quantile surface is already implemented and familiar."],
    ["Diagnostic", "Feature changes can be isolated without changing every downstream layer."],
    ["Comparable", "Benchmark-relative results can be read across windows and baskets."]
  ];
  reasons.forEach(([title, body], i) => {
    const x = 64 + (i % 2) * 560;
    const y = 252 + Math.floor(i / 2) * 154;
    addCard(slide, { x, y, w: 520, h: 122, title, body, accent: [COLORS.blue, COLORS.green, COLORS.amber, COLORS.violet][i] });
  });

  slide = newSlide(presentation, 5);
  addTitle(
    slide,
    "GEN5.3 SCOPE",
    "Gen5.3 can be the feature-quality track",
    "This name is justified if it marks a real change in question: from 'can we clone Gen4?' to 'what PCA inputs create alpha?'"
  );
  addCard(slide, {
    x: 82, y: 250, w: 500, h: 246,
    title: "Gen5.2",
    body: "Mechanics calibration. Gen4 comparison. Live-capital accounting. Selection-policy parity. Fallback behavior. Trade tape reconciliation.",
    accent: COLORS.blue,
  });
  addCard(slide, {
    x: 624, y: 250, w: 500, h: 246,
    title: "Gen5.3",
    body: "PCA feature diagnostics. Benchmark-relative alpha. Upside participation. Downside avoidance. State accountability. Feature-block comparisons.",
    accent: COLORS.green,
  });

  slide = newSlide(presentation, 6);
  addTitle(
    slide,
    "FEATURE HYPOTHESES",
    "Better PCA states may come from better descriptions of the market",
    "The first screen should test feature blocks, not every possible parameter."
  );
  const featureBlocks = [
    ["Trend and participation", "Returns across horizons, EMA slope, EMA stack, distance from highs, continuation markers."],
    ["Volatility and drawdown", "Realized volatility, ATR/range expansion, downside vol, drawdown from rolling peak."],
    ["Benchmark-relative", "Excess return vs SPY/QQQ, beta-adjusted relative strength, relative drawdown."],
    ["Breadth and context", "Percent above moving average, dispersion, co-movement, sector-relative strength."],
    ["Liquidity stress", "Volume z-score, dollar-volume stability, gap proxy from daily OHLC."]
  ];
  featureBlocks.forEach(([title, body], i) => {
    const y = 270 + i * 76;
    addCard(slide, {
      x: 86, y, w: 1030, h: 64, title, body,
      accent: [COLORS.blue, COLORS.amber, COLORS.green, COLORS.violet, COLORS.rose][i],
    });
  });

  slide = newSlide(presentation, 7);
  addTitle(
    slide,
    "FIRST SCREEN",
    "Hold the engine steady and only change the features",
    "A narrow test gives cleaner information than another wide factorial."
  );
  const lanes = [
    ["current_features_control", "Existing PCA inputs."],
    ["trend_participation_plus", "Adds features meant to detect when to stay with upside."],
    ["trend_volatility_plus", "Adds volatility and drawdown context to trend participation."],
    ["trend_volatility_relative_plus", "Adds benchmark-relative strength and fragility context."]
  ];
  lanes.forEach(([title, body], i) => {
    const x = 80 + i * 280;
    addCard(slide, { x, y: 260, w: 246, h: 214, title, body, accent: [COLORS.blue, COLORS.green, COLORS.amber, COLORS.violet][i] });
  });
  addText(slide, "Constants: behavioral_pool PCA, 3x3 quantile grid, same basket, same windows, same benchmark, same portfolio accounting.", {
    left: 100, top: 530, width: 1010, height: 46,
  }, { fontSize: 20, color: COLORS.ink, bold: true });

  slide = newSlide(presentation, 8);
  addTitle(
    slide,
    "READOUT",
    "A useful result explains how alpha appeared or failed",
    "The readout should be more diagnostic than a leaderboard."
  );
  addBullets(slide, [
    "Excess return versus equal-weight buy-and-hold basket.",
    "Upside participation when the benchmark basket is positive.",
    "Downside avoidance when the benchmark basket is negative.",
    "Time in market by state, asset, and selection policy.",
    "Trade count, win rate, average win/loss, and tail loss.",
    "State-level contribution to return and drawdown.",
    "No-trade frequency and whether no-trade avoided bad exposure."
  ], 92, 236, 1020, 42, { dot: COLORS.green, fontSize: 19 });

  slide = newSlide(presentation, 9);
  addTitle(
    slide,
    "GUARDRAILS",
    "This track should widen understanding without contaminating operations",
    "Feature exploration can get large quickly, so the first iteration needs hard boundaries."
  );
  addCard(slide, {
    x: 78, y: 248, w: 330, h: 234,
    title: "Operational wall",
    body: "Do not touch the frozen live advice bridge. Gen5.3 is research-only.",
    accent: COLORS.rose,
  });
  addCard(slide, {
    x: 444, y: 248, w: 330, h: 234,
    title: "Comparison wall",
    body: "Predeclare windows and compare every feature block to the same control and benchmark.",
    accent: COLORS.amber,
  });
  addCard(slide, {
    x: 810, y: 248, w: 330, h: 234,
    title: "Interpretation wall",
    body: "A winning feature block is inspection evidence, not accepted allocation evidence.",
    accent: COLORS.blue,
  });

  slide = newSlide(presentation, 10);
  addTitle(
    slide,
    "DECISIONS",
    "The next gate is small enough to approve cleanly",
    "This is the point where the operator chooses whether Gen5.3 is the right name and which feature blocks deserve the first test."
  );
  addBullets(slide, [
    "Name the track Gen5.3 if we accept PCA feature diagnostics as the next milestone.",
    "Choose the first active basket and context universe.",
    "Choose two or three feature blocks for the first screen.",
    "Choose historical windows before looking at results.",
    "Decide whether direct-spec and pooled-family both remain active in the screen."
  ], 92, 292, 1000, 42, { dot: COLORS.violet, fontSize: 20 });
  addCard(slide, {
    x: 92, y: 552, w: 1000, h: 78,
    title: "Recommended default",
    body: "Proceed with current control, trend-participation, trend-volatility, and trend-volatility-relative feature blocks under PCA 3x3, then judge by benchmark-relative diagnostics.",
    accent: COLORS.green,
  });

  slide = newSlide(presentation, 11);
  addTitle(
    slide,
    "FIRST SCREEN DESIGN",
    "The first Gen5.3 test changes features, not the engine",
    "That keeps the causal question clean: did the state map improve because the PCA saw better information?"
  );
  addCard(slide, {
    x: 72, y: 248, w: 500, h: 132,
    title: "Held fixed",
    body: "Behavioral-pool PCA, 3x3 quantile states, direct-spec and pooled-family selection, shared-account live-capital accounting, and equal-weight basket-hold benchmark.",
    accent: COLORS.blue,
  });
  addCard(slide, {
    x: 612, y: 248, w: 500, h: 132,
    title: "Stress dataset",
    body: "High beta growth, defensive staples, and energy/commodity baskets across 2020Q3 rebound and 2022Q1 rate-shock drawdown windows.",
    accent: COLORS.amber,
  });
  addCard(slide, {
    x: 72, y: 420, w: 500, h: 132,
    title: "Lean replay choice",
    body: "The first run uses state-switch continuation by default, because recent audits point to participation and continuity as the sharper failure mode.",
    accent: COLORS.green,
  });
  addCard(slide, {
    x: 612, y: 420, w: 500, h: 132,
    title: "Guardrail",
    body: "The frozen live advice bridge is untouched. This screen is research-only and cannot change operational advice semantics.",
    accent: COLORS.rose,
  });

  slide = newSlide(presentation, 12);
  addTitle(
    slide,
    "FEATURE CONDITIONS",
    "Each feature set asks a different economic question",
    "The conditions are deliberately additive so we can see whether each new layer earns its place."
  );
  const featureCards = [
    ["current_features_control", "Does the existing Gen5.2 PCA surface already explain enough state behavior?"],
    ["trend_participation_plus", "Do returns, EMA shape, and distance from highs help PCA recognize upside participation?"],
    ["trend_volatility_plus", "Does adding downside vol, range, drawdown, and vol-ratio separate healthy trend from fragile trend?"],
    ["trend_volatility_relative_plus", "Does context-relative return, volatility, and drawdown distinguish leadership from broad beta?"]
  ];
  featureCards.forEach(([title, body], i) => {
    const x = 72 + (i % 2) * 560;
    const y = 250 + Math.floor(i / 2) * 156;
    addCard(slide, {
      x, y, w: 520, h: 122, title, body,
      accent: [COLORS.blue, COLORS.green, COLORS.amber, COLORS.violet][i],
    });
  });

  slide = newSlide(presentation, 13);
  addTitle(
    slide,
    "ROADMAP",
    "Gen5.3 should become a feature-regime workbench",
    "Trend is the first test because it matches the current failure mode, but it should not become the whole research universe."
  );
  const roadmap = [
    ["Mean reversion", "Stretch, dislocation, RSI slope, Bollinger position, and capitulation features."],
    ["Volatility regimes", "Compression, expansion, downside acceleration, gap frequency, and drawdown speed."],
    ["Relative leadership", "Context-relative strength, relative drawdown, and cross-sectional rank or z-score."],
    ["Event and sentiment", "Later extension only, because earnings and sentiment require stricter timestamp and provider guardrails."]
  ];
  roadmap.forEach(([title, body], i) => {
    const y = 236 + i * 92;
    addCard(slide, {
      x: 96, y, w: 992, h: 72, title, body,
      accent: [COLORS.blue, COLORS.green, COLORS.violet, COLORS.rose][i],
    });
  });

  slide = newSlide(presentation, 14);
  addTitle(
    slide,
    "FIRST SMOKE RUN",
    "The staged diverse packet tested all feature sets without paying full factorial compute",
    "This is not the full answer. It is the first sanity-check surface across high-beta, defensive, and commodity/gold behavior in 2022Q1."
  );
  addCard(slide, {
    x: 70, y: 250, w: 326, h: 160,
    title: "Scope",
    body: "Two active symbols per archetype: AMD/NVDA, KO/WMT, XLE/GLD. Same broad anchors, 3x3 behavioral-pool PCA, direct and pooled-family policies.",
    accent: COLORS.blue,
  });
  addCard(slide, {
    x: 430, y: 250, w: 326, h: 160,
    title: "Why staged",
    body: "Full-width feature sweeps are compute-heavy because each feature set changes state assignment and requires separate authority fitting.",
    accent: COLORS.amber,
  });
  addCard(slide, {
    x: 790, y: 250, w: 326, h: 160,
    title: "Implementation finding",
    body: "Replay now reads frozen pca_feature_cols from authority contracts; compact slugs avoid Windows path-length failures.",
    accent: COLORS.green,
  });
  addCard(slide, {
    x: 160, y: 450, w: 870, h: 92,
    title: "Artifact packet",
    body: "runs/research_workbench/g53/feat_smoke_20260708a",
    accent: COLORS.violet,
  });

  slide = newSlide(presentation, 15);
  addTitle(
    slide,
    "SMOKE RESULT",
    "Feature design changed alpha behavior, but no feature block is promoted yet",
    "Green cells beat the same-basket equal-weight hold over 2022Q1; red cells lagged it."
  );
  await addImage(slide, SMOKE_ALPHA_BAR, {
    left: 78, top: 282, width: 1120, height: 340,
  }, "Gen5.3 diverse smoke alpha bar chart");

  slide = newSlide(presentation, 16);
  addTitle(
    slide,
    "EQUITY AUDIT",
    "The same result looks different by basket archetype",
    "High-beta success was mostly drawdown avoidance in a falling basket; commodity/gold underparticipated in a strong basket."
  );
  await addImage(slide, SMOKE_EQUITY, {
    left: 74, top: 205, width: 1130, height: 438,
  }, "Gen5.3 diverse smoke equity overlay");

  slide = newSlide(presentation, 17);
  addTitle(
    slide,
    "FIRST INTERPRETATION",
    "The signal is real enough to continue, but not clean enough to canonize",
    "The next run should add breadth and at least one more window before changing defaults."
  );
  addCard(slide, {
    x: 64, y: 244, w: 356, h: 178,
    title: "High beta",
    body: "All feature sets beat the falling basket. Trend+vol was strongest at +19.3 pp alpha, but only 6.5% exposure and one entry.",
    accent: COLORS.green,
  });
  addCard(slide, {
    x: 462, y: 244, w: 356, h: 178,
    title: "Defensive",
    body: "Trend-participation direct was the best lane at +2.4 pp alpha. Volatility and relative additions lagged the simple basket hold.",
    accent: COLORS.blue,
  });
  addCard(slide, {
    x: 860, y: 244, w: 356, h: 178,
    title: "Commodity/gold",
    body: "All lanes made money, but none beat a strong basket hold. Trend-participation was least bad at -7.6 pp alpha.",
    accent: COLORS.amber,
  });
  addCard(slide, {
    x: 156, y: 474, w: 900, h: 94,
    title: "Working hypothesis",
    body: "Trend features may improve participation in some baskets; volatility and relative features may be better avoidance filters than general alpha boosters. Test wider before promoting anything.",
    accent: COLORS.violet,
  });

  slide = newSlide(presentation, 18);
  addTitle(
    slide,
    "FULL-SYMBOL FOLLOW-UP",
    "The confidence run deliberately made the smoke result harder to survive",
    "The next screen kept PCA 3x3, selection policy, accounting, and replay fixed while expanding symbols and historical regimes."
  );
  addCard(slide, {
    x: 68, y: 238, w: 330, h: 164,
    title: "More symbols",
    body: "Full five-name baskets: high-beta growth, defensive staples, and energy/commodity. This reduces the chance that one symbol explains the result.",
    accent: COLORS.blue,
  });
  addCard(slide, {
    x: 430, y: 238, w: 330, h: 164,
    title: "More regimes",
    body: "Five OOS windows: 2020Q3, 2021Q4, 2022Q1, 2022Q4, and 2024Q4. The screen spans rebound, late-cycle growth, drawdown, stress, and risk-on periods.",
    accent: COLORS.amber,
  });
  addCard(slide, {
    x: 792, y: 238, w: 330, h: 164,
    title: "Same comparison",
    body: "Four PCA feature sets, direct-spec versus pooled-family, state-switch continuation, and equal-weight live-basket hold as benchmark.",
    accent: COLORS.green,
  });
  addCard(slide, {
    x: 156, y: 456, w: 900, h: 92,
    title: "Artifact packet",
    body: "runs/research_workbench/g53/feat_full5w_20260709a",
    accent: COLORS.violet,
  });

  slide = newSlide(presentation, 19);
  addTitle(
    slide,
    "REALITY CHECK",
    "The feature signal did not generalize into benchmark-relative alpha",
    "Across 120 portfolio rows, every feature/policy/basket aggregate lagged the equal-weight basket hold."
  );
  await addImage(slide, FULL_HEATMAP, {
    left: 78, top: 282, width: 1120, height: 340,
  }, "Five-window full-symbol Gen5.3 alpha heatmap");

  slide = newSlide(presentation, 20);
  addTitle(
    slide,
    "WHAT CHANGED",
    "The new features changed behavior, but not enough to beat the benchmark",
    "The expanded screen is useful because it separates a promising local smoke result from a robust default."
  );
  addCard(slide, {
    x: 64, y: 228, w: 360, h: 166,
    title: "Best high-beta aggregate",
    body: "Control plus pooled-family was least bad: mean alpha -6.7 pp, 40% positive-alpha windows, 36% average exposure.",
    accent: COLORS.blue,
  });
  addCard(slide, {
    x: 460, y: 228, w: 360, h: 166,
    title: "Best defensive aggregate",
    body: "Trend-volatility plus direct-spec was least bad: mean alpha -3.6 pp, but no positive-alpha windows across the five-window panel.",
    accent: COLORS.green,
  });
  addCard(slide, {
    x: 856, y: 228, w: 360, h: 166,
    title: "Best commodity aggregate",
    body: "Relative trend-volatility plus pooled-family was least bad: mean alpha -3.9 pp, 40% positive-alpha windows.",
    accent: COLORS.amber,
  });
  addCard(slide, {
    x: 114, y: 454, w: 1010, h: 106,
    title: "Policy readout",
    body: "Pooled-family again looked more robust than direct-spec by trading less: -6.6 pp mean alpha versus -7.6 pp, with lower exposure and fewer entries.",
    accent: COLORS.violet,
  });

  slide = newSlide(presentation, 21);
  addTitle(
    slide,
    "PARTICIPATION PROBLEM",
    "The benchmark gap is largest when buy-and-hold had a strong quarter",
    "The system can avoid some downside, but it still tends to undercapture strong basket upside."
  );
  await addImage(slide, FULL_ALPHA_BAR, {
    left: 78, top: 282, width: 1120, height: 340,
  }, "Five-window full-symbol Gen5.3 alpha bar chart");

  slide = newSlide(presentation, 22);
  addTitle(
    slide,
    "EXPOSURE AUDIT",
    "More exposure alone did not solve the alpha problem",
    "The scatter helps separate undertrading from poor state/action choice at comparable exposure."
  );
  await addImage(slide, FULL_SCATTER, {
    left: 92, top: 286, width: 1096, height: 318,
  }, "Five-window exposure versus alpha scatter");

  slide = newSlide(presentation, 23);
  addTitle(
    slide,
    "UPDATED INTERPRETATION",
    "Gen5.3 should shift from feature promotion to failure-mode diagnosis",
    "The screen did its job: it protected us from canonizing a feature set based on one favorable smoke window."
  );
  addCard(slide, {
    x: 74, y: 236, w: 520, h: 132,
    title: "Do not promote a new default yet",
    body: "The current control feature set remains the top aggregate across all baskets/windows. New trend and volatility features remain research candidates, not defaults.",
    accent: COLORS.rose,
  });
  addCard(slide, {
    x: 634, y: 236, w: 520, h: 132,
    title: "Keep pooled-family alive",
    body: "It remains less brittle than direct-spec in this broader screen, but it still does not clear the benchmark alpha bar.",
    accent: COLORS.green,
  });
  addCard(slide, {
    x: 74, y: 414, w: 520, h: 132,
    title: "Next narrow slice",
    body: "Audit state/action gating during strong benchmark quarters: which states are flat, which families are chosen, and why continuation misses upside.",
    accent: COLORS.blue,
  });
  addCard(slide, {
    x: 634, y: 414, w: 520, h: 132,
    title: "Research direction",
    body: "Treat PCA feature work as alive, but pair it with action-quality diagnostics before adding more feature families or a new regime model.",
    accent: COLORS.violet,
  });

  slide = newSlide(presentation, 24);
  addTitle(
    slide,
    "PERFORMANCE AUDIT",
    "Representative trade tapes turn the aggregate result into behavior",
    null
  );
  await addImage(slide, AUDIT_TAPES, {
    left: 72, top: 214, width: 1136, height: 430,
  }, "Representative Gen5.3 feature trade tapes with state bands and actions");

  slide = newSlide(presentation, 25);
  addTitle(
    slide,
    "STATE QUALITY",
    "Some feature sets separated future behavior better than the alpha read implies",
    "This is not allocation evidence; it asks whether PCA states formed meaningfully different forward-return buckets before judging the action layer."
  );
  await addImage(slide, AUDIT_STATE, {
    left: 78, top: 262, width: 730, height: 340,
  }, "Gen5.3 state discrimination diagnostics");
  addCard(slide, {
    x: 842, y: 280, w: 330, h: 148,
    title: "Best separation signal",
    body: "High-beta trend-participation had the widest state next-return spread and hit-rate spread, with lower switching than the control.",
    accent: COLORS.blue,
  });
  addCard(slide, {
    x: 842, y: 462, w: 330, h: 118,
    title: "Interpretation",
    body: "A feature set can contain regime information even when the current action policy underuses it.",
    accent: COLORS.green,
  });

  slide = newSlide(presentation, 26);
  addTitle(
    slide,
    "ACTION QUALITY",
    "The weaker link often looked like exposure alignment, not state separation",
    "The chart compares whether states with better next-day behavior actually received more long exposure."
  );
  await addImage(slide, AUDIT_ALIGNMENT, {
    left: 74, top: 262, width: 744, height: 336,
  }, "Gen5.3 state/action alignment diagnostics");
  addCard(slide, {
    x: 850, y: 268, w: 330, h: 126,
    title: "Mixed alignment",
    body: "A few lanes had positive state-return versus long-rate alignment, but many were negative or flat.",
    accent: COLORS.amber,
  });
  addCard(slide, {
    x: 850, y: 426, w: 330, h: 126,
    title: "Practical meaning",
    body: "The next narrow test should improve action gating before simply adding more PCA features.",
    accent: COLORS.violet,
  });

  slide = newSlide(presentation, 27);
  addTitle(
    slide,
    "AUTHORITY MIX",
    "Selected families reveal whether the engine is trading or abstaining",
    "This heatmap is a sanity check for no-trade dominance, trend-family concentration, and whether direct versus pooled policy changes the selected action vocabulary."
  );
  await addImage(slide, AUDIT_FAMILY, {
    left: 72, top: 246, width: 1136, height: 370,
  }, "Gen5.3 selected strategy family mix heatmap");

  slide = newSlide(presentation, 28);
  addTitle(
    slide,
    "AUDIT READOUT",
    "The features are not dead, but promotion would be premature",
    "The right next step is a narrower state/action-gating probe, not a broader feature search."
  );
  addCard(slide, {
    x: 74, y: 304, w: 520, h: 124,
    title: "What survived",
    body: "Trend-participation features showed useful state discrimination in high-beta baskets. Volatility/relative features may still help avoidance or commodity pockets.",
    accent: COLORS.green,
  });
  addCard(slide, {
    x: 634, y: 304, w: 520, h: 124,
    title: "What failed",
    body: "Benchmark-relative alpha did not generalize. The action layer often stayed flat in favorable states or traded in weaker states.",
    accent: COLORS.rose,
  });
  addCard(slide, {
    x: 74, y: 452, w: 520, h: 150,
    title: "Diagnostic to keep",
    body: "Track state return spread, hit-rate spread, state/action alignment, no-trade in good states, and long-rate in bad states alongside performance.",
    accent: COLORS.blue,
  });
  addCard(slide, {
    x: 634, y: 452, w: 520, h: 150,
    title: "Next slice",
    body: "Pick strong benchmark quarters and test whether action gating can increase upside participation without destroying the downside-avoidance pockets.",
    accent: COLORS.violet,
  });

  return presentation;
}

async function main() {
  await fs.mkdir(OUT_DIR, { recursive: true });
  await fs.mkdir(RENDER_DIR, { recursive: true });

  const presentation = await buildDeck();

  for (const [index, slide] of presentation.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    await writeBlob(
      path.join(RENDER_DIR, `${stem}.png`),
      await presentation.export({ slide, format: "png", scale: 1.4 })
    );
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(RENDER_DIR, `${stem}.layout.json`), await layout.text());
  }

  await writeBlob(
    MONTAGE_PATH,
    await presentation.export({ format: "webp", montage: true, scale: 1 })
  );

  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(DECK_PATH);

  const inspect = await presentation.inspect({
    kind: "slide,textbox,shape,chart,table,image,notes,layout",
    maxChars: 60000,
  });
  await fs.writeFile(INSPECT_PATH, inspect.ndjson);

  console.log(`Wrote ${DECK_PATH}`);
  console.log(`Wrote ${MONTAGE_PATH}`);
  console.log(`Wrote ${INSPECT_PATH}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
