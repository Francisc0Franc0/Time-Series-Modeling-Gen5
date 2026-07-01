import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const defaultArtifactModule =
  "C:/Users/Franc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";
const artifactModule = process.env.ARTIFACT_TOOL_MODULE || defaultArtifactModule;
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactModule).href);

const outDir = path.join(repoRoot, "outputs");
const summaryDir = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "context_universe_factorial_temporal_summaries",
  "ctxfac_temporal_context_replication_20241231_20260623"
);
const rankCsv = path.join(summaryDir, "temporal_context_replication_rank_summary.csv");
const metricsPng = path.join(summaryDir, "temporal_context_replication_metrics.png");
const coverageCsv = path.join(repoRoot, "runs", "data_refresh", "alpaca_daily_symbol_coverage_20260623.csv");
const finalPptx = path.join(outDir, "gen5_temporal_context_replication_summary_sip_refresh.pptx");
const inspectPath = path.join(outDir, "gen5_temporal_context_replication_summary_sip_refresh.pptx.inspect.ndjson");
const montagePath = path.join(outDir, "gen5_temporal_context_replication_summary_sip_refresh_montage.webp");
const slidePreviewDir = path.join(outDir, "gen5_temporal_context_replication_summary_sip_refresh_slides");

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
  return rows.filter((r) => r.length === header.length).map((r) => Object.fromEntries(header.map((h, idx) => [h, r[idx]])));
}

function pct(value, digits = 0) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "";
  return `${(n * 100).toFixed(digits)}%`;
}

function num(value, digits = 2) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "";
  return n.toFixed(digits);
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
    alignment: style.alignment || "left",
  };
  return shape;
}

