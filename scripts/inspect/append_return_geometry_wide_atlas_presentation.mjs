import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const moduleRoot = process.env.CODEX_NODE_MODULES ||
  "C:/Users/Franc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules";
const artifactEntrypoint = path.join(moduleRoot, "@oai", "artifact-tool", "dist", "artifact_tool.mjs");
const { FileBlob, PresentationFile } = await import(pathToFileURL(artifactEntrypoint).href);

const deckPath = path.join(
  repoRoot, "operator_hypothesis_lab", "presentations", "tsla_descriptive_microscope_evidence.pptx",
);
const packet = path.join(
  repoRoot, "runs", "research_workbench", "operator_hypothesis_lab", "return_geometry_wide_atlas_20260827",
);
const visual = (name) => path.join(packet, "visuals", name);
const qaRoot = path.join(os.tmpdir(), "codex-presentations", "tsla-wide-atlas-edit");
await fs.mkdir(qaRoot, { recursive: true });

const presentation = await PresentationFile.importPptx(await FileBlob.load(deckPath));
if (presentation.slides.items.length !== 105) {
  throw new Error(`Expected the 105-slide running deck; found ${presentation.slides.items.length}.`);
}

const colors = {
  ink: "#111827",
  muted: "#667384",
  rule: "#B8BCC4",
  coral: "#E45756",
  blue: "#3D8DFF",
  green: "#2A9D6F",
  purple: "#7C3AED",
  amber: "#F59E0B",
  pale: "#F4F6F8",
  paleBlue: "#EDF5FF",
  paleCoral: "#FDF0EF",
  white: "#FFFFFF",
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
    fontSize: style.fontSize ?? 20,
    color: style.color ?? colors.ink,
    bold: style.bold ?? false,
    alignment: style.alignment,
    verticalAlignment: style.verticalAlignment,
  };
  return shape;
}

function addRect(slide, position, fill, line = fill, radius = false) {
  return slide.shapes.add({
    geometry: radius ? "roundRect" : "rect",
    position,
    fill,
    line: { style: "solid", fill: line, width: 1 },
    ...(radius ? { borderRadius: "rounded-xl" } : {}),
  });
}

function addHeader(slide, title, page, section = "WIDE ATLAS") {
  addText(slide, section, { left: 48, top: 24, width: 440, height: 24 }, {
    fontSize: 16, bold: true, color: colors.muted,
  });
  addText(slide, title, { left: 48, top: 56, width: 1184, height: 66 }, {
    fontSize: 47, bold: true,
  });
  addRect(slide, { left: 48, top: 126, width: 1184, height: 2 }, colors.rule);
  addText(slide, "129 instruments | adjusted daily | 2018–2023", { left: 48, top: 684, width: 470, height: 18 }, {
    fontSize: 12, color: colors.muted,
  });
  addText(slide, String(page), { left: 1100, top: 682, width: 132, height: 20 }, {
    fontSize: 12, color: colors.muted, alignment: "right",
  });
}

function addNotes(slide, body, sources) {
  slide.speakerNotes.textFrame.setText([
    body,
    "",
    "[Sources]",
    ...sources.map((source) => `- ${source}`),
    "[/Sources]",
  ].join("\n"));
  slide.speakerNotes.setVisible(true);
}

async function addImage(slide, imagePath, position, alt) {
  const bytes = await fs.readFile(imagePath);
  return slide.images.add({
    blob: bytes,
    contentType: "image/png",
    alt,
    fit: "contain",
    position,
  });
}

function addEvidenceFrame(slide) {
  addRect(slide, { left: 105, top: 142, width: 1070, height: 515 }, colors.white, "#D7DBE2", true);
}

function addThreeRowDecision(slide, rows, footerLabel, footerText) {
  const tops = [168, 294, 420];
  rows.forEach((row, index) => {
    addRect(slide, { left: 58, top: tops[index], width: 10, height: 94 }, row.color);
    addText(slide, row.label, { left: 92, top: tops[index] - 2, width: 220, height: 30 }, {
      fontSize: 18, bold: true, color: row.color,
    });
    addText(slide, row.headline, { left: 326, top: tops[index] - 4, width: 500, height: 44 }, {
      fontSize: 28, bold: true,
    });
    addText(slide, row.detail, { left: 850, top: tops[index] - 2, width: 350, height: 74 }, {
      fontSize: 20, color: colors.muted,
    });
    addRect(slide, { left: 92, top: tops[index] + 104, width: 1108, height: 1 }, colors.rule);
  });
  addRect(slide, { left: 58, top: 562, width: 1142, height: 82 }, colors.pale, "#D7DBE2", true);
  addText(slide, footerLabel, { left: 82, top: 580, width: 270, height: 34 }, { fontSize: 20, bold: true });
  addText(slide, footerText, { left: 350, top: 576, width: 820, height: 52 }, { fontSize: 19, color: colors.muted });
}

