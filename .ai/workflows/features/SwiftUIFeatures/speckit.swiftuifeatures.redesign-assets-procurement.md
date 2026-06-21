# Asset Procurement List - SwiftUIFeatures Redesign

**Date:** 2026-05-10  
**Status:** Ready for asset designer / design system team  
**Format Required:** SVG source + PNG (@1x, @2x, @3x) + PDF preview (preferred); SF Symbols allowed only when explicitly approved per icon  
**Color Mode:** Monochrome (grayscale, black, white, gray range only)  
**Background:** Transparent

---

## REQUIRED ASSETS (High Priority — must deliver)

### 1. Navigation Chevrons

| Icon | Size | Color | Usage | Screens | Quantities |
|------|------|-------|-------|---------|-----------|
| **Chevron Right ›** | 16px | Light gray #b7bfd3 | Row navigation indicator | VenuesVC | ~10 instances |
| **Chevron Right ›** | 15px | Light gray #c2cbe0 | Row navigation indicator | VenueForMoviesVC | ~6 instances |
| **Chevron Left ‹** | 13px | Black #000000 | Back button navigation | VenuesVC + VenuesDetailsVC | 2 instances |

**Delivery Notes:**
- Stroke width: 1.5-2px for 13-16px sizes
- Safe area: 1px padding inside bounds
- Provide both outline/stroke versions (not filled)

### 2. Favorite Toggle Icon

| Icon | Size(s) | States | Color | Usage | Screen | Qty |
|------|---------|--------|-------|-------|--------|-----|
| **Heart OR Star** | 32x32px | Outline + Filled | Monochrome | Favorite toggle button per movie | MoviesVC | 1 icon pair |

**Delivery Notes:**
- **State 1 (Unfavorited):** Outline only (stroke, no fill)
- **State 2 (Favorited):** Solid fill (black or dark gray)
- Stroke width: 2-2.5px for 32px
- Provide both states as separate assets or single icon with variations

### 3. Action Icons (VenuesDetailsVC)

| Icon | Size | Color | Label | Button Position | Qty |
|------|------|-------|-------|-----------------|-----|
| **Ticket** | 12px | White #FFFFFF | Book | Full-width, left-aligned | 1 |
| **Calendar** | 12px | White #FFFFFF | Dates | Full-width, left-aligned | 1 |
| **Map/Location** | 12px | White #FFFFFF | Map | Full-width, left-aligned | 1 |
| **Film/Reel** | 12px | White #FFFFFF | Movie Detail | Full-width, left-aligned | 1 |
| **Calendar (variant)** | 12px | White #FFFFFF | Calendar | Full-width, left-aligned | 1 |

**Delivery Notes:**
- All positioned left of button text labels
- Stroke width: 1.5px for 12px size
- Can use iOS SF Symbols: `ticket`, `calendar`, `map`, `film`, `calendar.circle`
- OR custom SVG equivalents

### 4. Movie Poster Placeholder

| Asset | Size | Usage | Screen | Qty |
|-------|------|-------|--------|-----|
| **Film Reel Icon OR Gradient Fill** | 52x52px | Placeholder when movie poster unavailable | MoviesVC, VenueForMoviesVC | 1 |

**Delivery Notes:**
- Rounded corners (12-16px radius)
- Option A: Film reel outline icon (monochrome)
- Option B: Gradient fill (light gray to darker gray)
- Safe area: 4px padding inside bounds

---

## OPTIONAL ASSETS (Lower Priority — can use native emoji)

### Metadata Icons

| Icon | Size | Color | Usage | Screen | Fallback Emoji |
|------|------|-------|-------|--------|----------------|
| **Location Pin** | 16px | Gray #808080 | Venue address indicator | VenuesVC | 📍 |
| **Home** | 16px | Gray #808080 | Venue address alt | VenuesVC | 🏠 |
| **Folder/Tag** | 12px | Gray #808080 | Category indicator | VenueForMoviesVC | 📁 |
| **Calendar/Date** | 12px | Gray #808080 | Screening date indicator | VenueForMoviesVC | 📅 |

**Delivery Notes:**
- LOW priority — can use native emoji to reduce asset burden
- If custom assets provided, use same stroke/style as required icons
- Recommendation: skip these and use emoji strings in NSAttributedString

---

## TOTAL ASSET COUNT

| Category | Count | Priority | Notes |
|----------|-------|----------|-------|
| Navigation chevrons | 3 | **Required** | 16px (2x color variants) + 13px (black) |
| Favorite toggle | 1 | **Required** | 2 states (outline + filled) |
| Action icons | 5 | **Required** | 12px, white on black button, all monochrome |
| Poster placeholder | 1 | **Required** | 52x52px, rounded |
| **Subtotal (Required)** | **10 icons** | — | Must-deliver set |
| Metadata icons (optional) | 4 | *Optional* | Can use emoji instead |
| **Total (including optional)** | **14 icons** | — | Full set if budget allows |

