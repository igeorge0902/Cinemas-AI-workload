# ViewController Migration Examples & Testing Guide

## Overview

This document shows concrete examples of how to migrate ViewControllers from direct endpoint invocations (`app.services.<service>.<endpoint>`) to shared data managers, while keeping the existing `AppDelegate` protocol-based injection layout.

**Deferred policy:** Test implementation/execution examples in this document are optional and non-blocking until further notice.

---

## Example 1: MoviesVC Migration

### Before (Current)
```swift
// SwiftCinemas/SwiftLoginScreen/MoviesVC.swift (BEFORE)

class MoviesVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var movies: [NSDictionary] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadMovies()
    }
    
    func loadMovies() {
        Task { @MainActor in
            guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
            do {
                let data = try await app.services.mbooks.moviesPaging(
                    query: ["setFirstResult": String(0)]
                )
                let json = try JSON(data: data)
                
                // Manual JSON parsing
                if let list = json["movies"].object as? NSArray {
                    for i in 0 ..< list.count {
                        if let movie = list[i] as? NSDictionary {
                            self.movies.append(movie)
                        }
                    }
                }
                
                tableView?.reloadData()
            } catch {
                NSLog("loadMovies error: %@", error.localizedDescription)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let movie = movies[indexPath.row]
        cell.textLabel?.text = movie["name"] as? String
        return cell
    }
}
```

### After (Refactored)
```swift
// SwiftCinemas/SwiftLoginScreen/MoviesVC.swift (AFTER)

class MoviesVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var movies: [MovieDataModel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadMovies()
    }
    
    func loadMovies() {
        Task { @MainActor in
            do {
                // Clean, type-safe API
                self.movies = try await MoviesDataManager.shared.fetchPaging(
                    query: ["setFirstResult": "0"]
                )
                
                // Preload images async (doesn't block UI updates)
                MoviesDataManager.shared.preloadImages(for: self.movies)
                
                tableView?.reloadData()
            } catch {
                // Error already logged in MoviesDataManager
                self.showErrorAlert(title: "Loading Error", message: "\(error)")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let movie = movies[indexPath.row]
        cell.textLabel?.text = movie.name
        return cell
    }
    
    private func showErrorAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

**Key Changes:**
- ✅ Removed direct endpoint invocation from VC logic
- ✅ Replaced raw `NSDictionary` with typed `MovieDataModel`
- ✅ Removed manual JSON parsing
- ✅ API is now self-documenting: `fetchPaging(query:)`
- ✅ Preloading images as async background task
- ✅ Better error handling

---

## Example 2: VenuesVC Migration

### Before
```swift
// VenuesVC.swift (BEFORE)

func addData() {
    let myString = String(movieId)
    
    Task { @MainActor [weak self] in
        guard let self else { return }
        do {
            let data = try await self.appServices.mbooks.venue(movieId: myString)
            let json = try JSON(data: data)
            
            if let list = json["venues"].object as? NSArray {
                for i in 0 ..< list.count {
                    if let dataBlock = list[i] as? NSDictionary {
                        self.TableData.append(datastruct(add: dataBlock))
                    }
                }
            }
            self.tableView?.reloadData()
        } catch {
            NSLog("VenuesVC.addData: %@", error.localizedDescription)
        }
    }
}

func addLocation() {
    PlacesData_.removeAll()
    
    Task { @MainActor [weak self] in
        guard let self else { return }
        do {
            let data = try await self.appServices.mbooks.locations()
            let json = try JSON(data: data)
            
            if let list = json["locations"].object as? NSArray {
                for i in 0 ..< list.count {
                    if let dataBlock = list[i] as? NSDictionary {
                        if let location = PlacesData.fromJSON(dataBlock) {
                            PlacesData_.append(location)
                        }
                    }
                }
            }
            self.tableView?.reloadData()
        } catch {
            NSLog("VenuesVC.addLocation: %@", error.localizedDescription)
        }
    }
}
```

### After
```swift
// VenuesVC.swift (AFTER)

func addData() {
    Task { @MainActor in
        do {
            let venues = try await VenuesDataManager.shared.fetchVenuesForMovie(
                movieId: String(movieId)
            )
            self.venues = venues
            tableView?.reloadData()
        } catch {
            self.showErrorAlert(error: error)
        }
    }
}

