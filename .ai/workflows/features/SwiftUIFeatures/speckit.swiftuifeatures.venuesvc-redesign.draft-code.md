# Draft Code Notes - VenuesVC / VenuesMigration Redesign

> Goal: redesign only, keep existing storyboard and flow contracts.

## Target files
- `SwiftCinemas/SwiftLoginScreen/VenuesVC.swift`
- `SwiftCinemas/SwiftLoginScreen/VenuesMigration/VenuesMigration.swift`

## Draft UIKit additions (`VenuesVC`)
```swift
private var selectedVenueForNavigation: VenueModel?
private var continueButton: UIButton?
```

## Draft UIKit two-step flow
```swift
func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
    // ...existing admin/map branches unchanged...
    let data = tableData[indexPath.row]
    selectedVenueForNavigation = data
    VenuesDataManager.shared.selectedVenue = data
    detailsLabel.text = "📍 Venue: \(data.name)\n🏠 Address: \(data.address)"
    continueButton?.isEnabled = true
}

@objc private func continueToDetails() {
    guard selectedVenueForNavigation != nil else { return }
    performSegue(withIdentifier: "goto_venues_details", sender: self)
}
```

## Draft SwiftUI parity (`VenuesMigrationView` standard mode)
```swift
Button("View Details") {
    if let venue = viewModel.selectedVenue {
        viewModel.onNavigateToDetails?(venue)
    }
}
.disabled(viewModel.selectedVenue == nil)
```

## Draft styling note
- Apply same row spacing/typography polish in:
  - UIKit table cells (`VenuesVC`)
  - SwiftUI rows (`VenuePictureRow`, `VenueListRow` where applicable)

## Storyboard-safe constraints
- Keep `prepare(for segue:)` contract in `VenuesVC` unchanged.
- Keep segue string `"goto_venues_details"` unchanged.
- Keep migration host storyboard instantiation for `VenuesDetailsVC` unchanged.

## Draft regression hotspots
- Do not break map-flow selection dismissal in `VenuesVC`.
- Do not break admin selection notifications.
- Ensure bottom CTA state resets correctly when view reappears.

