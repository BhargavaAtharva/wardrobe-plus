"""Re-check a trained model on its held-out validation images.

train.py stores the list of validation files inside the checkpoint, so this
measures the model only on images it never trained on. (The old version of
this script copied random *training* images into data/test, which is why its
98-100% numbers were not a real validation score.)

For accuracy on real phone photos, use evaluate.py instead.

Usage (from ml-model/):  python3 test_model.py [saved-models/model.pth]
"""

import os
import sys

import torch
import torch.nn as nn
from PIL import Image
from torchvision import models, transforms

path = sys.argv[1] if len(sys.argv) > 1 else 'saved-models/model.pth'
checkpoint = torch.load(path, map_location='cpu')
class_names = checkpoint['class_names']
val_files = checkpoint.get('val_files')
if not val_files:
    sys.exit(f'{path} was trained before validation splits were recorded, so there is no '
             'held-out set to test on. Retrain with train.py, or use evaluate.py on real photos.')

model = models.efficientnet_b0(weights=None)
model.classifier[1] = nn.Linear(model.classifier[1].in_features, len(class_names))
model.load_state_dict(checkpoint['model_state_dict'])
model.eval()

transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
])

correct, total = {c: 0 for c in class_names}, {c: 0 for c in class_names}
missing = 0
with torch.no_grad():
    for rel in val_files:
        file = os.path.join('data/train', rel)
        if not os.path.exists(file):
            missing += 1
            continue
        true_class = rel.split(os.sep)[0]
        image = transform(Image.open(file).convert('RGB')).unsqueeze(0)
        predicted = class_names[model(image).argmax(1).item()]
        total[true_class] += 1
        correct[true_class] += predicted == true_class

n = sum(total.values())
print(f'Validation accuracy: {100 * sum(correct.values()) / max(n, 1):.1f}% on {n} held-out images')
for c in class_names:
    if total[c]:
        print(f'  {c:10} {100 * correct[c] / total[c]:.1f}%  ({total[c]} images)')
if missing:
    print(f'({missing} validation files no longer exist and were skipped)')
