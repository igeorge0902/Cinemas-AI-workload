# Draft Code Notes - MoviesVC Redesign (UIKit)

> Goal: redesign only, keep storyboard/flow behavior.

## Target files
- `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift`
- `SwiftCinemas/SwiftLoginScreen/ListViewCell.swift`

## Draft model additions (`MoviesVC`)
```swift
private var categoryChips: [String] = []
private var favoritesByMovieId: [Int: Bool] = [:]
private var ratingsByMovieId: [Int: String] = [:]
```

## Draft fixture loader (`MoviesVC`)
```swift
private func loadRatingsFixture() {
    guard let url = Bundle.main.url(forResource: "ratings-mock", withExtension: "json") else { return }
    do {
        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(RatingsPayload.self, from: data)
        ratingsByMovieId = Dictionary(uniqueKeysWithValues: payload.ratings.map { ($0.movieId, $0.rating) })
    } catch {
        ratingsByMovieId = [:]
        NSLog("MoviesVC ratings fixture failed: %@", error.localizedDescription)
    }
}
```

## Draft chip tap handler (`MoviesVC`)
```swift
@objc private func didTapCategoryChip(_ sender: UIButton) {
    let title = sender.currentTitle ?? ""
    category_ = (title == "All") ? nil : title
    SearchData.removeAll()
    TableData.removeAll()
    addData(category: category_ ?? "nil")
}
```

## Draft category source resolver (`MoviesVC`)
```swift
private let fallbackCategories = ["All", "Action", "Drama", "Comedy"]

private func extractedCategory(from movie: MovieDataModel) -> String? {
    // Read from whichever field/adapter is currently available in MoviesVC.
    // Keep this helper local so no backend or model contract changes are required.
    return nil
}

private func resolveCategories(from movies: [MovieDataModel]) {
    let fromBackend = Set(movies.compactMap { movie in
        let raw = extractedCategory(from: movie)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (raw?.isEmpty == false) ? raw : nil
    })

    if fromBackend.isEmpty {
        categoryChips = fallbackCategories
        NSLog("MoviesVC categories source=fallback count=%d", categoryChips.count)
    } else {
        categoryChips = ["All"] + fromBackend.sorted()
        NSLog("MoviesVC categories source=backend count=%d", categoryChips.count)
    }
}
```

## Draft cell binding extension (`ListViewCell`)
```swift
func configureRedesign(
    title: String,
    rating: String,
    isFavorite: Bool,
    onFavoriteTap: (() -> Void)?
) {
    titleText.text = title
    ratingLabel.text = "Rating: \(rating)"
    favoriteButton.isSelected = isFavorite
    favoriteTapHandler = onFavoriteTap
}
```

## Draft storyboard-safe constraints
- Keep `performSegue(withIdentifier: "goto_venues", sender: self)` unchanged.
- Keep `performSegue(withIdentifier: "goto_movie_detail", sender: button)` unchanged.
- Keep `prepare(for:sender:)` mapping unchanged.

## Draft regression hotspots
- `tableView(_:didSelectRowAt:)` branch that triggers migration factory.
- `numberOfSections` + `numberOfRowsInSection` behavior when chips/categories/search interact.
- `configureLayout(compact:)` must still handle admin/update rows.

