# iOS ↔ Backend Endpoint Dependency Map
**Visual Contract Reference**

---

## Booking Flow Chain

```
┌─────────────────────────────────────────────────────────────────┐
│                         MOVIE BROWSE                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  GET /mbooks-1/rest/book/movies/paging                          │
│      ├─ Query: setFirstResult, category                         │
│      └─ Response: {movies[{movieId, name, detail,               │
│                            large_picture, thumbnail_picture}]}  │
│                                                                  │
│  ↓ (Optional) Fetch metadata                                    │
│  RapidAPI IMDb Service (EXTERNAL)                               │
│      └─ Gets: genre, rating, runtime                            │
│                                                                  │
│  ↓ User selects movie                                           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      VENUE SELECTION                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  GET /mbooks-1/rest/book/venue/v2/{movieId}                     │
│      ├─ Response: {locations[{locationId, name,                │
│      │              formatted_address, latitude,                │
│      │              longitude, thumbnail}]}                     │
│      │                                                           │
│      └─ Alternative: /venue/{movieId}                           │
│          Response: {venues[{venuesId, name, address,            │
│                            screen_screenId, locationId}]}       │
│                                                                  │
│  ↓ User selects venue                                           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    DATE/TIME SELECTION                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  GET /mbooks-1/rest/book/dates/{locationId}/{movieId}           │
│      └─ Response: {dates[{screeningDateId, date, time}]}        │
│                                                                  │
│  ↓ User selects date                                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      SEAT SELECTION                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  GET /mbooks-1/rest/book/seats/{screeningDateId}                │
│      └─ Response: {seatsforscreen[{seatId, seatNumber,          │
│                                    seatRow, isReserved,         │
│                                    price, tax}]}                │
│                                                                  │
│  ↓ User selects seats → creates orderId                         │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    PAYMENT / CHECKOUT                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Step 1: GET /login/CheckOut (proxy)                             │
│      ├─ Backend: /mbooks-1/rest/book/payment/clientToken        │
│      └─ Response: {clientToken: "eyJ..."}                        │
│                                                                   │
│  Step 2: Initialize Braintree.Client with clientToken           │
│           → User enters card details                             │
│           → Braintree SDK generates payment_method_nonce         │
│                                                                   │
│  Step 3: POST /login/CheckOut (proxy)                            │
│      ├─ Backend: /mbooks-1/rest/book/payment/fullcheckout2      │
│      ├─ Payload:                                                 │
│      │    payment_method_nonce = (from Braintree)                │
│      │    orderId = (booking ID)                                 │
│      │    seatsToBeReserved = {seat: "A1-B2-C3-"}                │
│      │                                                            │
│      └─ Response: {                                              │
│           ResponseText: "hello" (success indicator),             │
│           Status: "success" | error message,                     │
│           Amount: "150.00",                                      │
│           TaxAmount: "15.00",                                    │
│           tickets[{                                              │
│             ticketId, movieName, venueName,                      │
│             seatRow, seatNumber, price, tax                      │
│           }],                                                    │
│           seatsforscreen[...] (updated seat map)                 │
│         }                                                         │
│                                                                   │
│  ↓ Success: Save purchase; show confirmation                     │
│  ↑ Failure: Show error; rollback; release seats                  │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    PURCHASES / HISTORY                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  GET /login/purchases                                            │
│      └─ Response: {purchases[{orderId, purchaseId,               │
│                              movieName, venueName,               │
│                              moviePicture, screeningDate,        │
│                              purchaseDate}]}                     │
│                                                                   │
│  ↓ User selects purchase                                         │
│                                                                   │
│  GET /login/purchases/tickets?purchaseId={id}                    │
│      └─ Response: {tickets[{ticketId, movieName, venueName,     │
│                            seatRow, seatNumber,                  │
│                            price, tax, screeningDate}]}          │
│                                                                   │
│  Optional: Cancel/Refund                                         │
│  ├─ POST /login/purchases/manage (cancel specific tickets)       │
│  └─ POST /login/purchases/delete (refund entire purchase)        │
└──────────────────────────────────────────────────────────────────┘
```

