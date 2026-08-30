import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const moduleRoot = process.env.RUNTIME_NODE_MODULES;
if (!moduleRoot) {
  throw new Error("RUNTIME_NODE_MODULES is required.");
}
const artifactEntrypoint = path.join(
  moduleRoot,
  "@oai",
  "artifact-tool",
  "dist",
  "artifact_tool.mjs",
);
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactEntrypoint).href);

const repoRoot = process.env.GEN5_REPO_ROOT || process.cwd();
const packetRoot = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "edge_discovery_lab",
  "edl_ms_01_rule201_reclaim_discovery_20260830",
);
const deckPath = path.join(
  repoRoot,
  "edge_discovery_lab",
  "presentations",
  "edl_ms_01_rule201_reclaim_discovery.pptx",
);
const qaRoot = path.join(
  repoRoot,
  "runs",
  "research_workbench",
  "edge_discovery_lab",
  "edl_ms_01_rule201_reclaim_deck_20260830",
);
const renderRoot = path.join(qaRoot, "rendered");
const scatterPath = path.join(packetRoot, "visuals", "rule201_threshold_scatter.png");
const tapesPath = path.join(packetRoot, "visuals", "rule201_deterministic_event_tapes.png");

const sources = {
  sec: "SEC, Division of Trading and Markets, Responses to Frequently Asked Questions Concerning Rule 201 of Regulation SHO, https://www.sec.gov/rules-regulations/staff-guidance/trading-markets-frequently-asked-questions-7",
  nasdaq: "Nasdaq Trader, Short Sale Circuit Breaker, https://nasdaqtrader.com/trader.aspx?id=ShortSaleCircuitBreaker",
  localReport: "Local discovery packet: runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_reclaim_discovery_20260830/report.md",
  runSpec: "Local frozen run specification: runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_reclaim_discovery_20260830/run_spec.csv",
  ledger: "Local event ledger: runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_reclaim_discovery_20260830/event_ledger.csv",
  tapes: "Local deterministic tape selection: runs/research_workbench/edge_discovery_lab/edl_ms_01_rule201_reclaim_discovery_20260830/selected_event_tapes.csv",
};

const C = {
  white: "#FFFFFF",
  ink: "#000000",
  navy: "#24364B",
  muted: "#667386",
  rule: "#B8BCC4",
  blue: "#3D8DFF",
  paleBlue: "#D0EDFA",
  panel: "#F3F5F7",
  red: "#B44738",
  paleRed: "#F6E5E1",
  green: "#14866D",
  paleGreen: "#E2F1EC",
  amber: "#A86B00",
};

