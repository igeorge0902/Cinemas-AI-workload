# UIKit Draft Notes: AdminVC + AdminUpdateVC (Pre-implementation)

This file is a draft-only companion for review. It does not change runtime code.

## Intent
- Implement new design only.
- Keep all existing features and backend contracts intact.
- Reuse existing shared/reusable cell/list/button patterns first.

## Draft component direction

### Reusable admin row style (draft)
```swift
// Draft idea only
struct AdminRowStyle {
    static let cornerRadius: CGFloat = 10
    static let borderColor = UIColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1)
    static let borderWidth: CGFloat = 1

    static func apply(to view: UIView) {
        view.layer.cornerRadius = cornerRadius
        view.layer.borderWidth = borderWidth
        view.layer.borderColor = borderColor.cgColor
        view.clipsToBounds = true
    }
}
```

### Reusable admin button style (draft)
```swift
// Draft idea only
extension UIButton {
    func applyAdminPrimaryButtonStyle() {
        backgroundColor = .black
        setTitleColor(.white, for: .normal)
        layer.cornerRadius = 12
        titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
    }
}
```

### Admin update venue marker row (draft)
```swift
// Draft idea only
func configureVenueCell(name: String, marker: String?, capacity: String?) {
    venueNameLabel.text = name
    markerLabel.text = marker // e.g. "(original)" or "(new selection)"
    capacityLabel.text = capacity // e.g. "capacity 280"
}
```

## Guardrails checklist
- [ ] No new backend functions/endpoints
- [ ] Keep payload/segue/notification contracts intact
- [ ] Movie update list in admin update mode shows movie name only
- [ ] Reusable side-deliverable implemented via shared components