---

## Missing Field Diagram

```
BACKEND MOVIE ENTITY              BACKEND RESPONSE          iOS MODEL
┌─────────────────┐              ┌──────────────┐        ┌──────────────┐
│ movieId         │✓Serialized→│ movieId      │        │ movieId      │✓Read
│ name            │✓           │ name         │        │ name         │✓
│ detail          │✓           │ detail       │        │ detail       │✓
│ large_picture   │✓           │ large_picture│        │ largePicture │✓
│ thumbnail_pic   │✓           │ thumbnail... │        │ ...          │✓
│ iMDB_url        │✓           │ iMDB_url     │        │ imdbUrl      │✓
│ category        │✓Entity     │ ✗NOT in /    │        │ ...          │
│                 │   field    │   movies     │        │              │✓External
│ [MISSING]       │  N/A       │  N/A         │←─Gap─→│ rating       │  RapidAPI
│ [MISSING]       │  N/A       │  N/A         │←─Gap─→│ genre        │  RapidAPI
└─────────────────┘            └──────────────┘        └──────────────┘

Legend:
✓ = Present & Used
✓Entity = In Java entity, not serialized in response
✗ = Not in response
← Gap = Strategic gap (external service fills)
→ = Field transformation
```

---

## Request/Response Payload Examples

### Example 1: Movie Browse (GET /movies/paging)

**Request**
```
GET /mbooks-1/rest/book/movies/paging?setFirstResult=0&category=Action
Header: X-Device: device-123
```

**Response**
```json
{
  "movies": [
    {
      "movieId": "1",
      "name": "The Matrix",
      "detail": "A computer programmer is offered a choice...",
      "large_picture": "https://..../matrix-large.jpg",
      "thumbnail_picture": "https://..../matrix-thumb.jpg",
      "iMDB_url": "tt0133093"
    },
    {
      "movieId": "2",
      "name": "Inception",
      "detail": "A thief who specializes in extraction...",
      "large_picture": "https://..../inception-large.jpg",
      "thumbnail_picture": "https://..../inception-thumb.jpg",
      "iMDB_url": "tt1375666"
    }
  ]
}
```

**iOS Parsing** (MovieDataModel)
```swift
let detail = json["detail"].string ?? json["description"].string ?? ""
let picture = json["large_picture"].string ?? json["thumbnail_picture"].string ?? ""
// category NOT in response; iOS shows static "Action" or fetches from RapidAPI
```

---

### Example 2: Dates (GET /book/dates/{locationId}/{movieId})

**Request**
```
GET /mbooks-1/rest/book/dates/101/1
```

**Response**
```json
{
  "dates": [
    {
      "screeningDateId": "501",
      "date": "2026-05-15",
      "time": "14:30"
    },
    {
      "screeningDateId": "502",
      "date": "2026-05-15",
      "time": "17:00"
    },
    {
      "screeningDateId": "503",
      "date": "2026-05-16",
      "time": "19:30"
    }
  ]
}
```

**iOS Parsing** (ScreeningDateModel)
```swift
let screeningDateId = json["screeningDateId"].stringValue
let date = json["date"].stringValue ?? json["DATE"].stringValue
let time = json["time"].stringValue ?? json["TIME"].stringValue
```

---

### Example 3: Seats (GET /book/seats/{screeningDateId})

**Request**
```
GET /mbooks-1/rest/book/seats/501
```

**Response**
```json
{
  "seatsforscreen": [
    {
      "seatId": 1001,
      "seatNumber": "1",
      "seatRow": "A",
      "isReserved": "0",
      "price": 10,
      "tax": 1.0
    },
    {
      "seatId": 1002,
      "seatNumber": "2",
      "seatRow": "A",
      "isReserved": "1",
      "price": 10,
      "tax": 1.0
    }
  ]
}
```

