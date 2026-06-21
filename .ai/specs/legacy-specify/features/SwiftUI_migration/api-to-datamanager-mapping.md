# API Endpoints → DataManager Mapping

Reference guide for which API endpoints populate which DataManager properties.

## Overview

| Service | Endpoint | Returns | Target DataManager | Target Property | Response Format |
|---------|----------|---------|------------------|-----------------|-----------------|
| mbooks | `locations()` | venues | VenuesDataManager | `venues` | `{ "locations": [...] }` |
| mbooks | `movies()` (paging) | movies | MoviesDataManager | `movies` | `{ "movies": [...] }` |
| mbooks | `seats(screeningDateId)` | seat list | BasketDataManager | `seats` | `{ "seatsforscreen": [...] }` |
| mbooks | `checkout()` | tickets | BasketDataManager | `tickets` | `{ "tickets": [...] }` |
| mbooks | `screens()` (admin) | screenings | AdminDataManager | `screenings` | `{ "screens": [...] }` |
| images | `getData(urlString)` | image data | **N/A** (direct use) | — | binary image |
| loginGateway | `login(credentials)` | user/token | **N/A** (store in UserDefaults) | — | `{ "user": "...", "token": "..." }` |

---

## Detailed API Flows

### 1. VenuesDataManager — `venues` Property

**Source API:**
```swift
appServices.mbooks.locations()
```

**Response format:**
```json
{
  "locations": [
    {
      "locationId": 1,
      "name": "Cinema One",
      "formatted_address": "123 Main St",
      "latitude": 47.6062,
      "longitude": -122.3321,
      "thumbnail": "pic_001.jpg"
    },
    ...
  ]
}
```

**Parsing & mapping:**
```swift
let data = try await self.appServices.mbooks.locations()
let json = try JSON(data: data)
if let list = json["locations"].object as? NSArray {
    var locations: [PlacesData] = []
    for item in list {
        if let location = PlacesData.fromJSON(item as! NSDictionary) {
            locations.append(location)
        }
    }
    self.appServices.venues.venues = locations
}
```

**Call sites (current):**
- VenuesVC.addLocation() [line 202]
- MapViewController.addData() [line 150+]
- VenuesMigration.fetchLocations() [line 192+]

**Call sites (after migration):**
- VenuesVC.addLocation() → `self.appServices.venues.venues`
- MapViewController.addData() → `self.appServices.venues.venues`
- VenuesMigration.fetchLocations() → `@EnvironmentObject var venuesManager`

---

### 2. VenuesDataManager — `filteredVenues` Property

**Source API:** (same as `venues`, but filtered)

**Filtering logic:**
- Populated in map mode when `mapViewPage == true`
- Filters venues based on screening selection
- Used for map annotations

**Parsing & mapping:**
```swift
// Same as venues above, but assign to filteredVenues
self.appServices.venues.filteredVenues = locations
```

**Call sites (current):**
- VenuesVC.addLocation() [line 215] — conditional append to PlacesData2_
- VenuesMigration.fetchLocations() [line 199] — assignment to PlacesData2_

**Call sites (after migration):**
- VenuesVC.addLocation() → conditional write to `filteredVenues`
- VenuesMigration → direct write to `filteredVenues`

---

### 3. BasketDataManager — `seats` Property

**Source API:**
```swift
appServices.mbooks.seats(screeningDateId: String)
```

**Response format:**
```json
{
  "seatsforscreen": [
    {
      "seatId": 101,
      "seatNumber": "A1",
      "seatRow": "A",
      "isReserved": "false",
      "price": 1200,
      "tax": 240.0
    },
    ...
  ]
}
```

**Parsing & mapping:**
```swift
app.services.basket.seats = []  // reset
let data = try await app.services.mbooks.seats(screeningDateId: myString)
let json = try JSON(data: data)
if let list = json["seatsforscreen"].object as? NSArray {
    var seats: [SeatsData] = []
    for item in list {
        if let dataBlock = item as? NSDictionary {
            seats.append(SeatsData(add: dataBlock))
        }
    }
    app.services.basket.seats = seats
}
```

