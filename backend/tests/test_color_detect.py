import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from color_detect import SWATCHES, _to_lab, detect_color, name_color  # noqa: E402


def cutout(regions, size=120):
    """RGBA image: transparent background, garment made of (rgb, fraction) stripes."""
    arr = np.zeros((size, size, 4), dtype=np.uint8)
    top = 10
    usable = size - 20
    for rgb, fraction in regions:
        h = int(usable * fraction)
        arr[top:top + h, 20:size - 20, :3] = rgb
        arr[top:top + h, 20:size - 20, 3] = 255
        top += h
    return Image.fromarray(arr, 'RGBA')


def name_of(rgb):
    return name_color(_to_lab(np.array([rgb], dtype=np.uint8))[0])


def test_every_swatch_names_itself():
    for name, rgb in SWATCHES.items():
        assert name_of(rgb) == name, name


def test_warm_lit_white_is_white_not_beige():
    assert name_of((215, 200, 178)) == 'white'      # white shirt under a yellow bulb
    assert name_of((175, 160, 135)) == 'beige'      # khaki shorts


def test_faint_blue_grey_is_denim():
    assert name_of((132, 145, 152)) == 'light blue'
    assert name_of((132, 140, 138)) == 'grey'


def test_solid_garment():
    color, _ = detect_color(cutout([((190, 35, 45), 1.0)]))
    assert color == 'red'


def test_shadow_does_not_make_it_multicolor():
    color, _ = detect_color(cutout([((240, 240, 238), 0.6), ((185, 185, 183), 0.4)]))
    assert color == 'white'


def test_black_and_white_print_is_multicolor():
    color, _ = detect_color(cutout([((25, 25, 25), 0.55), ((240, 240, 240), 0.45)]))
    assert color == 'multicolor'


def test_small_logo_does_not_make_it_multicolor():
    color, _ = detect_color(cutout([((25, 25, 25), 0.9), ((200, 30, 30), 0.1)]))
    assert color == 'black'


def test_empty_cutout_is_unknown():
    assert detect_color(Image.new('RGBA', (50, 50)))[0] == 'unknown'
