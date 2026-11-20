"""Outfit recommendation: score every valid outfit and return the best one.

score = 0.35 * colour harmony + 0.30 * freshness + 0.35 * occasion fit - repeat penalty

- Colour harmony: how well the pieces' colours go together (neutral + colour is
  safest, two busy prints clash, etc.).
- Freshness: how long since each piece was last worn. 14+ days (or never worn)
  counts as fully fresh. Pieces worn in the last 2 days are left out entirely.
- Occasion fit: how appropriate the main piece (top or dress) is for the
  occasion, plus whether the colours suit its mood (muted for Office, bold for
  Party, dark and practical for Travel). This is what makes Office, Party, etc.
  give genuinely different outfits.
- Repeat penalty: the exact same combination worn recently scores lower.
- Layer bonus: for Office/Travel, a matching jacket on top wins a tie.

Everything here is plain Python with no Flask/torch imports so it can be unit tested.
"""

from datetime import datetime, timezone

TOPS = {'Tshirts', 'Shirts'}  # kurtas are no longer supported
BOTTOMS = {'Pants'}
ONE_PIECES = {'Dresses'}
OUTERWEAR = {'Outerwear', 'Jackets'}

WEIGHTS = {'color': 0.35, 'freshness': 0.30, 'occasion': 0.35}
FRESH_AFTER_DAYS = 14
RECENTLY_WORN_DAYS = 2

DISPLAY = {
    'Tshirts': 'T-shirt', 'Shirts': 'shirt', 'Kurtas': 'kurta', 'Pants': 'pants',
    'Dresses': 'dress', 'Outerwear': 'jacket', 'Jackets': 'jacket',
}

# How well each type suits each occasion. 0 removes the item for that occasion.
# Pants go with everything, so the main piece (top or dress) decides the fit.
OCCASION_FIT = {
    'Casual': {'Tshirts': 1.0, 'Shirts': 0.65, 'Dresses': 0.75, 'Pants': 1.0, 'Outerwear': 0.6, 'Jackets': 0.6},
    'Office': {'Tshirts': 0.0, 'Shirts': 1.0, 'Dresses': 0.55, 'Pants': 1.0, 'Outerwear': 1.0, 'Jackets': 1.0},
    'Party':  {'Tshirts': 0.35, 'Shirts': 0.75, 'Dresses': 1.0, 'Pants': 1.0, 'Outerwear': 0.0, 'Jackets': 0.0},
    'Travel': {'Tshirts': 1.0, 'Shirts': 0.55, 'Dresses': 0.45, 'Pants': 1.0, 'Outerwear': 0.8, 'Jackets': 0.8},
}
TYPE_WEIGHT_IN_OCCASION = 0.7  # the rest is colour mood

# Colour mood per occasion (default 0.7 for colours not listed).
COLOR_MOOD = {
    'Casual': {},  # anything goes
    'Office': {**dict.fromkeys(['white', 'light blue', 'navy', 'grey', 'dark grey', 'black', 'beige'], 1.0),
               **dict.fromkeys(['red', 'pink', 'yellow', 'orange', 'purple', 'multicolor', 'maroon'], 0.35)},
    'Party':  {**dict.fromkeys(['red', 'maroon', 'black', 'multicolor', 'purple', 'pink', 'teal'], 1.0),
               **dict.fromkeys(['grey', 'beige', 'light blue'], 0.45)},
    'Travel': {**dict.fromkeys(['navy', 'black', 'dark grey', 'olive', 'light blue', 'blue', 'grey'], 1.0),
               **dict.fromkeys(['white', 'beige', 'pink', 'yellow'], 0.45)},
}
MOOD_NOTES = {
    'Office': ('Muted colours look polished at the office', 'Bright colours are bold for the office'),
    'Party': ('Stands out at a party', 'Pale colours are quiet for a party'),
    'Travel': ('Dark, practical colours for travel', 'Light colours show stains when travelling'),
}


