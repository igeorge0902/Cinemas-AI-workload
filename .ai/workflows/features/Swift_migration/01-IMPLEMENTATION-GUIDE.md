# Shared Data Manager Implementation Guide

## Base Protocol Definition

Create a new file: `SwiftCinemas/SwiftLoginScreen/Networking/SharedDataManager.swift`

```swift
import Foundation

/// Base protocol for all shared data managers.
/// Defines common patterns for error handling, logging, and async/await patterns.
protocol SharedDataManager: AnyObject {
    /// Human-readable domain name for logging (e.g., "Movies", "Seats", "Auth")
    static var domain: String { get }
    
    /// Optional: override to add custom error handling per manager
    func handleError(_ error: Error) -> Error
}

extension SharedDataManager {
    func handleError(_ error: Error) -> Error {
        if let appError = error as? AppError {
            NSLog("[%@] AppError: %@", Self.domain, appError.localizedDescription)
        } else {
            NSLog("[%@] Error: %@", Self.domain, error.localizedDescription)
        }
        return error
    }
}

/// Optional generic base class for type-safe managers
class BaseDataManager<T>: SharedDataManager {
    static var domain: String {
        String(describing: T.self)
    }
}
```

---

## Injection Compatibility Rule (Must Keep)

Keep the current wiring model unchanged:
- `AppDelegate` owns `AppServices`
- ViewControllers may continue to use `HasAPIClient` + `injectAPIClientIfNeeded()`
- Existing `HasAppServices` usage remains valid

Migration scope is only to remove direct endpoint orchestration/parsing from VCs (for example `app.services.mbooks.moviesPaging(...)` in VC bodies). Do not remove or redesign the protocol-based injection layout.

---

## Implementation Pattern: MoviesData

Create/refactor file: `SwiftCinemas/SwiftLoginScreen/MoviesData.swift`

```swift
import Foundation
import SwiftyJSON
import UIKit

/// Manages all movie-related backend calls.
/// - Encapsulates `/mbooks-1/rest/book/movies` endpoints
/// - Returns strongly-typed [Movie] instead of raw JSON
final class MoviesData: SharedDataManager {
    static let shared = MoviesData()
    static var domain: String { "Movies" }
    
    private let mbooks: MbooksService
    private let images: ImageResourceService
    
    private init() {
        guard let app = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not accessible during MoviesData.shared init")
        }
        self.mbooks = app.services.mbooks
        self.images = app.services.images
    }
    
    /// MARK: - Movies (Browse & Search)
    
    /// Fetch paginated movies for browse view
    /// - Parameter query: [String: String] with setFirstResult, limit, etc.
    /// - Returns: Parsed array of Movie objects
    func fetchPaging(query: [String: String]) async throws -> [Movie] {
        do {
            let data = try await mbooks.moviesPaging(query: query)
            let json = try JSON(data: data)
            
            guard let movies = json["movies"].array else {
                throw AppError.decodingFailed
            }
            
            return movies.compactMap { Movie(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
    
    /// Search movies by query string
    /// - Parameter query: [String: String] with search term, pagination params
    /// - Returns: Filtered array of Movie objects
    func search(query: [String: String]) async throws -> [Movie] {
        do {
            let data = try await mbooks.moviesSearch(query: query)
            let json = try JSON(data: data)
            
            guard let movies = json["movies"].array else {
                throw AppError.decodingFailed
            }
            
            return movies.compactMap { Movie(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
    
    /// Fetch trending movies for home screen
    /// - Parameters:
    ///   - limit: max number of results (default 5)
    ///   - days: optional lookback period in days
    /// - Returns: Trending movies sorted by relevance
    func fetchTrending(limit: Int = 5, days: Int? = nil) async throws -> [Movie] {
        do {
            let data = try await mbooks.trendingMovies(limit: limit, days: days)
            let json = try JSON(data: data)
            
            guard let movies = json["movies"].array else {
                throw AppError.decodingFailed
            }
            
            return movies.compactMap { Movie(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
    
    /// MARK: - Batch Operations (Preload Images)
    
    /// Pre-download all movie posters for a collection
    /// Called after fetchPaging() to warm image cache
    /// - Parameter movies: Array of Movie objects with large_picture URLs
    func preloadImages(for movies: [Movie]) {
        Task {
            for movie in movies {
                let fullURL = URLManager.image(movie.large_picture)
                _ = try? await images.getData(urlString: fullURL, realmCache: true)
            }
        }
    }
}

/// MARK: - Movie Data Model

struct Movie {
    let movieId: Int
    let movieIdString: String
    let name: String
    let detail: String
    let large_picture: String
    let iMDB_url: String
    
    init?(json: JSON) {
        guard let idStr = json["movieId"].string,
              let id = Int(idStr),
              let name = json["name"].string,
              let detail = json["detail"].string,
              let picture = json["large_picture"].string,
              let imdb = json["iMDB_url"].string else {
            return nil
        }
        
        self.movieId = id
        self.movieIdString = idStr
        self.name = name
        self.detail = detail
        self.large_picture = picture
        self.iMDB_url = imdb
    }
}
```

