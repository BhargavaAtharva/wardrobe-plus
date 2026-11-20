"""Classify one photo from the command line using the same pipeline as the app
(background removal -> classifier -> colour detection).

Usage (from ml-model/):  ../backend/venv/bin/python3 predict.py path/to/photo.jpg
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'backend'))

if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    from app import predict_clothing
    with open(sys.argv[1], 'rb') as f:
        print(json.dumps(predict_clothing(f.read()), indent=2))
