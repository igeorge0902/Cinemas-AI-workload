# iOS ↔ Backend Field Gaps & Fallback Strategy
**Quick Reference Card**

---

## ✅ No Backend Changes Needed

This analysis confirms **the backend is correct and complete** for all core booking flows. iOS uses strategic fallbacks where architectural gaps exist (external enrichment, not backend deficiencies).

---

## Missing Fields (Strategic, Not Bugs)

### 1. Movie `rating` Field
- **Backend:** ❌ Not provided
- **iOS Approach:** Fetches from **external RapidAPI IMDb service**
- **Code:** `RapidMovieDatabaseService` → `imdbTitle()`
- **Why:** Avoids coupling backend to IMDb; decouples from data freshness
- **Status:** ✅ Working as designed

### 2. Movie `genre` Field
- **Backend:** ❌ Not provided (only in `category` filtered results)
- **iOS Approach:** Fetches from **external RapidAPI IMDb service**
- **Code:** Same as rating
- **Why:** Same as rating
- **Status:** ✅ Working as designed

### 3. Movie `category` in Response
- **Backend:** ✅ Entity has field, but **NOT serialized** in `/movies`, `/movies/paging`, `/movies/search`
- **iOS Approach:** Does NOT request category in browse responses
- **Impact:** iOS browse view doesn't show category badges
- **Workaround:** Hardcoded strings or external API
- **Status:** ⚠️ **Design decision:** Leave as-is (no UI requirement currently)

---

## Field Name Fallbacks (iOS Resilience)

### Movie Model
```swift
detail    ← Backend: "detail"     | Fallback: "description" | Final fallback: ""
picture   ← Backend: "large_picture" | Fallback: "thumbnail_picture" | Final: ""
```

### Venue Model
```swift
address   ← Backend: "address"    | Fallback: "formatted_address" | Final: ""
picture   ← Backend: "venues_picture" | Fallback: "thumbnail" | Final: ""
screenId  ← Backend: stringValue OR intValue → convert to String
```

### Screening Date Model
```swift
date      ← Backend: "date"       | Fallback: "DATE"
time      ← Backend: "time"       | Fallback: "TIME"
```

### Seat Model
```
isReserved ← Backend: "0" or "1" (STRING, NOT BOOLEAN)
           iOS must compare: isReserved == "1" for reserved
```

---

## Response Type Conversions (iOS Must Handle)

| Field | Backend Type | iOS Type | Conversion |
|-------|--------------|----------|------------|
| `movieId` | int OR string | String | Parse both; convert int to string |
| `venuesId` | int OR string | Int | Parse both |
| `locationId` | int OR string | Int | Parse both |
| `Amount` | string OR number | String | Parse number if needed; stringValue |
| `TaxAmount` | string OR number | String | Parse number if needed; stringValue |
| `isReserved` | string `"0"` or `"1"` | String | ⚠️ **Must stay String** (not boolean) |

---

## Response Array Fallbacks

### Movies Search
```json
Success:    {"searchedMovies": [...]  }
Fallback:   {"movies": [...]}  
Empty:      {"NotFoundMovies": "EndOfFile:)"}
```
**iOS Handling:** `json["searchedMovies"].array ?? json["movies"].array`

### Checkout Success Check
```
Primary:    ResponseText == "hello"
Secondary:  Status == "success"
Also check: status (lowercase)
```

---

## External API Integration (Not Backend Gaps)

### RapidAPI IMDb Enrichment
- **Service:** `RapidMovieDatabaseService`
- **Used For:** Movie metadata (title, genre, rating)
- **Triggered:** When user opens MovieDetailVC or trending view
- **Cache:** Realm-backed cache per IMDb ID
- **Failure Mode:** Graceful; iOS continues without metadata

---

## Hardcoded Contracts (Backend MUST NOT Change)

### Critical Payload Parameters (POST /checkout)
```
payment_method_nonce  (string, from Braintree SDK)
orderId               (string, booking identifier)
seatsToBeReserved     (JSON, format: "A1-B2-C3-" with trailing dash)
```

### Critical Response Keys (Success Detection)
```
ResponseText          (check == "hello" for success)
Status OR status      (check == "success")
tickets[]             (issued tickets array)
seatsforscreen[]      (updated seat map)
Error OR message      (error details)
```

### Critical Header Names (Auth)
```
X-Token               (session token)
X-Device              (device ID)
uuid                  (user UUID)
Ciphertext            (encrypted payload)
X-HMAC-HASH           (HMAC signature)
```

---

## Summary: iOS Is Resilient ✅

✅ All critical booking fields present  
✅ iOS handles field name variants  
✅ iOS handles type conversions (int ↔ string)  
✅ iOS uses external APIs for non-core data (rating, genre)  
✅ iOS provides user-friendly error messages  
❌ NO backend changes recommended at this time  

**Recommendation:** This contract is stable. Future changes should be driven by iOS UI requirements, not backend data availability.

---

## Decision Matrix

| Question | Answer | Reason | Recommendation |
|----------|--------|--------|-----------------|
| Does backend return movie category? | Partially (only in admin view) | Entity exists but not serialized | Leave as-is; iOS doesn't display in browse |
| Does backend return movie rating? | No | External service handles enrichment | No change; design is correct |
| Does backend return movie genre? | No | External service handles enrichment | No change; design is correct |
| Can iOS handle missing picture? | Yes | Falls back to thumbnail | No change; handled well |
| Should `isReserved` be boolean? | No | Backend serializes as string always | iOS must adapt; leave backend as-is |
| Should `/dates` endpoint require `locationId`? | Yes | Already implemented | Keep as baseline; allows future location filtering |