func addLocation() {
    Task { @MainActor in
        do {
            self.locations = try await LocationsDataManager.shared.fetchLocations()
            tableView?.reloadData()
        } catch {
            self.showErrorAlert(error: error)
        }
    }
}
```

**Key Changes:**
- ✅ Replaced multiple `if let` pyramid with direct type-safe calls
- ✅ Removed global array mutations (`PlacesData_.removeAll()`)
- ✅ Direct assignment to instance variables
- ✅ Simpler error handling

---

## Example 3: Checkout/Payment Flow Migration

### Before
```swift
// CheckoutVC.swift (BEFORE)

func getClientToken() {
    Task { @MainActor in
        guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
        do {
            let data = try await app.services.loginGateway.getCheckOut()
            let json = try JSON(data: data)
            
            if let clientToken = json["clientToken"].string,
               let apiKey = json["APIKEY"].string {
                self.braintreeClientToken = clientToken
                self.apiKey = apiKey
                self.setupBraintree()
            }
        } catch {
            NSLog("getClientToken error: %@", error.localizedDescription)
        }
    }
}

func submitPayment(nonce: String) {
    Task { @MainActor in
        guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
        
        let orderId = self.orderId
        let seats = self.selectedSeats.joined(separator: "-") + "-"
        let postBody = "payment_method_nonce=\(nonce)&orderId=\(orderId)&seatsToBeReserved=\(seats)"
        let bodyData = postBody.data(using: .utf8)!
        
        do {
            let responseData = try await app.services.loginGateway.postCheckOut(body: bodyData)
            let json = try JSON(data: responseData)
            
            if let status = json["status"].string, status == "success" {
                self.transactionId = json["transactionId"].string
                self.showSuccess()
            } else {
                self.showError(message: json["message"].string ?? "Payment failed")
            }
        } catch {
            NSLog("submitPayment error: %@", error.localizedDescription)
        }
    }
}
```

### After
```swift
// CheckoutVC.swift (AFTER)

func getClientToken() {
    Task { @MainActor in
        do {
            let tokenModel = try await CheckoutDataManager.shared.fetchClientToken()
            self.braintreeClientToken = tokenModel.clientToken
            self.apiKey = tokenModel.apiKey
            self.setupBraintree()
        } catch {
            self.showErrorAlert(error: error)
        }
    }
}

func submitPayment(nonce: String) {
    Task { @MainActor in
        do {
            let seats = self.selectedSeats.joined(separator: "-") + "-"
            
            let response = try await CheckoutDataManager.shared.checkout(
                paymentMethodNonce: nonce,
                orderId: self.orderId,
                seatsToBeReserved: seats
            )
            
            self.transactionId = response.transactionId
            self.showSuccess()
        } catch {
            self.showErrorAlert(error: error)
        }
    }
}
```

**Key Changes:**
- ✅ No manual string concatenation for POST body
- ✅ Structured return type (`ClientTokenModel`, `CheckoutResponseModel`)
- ✅ Manager handles encoding and error interpretation
- ✅ VC focuses on UI updates, not protocol details

---

## Example 4: Seats Selection Migration

### Before
```swift
// SeatsVC.swift (BEFORE)

func loadSeats() {
    SeatsData_.removeAll()
    numberOfRows.removeAll()
    
    Task { @MainActor in
        guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
        do {
            let data = try await app.services.mbooks.seats(
                screeningDateId: String(screeningDateId)
            )
            let json = try JSON(data: data)
            
            if let list = json["seatsforscreen"].object as? NSArray {
                for i in 0 ..< list.count {
                    if let dataBlock = list[i] as? NSDictionary {
                        let seat = SeatsData(add: dataBlock)
                        SeatsData_.append(seat)
                        
                        if !numberOfRows.contains(seat.seatRow) {
                            numberOfRows.append(seat.seatRow)
                        }
                    }
                }
            }
            
            tableView_?.reloadData()
        } catch {
            NSLog("SeatsData.addData: %@", error.localizedDescription)
        }
    }
}
```

### After
```swift
// SeatsVC.swift (AFTER)

func loadSeats() {
    Task { @MainActor in
        do {
            self.seats = try await SeatsDataManager.shared.fetchSeats(
                screeningDateId: self.screeningDateId
            )
            self.rows = SeatsDataManager.shared.getRows(self.seats)
            tableView?.reloadData()
        } catch {
            self.showErrorAlert(error: error)
        }
    }
}

