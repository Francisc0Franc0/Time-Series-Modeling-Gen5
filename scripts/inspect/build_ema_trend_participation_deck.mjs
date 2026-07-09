import fs from "node:fs/promises";
import path from "node:path";
import { Presentation, PresentationFile } from "@oai/artifact-tool";

const repoRoot = process.env.GEN5_REPO_ROOT || process.cwd();
const outputPath = process.env.GEN5_EMA_TREND_DECK_OUT ||
  path.join(repoRoot, "presentations", "gen5_ema_trend_participation_probe.pptx");
const previewDir = process.env.GEN5_EMA_TREND_DECK_PREVIEW ||
  path.join(path.dirname(outputPath), "gen5_ema_trend_participation_probe_slides");
const montagePath = process.env.GEN5_EMA_TREND_DECK_MONTAGE ||
  path.join(path.dirname(outputPath), "gen5_ema_trend_participation_probe_montage.webp");

const comparisonDir = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "selpol_context",
  "selpol_context_e2",
  "ema_trend_participation_comparison",
  "HB_broad_risk_no_vxx",
);

const files = {
  comparison: path.join(comparisonDir, "ema_trend_participation_comparison_summary.csv"),
  portfolio: path.join(comparisonDir, "ema_trend_participation_portfolio_all.csv"),
  exposure: path.join(comparisonDir, "ema_trend_participation_exposure_all.csv"),
  family: path.join(comparisonDir, "ema_trend_participation_family_selection_delta.csv"),
  returnHeatmap: path.join(comparisonDir, "ema_trend_participation_return_delta_heatmap.png"),
  exposureHeatmap: path.join(comparisonDir, "ema_trend_participation_exposure_delta_heatmap.png"),
};

const colors = {
  ink: "#000000",
  muted: "#555555",
  rule: "#B8BCC4",
  panel: "#EDEDED",
  canvas: "#FFFFFF",
  highlight: "#FF6B35",
  teal: "#00A88F",
  red: "#F15A5A",
  slate: "#222222",
};

function parseCsvLine(line) {
  const out = [];
  let value = "";
  let quoted = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (ch === '"' && quoted && line[i + 1] === '"') {
      value += '"';
      i += 1;
    } else if (ch === '"') {
      quoted = !quoted;
    } else if (ch === "," && !quoted) {
      out.push(value);
      value = "";
    } else {
      value += ch;
    }
  }
  out.push(value);
  return out;
}

async function readCsv(file) {
  const raw = await fs.readFile(file, "utf8");
  const lines = raw.trim().split(/\r?\n/).filter(Boolean);
  const header = parseCsvLine(lines[0]);
  return lines.slice(1).map((line) => {
    const vals = parseCsvLine(line);
    const row = {};
    header.forEach((key, i) => {
      row[key] = vals[i] ?? "";
    });
    return row;
  });
}

function num(x) {
  const v = Number(x);
  return Number.isFinite(v) ? v : 0;
}

function mean(values) {
  const xs = values.map(num).filter(Number.isFinite);
  return xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0;
}

function pct(v, digits = 1) {
  return `${(v * 100).toFixed(digits)}%`;
}

function pp(v, digits = 1) {
  return `${(v * 100).toFixed(digits)} pp`;
}

function policyLabel(policy) {
  return policy === "asset_state_direct_spec" ? "Direct-spec" : "Pooled-family";
}

function datasetLabel(dataset) {
  return dataset.includes("probe") ? "Compact EMA" : "Default EMA";
}

function shortWindow(id) {
  return id.replace("_asof_", "\n").replace(/20(\d\d)Q(\d).*/, "'$1 Q$2");
}

