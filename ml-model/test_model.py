import torch
import torch.nn as nn
from torchvision import models, transforms, datasets
from torch.utils.data import DataLoader

# Same transforms as training but no augmentation
test_transforms = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

# Load saved model
checkpoint = torch.load('saved-models/model.pth', map_location='cpu')
class_names = checkpoint['class_names']

model = models.efficientnet_b0(weights=None)
num_features = model.classifier[1].in_features
model.classifier[1] = nn.Linear(num_features, len(class_names))
model.load_state_dict(checkpoint['model_state_dict'])
model.eval()

# We'll use 20% of training data as a quick validation check
# First split some images into data/test folders
import os
import shutil
import random

for category in class_names:
    src_folder = f'data/train/{category}'
    dst_folder = f'data/test/{category}'
    os.makedirs(dst_folder, exist_ok=True)
    
    images = os.listdir(src_folder)
    test_images = random.sample(images, min(50, len(images)))
    
    for img in test_images:
        shutil.copy2(f'{src_folder}/{img}', f'{dst_folder}/{img}')

# Run validation
test_dataset = datasets.ImageFolder('data/test', transform=test_transforms)
test_loader = DataLoader(test_dataset, batch_size=32, shuffle=False)

correct = 0
total = 0

with torch.no_grad():
    for images, labels in test_loader:
        outputs = model(images)
        _, predicted = outputs.max(1)
        total += labels.size(0)
        correct += predicted.eq(labels).sum().item()

print(f"Validation Accuracy: {100*correct/total:.1f}%")
print(f"Tested on {total} images across {len(class_names)} categories")

# Per category breakdown
print("\nPer category accuracy:")
category_correct = {c: 0 for c in class_names}
category_total = {c: 0 for c in class_names}

test_dataset2 = datasets.ImageFolder('data/test', transform=test_transforms)
test_loader2 = DataLoader(test_dataset2, batch_size=32, shuffle=False)

with torch.no_grad():
    for images, labels in test_loader2:
        outputs = model(images)
        _, predicted = outputs.max(1)
        for label, pred in zip(labels, predicted):
            category = class_names[label.item()]
            category_total[category] += 1
            if label == pred:
                category_correct[category] += 1

for category in class_names:
    acc = 100 * category_correct[category] / category_total[category]
    print(f"  {category}: {acc:.1f}%")