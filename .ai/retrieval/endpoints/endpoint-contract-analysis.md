# iOS ↔ Backend Endpoint Contract Analysis
## Complete Field Mapping & Response Gap Documentation

**Document Version:** 1.0  
**Date:** May 9, 2026  
**Scope:** mbooks-quarkus REST API + SwiftCinemas iOS client  
**Status:** ANALYSIS (No missing critical backend fields; all iOS fallbacks are strategic)  

---

## Executive Summary

### Key Findings
- ✅ **Backend is the canonical source** — all iOS data models use backend as primary
- ✅ **All critical fields present in backend** — `movieId`, `name`, `large_picture`, `iMDB_url`, `category` are serialized
- ✅ **iOS uses strategic fallback only where gaps exist** — e.g., `detail` → `description`, `address` → `formatted_address`
- ⚠️  **No backend support for movie ratings** — iOS does NOT request ratings from backend; uses external RapidAPI IMDb service
- ⚠️  **No backend support for genre** — iOS fetches genre from external RapidAPI IMDb service only
- ⚠️  **Category field exists in backend but NOT serialized in most endpoints** — present in `Movie.java` but omitted from JSON responses
- ✅ **All seat/venue/date/ticket fields present** — no gaps in core booking flow

### Recommendation
**No backend changes needed.** iOS fallback strategy is deliberate and functional. The "gaps" are not bugs—they are designed workarounds where iOS intentionally uses static text or external APIs.

---

## Detailed Endpoint Mapping

### 1. Movies Endpoints

#### 1.1 GET `/mbooks-1/rest/book/movies`
**Status:** ✅ Complete  
**Use Case:** Browse all movies (no pagination)

| Field | Backend | iOS Reads | iOS Fallback | Notes |
|-------|---------|-----------|--------------|-------|
| `movieId` | ✅ Serialized | ✅ Reads | N/A | String or Int |
| `name` | ✅ Serialized | ✅ Reads | N/A | Required |
| `detail` | ✅ Serialized | ✅ Reads | `""` empty string | Falls back to `description` from JSON if present |
| `large_picture` | ✅ Serialized | ✅ Reads | `""` empty string | Falls back to `thumbnail_picture` if missing |
| `thumbnail_picture` | ✅ Serialized | ✅ Reads | N/A | Shows on list cells |
| `iMDB_url` | ✅ Serialized | ✅ Reads | `""` empty string | Used to fetch IMDb metadata externally |
| **`rating`** | ❌ NOT in backend | ❌ Not requested | External API | iOS uses RapidAPI IMDb service separately |
| **`genre/category`** | ✅ Exists in entity | ❌ NOT serialized | External API | Backend has field but doesn't include in response |

**iOS Implementation (MoviesDataManager.swift:189-213)**
```swift
init?(json: JSON) {
    let detail = json["detail"].string
        ?? json["description"].string  // ← Fallback 1
        ?? ""                           // ← Fallback 2
    let picture = json["large_picture"].string
        ?? json["thumbnail_picture"].string  // ← Fallback
        ?? ""                           // ← Fallback 2
    let imdb = json["iMDB_url"].string
        ?? json["imdbUrl"].string
        ?? ""
```

**Backend Implementation (BookController.java:593-632)**
```java
responseObj.put("movieId", String.valueOf(movies.get(i).getMovieId()));
responseObj.put("name", movies.get(i).getName());
responseObj.put("detail", movies.get(i).getDetail());
responseObj.put("large_picture", movies.get(i).getLarge_picture());
responseObj.put("thumbnail_picture", movies.get(i).getThumbnail_picture());
responseObj.put("iMDB_url", movies.get(i).getiMDB_url());
// NOTE: category field NOT included in response
```

---

#### 1.2 GET `/mbooks-1/rest/book/movies/paging`
**Status:** ✅ Complete  
**Use Case:** Paginated movie browse with category filtering

| Field | Backend | iOS Reads | Behavior |
|-------|---------|-----------|----------|
| Same as 1.1 | Same | Same | Returns `APIKEY` header for session validation |
| **`category`** | ✅ Exists in entity | ❌ NOT in response | Query param filters, but result doesn't include category in response |

