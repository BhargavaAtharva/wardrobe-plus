"""Train the clothing-type classifier (EfficientNet-B0 transfer learning).

What changed from the first versions:
- 15% of every class is held out as a validation set the model never trains on,
  so the reported validation accuracy is honest (the old test_model.py sampled
  its "test" images from the training folder).
- Folders whose names start with "_" or end in "_backup"/"_temp" are ignored, so
  a category can be parked without moving it out of data/train.
- Every run is saved as its own versioned file with its metrics, and the best
  epoch (by validation accuracy) is kept. saved-models/model.pth is updated to
  point at the newest run, which is what the backend loads.

Usage (from ml-model/):  python3 train.py
"""

import json
import os
import random
import shutil
from datetime import datetime

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, Subset, WeightedRandomSampler
from torchvision import datasets, models, transforms

DATA_DIR = 'data/train'
SAVE_DIR = 'saved-models'
VAL_FRACTION = 0.15
SEED = 42
PHASE1_EPOCHS = 5
PHASE2_EPOCHS = 10


def is_parked(name):
    return name.startswith('_') or name.endswith('_backup') or name.endswith('_temp')


class WardrobeFolder(datasets.ImageFolder):
    def find_classes(self, directory):
        classes = sorted(e.name for e in os.scandir(directory) if e.is_dir() and not is_parked(e.name))
        return classes, {c: i for i, c in enumerate(classes)}


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
eval_transforms = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
])


def stratified_split(targets, val_fraction, seed):
    rng = random.Random(seed)
    by_class = {}
    for idx, label in enumerate(targets):
        by_class.setdefault(label, []).append(idx)
    train_idx, val_idx = [], []
    for indices in by_class.values():
        rng.shuffle(indices)
        n_val = max(1, int(len(indices) * val_fraction))
        val_idx += indices[:n_val]
        train_idx += indices[n_val:]
    return train_idx, val_idx


def run_epoch(model, loader, device, criterion, optimizer=None):
    training = optimizer is not None
    model.train(training)
    total_loss, correct, total = 0.0, 0, 0
    per_class_correct, per_class_total = {}, {}
    with torch.set_grad_enabled(training):
        for images, labels in loader:
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            loss = criterion(outputs, labels)
            if training:
                optimizer.zero_grad()
                loss.backward()
                optimizer.step()
            total_loss += loss.item()
            predicted = outputs.argmax(1)
            correct += predicted.eq(labels).sum().item()
            total += labels.size(0)
            for label, pred in zip(labels.tolist(), predicted.tolist()):
                per_class_total[label] = per_class_total.get(label, 0) + 1
                per_class_correct[label] = per_class_correct.get(label, 0) + (label == pred)
    per_class = {k: per_class_correct[k] / per_class_total[k] for k in per_class_total}
    return total_loss / max(len(loader), 1), correct / max(total, 1), per_class


