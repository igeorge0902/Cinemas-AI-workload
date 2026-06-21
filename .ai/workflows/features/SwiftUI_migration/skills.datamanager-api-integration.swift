/**
 * Skill: API Response → DataManager Integration Pattern
 *
 * This skill guides developers on how to wire API responses from AppServices
 * into observable DataManager properties using Combine's @Published.
 *
 * Context:
 * - Cinemas iOS app uses Combine + ObservableObject for reactive state
 * - AppServices provides typed async APIs (mbooks, images, loginGateway, etc.)
 * - Responses are currently parsed and appended to bare global arrays
 * - DataManagers replace those globals with @Published properties
 *
 * Skill level: Intermediate (requires familiarity with async/await, Combine)
 */

import Foundation
import Combine
import SwiftyJSON
import UIKit

// ───────────────────────────────────────────────────
// 1. Basic Pattern: VC → AppServices → JSON Parse → DataManager
// ───────────────────────────────────────────────────

/**
 Refactoring example: VenuesVC.addLocation()

 BEFORE (writes to bare global):
 ```swift
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
                             PlacesData_.append(location)     // ← bare global
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

 AFTER (writes to DataManager):
 ```swift
 func addLocation() {
     Task { @MainActor [weak self] in
         guard let self else { return }
         do {
             let data = try await self.appServices.mbooks.locations()
             let json = try JSON(data: data)
             if let list = json["locations"].object as? NSArray {
                 var locations: [PlacesData] = []
                 for i in 0 ..< list.count {
                     if let dataBlock = list[i] as? NSDictionary {
                         if let location = PlacesData.fromJSON(dataBlock) {
                             locations.append(location)
                         }
                     }
                 }
                 // Write to manager's @Published property (triggers observers)
                 self.appServices.venues.venues = locations
             }
             self.tableView?.reloadData()
         } catch {
             NSLog("VenuesVC.addLocation: %@", error.localizedDescription)
         }
     }
 }
 ```
 */

// ───────────────────────────────────────────────────
// 2. Static Fetch Functions: Model Class Methods
// ───────────────────────────────────────────────────

/**
 Refactoring example: SeatsData.addData(_:)

 Data models often have `class func` methods that fetch and populate globals.
 These must be updated to use the manager.

 Access pattern in static context:
 - UIApplication.shared.delegate to get AppDelegate
 - AppDelegate.services to get AppServices
 - AppServices.<manager>.<property> to write data

 BEFORE (static function writes to SeatsData_ global):
 ```swift
 class SeatsData: NSObject {
     var seatId: Int!
     var seatNumber: String!
     // ... other properties

     class func addData(_ screeningDateId: Int) {
         let myString = String(screeningDateId)
         SeatsData_.removeAll()  // ← bare global

         Task { @MainActor in
             guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
             do {
                 let data = try await app.services.mbooks.seats(screeningDateId: myString)
                 let json = try JSON(data: data)
                 if let list = json["seatsforscreen"].object as? NSArray {
                     for i in 0 ..< list.count {
                         if let dataBlock = list[i] as? NSDictionary {
                             SeatsData_.append(SeatsData(add: dataBlock))  // ← bare global
                         }
                     }
                 }
             } catch {
                 NSLog("SeatsData.addData: %@", error.localizedDescription)
             }
         }
     }
 }
 ```

 AFTER (static function writes to DataManager):
 ```swift
 class SeatsData: NSObject {
     var seatId: Int!
     var seatNumber: String!
     // ... other properties

     class func addData(_ screeningDateId: Int) {
         let myString = String(screeningDateId)

         Task { @MainActor in
             guard let app = UIApplication.shared.delegate as? AppDelegate else { return }

             // Reset via manager (not bare global)
             app.services.basket.seats = []

             do {
                 let data = try await app.services.mbooks.seats(screeningDateId: myString)
                 let json = try JSON(data: data)
                 if let list = json["seatsforscreen"].object as? NSArray {
                     var seats: [SeatsData] = []
                     for i in 0 ..< list.count {
                         if let dataBlock = list[i] as? NSDictionary {
                             seats.append(SeatsData(add: dataBlock))
                         }
                     }
                     // Write entire array to @Published property
                     app.services.basket.seats = seats
                 }
             } catch {
                 NSLog("SeatsData.addData: %@", error.localizedDescription)
             }
         }
     }
 }
 ```
 */