function addText(slide, text, position, style = {}) {
  const shape = slide.shapes.add({
    geometry: "textbox",
    position,
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = text;
  shape.text.style = {
    fontFace: "Arial",
    fontSize: style.fontSize ?? 20,
    bold: style.bold ?? false,
    color: style.color ?? C.ink,
    alignment: style.alignment ?? "left",
    verticalAlignment: style.verticalAlignment ?? "top",
  };
  return shape;
}

function addRect(slide, position, fill, line = fill, width = 0) {
  return slide.shapes.add({
    geometry: "rect",
    position,
    fill,
    line: { style: "solid", fill: line, width },
  });
}

function addRule(slide, top) {
  addRect(slide, { left: 48, top, width: 1184, height: 2 }, C.rule);
}

function addHeader(slide, title, page, kicker = "EDGE DISCOVERY LAB · EDL-MS-01") {
  addText(slide, kicker, { left: 48, top: 26, width: 520, height: 20 }, {
    fontSize: 14, bold: true, color: C.muted,
  });
  addText(slide, title, { left: 48, top: 58, width: 1160, height: 64 }, {
    fontSize: 40, bold: true, color: C.ink,
  });
  addRule(slide, 130);
  addText(slide, "Discovery slice · adjusted daily bars · 2018–2023 TRAIN only", {
    left: 48, top: 685, width: 720, height: 18,
  }, { fontSize: 12, color: C.muted });
  addText(slide, String(page).padStart(2, "0"), {
    left: 1140, top: 682, width: 92, height: 20,
  }, { fontSize: 12, color: C.muted, alignment: "right" });
}

function addNotes(slide, body, sourceList) {
  slide.speakerNotes.textFrame.setText([
    body,
    "",
    "[Sources]",
    ...sourceList.map((source) => "- " + source),
    "[/Sources]",
  ].join("\n"));
  slide.speakerNotes.setVisible(true);
}

function addMetric(slide, value, label, detail, left, top, width = 250, accent = C.blue) {
  addRect(slide, { left, top, width, height: 126 }, C.panel);
  addRect(slide, { left, top, width: 8, height: 126 }, accent);
  addText(slide, value, { left: left + 24, top: top + 16, width: width - 40, height: 44 }, {
    fontSize: 34, bold: true,
  });
  addText(slide, label, { left: left + 24, top: top + 66, width: width - 40, height: 24 }, {
    fontSize: 16, bold: true, color: C.navy,
  });
  addText(slide, detail, { left: left + 24, top: top + 94, width: width - 40, height: 20 }, {
    fontSize: 12, color: C.muted,
  });
}

function addBullet(slide, text, left, top, width, accent = C.blue, fontSize = 21) {
  addRect(slide, { left, top: top + 8, width: 9, height: 9 }, accent);
  addText(slide, text, { left: left + 24, top, width: width - 24, height: 58 }, {
    fontSize, color: C.navy,
  });
}

async function addImage(slide, imagePath, position, alt) {
  const bytes = await fs.readFile(imagePath);
  slide.images.add({
    blob: bytes,
    contentType: "image/png",
    alt,
    fit: "contain",
    position,
  });
}

async function main() {
  await fs.mkdir(path.dirname(deckPath), { recursive: true });
  await fs.mkdir(renderRoot, { recursive: true });
  await fs.writeFile(path.join(qaRoot, "source-notes.txt"), [
    sources.sec,
    sources.nasdaq,
    sources.localReport,
    sources.runSpec,
    sources.ledger,
    sources.tapes,
  ].join("\n"), "utf8");

  const p = Presentation.create({ slideSize: { width: 1280, height: 720 } });

  // Slide 1 — cover
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addRect(slide, { left: 0, top: 0, width: 24, height: 720 }, C.blue);
    addText(slide, "EDGE DISCOVERY LAB · FIRST JOINT LLM / OPERATOR CANDIDATE", {
      left: 72, top: 72, width: 720, height: 28,
    }, { fontSize: 16, bold: true, color: C.muted });
    addText(slide, "Rule 201\nReclaim", {
      left: 72, top: 148, width: 820, height: 190,
    }, { fontSize: 78, bold: true, color: C.ink });
    addText(slide, "A fixed market-structure threshold meets same-day price recovery.", {
      left: 76, top: 370, width: 780, height: 70,
    }, { fontSize: 30, color: C.navy });
    addRect(slide, { left: 930, top: 118, width: 250, height: 250 }, C.navy);
    addText(slide, "−10%", { left: 944, top: 180, width: 222, height: 86 }, {
      fontSize: 58, bold: true, color: C.white, alignment: "center",
    });
    addText(slide, "prior-close\nthreshold", { left: 954, top: 276, width: 202, height: 58 }, {
      fontSize: 20, color: C.paleBlue, alignment: "center",
    });
    addRect(slide, { left: 72, top: 532, width: 1106, height: 2 }, C.rule);
    addText(slide, "Discovery question", { left: 72, top: 562, width: 220, height: 26 }, {
      fontSize: 17, bold: true, color: C.blue,
    });
    addText(slide, "When a volatile stock breaches a salient rule threshold but recovers before the close, does the next tradable session behave differently?", {
      left: 300, top: 555, width: 860, height: 64,
    }, { fontSize: 23, color: C.navy });
    addText(slide, "DISCOVERY SLICE COMPLETE · NO EDGE CLAIM", {
      left: 72, top: 666, width: 540, height: 20,
    }, { fontSize: 13, bold: true, color: C.red });
    addNotes(slide,
      "This opens the Edge Discovery Lab. The purpose is to let the operator and LLM interrogate one narrow mechanism visually before any broad statistical gate is opened.",
      [sources.sec, sources.nasdaq, sources.localReport],
    );
  }

  // Slide 2 — mechanism
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "The candidate joins price stress to a real market-structure threshold", 2);
    addText(slide, "PRICE PATH", { left: 68, top: 178, width: 250, height: 24 }, {
      fontSize: 16, bold: true, color: C.muted,
    });
    addText(slide, "Prior close", { left: 72, top: 224, width: 190, height: 34 }, {
      fontSize: 26, bold: true,
    });
    addRect(slide, { left: 228, top: 238, width: 126, height: 4 }, C.navy);
    addText(slide, "Intraday low\n≤ −10%", { left: 378, top: 202, width: 190, height: 70 }, {
      fontSize: 26, bold: true, color: C.red, alignment: "center",
    });
    addRect(slide, { left: 562, top: 238, width: 126, height: 4 }, C.navy);
    addText(slide, "Close-location\nvalue", { left: 704, top: 202, width: 220, height: 70 }, {
      fontSize: 26, bold: true, color: C.green, alignment: "center",
    });
    addRect(slide, { left: 908, top: 238, width: 126, height: 4 }, C.navy);
    addText(slide, "Next open\nis tradable", { left: 1048, top: 202, width: 150, height: 70 }, {
      fontSize: 24, bold: true, alignment: "center",
    });
    addRect(slide, { left: 64, top: 326, width: 548, height: 250 }, C.paleBlue);
    addText(slide, "What Rule 201 contributes", { left: 92, top: 354, width: 470, height: 34 }, {
      fontSize: 27, bold: true, color: C.navy,
    });
    addBullet(slide, "A fixed threshold anchored to the prior close—not a fitted indicator.", 94, 414, 476, C.blue, 20);
    addBullet(slide, "A plausible change in the short-sale execution environment after activation.", 94, 480, 476, C.blue, 20);
    addRect(slide, { left: 644, top: 326, width: 548, height: 250 }, C.paleRed);
    addText(slide, "What it does not contribute", { left: 672, top: 354, width: 470, height: 34 }, {
      fontSize: 27, bold: true, color: C.red,
    });
    addBullet(slide, "It is not a ban on short selling; eligible short-sale executions are price constrained.", 674, 414, 476, C.red, 20);
    addBullet(slide, "A daily low is only a proxy for official exchange activation status.", 674, 480, 476, C.red, 20);
    addNotes(slide,
      "Rule 201 generally activates after a 10 percent decline from the prior close and applies for the remainder of that day and the following trading day. This study uses adjusted daily bars, so the trigger is explicitly labeled a proxy rather than official exchange status.",
      [sources.sec, sources.nasdaq, sources.localReport],
    );
  }

  // Slide 3 — frozen surface
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "The first slice freezes a small, interpretable discovery surface", 3);
    addMetric(slide, "10", "volatile equities", "TSLA, AMD, NVDA, GME, AMC…", 58, 180, 260, C.blue);
    addMetric(slide, "2018–23", "TRAIN window", "post-2023 remains sealed", 346, 180, 260, C.green);
    addMetric(slide, "−12%…−8%", "visual band", "around the −10% proxy", 634, 180, 260, C.red);
    addMetric(slide, "1 / 3 / 5", "forward sessions", "next-open entry convention", 922, 180, 260, C.amber);
    addText(slide, "MEASURED NOW", { left: 64, top: 360, width: 260, height: 24 }, {
      fontSize: 16, bold: true, color: C.green,
    });
    addBullet(slide, "Trigger proxy: daily low / prior close − 1 ≤ −10%.", 68, 402, 520, C.green);
    addBullet(slide, "Reclaim strength: where the close lands inside that day’s high–low range.", 68, 472, 520, C.green);
    addBullet(slide, "Context only: abnormal dollar volume versus the strictly prior 20-session median.", 68, 542, 520, C.green);
    addText(slide, "DELIBERATELY NOT OPENED", { left: 660, top: 360, width: 350, height: 24 }, {
      fontSize: 16, bold: true, color: C.red,
    });
    addBullet(slide, "No significance tests, multiplicity gates, costs, sizing, or executable strategy.", 664, 402, 510, C.red);
    addBullet(slide, "No outcome-selected tapes and no post-2023 inspection.", 664, 472, 510, C.red);
    addBullet(slide, "No claim that this basket represents the broader market.", 664, 542, 510, C.red);
    addNotes(slide,
      "The basket is an explicit operator-style discovery surface rather than a representative atlas. The point of this slice is construction validity and visual intelligibility.",
      [sources.runSpec, sources.localReport],
    );
  }

  // Slide 4 — scatter
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "The threshold is visible; a following-return cliff is not", 4);
    await addImage(slide, scatterPath, { left: 44, top: 150, width: 850, height: 500 },
      "Scatterplot of intraday low drawdown around the Rule 201 proxy against next-open session return, colored by close-location value and sized by abnormal dollar volume.");
    addMetric(slide, "646", "band events", "−12% through −8%", 928, 174, 264, C.blue);
    addMetric(slide, "239", "proxy-triggered", "low drawdown ≤ −10%", 928, 320, 264, C.red);
    addMetric(slide, "24", "strong reclaims", "triggered + CLV ≥ 0.75", 928, 466, 264, C.green);
    addText(slide, "Visual read: dispersion dominates any abrupt separation at the rule threshold.", {
      left: 930, top: 610, width: 260, height: 50,
    }, { fontSize: 16, bold: true, color: C.navy });
    addNotes(slide,
      "There are enough events to inspect the construction, but only 24 proxy-triggered strong-reclaim observations. The scatter does not show an obvious discontinuity in next-session returns at the negative 10 percent line.",
      [sources.ledger, sources.localReport],
    );
  }

  // Slide 5 — tapes
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "The first tapes challenge the immediate-next-session story", 5);
    await addImage(slide, tapesPath, { left: 58, top: 152, width: 1164, height: 482 },
      "Four deterministic chronological Rule 201 candidate event tapes showing the event day, prior-close line, threshold line, and next-open entry marker.");
    addRect(slide, { left: 58, top: 642, width: 1164, height: 30 }, C.panel);
    addText(slide, "All four examples fell in the immediately following session; three were positive by five sessions. That is a horizon question—not a rescue.", {
      left: 76, top: 647, width: 1128, height: 20,
    }, { fontSize: 15, bold: true, color: C.navy, alignment: "center" });
    addNotes(slide,
      "The tapes are the first chronological example of each predeclared category, not the best or worst outcomes. Their common next-session weakness makes the immediate-rebound story less compelling, while three positive five-session outcomes motivate keeping horizon and mechanism separate in the next discussion.",
      [sources.tapes, sources.localReport],
    );
  }

  // Slide 6 — close
  {
    const slide = p.slides.add();
    slide.background.fill = C.white;
    addHeader(slide, "The slice earns a sharper question—not an edge claim", 6);
    addRect(slide, { left: 58, top: 172, width: 552, height: 360 }, C.paleGreen);
    addText(slide, "VISIBLE NOW", { left: 88, top: 202, width: 250, height: 26 }, {
      fontSize: 17, bold: true, color: C.green,
    });
    addText(slide, "The construction works.", { left: 88, top: 252, width: 470, height: 40 }, {
      fontSize: 31, bold: true,
    });
    addBullet(slide, "A real fixed threshold can be interrogated without fitting it.", 90, 322, 470, C.green, 21);
    addBullet(slide, "Close-location value cleanly distinguishes reclaim from weak-close events.", 90, 398, 470, C.green, 21);
    addBullet(slide, "The tape view exposes timing that a single summary return would hide.", 90, 474, 470, C.green, 21);
    addRect(slide, { left: 642, top: 172, width: 580, height: 360 }, C.paleRed);
    addText(slide, "STILL UNKNOWN", { left: 672, top: 202, width: 250, height: 26 }, {
      fontSize: 17, bold: true, color: C.red,
    });
    addText(slide, "Whether a tradable effect exists.", { left: 672, top: 252, width: 500, height: 40 }, {
      fontSize: 31, bold: true,
    });
    addBullet(slide, "Does exact exchange activation sharpen the proxy?", 674, 322, 494, C.red, 21);
    addBullet(slide, "Is there any reproducible distinction by reclaim strength or horizon?", 674, 398, 494, C.red, 21);
    addBullet(slide, "Does the idea survive a predeclared atlas, costs, and untouched data?", 674, 474, 494, C.red, 21);
    addRect(slide, { left: 58, top: 568, width: 1164, height: 78 }, C.navy);
    addText(slide, "STATUS", { left: 86, top: 590, width: 120, height: 26 }, {
      fontSize: 16, bold: true, color: C.paleBlue,
    });
    addText(slide, "DISCOVERY SLICE COMPLETE · NO PASS / STOP · NO EDGE CLAIM", {
      left: 230, top: 583, width: 920, height: 38,
    }, { fontSize: 25, bold: true, color: C.white });
    addNotes(slide,
      "This is a successful lab slice because it creates a transparent mechanism, validated construction, and operator-facing evidence. The next research gate remains an operator decision.",
      [sources.localReport, sources.runSpec],
    );
  }

  for (const [index, slide] of p.slides.items.entries()) {
    const stem = "slide-" + String(index + 1).padStart(2, "0");
    const png = await p.export({ slide, format: "png", scale: 2 });
    await fs.writeFile(path.join(renderRoot, stem + ".png"), Buffer.from(await png.arrayBuffer()));
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(renderRoot, stem + ".layout.json"), await layout.text());
  }
  const montage = await p.export({ format: "webp", montage: true, scale: 1 });
  await fs.writeFile(path.join(qaRoot, "montage.webp"), Buffer.from(await montage.arrayBuffer()));
  const inspect = await p.inspect({ kind: "slide,textbox,shape,image,chart,table,layout", maxChars: 100000 });
  await fs.writeFile(path.join(qaRoot, "edl_ms_01_rule201_reclaim_discovery.inspect.ndjson"), inspect.ndjson);
  await fs.writeFile(deckPath + ".inspect.ndjson", inspect.ndjson);
  const pptx = await PresentationFile.exportPptx(p);
  await pptx.save(deckPath);
  console.log(deckPath);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