def occasion_score(outfit, occasion):
    """(score 0-1, type fit, colour mood) for an outfit at an occasion."""
    fit = OCCASION_FIT.get(occasion, OCCASION_FIT['Casual'])
    mood = COLOR_MOOD.get(occasion, {})
    type_fit = fit.get(outfit[0]['type'], 0)
    if len(outfit) == 3:  # a layer counts a little
        type_fit = 0.8 * type_fit + 0.2 * fit.get(outfit[2]['type'], 0)
    # The top/dress leads the mood, but the pants count too (maroon trousers
    # aren't office wear even under a white shirt).
    main_mood = mood.get(outfit[0].get('color'), 0.7)
    rest = outfit[1:]
    colour_mood = main_mood if not rest else (
        0.55 * main_mood + 0.45 * sum(mood.get(i.get('color'), 0.7) for i in rest) / len(rest))
    return (TYPE_WEIGHT_IN_OCCASION * type_fit + (1 - TYPE_WEIGHT_IN_OCCASION) * colour_mood,
            type_fit, colour_mood)


LAYER_OCCASIONS = {'Office', 'Travel'}
LAYER_BONUS = 0.03
SHOWN_PIECE_PENALTY = 0.10  # per time a piece was already shown this session

NEUTRALS = {'black', 'white', 'grey', 'dark grey', 'beige', 'navy'}
DENIM = {'blue', 'light blue'}  # behaves like a neutral on bottoms (jeans)
GOOD_PAIRS = {
    frozenset(p) for p in [
        ('brown', 'green'), ('brown', 'olive'), ('brown', 'blue'), ('brown', 'light blue'),
        ('olive', 'maroon'), ('pink', 'light blue'), ('pink', 'blue'), ('yellow', 'blue'),
        ('green', 'light blue'), ('red', 'light blue'), ('purple', 'light blue'),
        ('orange', 'blue'), ('maroon', 'light blue'), ('olive', 'light blue'),
        ('teal', 'brown'), ('teal', 'light blue'), ('teal', 'pink'),
    ]
}


def _is_neutral(color, item_type=None):
    return color in NEUTRALS or (color in DENIM and item_type in BOTTOMS)


def color_pair_score(a, b):
    """Score two items' colours together. Returns (score 0-1, explanation)."""
    ca, cb = (a.get('color') or 'unknown'), (b.get('color') or 'unknown')
    na, nb = _is_neutral(ca, a.get('type')), _is_neutral(cb, b.get('type'))

    if 'unknown' in (ca, cb):
        return 0.5, 'One colour is unknown, so colour matching is a guess'
    if ca == 'multicolor' and cb == 'multicolor':
        return 0.15, 'Two busy prints together tend to clash'
    if 'multicolor' in (ca, cb):
        other_neutral = nb if ca == 'multicolor' else na
        if other_neutral:
            return 0.9, 'A plain neutral balances the print'
        return 0.3, 'A print with another strong colour can look busy'
    if na and nb:
        if ca == cb:
            return 0.7, f'Tonal {ca} look'
        return 0.9, f'{ca.capitalize()} and {cb} are an easy neutral pairing'
    if na or nb:
        neutral, colour = (ca, cb) if na else (cb, ca)
        return 1.0, f'{neutral.capitalize()} grounds the {colour}'
    if ca == cb:
        return 0.55, f'{ca.capitalize()} head to toe is bold'
    if frozenset((ca, cb)) in GOOD_PAIRS:
        return 0.8, f'{ca.capitalize()} and {cb} complement each other'
    return 0.35, f'{ca.capitalize()} and {cb} compete for attention'


def _parse_time(value):
    if not value:
        return None
    try:
        dt = datetime.fromisoformat(str(value).replace('Z', '+00:00'))
    except ValueError:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def days_since_worn(item, now):
    worn = _parse_time(item.get('lastWorn'))
    if worn is None:
        return None
    return max((now - worn).total_seconds() / 86400.0, 0.0)


def freshness(item, now):
    days = days_since_worn(item, now)
    if days is None:
        return 1.0
    return min(days / FRESH_AFTER_DAYS, 1.0)


