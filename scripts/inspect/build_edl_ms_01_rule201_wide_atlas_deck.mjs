import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const moduleRoot = process.env.RUNTIME_NODE_MODULES;
if (!moduleRoot) throw new Error("RUNTIME_NODE_MODULES is required.");
const artifactEntrypoint = path.join(
  moduleRoot, "@oai", "artifact-tool", "dist", "artifact_tool.mjs",
);
const { Presentation, PresentationFile } = await import(
  pathToFileURL(artifactEntrypoint).href
);

const repoRoot = process.env.GEN5_REPO_ROOT || process.cwd();
const packetRoot = path.join(
  repoRoot, "runs", "research_workbench", "edge_discovery_lab",
  "edl_ms_01_rule201_wide_atlas_20260830",
);
const deckPath = path.join(
  repoRoot, "edge_discovery_lab", "presentations",
  "edl_ms_01_rule201_wide_atlas.pptx",
);
const qaRoot = process.env.TMP_DIR || path.join(
  repoRoot, "runs", "research_workbench", "edge_discovery_lab",
  "edl_ms_01_rule201_wide_atlas_deck_20260830",
);
const renderRoot = path.join(qaRoot, "rendered");
const visuals = {
  availability: path.join(packetRoot, "visuals", "wide_atlas_event_availability.png"),
  core: path.join(packetRoot, "visuals", "wide_atlas_core_stock_paths.png"),
  weighting: path.join(packetRoot, "visuals", "wide_atlas_weighting_comparison.png"),
  cohorts: path.join(packetRoot, "visuals", "wide_atlas_cohort_horizons.png"),
  concentration: path.join(packetRoot, "visuals", "wide_atlas_triggered_strong_concentration.png"),
};

const sources = {
  report: "Local report: runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_wide_atlas_20260830/report.md",
  spec: "Local frozen run specification: runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_wide_atlas_20260830/run_spec.csv",
  pooled: "Local event-pooled paths: runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_wide_atlas_20260830/pooled_path_summary.csv",
  equal: "Local equal-symbol paths: runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_wide_atlas_20260830/equal_symbol_path_summary.csv",
  counts: "Local enrolled-symbol counts: runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_wide_atlas_20260830/symbol_event_counts.csv",
  coverage: "Local coverage ledger: runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_wide_atlas_20260830/coverage_ledger.csv",
  comparison: "Local pilot-versus-wide comparison: runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_wide_atlas_20260830/pilot_vs_wide_comparison.csv",
};

const C = {
  white: "#FFFFFF", ink: "#000000", muted: "#667386", navy: "#24364B",
  rule: "#B8BCC4", panel: "#EDEDED", blue: "#3D8DFF", paleBlue: "#D0EDFA",
  green: "#14866D", paleGreen: "#E2F1EC", red: "#B44738", paleRed: "#F6E5E1",
  purple: "#6957D5", amber: "#A86B00",
};

