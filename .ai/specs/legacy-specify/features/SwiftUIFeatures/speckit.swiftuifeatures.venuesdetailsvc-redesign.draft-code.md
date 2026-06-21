# Draft Code Notes - VenuesDetailsVC Redesign (UIKit)

> Goal: redesign only, keep current selectors/segues/contracts.

## Target file
- `SwiftCinemas/SwiftLoginScreen/VenuesDetailsVC.swift`

## Draft blur overlay properties
```swift
private let heroBlurOverlay = UIVisualEffectView(effect: nil)
private let maxBlurRadius: CGFloat = 14
```

## Draft scroll mapping
```swift
func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let progress = max(0, min(1, scrollView.contentOffset.y / 180.0))
    heroBlurOverlay.effect = UIBlurEffect(style: .systemUltraThinMaterial)
    heroBlurOverlay.alpha = 0.1 + (0.4 * progress)
}
```

## Draft vertical buttons creation
```swift
private func setupButtonsVertical() {
    let actions: [(String, Selector)] = [
        ("Book", #selector(book)),
        ("Dates", #selector(dates)),
        ("Map", #selector(map)),
        ("Movie Detail", #selector(movieDetail)),
        ("Calendar", #selector(selectCalendar))
    ]
    // Build one-column button stack, keep selectors unchanged.
}
```

## Draft ordering note
```swift
private func setupUI() {
    setupTextView()      // text first
    setupButtonsVertical()
    setupPlayer()        // media remains available
}
```

## Storyboard-safe constraints
- Keep `performSegue(withIdentifier: "goto_map2", sender: self)` unchanged.
- Keep `performSegue(withIdentifier: "goto_movie_detail2", sender: self)` unchanged.
- Keep all popover presentation flow unchanged.

## Draft regression hotspots
- Ensure `book` still enforces selected date and uses `SeatsDataManager` same way.
- Ensure `dates` still loads from `DatesDataManager` and opens `PopOverDates`.
- Ensure no duplicate player/subview setup on repeated `viewDidAppear`.

