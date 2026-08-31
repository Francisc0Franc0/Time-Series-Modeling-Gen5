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
  "edl_ms_01_attention_falsification_20260831",
);
const deckPath = path.join(
  repoRoot, "edge_discovery_lab", "presentations",
  "edl_ms_01_attention_falsification.pptx",
);
const qaRoot = process.env.TMP_DIR || path.join(
  repoRoot, "runs", "research_workbench", "edge_discovery_lab",
  "edl_ms_01_attention_falsification_deck_20260831",
);
const renderRoot = path.join(qaRoot, "rendered");
const visuals = {
  balance: path.join(packetRoot, "visuals", "attention_matching_balance.png"),
  pairs: path.join(packetRoot, "visuals", "attention_paired_day5_outcomes.png"),
  paths: path.join(packetRoot, "visuals", "attention_matched_forward_paths.png"),
  sensitivity: path.join(packetRoot, "visuals", "attention_falsification_sensitivity.png"),
};
const sources = {
  pilot: "Local forward-path report: runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_forward_path_20260830/report.md",
  wide: "Local wide-atlas report: runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_wide_atlas_20260830/report.md",
  report: "Local report: runs/research_workbench/edge_discovery_lab/edl_ms_01_attention_falsification_20260831/report.md",
  spec: "Local frozen run specification: runs/research_workbench/edge_discovery_lab/edl_ms_01_attention_falsification_20260831/run_spec.csv",
  enrollment: "Local matching enrollment audit: runs/research_workbench/edge_discovery_lab/edl_ms_01_attention_falsification_20260831/matching_enrollment_audit.csv",
  balance: "Local matching balance: runs/research_workbench/edge_discovery_lab/edl_ms_01_attention_falsification_20260831/matching_balance.csv",
  primary: "Local primary day-five test: runs/research_workbench/edge_discovery_lab/edl_ms_01_attention_falsification_20260831/primary_day5_test.csv",
  paths: "Local matched path summary: runs/research_workbench/edge_discovery_lab/edl_ms_01_attention_falsification_20260831/matched_path_summary.csv",
  years: "Local leave-one-year-out sensitivity: runs/research_workbench/edge_discovery_lab/edl_ms_01_attention_falsification_20260831/leave_one_year_out.csv",
  symbols: "Local leave-one-attention-symbol-out sensitivity: runs/research_workbench/edge_discovery_lab/edl_ms_01_attention_falsification_20260831/leave_one_attention_symbol_out.csv",
  status: "Local falsification status: runs/research_workbench/edge_discovery_lab/edl_ms_01_attention_falsification_20260831/falsification_status.csv",
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
  addText(slide, "Adjusted daily · 2018–2023 TRAIN · matched falsification", {
    left: 42, top: 684, width: 650, height: 18,
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
    left: position.left + 22, top: position.top + 14,
    width: position.width - 38, height: 48,
  }, { fontSize: 35, bold: true, color: accent });
  addText(slide, label, {
    left: position.left + 22, top: position.top + 65,
    width: position.width - 38, height: 24,
  }, { fontSize: 17, bold: true, color: C.navy });
  addText(slide, detail, {
    left: position.left + 22, top: position.top + 94,
    width: position.width - 38, height: 28,
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

  // 1 — sparse Codex Grid cover.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addRect(slide, { left: 0, top: 0, width: 22, height: 720 }, C.red);
    addText(slide, "EDGE DISCOVERY LAB · NARROW FALSIFICATION", {
      left: 56, top: 50, width: 700, height: 26,
    }, { fontSize: 16, bold: true, color: C.muted });
    addText(slide, "Attention-stock distinction", {
      left: 56, top: 146, width: 900, height: 88,
    }, { fontSize: 58, bold: true, color: C.ink });
    addText(slide, "The positive effect does not reproduce.", {
      left: 58, top: 264, width: 920, height: 54,
    }, { fontSize: 35, bold: true, color: C.red });
    addText(slide,
      "Yet the matching itself fails balance—showing that attention and core events occupy meaningfully different pre-outcome environments.",
      { left: 58, top: 350, width: 820, height: 112 },
      { fontSize: 24, color: C.navy },
    );
    addRect(slide, { left: 958, top: 150, width: 240, height: 240 }, C.navy);
    addText(slide, "20", { left: 976, top: 194, width: 204, height: 74 }, {
      fontSize: 64, bold: true, color: C.white, alignment: "center",
    });
    addText(slide, "matched pairs", {
      left: 978, top: 288, width: 200, height: 42,
    }, { fontSize: 22, color: C.paleBlue, alignment: "center" });
    addRect(slide, { left: 58, top: 532, width: 1140, height: 2 }, C.rule);
    addText(slide, "INCONCLUSIVE · MATCH BALANCE FAILED", {
      left: 58, top: 572, width: 720, height: 28,
    }, { fontSize: 17, bold: true, color: C.red });
    addText(slide, "No matcher rescue after outcomes", {
      left: 850, top: 572, width: 348, height: 28,
    }, { fontSize: 17, bold: true, color: C.muted, alignment: "right" });
    addNotes(slide,
      "This sequel tests the wide-atlas clue that attention stocks carried most of the apparent five-session rebound. The result has two layers: the positive distinction fails in the matched sample, and the predeclared balance gate also fails.",
      [sources.report, sources.status, sources.primary],
    );
  }

  // 2 — frozen contract.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "The comparison was frozen before forward returns were attached", 2,
      "One target state, one outcome horizon, one paired inferential test.");
    addMetric(slide, "20", "same-year pairs", "1:1 without replacement", { left: 52, top: 182, width: 260, height: 128 }, C.blue);
    addMetric(slide, "4", "matching variables", "all observed before outcome", { left: 340, top: 182, width: 260, height: 128 }, C.purple);
    addMetric(slide, "5", "forward sessions", "sole inferential horizon", { left: 628, top: 182, width: 260, height: 128 }, C.green);
    addMetric(slide, "0.25", "balance limit", "maximum absolute SMD", { left: 916, top: 182, width: 312, height: 128 }, C.amber);
    addRect(slide, { left: 52, top: 350, width: 560, height: 278 }, C.paleBlue);
    addText(slide, "MATCH ON EVENT GEOMETRY", { left: 82, top: 380, width: 390, height: 24 }, {
      fontSize: 16, bold: true, color: C.blue,
    });
    addBullet(slide, "Minimum intraday return: breach severity.", { left: 82, top: 430, width: 480, height: 44 }, C.blue);
    addBullet(slide, "Close-location value: strength of reclaim.", { left: 82, top: 482, width: 480, height: 44 }, C.blue);
    addBullet(slide, "Log abnormal dollar volume: event attention/scale.", { left: 82, top: 534, width: 480, height: 48 }, C.blue);
    addBullet(slide, "Event date: calendar proximity within year.", { left: 82, top: 588, width: 480, height: 38 }, C.blue);
    addRect(slide, { left: 646, top: 350, width: 582, height: 278 }, C.panel);
    addText(slide, "PREDECLARED PASS LOGIC", { left: 676, top: 380, width: 390, height: 24 }, {
      fontSize: 16, bold: true, color: C.navy,
    });
    addBullet(slide, "Mean attention-minus-core day-five return must be positive.", { left: 676, top: 430, width: 504, height: 52 }, C.navy);
    addBullet(slide, "Exact one-sided sign-flip p ≤ .05.", { left: 676, top: 494, width: 504, height: 44 }, C.navy);
    addBullet(slide, "All leave-one-year and leave-one-attention-symbol means stay positive.", { left: 676, top: 548, width: 504, height: 66 }, C.navy);
    addNotes(slide,
      "The matching pool contained only stock events in the triggered-proxy and strong-reclaim state. Matching occurred inside exact calendar year and was completed before outcomes were attached.",
      [sources.spec, sources.enrollment],
    );
  }

  // 3 — balance audit.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "The matcher cannot make the two cohorts sufficiently comparable", 3,
      "Two of four pre-outcome variables remain beyond the frozen 0.25 balance limit.");
    await addImage(slide, visuals.balance, { left: 46, top: 154, width: 900, height: 510 },
      "Absolute standardized mean differences before and after matching attention-stock events to core-stock events.");
    addRect(slide, { left: 974, top: 184, width: 254, height: 168 }, C.paleRed);
    addText(slide, "0.421", { left: 994, top: 218, width: 214, height: 48 }, {
      fontSize: 37, bold: true, color: C.red, alignment: "center",
    });
    addText(slide, "breach severity\npost-match SMD", {
      left: 994, top: 278, width: 214, height: 54,
    }, { fontSize: 17, bold: true, color: C.navy, alignment: "center" });
    addRect(slide, { left: 974, top: 378, width: 254, height: 168 }, C.paleRed);
    addText(slide, "0.331", { left: 994, top: 412, width: 214, height: 48 }, {
      fontSize: 37, bold: true, color: C.red, alignment: "center",
    });
    addText(slide, "event timing\npost-match SMD", {
      left: 994, top: 472, width: 214, height: 54,
    }, { fontSize: 17, bold: true, color: C.navy, alignment: "center" });
    addText(slide, "2021 contributes 11 attention events but no same-year core comparator.", {
      left: 974, top: 584, width: 254, height: 60,
    }, { fontSize: 16, bold: true, color: C.navy });
    addNotes(slide,
      "Close-location value and log abnormal dollar volume pass the balance limit. Breach severity and event date do not. Twenty pairs come from 2018, 2020, 2022, and 2023; 2021 attention events cannot enter because the core pool has no target event that year.",
      [sources.balance, sources.enrollment],
    );
  }

  // 4 — primary paired outcome.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "Within the available pairs, attention stocks perform worse by day five", 4,
      "The direction is opposite the wide-atlas clue, with no one-sided evidence for a positive difference.");
    await addImage(slide, visuals.pairs, { left: 42, top: 154, width: 910, height: 514 },
      "Matched-pair day-five outcomes and the distribution of attention-minus-core return differences.");
    addRect(slide, { left: 980, top: 178, width: 248, height: 150 }, C.paleRed);
    addText(slide, "−3.34 pp", { left: 996, top: 208, width: 216, height: 46 }, {
      fontSize: 34, bold: true, color: C.red, alignment: "center",
    });
    addText(slide, "mean paired log-return\ndifference", {
      left: 996, top: 266, width: 216, height: 48,
    }, { fontSize: 16, bold: true, color: C.navy, alignment: "center" });
    addRect(slide, { left: 980, top: 352, width: 248, height: 132 }, C.panel);
    addText(slide, "45%", { left: 996, top: 380, width: 216, height: 42 }, {
      fontSize: 32, bold: true, color: C.navy, alignment: "center",
    });
    addText(slide, "attention win rate", {
      left: 996, top: 435, width: 216, height: 30,
    }, { fontSize: 17, bold: true, color: C.navy, alignment: "center" });
    addRect(slide, { left: 980, top: 508, width: 248, height: 132 }, C.panel);
    addText(slide, "p = .818", { left: 996, top: 536, width: 216, height: 42 }, {
      fontSize: 31, bold: true, color: C.navy, alignment: "center",
    });
    addText(slide, "exact one-sided sign flip", {
      left: 996, top: 591, width: 216, height: 30,
    }, { fontSize: 15, bold: true, color: C.navy, alignment: "center" });
    addNotes(slide,
      "The exact test enumerates all 1,048,576 sign assignments for the 20 paired differences. The negative point estimate and large one-sided p-value show that the earlier positive attention-stock pattern does not reproduce in this matched sample.",
      [sources.primary],
    );
  }

  // 5 — contextual path.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "The contextual path shows no hidden day-five recovery advantage", 5,
      "Only session five is inferential; sessions 0–10 are displayed to understand shape.");
    await addImage(slide, visuals.paths, { left: 52, top: 160, width: 1176, height: 492 },
      "Matched attention and core median forward paths and paired mean differences from next-open session zero through ten.");
    addNotes(slide,
      "The paired mean difference is below zero around the predeclared day-five horizon. The surrounding path is descriptive context and was not searched to nominate another holding period.",
      [sources.paths, sources.primary],
    );
  }

  // 6 — sensitivity.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "No single year or attention symbol creates the negative result", 6,
      "Every leave-one-out mean remains negative—the opposite of the frozen robustness condition.");
    await addImage(slide, visuals.sensitivity, { left: 48, top: 158, width: 930, height: 500 },
      "Leave-one-year-out and leave-one-attention-symbol-out paired mean differences at the day-five horizon.");
    addRect(slide, { left: 1002, top: 192, width: 226, height: 188 }, C.paleRed);
    addText(slide, "0 / 4", { left: 1018, top: 228, width: 194, height: 48 }, {
      fontSize: 36, bold: true, color: C.red, alignment: "center",
    });
    addText(slide, "leave-one-year means\nremain positive", {
      left: 1018, top: 290, width: 194, height: 60,
    }, { fontSize: 16, bold: true, color: C.navy, alignment: "center" });
    addRect(slide, { left: 1002, top: 412, width: 226, height: 188 }, C.paleRed);
    addText(slide, "0 / all", { left: 1018, top: 448, width: 194, height: 48 }, {
      fontSize: 36, bold: true, color: C.red, alignment: "center",
    });
    addText(slide, "leave-one-symbol means\nremain positive", {
      left: 1018, top: 510, width: 194, height: 60,
    }, { fontSize: 16, bold: true, color: C.navy, alignment: "center" });
    addNotes(slide,
      "Omitting each matched calendar year in turn leaves a negative attention-minus-core mean. Omitting each attention symbol in turn also leaves a negative mean. This is robust against simple single-era and single-name explanations within the matched sample.",
      [sources.years, sources.symbols],
    );
  }

  // 7 — interpretation and handoff.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "The cohort label fails; the environment difference becomes the next question", 7,
      "We close this falsification without edge promotion or post-outcome matcher changes.");
    addRect(slide, { left: 52, top: 182, width: 560, height: 326 }, C.paleRed);
    addText(slide, "WHAT WE CAN SAY", { left: 82, top: 214, width: 360, height: 24 }, {
      fontSize: 16, bold: true, color: C.red,
    });
    addText(slide, "The attention-stock advantage does not reproduce.", {
      left: 82, top: 258, width: 476, height: 74,
    }, { fontSize: 31, bold: true, color: C.ink });
    addBullet(slide, "Matched point estimate is negative, not merely weak.", { left: 84, top: 366, width: 470, height: 48 }, C.red, 20);
    addBullet(slide, "All year and symbol leave-outs remain negative.", { left: 84, top: 426, width: 470, height: 48 }, C.red, 20);
    addRect(slide, { left: 646, top: 182, width: 582, height: 326 }, C.paleBlue);
    addText(slide, "WHAT WE CANNOT SAY", { left: 676, top: 214, width: 360, height: 24 }, {
      fontSize: 16, bold: true, color: C.blue,
    });
    addText(slide, "This is not a clean matched-estimand rejection.", {
      left: 676, top: 258, width: 500, height: 74,
    }, { fontSize: 31, bold: true, color: C.ink });
    addBullet(slide, "Severity and timing remain materially imbalanced.", { left: 678, top: 366, width: 500, height: 48 }, C.blue, 20);
    addBullet(slide, "Changing the matcher now would be post-outcome rescue.", { left: 678, top: 426, width: 500, height: 48 }, C.blue, 20);
    addRect(slide, { left: 52, top: 548, width: 1176, height: 108 }, C.navy);
    addText(slide, "NEXT SEPARATELY FROZEN SLICE", { left: 80, top: 572, width: 270, height: 24 }, {
      fontSize: 15, bold: true, color: C.paleBlue,
    });
    addText(slide,
      "Quantify the pre-outcome features that separate these event environments—starting with breach severity and calendar timing, then carefully chosen asset traits.",
      { left: 360, top: 566, width: 830, height: 66 },
      { fontSize: 21, bold: true, color: C.white },
    );
    addNotes(slide,
      "The earlier positive cohort clue is not promoted. The inability to balance the two pools is itself a finding: the target events occur in different environments. A new slice may quantify those separators, but its feature vocabulary and outcomes must be frozen separately.",
      [sources.status, sources.balance, sources.primary, sources.report],
    );
  }

  // 8 — plain-English closeout for the complete Rule 201 sequence.
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "Rule 201, in plain English: the rebound clue did not generalize", 8,
      "The study improved our diagnosis without producing a tradable rule.");
    addRect(slide, { left: 52, top: 182, width: 560, height: 326 }, C.paleRed);
    addText(slide, "THE STORY", { left: 82, top: 214, width: 360, height: 24 }, {
      fontSize: 16, bold: true, color: C.red,
    });
    addText(slide, "A dramatic drop and strong close looked promising.", {
      left: 82, top: 258, width: 476, height: 74,
    }, { fontSize: 31, bold: true, color: C.ink });
    addBullet(slide, "Pilot: median rebound near +3.7% by session five.", { left: 84, top: 366, width: 470, height: 48 }, C.red, 20);
    addBullet(slide, "Balanced 88-stock core: roughly −0.24%.", { left: 84, top: 426, width: 470, height: 48 }, C.red, 20);
    addRect(slide, { left: 646, top: 182, width: 582, height: 326 }, C.paleBlue);
    addText(slide, "THE VERDICT", { left: 676, top: 214, width: 360, height: 24 }, {
      fontSize: 16, bold: true, color: C.blue,
    });
    addText(slide, "The attention-stock explanation failed its follow-up.", {
      left: 676, top: 258, width: 500, height: 74,
    }, { fontSize: 31, bold: true, color: C.ink });
    addBullet(slide, "Matched difference: −3.34 pp; one-sided p = .818.", { left: 678, top: 366, width: 500, height: 48 }, C.blue, 20);
    addBullet(slide, "Balance also failed: the cohorts came from different environments.", { left: 678, top: 426, width: 500, height: 48 }, C.blue, 20);
    addRect(slide, { left: 52, top: 548, width: 1176, height: 108 }, C.navy);
    addText(slide, "CURRENT STOP", { left: 80, top: 572, width: 270, height: 24 }, {
      fontSize: 15, bold: true, color: C.paleBlue,
    });
    addText(slide,
      "Do not trade the label. Carry forward the question: which measurable, pre-outcome features separate rebound environments from non-rebound environments?",
      { left: 360, top: 566, width: 830, height: 66 },
      { fontSize: 21, bold: true, color: C.white },
    );
    addNotes(slide,
      "This slide summarizes the complete Rule 201 investigation in plain English. The original ten-stock pilot showed a temporary median rebound near session five. The balanced 88-stock core did not reproduce it. The apparent attention-stock explanation then reversed in the frozen matched follow-up, while the match-balance gate also failed. The result is a better-defined research question, not a tradable rule.",
      [sources.pilot, sources.wide, sources.report],
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
