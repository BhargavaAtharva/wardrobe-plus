from flask import Flask, request, jsonify
from flask_cors import CORS
import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
import io
import json
from rembg import remove
import cv2
import numpy as np
import os
import random

app = Flask(__name__)
CORS(app)

# Load model
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
checkpoint = torch.load(os.path.join(BASE_DIR, '../ml-model/saved-models/model.pth'), map_location='cpu')
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

# Color compatibility matrix
COLOR_PAIRS = {
    'black': ['white', 'grey', 'beige', 'blue', 'red', 'pink', 'yellow', 'green', 'brown', 'multicolor', 'dark grey'],
    'white': ['black', 'grey', 'beige', 'blue', 'red', 'pink', 'yellow', 'green', 'brown', 'navy', 'dark grey'],
    'grey': ['black', 'white', 'beige', 'blue', 'red', 'pink', 'yellow', 'green', 'brown', 'multicolor', 'dark grey'],
    'dark grey': ['black', 'white', 'beige', 'blue', 'red', 'pink', 'yellow', 'green', 'brown', 'multicolor'],
    'beige': ['black', 'white', 'grey', 'brown', 'blue', 'green', 'navy'],
    'blue': ['white', 'grey', 'black', 'beige', 'brown', 'navy'],
    'navy': ['white', 'beige', 'grey', 'blue', 'brown'],
    'brown': ['beige', 'white', 'grey', 'green', 'navy'],
    'green': ['white', 'beige', 'brown', 'navy', 'black'],
    'red': ['black', 'white', 'grey', 'navy'],
    'pink': ['white', 'grey', 'black', 'navy'],
    'yellow': ['white', 'grey', 'navy', 'black'],
    'purple': ['white', 'grey', 'black', 'beige'],
    'multicolor': ['black', 'white', 'grey'],
    'unknown': ['black', 'white', 'grey', 'beige'],
}

OCCASION_RULES = {
    'Casual': {
        'allowed_tops': ['Tshirts', 'Shirts', 'Kurtas'],
        'allowed_bottoms': ['Pants'],
        'allow_dresses': True,
        'allow_outerwear': True,
    },
    'Office': {
        'allowed_tops': ['Shirts', 'Kurtas'],
        'allowed_bottoms': ['Pants'],
        'allow_dresses': True,
        'allow_outerwear': True,
    },
    'Party': {
        'allowed_tops': ['Tshirts', 'Shirts'],
        'allowed_bottoms': ['Pants'],
        'allow_dresses': True,
        'allow_outerwear': False,
    },
    'Travel': {
        'allowed_tops': ['Tshirts', 'Shirts', 'Kurtas'],
        'allowed_bottoms': ['Pants'],
        'allow_dresses': True,
        'allow_outerwear': True,
    },
}

def colors_match(color1, color2):
    if color1 == color2:
        return True
    return color2 in COLOR_PAIRS.get(color1, [])

def get_outfit_reason(top, bottom, weather_desc, occasion):
    reasons = []
    if occasion == 'Office':
        reasons.append("Professional look")
    elif occasion == 'Party':
        reasons.append("Party ready")
    elif occasion == 'Travel':
        reasons.append("Travel comfortable")
    else:
        reasons.append("Casual everyday look")
    if weather_desc:
        reasons.append(f"suited for {weather_desc}")
    return ", ".join(reasons)

def remove_background(image_bytes):
    output_bytes = remove(image_bytes)
    image = Image.open(io.BytesIO(output_bytes)).convert('RGBA')
    background = Image.new('RGBA', image.size, (255, 255, 255, 255))
    background.paste(image, mask=image.split()[3])
    return background.convert('RGB')

