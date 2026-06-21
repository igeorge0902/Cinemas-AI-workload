import cv2
import json
from pathlib import Path

src = Path('/Users/gyorgy.gaspar/work/cinemas/cinemas/.specify/features/SwiftUIFeatures/icons.png')
out = Path('/Users/gyorgy.gaspar/work/cinemas/cinemas/.specify/features/SwiftUIFeatures/extracted-assets')

img = cv2.imread(str(src), cv2.IMREAD_UNCHANGED)
if img is None:
    raise SystemExit('Could not read source image')

alpha = img[:, :, 3]
mask = (alpha > 100).astype('uint8')
num, _, stats, _ = cv2.connectedComponentsWithStats(mask, 8)

candidates = []
for i in range(1, num):
    x, y, w, h, area = map(int, stats[i])
    if area < 120:
        continue
    if w > 400 and h < 20:
        continue
    candidates.append({'id': i, 'x': x, 'y': y, 'w': w, 'h': h, 'area': area})

# Locked mapping to avoid icon mixing between runs.
# IDs come from connectedComponentsWithStats on the current icons.png sheet.
LOCKED_IDS = {
    'chevron_right_16': 18,
    'chevron_right_15': 16,
    'chevron_left_13': 17,
    'favorite_outline_32': 117,
    'favorite_filled_32': 115,
    'action_book_12': 116,
    'action_dates_12': 113,
    'action_map_12': 112,
    'action_movie_detail_12': 114,
    'poster_placeholder_52': 68,
}

by_id = {c['id']: c for c in candidates}

def by_x(comp):
    return comp['x']

top = sorted([c for c in candidates if 120 <= c['y'] <= 320 and c['area'] > 500], key=by_x)
mid = sorted([c for c in candidates if 380 <= c['y'] <= 530 and c['area'] > 1200], key=by_x)
bot = sorted([c for c in candidates if 730 <= c['y'] <= 860 and c['area'] > 2000], key=by_x)
large = sorted([c for c in candidates if c['area'] > 20000], key=lambda c: c['area'], reverse=True)

mapping = []

def add(category, name, comp, note=''):
    if comp is not None:
        mapping.append({'category': category, 'name': name, 'component': comp, 'note': note})

if len(top) >= 3:
    add('required/navigation', 'chevron_right_16', by_id.get(LOCKED_IDS['chevron_right_16']), 'locked component-id mapping')
    add('required/navigation', 'chevron_right_15', by_id.get(LOCKED_IDS['chevron_right_15']), 'locked component-id mapping')
    add('required/navigation', 'chevron_left_13', by_id.get(LOCKED_IDS['chevron_left_13']), 'locked component-id mapping')

if len(mid) >= 2:
    add('required/favorite', 'favorite_outline_32', by_id.get(LOCKED_IDS['favorite_outline_32']), 'locked component-id mapping')
    add('required/favorite', 'favorite_filled_32', by_id.get(LOCKED_IDS['favorite_filled_32']), 'locked component-id mapping')

for name in ['action_book_12', 'action_dates_12', 'action_map_12', 'action_movie_detail_12']:
    add('required/actions', name, by_id.get(LOCKED_IDS[name]), 'locked component-id mapping')

if large:
    add('required/placeholder', 'poster_placeholder_52', by_id.get(LOCKED_IDS['poster_placeholder_52']) or large[0], 'locked component-id mapping')

for idx, name in enumerate([
    'meta_location_pin_16',
    'meta_home_16',
    'meta_folder_tag_12',
    'meta_calendar_date_12',
]):
    if idx < len(bot):
        add('optional/metadata', name, bot[idx], 'bottom-row positional mapping')

out.mkdir(parents=True, exist_ok=True)
# Remove old extracted PNGs so reruns do not keep stale mappings.
for old in out.rglob('*.png'):
    old.unlink(missing_ok=True)
for item in mapping:
    c = item['component']
    x, y, w, h = c['x'], c['y'], c['w'], c['h']
    p = 6
    x0 = max(0, x - p)
    y0 = max(0, y - p)
    x1 = min(img.shape[1], x + w + p)
    y1 = min(img.shape[0], y + h + p)
    crop = img[y0:y1, x0:x1]

    folder = out / item['category']
    folder.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(folder / f"{item['name']}.png"), crop)

manifest = {
    'source': str(src),
    'counts': {
        'top_candidates': len(top),
        'mid_candidates': len(mid),
        'bottom_candidates': len(bot),
        'exports': len(mapping),
    },
    'exports': [
        {
            'category': item['category'],
            'name': item['name'],
            'bbox': {k: item['component'][k] for k in ('x', 'y', 'w', 'h', 'area')},
            'note': item['note'],
        }
        for item in mapping
    ],
    'verification_required': True,
    'verification_note': 'Mappings use locked component IDs to prevent icon mix-ups. Re-validate IDs only if icons.png is replaced.',
}

(out / 'manifest.json').write_text(json.dumps(manifest, indent=2))
print('Exported', len(mapping), 'assets to', out)
print('Counts:', manifest['counts'])