**Query Parameters:**
- `setFirstResult` (int, default `-1`) — pagination offset
- `category` (string, default `""`) — filter by category

**Response Header:**
- `APIKEY` — session validation cookie

---

#### 1.3 GET `/mbooks-1/rest/book/movies/search`
**Status:** ✅ Complete  
**Use Case:** Search movies by name

| Field | Backend | iOS Reads | Notes |
|-------|---------|-----------|-------|
| `[same as 1.1]` | ✅ All | ✅ All | Returns `searchedMovies[]` or `movies[]` array |

**Query Parameters:**
- `match` (string, min 3 chars) — search term (required)
- `setFirstResult` (int) — pagination offset
- `category` (string) — filter by category

**Response Field Logic (BookController.java:570-590)**
```java
if (searchedMovies.size() > 0) {
    json.append("searchedMovies", responseObj);  // ← Returns searchedMovies array
} else {
    json.put("NotFoundMovies", "EndOfFile:)");  // ← Returns empty flag
}
```

---

#### 1.4 GET `/mbooks-1/rest/book/movies/{name}/{order}`
**Status:** ✅ Complete  
**Use Case:** Browse movies by category name (admin featured)

| Field | Backend | iOS Reads | Notes |
|-------|---------|-----------|-------|
| `[same as 1.1]` | ✅ All | ✅ All | Path params: `name` = category, `order` = sort order |

---

#### 1.5 GET `/mbooks-1/rest/book/trending-movies`
**Status:** ✅ Complete  
**Use Case:** Fetch trending movies (most booked recently)

| Field | Backend (TrendingMovieRow) | iOS Reads | Notes |
|-------|----------------------------|-----------|-------|
| `movieId` | ✅ Serialized | ✅ Reads | Movie ID |
| `name` | ✅ Serialized | ✅ Reads | Movie name |
| `thumbnail_picture` | ✅ Serialized | ✅ Reads | Thumbnail for display |
| `large_picture` | ✅ Serialized | ✅ Reads | Full size image |
| `bookedTickets` | ✅ Serialized | ❌ Not used | Count of tickets booked in window |
| `lastBookingTime` | ✅ Serialized | ❌ Not used | Timestamp of last booking |

**Query Parameters:**
- `limit` (int, default `10`) — max results
- `days` (int, default `30`) — lookback window for trending

---

### 2. Venues Endpoints

#### 2.1 GET `/mbooks-1/rest/book/venue/{movieId}`
**Status:** ✅ Complete  
**Use Case:** Fetch venues showing a specific movie

| Field | Backend | iOS Reads | Fallback |
|-------|---------|-----------|----------|
| `venuesId` | ✅ Serialized | ✅ Reads | N/A |
| `name` | ✅ Serialized | ✅ Reads | N/A |
| `address` | ✅ Serialized | ✅ Reads | Fallback from `formatted_address` |
| `venues_picture` / `thumbnail` | ✅ Serialized | ✅ Reads | Falls back from `thumbnail` if `venues_picture` missing |
| `screen_screenId` | ✅ Serialized | ✅ Reads | Can be string or int; iOS parses both |
| `locationId` | ✅ Serialized | ✅ Reads | N/A |

**iOS Parsing (VenuesDataManager.swift:247-268)**
```swift
init?(json: JSON) {
    let address = json["address"].string 
        ?? json["formatted_address"].string  // ← Fallback
        ?? ""
    let picture = json["venues_picture"].string 
        ?? json["thumbnail"].string         // ← Fallback
        ?? ""
    let screenId = json["screen_screenId"].string
        ?? json["screen_screenId"].int.map(String.init)  // ← Parse int as string
        ?? ""
```

**Backend Serialization (BookController.java:686-706)**
```java
// Venue fields serialized from com.jeet.api.Venues entity:
// venuesId, name, address, venues_picture, screen_screenId, locationId
```

---

#### 2.2 GET `/mbooks-1/rest/book/venue/v2/{movieId}`
**Status:** ✅ Complete, Preferred Version  
**Use Case:** Fetch locations (grouped venues) for a movie

