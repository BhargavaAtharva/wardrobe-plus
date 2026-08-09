import torch
import torch.nn as nn
from torchvision import datasets, transforms, models
from torch.utils.data import DataLoader, WeightedRandomSampler
import os
import numpy as np

# Stronger augmentation to handle real world photos
train_transforms = transforms.Compose([
    transforms.Resize((256, 256)),
    transforms.RandomCrop(224),
    transforms.RandomHorizontalFlip(),
    transforms.RandomVerticalFlip(p=0.1),
    transforms.ColorJitter(brightness=0.4, contrast=0.4, saturation=0.3, hue=0.1),
    transforms.RandomRotation(30),
    transforms.RandomGrayscale(p=0.05),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    transforms.RandomErasing(p=0.1),
])

# Load dataset
train_dataset = datasets.ImageFolder('data/train', transform=train_transforms)
class_names = train_dataset.classes
print(f"Classes: {class_names}")

# Count images per class
class_counts = np.array([len(os.listdir(f'data/train/{c}')) for c in class_names])
print(f"Images per class: {dict(zip(class_names, class_counts))}")

# Weighted sampler for class imbalance
class_weights = 1.0 / class_counts
sample_weights = [class_weights[label] for _, label in train_dataset.samples]
sampler = WeightedRandomSampler(sample_weights, len(sample_weights))

train_loader = DataLoader(train_dataset, batch_size=32, sampler=sampler, num_workers=0)

# Load pre-trained EfficientNet
model = models.efficientnet_b0(weights=models.EfficientNet_B0_Weights.DEFAULT)
num_features = model.classifier[1].in_features
model.classifier[1] = nn.Linear(num_features, len(class_names))

# Use Mac GPU
device = torch.device('mps' if torch.backends.mps.is_available() else 'cpu')
print(f"Training on: {device}")
model = model.to(device)

criterion = nn.CrossEntropyLoss()

# Two phase training
# Phase 1: Train only the final layer (5 epochs)
for param in model.features.parameters():
    param.requires_grad = False

optimizer = torch.optim.Adam(model.classifier.parameters(), lr=0.001)

print("\nPhase 1: Training final layer only...")
for epoch in range(5):
    model.train()
    running_loss = 0.0
    correct = 0
    total = 0

    for images, labels in train_loader:
        images, labels = images.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()

        running_loss += loss.item()
        _, predicted = outputs.max(1)
        total += labels.size(0)
        correct += predicted.eq(labels).sum().item()

    print(f"Epoch {epoch+1}/5 | Loss: {running_loss/len(train_loader):.3f} | Accuracy: {100*correct/total:.1f}%")

# Phase 2: Fine tune entire network (10 epochs, lower lr)
for param in model.features.parameters():
    param.requires_grad = True

optimizer = torch.optim.Adam(model.parameters(), lr=0.0001)
scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=10)

print("\nPhase 2: Fine tuning entire network...")
for epoch in range(10):
    model.train()
    running_loss = 0.0
    correct = 0
    total = 0

    for images, labels in train_loader:
        images, labels = images.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()

        running_loss += loss.item()
        _, predicted = outputs.max(1)
        total += labels.size(0)
        correct += predicted.eq(labels).sum().item()

    scheduler.step()
    print(f"Epoch {epoch+1}/10 | Loss: {running_loss/len(train_loader):.3f} | Accuracy: {100*correct/total:.1f}%")

# Save model
os.makedirs('saved-models', exist_ok=True)
torch.save({
    'model_state_dict': model.state_dict(),
    'class_names': class_names
}, 'saved-models/model.pth')

print("\nModel saved to saved-models/model.pth")