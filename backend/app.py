import io
import os

import torch
import torch.nn as nn
from flask import Flask, jsonify, request
from flask_cors import CORS
import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError
from rembg import new_session, remove
from torchvision import models, transforms

import accounts
from accounts import require_auth
from color_detect import COLOR_NAMES, detect_color
from matcher import match
from recommender import OCCASION_FIT, recommend

app = Flask(__name__)
CORS(app)
app.register_blueprint(accounts.bp)
accounts.init_db()
accounts.ensure_demo_account()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.environ.get(
    'WARDROBE_MODEL', os.path.join(BASE_DIR, '../ml-model/saved-models/model.pth'))

# Clothing types the app supports. The model only predicts some of them; the
# rest (Outerwear) are set by the user when editing an item. Kurtas were dropped:
# the model can't recognise them and they made poor Office/Party suggestions.
APP_TYPES = ['Tshirts', 'Shirts', 'Pants', 'Dresses', 'Outerwear']

# Load model once at startup
checkpoint = torch.load(MODEL_PATH, map_location='cpu')
class_names = checkpoint['class_names']

model = models.efficientnet_b0(weights=None)
num_features = model.classifier[1].in_features
model.classifier[1] = nn.Linear(num_features, len(class_names))
model.load_state_dict(checkpoint['model_state_dict'])
model.eval()

transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

# Background removal uses two models. u2net is fast (~2s) and fine on plain
# backgrounds, but on striped/patterned bedsheets it often keeps the sheet or
# only a logo. When its mask looks like a failure we re-run with BiRefNet-lite,
# which is slower (~12s) but handles busy backgrounds far better.
# Sessions are created once; creating them per request reloads the model.
fast_session = new_session('u2net')
robust_session = new_session('birefnet-general-lite')

MAX_SIDE = 1280             # phone photos are ~4000px; downscale for speed
MIN_FOREGROUND = 0.25       # cut-out smaller than this share of the photo -> suspicious
MAX_SOFT_EDGE = 0.10        # lots of half-transparent pixels -> model was unsure


def _load_image(image_bytes):
    image = Image.open(io.BytesIO(image_bytes))
    image = ImageOps.exif_transpose(image).convert('RGB')
    image.thumbnail((MAX_SIDE, MAX_SIDE))
    return image


def _mask_stats(cutout):
    alpha = np.array(cutout)[:, :, 3]
    foreground = float((alpha > 160).mean())
    soft = float(((alpha > 20) & (alpha < 235)).mean())
    return foreground, soft


def segment(image):
    """Cut the garment out of the photo. Returns (rgba_cutout, model_used)."""
    cutout = remove(image, session=fast_session).convert('RGBA')
    foreground, soft = _mask_stats(cutout)
    if foreground >= MIN_FOREGROUND and soft <= MAX_SOFT_EDGE:
        return cutout, 'u2net'
    robust = remove(image, session=robust_session).convert('RGBA')
    if _mask_stats(robust)[0] > foreground:
        return robust, 'birefnet-general-lite'
    return cutout, 'u2net'


def remove_background(image_bytes):
    """Returns (rgba_cutout, rgb_on_white, model_used). Raises on unreadable images."""
    cutout, used = segment(_load_image(image_bytes))
    background = Image.new('RGBA', cutout.size, (255, 255, 255, 255))
    background.paste(cutout, mask=cutout.split()[3])
    return cutout, background.convert('RGB'), used


def predict_clothing(image_bytes):
    cutout, on_white, segmenter = remove_background(image_bytes)
    color, _ = detect_color(cutout)
    tensor = transform(on_white).unsqueeze(0)
    with torch.no_grad():
        probabilities = torch.nn.functional.softmax(model(tensor)[0], dim=0)
    top = torch.topk(probabilities, k=min(3, len(class_names)))
    ranked = [
        {'type': class_names[idx], 'confidence': round(p * 100, 1)}
        for p, idx in zip(top.values.tolist(), top.indices.tolist())
    ]
    return {
        'type': ranked[0]['type'],
        'confidence': ranked[0]['confidence'],
        'color': color,
        'alternatives': ranked[1:],
        'segmenter': segmenter,
    }


@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'ok',
        'classes': class_names,
        'types': APP_TYPES,
        'colors': COLOR_NAMES,
        'occasions': list(OCCASION_FIT.keys()),
    })


@app.route('/classify', methods=['POST'])
@require_auth
def classify():
    if 'image' not in request.files:
        return jsonify({'error': 'no_image', 'message': 'No image was sent.'}), 400
    image_bytes = request.files['image'].read()
    if not image_bytes:
        return jsonify({'error': 'no_image', 'message': 'The image was empty.'}), 400
    try:
        return jsonify(predict_clothing(image_bytes))
    except (UnidentifiedImageError, OSError):
        return jsonify({'error': 'bad_image',
                        'message': 'Could not read that image. Try a JPEG or PNG photo.'}), 400


@app.route('/suggest', methods=['POST'])
@require_auth
def suggest():
    data = request.get_json(silent=True) or {}
    result = recommend(
        items=data.get('items', []),
        occasion=data.get('occasion', 'Casual'),
        history=data.get('history', []),
        exclude_keys=data.get('exclude_keys', []),
    )
    status = 200 if 'error' not in result else 422
    return jsonify(result), status


@app.route('/match', methods=['POST'])
@require_auth
def match_piece():
    """Rank the tops that go with a pair of pants, or the pants that go with a top."""
    data = request.get_json(silent=True) or {}
    occasion = data.get('occasion')
    result = match(
        anchor_id=data.get('anchor_id'),
        items=data.get('items', []),
        occasion=occasion if occasion in OCCASION_FIT else None,
        history=data.get('history', []),
    )
    return jsonify(result), (200 if 'error' not in result else 422)


if __name__ == '__main__':
    # debug's auto-reloader would load the model twice; opt in with FLASK_DEBUG=1
    app.run(debug=os.environ.get('FLASK_DEBUG') == '1', host='0.0.0.0',
            port=int(os.environ.get('PORT', 5000)))