**iOS Parsing** (SeatModel)
```swift
struct Seat {
    let isReserved: String  // ← "0" or "1" STRING!
    
    var isAvailable: Bool {
        isReserved == "0"  // ← Must compare as string
    }
}
```

---

### Example 4: Checkout Payment (POST /login/CheckOut)

**Request**
```
POST /login/CheckOut HTTP/1.1
Content-Type: application/x-www-form-urlencoded
X-Token: session-token-xyz
Ciphertext: encrypted-payload

payment_method_nonce=nonce_abc123xyz&orderId=ORD-2026-001&seatsToBeReserved={"seat":"A1-B2-C3-"}
```

**Response (Success)**
```json
{
  "ResponseText": "hello",
  "Status": "success",
  "Amount": "30.00",
  "TaxAmount": "3.00",
  "tickets": [
    {
      "ticketId": 5001,
      "movie_name": "The Matrix",
      "movie_picture": "https://...",
      "venue_name": "Downtown Cinema",
      "seats_seatRow": "A",
      "seats_seatNumber": "1",
      "price": 10,
      "tax": 1.0,
      "screen_screenId": "1",
      "screening_date": "2026-05-15 14:30"
    }
  ],
  "seatsforscreen": [
    // updated seat map after reservation
  ]
}
```

**Response (Failure)**
```json
{
  "ResponseText": "error",
  "Status": "failed",
  "Error": "Card declined by issuer",
  "Amount": null,
  "TaxAmount": null,
  "tickets": [],
  "seatsforscreen": [],
  "failedTickets": []
}
```

**iOS Interpretation**
```swift
let isSuccess = responseText == "hello" || status == "success"
if !isSuccess {
    let userMessage = interpretPaymentError(errorMessage)
    // Shows: "Your bank declined the payment. Please use a different card..."
}
```

---

## Field Transformation Summary

| Backend Field | iOS Property | Transform | Example |
|---------------|--------------|-----------|---------|
| `movieId` | `movieIdString` | int → String | `1` → `"1"` |
| `venuesId` | `venuesId` | int/String → int | `"101"` → `101` |
| `large_picture` | `largePicture` | Direct | No change |
| `detail` | `detail` | Try alt keys | `"description"` → `"detail"` |
| `isReserved` | `isReserved` | Keep as String | `"0"` stays `"0"` |
| `Amount` | `amount` | number → String | `150` → `"150.00"` |

---

## Error Message Mapping

**Backend Error** → **iOS User Message**
```
"nonce" / "payment method"  →  "Your payment method could not be verified..."
"declined"                 →  "Your bank declined the payment..."
"insufficient"             →  "Insufficient funds. Please use another..."
"gateway" / "network" / "timeout"  →  "Payment service is temporarily unavailable..."
[empty/unknown]            →  "Payment could not be completed. Please try again."
```

---

## Authentication Headers (Hardcoded Contracts)

| Header | Usage | Source |
|--------|-------|--------|
| `X-Token` | Session validation | Login response |
| `X-Device` | Device identification | Initial auth handshake |
| `uuid` | User UUID | Database user record |
| `Ciphertext` | Encrypted request payload | AES encryption on request body |
| `X-HMAC-HASH` | Request integrity (HMAC-SHA512) | iOS HMAC interceptor |
| `XSRF-TOKEN` | CSRF protection | Session cookie |

✅ **All header names must match exactly—iOS client depends on these.**

---

## Versioning Notes

- Backend version: Quarkus 3.19.4
- iOS version: Swift 5.x (async/await)
- Contract version: 1.0 (stable; current as of May 2026)
- Braintree SDK versions:
  - Client.js: 1.44.1
  - iOS: 5.26.0
  - Java: 3.36.0

---