function addText(slide, text, position, style = {}) {
  const shape = slide.shapes.add({
    geometry: "textbox", name: style.name,
    position, fill: "none", line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = text;
  shape.text.style = {
    fontFace: "Arial", fontSize: style.fontSize ?? 20,
    bold: style.bold ?? false, color: style.color ?? C.ink,
    alignment: style.alignment ?? "left",
    verticalAlignment: style.verticalAlignment ?? "top",
  };
  return shape;
}

function addRect(slide, position, fill, line = fill, width = 0, name) {
  return slide.shapes.add({
    geometry: "rect", name, position, fill,
    line: { style: "solid", fill: line, width },
  });
}

function addHeader(slide, title, page, subtitle = "") {
  addText(slide, "EDGE DISCOVERY LAB · EDL-MS-01", {
    left: 42, top: 24, width: 450, height: 20,
  }, { fontSize: 14, bold: true, color: C.muted, name: "section-label" });
  addText(slide, title, { left: 42, top: 53, width: 1190, height: 54 }, {
    fontSize: 36, bold: true, color: C.ink, name: "slide-title",
  });
  if (subtitle) {
    addText(slide, subtitle, { left: 44, top: 108, width: 1160, height: 30 }, {
      fontSize: 18, color: C.muted, name: "slide-subtitle",
    });
  }
  addRect(slide, { left: 42, top: 143, width: 1196, height: 2 }, C.rule);
  addText(slide, "Adjusted daily · 2018–2023 TRAIN · descriptive only", {
    left: 42, top: 684, width: 600, height: 18,
  }, { fontSize: 12, color: C.muted, name: "footer-status" });
  addText(slide, String(page).padStart(2, "0"), {
    left: 1160, top: 682, width: 76, height: 18,
  }, { fontSize: 12, color: C.muted, alignment: "right", name: "page-number" });
}

function addNotes(slide, body, sourceList) {
  slide.speakerNotes.textFrame.setText([
    body, "", "[Sources]", ...sourceList.map((x) => `- ${x}`), "[/Sources]",
  ].join("\n"));
  slide.speakerNotes.setVisible(true);
}

function addMetric(slide, value, label, detail, position, accent = C.blue) {
  addRect(slide, position, C.panel, C.panel, 0, `metric-${label}`);
  addRect(slide, { left: position.left, top: position.top, width: 8, height: position.height }, accent);
  addText(slide, value, {
    left: position.left + 24, top: position.top + 16,
    width: position.width - 42, height: 48,
  }, { fontSize: 36, bold: true });
  addText(slide, label, {
    left: position.left + 24, top: position.top + 68,
    width: position.width - 42, height: 24,
  }, { fontSize: 17, bold: true, color: C.navy });
  addText(slide, detail, {
    left: position.left + 24, top: position.top + 97,
    width: position.width - 42, height: 22,
  }, { fontSize: 13, color: C.muted });
}

function addBullet(slide, text, position, accent = C.blue, fontSize = 20) {
  addRect(slide, { left: position.left, top: position.top + 8, width: 9, height: 9 }, accent);
  addText(slide, text, {
    left: position.left + 22, top: position.top,
    width: position.width - 22, height: position.height,
  }, { fontSize, color: C.navy });
}

async function addImage(slide, imagePath, position, alt) {
  const bytes = await fs.readFile(imagePath);
  slide.images.add({
    blob: bytes, contentType: "image/png", alt, fit: "contain", position,
  });
}

async function main() {
  await fs.mkdir(path.dirname(deckPath), { recursive: true });
  await fs.mkdir(renderRoot, { recursive: true });
  await fs.writeFile(
    path.join(qaRoot, "source-notes.txt"), Object.values(sources).join("\n"), "utf8",
  );
  const p = Presentation.create({ slideSize: { width: 1280, height: 720 } });

  // 1 — cover, adapted from the Codex Grid sparse stacked-text cover hierarchy.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addRect(slide, { left: 0, top: 0, width: 22, height: 720 }, C.blue);
    addText(slide, "EDGE DISCOVERY LAB · BREADTH REPLICATION", {
      left: 56, top: 50, width: 640, height: 26,
    }, { fontSize: 16, bold: true, color: C.muted });
    addText(slide, "Rule 201 Reclaim", {
      left: 56, top: 154, width: 810, height: 82,
    }, { fontSize: 62, bold: true, color: C.ink });
    addText(slide, "The pilot hump is cohort-sensitive.", {
      left: 58, top: 264, width: 920, height: 58,
    }, { fontSize: 36, bold: true, color: C.navy });
    addText(slide,
      "The 88-stock balanced core does not reproduce the ten-stock day-five median. Attention stocks carry most of the visible temporary recovery.",
      { left: 58, top: 354, width: 820, height: 96 },
      { fontSize: 24, color: C.navy },
    );
    addRect(slide, { left: 944, top: 142, width: 260, height: 260 }, C.navy);
    addText(slide, "129", { left: 962, top: 187, width: 224, height: 80 }, {
      fontSize: 66, bold: true, color: C.white, alignment: "center",
    });
    addText(slide, "instruments\nenrolled", {
      left: 972, top: 286, width: 204, height: 70,
    }, { fontSize: 22, color: C.paleBlue, alignment: "center" });
    addRect(slide, { left: 58, top: 532, width: 1146, height: 2 }, C.rule);
    addText(slide, "WIDE-ATLAS REPLICATION COMPLETE · NO EDGE CLAIM", {
      left: 58, top: 572, width: 820, height: 28,
    }, { fontSize: 17, bold: true, color: C.red });
    addText(slide, "Post-2023 data remain sealed", {
      left: 930, top: 572, width: 274, height: 28,
    }, { fontSize: 17, bold: true, color: C.muted, alignment: "right" });
    addNotes(slide,
      "This sequel asks whether the ten-stock pilot's visible five-session recovery hump survives a preregistered breadth expansion. The central result is cohort sensitivity, not edge promotion.",
      [sources.report, sources.spec, sources.comparison],
    );
  }

  // 2 — frozen contract and breadth.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "One frozen rule enters four visibly separate cohorts", 2,
      "Definitions are inherited from the pilot; only representation changes.");
    addMetric(slide, "88", "core stocks", "8 per GICS sector", { left: 52, top: 184, width: 270, height: 132 }, C.blue);
    addMetric(slide, "16", "attention stocks", "separate challenger cohort", { left: 354, top: 184, width: 270, height: 132 }, C.purple);
    addMetric(slide, "15", "equity ETFs", "broad and sector controls", { left: 656, top: 184, width: 270, height: 132 }, C.green);
    addMetric(slide, "10", "non-equity ETFs", "rates, commodities, FX", { left: 958, top: 184, width: 270, height: 132 }, C.amber);
    addRect(slide, { left: 52, top: 354, width: 560, height: 264 }, C.paleBlue);
    addText(slide, "UNCHANGED EVENT GEOMETRY", {
      left: 82, top: 382, width: 400, height: 24,
    }, { fontSize: 16, bold: true, color: C.blue });
    addBullet(slide, "Daily low / prior close from −12% through −8%.", { left: 82, top: 428, width: 482, height: 48 }, C.blue);
    addBullet(slide, "Triggered proxy at or below −10%; strong CLV ≥ .75; weak CLV ≤ .25.", { left: 82, top: 488, width: 482, height: 60 }, C.blue);
    addBullet(slide, "Completed signal close → next-open entry → sessions 0–10.", { left: 82, top: 558, width: 482, height: 48 }, C.blue);
    addRect(slide, { left: 646, top: 354, width: 582, height: 264 }, C.panel);
    addText(slide, "REPRESENTATION GUARDRAILS", {
      left: 676, top: 382, width: 400, height: 24,
    }, { fontSize: 16, bold: true, color: C.navy });
    addBullet(slide, "All 129 stay enrolled—including six with no band event.", { left: 676, top: 428, width: 510, height: 48 }, C.navy);
    addBullet(slide, "Seven later listings retain shorter available histories; none are outcome-dropped.", { left: 676, top: 488, width: 510, height: 60 }, C.navy);
    addBullet(slide, "Stocks and ETFs are separated before any cohort readout.", { left: 676, top: 558, width: 510, height: 48 }, C.navy);
    addNotes(slide,
      "The primary replication is the balanced 88-stock core. The attention and ETF cohorts are separate challengers and controls. Zero-event instruments remain in the enrolled-symbol ledger.",
      [sources.spec, sources.counts, sources.coverage],
    );
  }

  // 3 — availability.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "Breadth adds observations, but the target event stays sparse", 3,
      "The attention cohort generates far more severe daily-low events than the balanced core.");
    await addImage(slide, visuals.availability, { left: 48, top: 160, width: 1184, height: 500 },
      "Cohort event observations and enrolled-symbol availability across the frozen 129-instrument Rule 201 atlas.");
    addNotes(slide,
      "Every core and attention stock has at least one discovery-band event, but only 20 of 88 core stocks and 13 of 16 attention stocks have a triggered/strong-reclaim event. ETF target cells are especially thin.",
      [sources.counts, sources.coverage],
    );
  }

  // 4 — primary replication.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "The 88-stock core does not reproduce the pilot's day-five hump", 4,
      "Primary event-pooled replication: medians with event-level interquartile ribbons.");
    await addImage(slide, visuals.core, { left: 44, top: 152, width: 930, height: 520 },
      "Four event-pooled forward-path panels for the Rule 201 event categories across the 88-stock sector core.");
    addRect(slide, { left: 995, top: 182, width: 235, height: 180 }, C.paleRed);
    addText(slide, "−0.24%", { left: 1015, top: 214, width: 195, height: 48 }, {
      fontSize: 36, bold: true, color: C.red, alignment: "center",
    });
    addText(slide, "triggered + strong\nday-five median", {
      left: 1015, top: 274, width: 195, height: 62,
    }, { fontSize: 17, bold: true, color: C.navy, alignment: "center" });
    addRect(slide, { left: 995, top: 390, width: 235, height: 180 }, C.panel);
    addText(slide, "21", { left: 1015, top: 422, width: 195, height: 48 }, {
      fontSize: 36, bold: true, color: C.navy, alignment: "center",
    });
    addText(slide, "events across\n20 eligible symbols", {
      left: 1015, top: 482, width: 195, height: 62,
    }, { fontSize: 17, bold: true, color: C.navy, alignment: "center" });
    addText(slide, "Mechanism clue: a down-then-recovery shape remains, but not the pilot median at session five.", {
      left: 995, top: 598, width: 235, height: 58,
    }, { fontSize: 15, bold: true, color: C.navy });
    addNotes(slide,
      "The pilot ten-stock triggered/strong group had a positive 3.72 percent day-five median. The balanced core's comparable event-pooled median is negative 0.24 percent across 21 events and negative 0.48 percent at day ten.",
      [sources.pooled, sources.comparison],
    );
  }

  // 5 — weighting.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "Equal-symbol weighting reveals who controls the apparent path", 5,
      "Solid = event-pooled median; dashed = equal mean of within-symbol medians.");
    await addImage(slide, visuals.weighting, { left: 46, top: 152, width: 940, height: 516 },
      "Comparison of event-pooled and equal-symbol triggered/strong-reclaim paths across the four atlas cohorts.");
    addRect(slide, { left: 1004, top: 178, width: 226, height: 206 }, C.paleGreen);
    addText(slide, "+0.51%", { left: 1020, top: 215, width: 194, height: 50 }, {
      fontSize: 34, bold: true, color: C.green, alignment: "center",
    });
    addText(slide, "core day five\nequal-symbol mean", {
      left: 1020, top: 278, width: 194, height: 60,
    }, { fontSize: 17, bold: true, color: C.navy, alignment: "center" });
    addRect(slide, { left: 1004, top: 408, width: 226, height: 196 }, C.panel);
    addText(slide, "47 / 68", { left: 1020, top: 444, width: 194, height: 50 }, {
      fontSize: 34, bold: true, color: C.purple, alignment: "center",
    });
    addText(slide, "all-stock target events\ncome from attention names", {
      left: 1020, top: 507, width: 194, height: 62,
    }, { fontSize: 16, bold: true, color: C.navy, alignment: "center" });
    addText(slide, "The mild core signal is not the same phenomenon as the attention-stock hump.", {
      left: 1004, top: 622, width: 226, height: 42,
    }, { fontSize: 14, bold: true, color: C.navy });
    addNotes(slide,
      "Within each eligible symbol, the median path is computed first; those symbol medians are then averaged equally. This prevents event-rich names from mechanically dominating the curve. ETF panels each have only one target event and therefore identical pooled and equal-symbol lines.",
      [sources.equal, sources.pooled, sources.counts],
    );
  }

  // 6 — cohort vocabulary.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "Cohort separation matters more than the threshold label alone", 6,
      "Day-five and day-ten medians expose different return geometry across the same four event states.");
    await addImage(slide, visuals.cohorts, { left: 46, top: 152, width: 930, height: 516 },
      "Heatmaps of day-five and day-ten event-pooled median returns by Rule 201 event category and atlas cohort.");
    addRect(slide, { left: 1002, top: 186, width: 230, height: 182 }, C.paleGreen);
    addText(slide, "+2.65%", { left: 1018, top: 220, width: 198, height: 48 }, {
      fontSize: 34, bold: true, color: C.green, alignment: "center",
    });
    addText(slide, "attention-stock target\nday-five median", {
      left: 1018, top: 282, width: 198, height: 58,
    }, { fontSize: 17, bold: true, color: C.navy, alignment: "center" });
    addRect(slide, { left: 1002, top: 394, width: 230, height: 214 }, C.paleRed);
    addText(slide, "ETF warning", { left: 1018, top: 424, width: 198, height: 30 }, {
      fontSize: 23, bold: true, color: C.red, alignment: "center",
    });
    addText(slide,
      "Triggered + strong cells contain one event in each ETF cohort. Their ±10–20% values are examples, not cohort estimates.",
      { left: 1020, top: 470, width: 194, height: 112 },
      { fontSize: 16, color: C.navy, alignment: "center" },
    );
    addNotes(slide,
      "The attention-stock triggered/strong group has a positive 2.65 percent day-five median and a negative 2.28 percent day-ten median. The ETF target cells are visually extreme because each cohort contains one eligible event, so they must not be interpreted as stable estimates.",
      [sources.pooled, sources.counts],
    );
  }

  // 7 — concentration.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "The wider atlas reduces one-name dependence, not calendar clustering", 7,
      "Triggered + strong events remain concentrated in attention names and stress-heavy years.");
    await addImage(slide, visuals.concentration, { left: 48, top: 156, width: 900, height: 500 },
      "Largest symbol contributions and calendar-year shares for triggered strong-reclaim events across all 129 instruments.");
    addRect(slide, { left: 976, top: 182, width: 252, height: 174 }, C.panel);
    addText(slide, "AMC · MARA · CVNA", { left: 993, top: 214, width: 218, height: 40 }, {
      fontSize: 22, bold: true, color: C.navy, alignment: "center",
    });
    addText(slide, "three largest symbol\ncontributions", {
      left: 993, top: 274, width: 218, height: 60,
    }, { fontSize: 17, color: C.navy, alignment: "center" });
    addRect(slide, { left: 976, top: 384, width: 252, height: 174 }, C.paleRed);
    addText(slide, "2020 + 2022", { left: 993, top: 416, width: 218, height: 40 }, {
      fontSize: 28, bold: true, color: C.red, alignment: "center",
    });
    addText(slide, "supply most target\nevents", {
      left: 993, top: 478, width: 218, height: 58,
    }, { fontSize: 17, color: C.navy, alignment: "center" });
    addText(slide, "Breadth changes the diagnosis: concentration is now a cohort-and-era question, not just AMC/CVNA.", {
      left: 976, top: 592, width: 252, height: 62,
    }, { fontSize: 15, bold: true, color: C.navy });
    addNotes(slide,
      "AMC, MARA, and CVNA are the three largest individual contributors. Calendar concentration remains strongest in 2020 and 2022. The wider atlas therefore reduces the original pilot's two-name dependence but does not remove cohort and era dependence.",
      [sources.counts, sources.report],
    );
  }

  // 8 — conclusion and next decision.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "Breadth falsifies universality and sharpens the next question", 8,
      "This is a successful learning result: the visible path has a location, not yet an edge.");
    addRect(slide, { left: 52, top: 184, width: 560, height: 336 }, C.paleRed);
    addText(slide, "WHAT DID NOT SURVIVE", { left: 82, top: 214, width: 360, height: 24 }, {
      fontSize: 16, bold: true, color: C.red });
    addText(slide, "A broad Rule 201 × reclaim rebound.", {
      left: 82, top: 260, width: 470, height: 72,
    }, { fontSize: 31, bold: true, color: C.ink });
    addBullet(slide, "Core 88: −0.24% event-pooled median at day five.", { left: 84, top: 358, width: 470, height: 48 }, C.red, 20);
    addBullet(slide, "Only 21 target events across 20 core symbols.", { left: 84, top: 420, width: 470, height: 48 }, C.red, 20);
    addBullet(slide, "ETF target cells are too thin to adjudicate anything.", { left: 84, top: 474, width: 470, height: 48 }, C.red, 20);
    addRect(slide, { left: 646, top: 184, width: 582, height: 336 }, C.paleGreen);
    addText(slide, "WHAT REMAINS INTERESTING", { left: 676, top: 214, width: 400, height: 24 }, {
      fontSize: 16, bold: true, color: C.green });
    addText(slide, "A temporary-recovery shape in attention stocks.", {
      left: 676, top: 260, width: 500, height: 72,
    }, { fontSize: 31, bold: true, color: C.ink });
    addBullet(slide, "Attention cohort: +2.65% median at day five, negative by day ten.", { left: 678, top: 358, width: 500, height: 56 }, C.green, 20);
    addBullet(slide, "Core equal-symbol view is mildly positive, but sparse.", { left: 678, top: 430, width: 500, height: 48 }, C.green, 20);
    addBullet(slide, "The mechanism now points to cohort/era conditions upstream of the rule.", { left: 678, top: 490, width: 500, height: 56 }, C.green, 20);
    addRect(slide, { left: 52, top: 558, width: 1176, height: 92 }, C.navy);
    addText(slide, "NEXT OPERATOR GATE", { left: 80, top: 580, width: 220, height: 24 }, {
      fontSize: 15, bold: true, color: C.paleBlue });
    addText(slide,
      "Explain or predeclare a falsification of the attention-stock distinction—or pause the daily lane before opening intraday data.",
      { left: 310, top: 576, width: 880, height: 54 },
      { fontSize: 22, bold: true, color: C.white },
    );
    addNotes(slide,
      "This closes the breadth replication without selecting a horizon or promoting a rule. A subsequent slice could inspect an upstream explanation for attention-stock behavior or freeze a falsification of the cohort distinction. Either intraday branch remains separately gated.",
      [sources.report, sources.pooled, sources.equal, sources.comparison],
    );
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
  const inspect = await p.inspect({
    kind: "slide,textbox,shape,image,chart,table,layout", maxChars: 120000,
  });
  await fs.writeFile(path.join(qaRoot, "deck.inspect.ndjson"), inspect.ndjson);
  const pptx = await PresentationFile.exportPptx(p);
  await pptx.save(deckPath);
  console.log(deckPath);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
