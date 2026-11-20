"""Find a match: given one top or one pair of pants, rank every piece of the
other kind in the closet by how well it goes with it.

pair score = 0.45 colour + 0.25 style + 0.15 freshness + 0.15 occasion - repeat penalty
(with no occasion chosen, the occasion share goes to colour and style)

- Colour: the outfit colour rules from recommender.py (neutral + colour is
  safest, prints need a plain partner, ...) blended with light/dark contrast:
  black + white is classic, grey on grey looks flat.
- Style: how dressy each piece is. A shirt is smarter than a T-shirt;
  dark trousers are smarter than light denim. Pieces at a similar level match
  best (shirt + navy trousers, T-shirt + jeans); a dressier top over jeans is
  fine (smart-casual), a T-shirt with formal trousers is marked down more.
- Freshness: prefers pieces you haven't worn lately; pieces worn in the last
  2 days still appear, but lower and marked.
- Occasion (optional): how well the pair suits it, same rules as the outfit generator.
"""

from datetime import datetime, timezone

from recommender import (
    BOTTOMS, DISPLAY, ONE_PIECES, OUTERWEAR, RECENTLY_WORN_DAYS, TOPS, _label,
    _repeat_penalty, color_pair_score, days_since_worn, freshness, occasion_score, outfit_key,
)

# Approximate lightness (CIELAB L*, 0 = black, 100 = white) of each colour name.
LIGHTNESS = {
    'black': 12, 'dark grey': 32, 'grey': 60, 'white': 96, 'beige': 74, 'brown': 38,
    'navy': 20, 'blue': 40, 'light blue': 70, 'teal': 48, 'green': 47, 'olive': 46,
    'red': 42, 'maroon': 25, 'pink': 70, 'purple': 35, 'yellow': 82, 'orange': 62,
    'multicolor': 50,
}

# How dressy a piece is, 0 = very casual, 1 = formal.
TOP_FORMALITY = {'Tshirts': 0.25, 'Shirts': 0.8}
DENIM_COLORS = {'light blue', 'blue'}
SMART_BOTTOM_COLORS = {'black', 'navy', 'grey', 'dark grey', 'beige', 'brown', 'olive'}


def bottom_formality(item):
    color = item.get('color')
    if color in DENIM_COLORS:
        return 0.3   # jeans
    if color in SMART_BOTTOM_COLORS:
        return 0.7   # trousers / chinos (or dark jeans — we can't tell from colour)
    return 0.5


def formality(item):
    if item.get('type') in BOTTOMS:
        return bottom_formality(item)
    return TOP_FORMALITY.get(item.get('type'), 0.5)


def contrast_score(a, b):
    """1.0 for a clear light/dark contrast, lower for two pieces of similar lightness."""
    la, lb = LIGHTNESS.get(a.get('color'), 50), LIGHTNESS.get(b.get('color'), 50)
    return min(abs(la - lb) / 40.0, 1.0)


def _style_note(top, bottom, style):
    t, b = DISPLAY.get(top['type'], 'top'), _label(bottom)
    if style >= 0.85:
        return f'The {t} and {b} sit at the same level of dressiness'
    if formality(top) > formality(bottom):
        return f'The {t} dresses up the {b} — a smart-casual look'
    return f'The {b} is dressier than the {t}, which can look mismatched'


def score_pair(anchor, other, occasion=None, history=None, now=None):
    now = now or datetime.now(timezone.utc)
    top, bottom = (anchor, other) if anchor['type'] in TOPS else (other, anchor)

    harmony, colour_note = color_pair_score(top, bottom)
    contrast = contrast_score(top, bottom)
    colour = 0.75 * harmony + 0.25 * contrast
    gap = formality(top) - formality(bottom)
    # A dressier top over casual pants is classic smart-casual (white shirt +
    # jeans); a casual top with formal trousers looks off, so it costs more.
    style = 1.0 - (0.5 * gap if gap > 0 else 0.8 * -gap)
    fresh = freshness(other, now)

    if occasion:
        occ, type_fit, _ = occasion_score([top, bottom], occasion)
        weights = {'color': 0.45, 'style': 0.25, 'freshness': 0.15, 'occasion': 0.15}
    else:
        occ, type_fit = None, None
        weights = {'color': 0.55, 'style': 0.30, 'freshness': 0.15, 'occasion': 0.0}

    key = outfit_key([top, bottom])
    penalty, repeat_days = _repeat_penalty(key, history, now)
    total = (weights['color'] * colour + weights['style'] * style + weights['freshness'] * fresh
             + weights['occasion'] * (occ or 0) - penalty)
    total = max(0.0, min(1.0, total))

    reasons = [colour_note]
    if contrast >= 0.9 and harmony >= 0.85:
        reasons.append('Strong light/dark contrast keeps it crisp')
    elif contrast < 0.3 and harmony < 1.0:
        reasons.append('Both pieces are a similar shade, so the look is a bit flat')
    reasons.append(_style_note(top, bottom, style))
    days = days_since_worn(other, now)
    if days is None:
        reasons.append(f'You haven\'t worn the {_label(other)} yet')
    elif days < RECENTLY_WORN_DAYS:
        reasons.append(f'You wore the {_label(other)} in the last 2 days')
    elif days >= 14:
        reasons.append(f'The {_label(other)} hasn\'t been worn in {int(days)} days')
    if occasion and type_fit is not None and type_fit == 0:
        reasons.append(f'Not suitable for {occasion.lower()}')
    if repeat_days is not None and penalty > 0:
        reasons.append(f'You wore this exact pair {int(repeat_days)} days ago')

    return {
        'item': other,
        'key': key,
        'score': total,
        'match_score': round(total * 100),
        'breakdown': {
            'color': round(colour * 100),
            'style': round(style * 100),
            'freshness': round(fresh * 100),
            **({'occasion': round(occ * 100)} if occasion else {}),
            'repeat_penalty': round(penalty * 100),
        },
        'recently_worn': days is not None and days < RECENTLY_WORN_DAYS,
        'reasons': reasons,
    }


def match(anchor_id, items, occasion=None, history=None, now=None, limit=None):
    """Rank pieces that go with the item `anchor_id`. Returns a dict for the API."""
    now = now or datetime.now(timezone.utc)
    by_id = {str(i.get('id')): i for i in items or [] if i.get('id') is not None}
    anchor = by_id.get(str(anchor_id))
    if anchor is None:
        return {'error': 'not_found', 'message': 'That item is no longer in your closet.'}

    kind = anchor.get('type')
    if kind in ONE_PIECES:
        return {'error': 'complete_look', 'message': 'A dress is a complete outfit on its own.'}
    if kind in OUTERWEAR:
        return {'error': 'unsupported', 'message': 'Matching works for tops and pants.'}
    if kind in TOPS:
        wanted, wanted_label = BOTTOMS, 'pants'
    elif kind in BOTTOMS:
        wanted, wanted_label = TOPS, 'tops'
    else:
        return {'error': 'unsupported', 'message': 'Matching works for tops and pants.'}

    candidates = [i for i in by_id.values() if i.get('type') in wanted]
    if not candidates:
        return {'error': 'no_candidates', 'message': f'Add some {wanted_label} to your closet to find a match.'}

    ranked = sorted((score_pair(anchor, c, occasion, history, now) for c in candidates),
                    key=lambda r: (r['recently_worn'], -r['score'], r['key']))
    if limit:
        ranked = ranked[:limit]
    return {'anchor': anchor, 'looking_for': wanted_label, 'occasion': occasion, 'matches': ranked}