---

## Implementation Pattern: SeatsData

Create/refactor file: `SwiftCinemas/SwiftLoginScreen/SeatsData.swift`

```swift
import Foundation
import SwiftyJSON
import UIKit

/// Manages seat availability and booking for a screening
final class SeatsData: SharedDataManager {
    static let shared = SeatsData()
    static var domain: String { "Seats" }
    
    private let mbooks: MbooksService
    
    private init() {
        guard let app = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not accessible during SeatsData.shared init")
        }
        self.mbooks = app.services.mbooks
    }
    
    /// MARK: - Seat Queries
    
    /// Fetch all seats for a screening with availability status
    /// - Parameter screeningDateId: ID of the screening date
    /// - Returns: Array of Seat objects grouped by row
    func fetchSeats(screeningDateId: Int) async throws -> [Seat] {
        do {
            let data = try await mbooks.seats(screeningDateId: String(screeningDateId))
            let json = try JSON(data: data)
            
            guard let seatList = json["seatsforscreen"].array else {
                throw AppError.decodingFailed
            }
            
            return seatList.compactMap { Seat(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
    
    /// Group seats by row letter for UI display
    /// - Parameter seats: Raw seat array from fetchSeats()
    /// - Returns: Dictionary [rowLetter: [Seat]]
    func groupByRow(_ seats: [Seat]) -> [String: [Seat]] {
        Dictionary(grouping: seats, by: { $0.seatRow })
    }
}

/// MARK: - Seat Data Model

struct Seat {
    let seatId: Int
    let seatNumber: String
    let seatRow: String
    let isReserved: Bool  // "0" → false, "1" → true
    let price: Int
    let tax: Double
    
    init?(json: JSON) {
        guard let id = json["seatId"].int,
              let number = json["seatNumber"].string,
              let row = json["seatRow"].string,
              let reserved = json["isReserved"].string,
              let price = json["price"].int,
              let tax = json["tax"].double else {
            return nil
        }
        
        self.seatId = id
        self.seatNumber = number
        self.seatRow = row
        self.isReserved = reserved == "1"
        self.price = price
        self.tax = tax
    }
}
```

---

## Implementation Pattern: LocationsData (PlacesData renamed)

Create/refactor file: `SwiftCinemas/SwiftLoginScreen/LocationsData.swift`

```swift
import Foundation
import MapKit
import SwiftyJSON
import UIKit

/// Manages venue locations and geographic data
final class LocationsData: SharedDataManager {
    static let shared = LocationsData()
    static var domain: String { "Locations" }
    
    private let mbooks: MbooksService
    
    private init() {
        guard let app = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not accessible during LocationsData.shared init")
        }
        self.mbooks = app.services.mbooks
    }
    
    /// MARK: - Locations
    
    /// Fetch all cinema locations
    /// - Returns: Array of Location objects (can be used as MapKit annotations)
    func fetchLocations() async throws -> [Location] {
        do {
            let data = try await mbooks.locations()
            let json = try JSON(data: data)
            
            guard let locations = json["locations"].array else {
                throw AppError.decodingFailed
            }
            
            return locations.compactMap { Location(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
    
    /// Fetch venue details for a specific location
    /// - Parameter venuesId: ID of the venue
    /// - Returns: Location object with full details
    func fetchVenue(id venuesId: String) async throws -> Location {
        do {
            let data = try await mbooks.locationsVenue(venuesId: venuesId)
            let json = try JSON(data: data)
            
            guard let locJson = json["location"].dictionary else {
                throw AppError.decodingFailed
            }
            
            guard let location = Location(json: JSON(locJson)) else {
                throw AppError.decodingFailed
            }
            
            return location
        } catch {
            throw handleError(error)
        }
    }
}

/// MARK: - Location Data Model

struct Location: NSObject, MKAnnotation {
    let locationId: Int
    let title: String?
    let address: String
    let formattedAddress: String
    let type: String
    let coordinate: CLLocationCoordinate2D
    let thumbnail: String?
    
    init?(json: JSON) {
        guard let id = json["locationId"].int,
              let name = json["name"].string,
              let address = json["address"].string,
              let formatted = json["formatted_address"].string,
              let latitude = json["latitude"].double,
              let longitude = json["longitude"].double else {
            return nil
        }
        
        self.locationId = id
        self.title = name
        self.address = address
        self.formattedAddress = formatted
        self.type = "movie_theater"
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.thumbnail = json["thumbnail"].string ?? "No picture"
        
        super.init()
    }
    
    // MARK: - MKAnnotation Protocol
    
    dynamic var subtitle: String? {
        address
    }
    
    func pinColor() -> MKPinAnnotationColor {
        .red
    }
    
    func mapItem() -> MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate, 
                                    addressDictionary: [kABPersonAddressStreetKey: address])
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = title
        return mapItem
    }
}
```

