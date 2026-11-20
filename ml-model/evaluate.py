"""Honest evaluation on real photos the model never trained on.

Runs every photo through the exact pipeline the app uses (background removal ->
classifier -> colour detection) and compares against hand-written labels.

Usage (from ml-model/, using the backend's virtual environment):
    ../backend/venv/bin/python3 evaluate.py
    ../backend/venv/bin/python3 evaluate.py --images holdout/images --labels holdout/labels.csv

labels.csv columns: filename,type,color   (type uses the app's names, e.g. Pants)

Rules for a fair score: photos in the holdout set must never be copied into
data/train, and colour labels should be written down before looking at results.
"""

import argparse
import csv
import os
import sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'backend'))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--images', default=os.path.join(HERE, 'holdout', 'images'))
    parser.add_argument('--labels', default=os.path.join(HERE, 'holdout', 'labels.csv'))
    args = parser.parse_args()

    from app import class_names, predict_clothing  # loads the model once

    with open(args.labels, newline='') as f:
        rows = list(csv.DictReader(f))

    type_total, type_correct = Counter(), Counter()
    confusion = defaultdict(Counter)
    color_correct = 0
    unsupported = []

    print(f'{"file":22} {"true type":10} {"predicted":18} {"true colour":12} {"detected":12}')
    for row in rows:
        path = os.path.join(args.images, row['filename'])
        with open(path, 'rb') as f:
            result = predict_clothing(f.read())
        true_type, true_color = row['type'], row['color']
        pred = f'{result["type"]} {result["confidence"]:.0f}%'
        mark_type = 'ok' if result['type'] == true_type else '--'
        mark_color = 'ok' if result['color'] == true_color else '--'
        print(f'{row["filename"]:22} {true_type:10} {pred:15} {mark_type} '
              f'{true_color:12} {result["color"]:12} {mark_color}  [{result["segmenter"]}]')

        color_correct += result['color'] == true_color
        if true_type not in class_names:
            unsupported.append(row['filename'])
            continue
        type_total[true_type] += 1
        type_correct[true_type] += result['type'] == true_type
        confusion[true_type][result['type']] += 1

    n_type = sum(type_total.values())
    print('\n=== Clothing type (only types the model was trained on) ===')
    if n_type:
        print(f'Overall: {sum(type_correct.values())}/{n_type} '
              f'= {100 * sum(type_correct.values()) / n_type:.0f}%')
        for t in class_names:
            if type_total[t]:
                print(f'  {t:10} {type_correct[t]}/{type_total[t]}')
        print('\nConfusion (rows = true, columns = predicted):')
        print(' ' * 12 + ''.join(f'{c[:8]:>9}' for c in class_names))
        for t in class_names:
            if type_total[t]:
                print(f'  {t:10}' + ''.join(f'{confusion[t][c]:>9}' for c in class_names))
    if unsupported:
        print(f'\nSkipped for type accuracy (model has no such class): {", ".join(unsupported)}')

    print('\n=== Colour ===')
    print(f'Overall: {color_correct}/{len(rows)} = {100 * color_correct / len(rows):.0f}%')
    print(f'\nHoldout size: {len(rows)} photos. With this few photos, one mistake moves '
          f'accuracy by {100 / max(n_type, 1):.0f} points — add more for a reliable number.')


if __name__ == '__main__':
    main()