// Slide 106 — transition.
{
  const slide = presentation.slides.add();
  slide.background.fill = colors.white;
  addText(slide, "WIDE ATLAS", { left: 48, top: 42, width: 420, height: 28 }, {
    fontSize: 18, bold: true, color: colors.coral,
  });
  addText(slide, "Does the plateau survive real sector breadth?", { left: 48, top: 164, width: 1130, height: 190 }, {
    fontSize: 58, bold: true,
  });
  addRect(slide, { left: 48, top: 390, width: 132, height: 8 }, colors.coral);
  addText(slide, "Freeze 129 instruments, all nine filters, and a coarse 20–100-session grid.",
    { left: 48, top: 438, width: 1040, height: 72 }, { fontSize: 27, color: colors.muted });
  addText(slide, "Primary headline: 88 stocks, eight in each of 11 GICS sectors, equal-sector weighted.",
    { left: 48, top: 570, width: 1100, height: 64 }, { fontSize: 21, color: colors.muted });
  addText(slide, "106", { left: 1180, top: 682, width: 52, height: 20 }, { fontSize: 12, color: colors.muted, alignment: "right" });
  addNotes(slide,
    "This slice opens breadth, not another horizon search. The attention sleeve and controls are retained as challengers, while the full-history 88-stock core determines the equal-sector headline.",
    [
      "operator_hypothesis_lab/docs/RETURN_GEOMETRY_WIDE_ATLAS_2018_2023.md",
      "operator_hypothesis_lab/registries/return_geometry_wide_atlas.csv",
    ]);
}

// Slide 107 — frozen design.
{
  const slide = presentation.slides.add();
  slide.background.fill = colors.white;
  addHeader(slide, "The wider atlas is balanced before results are read", 107);
  addThreeRowDecision(slide, [
    { label: "CORE", headline: "88 stocks", detail: "11 sectors × 8 names", color: colors.blue },
    { label: "CHALLENGE", headline: "16 attention names", detail: "separate sleeve—not a sector", color: colors.amber },
    { label: "CONTROLS", headline: "25 liquid proxies", detail: "15 equity ETFs + 10 non-equity", color: colors.green },
  ], "Frozen grid", "Prior and following = 20 / 25 / 30 / 35 / 40 / 50 / 75 / 100. All nine existing filter states; no per-asset selection.");
  addNotes(slide,
    "GICS supplies the 11-sector top-level taxonomy. These are frozen current research labels, not point-in-time constituent histories. Only the core enters equal-sector aggregation.",
    [
      "operator_hypothesis_lab/registries/return_geometry_wide_atlas.csv",
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/run_spec.csv",
      "https://www.spglobal.com/spdji/en/landing/topic/gics/",
      "https://www.spglobal.com/spdji/en/documents/methodologies/methodology-gics.pdf?force_download=true",
    ]);
}

// Slide 108 — coverage and integrity.
{
  const slide = presentation.slides.add();
  slide.background.fill = colors.white;
  addHeader(slide, "Coverage is complete where the headline is formed", 108);
  const cards = [
    { x: 58, value: "129/129", label: "analyzable", fill: colors.paleBlue, color: colors.blue },
    { x: 450, value: "88/88", label: "core full-history", fill: "#EDF8F3", color: colors.green },
    { x: 842, value: "74,304", label: "asset-state cells", fill: colors.paleCoral, color: colors.coral },
  ];
  cards.forEach((card) => {
    addRect(slide, { left: card.x, top: 164, width: 340, height: 180 }, card.fill, card.fill, true);
    addText(slide, card.value, { left: card.x + 22, top: 188, width: 296, height: 70 }, { fontSize: 48, bold: true, color: card.color, alignment: "center" });
    addText(slide, card.label, { left: card.x + 22, top: 274, width: 296, height: 38 }, { fontSize: 21, bold: true, alignment: "center" });
  });
  addRect(slide, { left: 58, top: 386, width: 1142, height: 210 }, colors.pale, "#D7DBE2", true);
  addText(slide, "10 partial-history attention names", { left: 84, top: 414, width: 460, height: 48 }, { fontSize: 29, bold: true });
  addText(slide, "Refreshed once; no pre-listing rows exist. Every history reaches 2023, and none enters equal-sector weighting.",
    { left: 84, top: 478, width: 1055, height: 72 }, { fontSize: 21, color: colors.muted });
  addText(slide, "12 / 12 integrity checks pass • original 30-name overlap reproduces below 5e−16",
    { left: 84, top: 566, width: 1055, height: 30 }, { fontSize: 17, bold: true, color: colors.green });
  addNotes(slide,
    "The remaining provider WARN labels are structural IPO/first-trade partial histories in the attention sleeve. A refresh was attempted and returned no earlier bars. The equal-sector core is fully covered.",
    [
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/coverage_ledger.csv",
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/wide_atlas_query_merge_summary.csv",
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/wide_atlas_checks.csv",
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/original_atlas_parity.csv",
    ]);
}

