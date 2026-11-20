import os
import sys
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from matcher import match  # noqa: E402

NOW = datetime(2026, 10, 10, 12, 0, tzinfo=timezone.utc)


def item(id, type, color, last_worn_days=None):
    return {'id': id, 'type': type, 'color': color,
            'lastWorn': (NOW - timedelta(days=last_worn_days)).isoformat() if last_worn_days is not None else None}


CLOSET = [
    item(1, 'Tshirts', 'red'), item(2, 'Shirts', 'white'), item(3, 'Shirts', 'multicolor'),
    item(4, 'Shirts', 'maroon'), item(5, 'Tshirts', 'black'),
    item(10, 'Pants', 'light blue'), item(11, 'Pants', 'navy'), item(12, 'Pants', 'beige'),
    item(13, 'Pants', 'olive'), item(14, 'Pants', 'multicolor'), item(15, 'Dresses', 'red'),
]


def ranked(anchor_id, **kw):
    return [m['item']['id'] for m in match(anchor_id, CLOSET, now=NOW, **kw)['matches']]


def test_top_gets_pants_and_pants_get_tops():
    assert set(ranked(1)) == {10, 11, 12, 13, 14}
    assert set(ranked(10)) == {1, 2, 3, 4, 5}


def test_dress_has_no_match():
    assert match(15, CLOSET, now=NOW)['error'] == 'complete_look'


def test_red_tshirt_goes_with_jeans_not_olive():
    order = ranked(1)
    assert order[0] == 10
    assert order.index(13) > order.index(11)


def test_print_needs_a_plain_partner():
    order = ranked(3)
    assert order[-1] == 14  # print + print is last
    assert order[0] in (11, 12)  # a plain neutral first


def test_shirt_prefers_trousers_over_print():
    order = ranked(2)
    assert order.index(11) < order.index(14)


def test_recently_worn_pieces_go_to_the_end_and_are_marked():
    closet = CLOSET + [item(16, 'Pants', 'black', last_worn_days=1)]
    result = match(5, closet, now=NOW)
    last = result['matches'][-1]
    assert last['item']['id'] == 16 and last['recently_worn'] is True


def test_occasion_marks_unsuitable_tops():
    result = match(11, CLOSET, occasion='Office', now=NOW)
    tshirt = next(m for m in result['matches'] if m['item']['id'] == 5)
    shirt = next(m for m in result['matches'] if m['item']['id'] == 2)
    assert shirt['match_score'] > tshirt['match_score']
    assert any('Not suitable' in r for r in tshirt['reasons'])


def test_repeat_pair_is_penalised():
    history = [{'date': (NOW - timedelta(days=2)).isoformat(), 'itemIds': [1, 10]}]
    with_repeat = match(1, CLOSET, history=history, now=NOW)['matches']
    jeans = next(m for m in with_repeat if m['item']['id'] == 10)
    assert jeans['breakdown']['repeat_penalty'] > 0


def test_missing_other_half():
    result = match(1, [item(1, 'Tshirts', 'red')], now=NOW)
    assert result['error'] == 'no_candidates'
