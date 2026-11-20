# What was changed in the research paper, and why

Every claim was checked against the code in this repo (`backend/`, `ml-model/`, `app/wardrobe_plus/`)
and its git history. "Original" refers to `researchpaper.docx`.

## Claims that were wrong or not implemented

| # | Original paper said | What the code actually does | Fix in the revised paper |
|---|---|---|---|
| 1 | Fine-tuned **ResNet-50** (25M params) | **EfficientNet-B0** (`train.py`, `app.py`). ResNet never appears anywhere in git history. | Rewritten around EfficientNet-B0; ResNet kept only as related work |
| 2 | **8 classes**: T-shirts, Shirts, Jeans, Trousers, Dresses, Jackets, Kurtas, Shoes | **4 classes**: Dresses, Pants (Jeans + Trousers merged), Shirts, Tshirts. Outerwear can be set manually. Kurtas, jackets and shoes were dropped. | 4 classes, with a dataset table per class and source |
| 3 | Trained only on the Kaggle Fashion Product Images dataset | Three sources: Kaggle *small* (60×80 px) catalogue images, the agrigorev Clothing Dataset (real photos) and 156 team photos, for 14,477 images in total | New dataset section and Table I |
| 4 | "Trained from scratch without freezing", 10 epochs, Adam lr 0.001 | Two phases: head only for 5 epochs at lr 1e-3, then the full network for 10 epochs at lr 1e-4 with cosine annealing | Corrected text and Table II |
| 5 | Augmentation: flip, jitter ±0.2, rotation 15° | Resize to 256 → random 224 crop, H/V flips, jitter 0.4/0.4/0.3/0.1, rotation 30°, greyscale, random erasing | Corrected |
| 6 | `/suggest` uses **temperature rules** (<15 °C jacket, >20 °C dress) and a **weather API** | No weather or temperature anywhere. `/suggest` uses an occasion-based weighted score (colour, freshness, occasion, repeat penalty). | Full description of the real recommender with equations and tables |
| 7 | **Voice commands and audio descriptions** for visually-impaired users (listed as a feature/contribution) | No text-to-speech, voice or accessibility code in the app | Moved to *future work* |
| 8 | "Cost per wear" sustainability metric | Not implemented. The app tracks wear count, last-worn date and outfit history, and favours unworn pieces. | Only what exists is described |
| 9 | Accuracy "above 90% in 3 epochs"; evaluation by sampling 50 images per class **from the training folder** | That evaluation was leaked: it tested on training images. The current `train.py` holds out 15%, and `evaluate.py` tests on 12 real photos that were never used for training. | New results section with a real validation split, the holdout set, and an explicit correction of the old number |
| 10 | "Runs on commodity CPUs only" | Trained on an Apple-silicon GPU (MPS). Inference runs on CPU. | Corrected |
| 11 | "Kurtas as a separate class" presented as a contribution | Kurtas were dropped: the model could not recognise them | Removed; listed as a limitation |
| 12 | Background removal "can be applied" | Two-stage rembg: U²-Net, falling back to BiRefNet when the mask fails a check | New section with the algorithm |
| 13 | Missing features | Colour detection (CIELAB k-means), Find-a-Match ranker, token accounts, per-account SQLite storage, outfit history, tests | All added in the Implementation section |

## Reference problems

| Original | Problem | Fix |
|---|---|---|
| [3] X. He *et al.*, "An effective pipeline for a real-world clothes retrieval system," arXiv:1811.03568, 2018 | Wrong authors, year and arXiv number | Y.-H. Ji *et al.*, arXiv:2005.12739, 2020 |
| [6] Goh *et al.*, CCNC 2011, pp. 1–5 | Wrong pages | pp. 303–307 |
| [7] C. P. Vaidya *et al.*, "Smart wardrobe: A deep learning model," ICCCEE 2023 | **Could not be found anywhere**; it looks fabricated | Removed |
| [8] Banoth *et al.* | Missing fourth author | Added V. Raj |
| "FashionNet ... further work expanded" | FashionNet was introduced *in* the DeepFashion paper itself | Corrected wording |
| [1] Kaggle Fashion Product Images (full) | The project uses the *small* version | Correct dataset cited |

New references were added for things the system actually uses: EfficientNet, ImageNet, U²-Net, BiRefNet, rembg,
k-means++, the Clothing Dataset, Street2Shop (domain gap), node-wise GNN outfit compatibility,
and the Ellen MacArthur Foundation report (clothing utilisation).

## New results reported in the paper (measured 2026-10-12)

| Measurement | Result |
|---|---|
| Validation accuracy (same recipe, stratified 15% held out, 2,170 images) | **98.5%** overall: 98.9% catalogue, **96.8% on the 379 real photos** |
| Weakest class | T-shirts on real photos: 93.5%. 29 of the 32 errors are T-shirts (predicted as dress, shirt or pants). |
| Deployed model on 12 held-out phone photos | Type 11/11, colour 12/12 (the colour rules were tuned on these photos) |
| Validation-run model on the same 12 photos | Type 10/11 (a white shirt was called a dress at 95% confidence), colour 12/12 |
| Kurta photo (unsupported class) | Both models say "Dress" at >99% confidence; reported as a limitation |
| Latency on an M4 CPU | about 0.4 s with U²-Net, about 6 s when the BiRefNet fallback runs |
| Tests | 47 backend (pytest), 25 Flutter unit tests: all pass |

The validation-run model lives in a temp folder. `ml-model/saved-models/model.pth` was **not** changed.

## Still to check yourselves
- **Banoth et al. venue.** The citation metadata gives the date (April 2022) and IEEE as the publisher. I assumed the
  conference is I2CT 2022; confirm on IEEE Xplore (document 9824354).
- **Results are from a fresh run.** The validation numbers come from a re-training run with a 15% held-out split
  (same recipe as the deployed model). The deployed `model.pth` was trained on all images and was not replaced.
