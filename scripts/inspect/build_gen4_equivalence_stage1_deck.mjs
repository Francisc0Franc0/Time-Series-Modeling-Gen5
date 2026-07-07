import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const artifactModule =
  process.env.ARTIFACT_TOOL_MODULE ||
  "C:/Users/Franc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactModule).href);

const runRoot =
  process.env.GEN5_GEN4_EQ_RUN_ROOT ||
  path.join(repoRoot, "runs", "research_workbench", "gen4_equivalence", "gen4_equivalence_20260706stage1c");
const presentationDir = path.join(repoRoot, "presentations");
const outputPath =
  process.env.GEN5_GEN4_EQ_DECK_OUT ||
  path.join(presentationDir, "gen5_gen4_equivalence_stage1.pptx");
const previewDir =
  process.env.GEN5_GEN4_EQ_DECK_PREVIEW ||
  path.join(presentationDir, "gen5_gen4_equivalence_stage1_slides");
const montagePath =
  process.env.GEN5_GEN4_EQ_DECK_MONTAGE ||
  path.join(presentationDir, "gen5_gen4_equivalence_stage1_montage.webp");

const files = {
  runSpec: path.join(runRoot, "gen4_equivalence_run_spec.csv"),
  comparison: path.join(runRoot, "gen4_equivalence_comparison_summary.csv"),
  quarter: path.join(runRoot, "gen4_equivalence_quarter_summary.csv"),
  gen5Family: path.join(runRoot, "gen4_equivalence_gen5_family_summary.csv"),
  gen4Family: path.join(runRoot, "gen4_equivalence_gen4_family_summary.csv"),
  health: path.join(runRoot, "query", "gen4_equivalence_query_health.csv"),
  equityOverlay: path.join(runRoot, "gen4_equivalence_equity_overlay.png"),
  alphaScorecard: path.join(runRoot, "gen4_equivalence_alpha_scorecard.png"),
  quarterHeatmap: path.join(runRoot, "gen4_equivalence_quarter_alpha_heatmap.png"),
  familyMix: path.join(runRoot, "gen4_equivalence_family_mix.png"),
};

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

function num(value) {
  const out = Number(value);
  return Number.isFinite(out) ? out : 0;
}

function pct(value, digits = 1) {
  return `${(num(value) * 100).toFixed(digits)}%`;
}

function pp(value, digits = 1) {
  return `${(num(value) * 100).toFixed(digits)} pp`;
}

function policyLabel(policy) {
  return policy === "asset_state_direct_spec" ? "Direct-spec" : "Pooled-family";
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
  addText(slide, title, 72, 78, 1080, 86, { fontSize: 35, color: "slate-950", bold: true });
  slide.shapes.add({
    geometry: "rect",
    position: { left: 72, top: 174, width: 1136, height: 2 },
    fill: "slate-200",
    line: { style: "solid", fill: "none", width: 0 },
  });
}

function addFooter(slide, page) {
  addText(slide, "Research inspection only. Not allocation evidence.", 72, 682, 640, 24, {
    fontSize: 12,
    color: "slate-500",
  });
  addText(slide, String(page).padStart(2, "0"), 1138, 682, 70, 24, {
    fontSize: 12,
    color: "slate-500",
    alignment: "right",
  });
}

function addBullet(slide, text, left, top, width, fontSize = 19) {
  addText(slide, "-", left, top, 20, 28, { fontSize, color: "teal-700", bold: true });
  addText(slide, text, left + 28, top, width - 28, 54, { fontSize, color: "slate-800" });
}

function addMetricCard(slide, label, value, note, left, top, width, height = 116) {
  slide.shapes.add({
    geometry: "roundRect",
    position: { left, top, width, height },
    fill: "white",
    line: { style: "solid", fill: "slate-200", width: 1 },
    borderRadius: "rounded-lg",
  });
  addText(slide, label.toUpperCase(), left + 18, top + 15, width - 36, 18, {
    fontSize: 11,
    color: "slate-500",
    bold: true,
  });
  addText(slide, value, left + 18, top + 38, width - 36, 34, {
    fontSize: 26,
    color: "slate-950",
    bold: true,
  });
  addText(slide, note, left + 18, top + 77, width - 36, height - 82, {
    fontSize: 14,
    color: "slate-600",
  });
}