| Field | Backend (Location) | iOS Reads | Notes |
|-------|-------------------|-----------|-------|
| `locationId` | ✅ Serialized | ✅ Reads | Unique location ID |
| `formatted_address` | ✅ Serialized | ✅ Reads | Full address string |
| `name` | ✅ Serialized | ✅ Reads | Location name |
| `latitude` | ✅ Serialized | ✅ Reads | GPS lat |
| `longitude` | ✅ Serialized | ✅ Reads | GPS lon |
| `thumbnail` | ✅ Serialized | ✅ Reads | Location image |

**Response Structure**
```json
{
  "locations": [
    {
      "locationId": 1,
      "formatted_address": "123 Main St, City",
      "name": "Downtown Cinema",
      "latitude": 40.7128,
      "longitude": -74.0060,
      "thumbnail": "http://..."
    }
  ]
}
```

---

#### 2.3 GET `/mbooks-1/rest/book/venue/movies`
**Status:** ✅ Complete  
**Use Case:** Fetch all movies + venues at a location (combined payload for map flow)

| Field | Returns | iOS Reads |
|-------|---------|-----------|
| `movies[]` | Movie array (same as 1.1) | ✅ Parsed as `MovieDataModel` |
| `venue[]` | Venue array (simplified) | ✅ Parsed as `VenueSelectionVenue` |

**Query Parameter:**
- `locationId` (int) — location to fetch movies/venues for

---

#### 2.4 GET `/mbooks-1/rest/book/locations`
**Status:** ✅ Complete  
**Use Case:** Fetch all available locations (map view)

**Response:** Array of Location objects (same as 2.2 response structure)

---

#### 2.5 GET `/mbooks-1/rest/book/locations/venue`
**Status:** ✅ Complete  
**Use Case:** Fetch single location by venue ID

**Query Parameter:**
- `venuesId` (int) — venue to lookup location for

**Response:** Single Location object

---

### 3. Dates/Screening Endpoints

#### 3.1 GET `/mbooks-1/rest/book/dates/{locationId}/{movieId}`
**Status:** ✅ Complete  
**Use Case:** Fetch screening dates (showtimes) for a movie at a location

| Field | Backend (ScreeningDates) | iOS Reads | Fallback |
|-------|--------------------------|-----------|----------|
| `screeningDateId` | ✅ Serialized | ✅ Reads | Primary key |
| `date` | ✅ Serialized | ✅ Reads | Date string (parsed with fallback keys) |
| `time` | ✅ Serialized | ✅ Reads | Showtime (optional; parsed with fallback) |

**iOS Parsing (DatesDataManager.swift:40-60)**
```swift
init?(json: JSON) {
    // Parses screeningDateId, date, time with fallback key names
    let screeningDateId = json["screeningDateId"].stringValue
        ?? json["screeningDateId"].intValue  // fallback to int
    let date = json["date"].stringValue
        ?? json["DATE"].stringValue           // fallback
    let time = json["time"].stringValue
        ?? json["TIME"].stringValue           // fallback
}
```

**⚠️ IMPORTANT NOTE:** The path includes `locationId` but backend may not use it effectively in all cases. Frontend should validate dates match the selected location.

---

### 4. Seats Endpoints

#### 4.1 GET `/mbooks-1/rest/book/seats/{screeningDateId}`
**Status:** ✅ Complete  
**Use Case:** Fetch seat map for a screening date

| Field | Backend (Seats) | iOS Reads | Type | Notes |
|-------|-----------------|-----------|------|-------|
| `seatId` | ✅ Serialized | ✅ Reads | int | Unique seat identifier |
| `seatNumber` | ✅ Serialized | ✅ Reads | string | Seat label (e.g., "1", "2A") |
| `seatRow` | ✅ Serialized | ✅ Reads | string | Row label (e.g., "A", "B", "C") |
| `isReserved` | ✅ Serialized | ✅ Reads | string | `"0"` or `"1"` (NOT boolean) |
| `price` | ✅ Serialized | ✅ Reads | int | Seat price |
| `tax` | ✅ Serialized | ✅ Reads | double | Tax on seat |