---

## ASSET DELIVERY SPECIFICATIONS

### File Format
- **Primary (standard):** SVG source + PNG exports (@1x, @2x, @3x) + one PDF preview sheet
- **Alternative (explicit approval):** iOS SF Symbols mapping manifest for specific icons
- **Naming:** snake_case with size suffix, e.g. `icon_chevron_right_16`

### Color Mode
- **Monochrome only** for icon glyphs (no accent colors)
- Grayscale range: #000000 (black) → #FFFFFF (white)
- Specific colors used:
  - Black: #000000
  - White: #FFFFFF (required for icons on black action buttons)
  - Light gray (VenuesVC): #b7bfd3
  - Light gray (VenueForMoviesVC): #c2cbe0
  - Medium gray (metadata): #808080

Gradient exception policy:
- Gradients are allowed only for non-glyph surfaces: poster placeholder fill and scroll blur overlays.
- Gradient usage must not be applied to icon glyph strokes/fills.

### Dimensions
| Size | Usage | Stroke Weight |
|------|-------|---|
| 32x32px | Favorite toggle | 2-2.5px |
| 16px | Chevrons, metadata | 1.5-2px |
| 15px | Chevron (alt) | 1.5-2px |
| 13px | Back button | 1.5-2px |
| 12px | Action icons, metadata | 1.5px |
| 52x52px | Poster placeholder | N/A (icon or gradient) |

### Design Rules
- **Background:** Always transparent
- **Safe area:** 1px padding inside bounds (minimum)
- **Stroke only** for unfilled icons (no solid fills except favorites filled state)
- **Corners:** Rounded corners where applicable (12-16px radius for placeholder)

---

## DELIVERY TIMELINE & CONTACTS

**Ready when:**
1. Designer confirms asset specifications above
2. Provide SVG or PNG (@1x, @2x, @3x) + PDF
3. Label files clearly (e.g., `icon-chevron-right-16px`, `icon-heart-favorite-32px`)

**iOS Dev receives assets in:**
- `SwiftCinemas/SwiftLoginScreen/Assets.xcassets/` (project-relative canonical target)
- Optional staging folder: `.ai/workflows/features/SwiftUIFeatures/extracted-assets/`
- Naming convention: snake_case, size suffix (e.g., `icon_chevron_right_16`)

**Related documentation:**
- Full inventory: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.redesign-icon-inventory.md`
- Styling guide: `speckit.swiftuifeatures.*.specify` (REQ-*-10, REQ-*-11, REQ-*-12, REQ-*-13)
- Runbook: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.redesign-implementation-runbook.md`

---

## Emoji Fallback Plan (if assets delayed)

If custom assets not available by implementation start date, use native emoji as temporary fallback:

```swift
// Navigation
let chevronRight = "›"  // or use .chevron.right from SF Symbols
let chevronLeft = "‹"   // or use .chevron.left from SF Symbols

// Interactions
let favoriteUnselected = "♡"  // or ☆
let favoriteSelected = "♥"    // or ★

// Actions
let actionBook = "🎫"
let actionDates = "📅"
let actionMap = "🗺️"
let actionMovie = "🎬"
let actionCalendar = "📆"

// Metadata
let metaLocation = "📍"
let metaHome = "🏠"
let metaCategory = "📁"
let metaDate = "📅"
```

---

## Sign-Off Checklist

- [ ] Designer confirms asset count and specifications
- [ ] Assets ready for delivery (SVG / PNG+PDF)
- [ ] File naming convention agreed
- [ ] Delivery location confirmed: `SwiftCinemas/SwiftLoginScreen/Assets.xcassets/`
- [ ] iOS dev integration ready (NSAttributedString binding, image loading)

---

## icons.png intake status (reviewed)

Source sheet:
- `.ai/workflows/features/SwiftUIFeatures/icons.png`

Auto-extracted (best effort) to:
- `.ai/workflows/features/SwiftUIFeatures/extracted-assets/`
- `.ai/workflows/features/SwiftUIFeatures/extracted-assets/manifest.json`

Coverage summary:
- Required navigation: extracted (3)
- Required favorite states: extracted (2)
- Required action icons: extracted (4 of 5) - `action_calendar_12` still needs explicit confirmation/provision
- Required placeholder: extracted (1 candidate)
- Optional metadata: extracted (4)

Verification note:
- Current extraction is layout/OCR-assisted best effort. Asset names and mappings must be visually confirmed before app integration.

