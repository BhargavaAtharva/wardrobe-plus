# Wardrobe+ (ACloset AI)

An AI-powered wardrobe app built for IPD (Innovative Product Development), TSEC Mumbai.
Photograph your clothes, let the AI tag them, and get daily outfit suggestions that
bring back the pieces you haven't worn in a while.

## What it does

1. **Add clothing** — take or upload a photo. The server removes the background,
   identifies the type and detects the main colour. You can correct either before saving.
2. **Closet** — all your clothes, filterable by type, each with a detail page
   (times worn, last worn, date added) where you can edit or delete it.
3. **Outfit generator** — pick an occasion (Casual, Office, Party, Travel) and get the
   best-scoring outfit from your closet, with a match score and the reasons behind it.
   "Wear This Today" logs it; "Show Another Look" moves to the next best option.
4. **Find a match** — open any top or pair of pants (or tap "Or start from a piece you
   choose" on the Outfits tab) and every piece of the other kind is ranked by how well it
   goes with it, with the reasons. Optionally pick an occasion.
5. **Outfit history** — everything you've logged, grouped by day.
6. **Home** — today's outfit, recently added pieces, and pieces you haven't worn in 2+ weeks.

**Accounts.** You sign in with email + password (or create an account). Accounts live on the
Wardrobe+ server (`backend/accounts.py`, SQLite in `backend/data/`, passwords stored as salted
hashes); sign-in returns a token, and the photo/outfit endpoints refuse requests without one.
Each account's closet and history are stored on the phone (SQLite), so different accounts never
see each other's clothes. Closets are **not** synced between phones.

**Demo account** (created automatically when the server starts):
email `demo@wardrobeplus.app`, password `demo1234` — change it with the
`WARDROBE_DEMO_EMAIL` / `WARDROBE_DEMO_PASSWORD` environment variables. Its closet is the 26-photo
set in `ml-model/demo_closet/` (see that folder's `manifest.csv`). Those photos were part of the
training data, so use them to demo features, not to claim accuracy.

## How it works

```
Flutter app (iPhone)  ──HTTP──▶  Flask server (Mac)
  SQLite closet + history          /classify  background removal → EfficientNet-B0 → colour
                                   /suggest   outfit scoring
```

**Classification** (`backend/app.py`)
- Background removal with rembg. The fast `u2net` model runs first; when its cut-out
  looks like a failure (covers < 25% of the photo or has very uncertain edges — typical
  on striped/patterned bedsheets) the slower, more robust `birefnet-general-lite` runs instead.
- Type: EfficientNet-B0 fine-tuned with transfer learning. It currently recognises
  **T-shirts, Shirts, Pants and Dresses**. Outerwear can be set manually and is used
  as a layer for Office/Travel. Kurtas are not supported (the model can't recognise them).
- Colour (`backend/color_detect.py`): k-means on the garment's pixels in CIELAB colour
  space, then rules on lightness / colourfulness / hue that account for phone photos
  (warm-lit whites, faintly blue denim). Two large, clearly different colour clusters
  → "multicolor".

**Outfit scoring** (`backend/recommender.py`)

Every valid outfit (top + pants, or a dress; plus a jacket for Office/Travel) is scored:

| Part | Weight | Meaning |
|---|---|---|
| Colour harmony | 35% | neutral + colour or two neutrals are safest; two prints clash; denim counts as neutral on bottoms |
| Freshness | 30% | days since each piece was last worn; 14+ days or never worn = full score |
| Occasion fit | 35% | does the main piece suit it (shirt for Office, dress for Party; T-shirts excluded from Office) and do its colours fit the mood (muted for Office, bold for Party, dark for Travel) |
| Repeat penalty | −25 / −10 | the exact same outfit worn in the last 7 / 30 days |

Pieces worn in the last 2 days are skipped. The match % shown in the app is this score. "Show Another Look" skips outfits already shown and
prefers ones that change the pieces, not just the pants.

**Find a match** (`backend/matcher.py`)

For a chosen top, every pair of pants is scored (and vice versa):

| Part | Weight | Meaning |
|---|---|---|
| Colour | 45% (55% with no occasion) | the colour-harmony rules above, blended with light/dark contrast (black + white is crisp, grey on grey is flat) |
| Style | 25% (30%) | how dressy each piece is: shirt > T-shirt, dark trousers > light denim. Same level matches best; a dressier top over jeans is fine (smart-casual), a T-shirt with formal trousers is marked down |
| Freshness | 15% | prefers pieces not worn lately; anything worn in the last 2 days is listed last and marked |
| Occasion | 15% (if chosen) | same occasion rules as the outfit generator |

## Accuracy (honest numbers)

`ml-model/evaluate.py` runs the full app pipeline on **real phone photos the model never
trained on** (`ml-model/holdout/`, checked to share no files with the training data).

| | Result |
|---|---|
| Clothing type (4 trained classes) | 11 / 11 |
| Colour | 12 / 12 |

Caveats you should mention if asked:
- 12 photos is a small test set; one mistake moves accuracy by ~9 points.
- The colour rules were tuned while looking at these same 12 photos, so the colour score
  is optimistic. Add new labelled photos to `ml-model/holdout/` for a fair check.
- The earlier "98–100% validation accuracy" was **not** a real validation score: the old
  `test_model.py` tested on images copied from the training folder. `train.py` now holds
  out 15% per class and reports real validation accuracy from the next training run on.

## Running it

### 1. Backend (on a Mac)
```bash
cd backend
./start.sh          # first run creates venv and installs requirements.txt
```
It prints the address to enter in the app, e.g. `http://Your-Mac.local:5000`.
The trained model must be at `ml-model/saved-models/model.pth` (not in git — share it
by AirDrop). The first photo after starting downloads the background-removal models (~400 MB, once).
If port 5000 is busy, turn off **System Settings → AirPlay Receiver**.

### 2. App (iPhone, same Wi-Fi as the Mac)
```bash
cd app/wardrobe_plus
flutter pub get
flutter run
```
In the app: **Profile → Server address** → paste the address from `start.sh` → Test connection → Save.
The `.local` name survives Wi-Fi/IP changes; if a hotspot blocks it, use the IP instead.

### 3. Tests
```bash
cd backend && venv/bin/pip install -r requirements-dev.txt && venv/bin/python3 -m pytest tests
cd app/wardrobe_plus && flutter test
# full end-to-end on a SPARE simulator (server must be running).
# Warning: this uninstalls the app afterwards, deleting all closets on that device.
flutter test integration_test -d <simulator-id> \
  --dart-define=SERVER_URL=http://localhost:5000 \
  --dart-define=PHOTOS_DIR=$PWD/../../ml-model/holdout/images
```

### 4. Model work
```bash
cd ml-model
../backend/venv/bin/python3 evaluate.py      # accuracy on real held-out photos
python3 train.py                              # retrain (versioned; old model kept)
python3 test_model.py                         # re-check validation split of a trained model
../backend/venv/bin/python3 predict.py photo.jpg
```
To park a category without deleting it, rename its folder in `data/train` to end in
`_backup` or `_temp` (or start with `_`). Never copy holdout photos into `data/train`.

## Project structure
```
backend/      Flask API: app.py, accounts.py, color_detect.py, recommender.py, matcher.py, tests/
ml-model/     train.py, evaluate.py, test_model.py, predict.py, prepare_data.py, holdout/
app/wardrobe_plus/lib/
  screens/    splash, onboarding, sign in / create account, home, closet, clothing detail,
              add clothing, outfit generator, find a match, outfit history, profile,
              server settings
  services/   api_client, database_helper (SQLite), image_store, config, catalog, ...
  widgets/    shared UI pieces
```

## Known limitations / roadmap
- Model types: Outerwear (and kurtas, if re-added) need ~200+ real photos each before they can be trained.
- Background removal on busy backgrounds takes ~12–15 s per photo.
- Closets are stored per phone, not on the server, so they don't sync between devices.
- Weather-aware suggestions, pattern detection and learning personal style are future work.
- iOS allows plain HTTP to the Mac (`NSAllowsArbitraryLoads`) for local development only.

## Team
Built by Atharva Bhargava and team — TSEC, Mumbai.