// Render seats grouped by row
func setupSeatGrid() {
    let grouped = SeatsDataManager.shared.groupByRow(seats)
    // Use grouped[row] to build UI...
}
```

**Key Changes:**
- ✅ No global array mutations
- ✅ Returned data is strongly typed
- ✅ Helper methods (groupByRow, getRows) available on manager
- ✅ Cleaner separation: data fetching vs. UI rendering

---

## Testing Guide

### Unit Testing Data Managers

Create file: `SwiftCinemasTests/MoviesDataManagerTests.swift`

```swift
import XCTest
@testable import SwiftCinemas

@MainActor
class MoviesDataManagerTests: XCTestCase {
    
    var sut: MoviesDataManager!
    var mockMbooksService: MockMbooksService!
    
    override func setUp() {
        super.setUp()
        // Create mock service
        mockMbooksService = MockMbooksService()
        
        // Inject mock into manager (requires optional init)
        // OR mock AppDelegate.services before accessing .shared
        sut = MoviesDataManager.shared
    }
    
    override func tearDown() {
        sut = nil
        mockMbooksService = nil
        super.tearDown()
    }
    
    // MARK: - Fetch Paging Tests
    
    func testFetchPagingSuccess() async throws {
        // Arrange
        let mockResponse = """
        {
            "movies": [
                {
                    "movieId": "1",
                    "name": "Test Movie",
                    "detail": "A test movie",
                    "large_picture": "/images/test.jpg",
                    "iMDB_url": "https://imdb.com/123"
                }
            ]
        }
        """.data(using: .utf8)!
        
        mockMbooksService.moviesPagingResult = mockResponse
        
        // Act
        let movies = try await sut.fetchPaging(query: ["setFirstResult": "0"])
        
        // Assert
        XCTAssertEqual(movies.count, 1)
        XCTAssertEqual(movies[0].name, "Test Movie")
        XCTAssertEqual(movies[0].movieId, 1)
    }
    
