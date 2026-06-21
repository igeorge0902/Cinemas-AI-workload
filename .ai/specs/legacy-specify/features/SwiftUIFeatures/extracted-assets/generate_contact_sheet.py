import math
from pathlib import Path

import cv2
import numpy as np

ROOT = Path("/Users/gyorgy.gaspar/work/cinemas/cinemas/.specify/features/SwiftUIFeatures/extracted-assets")
OUT = ROOT / "contact-sheet.png"

# Preferred visual order for review.
ORDER = [
    "required/navigation",
    "required/favorite",
    "required/actions",
    "required/placeholder",
    "optional/metadata",
]

CELL_W = 260
CELL_H = 200
PADDING = 24
LABEL_H = 44
BG = (245, 245, 245, 255)
TEXT = (20, 20, 20, 255)
BORDER = (210, 210, 210, 255)


def load_items():
    items = []
    for category in ORDER:
        folder = ROOT / category
        if not folder.exists():
            continue
        for path in sorted(folder.glob("*.png")):
            items.append((category, path))
    return items


def fit_image(img, max_w, max_h):
    h, w = img.shape[:2]
    if w == 0 or h == 0:
        return img
    scale = min(max_w / w, max_h / h)
    new_w = max(1, int(w * scale))
    new_h = max(1, int(h * scale))
    return cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)


def alpha_blit(dst, src, x, y):
    h, w = src.shape[:2]
    roi = dst[y:y + h, x:x + w]

    if src.shape[2] == 4:
        alpha = src[:, :, 3:4].astype(np.float32) / 255.0
        src_rgb = src[:, :, :3].astype(np.float32)
        roi_rgb = roi[:, :, :3].astype(np.float32)
        out_rgb = src_rgb * alpha + roi_rgb * (1.0 - alpha)
        roi[:, :, :3] = out_rgb.astype(np.uint8)
        roi[:, :, 3] = 255
    else:
        roi[:, :, :3] = src[:, :, :3]
        roi[:, :, 3] = 255


def main():
    items = load_items()
    if not items:
        raise SystemExit("No extracted PNG assets found.")

    cols = 4
    rows = math.ceil(len(items) / cols)

    width = PADDING + cols * CELL_W + (cols - 1) * PADDING + PADDING
    height = PADDING + rows * CELL_H + (rows - 1) * PADDING + PADDING

    canvas = np.zeros((height, width, 4), dtype=np.uint8)
    canvas[:, :] = BG

    font = cv2.FONT_HERSHEY_SIMPLEX

    for i, (category, path) in enumerate(items):
        r = i // cols
        c = i % cols
        x = PADDING + c * (CELL_W + PADDING)
        y = PADDING + r * (CELL_H + PADDING)

        cv2.rectangle(canvas, (x, y), (x + CELL_W, y + CELL_H), BORDER, 1)

        name = path.stem
        category_short = category.split("/")[-1]
        label = f"{category_short}: {name}"
        cv2.putText(canvas, label[:40], (x + 8, y + 24), font, 0.5, TEXT, 1, cv2.LINE_AA)

        img = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
        if img is None:
            continue

        display = fit_image(img, CELL_W - 20, CELL_H - LABEL_H - 20)
        dh, dw = display.shape[:2]
        px = x + (CELL_W - dw) // 2
        py = y + LABEL_H + (CELL_H - LABEL_H - dh) // 2

        if display.shape[2] == 3:
            alpha = np.full((dh, dw, 1), 255, dtype=np.uint8)
            display = np.concatenate([display, alpha], axis=2)

        alpha_blit(canvas, display, px, py)

    cv2.imwrite(str(OUT), canvas)
    print(str(OUT))


if __name__ == "__main__":
    main()

