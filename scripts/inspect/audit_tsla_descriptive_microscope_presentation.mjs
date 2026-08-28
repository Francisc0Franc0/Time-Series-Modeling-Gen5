import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { pathToFileURL } from "node:url";

const repoRoot = process.cwd();
const artifactEntrypoint = path.join(
  process.env.CODEX_NODE_MODULES ||
    "C:/Users/Franc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules",
  "@oai", "artifact-tool", "dist", "artifact_tool.mjs",
);
const { FileBlob, PresentationFile } = await import(pathToFileURL(artifactEntrypoint).href);

const deckPath = path.join(
  repoRoot, "operator_hypothesis_lab", "presentations", "tsla_descriptive_microscope_evidence.pptx",
);
const auditRoot = path.join(os.tmpdir(), "codex-presentations", "tsla-wide-atlas-audit");
const layoutDir = path.join(auditRoot, "source-slide-layouts");
await fs.mkdir(layoutDir, { recursive: true });

const presentation = await PresentationFile.importPptx(await FileBlob.load(deckPath));
const inspect = await presentation.inspect({
  kind: "slide,textbox,shape,image,table,chart,notes,layout",
  maxChars: 1000000,
});
await fs.writeFile(path.join(auditRoot, "source-deck-inspect.ndjson"), inspect.ndjson);

for (let i = 0; i < presentation.slides.items.length; i += 1) {
  const slide = presentation.slides.getItem(i);
  const layout = await slide.export({ format: "layout" });
  await fs.writeFile(
    path.join(layoutDir, `slide-${String(i + 1).padStart(3, "0")}.layout.json`),
    await layout.text(),
  );
}

const montage = await presentation.export({
  format: "webp",
  montage: { format: "webp", columns: 6, slideWidth: 240, padding: 18, gap: 12 },
  scale: 1,
});
await fs.writeFile(path.join(auditRoot, "source-montage.webp"), new Uint8Array(await montage.arrayBuffer()));

const frameMap = [
  "# Source-frame map",
  "",
  `- Source deck: ${deckPath}`,
  `- Source slides inspected: ${presentation.slides.items.length}`,
  "- Slides 98-105: most recent sparse-boundary-probe section; use as the visual and narrative frame for the appended wide-atlas section.",
  "- Preserve: 16:9 canvas, dark navy title bands, coral section accents, white evidence surfaces, concise decision/footer grammar, and speaker-note citations.",
  "- New section: transition, frozen design, coverage, full signed-down surface, sector diagonal, all-state diagonal, cohort heterogeneity, interpretation/STOP.",
];
await fs.writeFile(path.join(auditRoot, "source-frame-map.md"), frameMap.join("\n"));

const deviations = [
  "# Deviation log",
  "",
  "- No existing slides will be edited or deleted.",
  "- Eight appendix slides will be appended because the approved slice introduces a new atlas, new coverage surface, and new evidence figures.",
  "- New plots remain raster evidence images; titles, framing, callouts, and notes remain editable objects.",
  "- The attention sleeve is visually separated from the GICS core and never presented as a sector.",
  "- Current GICS labels are explicitly described as research metadata, not point-in-time membership.",
];
await fs.writeFile(path.join(auditRoot, "deviation-log.md"), deviations.join("\n"));

console.log(JSON.stringify({
  auditRoot,
  slides: presentation.slides.items.length,
  inspectRecords: inspect.recordCount,
  inspectTruncated: inspect.truncated,
}));
