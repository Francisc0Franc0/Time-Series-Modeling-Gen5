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
const qaRoot = path.join(os.tmpdir(), "codex-presentations", "tsla-wide-atlas-repair");
await fs.mkdir(qaRoot, { recursive: true });

const presentation = await PresentationFile.importPptx(await FileBlob.load(deckPath));
if (presentation.slides.items.length !== 113) {
  throw new Error(`Expected the 113-slide running deck; found ${presentation.slides.items.length}.`);
}

function recordsFrom(ndjson) {
  return ndjson.split(/\r?\n/).filter(Boolean).map((line) => JSON.parse(line));
}

async function findTextShape(slideNumber, exactTexts) {
  const candidates = Array.isArray(exactTexts) ? exactTexts : [exactTexts];
  for (const exactText of candidates) {
    const result = await presentation.inspect({
      kind: "textbox,shape",
      search: exactText,
      include: "id,slide,text,textPreview,bbox",
      maxChars: 10000,
    });
    const record = recordsFrom(result.ndjson).find((item) =>
      item.slide === slideNumber && (item.text === exactText || item.textPreview === exactText));
    if (record?.id) return presentation.resolve(record.id);
  }
  throw new Error(`Could not resolve '${candidates.join("' or '")}' on slide ${slideNumber}.`);
}

const slide111Title = await findTextShape(111, "The template discriminates among regime states");
slide111Title.text.style = { fontSize: 42, bold: true, color: "#111827" };
slide111Title.position = { left: 48, top: 56, width: 1184, height: 62 };

const slide111Page = await findTextShape(111, ["111", "1\u20091\u20091"]);
slide111Page.text = "1\u20091\u20091";

const slide113Title = await findTextShape(113, [
  "Decision: broad transport survives—edge remains unopened",
  "Broad transport survives; edge remains unopened",
]);
slide113Title.text = "Broad transport survives; edge remains unopened";
slide113Title.text.style = { fontSize: 43, bold: true, color: "#111827" };
slide113Title.position = { left: 48, top: 56, width: 1184, height: 62 };

const slide113Page = await findTextShape(113, ["113", "1\u20091\u20093"]);
slide113Page.text = "";

const slide113 = presentation.slides.getItem(112);
const sectionOverlay = slide113.shapes.add({
  geometry: "textbox",
  name: "wide-atlas-section-overlay",
  position: { left: 48, top: 24, width: 440, height: 24 },
  fill: "none",
  line: { style: "solid", fill: "none", width: 0 },
});
sectionOverlay.text = "WIDE ATLAS";
sectionOverlay.text.style = { fontSize: 16, bold: true, color: "#667384" };

const pageOverlay = slide113.shapes.add({
  geometry: "textbox",
  name: "wide-atlas-page-overlay",
  position: { left: 1180, top: 682, width: 52, height: 20 },
  fill: "none",
  line: { style: "solid", fill: "none", width: 0 },
});
pageOverlay.text = "113";
pageOverlay.text.style = { fontSize: 12, color: "#667384", alignment: "right" };

for (const slideNumber of [111, 113]) {
  const slide = presentation.slides.getItem(slideNumber - 1);
  const png = await presentation.export({ slide, format: "png", scale: 1 });
  await fs.writeFile(
    path.join(qaRoot, `slide-${slideNumber}.png`),
    new Uint8Array(await png.arrayBuffer()),
  );
  const layout = await slide.export({ format: "layout" });
  await fs.writeFile(path.join(qaRoot, `slide-${slideNumber}.layout.json`), await layout.text());
}

const pptx = await PresentationFile.exportPptx(presentation);
await pptx.save(deckPath);
console.log(JSON.stringify({ deckPath, repairedSlides: [111, 113], qaRoot }));