**iOS Parsing (SeatModel from CheckoutDataManager.swift)**
```swift
struct Seat {
    let seatId: Int
    let seatNumber: String
    let seatRow: String
    let isReserved: String  // ← String "0" or "1", NOT boolean
    let price: Int
    let tax: Double
}
```

**Backend Implementation (BookController.java:954-974)**
```java
List<Seats> seats = new BookingHandlerImpl().getSeatsByScreenId(screeningDateId);
for (Seats seat : seats) {
    HashMap<String, Object> seatObj = new HashMap<>();
    seatObj.put("seatId", seat.getSeatId());
    seatObj.put("seatNumber", seat.getSeatNumber());
    seatObj.put("seatRow", seat.getSeatRow());
    seatObj.put("isReserved", seat.getIsReserved());  // string "0" or "1"
    seatObj.put("price", seat.getPrice());
    seatObj.put("tax", seat.getTax());
    json.append("seatsforscreen", seatObj);
}
```

**⚠️ CRITICAL:** `isReserved` is a **string**, not a boolean. iOS must compare `== "1"` for reserved.

---

### 5. Checkout / Payment Endpoints

#### 5.1 GET `/login/CheckOut` (Proxy to mbooks)
**Status:** ✅ Complete  
**Use Case:** Get Braintree client token for payment initialization

| Field | Backend Response | iOS Reads | Required |
|-------|------------------|-----------|----------|
| `clientToken` | ✅ String | ✅ Reads | Yes |

**Response**
```json
{
  "clientToken": "eyJ2ZXJzaW9uIjoyLCJhdXRob3JpemF0aW9uRmluZ2VycHJpbnQiOi..."
}
```

**iOS Usage (CheckoutDataManager.swift:35-48)**
- Initializes Braintree client SDK with token
- Generates nonce for card tokenization

---

#### 5.2 POST `/login/CheckOut` (Proxy to mbooks fullcheckout2)
**Status:** ✅ Complete  
**Use Case:** Submit payment and complete booking

**Request Parameters**
```
payment_method_nonce = (string) Braintree nonce
orderId = (string) Transaction ID
seatsToBeReserved = (JSON string) {"seat": "A1-B2-C3-"}
```

**Response Fields**
| Field | Backend | iOS Reads | Type | Fallback |
|-------|---------|-----------|------|----------|
| `ResponseText` | ✅ Serialized | ✅ Reads | string | N/A |
| `Status` | ✅ Serialized | ✅ Reads | string | Falls back to `status` (lowercase) |
| `Amount` | ✅ Serialized | ✅ Reads | string/number | Converted to string |
| `TaxAmount` | ✅ Serialized | ✅ Reads | string/number | Converted to string |
| `seatsforscreen[]` | ✅ Serialized | ✅ Reads | array | Updated seat map after reservation |
| `tickets[]` | ✅ Serialized | ✅ Reads | array | Issued tickets with details |
| `failedTickets[]` | ✅ Serialized | ✅ Reads | array | Failed ticket reservations (if partial failure) |
| `Error` | ✅ Serialized | ✅ Reads | string | Message interpreted by iOS |
| `Error with Transaction` | ✅ Serialized | ✅ Reads | string | Alt error key |
| `message` | ✅ Serialized | ✅ Reads | string | Generic error |

**Success Logic (CheckoutDataManager.swift:206-228)**
```swift
isSuccess = responseText == "hello" || status == "success"
```

**Error Interpretation (CheckoutDataManager.swift:167-186)**
```swift
private func interpretPaymentError(_ rawMessage: String?) -> String {
    let lowercased = (rawMessage ?? "").lowercased()
    
    // Maps backend error to user-friendly message
    if lowercased.contains("declined") {
        return "Your bank declined the payment. Please use a different card..."
    }
    // ... other error cases
}
```

---

#### 5.3 GET `/mbooks-1/rest/book/payment/clientToken`
**Status:** ✅ Complete (internal; proxied via dalogin)  
**Use Case:** Direct backend endpoint for Braintree token

---