function addText(slide, text, pos, style = {}) {
  const shape = slide.shapes.add({
    geometry: "textbox",
    position: pos,
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = text;
  shape.text.style = {
    fontSize: style.fontSize ?? 20,
    bold: style.bold ?? false,
    color: style.color ?? colors.ink,
    alignment: style.alignment ?? "left",
    fontFace: "Helvetica Neue",
  };
  return shape;
}

function addRule(slide, left, top, width) {
  slide.shapes.add({
    geometry: "rect",
    position: { left, top, width, height: 1 },
    fill: colors.rule,
    line: { style: "solid", fill: colors.rule, width: 0 },
  });
}

function addHeader(slide, title, kicker = "GEN5.1 EMA TREND PARTICIPATION PROBE") {
  addText(slide, kicker, { left: 42, top: 36, width: 620, height: 24 }, {
    fontSize: 13,
    bold: true,
    color: colors.muted,
  });
  addText(slide, title, { left: 42, top: 76, width: 1120, height: 94 }, {
    fontSize: 36,
    bold: true,
  });
  addRule(slide, 42, 178, 1196);
}

function addFooter(slide, page) {
  addText(slide, "Research inspection only. Not allocation evidence.", { left: 42, top: 674, width: 620, height: 24 }, {
    fontSize: 13,
    color: colors.muted,
  });
  addText(slide, String(page).padStart(2, "0"), { left: 1160, top: 674, width: 78, height: 24 }, {
    fontSize: 13,
    color: colors.muted,
    alignment: "right",
  });
}

function addMetric(slide, label, value, sub, x, y, w = 250) {
  slide.shapes.add({
    geometry: "rect",
    position: { left: x, top: y, width: w, height: 120 },
    fill: colors.panel,
    line: { style: "solid", fill: colors.panel, width: 0 },
  });
  addText(slide, value, { left: x + 20, top: y + 18, width: w - 40, height: 44 }, {
    fontSize: 32,
    bold: true,
  });
  addText(slide, label, { left: x + 20, top: y + 64, width: w - 40, height: 24 }, {
    fontSize: 16,
    bold: true,
    color: colors.muted,
  });
  addText(slide, sub, { left: x + 20, top: y + 90, width: w - 40, height: 22 }, {
    fontSize: 13,
    color: colors.muted,
  });
}

function addBulletList(slide, items, x, y, w, fontSize = 22, gap = 56) {
  items.forEach((item, idx) => {
    const top = y + idx * gap;
    addText(slide, "•", { left: x, top: top + 2, width: 24, height: 26 }, {
      fontSize,
      bold: true,
      color: colors.highlight,
    });
    addText(slide, item, { left: x + 34, top, width: w - 34, height: gap - 4 }, {
      fontSize,
      color: colors.slate,
    });
  });
}

function addSimpleTable(slide, rows, x, y, widths, rowH = 58) {
  rows.forEach((row, r) => {
    let left = x;
    row.forEach((cell, c) => {
      slide.shapes.add({
        geometry: "rect",
        position: { left, top: y + r * rowH, width: widths[c], height: rowH },
        fill: r === 0 ? colors.panel : colors.canvas,
        line: { style: "solid", fill: colors.rule, width: 1 },
      });
      addText(slide, cell, { left: left + 12, top: y + r * rowH + 10, width: widths[c] - 24, height: rowH - 14 }, {
        fontSize: r === 0 ? 16 : 15,
        bold: r === 0,
        color: r === 0 ? colors.ink : colors.slate,
      });
      left += widths[c];
    });
  });
}

async function addImage(slide, imagePath, pos, alt) {
  const bytes = await fs.readFile(imagePath);
  slide.images.add({
    blob: bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength),
    contentType: "image/png",
    alt,
    fit: "contain",
    position: pos,
  });
}

async function main() {
  const comparison = await readCsv(files.comparison);
  const portfolio = await readCsv(files.portfolio);
  const exposure = await readCsv(files.exposure);
  const family = await readCsv(files.family);

  const byPolicy = ["asset_state_direct_spec", "pooled_family_asset_variant"].map((policy) => {
    const rows = comparison.filter((r) => r.selection_policy === policy);
    const famRows = family.filter((r) => r.selection_policy === policy && r.strategy_family === "ema_trend");
    return {
      policy,
      label: policyLabel(policy),
      returnDelta: mean(rows.map((r) => r.return_delta_probe_minus_baseline)),
      exposureDelta: mean(rows.map((r) => r.exposure_delta_probe_minus_baseline)),
      tradeDelta: mean(rows.map((r) => r.trade_count_delta_probe_minus_baseline)),
      selectedDelta: mean(famRows.map((r) => r.selected_share_delta_probe_minus_baseline)),
    };
  });

  const exposureKey = new Map(
    exposure.map((r) => [`${r.dataset_label}::${r.selection_policy}::${r.window_id}`, num(r.mean_benchmark_return)]),
  );
  const portfolioBench = portfolio.map((r) => {
    const bench = exposureKey.get(`${r.dataset_label}::${r.selection_policy}::${r.window_id}`) ?? 0;
    const strategy = num(r.equal_symbol_mean_compound_trace_return);
    return { ...r, benchmark: bench, excess: strategy - bench, strategy };
  });

  const benchmarkMeans = [];
  for (const dataset of [...new Set(portfolioBench.map((r) => r.dataset_label))]) {
    for (const policy of [...new Set(portfolioBench.map((r) => r.selection_policy))]) {
      const rows = portfolioBench.filter((r) => r.dataset_label === dataset && r.selection_policy === policy);
      if (!rows.length) continue;
      benchmarkMeans.push({
        dataset,
        policy,
        label: `${datasetLabel(dataset)}\n${policyLabel(policy).replace("-spec", "").replace("-family", "")}`,
        strategy: mean(rows.map((r) => r.strategy)),
        benchmark: mean(rows.map((r) => r.benchmark)),
        excess: mean(rows.map((r) => r.excess)),
      });
    }
  }

  const windows = [...new Set(comparison.map((r) => r.window_id))];
  const directDeltas = windows.map((w) => num(comparison.find((r) => r.window_id === w && r.selection_policy === "asset_state_direct_spec")?.return_delta_probe_minus_baseline));
  const pooledDeltas = windows.map((w) => num(comparison.find((r) => r.window_id === w && r.selection_policy === "pooled_family_asset_variant")?.return_delta_probe_minus_baseline));

  const presentation = Presentation.create({ slideSize: { width: 1280, height: 720 } });

  // Slide 1
  {
    const slide = presentation.slides.add();
    slide.background.fill = colors.canvas;
    addText(slide, "EMA trend participation probe", { left: 42, top: 72, width: 940, height: 98 }, {
      fontSize: 58,
      bold: true,
    });
    addText(slide, "A compact troubleshooting deck for the Gen5.1 high-beta broad-risk audit lane", { left: 42, top: 190, width: 760, height: 70 }, {
      fontSize: 24,
      color: colors.muted,
    });
    addRule(slide, 42, 305, 760);
    addText(slide, "Central readout", { left: 42, top: 345, width: 220, height: 30 }, {
      fontSize: 18,
      bold: true,
      color: colors.muted,
    });
    addText(slide, "The compact EMA variants did increase participation and modestly improved average replay results, but they still need a full-family confirmation and benchmark-relative scrutiny.", { left: 42, top: 384, width: 820, height: 128 }, {
      fontSize: 30,
      color: colors.ink,
    });
    addMetric(slide, "Direct mean delta", pp(byPolicy[0].returnDelta), "compact minus default", 904, 184, 292);
    addMetric(slide, "Pooled mean delta", pp(byPolicy[1].returnDelta), "compact minus default", 904, 330, 292);
    addMetric(slide, "Status", "Promising", "not promoted yet", 904, 476, 292);
    addFooter(slide, 1);
  }

  // Slide 2
  {
    const slide = presentation.slides.add();
    slide.background.fill = colors.canvas;
    addHeader(slide, "We tested EMA trend because the bigger audit exposed an upside-participation problem");
    addBulletList(slide, [
      "The recent context/policy screen did not mainly fail through catastrophic trade picking.",
      "In a high-upside window, the model won many trades but stayed flat too often.",
      "That made EMA trend a natural first troubleshooting target: can we enter and carry trends without simply overtrading?",
    ], 64, 198, 700, 24, 82);
    slide.shapes.add({
      geometry: "rect",
      position: { left: 835, top: 206, width: 348, height: 310 },
      fill: colors.panel,
      line: { style: "solid", fill: colors.panel, width: 0 },
    });
    addText(slide, "Prior audit clue", { left: 868, top: 238, width: 280, height: 28 }, {
      fontSize: 18,
      bold: true,
      color: colors.muted,
    });
    addText(slide, "2020Q3 exposure", { left: 868, top: 292, width: 280, height: 30 }, {
      fontSize: 22,
      bold: true,
    });
    addText(slide, "35.5%", { left: 868, top: 334, width: 130, height: 58 }, {
      fontSize: 44,
      bold: true,
      color: colors.highlight,
    });
    addText(slide, "Direct", { left: 1004, top: 350, width: 110, height: 28 }, {
      fontSize: 18,
      color: colors.muted,
    });
    addText(slide, "48.3%", { left: 868, top: 408, width: 130, height: 58 }, {
      fontSize: 44,
      bold: true,
      color: colors.highlight,
    });
    addText(slide, "Pooled", { left: 1004, top: 424, width: 110, height: 28 }, {
      fontSize: 18,
      color: colors.muted,
    });
    addText(slide, "The question became participation quality, not just raw strategy selection.", { left: 868, top: 486, width: 270, height: 56 }, {
      fontSize: 18,
      color: colors.slate,
    });
    addFooter(slide, 2);
  }

  // Slide 3
  {
    const slide = presentation.slides.add();
    slide.background.fill = colors.canvas;
    addHeader(slide, "The compact variant changes entry and exit behavior, not the whole system");
    addSimpleTable(slide, [
      ["Dimension", "Default EMA trend", "Compact participation variant"],
      ["Entry", "Fast EMA above slow EMA plus positive fast-EMA slope over 3 bars.", "Adds earlier entries: fast above slow, or positive slope over 1 bar."],
      ["Exit", "Exit when the full trend condition turns off.", "Adds carry behavior: stay long until fast EMA crosses below slow EMA."],
      ["Grid", "Gen4-style EMA trend default periods.", "Keeps defaults and adds targeted fast/carry pairs such as 3/10, 5/20, 8/20, 10/30."],
      ["Scope", "EMA trend competes only with no-trade in this probe.", "Same EMA/no-trade scope, so the mechanism is isolated before full-family compute."],
    ], 54, 190, [180, 470, 530], 76);
    addText(slide, "This was deliberately not a live-bridge change and not a full-grid promotion.", { left: 72, top: 600, width: 1040, height: 34 }, {
      fontSize: 22,
      bold: true,
      color: colors.muted,
    });
    addFooter(slide, 3);
  }

  // Slide 4
  {
    const slide = presentation.slides.add();
    slide.background.fill = colors.canvas;
    addHeader(slide, "The compact variants increased participation and helped on average");
    slide.charts.add("bar", {
      position: { left: 70, top: 198, width: 560, height: 330 },
      categories: byPolicy.map((r) => r.label),
      series: [
        { name: "Return delta", values: byPolicy.map((r) => r.returnDelta), fill: colors.highlight },
        { name: "Exposure delta", values: byPolicy.map((r) => r.exposureDelta), fill: colors.ink },
      ],
      hasLegend: true,
      legend: { position: "bottom", textStyle: { fill: colors.muted, fontSize: 13 } },
      barOptions: { direction: "column", grouping: "clustered", gapWidth: 70 },
      yAxis: { numberFormatCode: "0.0%", majorGridlines: { style: "solid", fill: "#DDDDDD", width: 1 }, textStyle: { fill: colors.muted, fontSize: 12 } },
      xAxis: { textStyle: { fill: colors.slate, fontSize: 13 } },
      dataLabels: { showValue: true, position: "outEnd", textStyle: { fill: colors.ink, fontSize: 12, bold: true } },
      chartFill: colors.canvas,
      plotAreaFill: colors.canvas,
    });
    addMetric(slide, "EMA selected states", `+${pp(byPolicy[0].selectedDelta)}`, "Direct", 690, 202, 222);
    addMetric(slide, "EMA selected states", `+${pp(byPolicy[1].selectedDelta)}`, "Pooled", 934, 202, 222);
    addMetric(slide, "Trades per window", `+${byPolicy[0].tradeDelta.toFixed(1)}`, "Direct", 690, 354, 222);
    addMetric(slide, "Trades per window", `+${byPolicy[1].tradeDelta.toFixed(1)}`, "Pooled", 934, 354, 222);
    addText(slide, "The probe did what it was designed to do: it made EMA trend a more active competitor and raised exposure.", { left: 690, top: 520, width: 466, height: 56 }, {
      fontSize: 21,
      color: colors.slate,
    });
    addFooter(slide, 4);
  }

  // Slide 5
  {
    const slide = presentation.slides.add();
    slide.background.fill = colors.canvas;
    addHeader(slide, "The average improved, but the window-level pattern stayed mixed");
    slide.charts.add("bar", {
      position: { left: 58, top: 190, width: 570, height: 330 },
      categories: windows.map(shortWindow),
      series: [
        { name: "Direct delta", values: directDeltas, fill: colors.highlight },
        { name: "Pooled delta", values: pooledDeltas, fill: colors.ink },
      ],
      hasLegend: true,
      legend: { position: "bottom", textStyle: { fill: colors.muted, fontSize: 13 } },
      barOptions: { direction: "column", grouping: "clustered", gapWidth: 55 },
      yAxis: { numberFormatCode: "0.0%", majorGridlines: { style: "solid", fill: "#DDDDDD", width: 1 }, textStyle: { fill: colors.muted, fontSize: 12 } },
      xAxis: { textStyle: { fill: colors.slate, fontSize: 11 } },
      dataLabels: { showValue: false },
      chartFill: colors.canvas,
      plotAreaFill: colors.canvas,
    });
    await addImage(slide, files.returnHeatmap, { left: 686, top: 202, width: 470, height: 230 }, "Return delta heatmap for compact EMA trend probe");
    addText(slide, "Positive mean deltas did not mean universal improvement. 2019Q3 worsened for both policies, and pooled-family also worsened in 2020Q3.", { left: 690, top: 468, width: 480, height: 92 }, {
      fontSize: 22,
      color: colors.slate,
    });
    addFooter(slide, 5);
  }

  // Slide 6
  {
    const slide = presentation.slides.add();
    slide.background.fill = colors.canvas;
    addHeader(slide, "The benchmark still dominates the tactical replay");
    slide.charts.add("bar", {
      position: { left: 56, top: 190, width: 690, height: 340 },
      categories: benchmarkMeans.map((r) => r.label),
      series: [
        { name: "Strategy replay", values: benchmarkMeans.map((r) => r.strategy), fill: colors.highlight },
        { name: "Equal-weight hold", values: benchmarkMeans.map((r) => r.benchmark), fill: colors.rule },
        { name: "Excess", values: benchmarkMeans.map((r) => r.excess), fill: colors.ink },
      ],
      hasLegend: true,
      legend: { position: "bottom", textStyle: { fill: colors.muted, fontSize: 12 } },
      barOptions: { direction: "column", grouping: "clustered", gapWidth: 80 },
      yAxis: { numberFormatCode: "0.0%", majorGridlines: { style: "solid", fill: "#DDDDDD", width: 1 }, textStyle: { fill: colors.muted, fontSize: 12 } },
      xAxis: { textStyle: { fill: colors.slate, fontSize: 11 } },
      dataLabels: { showValue: false },
      chartFill: colors.canvas,
      plotAreaFill: colors.canvas,
    });
    const bestExcess = benchmarkMeans.reduce((best, row) => row.excess > best.excess ? row : best, benchmarkMeans[0]);
    addMetric(slide, "Best mean excess", pct(bestExcess.excess), bestExcess.label.replace("\n", " / "), 810, 206, 320);
    addText(slide, "The compact EMA variant is useful as a mechanism probe, but benchmark-relative alpha is still unresolved. The next clean test is to let a pruned compact EMA set compete inside the full strategy family lane.", { left: 810, top: 362, width: 330, height: 136 }, {
      fontSize: 22,
      color: colors.slate,
    });
    addFooter(slide, 6);
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
  const inspect = await presentation.inspect({ kind: "slide,textbox,shape,image,chart,table,layout", maxChars: 60000 });
  await fs.writeFile(`${outputPath}.inspect.ndjson`, inspect.ndjson);
  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(outputPath);
  console.log(outputPath);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