// ───────────────────────────────────────────────────
// 3. DataManager with Optional Convenience Fetch Method
// ───────────────────────────────────────────────────

/**
 Advanced pattern: Move API logic into DataManager to reduce VC boilerplate.

 This is optional for Phase 1, but recommended for Phase 2+.

 Benefits:
 - API call logic is centralized in one place (DataManager)
 - VCs have less error handling boilerplate
 - Easier to add caching, retry logic, or other cross-cutting concerns
 - Testability improves (mock the DataManager method)

 Example:
 ```swift
 final class VenuesDataManager: ObservableObject {
     @Published var venues: [PlacesData] = []
     @Published var filteredVenues: [PlacesData] = []

     func fetchVenues(from service: MbooksService) {
         Task { @MainActor in
             do {
                 let data = try await service.locations()
                 let json = try JSON(data: data)
                 if let list = json["locations"].object as? NSArray {
                     var locations: [PlacesData] = []
                     for item in list {
                         if let location = PlacesData.fromJSON(item as! NSDictionary) {
                             locations.append(location)
                         }
                     }
                     // Publish to @Published property
                     self.venues = locations
                 }
             } catch {
                 NSLog("VenuesDataManager.fetchVenues: %@", error.localizedDescription)
             }
         }
     }

     func reset() {
         venues.removeAll()
         filteredVenues.removeAll()
     }
 }

 // In VC:
 func addLocation() {
     appServices.venues.fetchVenues(from: appServices.mbooks)
 }
 ```
 */

// ───────────────────────────────────────────────────
// 4. Observing DataManager Changes in UIKit VCs
// ───────────────────────────────────────────────────

/**
 Once data is in a DataManager @Published property, VCs can observe it.

 UIKit pattern using Combine:

 ```swift
 class MyViewController: UIViewController, HasAppServices {
     var appServices: AppServices!
     var cancellables = Set<AnyCancellable>()

     override func viewDidLoad() {
         super.viewDidLoad()

         // Subscribe to DataManager changes
         appServices.venues.$venues
             .receive(on: DispatchQueue.main)
             .sink { [weak self] venues in
                 print("Venues changed, reloading table...")
                 self?.tableView?.reloadData()
             }
             .store(in: &cancellables)
     }

     deinit {
         cancellables.removeAll()
     }
 }
 ```
 */

// ───────────────────────────────────────────────────
// 5. Observing DataManager in SwiftUI Views
// ───────────────────────────────────────────────────

/**
 SwiftUI pattern using @ObservedObject or @EnvironmentObject:

 ```swift
 struct VenuesView: View {
     @ObservedObject var venuesManager: VenuesDataManager

     var body: some View {
         List(venuesManager.venues, id: \.locationId) { venue in
             Text(venue.title ?? "Unknown")
         }
         .onAppear {
             // Trigger fetch when view appears
             // (assuming DataManager has a convenience method)
         }
     }
 }

 // Or, if injected as EnvironmentObject:
 struct VenuesDetailView: View {
     @EnvironmentObject var venuesManager: VenuesDataManager

     var body: some View {
         List(venuesManager.venues) { venue in
             Text(venue.title ?? "")
         }
     }
 }
 ```
 */

// ───────────────────────────────────────────────────
// 6. Error Handling Best Practices
// ───────────────────────────────────────────────────

/**
 Key principles:

 1. **Log all errors** — use NSLog with context string
   ```swift
   catch {
       NSLog("VenuesDataManager.fetchVenues: %@", error.localizedDescription)
   }
   ```

 2. **Leave @Published property unchanged on error** — don't wipe data
    Example: If API fails, keep the existing venues list
   ```swift
   do {
       let data = try await service.locations()
       // ... parse and update self.venues
   } catch {
       NSLog("FetchVenues failed: %@", error.localizedDescription)
       // self.venues remains unchanged
   }
   ```

 3. **Optionally, add an @Published error state** (Phase 2+)
   ```swift
   @Published var error: Error?

   func fetchVenues(from service: MbooksService) {
       Task { @MainActor in
           do {
               // ... fetch and update venues
               self.error = nil  // clear error on success
           } catch {
               self.error = error  // publish error to UI
               NSLog("FetchVenues: %@", error.localizedDescription)
           }
       }
   }
   ```

 4. **Never silently fail** — always log
    - Network failures
    - JSON parsing failures
    - Model instantiation failures
    - Any caught exception
 */