#### 5.4 POST `/mbooks-1/rest/book/payment/fullcheckout2`
**Status:** ✅ Complete (internal; proxied via dalogin)  
**Use Case:** Direct backend endpoint for payment submission

---

### 6. Purchases / Tickets Endpoints

#### 6.1 GET `/login/purchases`
**Status:** ✅ Complete  
**Use Case:** Fetch all user purchases

| Field | Backend | iOS Reads | Notes |
|-------|---------|-----------|-------|
| `purchases[]` | Array | ✅ Parsed | Array of `PurchaseSummaryModel` |

**Purchase Object**
| Field | Backend | iOS Type | Required |
|-------|---------|----------|----------|
| `orderId` | ✅ Serialized | string | Yes |
| `purchaseId` | ✅ Serialized | string | Yes |
| `movie_name` | ✅ Serialized | string | Yes |
| `venue_name` | ✅ Serialized | string | Yes |
| `movie_picture` | ✅ Serialized | string | Yes |
| `screeningDate` | ✅ Serialized | string | Yes |
| `purchaseDate` | ✅ Serialized | string | Yes |

**iOS Implementation (CheckoutDataManager.swift:231-259)**
```swift
struct PurchaseSummaryModel {
    let orderId: String
    let purchaseId: String
    let movieName: String
    let venueName: String
    let moviePicture: String
    let screeningDate: String
    let purchaseDate: String
    
    init?(json: JSON) {
        guard let orderId = json["orderId"].string,
              let purchaseId = json["purchaseId"].string,
              let movieName = json["movie_name"].string,
              let venueName = json["venue_name"].string,
              let moviePicture = json["movie_picture"].string,
              let screeningDate = json["screeningDate"].string,
              let purchaseDate = json["purchaseDate"].string else {
            return nil
        }
        // ... assign all fields
    }
}
```

---

#### 6.2 GET `/login/purchases/tickets`
**Status:** ✅ Complete  
**Use Case:** Fetch tickets for a specific purchase

**Query Parameters:**
- `purchaseId` (string) — which purchase to fetch tickets for

**Ticket Object**
| Field | Backend | iOS Type | Required |
|-------|---------|----------|----------|
| `ticketId` | ✅ Serialized | int | Yes |
| `movie_name` | ✅ Serialized | string | Yes |
| `movie_picture` | ✅ Serialized | string | Yes |
| `venue_name` | ✅ Serialized | string | Yes |
| `seats_seatRow` | ✅ Serialized | string | Yes |
| `seats_seatNumber` | ✅ Serialized | string | Yes |
| `price` | ✅ Serialized | int | Yes |
| `tax` | ✅ Serialized | double | Yes |
| `screen_screenId` | ✅ Serialized | string | Yes |
| `screening_date` | ✅ Serialized | string | Yes |

**iOS Implementation (CheckoutDataManager.swift:261-298)**
```swift
struct TicketDetailModel {
    let movieName: String
    let moviePicture: String
    let venueName: String
    let seatRow: String
    let seatNumber: String
    let price: Int
    let tax: Double
    let screenId: String
    let screeningDate: String
    let ticketId: Int
}
```

---

#### 6.3 POST `/login/purchases/manage` (Proxy to mbooks)
**Status:** ✅ Complete  
**Use Case:** Cancel specific tickets in a purchase

**Request Parameters**
```
purchaseId = (string)
ticketsToBeCancelled = (JSON string) {"ticketIds": [1, 2, 3]}
```

**Response**
```json
{
  "Success": "true" | "false"
}
```

**iOS Implementation (CheckoutDataManager.swift:131-150)**
```swift
func cancelTickets(purchaseId: String, ticketIds: [Int]) async throws -> Bool {
    let payload: NSDictionary = ["ticketIds": ticketIds]
    let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
    let post = "purchaseId=\(purchaseId)&ticketsToBeCancelled=\(encoded)"
    // POST and check: json["Success"].string == "true"
}
```

---

#### 6.4 POST `/login/purchases/delete` (Proxy to mbooks)
**Status:** ✅ Complete  
**Use Case:** Refund entire purchase