def outfit_key(items):
    return '-'.join(str(i) for i in sorted(int(it['id']) for it in items))


def _repeat_penalty(key, history, now):
    """Penalty if this exact combination was logged recently."""
    best = None
    for entry in history or []:
        ids = entry.get('itemIds') or []
        if isinstance(ids, str):
            ids = [x for x in ids.split(',') if x]
        try:
            entry_key = '-'.join(str(i) for i in sorted(int(x) for x in ids))
        except (TypeError, ValueError):
            continue
        if entry_key != key:
            continue
        when = _parse_time(entry.get('date'))
        if when is None:
            continue
        days = (now - when).total_seconds() / 86400.0
        if best is None or days < best:
            best = days
    if best is None:
        return 0.0, None
    if best < 7:
        return 0.25, best
    if best < 30:
        return 0.1, best
    return 0.0, best


def _label(item):
    colour = item.get('color')
    name = DISPLAY.get(item.get('type'), (item.get('type') or 'item').lower())
    if colour and colour not in ('unknown', 'multicolor'):
        return f'{colour} {name}'
    if colour == 'multicolor':
        return f'printed {name}'
    return name


def _candidates(items, occasion):
    fit = OCCASION_FIT.get(occasion, OCCASION_FIT['Casual'])
    usable = [i for i in items if fit.get(i.get('type'), 0) > 0 and i.get('id') is not None]
    tops = [i for i in usable if i['type'] in TOPS]
    bottoms = [i for i in usable if i['type'] in BOTTOMS]
    dresses = [i for i in usable if i['type'] in ONE_PIECES]
    layers = [i for i in usable if i['type'] in OUTERWEAR] if occasion in LAYER_OCCASIONS else []

    bases = [[t, b] for t in tops for b in bottoms] + [[d] for d in dresses]
    out = []
    for base in bases:
        out.append(base)
        for layer in layers:
            if color_pair_score(base[0], layer)[0] >= 0.8:
                out.append(base + [layer])
    return out


def _score(outfit, occasion, history, now):
    main = outfit[0]

    pair_scores = []
    colour_note = None
    if len(outfit) >= 2:
        s, colour_note = color_pair_score(outfit[0], outfit[1])
        pair_scores.append(s)
        if len(outfit) == 3:
            pair_scores.append(color_pair_score(outfit[0], outfit[2])[0])
        colour = sum(pair_scores) / len(pair_scores)
    else:
        colour = 0.85  # a dress is a complete look on its own
        colour_note = 'A dress is a complete look on its own'

    fresh = sum(freshness(i, now) for i in outfit) / len(outfit)
    occ, type_fit, colour_mood = occasion_score(outfit, occasion)
    key = outfit_key(outfit)
    penalty, repeat_days = _repeat_penalty(key, history, now)

    # A matching layer completes an office/travel look, so it wins ties.
    layer_bonus = LAYER_BONUS if len(outfit) == 3 else 0.0
    shown_score = max(0.0, min(1.0, WEIGHTS['color'] * colour + WEIGHTS['freshness'] * fresh
                               + WEIGHTS['occasion'] * occ - penalty))
    total = shown_score + layer_bonus  # the bonus only affects ranking, not the % shown

    reasons = [colour_note]
    fresh_notes = []
    for item in outfit:
        days = days_since_worn(item, now)
        if days is None:
            fresh_notes.append(f'You haven\'t worn the {_label(item)} yet')
        elif days >= FRESH_AFTER_DAYS:
            verb = 'haven\'t' if item['type'] in BOTTOMS else 'hasn\'t'
            fresh_notes.append(f'The {_label(item)} {verb} been worn in {int(days)} days')
    reasons.extend(fresh_notes[:2])
    piece = DISPLAY.get(main['type'], main['type']).capitalize()
    if type_fit >= 0.9:
        reasons.append(f'{piece} suits {occasion.lower()}')
    elif type_fit >= 0.6:
        reasons.append(f'{piece} works for {occasion.lower()}')
    else:
        reasons.append(f'{piece} is a stretch for {occasion.lower()}, but it\'s the best match you have')
    if occasion in MOOD_NOTES:
        good, bad = MOOD_NOTES[occasion]
        if colour_mood >= 0.95:
            reasons.append(good)
        elif colour_mood <= 0.5:
            reasons.append(bad)
    if repeat_days is not None and penalty > 0:
        reasons.append(f'You wore this exact outfit {int(repeat_days)} days ago')
    if len(outfit) == 3:
        reasons.append(f'Layered with your {_label(outfit[2])}')

    return {
        'key': key,
        'score': total,
        'match_score': round(shown_score * 100),
        'breakdown': {
            'color': round(colour * 100),
            'freshness': round(fresh * 100),
            'occasion': round(occ * 100),
            'repeat_penalty': round(penalty * 100),
        },
        'reasons': reasons,
    }