def main():
    torch.manual_seed(SEED)
    full_train = WardrobeFolder(DATA_DIR, transform=train_transforms)
    full_eval = WardrobeFolder(DATA_DIR, transform=eval_transforms)
    class_names = full_train.classes
    print(f'Classes: {class_names}')

    train_idx, val_idx = stratified_split(full_train.targets, VAL_FRACTION, SEED)
    train_set = Subset(full_train, train_idx)
    val_set = Subset(full_eval, val_idx)

    train_targets = [full_train.targets[i] for i in train_idx]
    counts = np.bincount(train_targets, minlength=len(class_names))
    print('Train / validation images per class:')
    val_counts = np.bincount([full_train.targets[i] for i in val_idx], minlength=len(class_names))
    for name, n_train, n_val in zip(class_names, counts, val_counts):
        print(f'  {name:10} {n_train:6} / {n_val}')

    # Weighted sampling so rare classes are seen as often as common ones
    sample_weights = [1.0 / counts[t] for t in train_targets]
    sampler = WeightedRandomSampler(sample_weights, len(sample_weights))
    train_loader = DataLoader(train_set, batch_size=32, sampler=sampler, num_workers=0)
    val_loader = DataLoader(val_set, batch_size=64, shuffle=False, num_workers=0)

    model = models.efficientnet_b0(weights=models.EfficientNet_B0_Weights.DEFAULT)
    model.classifier[1] = nn.Linear(model.classifier[1].in_features, len(class_names))
    device = torch.device('mps' if torch.backends.mps.is_available() else 'cpu')
    print(f'Training on: {device}')
    model = model.to(device)
    criterion = nn.CrossEntropyLoss()

    best = {'val_acc': -1.0}
    history = []

    def record(phase, epoch, epochs, optimizer):
        train_loss, train_acc, _ = run_epoch(model, train_loader, device, criterion, optimizer)
        val_loss, val_acc, per_class = run_epoch(model, val_loader, device, criterion)
        history.append({'phase': phase, 'epoch': epoch, 'train_acc': train_acc, 'val_acc': val_acc,
                        'train_loss': train_loss, 'val_loss': val_loss})
        print(f'{phase} epoch {epoch}/{epochs} | train {100 * train_acc:.1f}% '
              f'| validation {100 * val_acc:.1f}% (loss {val_loss:.3f})')
        if val_acc > best['val_acc']:
            best.update(val_acc=val_acc, state={k: v.detach().cpu().clone() for k, v in model.state_dict().items()},
                        per_class={class_names[k]: v for k, v in per_class.items()},
                        phase=phase, epoch=epoch)

    # Phase 1: train only the new final layer
    for p in model.features.parameters():
        p.requires_grad = False
    optimizer = torch.optim.Adam(model.classifier.parameters(), lr=0.001)
    print('\nPhase 1: training final layer only...')
    for epoch in range(1, PHASE1_EPOCHS + 1):
        record('phase1', epoch, PHASE1_EPOCHS, optimizer)

    # Phase 2: fine-tune the whole network with a lower learning rate
    for p in model.features.parameters():
        p.requires_grad = True
    optimizer = torch.optim.Adam(model.parameters(), lr=0.0001)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=PHASE2_EPOCHS)
    print('\nPhase 2: fine-tuning entire network...')
    for epoch in range(1, PHASE2_EPOCHS + 1):
        record('phase2', epoch, PHASE2_EPOCHS, optimizer)
        scheduler.step()

    os.makedirs(SAVE_DIR, exist_ok=True)
    version = datetime.now().strftime('%Y%m%d-%H%M')
    model_file = os.path.join(SAVE_DIR, f'model-{version}.pth')
    root = os.path.abspath(DATA_DIR)
    val_files = [os.path.relpath(full_eval.samples[i][0], root) for i in val_idx]
    torch.save({
        'model_state_dict': best['state'],
        'class_names': class_names,
        'version': version,
        'val_files': val_files,
        'val_accuracy': best['val_acc'],
    }, model_file)

    metrics = {
        'version': version,
        'classes': class_names,
        'train_images': dict(zip(class_names, counts.tolist())),
        'val_images': dict(zip(class_names, val_counts.tolist())),
        'best_epoch': f'{best["phase"]} {best["epoch"]}',
        'val_accuracy': best['val_acc'],
        'val_accuracy_per_class': best['per_class'],
        'history': history,
    }
    with open(os.path.join(SAVE_DIR, f'model-{version}.json'), 'w') as f:
        json.dump(metrics, f, indent=2)

    current = os.path.join(SAVE_DIR, 'model.pth')
    if os.path.exists(current):
        previous = os.path.join(SAVE_DIR, f'model-before-{version}.pth')
        shutil.copy2(current, previous)
        print(f'\nPrevious model.pth kept as {previous}')
    shutil.copy2(model_file, current)

    print(f'\nBest validation accuracy: {100 * best["val_acc"]:.1f}% ({best["phase"]} epoch {best["epoch"]})')
    for name, acc in best['per_class'].items():
        print(f'  {name:10} {100 * acc:.1f}%')
    print(f'Saved {model_file} (+ metrics .json) and updated {current}')
    print('Next: run evaluate.py for accuracy on real photos (holdout/).')


if __name__ == '__main__':
    main()
