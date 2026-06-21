# Complete Data Manager Implementations

This document provides ready-to-implement code for all refactored data managers.

---

## 1. SharedDataManager Protocol (Base)

**File:** `SwiftCinemas/SwiftLoginScreen/Networking/SharedDataManager.swift`

```swift
import Foundation

/// Base protocol for all shared data managers
protocol SharedDataManager: AnyObject {
    static var domain: String { get }
    func handleError(_ error: Error) -> Error
}

extension SharedDataManager {
    func handleError(_ error: Error) -> Error {
        if let appError = error as? AppError {
            NSLog("[%@] %@", Self.domain, appError.localizedDescription)
        } else {
            NSLog("[%@] %@", Self.domain, error.localizedDescription)
        }
        return error
    }
}
```

---

## 2. SeatsData Manager

**File:** `SwiftCinemas/SwiftLoginScreen/Managers/SeatsDataManager.swift`

```swift
import Foundation
import SwiftyJSON
import UIKit

final class SeatsDataManager: SharedDataManager {
    static let shared = SeatsDataManager()
    static var domain: String { "Seats" }
    
    private let mbooks: MbooksService
    
    private init() {
        guard let app = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not found")
        }
        self.mbooks = app.services.mbooks
    }
    
    /// Fetch seats for a screening with full availability data
    func fetchSeats(screeningDateId: Int) async throws -> [SeatModel] {
        do {
            let data = try await mbooks.seats(screeningDateId: String(screeningDateId))
            let json = try JSON(data: data)
            
            guard let seatArray = json["seatsforscreen"].array else {
                throw AppError.decodingFailed
            }
            
            return seatArray.compactMap { SeatModel(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
    
    /// Group seats by row for table view rendering
    func groupByRow(_ seats: [SeatModel]) -> [String: [SeatModel]] {
        var grouped: [String: [SeatModel]] = [:]
        for seat in seats {
            if grouped[seat.seatRow] == nil {
                grouped[seat.seatRow] = []
            }
            grouped[seat.seatRow]?.append(seat)
        }
        return grouped
    }
    
    /// Get unique rows sorted alphabetically
    func getRows(_ seats: [SeatModel]) -> [String] {
        Array(Set(seats.map { $0.seatRow })).sorted()
    }
}

struct SeatModel {
    let seatId: Int
    let seatNumber: String
    let seatRow: String
    let isReserved: Bool
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

## 3. DatesData Manager

**File:** `SwiftCinemas/SwiftLoginScreen/Managers/DatesDataManager.swift`

```swift
import Foundation
import SwiftyJSON

final class DatesDataManager: SharedDataManager {
    static let shared = DatesDataManager()
    static var domain: String { "Dates" }
    
    private let mbooks: MbooksService
    
