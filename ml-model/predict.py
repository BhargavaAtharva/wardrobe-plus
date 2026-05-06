import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
import json
import sys

def predict(image_path):
    # Load saved model and class names
    checkpoint = torch.load('saved-models/model.pth', map_location='cpu')
    class_names = checkpoint['class_names']

    # Rebuild model architecture
    model = models.efficientnet_b0(weights=None)
    num_features = model.classifier[1].in_features
    model.classifier[1] = nn.Linear(num_features, len(class_names))
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()

    # Preprocess image
    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ])

    image = Image.open(image_path).convert('RGB')
    image = transform(image).unsqueeze(0)

    # Predict
    with torch.no_grad():
        outputs = model(image)
        _, predicted = outputs.max(1)
        predicted_class = class_names[predicted.item()]

    return {"type": predicted_class}

if __name__ == '__main__':
    image_path = sys.argv[1]
    result = predict(image_path)
    print(json.dumps(result))