// Slide 109 — complete signed-down surface.
{
  const slide = presentation.slides.add();
  slide.background.fill = colors.white;
  addHeader(slide, "The signed-down plateau survives the full coarse surface", 109);
  addEvidenceFrame(slide);
  await addImage(slide, visual("equal_sector_signed_er20_down_trend_heatmap.png"),
    { left: 170, top: 148, width: 940, height: 500 },
    "Equal-sector signed-ER20 down-state negative-prior correlation heatmap");
  addText(slide, "Every one of 64 equal-sector cells is negative; this is a broad surface—not a selected endpoint.",
    { left: 120, top: 660, width: 1040, height: 18 }, { fontSize: 14, bold: true, alignment: "center" });
  addNotes(slide,
    "The primary surface takes the median loss-branch correlation within each sector and then the median across 11 sectors. All 64 cells remain negative. This is one dependent morphology, not 64 independent confirmations.",
    [
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/visuals/equal_sector_signed_er20_down_trend_heatmap.png",
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/equal_sector_cell_summary.csv",
      "operator_hypothesis_lab/docs/RETURN_GEOMETRY_WIDE_ATLAS_2018_2023.md",
    ]);
}

// Slide 110 — sector diagonal.
{
  const slide = presentation.slides.add();
  slide.background.fill = colors.white;
  addHeader(slide, "Sector breadth holds through 75—and nearly through 100", 110);
  addEvidenceFrame(slide);
  await addImage(slide, visual("signed_down_sector_diagonal.png"),
    { left: 132, top: 148, width: 1016, height: 500 },
    "Signed-down loss-rebound diagonal by GICS sector");
  addText(slide, "11 / 11 sector medians are negative through 75; 10 / 11 at 100, with Health Care ≈ +0.01.",
    { left: 120, top: 660, width: 1040, height: 18 }, { fontSize: 14, bold: true, alignment: "center" });
  addNotes(slide,
    "The 100-session Health Care exception is useful: broad transport is not the same thing as a universal law. Consumer Discretionary, Materials, Industrials, and Utilities are especially negative at 100.",
    [
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/visuals/signed_down_sector_diagonal.png",
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/sector_horizon_diagonal.csv",
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/headline_signed_down_diagonal.csv",
    ]);
}

// Slide 111 — all states.
{
  const slide = presentation.slides.add();
  slide.background.fill = colors.white;
  addHeader(slide, "The template discriminates among regime states", 111);
  addEvidenceFrame(slide);
  await addImage(slide, visual("all_states_equal_sector_diagonal.png"),
    { left: 145, top: 148, width: 990, height: 500 },
    "All nine frozen filters on the equal-sector loss-branch diagonal");
  addText(slide, "Trending / ATR-high / signed-down are strongest; signed-up losses are structurally sparse at short horizons.",
    { left: 120, top: 660, width: 1040, height: 18 }, { fontSize: 14, bold: true, alignment: "center" });
  addNotes(slide,
    "This view prevents the study from becoming a signed-down-only story. Unfiltered loss rebound remains visible, ATR-high is stronger than low/medium, and the signed-up negative-prior branch is sparse because the state and branch are mechanically discordant.",
    [
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/visuals/all_states_equal_sector_diagonal.png",
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/equal_sector_horizon_diagonal.csv",
      "operator_hypothesis_lab/docs/RETURN_GEOMETRY_WIDE_ATLAS_2018_2023.md",
    ]);
}