    func testFetchPagingDecodingFailure() async {
        // Arrange
        let invalidResponse = "{ invalid json }".data(using: .utf8)!
        mockMbooksService.moviesPagingResult = invalidResponse
        
        // Act & Assert
        do {
            _ = try await sut.fetchPaging(query: [:])
            XCTFail("Should throw AppError.decodingFailed")
        } catch let error as AppError {
            XCTAssertTrue(error == .decodingFailed)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testFetchPagingNetworkError() async {
        // Arrange
        mockMbooksService.shouldFail = true
        mockMbooksService.errorToThrow = AppError.networkFailure(
            underlying: URLError(.notConnectedToInternet)
        )
        
        // Act & Assert
        do {
            _ = try await sut.fetchPaging(query: [:])
            XCTFail("Should throw network error")
        } catch {
            // Expected
        }
    }
    
    // MARK: - Search Tests
    
    func testSearchSuccess() async throws {
        let mockResponse = """
        {
            "movies": [
                {
                    "movieId": "42",
                    "name": "Avatar",
                    "detail": "Sci-fi epic",
                    "large_picture": "/avatar.jpg",
                    "iMDB_url": "https://imdb.com/456"
                }
            ]
        }
        """.data(using: .utf8)!
        
        mockMbooksService.moviesSearchResult = mockResponse
        
        let movies = try await sut.search(query: ["term": "avatar"])
        
        XCTAssertEqual(movies.count, 1)
        XCTAssertEqual(movies[0].name, "Avatar")
    }
}

// MARK: - Mock Services

class MockMbooksService: MbooksService {
    var moviesPagingResult: Data?
    var moviesSearchResult: Data?
    var trendingMoviesResult: Data?
    var shouldFail = false
    var errorToThrow: Error?
    
    override func moviesPaging(query: [String: String]) async throws -> Data {
        if shouldFail {
            throw errorToThrow ?? AppError.networkFailure(
                underlying: URLError(.unknown)
            )
        }
        return moviesPagingResult ?? Data()
    }
    
    override func moviesSearch(query: [String: String]) async throws -> Data {
        if shouldFail {
            throw errorToThrow ?? AppError.networkFailure(
                underlying: URLError(.unknown)
            )
        }
        return moviesSearchResult ?? Data()
    }
    
    override func trendingMovies(limit: Int = 5, days: Int? = nil) async throws -> Data {
        if shouldFail {
            throw errorToThrow ?? AppError.networkFailure(
                underlying: URLError(.unknown)
            )
        }
        return trendingMoviesResult ?? Data()
    }
}
```

### Integration Tests

Create file: `SwiftCinemasTests/MoviesDataManagerIntegrationTests.swift`

```swift
import XCTest
@testable import SwiftCinemas

@MainActor
class MoviesDataManagerIntegrationTests: XCTestCase {
    
    var sut: MoviesDataManager!
    
    override func setUp() {
        super.setUp()
        // Uses real AppDelegate and AppServices (connect to staging backend)
        sut = MoviesDataManager.shared
    }
    
    func testFetchPagingIntegration() async throws {
        // This runs against the actual backend (or staging)
        let movies = try await sut.fetchPaging(
            query: ["setFirstResult": "0", "limit": "10"]
        )
        
        XCTAssertGreaterThan(movies.count, 0)
        XCTAssertNotNil(movies[0].name)
        XCTAssertNotNil(movies[0].largePicture)
    }
    
    func testFetchTrendingIntegration() async throws {
        let trending = try await sut.fetchTrending(limit: 5)
        
        XCTAssertLessThanOrEqual(trending.count, 5)
        XCTAssertGreaterThan(trending.count, 0)
    }
}
```

### ViewController UI Tests

Create file: `SwiftCinemasTests/MoviesVCTests.swift`

```swift
import XCTest
@testable import SwiftCinemas

class MoviesVCTests: XCTestCase {
    
    var vc: MoviesVC!
    var mockMoviesManager: MockMoviesDataManager!
    
    override func setUp() {
        super.setUp()
        // Inject mock into ViewController
        let storyboard = UIStoryboard(name: "Storyboard", bundle: nil)
        vc = storyboard.instantiateViewController(withIdentifier: "MoviesVC") as? MoviesVC
        
        _ = vc.view // Force load view
    }
    
    func testMoviesLoadedOnViewDidLoad() async {
        // Arrange
        let expectedMovies = [
            MovieDataModel(
                movieId: 1,
                movieIdString: "1",
                name: "Test",
                detail: "Desc",
                largePicture: "/test.jpg",
                imdbUrl: "http://imdb.com"
            )
        ]
        
        // Act
        vc.movies = expectedMovies
        vc.tableView?.reloadData()
        
        // Assert
        XCTAssertEqual(vc.tableView?.numberOfRows(inSection: 0), 1)
    }
    
    func testMoviesCellDisplay() {
        // Arrange
        vc.movies = [
            MovieDataModel(
                movieId: 1,
                movieIdString: "1",
                name: "Avatar",
                detail: "Sci-fi",
                largePicture: "/avatar.jpg",
                imdbUrl: "http://imdb.com"
            )
        ]
        
        // Act
        let cell = vc.tableView(vc.tableView!, cellForRowAt: IndexPath(row: 0, section: 0))
        
        // Assert
        XCTAssertEqual(cell.textLabel?.text, "Avatar")
    }
}
```

---

## Rollout Strategy

### Phase 1: Staging
- Deploy data managers to staging branch
- Optional (deferred): run unit + integration tests
- Manual smoke tests on iOS device (staging backend)
- Optional (deferred): Appium E2E tests (no changes needed)

### Phase 2: Canary
- Deploy to 5% of users via Firebase Remote Config
- Monitor crash logs + analytics
- Verify backward compatibility

### Phase 3: Full Rollout
- Deploy to 100% via staged rollout
- Monitor for 24h
- Revert if critical issues

### Rollback Plan
If issues arise, revert changed ViewController files (keep data managers if stable).

---

## Verification Checklist

After each ViewController migration:
- [ ] All builds without errors
- [ ] Optional (deferred): Unit tests pass (mock services)
- [ ] Optional (deferred): Integration tests pass (real backend)
- [ ] Optional (deferred): Appium E2E tests pass
- [ ] Memory profiler shows no leaks
- [ ] No new console warnings/errors
- [ ] Type-safe API used (no raw JSON parsing)
- [ ] Error handling tested