// ───────────────────────────────────────────────────
// 7. Main Thread Safety
// ───────────────────────────────────────────────────

/**
 Rule: All writes to @Published properties MUST occur on the main thread.

 Current codebase uses Task { @MainActor in ... } which ensures this.

 DO:
 ```swift
 Task { @MainActor in
     // Safe to write to @Published here
     self.appServices.venues.venues = locations
 }
 ```

 DON'T:
 ```swift
 DispatchQueue.global().async {
     // WRONG! Not on main thread
     self.appServices.venues.venues = locations
 }
 ```

 If in doubt, always wrap with:
 ```swift
 DispatchQueue.main.async {
     self.appServices.venues.venues = locations
 }
 ```
 */

// ───────────────────────────────────────────────────
// 8. Checklist: Refactoring a Single Global → DataManager
// ───────────────────────────────────────────────────

/**
 When refactoring a global variable (e.g., PlacesData_):

 □ 1. Identify all usages of the global:
      - grep -n "PlacesData_" *.swift

 □ 2. Categorize usage types:
      - Assignment: `PlacesData_ = [...]`
      - Append: `PlacesData_.append(...)`
      - Clear: `PlacesData_.removeAll()`
      - Read: `PlacesData_[0]`, `PlacesData_.count`

 □ 3. For each read/write site:
      - Bare globals → manager property access
      - `PlacesData_ =` → `appServices.venues.venues =`
      - `PlacesData_.append` → collect in temp array, then assign
      - `PlacesData_.removeAll()` → either reset property or call manager.reset()
      - `PlacesData_[i]` → `appServices.venues.venues[i]`
      - `PlacesData_.count` → `appServices.venues.venues.count`

 □ 4. Update static fetch functions (if any):
      - Find class methods like SeatsData.addData()
      - Replace bare global writes with manager writes

 □ 5. Update deinit blocks:
      - Old: `PlacesData_.removeAll()`
      - New: `appServices.venues.reset()` or `appServices.venues.venues = []`

 □ 6. Test the refactored code:
      - Run the flow that populates the data
      - Verify UI updates (table view reloads, etc.)
      - Check error logs for any uncaught exceptions

 □ 7. Once all usages are migrated, delete the bare global:
      - `var PlacesData_: [PlacesData] = .init()` ← DELETE

 □ 8. Ensure the codebase still compiles:
      - `xcodebuild build` or build in Xcode IDE
 */

// ───────────────────────────────────────────────────
// 9. Integration Points Summary
// ───────────────────────────────────────────────────

/**
 Four main integration points for API → DataManager flow:

 1. **AppServices property** (already exists)
    - Holds the four DataManagers (movies, venues, admin, basket)
    - Accessible via HasAppServices protocol in any VC
    - Lazy-initialized in AppDelegate

 2. **API call** (via AppServices service layer)
    - e.g., `appServices.mbooks.locations()`
    - Returns `Data` (bytes)
    - Already handles auth, caching, error recovery

 3. **Response parsing** (JSON via SwiftyJSON)
    - Parse `Data` into JSON
    - Extract array/objects
    - Instantiate model objects from JSON

 4. **DataManager write** (@Published property assignment)
    - Assign parsed models to manager property
    - Triggers Combine publishers
    - Notifies all observing VCs/SwiftUI views

 Flow diagram:

 VenuesVC.addLocation()
     ↓
 self.appServices.mbooks.locations()  [API call]
     ↓
 try await <receives Data>  [Response]
     ↓
 JSON(data: data)  [Parse]
     ↓
 [PlacesData, PlacesData, ...]  [Models]
     ↓
 self.appServices.venues.venues = [...]  [Write to manager]
     ↓
 @Published publisher triggers
     ↓
 All @ObservedObject and .sink() subscribers update UI
 */