function addSimpleTable(slide, columns, rows, left, top, widths, rowHeight = 42, fontSize = 13) {
  const totalWidth = widths.reduce((a, b) => a + b, 0);
  slide.shapes.add({
    geometry: "rect",
    position: { left, top, width: totalWidth, height: rowHeight },
    fill: "slate-100",
    line: { style: "solid", fill: "slate-200", width: 1 },
  });
  let x = left;
  columns.forEach((col, idx) => {
    addText(slide, col, x + 8, top + 10, widths[idx] - 16, 20, {
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
      addText(slide, String(cell), x + 8, y + 9, widths[cidx] - 16, rowHeight - 14, {
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

async function main() {
  const [runSpecRows, comparison, quarter, gen5Family, gen4Family, health] = await Promise.all([
    readCsv(files.runSpec),
    readCsv(files.comparison),
    readCsv(files.quarter),
    readCsv(files.gen5Family),
    readCsv(files.gen4Family),
    readCsv(files.health),
  ]);
  const runSpec = runSpecRows[0];
  const symbolCount = (runSpec.symbols || "").split(",").filter(Boolean).length;
  const quarterCount = (runSpec.replay_quarters || "").split(",").filter(Boolean).length;
  const isFullSymbol = symbolCount >= 16;
  const headlineGroup = comparison.some((r) => r.source === "Gen5.1 replay" && r.group_id === "live_all") ? "live_all" : "cluster_3";
  const deckTitle = isFullSymbol ? "Gen4 Equivalence Full 16-Symbol Screen" : "Gen4 Equivalence Stage 1";
  const headlineScope = isFullSymbol ? "Full Gen4 live/reporting universe" : "High-beta stage-1 slice";
  const gen5Rows = comparison.filter((r) => r.source === "Gen5.1 replay" && r.group_id === headlineGroup);
  const direct = gen5Rows.find((r) => r.selection_policy === "asset_state_direct_spec");
  const pooled = gen5Rows.find((r) => r.selection_policy === "pooled_family_asset_variant");
  const gen4Cluster3 = comparison.find((r) => r.source === "Gen4 artifact" && r.group_id === "cluster_3");
  const gen4Cluster1 = comparison.find((r) => r.source === "Gen4 artifact" && r.group_id === "cluster_1");
  const warnRows = health.filter((r) => r.severity === "WARN");
  const quarterRows = quarter.filter((r) => r.group_id === headlineGroup);
  const directQuarter = quarterRows.filter((r) => r.selection_policy === "asset_state_direct_spec");
  const pooledQuarter = quarterRows.filter((r) => r.selection_policy === "pooled_family_asset_variant");

  const presentation = await Presentation.create({ title: `Gen5.1 ${deckTitle}` });
  presentation.layout = "LAYOUT_WIDE";

  {
    const slide = presentation.slides.add();
    slide.background.fill = "white";
    addText(slide, "GEN5.1", 72, 54, 200, 28, { fontSize: 16, color: "teal-700", bold: true });
    addText(slide, deckTitle, 72, 108, 1000, 74, {
      fontSize: 44,
      color: "slate-950",
      bold: true,
    });
    addText(
      slide,
      "A forensic experiment to separate real Gen4 design differences from memory, benchmark definitions, and setup mismatch.",
      72,
      198,
      970,
      78,
      { fontSize: 24, color: "slate-700" },
    );
    addMetricCard(slide, "Symbols", `${symbolCount} symbols`, headlineScope, 72, 332, 320);
    addMetricCard(slide, "Windows", runSpec.replay_quarters, `${quarterCount} OOS quarters`, 424, 332, 360);
    addMetricCard(slide, "Grid", `${runSpec.model_grid_rows} rows`, "Gen4-picked supported specs", 816, 332, 320);
    addText(slide, isFullSymbol
      ? "This deck reports the full 16-symbol Gen5.1 replay for quarters where every live/reporting symbol can support the expanding TRAIN setup."
      : "The full Gen4 artifact remains the reference, but this deck reports a deliberately staged Gen5.1 replay, not the exhaustive all-symbol/all-quarter run.", 72, 500, 1030, 60, {
      fontSize: 20,
      color: "slate-700",
    });
    addFooter(slide, 1);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = "white";
    addTitle(slide, "Why we ran this");
    addBullet(slide, "Recent Gen5.1 screens often produced positive tactical returns but still lagged equal-weight hold.", 92, 216, 1040);
    addBullet(slide, "Your memory of Gen4 was that an analogous long-PCA, pooled-family design beat benchmarks more decisively.", 92, 292, 1040);
    addBullet(slide, "The question became: was Gen4 genuinely doing something better, or were we comparing unlike windows, universes, grids, and reporting surfaces?", 92, 368, 1040);
    addBullet(slide, isFullSymbol
      ? "This screen expands the staged replay to the full Gen4 live/reporting symbol breadth while keeping the same leakage-safe mechanics."
      : "This stage recreates the closest implemented Gen5.1 analogue first, then names remaining gaps before spending compute on a larger screen.", 92, 466, 1040);
    addFooter(slide, 2);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = "white";
    addTitle(slide, "What this screen matched, and what it did not");
    addSimpleTable(
      slide,
      ["Dimension", "Screen choice", "Why it matters"],
      [
        ["Context", "Gen4 RESEARCH_ASSETS analogue", "Tests the broad Gen4-like PCA context."],
        ["PCA/state", "Long pooled PCA + 4x4 quantile grid", "Matches the conceptual Gen4 surface."],
        ["Selection", "Direct-spec and pooled-family", "Compares current Gen5.1 against Gen4-style selection."],
        ["Grid", `${runSpec.model_grid_rows} Gen4-picked supported specs`, "Avoids full unused-grid compute while preserving picked RSI/z-ret specs."],
        ["Scope", `${symbolCount} symbols; ${runSpec.replay_quarters}`, isFullSymbol ? "Full symbol breadth, later feasible windows." : "A staged high-beta slice, not the whole Gen4 packet."],
      ],
      72,
      210,
      [170, 360, 560],
      58,
      13,
    );
    addText(slide, "Known gaps: SMA families are still absent from Gen5.1, and this is Phase40-style quarterly replay rather than live-bridge continuity.", 92, 590, 1010, 48, {
      fontSize: 18,
      color: "slate-700",
    });
    addFooter(slide, 3);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = "white";
    addTitle(slide, isFullSymbol ? "Full-symbol replay beat benchmark most clearly under direct-spec" : "Stage 1 beat its internal benchmark, especially direct-spec");
    addMetricCard(slide, "Direct-spec return", pct(direct.strategy_return), `${pp(direct.alpha_vs_benchmark)} vs benchmark`, 74, 210, 310);
    addMetricCard(slide, "Pooled-family return", pct(pooled.strategy_return), `${pp(pooled.alpha_vs_benchmark)} vs benchmark`, 414, 210, 310);
    addMetricCard(slide, "Equal-weight hold", pct(direct.benchmark_return), `Same ${headlineGroup} slice`, 754, 210, 310);
    await addImage(slide, files.alphaScorecard, 80, 360, 1040, 250, "Benchmark-relative alpha scorecard");
    addText(slide, isFullSymbol
      ? "Interpretation: expanding to the full feasible symbol set did not erase the tactical edge versus local hold. Direct-spec remained the stronger Gen5.1 policy in this packet."
      : "Interpretation: the staged Gen5.1 lane is not failing catastrophically. But direct-spec was stronger than pooled-family in this slice, which keeps the selection-policy question alive.", 86, 624, 1040, 44, {
      fontSize: 17,
      color: "slate-700",
    });
    addFooter(slide, 4);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = "white";
    addTitle(slide, "Window-level behavior is the useful audit layer");
    await addImage(slide, files.quarterHeatmap, 68, 202, 1120, 300, "Quarterly alpha heatmap");
    addSimpleTable(
      slide,
      ["Quarter", "Direct alpha", "Pooled alpha"],
      directQuarter.map((row) => {
        const pooledRow = pooledQuarter.find((r) => r.quarter_id === row.quarter_id);
        return [row.quarter_id, pp(row.alpha_vs_benchmark), pooledRow ? pp(pooledRow.alpha_vs_benchmark) : ""];
      }),
      104,
      526,
      [150, 170, 170],
      36,
      12,
    );
    addText(slide, isFullSymbol
      ? "The important pattern is not just total return. In 2022Q2 both policies protected capital versus local hold; in 2024Q4 both lagged the upside move."
      : "The important pattern is not just total return. The stage included a bullish quarter, a drawdown quarter, and a recent high-beta quarter, and the policies behaved differently across them.", 690, 526, 450, 100, {
      fontSize: 17,
      color: "slate-700",
    });
    addFooter(slide, 5);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = "white";
    addTitle(slide, "The family mix changed under Gen5.1 selection");
    await addImage(slide, files.familyMix, 72, 204, 760, 350, "Strategy family mix comparison");
    addSimpleTable(
      slide,
      ["Gen4 family", "Count"],
      gen4Family
        .sort((a, b) => num(b.count) - num(a.count))
        .slice(0, 6)
        .map((r) => [r.family, r.count]),
      870,
      220,
      [190, 90],
      38,
      12,
    );
    addText(slide, "Because this screen reconstructs picked Gen4 specs but lets Gen5.1 reselect by state and asset, family mix is evidence about selection behavior, not just parameter availability.", 864, 504, 310, 88, {
      fontSize: 17,
      color: "slate-700",
    });
    addFooter(slide, 6);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = "white";
    addTitle(slide, isFullSymbol ? "Do not overcompare this feasible slice to the full Gen4 artifact" : "Do not overcompare the staged run to the full Gen4 artifact");
    addMetricCard(slide, "Gen4 cluster 3", pct(gen4Cluster3.strategy_return), `${pp(gen4Cluster3.alpha_vs_benchmark)} vs its benchmark`, 76, 216, 330);
    addMetricCard(slide, "Gen4 cluster 1", pct(gen4Cluster1.strategy_return), `${pp(gen4Cluster1.alpha_vs_benchmark)} vs its benchmark`, 442, 216, 330);
    addMetricCard(slide, isFullSymbol ? "Full-symbol direct" : "Stage-1 direct", pct(direct.strategy_return), `${pp(direct.alpha_vs_benchmark)} in this Gen5.1 slice`, 808, 216, 330);
    await addImage(slide, files.equityOverlay, 86, 370, 1010, 230, "Gen4 artifact versus Gen5 equity overlay");
    addText(slide, isFullSymbol
      ? "The Gen4 artifact still spans more historical quarters and includes SMA/volatility semantics that Gen5.1 does not fully implement. This full-symbol slice narrows the setup gap, but it does not reproduce the entire Gen4 packet."
      : "The Gen4 artifact spans a fuller universe and more quarters. Stage 1 says the Gen5.1 reconstruction can produce benchmark-relative alpha in selected high-beta windows; it does not yet explain the full Gen4 advantage.", 92, 624, 1040, 44, {
      fontSize: 17,
      color: "slate-700",
    });
    addFooter(slide, 7);
  }

  {
    const slide = presentation.slides.add();
    slide.background.fill = "white";
    addTitle(slide, "Recommended next decision");
    addBullet(slide, isFullSymbol
      ? "Keep this as stronger forensic evidence, not a final equivalence answer: direct-spec beat local hold on the full feasible symbol set, while pooled-family was weaker but still positive versus local hold overall."
      : "Keep this as a staged positive signal, not a final answer: direct-spec was stronger here, but the Gen4-style pooled-family hypothesis is not dead.", 92, 220, 1040);
    addBullet(slide, isFullSymbol
      ? "Next decision: either run more later full-symbol quarters, or implement the remaining Gen4 semantic gaps only if the operator wants a stricter one-to-one reproduction."
      : "Next narrow slice: expand this exact corrected grid to all Gen4 high-beta cluster symbols across a larger annual-quarter ladder before touching SMA or full 16-symbol breadth.", 92, 318, 1040);
    addBullet(slide, isFullSymbol
      ? "The key unresolved question is no longer symbol breadth; it is whether the remaining Gen4-only semantics explain the residual gap to the full artifact."
      : "Only after that should we decide whether SMA families or exact Gen4 volatility-breakout semantics are worth implementing as true equivalence gaps.", 92, 416, 1040);
    addBullet(slide, `Data note: query health includes ${warnRows.length} WARN rows for PLTR/SOFI partial history in the broad context universe; that is expected listing-history behavior and should remain visible in reports.`, 92, 514, 1040);
    addFooter(slide, 8);
  }

  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.mkdir(previewDir, { recursive: true });
  for (const [index, slide] of presentation.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    const png = await presentation.export({ slide, format: "png", scale: 2 });
    await fs.writeFile(path.join(previewDir, `${stem}.png`), Buffer.from(await png.arrayBuffer()));
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(previewDir, `${stem}.layout.json`), await layout.text());
  }
  const montage = await presentation.export({ format: "webp", montage: true, scale: 1 });
  await fs.writeFile(montagePath, Buffer.from(await montage.arrayBuffer()));
  const inspect = await presentation.inspect({ kind: "slide,textbox,shape,image,chart,table,layout", maxChars: 80000 });
  await fs.writeFile(`${outputPath}.inspect.ndjson`, inspect.ndjson);
  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(outputPath);
  console.log(outputPath);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