---

## Implementation Pattern: BasketData (Shopping Cart)

Create/refactor file: `SwiftCinemas/SwiftLoginScreen/BasketData.swift`

```swift
import Foundation
import SwiftyJSON
import UIKit

/// Manages shopping basket (ticket cart) operations
/// - Encapsulates `/login/CheckOut` proxy servlet endpoints
/// - Handles payment flow, basket state, and ticket reservation
final class BasketData: SharedDataManager {
    static let shared = BasketData()
    static var domain: String { "Basket" }
    
    private let loginGateway: LoginGatewayService
    
    private init() {
        guard let app = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not accessible during BasketData.shared init")
        }
        self.loginGateway = app.services.loginGateway
    }
    
    /// MARK: - Basket Operations
    
    /// Get Braintree client token for payment form setup
    /// - Returns: ClientToken containing token and APIKEY for Braintree
    func getClientToken() async throws -> ClientToken {
        do {
            let data = try await loginGateway.getCheckOut()
            let json = try JSON(data: data)
            
            guard let clientToken = json["clientToken"].string,
                  let apiKey = json["APIKEY"].string else {
                throw AppError.decodingFailed
            }
            
            return ClientToken(clientToken: clientToken, apiKey: apiKey)
        } catch {
            throw handleError(error)
        }
    }
    
    /// Submit payment and create purchase
    /// - Parameters:
    ///   - nonce: Braintree payment method nonce from client token
    ///   - orderId: Unique order identifier
    ///   - seatsToBeReserved: Concatenated seat string (e.g., "A1-B2-C3-")
    /// - Returns: Purchase object with transaction details
    func submitPayment(nonce: String, orderId: String, seatsToBeReserved: String) async throws -> Purchase {
        do {
            let postBody = "payment_method_nonce=\(nonce)&orderId=\(orderId)&seatsToBeReserved=\(seatsToBeReserved)"
            let bodyData = postBody.data(using: .utf8)!
            
            let responseData = try await loginGateway.postCheckOut(body: bodyData)
            let json = try JSON(data: responseData)
            
            guard let status = json["status"].string else {
                throw AppError.decodingFailed
            }
            
            if status != "success" {
                let message = json["message"].string ?? "Payment failed"
                NSLog("[%@] Payment rejected: %@", Self.domain, message)
                throw AppError.httpError(statusCode: 400, message: message)
            }
            
            guard let purchase = Purchase(json: json) else {
                throw AppError.decodingFailed
            }
            
            return purchase
        } catch {
            throw handleError(error)
        }
    }
    
    /// MARK: - Basket State
    
    /// Get current basket (purchases for logged-in user)
    /// - Returns: Array of tickets/purchases in current session
    func getBasket() async throws -> [Purchase] {
        do {
            let data = try await loginGateway.getCheckOut()
            let json = try JSON(data: data)
            
            guard let purchases = json["purchases"].array else {
                return []
            }
            
            return purchases.compactMap { Purchase(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
}

/// MARK: - Basket Data Models

struct ClientToken {
    let clientToken: String
    let apiKey: String
}

struct Purchase {
    let purchaseId: Int
    let orderId: String
    let status: String  // "pending", "confirmed", "cancelled"
    let amount: Double
    let currency: String
    let seats: [String]  // Array of seat identifiers
    let transactionId: String?
    let createdAt: String
    
    init?(json: JSON) {
        guard let id = json["purchaseId"].int,
              let order = json["orderId"].string,
              let status = json["status"].string,
              let amount = json["amount"].double else {
            return nil
        }
        
        self.purchaseId = id
        self.orderId = order
        self.status = status
        self.amount = amount
        self.currency = json["currency"].string ?? "USD"
        self.seats = json["seats"].arrayValue.compactMap { $0.string }
        self.transactionId = json["transactionId"].string
        self.createdAt = json["createdAt"].string ?? ""
    }
}
```

---

## Update ViewControllers: MoviesVC Example

Before:
```swift
func loadMovies() {
    Task { @MainActor in
        guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
        do {
            let data = try await app.services.mbooks.moviesPaging(
                query: ["setFirstResult": String(0)]
            )
            let json = try JSON(data: data)
            // manually parse JSON...
        } catch {
            NSLog("Error: %@", error.localizedDescription)
        }
    }
}
```