**Call sites (current):**
- SeatsData.addData(_:) [line 31, static method]
- BasketVC (indirectly via SeatsData.addData call)

**Call sites (after migration):**
- SeatsData.addData(_:) writes to `app.services.basket.seats`

---

### 4. BasketDataManager — `items` Property

**Source API:** (implicit, built from UI selections)

**Storage:** Dictionary `[Int: BasketData]` where key = seatId

**Behavior:**
- Populated by user seat selection (not via API call initially)
- May be sent to backend in checkout request
- Tracks selected seats + ticket details

**Example assignment:**
```swift
// Adding a seat to basket
appServices.basket.items[seatId] = basketData

// Clearing basket
appServices.basket.items.removeAll()
```

**Call sites (current):**
- BasketVC — seat selection / checkout flow
- HomeVC — check basket count

**Call sites (after migration):**
- BasketVC → `appServices.basket.items[...]`
- HomeVC → `appServices.basket.items.count`

---

### 5. BasketDataManager — `tickets` Property

**Source API:**
```swift
appServices.mbooks.checkout(...)  // or similar endpoint
```

**Response format:**
```json
{
  "tickets": [
    {
      "movie_name": "Avatar",
      "seats_seatRow": "A",
      "seats_seatNumber": "1",
      "price": 1200,
      "tax": 240.0,
      "screen_screenId": "5",
      "ticketId": 999
    },
    ...
  ]
}
```

**Parsing & mapping:**
```swift
app.services.basket.tickets = []  // reset
let data = try await app.services.mbooks.checkout(...)
let json = try JSON(data: data)
if let list = json["tickets"].object as? NSArray {
    var tickets: [TicketsData] = []
    for item in list {
        if let dataBlock = item as? NSDictionary {
            tickets.append(TicketsData(add: dataBlock))
        }
    }
    app.services.basket.tickets = tickets
}
```

**Call sites (current):**
- BasketVC.postNonceToServer() [line 290+]
- Payment success / failure handling

**Call sites (after migration):**
- Same flows, write to `app.services.basket.tickets`

---

### 6. BasketDataManager — `ticketMap` Property

**Source:** User-populated from seat selection UI

**Storage:** Dictionary `[String: String]` mapping ticketId → seatNumber

**Behavior:**
- Built during seat selection
- Used for checkout request payload
- Tracks which ticket IDs map to which seat identifiers

**Example:**
```swift
appServices.basket.ticketMap["ticket_001"] = "A1"
appServices.basket.ticketMap["ticket_002"] = "A2"
```

**Call sites (current):**
- PopOver.swift — seat selection loop [line 137+]
- BasketVC — checkout payload assembly [line 303]

**Call sites (after migration):**
- PopOver / BasketVC → `appServices.basket.ticketMap[...]`

---

### 7. AdminDataManager — `screenings` Property

**Source API:**
```swift
appServices.mbooks.screens()  // or admin-specific endpoint
```

**Response format:**
```json
{
  "screens": [
    {
      "movie": "Avatar",
      "date": "2026-03-25 19:00",
      "venue": "Cinema One",
      "ScreeningId": "ABC123"
    },
    ...
  ]
}
```

**Parsing & mapping:**
```swift
app.services.admin.screenings = []  // reset
let data = try await app.services.mbooks.screens()
let json = try JSON(data: data)
if let list = json["screens"].object as? NSArray {
    var screenings: [ScreenData] = []
    for item in list {
        if let dataBlock = item as? NSDictionary {
            screenings.append(ScreenData(add: dataBlock))
        }
    }
    app.services.admin.screenings = screenings
}
```

**Call sites (current):**
- AdminVC — admin panel, screening list
- AdminUpdateVC — update screening view

**Call sites (after migration):**
- Same flows, write to `app.services.admin.screenings`

---

