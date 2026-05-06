from flask import Flask, request, jsonify
from flask_cors import CORS
import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
import io
import json

app = Flask(__name__)
CORS(app)

# Load model once when server starts
checkpoint = torch.load('../ml-model/saved-models/model.pth', map_location='cpu')
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

def predict_clothing(image_bytes):
    image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
    tensor = transform(image).unsqueeze(0)
    with torch.no_grad():
        outputs = model(tensor)
        probabilities = torch.nn.functional.softmax(outputs[0], dim=0)
        confidence, predicted = probabilities.max(0)
        predicted_class = class_names[predicted.item()]
    return {
        "type": predicted_class,
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

    # Rule based outfit suggestion
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