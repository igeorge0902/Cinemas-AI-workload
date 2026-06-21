# Draft Code Notes - VenueForMoviesVC Redesign (UIKit)

> Goal: redesign only, preserve storyboard behavior.

## Target files
- `SwiftCinemas/SwiftLoginScreen/VenueForMoviesVC.swift`
- `SwiftCinemas/SwiftLoginScreen/MovieCollectionViewCell.swift`

## Draft display DTO (`VenueForMoviesVC`)
```swift
private struct VenueMovieRowDisplay {
    let title: String
    let imagePath: String
    let categoryText: String
    let screeningDateText: String
}
```

## Draft mapping helper
```swift
private func makeDisplayRow(from selection: VenueMovieSelection) -> VenueMovieRowDisplay {
    let movie = selection.movie
    let category = movie.category?.isEmpty == false ? movie.category! : "N/A"
    let screeningDate = selection.screeningDate?.isEmpty == false ? selection.screeningDate! : "TBA"
    return VenueMovieRowDisplay(
        title: movie.name,
        imagePath: movie.largePicture,
        categoryText: "Category: \(category)",
        screeningDateText: "Screening Date: \(screeningDate)"
    )
}
```

## Draft single-column list layout
```swift
if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
    layout.minimumLineSpacing = 10
    layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    layout.itemSize = CGSize(width: view.bounds.width - 20, height: 100)
}
```

## Draft cell extension (`MovieCollectionViewCell`)
```swift
func configureRedesign(title: String, category: String, screeningDate: String) {
    textLabel.text = title
    categoryLabel.text = category
    screeningDateLabel.text = screeningDate
}
```

## Draft storyboard-safe constraints
- Keep `performSegue(withIdentifier: "goto_venues_details2", sender: self)` unchanged.
- Keep `prepare(for:sender:)` selection extraction unchanged.
- Keep `navigateBack()` unchanged.

## Draft regression hotspots
- Verify selected index in `prepare(for:)` still maps into `tableData` correctly after layout change.
- Verify image load async still updates the correct reused cell.

