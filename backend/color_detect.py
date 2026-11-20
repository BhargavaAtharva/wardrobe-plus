"""Dominant colour detection for a background-removed clothing photo.

Approach (replaces the old HSV-average heuristic):
1. Keep only clothing pixels, using the alpha mask from background removal.
2. Cluster those pixels in CIELAB space with k-means (k=3). Lab separates
   lightness (L) from colour (a/b), which matches how people see colour.
3. Name the biggest cluster with rules on lightness, chroma (how colourful)
   and hue angle. The rules are tuned for phone photos under indoor light:
   whites come out warm/yellowish and light denim is only faintly blue.
4. Call the item "multicolor" when another large cluster is clearly a
   different colour (different hue, or black vs white), not just a shadow.
"""

import cv2
import numpy as np

COLOR_NAMES = [
    'black', 'dark grey', 'grey', 'white', 'beige', 'brown', 'navy', 'blue',
    'light blue', 'teal', 'green', 'olive', 'red', 'maroon', 'pink', 'purple',
    'yellow', 'orange', 'multicolor',
]

# Approximate swatch colours (RGB) for each name; the app shows these.
SWATCHES = {
    'black': (30, 30, 32), 'dark grey': (75, 75, 78), 'grey': (150, 150, 152),
    'white': (245, 245, 242), 'beige': (200, 178, 140), 'brown': (115, 78, 50),
    'navy': (38, 48, 85), 'blue': (50, 90, 170), 'light blue': (150, 180, 215),
    'teal': (30, 128, 128), 'green': (60, 125, 75), 'olive': (110, 110, 60),
    'red': (190, 35, 45), 'maroon': (110, 32, 45), 'pink': (232, 150, 180),
    'purple': (110, 65, 140), 'yellow': (232, 200, 65), 'orange': (228, 120, 45),
}

_MIN_PIXELS = 200          # fewer clothing pixels than this -> "unknown"
_SAMPLE_PIXELS = 6000      # pixels fed to k-means (speed)
_MAJOR_SHARE = 0.22        # a cluster must cover this much to count as a 2nd colour
_CHROMA_COLORED = 18       # chroma above this means "has a real hue"


def _to_lab(rgb_pixels):
    """uint8 Nx3 RGB -> float Nx3 Lab with L in 0-100, a/b roughly -128..127."""
    lab = cv2.cvtColor(rgb_pixels.reshape(-1, 1, 3).astype(np.uint8), cv2.COLOR_RGB2LAB)
    lab = lab.reshape(-1, 3).astype(np.float32)
    lab[:, 0] = lab[:, 0] * 100.0 / 255.0
    lab[:, 1:] -= 128.0
    return lab


def _chroma(lab):
    return float(np.hypot(lab[1], lab[2]))


def _hue(lab):
    return float(np.degrees(np.arctan2(lab[2], lab[1])) % 360)


def name_color(lab):
    """Name one Lab colour (L 0-100)."""
    L, chroma, hue = float(lab[0]), _chroma(lab), _hue(lab)

    if chroma < 8:
        # Grey-ish. A faint blue tint is how denim and navy look in photos.
        if chroma >= 2.5 and 200 <= hue <= 300 and 25 <= L <= 70:
            return 'light blue' if L > 52 else 'navy'
        if L >= 85:
            return 'white'
        if L >= 45:
            return 'grey'
        if L >= 28:
            return 'dark grey'
        return 'black'

    if chroma < 22 and 50 <= hue <= 110:
        # Warm, low-colour: warm-lit white, cream/beige, khaki, brown.
        if L >= 74:
            return 'white'
        if L >= 55:
            return 'beige'
        if L >= 25:
            return 'brown'
        return 'black'

    if chroma < 12 and 200 <= hue <= 300:
        return 'light blue' if L > 52 else 'navy'

    if hue >= 345 or hue < 50:
        if L > 65 and chroma < 55:
            return 'pink'
        return 'maroon' if L < 35 else 'red'
    if hue < 75:
        return 'brown' if L < 45 else 'orange'
    if hue < 105:
        if L < 45:
            return 'olive' if hue > 85 else 'brown'
        return 'yellow' if chroma >= 35 else 'beige'
    if hue < 135:
        return 'olive' if chroma < 40 or L < 50 else 'green'
    if hue < 170:
        return 'green'
    if hue < 230:
        return 'teal'
    if hue < 300:
        if L < 30:
            return 'navy'
        return 'light blue' if L > 65 else 'blue'
    return 'pink' if L > 70 else 'purple'


def _clearly_different(c1, c2):
    """True when two cluster centres are different colours, not shades of one."""
    colored1 = _chroma(c1) > _CHROMA_COLORED
    colored2 = _chroma(c2) > _CHROMA_COLORED
    if colored1 and colored2:
        diff = abs(_hue(c1) - _hue(c2))
        return min(diff, 360 - diff) > 60
    if colored1 != colored2:
        # e.g. red print on white, black pattern on yellow
        return float(np.linalg.norm(c1 - c2)) > 45
    # Both neutral: only black-vs-white contrast counts (zebra prints),
    # not a white shirt with grey shadows.
    return abs(float(c1[0]) - float(c2[0])) > 55


def detect_color(rgba_image):
    """Return (color_name, details) for a PIL RGBA image with a cut-out alpha mask."""
    arr = np.array(rgba_image.convert('RGBA'))
    pixels = arr[:, :, :3][arr[:, :, 3] > 160]
    if len(pixels) < _MIN_PIXELS:
        return 'unknown', {}

    if len(pixels) > _SAMPLE_PIXELS:
        rng = np.random.default_rng(0)
        pixels = pixels[rng.choice(len(pixels), _SAMPLE_PIXELS, replace=False)]

    lab = _to_lab(pixels)
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.5)
    cv2.setRNGSeed(0)
    _, labels, centers = cv2.kmeans(lab, 3, None, criteria, 4, cv2.KMEANS_PP_CENTERS)
    shares = np.bincount(labels.flatten(), minlength=3) / len(labels)
    order = np.argsort(-shares)
    centers, shares = centers[order], shares[order]

    clusters = [{'color': name_color(c), 'share': round(float(s), 3)}
                for c, s in zip(centers, shares)]

    for i in range(1, 3):
        if shares[i] >= _MAJOR_SHARE and _clearly_different(centers[0], centers[i]):
            return 'multicolor', {'clusters': clusters}

    return clusters[0]['color'], {'clusters': clusters}
