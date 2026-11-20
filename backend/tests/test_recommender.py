import os
import sys
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from recommender import color_pair_score, freshness, recommend  # noqa: E402

NOW = datetime(2026, 10, 8, 12, 0, tzinfo=timezone.utc)


def ago(days):
    return (NOW - timedelta(days=days)).isoformat()


def item(id, type, color, last_worn_days=None):
    return {'id': id, 'type': type, 'color': color,
            'lastWorn': ago(last_worn_days) if last_worn_days is not None else None}


def test_empty_closet_is_an_error():
    result = recommend([], now=NOW)
    assert result['error'] == 'empty_closet'


def test_tops_only_explains_what_is_missing():
    result = recommend([item(1, 'Tshirts', 'white')], now=NOW)
    assert result['error'] == 'missing_pieces'
    assert 'pants' in result['message']


def test_office_excludes_tshirts():
    items = [item(1, 'Tshirts', 'white'), item(2, 'Pants', 'navy')]
    result = recommend(items, occasion='Office', now=NOW)
    assert result['error'] == 'missing_pieces'
    assert 'a shirt' in result['message']


def test_neutral_with_colour_beats_clashing_colours():
    assert color_pair_score({'color': 'red', 'type': 'Tshirts'}, {'color': 'black', 'type': 'Pants'})[0] == 1.0
    assert color_pair_score({'color': 'red', 'type': 'Tshirts'}, {'color': 'green', 'type': 'Pants'})[0] < 0.5
    assert color_pair_score({'color': 'multicolor', 'type': 'Shirts'}, {'color': 'multicolor', 'type': 'Pants'})[0] < 0.2


def test_denim_counts_as_neutral_on_bottoms_only():
    assert color_pair_score({'color': 'red', 'type': 'Tshirts'}, {'color': 'light blue', 'type': 'Pants'})[0] == 1.0
    assert color_pair_score({'color': 'light blue', 'type': 'Shirts'}, {'color': 'red', 'type': 'Shirts'})[0] < 1.0


def test_freshness_grows_with_days_since_worn():
    assert freshness(item(1, 'Tshirts', 'white'), NOW) == 1.0          # never worn
    assert freshness(item(1, 'Tshirts', 'white', 7), NOW) == 0.5
    assert freshness(item(1, 'Tshirts', 'white', 30), NOW) == 1.0


def test_long_unworn_item_is_preferred_over_recently_worn_one():
    items = [
        item(1, 'Tshirts', 'white', last_worn_days=3),
        item(2, 'Tshirts', 'white', last_worn_days=20),
        item(3, 'Pants', 'black', last_worn_days=20),
    ]
    result = recommend(items, now=NOW)
    assert [i['id'] for i in result['suggestion']] == [2, 3]
    assert any('20 days' in r for r in result['reasons'])


def test_items_worn_in_last_two_days_are_skipped():
    items = [
        item(1, 'Tshirts', 'white', last_worn_days=0.5),
        item(2, 'Tshirts', 'grey', last_worn_days=10),
        item(3, 'Pants', 'black', last_worn_days=10),
    ]
    result = recommend(items, now=NOW)
    assert 1 not in [i['id'] for i in result['suggestion']]


def test_falls_back_when_everything_was_worn_recently():
    items = [item(1, 'Tshirts', 'white', 1), item(2, 'Pants', 'black', 1)]
    result = recommend(items, now=NOW)
    assert [i['id'] for i in result['suggestion']] == [1, 2]
    assert any('last 2 days' in r for r in result['reasons'])


def test_exact_repeat_is_penalised():
    items = [item(1, 'Shirts', 'white', 10), item(2, 'Shirts', 'white', 10), item(3, 'Pants', 'navy', 10)]
    history = [{'date': ago(3), 'itemIds': [1, 3]}]
    result = recommend(items, history=history, now=NOW)
    assert result['key'] == '2-3'