function addTitle(slide, title, kicker = "Gen5.1 research inspection") {
  addText(slide, kicker.toUpperCase(), 72, 48, 780, 28, {
    fontSize: 14,
    color: "slate-500",
    bold: true,
  });
  addText(slide, title, 72, 86, 1040, 86, {
    fontSize: 38,
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

function addBulletList(slide, items, left, top, width, fontSize = 22, gap = 48) {
  items.forEach((item, idx) => {
    addText(slide, "•", left, top + idx * gap + 2, 24, 26, {
      fontSize,
      color: "teal-700",
      bold: true,
    });
    addText(slide, item, left + 32, top + idx * gap, width - 32, 42, {
      fontSize,
      color: "slate-800",
    });
  });
}

function addMetricCard(slide, label, value, note, left, top, width) {
  slide.shapes.add({
    geometry: "roundRect",
    position: { left, top, width, height: 118 },
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
    fontSize: 28,
    color: "slate-950",
    bold: true,
  });
  addText(slide, note, left + 20, top + 82, width - 40, 26, {
    fontSize: 15,
    color: "slate-600",
  });
}

function addSimpleTable(slide, columns, rows, left, top, widths, rowHeight = 36) {
  const totalWidth = widths.reduce((a, b) => a + b, 0);
  slide.shapes.add({
    geometry: "rect",
    position: { left, top, width: totalWidth, height: rowHeight },
    fill: "slate-100",
    line: { style: "solid", fill: "slate-200", width: 1 },
  });
  let x = left;
  columns.forEach((col, idx) => {
    addText(slide, col, x + 8, top + 8, widths[idx] - 16, 20, {
      fontSize: 13,
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
      addText(slide, String(cell), x + 8, y + 8, widths[cidx] - 16, 20, {
        fontSize: 13,
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

const ranks = parseCsv(await fs.readFile(rankCsv, "utf8"));
const coverage = parseCsv(await fs.readFile(coverageCsv, "utf8"));
const byRank = [...ranks].sort((a, b) => Number(a.mean_return_rank) - Number(b.mean_return_rank));
const leadQuantile = ranks.find(
  (r) => r.universe_id === "active_plus_risk_context" && r.surface_id === "behavioral_pool_quantile_grid_3x3"
);
const leadK9 = ranks.find(
  (r) => r.universe_id === "active_plus_risk_context" && r.surface_id === "behavioral_pool_kmeans_k9"
);
const activeCoverage = coverage.filter((r) => ["AMD", "NVDA", "TSLA", "AAPL", "MSTR"].includes(r.symbol));
const contextCoverage = coverage.filter((r) => ["SPY", "QQQ", "IWM", "SMH", "TLT", "GLD", "VXX"].includes(r.symbol));

await fs.mkdir(outDir, { recursive: true });
await fs.mkdir(slidePreviewDir, { recursive: true });
const presentation = Presentation.create({ slideSize: { width: 1280, height: 720 } });

{
  const slide = presentation.slides.add();
  slide.background.fill = "slate-50";
  addText(slide, "Gen5.1 Temporal Context Replication", 72, 104, 1040, 76, {
    fontSize: 44,
    color: "slate-950",
    bold: true,
  });
  addText(slide, "Updated after confirming Alpaca SIP restores 2016-era adjusted daily coverage for the research basket.", 72, 196, 880, 70, {
    fontSize: 24,
    color: "slate-700",
  });
  addMetricCard(slide, "Completed evidence", "7 windows", "Late 2024 through mid 2026", 72, 338, 300);
  addMetricCard(slide, "New data proof", "2016-01-04", "Earliest common active/risk date except VXX", 406, 338, 360);
  addMetricCard(slide, "Research boundary", "Inspection only", "No allocation approval from performance", 800, 338, 340);
  addText(slide, "The earlier broad rerun was stopped because compute, not data availability, became the limiting factor.", 72, 520, 1060, 48, {
    fontSize: 20,
    color: "slate-600",
  });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "The data blocker was IEX history, not the research wrapper");
  addRule(slide);
  addBulletList(
    slide,
    [
      "Gen4 auto-selected SIP when entitlement checks passed; Gen5 had been falling back to IEX unless explicitly overridden.",
      "The default Gen5 research feed is now SIP while still honoring ALPACA_DATA_FEED overrides.",
      "A live SIP refresh filled 2016-2020 cache history for the proposed active/context set.",
      "VXX remains the one structural exception, beginning on 2018-01-18 in the refreshed cache.",
    ],
    84,
    230,
    980,
    22,
    62
  );
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "The proposed AAPL basket now has usable 2016 coverage");
  addRule(slide);
  addSimpleTable(
    slide,
    ["Symbol", "Rows", "First session", "Latest session", "Refresh"],
    activeCoverage.map((r) => [r.symbol, r.row_count, r.observed_first_session, r.observed_latest_session, r.refresh_decision]),
    92,
    225,
    [120, 120, 190, 190, 180],
    42
  );
  addText(slide, "AAPL is the practical COIN/META replacement for true 2016-capable tests. META is not usable as-is before its FB ticker period, and COIN is too recent.", 92, 500, 980, 58, {
    fontSize: 20,
    color: "slate-700",
  });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "Completed windows still favor active-plus-risk context");
  addRule(slide);
  await addImage(slide, metricsPng, 36, 188, 1208, 478, "Temporal context replication metrics chart", "cover");
  addText(slide, "Completed seven-window packet; research inspection evidence only, not accepted allocation evidence.", 92, 672, 1000, 28, {
    fontSize: 16,
    color: "slate-500",
  });
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "3x3 is cleaner; k9 is stronger but less stable");
  addRule(slide);
  addMetricCard(slide, "Active-plus-risk 3x3", pct(leadQuantile.mean_total_return, 1), `Mean Sharpe ${num(leadQuantile.mean_sharpe)}; zero negative windows`, 84, 236, 480);
  addMetricCard(slide, "Active-plus-risk k9", pct(leadK9.mean_total_return, 1), `Mean Sharpe ${num(leadK9.mean_sharpe)}; two negative windows`, 620, 236, 480);
  addSimpleTable(
    slide,
    ["Condition", "Mean return", "Worst drawdown", "Neg windows"],
    byRank.slice(0, 4).map((r) => [
      `${r.universe_id.replace(/_context$/, "").replaceAll("_", " ")} / ${r.surface_id.replace("behavioral_pool_", "").replaceAll("_", " ")}`,
      pct(r.mean_total_return, 1),
      pct(r.worst_max_drawdown, 1),
      r.negative_return_count,
    ]),
    84,
    402,
    [520, 150, 160, 120],
    40
  );
}

{
  const slide = presentation.slides.add();
  slide.background.fill = "white";
  addTitle(slide, "The next run should be an overnight batch, not an inline chat rerun");
  addRule(slide);
  addBulletList(
    slide,
    [
      "Use active set AMD,NVDA,TSLA,AAPL,MSTR so the test can reach the older SIP history.",
      "Keep the same three context universes, but treat VXX as unavailable for true 2016-start windows unless you approve a replacement.",
      "Run adjacent windows around 2021 and 2022 first; add earlier windows only after resolving the VXX context choice.",
      "After the overnight batch completes, rebuild this deck with the expanded summary and then decide whether 3x3 remains the default state map.",
    ],
    84,
    226,
    1000,
    21,
    66
  );
  addText(slide, "STOP decision for you: whether to replace VXX for pre-2018 context tests, omit it from those windows, or accept 2018+ as the earliest fully comparable context universe.", 84, 606, 1040, 44, {
    fontSize: 20,
    color: "slate-700",
    bold: true,
  });
}

const montage = await presentation.export({ format: "webp", montage: true, scale: 1 });
await fs.writeFile(montagePath, new Uint8Array(await montage.arrayBuffer()));
for (const [index, slide] of presentation.slides.items.entries()) {
  const preview = await presentation.export({ slide, format: "png", scale: 1 });
  const slidePath = path.join(slidePreviewDir, `slide-${String(index + 1).padStart(2, "0")}.png`);
  await fs.writeFile(slidePath, new Uint8Array(await preview.arrayBuffer()));
}
const inspect = await presentation.inspect({ kind: "slide,textbox,shape,image,chart,table,layout", maxChars: 24000 });
await fs.writeFile(inspectPath, inspect.ndjson);
const pptx = await PresentationFile.exportPptx(presentation);
await pptx.save(finalPptx);

console.log(`Wrote ${finalPptx}`);
console.log(`Wrote ${inspectPath}`);
console.log(`Wrote ${montagePath}`);
console.log(`Wrote slide previews to ${slidePreviewDir}`);
