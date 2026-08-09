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

app = Flask(__name__)
CORS(app)

# Load model once when server starts
import os
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
checkpoint = torch.load(os.path.join(BASE_DIR, '../ml-model/saved-models/model.pth'), map_location='cpu')
class_names = checkpoint['class_names']

model = models.efficientnet_b0(weights=None)
num_features = model.classifier[1].in_features
model.classifier[1] = nn.Linear(num_features, len(class_names))
model.load_state_dict(checkpoint['model_state_dict'])
model.eval()

# Image preprocessing
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

def remove_background(image_bytes):
    """Remove background from image using rembg"""
    output_bytes = remove(image_bytes)
    image = Image.open(io.BytesIO(output_bytes)).convert('RGBA')
    # Paste onto white background
    background = Image.new('RGBA', image.size, (255, 255, 255, 255))
    background.paste(image, mask=image.split()[3])
    return background.convert('RGB')

def detect_color(image):
    """Detect dominant color of clothing item"""
    img_array = np.array(image)
    img_cv = cv2.cvtColor(img_array, cv2.COLOR_RGB2HSV)
    
    # Mask out white/near-white background
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
    
    # Low saturation = achromatic colors
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
    
    # Medium saturation — could be pastel or muted
    if avg_sat < 80:
        if avg_val > 180:
            return "beige"
        elif avg_hue < 35:
            return "brown"
    
    # Chromatic colors by hue
    # Check for multicolor before assigning single color
    # Get unique hue distribution
    hue_values = clothing_pixels[:, 0]
    hue_std = np.std(hue_values)
    
    if hue_std > 40 and avg_sat > 50:
        return "multicolor"
    
    # Also fix blue denim — low sat but bluish
    if avg_sat >= 20 and avg_hue > 90 and avg_hue < 130:
        return "blue"

    # Chromatic colors by hue
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
    # Remove background first
    image = remove_background(image_bytes)
    
    # Detect color
    color = detect_color(image)
    
    # Classify clothing type
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
    temp = weather.get('temp', 25)

    tops = [i for i in items if i['type'] in ['Tshirts', 'Shirts', 'Kurtas']]
    bottoms = [i for i in items if i['type'] in ['Jeans', 'Trousers']]
    dresses = [i for i in items if i['type'] == 'Dresses']
    jackets = [i for i in items if i['type'] == 'Jackets']

    suggestion = []
    reason = ""

    if temp < 15 and jackets:
        if tops:
            suggestion = [tops[0], bottoms[0] if bottoms else None, jackets[0]]
            reason = "Layered outfit for cold weather"
    elif dresses and temp > 20:
        suggestion = [dresses[0]]
        reason = "Light dress suitable for warm weather"
    elif tops and bottoms:
        suggestion = [tops[0], bottoms[0]]
        reason = "Classic casual combination"
    elif tops:
        suggestion = [tops[0]]
        reason = "Styled with what's available"

    suggestion = [s for s in suggestion if s is not None]

    return jsonify({
        "suggestion": suggestion,
        "reason": reason
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)