    private init() {
        guard let app = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not found")
        }
        self.mbooks = app.services.mbooks
    }
    
    /// Fetch screening dates for movie at location
    func fetchDates(locationId: String, movieId: String) async throws -> [DateModel] {
        do {
            let data = try await mbooks.dates(locationId: locationId, movieId: movieId)
            let json = try JSON(data: data)
            
            guard let dateArray = json["dates"].array else {
                throw AppError.decodingFailed
            }
            
            return dateArray.compactMap { DateModel(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
    
    /// Fetch dates for a specific screen
    func fetchDatesForScreen(screenId: String) async throws -> [DateModel] {
        do {
            let data = try await mbooks.dates(screenId: screenId)
            let json = try JSON(data: data)
            
            guard let dateArray = json["dates"].array else {
                throw AppError.decodingFailed
            }
            
            return dateArray.compactMap { DateModel(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
}

struct DateModel {
    let screeningDateId: String
    let date: String
    let time: String?
    
    init?(json: JSON) {
        guard let screeningId = json["screeningDateId"].string else {
            return nil
        }
        self.screeningDateId = screeningId
        self.date = json["date"].string ?? ""
        self.time = json["time"].string
    }
}
```

---

## 4. VenuesData Manager

**File:** `SwiftCinemas/SwiftLoginScreen/Managers/VenuesDataManager.swift`

```swift
import Foundation
import SwiftyJSON

final class VenuesDataManager: SharedDataManager {
    static let shared = VenuesDataManager()
    static var domain: String { "Venues" }
    
    private let mbooks: MbooksService
    
    private init() {
        guard let app = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not found")
        }
        self.mbooks = app.services.mbooks
    }
    
    /// Fetch venues showing a specific movie
    func fetchVenuesForMovie(movieId: String) async throws -> [VenueModel] {
        do {
            let data = try await mbooks.venue(movieId: movieId)
            let json = try JSON(data: data)
            
            guard let venueArray = json["venues"].array else {
                throw AppError.decodingFailed
            }
            
            return venueArray.compactMap { VenueModel(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
    
    /// Fetch movies available at a specific location
    func fetchMoviesAtLocation(locationId: String) async throws -> [MovieModel] {
        do {
            let data = try await mbooks.venueMovies(locationId: locationId)
            let json = try JSON(data: data)
            
            guard let movieArray = json["movies"].array else {
                throw AppError.decodingFailed
            }
            
            return movieArray.compactMap { MovieModel(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
}

struct VenueModel {
    let venuesId: Int
    let name: String
    let address: String
    let venuesPicture: String
    let screenId: String
    let locationId: Int
    
    init?(json: JSON) {
        guard let id = json["venuesId"].int,
              let name = json["name"].string,
              let address = json["address"].string,
              let picture = json["venues_picture"].string,
              let screenId = json["screen_screenId"].string,
              let locId = json["locationId"].int else {
            return nil
        }
        self.venuesId = id
        self.name = name
        self.address = address
        self.venuesPicture = picture
        self.screenId = screenId
        self.locationId = locId
    }
}

struct MovieModel {
    let movieId: String
    let name: String
    
    init?(json: JSON) {
        guard let id = json["movieId"].string,
              let name = json["name"].string else {
            return nil
        }
        self.movieId = id
        self.name = name
    }
}
```

---

## 5. LocationsData Manager (formerly PlacesData)

**File:** `SwiftCinemas/SwiftLoginScreen/Managers/LocationsDataManager.swift`

```swift
import Foundation
import MapKit
import SwiftyJSON

final class LocationsDataManager: SharedDataManager {
    static let shared = LocationsDataManager()
    static var domain: String { "Locations" }
    
    private let mbooks: MbooksService
    
    private init() {
        guard let app = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not found")
        }
        self.mbooks = app.services.mbooks
    }
    
    /// Fetch all cinema locations
    func fetchLocations() async throws -> [LocationModel] {
        do {
            let data = try await mbooks.locations()
            let json = try JSON(data: data)
            
            guard let locationArray = json["locations"].array else {
                throw AppError.decodingFailed
            }
            
            return locationArray.compactMap { LocationModel(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
    
    /// Fetch location for specific venue
    func fetchLocationForVenue(venuesId: String) async throws -> LocationModel {
        do {
            let data = try await mbooks.locationsVenue(venuesId: venuesId)
            let json = try JSON(data: data)
            
            guard let locJson = json["location"].dictionaryValue,
                  let location = LocationModel(json: JSON(locJson)) else {
                throw AppError.decodingFailed
            }
            
            return location
        } catch {
            throw handleError(error)
        }
    }
}

struct LocationModel: NSObject, MKAnnotation {
    let locationId: Int
    let title: String?
    let address: String
    let formattedAddress: String
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
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.thumbnail = json["thumbnail"].string ?? "No picture"
        
        super.init()
    }
    
    @objc dynamic var subtitle: String? { address }
    
    func pinColor() -> MKPinAnnotationColor { .red }
    
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

## 6. MoviesData Manager

**File:** `SwiftCinemas/SwiftLoginScreen/Managers/MoviesDataManager.swift`

```swift
import Foundation
import SwiftyJSON
import UIKit

final class MoviesDataManager: SharedDataManager {
    static let shared = MoviesDataManager()
    static var domain: String { "Movies" }
    
    private let mbooks: MbooksService
    private let images: ImageResourceService
    
    private init() {
        guard let app = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not found")
        }
        self.mbooks = app.services.mbooks
        self.images = app.services.images
    }
    
    /// Fetch paginated movies
    func fetchPaging(query: [String: String]) async throws -> [MovieDataModel] {
        do {
            let data = try await mbooks.moviesPaging(query: query)
            let json = try JSON(data: data)
            
            guard let movieArray = json["movies"].array else {
                throw AppError.decodingFailed
            }
            
            return movieArray.compactMap { MovieDataModel(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
    
    /// Search movies by term
    func search(query: [String: String]) async throws -> [MovieDataModel] {
        do {
            let data = try await mbooks.moviesSearch(query: query)
            let json = try JSON(data: data)
            
            guard let movieArray = json["movies"].array else {
                throw AppError.decodingFailed
            }
            
            return movieArray.compactMap { MovieDataModel(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
    
    /// Fetch trending movies
    func fetchTrending(limit: Int = 5, days: Int? = nil) async throws -> [MovieDataModel] {
        do {
            let data = try await mbooks.trendingMovies(limit: limit, days: days)
            let json = try JSON(data: data)
            
            guard let movieArray = json["movies"].array else {
                throw AppError.decodingFailed
            }
            
            return movieArray.compactMap { MovieDataModel(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
    
    /// Preload images for movies (async, doesn't block UI)
    func preloadImages(for movies: [MovieDataModel]) {
        Task {
            for movie in movies {
                let fullURL = URLManager.image(movie.largePicture)
                _ = try? await images.getData(urlString: fullURL, realmCache: true)
            }
        }
    }
}

struct MovieDataModel {
    let movieId: Int
    let movieIdString: String
    let name: String
    let detail: String
    let largePicture: String
    let imdbUrl: String
    
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
        self.largePicture = picture
        self.imdbUrl = imdb
    }
}
```

---

## 7. AuthData Manager (Login)

**File:** `SwiftCinemas/SwiftLoginScreen/Managers/AuthDataManager.swift`

```swift
import Foundation
import UIKit

final class AuthDataManager: SharedDataManager {
    static let shared = AuthDataManager()
    static var domain: String { "Auth" }
    
    private let loginGateway: LoginGatewayService
    
    private init() {
        guard let app = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not found")
        }
        self.loginGateway = app.services.loginGateway
    }
    
    /// Sign in with username and password
    /// - Note: Throws AppError on failure; stores session automatically
    func signIn(
        username: String,
        passwordHash: String,
        deviceId: String,
        systemVersion: String
    ) async throws {
        do {
            try await loginGateway.signIn(
                username: username,
                passwordHash: passwordHash,
                deviceId: deviceId,
                systemVersion: systemVersion
            )
        } catch {
            throw handleError(error)
        }
    }
    
    /// Fetch current user profile
    func fetchUser() async throws -> [String: Any] {
        do {
            let data = try await loginGateway.getUser()
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            return json
        } catch {
            throw handleError(error)
        }
    }
    
    /// Activate device with voucher
    func activate(deviceId: String, user: String) async throws {
        do {
            let data = try await loginGateway.postActivation(deviceId: deviceId, user: user)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            if let success = json["success"] as? NSNumber, success.intValue == 1 {
                NSLog("[%@] Activation successful", Self.domain)
            } else {
                throw AppError.decodingFailed
            }
        } catch {
            throw handleError(error)
        }
    }
}
```

---

## 8. CheckoutData Manager (Payments & Purchases)

**File:** `SwiftCinemas/SwiftLoginScreen/Managers/CheckoutDataManager.swift`

```swift
import Foundation
import SwiftyJSON

final class CheckoutDataManager: SharedDataManager {
    static let shared = CheckoutDataManager()
    static var domain: String { "Checkout" }
    
    private let loginGateway: LoginGatewayService
    private let mbooks: MbooksService
    
    private init() {
        guard let app = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not found")
        }
        self.loginGateway = app.services.loginGateway
        self.mbooks = app.services.mbooks
    }
    
    /// Get Braintree client token for payment form
    func fetchClientToken() async throws -> ClientTokenModel {
        do {
            let data = try await loginGateway.getCheckOut()
            let json = try JSON(data: data)
            
            guard let clientToken = json["clientToken"].string,
                  let apiKey = json["APIKEY"].string else {
                throw AppError.decodingFailed
            }
            
            return ClientTokenModel(clientToken: clientToken, apiKey: apiKey)
        } catch {
            throw handleError(error)
        }
    }
    
    /// Submit payment and complete checkout
    /// - Parameters:
    ///   - paymentMethodNonce: Braintree nonce from tokenization
    ///   - orderId: Booking reference
    ///   - seatsToBeReserved: Concatenated seat numbers (e.g., "A1-B2-")
    /// - Returns: Purchase confirmation with tickets and updated seat map
    func checkout(
        paymentMethodNonce: String,
        orderId: String,
        seatsToBeReserved: String
    ) async throws -> CheckoutResponseModel {
        do {
            let postBody = "payment_method_nonce=\(paymentMethodNonce)&orderId=\(orderId)&seatsToBeReserved=\(seatsToBeReserved)"
            let bodyData = postBody.data(using: .utf8)!
            
            let responseData = try await loginGateway.postCheckOut(body: bodyData)
            let json = try JSON(data: responseData)
            
            guard let status = json["status"].string else {
                throw AppError.decodingFailed
            }
            
            if status == "success" {
                return CheckoutResponseModel(
                    status: status,
                    transactionId: json["transactionId"].string ?? "",
                    tickets: json["tickets"].arrayValue,
                    seatMap: json["seatMap"].dictionaryValue
                )
            } else {
                let errorMsg = json["message"].string ?? "Payment failed"
                throw AppError.httpError(statusCode: 400, message: errorMsg)
            }
        } catch {
            throw handleError(error)
        }
    }
    
    /// Fetch all user purchases
    func fetchAllPurchases() async throws -> [PurchaseModel] {
        do {
            let data = try await loginGateway.getAllPurchases()
            let json = try JSON(data: data)
            
            guard let purchaseArray = json["purchases"].array else {
                throw AppError.decodingFailed
            }
            
            return purchaseArray.compactMap { PurchaseModel(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
    
    /// Get details for specific purchase
    func fetchPurchase(purchaseId: String) async throws -> PurchaseModel {
        do {
            let data = try await loginGateway.getManagePurchases(purchaseId: purchaseId)
            let json = try JSON(data: data)
            
            guard let purchase = PurchaseModel(json: json["purchase"]) else {
                throw AppError.decodingFailed
            }
            
            return purchase
        } catch {
            throw handleError(error)
        }
    }
}

struct ClientTokenModel {
    let clientToken: String
    let apiKey: String
}

struct CheckoutResponseModel {
    let status: String
    let transactionId: String
    let tickets: [JSON]
    let seatMap: [String: Any]
}

struct PurchaseModel {
    let purchaseId: String
    let bookingRef: String
    let date: String
    let venue: String
    let tickets: [String]
    
    init?(json: JSON) {
        guard let id = json["purchaseId"].string,
              let ref = json["bookingRef"].string,
              let date = json["date"].string,
              let venue = json["venue"].string else {
            return nil
        }
        
        self.purchaseId = id
        self.bookingRef = ref
        self.date = date
        self.venue = venue
        self.tickets = json["tickets"].arrayValue.compactMap { $0.string }
    }
}
```

---

## 9. BasketData Manager (Shopping Cart & Payments)

**File:** `SwiftCinemas/SwiftLoginScreen/Managers/BasketDataManager.swift`

```swift
import Foundation
import SwiftyJSON
import UIKit

/// Manages shopping basket, payments, and purchases
final class BasketDataManager: SharedDataManager {
    static let shared = BasketDataManager()
    static var domain: String { "Basket" }
    
    private let loginGateway: LoginGatewayService
    
    private init() {
        guard let app = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not found")
        }
        self.loginGateway = app.services.loginGateway
    }
    
    /// Get Braintree client token for payment form
    func getClientToken() async throws -> ClientTokenModel {
        do {
            let data = try await loginGateway.getCheckOut()
            let json = try JSON(data: data)
            
            guard let clientToken = json["clientToken"].string,
                  let apiKey = json["APIKEY"].string else {
                throw AppError.decodingFailed
            }
            
            return ClientTokenModel(clientToken: clientToken, apiKey: apiKey)
        } catch {
            throw handleError(error)
        }
    }
    
    /// Submit payment and create purchase
    func submitPayment(nonce: String, orderId: String, seatsToBeReserved: String) async throws -> PurchaseModel {
        do {
            let postBody = "payment_method_nonce=\(nonce)&orderId=\(orderId)&seatsToBeReserved=\(seatsToBeReserved)"
            guard let bodyData = postBody.data(using: .utf8) else {
                throw AppError.networkFailure(underlying: NSError(domain: "Basket", code: -1))
            }
            
            let responseData = try await loginGateway.postCheckOut(body: bodyData)
            let json = try JSON(data: responseData)
            
            guard let status = json["status"].string else {
                throw AppError.decodingFailed
            }
            
            if status != "success" {
                let message = json["message"].string ?? "Payment failed"
                throw AppError.httpError(statusCode: 400, message: message)
            }
            
            guard let purchase = PurchaseModel(json: json) else {
                throw AppError.decodingFailed
            }
            
            return purchase
        } catch {
            throw handleError(error)
        }
    }
    
    /// Get current basket/purchases for user
    func getBasket() async throws -> [PurchaseModel] {
        do {
            let data = try await loginGateway.getCheckOut()
            let json = try JSON(data: data)
            
            guard let purchases = json["purchases"].array else {
                return []
            }
            
            return purchases.compactMap { PurchaseModel(json: $0) }
        } catch {
            throw handleError(error)
        }
    }
}

// MARK: - Basket Models

struct ClientTokenModel {
    let clientToken: String
    let apiKey: String
}

struct PurchaseModel {
    let purchaseId: String
    let bookingRef: String
    let date: String
    let venue: String
    let tickets: [String]
    
    init?(json: JSON) {
        guard let id = json["purchaseId"].string,
              let ref = json["bookingRef"].string,
              let date = json["date"].string,
              let venue = json["venue"].string else {
            return nil
        }
        
        self.purchaseId = id
        self.bookingRef = ref
        self.date = date
        self.venue = venue
        self.tickets = json["tickets"].arrayValue.compactMap { $0.string }
    }
}
```

---

## Migration Checklist

- [ ] Create `SharedDataManager.swift` (base protocol)
- [ ] Create `SeatsDataManager.swift`
- [ ] Create `DatesDataManager.swift`
- [ ] Create `VenuesDataManager.swift`
- [ ] Create `LocationsDataManager.swift`
- [ ] Create `MoviesDataManager.swift`
- [ ] Create `AuthDataManager.swift`
- [ ] Create `CheckoutDataManager.swift`
- [ ] Create `BasketDataManager.swift` (shopping cart & payments)
- [ ] Update 20+ ViewControllers to use managers
- [ ] Remove old static methods from original data files
- [ ] Optional (deferred): Run unit tests (70%+ coverage)
- [ ] Optional (deferred): Run integration tests (auth + payment flows)
- [ ] Optional (deferred): Run UI tests (Appium - 85+ tests)
- [ ] Verify no regressions via manual flow checks (automated tests deferred unless requested)

