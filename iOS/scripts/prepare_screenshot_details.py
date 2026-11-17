"""Enlarge the actual highlighted line, retaining the captured pixels and text."""

import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "build/screenshots-2026-11-17"
count = 0
for source in (ROOT / "raw").glob("*/*/playing.png"):
    device, locale = source.parent.parent.name, source.parent.name
    image = Image.open(source).convert("RGB")
    pixels = np.asarray(image)
    mask = ((pixels[:, :, 0] > 230) & (pixels[:, :, 1] > 150)
            & (pixels[:, :, 1] < 225) & (pixels[:, :, 2] < 90))
    mask[:180] = False
    mask[int(image.height * 0.8):] = False
    y, x = np.where(mask)
    assert len(x) >= 20, f"Missing highlighted sample text: {device}/{locale}"
    top, bottom = max(0, int(y.min()) - 16), min(image.height, int(y.max()) + 17)
    assert bottom - top < 250, f"Unexpected multiple highlights: {device}/{locale}"
    target = ROOT / "details" / device / locale
    target.mkdir(parents=True, exist_ok=True)
    image.crop((40, top, image.width - 40, bottom)).save(target / "playing.png")
    (target / "playing.json").write_text(json.dumps({"centerY": (top + bottom) / 2 / image.height,
        "source": str(source.relative_to(ROOT)), "crop": [40, top, image.width - 40, bottom]}) + "\n")
    count += 1
print("Actual highlight-line details prepared:", count)
