# SwiftUIFeatures Redesign - Icon & Asset Inventory

Date: 2026-05-10
Owner: `@ios-dev`
Scope: all four redesigned screens
Status: Requirement capture (ready for asset procurement/implementation)

## Global styling constraints (all screens)
- **Screen background:** white (#FFFFFF)
- **Navigation buttons:** black (#000000), text-filled
- **Other interactive buttons:** grayscale (black/white/gray range only)
- **Text rendering:** NSAttributedString with configurable font family + size
- **No accent colors** for primary UI surfaces, controls, or typography

---

## Icon inventory by screen

### Screen 1: MoviesVC (moviesvc-redesign)

| Element | Type | Icon/Asset | Size | Color | State | Qty | Notes |
|---------|------|-----------|------|-------|-------|-----|-------|
| Favorite toggle | Button | Heart or Star | 32x32px | Monochrome | Outline ☆ / Filled ★ | Per row | 2 states: unfavorited + favorited |
| Movie poster placeholder | Image | Film reel or gradient | 52x52px | Gradient | Default | Per movie | Fallback for missing picture |
| Category chips | Text | None (text-only) | — | — | — | ~5 chips | "All", "Action", "Drama", "Crime", "Romance", "Troll" |
| Back button | Nav | Text "Back" | — | Black | Active | 1 | Remains text-based, no icon |

**Sub-total: 2 unique icons required**

---

### Screen 2: VenuesVC (venuesvc-redesign)

| Element | Type | Icon/Asset | Size | Color | State | Qty | Notes |
|---------|------|-----------|------|-------|-------|-----|-------|
| Row navigation chevron | Nav | Chevron › or right arrow | 16px | Light gray (#b7bfd3) | Static | ~10 instances | One per venue row |
| Back button | Nav | Chevron ‹ or back arrow | 13px | Black | Active | 1 | Top-left navigation |
| Address metadata (optional) | Icon | 📍 Location pin or 🏠 Home | 16px | Gray | Static | Optional | Emoji or asset for venue address |
| Bottom CTA button | Button | Text + optional arrow | 12px | Black | Active / Disabled | 1 | "Navigate to Details" button |

**Sub-total: 3 unique elements (including optional emoji)**

---

### Screen 3: VenueForMoviesVC (venueformoviesvc-redesign)

| Element | Type | Icon/Asset | Size | Color | State | Qty | Notes |
|---------|------|-----------|------|-------|-------|-----|-------|
| Row navigation chevron | Nav | Chevron › or arrow | 15px | Light gray (#c2cbe0) | Static | ~6 instances | One per movie-venue row |
| Movie poster placeholder | Image | Film reel or gradient | 52x52px | Gradient | Default | Per row | Fallback for missing picture |
| Category metadata icon (optional) | Icon | 📁 Folder or tag | 12px | Gray | Static | Optional | Category indicator |
| Screening date icon (optional) | Icon | 📅 Calendar | 12px | Gray | Static | Optional | Date indicator |

**Sub-total: 2-4 unique elements (depending on optional metadata icons)**

---

### Screen 4: VenuesDetailsVC (venuesdetailsvc-redesign)

| Element | Type | Icon/Asset | Size | Color | State | Qty | Notes |
|---------|------|-----------|------|-------|-------|-----|-------|
| Back button | Nav | Chevron ‹ or back arrow | 13px | Black | Active | 1 | Hero area top-left; semi-transparent pill background |
| Action: Book | Button | 🎫 Ticket | 12px | Black text | Active | 1 | Full-width, left-aligned icon + text |
| Action: Dates | Button | 📅 Calendar | 12px | Black text | Active | 1 | Full-width, left-aligned icon + text |
| Action: Map | Button | 🗺️ Map | 12px | Black text | Active | 1 | Full-width, left-aligned icon + text |
| Action: Movie Detail | Button | 🎬 Film | 12px | Black text | Active | 1 | Full-width, left-aligned icon + text |
| Action: Calendar | Button | 📆 Calendar alt | 12px | Black text | Active | 1 | Full-width, left-aligned icon + text |
| Blur effect | Visual | iOS UIBlurEffect | — | Gradient (#000000 0-80%) | Scroll-driven | 1 | Adaptive Light/Dark |
| Back affordance hint (optional) | Icon | Chevron ↑ or swipe | 12px | Gray | Static | Optional | Scroll-up gesture indicator |

**Sub-total: 6-7 unique action icons (including optional hint)**

---

## Consolidated icon asset list

### Required assets (high priority)

1. **Chevron/Navigation icons**
   - Right-pointing chevron › (16px light gray — VenuesVC)
   - Right-pointing chevron › (15px light gray — VenueForMoviesVC)
   - Left-pointing chevron ‹ (13px black — Back button, both screens)
   - Variants: iOS SF Symbols `chevron.right`, `chevron.left`, or custom SVG

2. **Favorite toggle**
   - Heart (outline + filled) OR Star (outline + filled)
   - 32x32px, monochrome
   - 2 states: unfavorited (outline), favorited (filled)

3. **Action icons (VenuesDetailsVC)**
   - Ticket 🎫 or generic ticket symbol
   - Calendar 📅 or date picker
   - Map 🗺️ or location marker
   - Film 🎬 or movie reel
   - Calendar variant 📆 (if different from Dates)
   - All 12px, black, left-aligned in full-width buttons
   - Variants: emoji, iOS SF Symbols, or custom SVG

### Optional assets (lower priority, can use emoji)

4. **Metadata icons**
   - Location pin 📍 (16px gray — venue address)
   - Home 🏠 (16px gray — venue address alt)
   - Folder 📁 (12px gray — category indicator)
   - Calendar 📅 (12px gray — screening date indicator)
   - Recommendation: use native emoji to reduce asset burden

### Visual effects (no asset file needed)

5. **Blur overlay**
   - iOS `UIBlurEffect(style: .light)` or `.dark` with `UIVisualEffectView`
   - 0-80% opacity gradient based on scroll progress
   - Applied to hero media in VenuesDetailsVC

---

## Asset specifications

### Icon standard format
- **Format:** PNG + PDF (for resolution independence) OR iOS SF Symbols (preferred)
- **Color:** Monochrome (grayscale, black, white, gray range)
- **Background:** Transparent
- **Stroke:** 1.5-2px for 12-16px icons, 2-2.5px for 32px
- **Safe area:** 1px padding inside bounds

### Emoji fallback strategy
- If custom assets not available, use native emoji:
  - Favorite: ♥️ (heart) or ⭐ (star)
  - Navigation: › (right) / ‹ (left)
  - Actions: 🎫, 📅, 🗺️, 🎬, 📆
  - Metadata: 📍, 🏠, 📁
- Emoji sizing: dependent on font size used in NSAttributedString

---

## Implementation checklist

| Item | Screen | Priority | Status | Notes |
|------|--------|----------|--------|-------|
| Right chevron (16px) | VenuesVC | Required | — | Light gray (#b7bfd3) |
| Right chevron (15px) | VenueForMoviesVC | Required | — | Light gray (#c2cbe0) |
| Left chevron (13px) | VenuesVC + VenuesDetailsVC | Required | — | Black, back button |
| Heart/Star toggle (32px) | MoviesVC | Required | — | 2 states (outline + filled) |
| Ticket icon (12px) | VenuesDetailsVC (Book) | Required | — | Black text |
| Calendar icon (12px) | VenuesDetailsVC (Dates) | Required | — | Black text |
| Map icon (12px) | VenuesDetailsVC (Map) | Required | — | Black text |
| Film icon (12px) | VenuesDetailsVC (Movie Detail) | Required | — | Black text |
| Calendar variant (12px) | VenuesDetailsVC (Calendar) | Required | — | Black text (alt calendar) |
| Location pin emoji | VenuesVC | Optional | — | Metadata, 16px gray |
| Home emoji | VenuesVC | Optional | — | Metadata alt, 16px gray |
| Folder emoji | VenueForMoviesVC | Optional | — | Category indicator, 12px |
| Date emoji | VenueForMoviesVC | Optional | — | Screening date, 12px |

---

## Noted missing assets / deferred items

- **Movie poster placeholder:** Film reel icon or gradient fill (52x52px) — used in movie list cells when image unavailable
- **Blur visual effect:** UIBlurEffect in VenuesDetailsVC (iOS native, no asset file)
- **Scroll-up gesture hint:** Optional chevron ↑ or swipe indicator for hero media (low priority)

---

## Backlog linkage

- Styling constraints: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.*.specify` files (REQ-*-10, REQ-*-11, REQ-*-12, REQ-*-13 sections)
- Deferred safety items: `RISK-MVC-SAFE-001` (category force-unwrap crash hardening)
- Implementation runbook: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.redesign-implementation-runbook.md`