After:
```swift
func loadMovies() {
    Task { @MainActor in
        do {
            self.movies = try await MoviesData.shared.fetchPaging(
                query: ["setFirstResult": "0"]
            )
            // Preload images async (doesn't block UI)
            MoviesData.shared.preloadImages(for: self.movies)
            tableView.reloadData()
        } catch {
            NSLog("MoviesVC: %@", error.localizedDescription)
        }
    }
}
```

---

## Screen-to-Screen Data Passing Plan (Manager Properties)

### Goal
Move cross-screen state from repeated segue assignments and globals into manager-owned context properties.

### Context Property Contracts

```swift
// MoviesDataManager
var selectedMovie: Movie? { get set }

// VenuesDataManager
var selectedVenue: Venue? { get set }

// LocationsDataManager
var selectedLocationId: Int? { get set }
var isMapFromVenueDetails: Bool { get set }

// DatesDataManager
var selectedScreeningDateId: String? { get set }
var selectedScreeningDateText: String? { get set }

// SeatsDataManager
var selectedSeatIds: [Int] { get set }
var selectedSeatNumbers: [String] { get set }

// BasketDataManager
var basketItemsBySeatId: [Int: BasketItem] { get set }
var seatsToReservePayloadByScreening: [String: String] { get set }

// PurchasesDataManager
var selectedPurchaseId: String? { get set }
```

### Migration Pattern for `prepare(for:)`

Before:
```swift
override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "goto_venues" {
        let next = segue.destination as? VenuesVC
        next?.movieId = movie.movieId
        next?.movieName = movie.name
        next?.selectDetails = movie.detail
        next?.selectLarge_picture = movie.large_picture
        next?.imdb = movie.imdb
    }
}
```

After:
```swift
override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "goto_venues" {
        MoviesDataManager.shared.selectedMovie = selectedMovie
        // Segue is now route-only.
    }
}
```

Destination VC:
```swift
override func viewDidLoad() {
    super.viewDidLoad()
    let selected = MoviesDataManager.shared.selectedMovie
    // consume selected and render
}
```

### Flow-by-Flow Ownership
- Movies -> MovieDetail/Venues: `MoviesDataManager.selectedMovie`
- Venues -> VenueDetails: `VenuesDataManager.selectedVenue`
- VenueDetails -> Map: `LocationsDataManager.selectedLocationId`
- Dates picker -> Seats/Basket: `DatesDataManager.selectedScreeningDateId`
- Seats popover -> Basket/Checkout: `SeatsDataManager` + `BasketDataManager`
- Purchases -> Tickets: `PurchasesDataManager.selectedPurchaseId`

### Cleanup Rule
After checkout completion or flow cancellation, call manager reset methods:

```swift
DatesDataManager.shared.resetNavigationContext()
SeatsDataManager.shared.resetNavigationContext()
BasketDataManager.shared.resetNavigationContext()
```

---

## Key Principles for All Implementations

1. **Single Responsibility**: Each manager handles one resource domain
2. **Type Safety**: Return `[Movie]` not `Data`
3. **Error Propagation**: Use `throw handleError()` consistently
4. **Async/Await**: All network calls use native Swift concurrency
5. **No UI Logic**: Data managers don't touch views
6. **Injection Layout Preserved**: Keep `AppDelegate` -> `AppServices` ownership and VC protocol-based injection (`HasAPIClient`, `injectAPIClientIfNeeded`, `HasAppServices`)
7. **Logging**: Include domain in all NSLog calls: `NSLog("[%@] message", Self.domain)`

---

## Testing Examples

### Unit Test for MoviesData
```swift
@MainActor
class MoviesDataTests: XCTestCase {
    var moviesData: MoviesData!
    var mockMbooks: MockMbooksService!
    
    override func setUp() {
        super.setUp()
        mockMbooks = MockMbooksService()
        // Inject mock service
        moviesData = MoviesData(mbooks: mockMbooks, images: MockImageService())
    }
    
    func testFetchPagingSuccess() async throws {
        // Setup mock to return valid JSON
        mockMbooks.moviesPagingResult = """
        { "movies": [
            { "movieId": "1", "name": "Test Movie", ... }
        ]}
        """.data(using: .utf8)!
        
        let movies = try await moviesData.fetchPaging(query: ["setFirstResult": "0"])
        
        XCTAssertEqual(movies.count, 1)
        XCTAssertEqual(movies[0].name, "Test Movie")
    }
    
    func testFetchPagingFailure() async {
        mockMbooks.shouldFail = true
        
        do {
            _ = try await moviesData.fetchPaging(query: [:])
            XCTFail("Expected AppError")
        } catch is AppError {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
```

---

## References

- Current implementation: `SwiftCinemas/SwiftLoginScreen/Networking/BackendServices.swift`
- Error types: `SwiftCinemas/SwiftLoginScreen/Networking/AppError.swift`
- URL management: `SwiftCinemas/SwiftLoginScreen/Networking/URLManager.swift`
