import { createRequire } from "node:module";
import { readdirSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const landingRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(import.meta.url);

function loadSharp() {
  try {
    return require("sharp");
  } catch {
    const store = join(landingRoot, "node_modules", ".pnpm");
    const entry = readdirSync(store).find((name) => name.startsWith("sharp@"));
    if (!entry) throw new Error("sharp not found; run pnpm install first");
    return require(join(store, entry, "node_modules", "sharp"));
  }
}

const sharp = loadSharp();
const screensDir = join(landingRoot, "public", "screens");
const files = readdirSync(screensDir).filter((name) => name.endsWith(".png"));

for (const file of files) {
  const path = join(screensDir, file);
  const { data, info } = await sharp(path)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const { width, height, channels } = info;
  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      if (data[(y * width + x) * channels + 3] >= 250) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) {
    console.log(`${file}: fully transparent, skipped`);
    continue;
  }
  const cropWidth = maxX - minX + 1;
  const cropHeight = maxY - minY + 1;
  if (cropWidth === width && cropHeight === height) {
    console.log(`${file}: already tight (${width}x${height})`);
    continue;
  }
  const output = await sharp(path)
    .extract({ left: minX, top: minY, width: cropWidth, height: cropHeight })
    .png({ compressionLevel: 9 })
    .toBuffer();
  writeFileSync(path, output);
  console.log(
    `${file}: ${width}x${height} -> ${cropWidth}x${cropHeight}, update lib/content.ts to width: ${cropWidth}, height: ${cropHeight}`
  );
}