def test_generate_again_never_repeats_until_options_run_out():
    items = [item(1, 'Tshirts', 'white'), item(2, 'Tshirts', 'black'), item(3, 'Pants', 'navy')]
    first = recommend(items, now=NOW)
    second = recommend(items, exclude_keys=[first['key']], now=NOW)
    assert second['key'] != first['key']
    third = recommend(items, exclude_keys=[first['key'], second['key']], now=NOW)
    assert third['cycled'] is True


def test_match_score_is_computed_not_hardcoded():
    good = recommend([item(1, 'Tshirts', 'red'), item(2, 'Pants', 'black')], now=NOW)
    bad = recommend([item(1, 'Tshirts', 'red'), item(2, 'Pants', 'green', last_worn_days=5)], now=NOW)
    assert good['match_score'] > bad['match_score']
    assert good['breakdown']['color'] == 100


def test_dress_is_a_complete_outfit():
    result = recommend([item(1, 'Dresses', 'red')], occasion='Party', now=NOW)
    assert [i['id'] for i in result['suggestion']] == [1]


def test_outerwear_layered_for_office_only():
    items = [item(1, 'Shirts', 'white'), item(2, 'Pants', 'navy'), item(3, 'Outerwear', 'black')]
    office = recommend(items, occasion='Office', now=NOW)
    party = recommend(items, occasion='Party', now=NOW)
    assert 3 in [i['id'] for i in office['suggestion']]
    assert 3 not in [i['id'] for i in party['suggestion']]


def test_history_ids_as_comma_string_are_accepted():
    items = [item(1, 'Shirts', 'white', 10), item(2, 'Shirts', 'white', 10), item(3, 'Pants', 'navy', 10)]
    result = recommend(items, history=[{'date': ago(1), 'itemIds': '1,3'}], now=NOW)
    assert result['key'] == '2-3'


def closet():
    return [
        item(1, 'Tshirts', 'black'), item(2, 'Tshirts', 'grey'), item(3, 'Shirts', 'white'),
        item(4, 'Shirts', 'teal'), item(5, 'Dresses', 'red'), item(6, 'Pants', 'beige'),
        item(7, 'Pants', 'light blue'), item(8, 'Pants', 'navy'),
    ]


def test_each_occasion_picks_a_suitable_main_piece():
    main = {occ: recommend(closet(), occasion=occ, now=NOW)['suggestion'][0]['type']
            for occ in ['Casual', 'Office', 'Party', 'Travel']}
    assert main['Casual'] == 'Tshirts'
    assert main['Office'] == 'Shirts'
    assert main['Party'] == 'Dresses'
    assert main['Travel'] == 'Tshirts'


def test_occasions_do_not_all_return_the_same_outfit():
    keys = {recommend(closet(), occasion=occ, now=NOW)['key'] for occ in ['Casual', 'Office', 'Party', 'Travel']}
    assert len(keys) >= 3


def test_show_another_changes_more_than_the_pants():
    first = recommend(closet(), occasion='Casual', now=NOW)
    second = recommend(closet(), occasion='Casual', exclude_keys=[first['key']], now=NOW)
    first_ids = {i['id'] for i in first['suggestion']}
    second_ids = {i['id'] for i in second['suggestion']}
    assert not first_ids & second_ids


def test_bold_colours_are_marked_down_for_office():
    items = [item(1, 'Shirts', 'red'), item(2, 'Shirts', 'white'), item(3, 'Pants', 'navy')]
    result = recommend(items, occasion='Office', now=NOW)
    assert result['suggestion'][0]['color'] == 'white'


def test_kurtas_are_never_suggested():
    items = [item(1, 'Kurtas', 'teal'), item(2, 'Shirts', 'white'), item(3, 'Pants', 'navy')]
    for occ in ['Casual', 'Office', 'Party', 'Travel']:
        assert 1 not in [i['id'] for i in recommend(items, occasion=occ, now=NOW)['suggestion']]