def detect_color(image):
    img_array = np.array(image)
    img_cv = cv2.cvtColor(img_array, cv2.COLOR_RGB2HSV)

    lower_white = np.array([0, 0, 180])
    upper_white = np.array([180, 40, 255])
    white_mask = cv2.inRange(img_cv, lower_white, upper_white)
    clothing_mask = cv2.bitwise_not(white_mask)

    clothing_pixels = img_cv[clothing_mask > 0]

    if len(clothing_pixels) == 0:
        return "unknown"

    avg_hue = np.mean(clothing_pixels[:, 0])
    avg_sat = np.mean(clothing_pixels[:, 1])
    avg_val = np.mean(clothing_pixels[:, 2])

    hue_std = np.std(clothing_pixels[:, 0])
    if hue_std > 40 and avg_sat > 50:
        return "multicolor"

    if avg_sat < 40:
        if avg_val > 210:
            return "white"
        elif avg_val > 170:
            return "beige"
        elif avg_val > 120:
            return "grey"
        elif avg_val > 60:
            return "dark grey"
        else:
            return "black"

    if avg_sat < 80:
        if avg_val > 180:
            return "beige"
        elif avg_hue < 35:
            return "brown"

    # Denim blue detection
    if avg_hue > 85 and avg_hue < 135 and avg_val > 60:
        return "blue"

    if avg_hue < 10 or avg_hue > 170:
        return "red"
    elif avg_hue < 20:
        return "orange"
    elif avg_hue < 38:
        return "yellow"
    elif avg_hue < 85:
        return "green"
    elif avg_hue < 130:
        return "blue"
    elif avg_hue < 160:
        return "purple"
    elif avg_hue < 170:
        return "pink"
    else:
        return "red"

def predict_clothing(image_bytes):
    image = remove_background(image_bytes)
    color = detect_color(image)
    tensor = transform(image).unsqueeze(0)
    with torch.no_grad():
        outputs = model(tensor)
        probabilities = torch.nn.functional.softmax(outputs[0], dim=0)
        confidence, predicted = probabilities.max(0)
        predicted_class = class_names[predicted.item()]
    return {
        "type": predicted_class,
        "color": color,
        "confidence": round(confidence.item() * 100, 1)
    }

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok", "classes": class_names})

@app.route('/classify', methods=['POST'])
def classify():
    if 'image' not in request.files:
        return jsonify({"error": "No image provided"}), 400
    image_file = request.files['image']
    image_bytes = image_file.read()
    result = predict_clothing(image_bytes)
    return jsonify(result)

@app.route('/suggest', methods=['POST'])
def suggest():
    data = request.get_json()
    items = data.get('items', [])
    weather = data.get('weather', {})
    occasion = data.get('occasion', 'Casual')
    exclude_ids = data.get('exclude_ids', [])

    temp = weather.get('temp', 25)
    weather_desc = weather.get('description', '')

    if not items:
        return jsonify({"error": "No items in wardrobe"}), 400

    rules = OCCASION_RULES.get(occasion, OCCASION_RULES['Casual'])

    tops = [i for i in items if i.get('type') in rules['allowed_tops'] and i.get('id') not in exclude_ids]
    bottoms = [i for i in items if i.get('type') in rules['allowed_bottoms'] and i.get('id') not in exclude_ids]
    dresses = [i for i in items if i.get('type') == 'Dresses' and rules['allow_dresses'] and i.get('id') not in exclude_ids]
    outerwear = [i for i in items if i.get('type') in ['Outerwear', 'Jackets'] and rules['allow_outerwear'] and i.get('id') not in exclude_ids]

    suggestion = []
    reason = ""
    match_score = 0

    if tops and bottoms:
        random.shuffle(tops)
        random.shuffle(bottoms)

        best_top = None
        best_bottom = None

        for top in tops:
            for bottom in bottoms:
                if colors_match(top.get('color', 'unknown'), bottom.get('color', 'unknown')):
                    best_top = top
                    best_bottom = bottom
                    break
            if best_top:
                break

        if not best_top:
            best_top = random.choice(tops)
            best_bottom = random.choice(bottoms)
            match_score = 70
        else:
            match_score = 92

        suggestion = [best_top, best_bottom]
        reason = get_outfit_reason(best_top, best_bottom, weather_desc, occasion)

        if temp < 20 and outerwear and rules['allow_outerwear']:
            matching_outer = [o for o in outerwear if
                colors_match(best_top.get('color', 'unknown'), o.get('color', 'unknown'))]
            if matching_outer:
                suggestion.append(random.choice(matching_outer))
                match_score = min(match_score + 5, 99)

    elif dresses and rules['allow_dresses']:
        dress = random.choice(dresses)
        suggestion = [dress]
        reason = get_outfit_reason(None, None, weather_desc, occasion)
        match_score = 88

    elif tops:
        suggestion = [random.choice(tops)]
        reason = "Styled with what's available"
        match_score = 60

    return jsonify({
        "suggestion": suggestion,
        "reason": reason,
        "match_score": match_score,
        "occasion": occasion,
        "weather": weather_desc
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)