### 8. MoviesDataManager — `movies` Property

**Source API:**
```swift
appServices.mbooks.moviesPaging(query: ["setFirstResult": String(0)])
```

**Response format:**
```json
{
  "movies": [
    {
      "movieId": "1",
      "name": "Avatar",
      "large_picture": "avatar.jpg",
      "detail": "A sci-fi epic...",
      "iMDB_url": "https://imdb.com/..."
    },
    ...
  ]
}
```

**Parsing & mapping:**
```swift
app.services.movies.movies = []  // reset
let data = try await app.services.mbooks.moviesPaging(query: ["setFirstResult": String(0)])
let json = try JSON(data: data)
if let list = json["movies"].object as? NSArray {
    var movies: [MoviesData] = []
    for item in list {
        if let dataBlock = item as? NSDictionary {
            let movie = MoviesData(add: dataBlock)
            movies.append(movie)
            // Also trigger image caching
            Data.imageFromUrl(urlString: URLManager.image(movie.large_picture!))
        }
    }
    app.services.movies.movies = movies
}
```

**Call sites (current):**
- MoviesData.addData() [line 31, static method]
- MoviesVC.viewDidLoad() [calls MoviesData.addData()]

**Call sites (after migration):**
- MoviesData.addData() writes to `app.services.movies.movies`

---

### 9. MoviesDataManager — `adminScreenings` Property

**Source API:** (fetched via admin endpoint, possibly different from ScreenData_)

**Response format:** `{ "adminScreenings": [...] }` (exact format TBD, see AdminUpdateVC)

**Parsing & mapping:**
```swift
app.services.movies.adminScreenings = []  // reset
let data = try await app.services.mbooks.adminScreenings()  // or similar
// ... parse and assign
app.services.movies.adminScreenings = adminScreenings
```

**Call sites (current):**
- MoviesVC (admin view, screening list) [line 209, 231]
- AdminUpdateVC (updates)

**Call sites (after migration):**
- Same flows, write to `app.services.movies.adminScreenings`

---

## Summary Table: API → DataManager Write Locations

| API Endpoint | Current Write Target | New Write Target | VC Method(s) |
|---|---|---|---|
| `mbooks.locations()` | `PlacesData_` | `appServices.venues.venues` | VenuesVC.addLocation() |
| `mbooks.locations()` (filtered) | `PlacesData2_` | `appServices.venues.filteredVenues` | VenuesVC.addLocation() (conditional) |
| `mbooks.seats(screeningDateId)` | `SeatsData_` | `appServices.basket.seats` | SeatsData.addData(_:) |
| `mbooks.checkout()` | `TicketsData_` | `appServices.basket.tickets` | BasketVC.postNonceToServer() |
| `mbooks.screens()` | `ScreenData_` | `appServices.admin.screenings` | AdminVC, AdminUpdateVC |
| `mbooks.moviesPaging()` | `TableData_` | `appServices.movies.movies` | MoviesData.addData() |
| `mbooks.adminScreenings()` | `ScreenData_2` | `appServices.movies.adminScreenings` | MoviesVC (admin) |
| (User selection) | `BasketData_` | `appServices.basket.items` | BasketVC (manual) |
| (User selection) | `tickets` dict | `appServices.basket.ticketMap` | PopOver (manual) |

---

## Best Practices

1. **Always reset before fetching:**
   ```swift
   app.services.basket.seats = []  // clear old data
   // ... fetch new data
   app.services.basket.seats = newSeats  // publish
   ```

2. **Collect in temp array before publishing:**
   ```swift
   var items: [Item] = []
   for element in response {
       items.append(parse(element))
   }
   app.services.manager.property = items  // single write triggers subscribers once
   ```

3. **Always log errors:**
   ```swift
   catch {
       NSLog("MyFunction: %@", error.localizedDescription)
   }
   ```

4. **Main thread only:**
   ```swift
   Task { @MainActor in
       // Safe to write to @Published here
       app.services.manager.property = value
   }
   ```

