# Fixed Asset Catalog (Implementation Safe)

Date: 2026-05-10
Source sheet: `/.ai/workflows/features/SwiftUIFeatures/icons.png`
Extractor: `/.ai/workflows/features/SwiftUIFeatures/extract_icons_from_sheet.py`
Manifest: `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/manifest.json`

This catalog reflects the **locked mapping** (manual overrides enabled) so icons are not mixed between runs.

---

## Required assets (ready)

### Navigation
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/required/navigation/chevron_right_16.png`
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/required/navigation/chevron_right_15.png`
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/required/navigation/chevron_left_13.png`

### Favorite
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/required/favorite/favorite_outline_32.png`
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/required/favorite/favorite_filled_32.png`

### Actions (VenuesDetailsVC)
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/required/actions/action_book_12.png`
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/required/actions/action_dates_12.png`  *(corrected from map mismatch)*
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/required/actions/action_map_12.png`    *(corrected from dates mismatch)*
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/required/actions/action_movie_detail_12.png`

### Placeholder
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/required/placeholder/poster_placeholder_52.png`

---

## Optional metadata assets
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/optional/metadata/meta_location_pin_16.png`
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/optional/metadata/meta_home_16.png`
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/optional/metadata/meta_folder_tag_12.png`
- `/.ai/workflows/features/SwiftUIFeatures/extracted-assets/optional/metadata/meta_calendar_date_12.png`

---

## Gap to resolve before full parity
- `action_calendar_12` is still not separately extracted from the current icon sheet mapping.
- Use temporary fallback for implementation phase:
  - SF Symbol: `calendar`
  - or emoji fallback: `📆`

---

## Import target for app implementation
Copy approved assets into:
- `SwiftCinemas/SwiftLoginScreen/Assets.xcassets/`

Recommended naming inside asset catalog:
- `icon_chevron_right_16`
- `icon_chevron_right_15`
- `icon_chevron_left_13`
- `icon_favorite_outline_32`
- `icon_favorite_filled_32`
- `icon_action_book_12`
- `icon_action_dates_12`
- `icon_action_map_12`
- `icon_action_movie_detail_12`
- `icon_poster_placeholder_52`
- `icon_meta_location_pin_16` (optional)
- `icon_meta_home_16` (optional)
- `icon_meta_folder_tag_12` (optional)
- `icon_meta_calendar_date_12` (optional)

---

## Safety note
If `icons.png` is replaced, re-run extraction and re-validate IDs before using the output.
Current extraction is locked for this exact sheet revision.