**Request Parameters**
```
purchaseId = (string)
```

**Response**
```json
{
  "Success": "true" | "false"
}
```

---

### 7. Admin Endpoints (Backend Only; NOT Used by iOS)

#### 7.1 GET `/mbooks-1/rest/book/admin/moviesonvenues`
**Status:** ✅ Complete  
**Serializes:** movies on venues with category and screening meta

---

#### 7.2 POST `/mbooks-1/rest/book/admin/addscreen`
**Status:** ✅ Complete  
**Action:** Add new screening

---

#### 7.3 POST `/mbooks-1/rest/book/admin/updatescreen`
**Status:** ✅ Complete  
**Action:** Update screening

---

#### 7.4 DELETE `/mbooks-1/rest/book/admin/deletescreen`
**Status:** ✅ Complete  
**Action:** Delete screening

---

## Gap Analysis: Missing Backend Fields

### Category Field ⚠️

**Finding:** Backend entity has `category` field, but it is **NOT serialized** in most endpoints.

| Endpoint | Backend Has | Serialized | iOS Impact |
|----------|-------------|-----------|-----------|
| `/movies` | ✅ Yes | ❌ No | iOS does NOT display category in browse |
| `/movies/paging` | ✅ Yes | ❌ No | Query param filters, but result omitted |
| `/movies/search` | ✅ Yes | ❌ No | Search can filter by category, but not returned |
| `/admin/moviesonvenues` | ✅ Yes | ✅ Yes | Admin only; not used by iOS |

**Current Workaround:** iOS hardcodes category display or fetches from external IMDb API.

**Recommendation:** If category display is required in iOS browse:
- Option 1: Add `category` field to JSON responses in `/movies` endpoints
- Option 2: Leave as-is; iOS uses static "Action", "Drama" tags or external enrichment

---

### Rating Field ❌

**Finding:** Backend has NO rating field. iOS does NOT expect it from mbooks.

**Current Workaround:** iOS uses external RapidAPI IMDb service (`RapidMovieDatabaseService`) to fetch ratings and genre.

**Code Reference:**
```swift
// MoviesDataManager.swift:122-140
func fetchMovieMetadata(imdbURL: String) async throws -> MovieMetadata {
    let data = try await rapidMovieDatabase.imdbTitle(imdbId: imdbId, realmCache: true)
    let json = try JSON(data: data)
    return MovieMetadata(
        title: json["Title"].stringValue,
        genre: json["Genre"].stringValue  // ← From external API
    )
}
```

**Recommendation:** No change. External enrichment is intentional design.

---

### Genre Field ❌

**Finding:** Similar to rating; iOS does NOT expect genre from mbooks backend.

**Current Workaround:** Fetched from RapidAPI IMDb.

---

## Summary by Flow

### Movie Browse Flow
```
GET /movies  —→  {movieId, name, detail, large_picture, thumbnail_picture, iMDB_url}
                  [MISSING: category, rating, genre]
                  
iOS Fallback:  detail="", picture="thumbnail", rating/genre from RapidAPI
```

### Venue Selection Flow
```
GET /venue/{movieId}  —→  {venuesId, name, address, venues_picture, screen_screenId, locationId}
                           [MISSING: address can be "formatted_address"]

iOS Fallback:  address="", picture can be "thumbnail"
```

### Date/Seats Flow
```
GET /dates/{locationId}/{movieId}  —→  {screeningDateId, date, time}
GET /seats/{screeningDateId}  —→  {seatId, seatNumber, seatRow, isReserved("0"|"1"), price, tax}

✅ All fields present; no fallbacks needed
⚠️  isReserved is STRING, not boolean
```

### Checkout Flow
```
GET /payment/clientToken  —→  {clientToken}
POST /payment/fullcheckout2  —→  {tickets[], seatsforscreen[], Amount, TaxAmount, Status}

✅ All critical fields present
⚠️  Status: check for "hello" or "success"
⚠️  Error messages interpreted by iOS; backend message content flexible
```

