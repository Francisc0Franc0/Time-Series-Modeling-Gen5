import fs from "node:fs/promises";
import path from "node:path";
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
const auditRoot = path.join(repoRoot, ".codex_tmp", "full-vocabulary-deck", "source-audit");
const layoutDir = path.join(auditRoot, "source-slide-layouts");
const renderDir = path.join(auditRoot, "source-slide-renders");
await fs.mkdir(layoutDir, { recursive: true });
await fs.mkdir(renderDir, { recursive: true });

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
  const png = await presentation.export({ slide, format: "png", scale: 1 });
  await fs.writeFile(
    path.join(renderDir, `slide-${String(i + 1).padStart(3, "0")}.png`),
    new Uint8Array(await png.arrayBuffer()),
  );
}

const montage = await presentation.export({
  format: "webp",
  montage: { format: "webp", columns: 6, slideWidth: 240, padding: 18, gap: 12 },
  scale: 1,
});
await fs.writeFile(path.join(auditRoot, "source-montage.webp"), new Uint8Array(await montage.arrayBuffer()));

const frameMap = {
  outputSlides: [
    { outputSlide: 114, sourceSlide: 106, narrativeRole: "full-vocabulary transition", reuseMode: "visual-frame", editTargets: [] },
    { outputSlide: 115, sourceSlide: 107, narrativeRole: "measurement grammar", reuseMode: "visual-frame", editTargets: [] },
    { outputSlide: 116, sourceSlide: 112, narrativeRole: "loss branch unfiltered and ER20", reuseMode: "duplicate-and-reframe", editTargets: [] },
    { outputSlide: 117, sourceSlide: 112, narrativeRole: "loss branch ATR states", reuseMode: "visual-frame", editTargets: [] },
    { outputSlide: 118, sourceSlide: 112, narrativeRole: "loss branch signed ER states", reuseMode: "visual-frame", editTargets: [] },
    { outputSlide: 119, sourceSlide: 112, narrativeRole: "gain branch unfiltered and ER20", reuseMode: "duplicate-and-reframe", editTargets: [] },
    { outputSlide: 120, sourceSlide: 112, narrativeRole: "gain branch ATR states", reuseMode: "visual-frame", editTargets: [] },
    { outputSlide: 121, sourceSlide: 112, narrativeRole: "gain branch signed ER states", reuseMode: "visual-frame", editTargets: [] },
    { outputSlide: 122, sourceSlide: 112, narrativeRole: "discriminator synthesis", reuseMode: "duplicate-and-reframe", editTargets: [] },
    { outputSlide: 123, sourceSlide: 113, narrativeRole: "interpretation boundary", reuseMode: "visual-frame", editTargets: [] },
  ],
  omittedSourceSlides: [],
};
await fs.writeFile(path.join(auditRoot, "template-frame-map.json"), JSON.stringify(frameMap, null, 2));

const audit = [
  `Source deck: ${deckPath}`,
  `Source slides inspected: ${presentation.slides.items.length}`,
  "Every source slide was rendered and exported to layout JSON.",
  "Slides 106-113 define the immediate wide-atlas visual and narrative grammar.",
  "Preserve: 16:9 canvas, navy titles, muted gray chrome, white evidence surfaces, restrained accent color, concise footer/page markers, and speaker-note citations.",
  "The appended section uses the same visual grammar while broadening the evidence vocabulary.",
];
await fs.writeFile(path.join(auditRoot, "template-audit.txt"), audit.join("\n"));

const deviations = [
  "- No existing slides will be edited or deleted.",
  "- Ten evidence slides will be appended because the request adds 15 horizons, nine filters, and both prior-sign branches.",
  "- Source slides are used as visual frames; the running deck's earlier code-authored sections do not expose reusable inherited content placeholders for exact clone-and-fill authoring.",
  "- New heatmaps remain raster evidence images; titles, framing, callouts, page markers, and notes remain editable objects.",
  "- The strongest discriminators receive synthesis emphasis only after all filter states are shown fairly.",
];
await fs.writeFile(path.join(auditRoot, "deviation-log.txt"), deviations.join("\n"));

const sourceNotes = [
  "All charts derive from the local full-vocabulary packet.",
  "GICS sector definitions retain the official S&P sources already cited in the running deck.",
  "No external raster assets are added in this section.",
];
await fs.writeFile(path.join(auditRoot, "source-notes.txt"), sourceNotes.join("\n"));

console.log(JSON.stringify({
  auditRoot,
  slides: presentation.slides.items.length,
  inspectRecords: inspect.recordCount,
  inspectTruncated: inspect.truncated,
}));