// Slide 112 — cohorts.
{
  const slide = presentation.slides.add();
  slide.background.fill = colors.white;
  addHeader(slide, "Challenge cohorts preserve useful heterogeneity", 112);
  addRect(slide, { left: 58, top: 150, width: 560, height: 490 }, colors.white, "#D7DBE2", true);
  addRect(slide, { left: 662, top: 150, width: 538, height: 490 }, colors.white, "#D7DBE2", true);
  await addImage(slide, visual("signed_down_cohort_diagonal.png"),
    { left: 72, top: 164, width: 532, height: 420 },
    "Signed-down loss-rebound diagonal across four atlas cohorts");
  await addImage(slide, visual("signed_down_attention_diagonal.png"),
    { left: 680, top: 164, width: 500, height: 420 },
    "Attention supplement signed-down diagonal by asset");
  addText(slide, "Equity ETFs are strongest; non-equity proxies start near zero.",
    { left: 82, top: 590, width: 520, height: 42 }, { fontSize: 16, bold: true, alignment: "center" });
  addText(slide, "Attention breadth rises from 56% at 20 to 75% at 100—still not uniform.",
    { left: 682, top: 590, width: 500, height: 42 }, { fontSize: 16, bold: true, alignment: "center" });
  addNotes(slide,
    "The attention sleeve is deliberately secondary and heterogeneous. Its median moves from -0.105 at 20 to -0.295 at 100, but several names retain opposite signs. Non-equity controls remain much weaker than equities.",
    [
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/visuals/signed_down_cohort_diagonal.png",
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/visuals/signed_down_attention_diagonal.png",
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/cohort_horizon_diagonal.csv",
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/asset_horizon_diagonal.csv",
    ]);
}

// Slide 113 — decision.
{
  const slide = presentation.slides.add();
  slide.background.fill = colors.white;
  addHeader(slide, "Decision: broad transport survives—edge remains unopened", 113);
  addThreeRowDecision(slide, [
    { label: "FOUND", headline: "Sector-wide plateau", detail: "64 / 64 primary cells negative", color: colors.green },
    { label: "LEARNS", headline: "Real heterogeneity", detail: "Health Care flat at 100; controls differ", color: colors.blue },
    { label: "DOES NOT EARN", headline: "A strategy or duration", detail: "no edge, causality, or 100-session hold", color: colors.coral },
  ], "Next clean gate", "Decompose non-overlapping future blocks—or freeze one compact summary for untouched-time transport. Stop expanding horizons at 100.");
  addNotes(slide,
    "This breadth slice weakens a TSLA-only, five-name-group, or single-sector explanation. Cumulative overlapping returns still hide when the rebound accrues. The operator must open the next gate explicitly.",
    [
      "operator_hypothesis_lab/docs/RETURN_GEOMETRY_WIDE_ATLAS_2018_2023.md",
      "operator_hypothesis_lab/docs/OWN_ASSET_RETURN_GEOMETRY_WORKFLOW_ROADMAP.md",
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/wide_atlas_status.csv",
      "runs/research_workbench/operator_hypothesis_lab/return_geometry_wide_atlas_20260827/report.md",
    ]);
}

const finalSlides = presentation.slides.items.length;
if (finalSlides !== 113) throw new Error(`Expected 113 slides after append; found ${finalSlides}.`);

const afterInspect = await presentation.inspect({
  kind: "slide,textbox,image,notes,layout",
  search: "WIDE ATLAS",
  maxChars: 50000,
});
await fs.writeFile(path.join(qaRoot, "after-inspect.ndjson"), afterInspect.ndjson);

for (let i = 105; i < 113; i += 1) {
  const slide = presentation.slides.getItem(i);
  const stem = `slide-${String(i + 1).padStart(3, "0")}`;
  const png = await presentation.export({ slide, format: "png", scale: 1 });
  await fs.writeFile(path.join(qaRoot, `${stem}.png`), new Uint8Array(await png.arrayBuffer()));
  const layout = await slide.export({ format: "layout" });
  await fs.writeFile(path.join(qaRoot, `${stem}.layout.json`), await layout.text());
}
const montage = await presentation.export({
  format: "webp",
  montage: { format: "webp", columns: 4, slideWidth: 300, padding: 20, gap: 14 },
  scale: 1,
});
await fs.writeFile(path.join(qaRoot, "after-montage.webp"), new Uint8Array(await montage.arrayBuffer()));

const pptx = await PresentationFile.exportPptx(presentation);
await pptx.save(deckPath);
console.log(JSON.stringify({ deckPath, finalSlides, qaRoot, inspectRecords: afterInspect.recordCount }));