def missing_pieces_message(items, occasion):
    fit = OCCASION_FIT.get(occasion, OCCASION_FIT['Casual'])
    usable = [i for i in items if fit.get(i.get('type'), 0) > 0]
    has_top = any(i['type'] in TOPS for i in usable)
    has_bottom = any(i['type'] in BOTTOMS for i in usable)
    has_dress = any(i['type'] in ONE_PIECES for i in usable)
    if has_dress or (has_top and has_bottom):
        return None
    if not has_top and not has_bottom:
        need = 'a top and a pair of pants, or a dress'
    elif not has_top:
        need = 'a top (T-shirt or shirt)' if occasion != 'Office' else 'a shirt'
    else:
        need = 'a pair of pants'
    return f'Add {need} to your closet to get a {occasion.lower()} outfit.'


def recommend(items, occasion='Casual', history=None, exclude_keys=None, now=None):
    """Return the best outfit and its explanation, or an error dict."""
    now = now or datetime.now(timezone.utc)
    occasion = occasion if occasion in OCCASION_FIT else 'Casual'
    items = [i for i in (items or []) if i.get('type')]

    if not items:
        return {'error': 'empty_closet', 'message': 'Your closet is empty. Add some clothes first.'}

    candidates = _candidates(items, occasion)
    if not candidates:
        return {'error': 'missing_pieces',
                'message': missing_pieces_message(items, occasion)
                or f'Nothing in your closet suits {occasion.lower()} yet.'}

    def recently_worn(outfit):
        return any((d := days_since_worn(i, now)) is not None and d < RECENTLY_WORN_DAYS for i in outfit)

    fresh_candidates = [c for c in candidates if not recently_worn(c)]
    relaxed = not fresh_candidates
    pool = candidates if relaxed else fresh_candidates

    scored = sorted(
        ((c, _score(c, occasion, history, now)) for c in pool),
        key=lambda pair: (-pair[1]['score'], pair[1]['key']),
    )

    shown = set(exclude_keys or [])
    remaining = [pair for pair in scored if pair[1]['key'] not in shown]
    cycled = not remaining
    if cycled:
        remaining = scored
    elif shown:
        # "Show another" should feel different, not the same top with other
        # pants: rank down pieces that were in outfits already shown. This only
        # changes the order; the match score shown to the user is unchanged.
        seen = {}
        for key in shown:
            for part in key.split('-'):
                seen[part] = seen.get(part, 0) + 1
        remaining.sort(key=lambda pair: (
            -(pair[1]['score'] - SHOWN_PIECE_PENALTY * sum(seen.get(str(i['id']), 0) for i in pair[0])),
            pair[1]['key']))

    outfit, result = remaining[0]
    reasons = result['reasons']
    if relaxed:
        reasons = reasons + ['Everything that fits was worn in the last 2 days, so this repeats something recent']

    return {
        'suggestion': outfit,
        'key': result['key'],
        'match_score': result['match_score'],
        'breakdown': result['breakdown'],
        'reasons': reasons,
        'reason': reasons[0],
        'occasion': occasion,
        'options_left': len(remaining) - 1,
        'cycled': cycled,
    }
