import pandas as pd
import shutil
import os

# Load the CSV which contains image labels
df = pd.read_csv('data/raw/styles.csv', on_bad_lines='skip')
print(f"Total items in dataset: {len(df)}")
print(f"Columns: {df.columns.tolist()}")
print(df.head())

# We'll use 'articleType' as our clothing category label
# Filter to only the categories we care about
target_categories = [
    'Tshirts', 'Shirts', 'Jeans', 'Trousers', 
    'Dresses', 'Jackets', 'Kurtas', 'Shoes'
]

df = df[df['articleType'].isin(target_categories)]
print(f"\nFiltered items: {len(df)}")

# Create train folders for each category
for category in target_categories:
    os.makedirs(f'data/train/{category}', exist_ok=True)

# Copy images into correct folders
success = 0
missing = 0

for _, row in df.iterrows():
    image_id = str(row['id'])
    category = row['articleType']
    
    src = f'data/raw/images/{image_id}.jpg'
    dst = f'data/train/{category}/{image_id}.jpg'
    
    if os.path.exists(src):
        shutil.copy2(src, dst)
        success += 1
    else:
        missing += 1

print(f"\nDone. Copied: {success} | Missing: {missing}")
print("\nImages per category:")
for category in target_categories:
    count = len(os.listdir(f'data/train/{category}'))
    print(f"  {category}: {count} images")
