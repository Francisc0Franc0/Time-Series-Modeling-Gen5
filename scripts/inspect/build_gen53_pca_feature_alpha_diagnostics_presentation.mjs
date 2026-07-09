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

function newSlide(presentation, index) {
  const slide = presentation.slides.add();
  slide.background.fill = COLORS.bg;
  addFooter(slide, index);
  return slide;
}

function buildDeck() {
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

  return presentation;
}

async function main() {
  await fs.mkdir(OUT_DIR, { recursive: true });
  await fs.mkdir(RENDER_DIR, { recursive: true });

  const presentation = buildDeck();

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