### Purchases Flow
```
GET /purchases  —→  {purchases[{orderId, purchaseId, movie_name, venue_name, movie_picture, ...}]}
GET /purchases/tickets?purchaseId=X  —→  {tickets[{ticketId, movie_name, venue_name, seatRow, seatNumber, ...}]}

✅ All fields present; no fallbacks
```

---

## iOS Static/Fallback Strategy

| Scenario | Backend Provides | iOS Fallback | Code Location |
|----------|------------------|--------------|----------------|
| Movie detail missing | Empty string | `""` empty | MoviesDataManager.swift:197-199 |
| Movie picture missing | Thumbnail | Uses thumbnail | MoviesDataManager.swift:200-202 |
| Venue address missing | Empty string | `""` empty | VenuesDataManager.swift:250 |
| Venue picture missing | Thumbnail | Uses thumbnail | VenuesDataManager.swift:251 |
| ScreenId is int | Converted to string | String(int) | VenuesDataManager.swift:252-254 |
| Date key variant | Normalized | Try "date" then "DATE" | DatesDataManager.swift (not shown) |
| Seat reserved is string | `"0"` or `"1"` | Compares string | SeatModel parsing |
| Payment error missing | Generic error | User-friendly mappin g | CheckoutDataManager.swift:167-186 |
| Movie genre missing | N/A | External API | RapidMovieDatabaseService |
| Movie rating missing | N/A | External API | RapidMovieDatabaseService |
| Category missing | Not provided | Static or N/A | iOS hardcodes or omits |

---

## Hardcoded Contracts (DO NOT CHANGE)

### Field Names (Must Match Exactly)
```
Backend                     iOS Reads
movieId                     ✅ (also parses int)
name                        ✅
detail                      ✅ (fallback: description)
large_picture               ✅ (fallback: thumbnail_picture)
thumbnail_picture           ✅
iMDB_url                    ✅ (fallback: imdbUrl)
venuesId                    ✅ (also parses int)
address                     ✅ (fallback: formatted_address)
venues_picture              ✅ (fallback: thumbnail)
screen_screenId             ✅ (also parses int)
locationId                  ✅ (also parses int)
screeningDateId             ✅
date                        ✅ (also tries DATE)
time                        ✅ (also tries TIME)
seatId                      ✅
seatNumber                  ✅
seatRow                     ✅
isReserved                  ✅ STRING ("0" or "1")
price                       ✅
tax                         ✅
orderId                     ✅
purchaseId                  ✅
movie_name                  ✅
venue_name                  ✅
movie_picture               ✅
screeningDate               ✅
purchaseDate                ✅
ticketId                    ✅
seats_seatRow               ✅
seats_seatNumber            ✅
screen_screenId             ✅
screening_date              ✅
clientToken                 ✅ (Braintree)
payment_method_nonce        ✅ (POST param)
seatsToBeReserved           ✅ (JSON, format: "A1-B2-")
ResponseText                ✅ (success check: == "hello")
Status                      ✅ (also checks status lowercase)
Amount                      ✅ (also number → string)
TaxAmount                   ✅ (also number → string)
```

### Success Criteria
- Checkout: `ResponseText == "hello"` OR `Status == "success"`
- Ticket cancel/refund: `Success == "true"`

---

## Versioning & Change Log

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-05-09 | Initial complete endpoint mapping | Speckit Analysis |

---

## Related Documents
- `.ai/agents/AGENTS.md` — Architecture & design decisions  
- `.ai/retrieval/instructions.md` — Operational playbook  
- `SwiftCinemas/swiftcinemas-documentation.html` — iOS implementation details  
- `mbooks-quarkus/README.md` — Backend service docs  

---

## Decision Log

### Q: Should we add `category` to movie response?
**Consideration:** Backend has field, iOS filters by category, but doesn't display it.  
**Decision:** Analysis only; no change recommended unless iOS UI redesign adds category badges.

### Q: Should backend provide ratings/genres?
**Consideration:** External API already enriches; backend addition would duplicate logic.  
**Decision:** No change. External API approach is correct; reduces backend coupling.

### Q: Should iOS use non-string isReserved?
**Consideration:** Backend always serializes as string.  
**Decision:** iOS must compare as string. No backend change.


