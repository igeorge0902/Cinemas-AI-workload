# Reference Guide — Cinemas Project

Complete reference of key files, APIs, database schemas, and decision trees for development.

Canonical endpoint contract IDs are maintained in `.ai/retrieval/references/CONTRACTS_INDEX.md`.

## Architecture at a Glance

```
iOS Client (SwiftCinemas)  ←→  Web UI (AngularJS)
           ↓                          ↓
        HTTPS / HMAC-SHA512 ← Session / HMAC-SHA512
           ↓                          ↓
   ┌──────────────────────────┐
   │  NGINX Ingress (TLS)     │
   │  + Apache mod_proxy      │
   └──────────────────────────┘
           ↓
   ┌──────────────────────────────────────────┐
   │  Quarkus Services                        │
   ├──────────────────────────────────────────┤
   │ dalogin (port 8080, /login)              │
   │   - Session management                    │
   │   - HMAC login (HelloWorld)              │
   │   - Proxy servlets (CheckOut, ...)       │
   │                                           │
   │ mbook (port 8888, /mbook-1)              │
   │   - User profiles, devices, sessions     │
   │   - WebSocket endpoint                   │
   │                                           │
   │ mbooks (port 8080, /mbooks-1)            │
   │   - Movie catalog                        │
   │   - Booking & payment                    │
   │   - WebSocket endpoint                   │
   │                                           │
   │ simple-service-webapp (port 8085)        │
   │   - Image serving                        │
   └──────────────────────────────────────────┘
           ↓
   ┌──────────────────────────┐
   │  MySQL 8                 │
   ├──────────────────────────┤
   │ login_ (dalogin, mbook)  │
   │ book (mbooks)            │
   └──────────────────────────┘
           
   ┌──────────────────────────┐
   │  Kafka (Zookeeper)       │
   │  Real-time broadcasts    │
   └──────────────────────────┘
           
   ┌──────────────────────────┐
   │  Observability Stack     │
   ├──────────────────────────┤
   │ Prometheus (metrics)     │
   │ Tempo (traces)           │
   │ Grafana (dashboards)     │
   └──────────────────────────┘
```

## Backend Services Reference

### iOS Networking Layer (SwiftCinemas Refactoring)

**Architecture:** Modern async/await-based HTTP client with centralized service wrappers, protocol-based headers, and response caching.

**Primary files** (`SwiftLoginScreen/Networking/`):
- `APIClient.swift` — Main HTTP client:
  - `APIClientProtocol` — Interface for request/response handling
  - `APIClient` — Async/await implementation, response caching, error handling, cookie management
  - `HasAPIClient` — Protocol for ViewControllers to receive injected client
- `BackendServices.swift` — Service wrapper classes (@MainActor bound):
  - `AppServices` — Container for all services (injected from AppDelegate)
  - `MbooksService` — `/mbooks-1/rest/book` endpoints (movies, venues, seats, admin)
  - `LoginGatewayService` — `/login` proxy servlets (login, checkout, purchases, activation)
  - `ImageResourceService` — Image downloads (absolute URLs, optional caching)
  - `RapidMovieDatabaseService` — External RapidAPI (IMDb)
  - `HasAppServices` — Protocol for ViewControllers to receive injected services
- `Endpoint.swift` — Request builder:
  - `Endpoint` struct — path, method, query, body, cacheKey, absoluteURL support
  - `buildRequest()` — URL composition and header injection
- `URLManager.swift` — Centralized URL configuration:
  - `baseHost` = `milo.crabdance.com` (single point to change)
  - Service paths: `loginPath`, `mbooksPath`, `imagePath`
  - WebSocket URL builder
- `HeaderProvider.swift` — Protocol + implementations:
  - `HeaderProvider` protocol — `headers() -> [String: String]`
  - `SessionHeaderProvider` — Session auth headers (X-Token, Ciphertext, X-Device)
  - `HMACLoginHeaderProvider` — HMAC-SHA512 login (X-HMAC-HASH, X-MICRO-TIME)
  - `MinimalGETHeaderProvider` — Empty headers (public/image requests)
  - `RapidMovieDatabaseHeaderProvider` — RapidAPI keys
  - `MergedHeaderProvider` — Combine base + extra headers
- `AppError.swift` — Standard error types:
  - `networkFailure(underlying: Error)`
  - `httpError(statusCode: Int, message: String)`
  - `authRequired` (401)
  - `activationRequired(voucherActive: Bool)` (300)
  - `decodingFailed` (JSON parsing)
- `ResponseCache.swift` — Protocol for caching GET responses (Realm-backed)
- `ErrorHandler.swift` — Error display + user-facing messages

**Service injection pattern** (`AppDelegate`):
```swift
let apiClient = APIClient(
    baseURL: URL(string: URLManager.baseURL)!,
    session: URLSession.sharedCustomSession,
    cache: RealmResponseCache()
)
let services = AppServices(
    apiClient: apiClient,
    mbooks: MbooksService(apiClient: apiClient),
    loginGateway: LoginGatewayService(apiClient: apiClient),
    images: ImageResourceService(apiClient: apiClient),
    rapidMovieDatabase: RapidMovieDatabaseService(apiClient: apiClient)
)
```

**Key differences from legacy (`GeneralRequestManager`)**:
- ✅ Modern async/await (no callbacks)
- ✅ Protocol-based header injection (extensible)
- ✅ Unified response caching via `ResponseCache`
- ✅ `@MainActor` bound services (UI thread safety)
- ✅ Standard `AppError` enum (no `NSError` strings)
- ✅ `Endpoint` struct (reusable URL composition)
- ✅ Service container injection (testability)

### dalogin-quarkus (Port 8080, Root: `/login`)

**Primary files:**
- `src/main/java/com/dalogin/servlets/HelloWorld.java` — HMAC login, password validation
- `src/main/java/com/dalogin/servlets/CheckOut.java` — proxy to mbooks checkout
- `src/main/java/com/dalogin/servlets/GetAllPurchases.java` — proxy to mbooks purchases
- `src/main/java/com/dalogin/servlets/ManagePurchases.java` — proxy to mbooks ticket management
- `src/main/java/com/dalogin/filters/RequestFilter.java` — extracts session UUID, validates HMAC
- `src/main/java/com/dalogin/filters/CiphertextFilter.java` — validates Ciphertext token
- `src/main/java/com/dalogin/filters/CookieFilter.java` — validates XSRF-TOKEN cookie
- `src/main/java/com/dalogin/filters/AuthFilter.java` — requires valid session
- `src/main/java/com/dalogin/client/ServiceClient.java` — injects headers for downstream calls
- `src/main/java/com/dalogin/utils/AesUtil.java` — AES-256 encryption (Ciphertext generation)
- `src/main/java/com/dalogin/utils/hmac512.java` — HMAC-SHA512 signature
- `src/main/resources/META-INF/resources/film-review/app.js` — AngularJS app (HMAC interceptor, controllers)
- `src/main/resources/META-INF/resources/film-review/index.html` — SPA shell, Braintree SDK
- `web.xml` — servlet + filter registration

**Database:** `login_` (MySQL)
- `user` — login credentials, activation status
- `device` — client devices (fingerprints)
- `session` — active sessions (uuid, token2, etc.)
- `voucher` — discount codes (state machine: issued → active → redeemed)

**Key endpoints:**
| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/HelloWorld` | POST | HMAC | Login + password validation |
| `/logout` | GET | Session | Destroy session |
| `/CheckOut` | GET/POST | Session | Proxy to mbooks payment |
| `/GetAllPurchases` | GET | Session | Proxy to mbooks purchases list |
| `/ManagePurchases` | GET/POST | Session | Proxy to mbooks ticket management |
| `/admin` | GET | Session | List active sessions/devices |

### mbook-quarkus (Port 8888, Root: `/mbook-1`)

**Primary files:**
- `src/main/java/com/jeet/rest/UserController.java` — user profile, device management
- `src/main/java/com/jeet/db/DAO.java` — user/device/session DAO queries
- `src/main/java/com/jeet/broadcasting/KafkaListener.java` — consumes user event broadcasts
- `src/main/java/com/jeet/WebSocketServer.java` — real-time user notifications

**Database:** `login_` (MySQL)

**Key endpoints:**
| Endpoint | Auth | Purpose |
|----------|------|---------|
| `/profile` | HMAC | Get user profile |
| `/devices` | HMAC | List user devices |
| `/sessions` | HMAC | List user sessions |
| `/ws` | WebSocket | Real-time notifications |

### mbooks-quarkus (Port 8080, Root: `/mbooks-1`)

**Primary files:**
- `src/main/java/com/jeet/rest/BookController.java` (1170 lines) — **main business logic**
  - Lines 1–300: Movies (browse, search, paging), venues
  - Lines 300–600: Seat selection, availability checking
  - Lines 600–1170: Payment (Braintree client token, checkout, transaction)
- `src/main/java/com/jeet/service/PaymentService.java` — Braintree gateway interaction
- `src/main/java/com/jeet/service/TicketService.java` — ticket creation, rollback logic
- `src/main/java/com/jeet/booking/BookingHandlerImpl.java` — booking workflow orchestration
- `src/main/java/com/jeet/db/DAO.java` — Hibernate queries (pessimistic locking, cache)
- `src/main/java/com/jeet/api/` — entity classes (Movie, Venue, Ticket, Purchase, Screen, Seats, ScreeningDates)
- `src/main/java/com/jeet/broadcasting/KafkaListener.java` — consumes movie event broadcasts
- `src/main/java/com/jeet/WebSocketServer.java` — real-time seat updates, broadcasts
- `src/main/resources/hibernate.cfg.xml` — Hibernate L2 cache, session factory
- `src/main/resources/infinispan-configs-local.xml` — Infinispan cache strategies

**Database:** `book` (MySQL)
- `movie` — film catalog
- `location` — cinema locations
- `venues` — cinema screens
- `screen` — screen/venue mapping
- `screening_dates` — show times
- `seats` — individual seat slots (reserved/available)
- `ticket` — purchased seats
- `purchase` — orders (contains 1+ tickets)

**Key endpoints:**
| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/book/movies` | GET | Public | Browse all movies (paginated) |
| `/book/movies/{id}` | GET | Public | Get movie details |
| `/book/locations` | GET | Public | Browse all cinema locations |
| `/book/venue/v2/{movieId}` | GET | HMAC | Venues screening this movie |
| `/book/dates/{locId}/{movId}` | GET | HMAC | Screening dates for movie@location |
| `/book/seats/{sdId}` | GET | HMAC | Seat map for a screening date |
| `/book/payment/clientToken` | GET | Session | Get Braintree client token |
| `/book/payment/fullcheckout2` | POST | Session | Submit payment + reserve seats |
| `/book/purchases` | GET | HMAC | List user's purchases |
| `/book/purchases/tickets` | GET | HMAC | Get tickets for a purchase |
| `/book/managepurchases` | POST | Session | Cancel individual tickets |
| `/book/deletepurchases` | POST | Session | Delete entire purchase |
| `/ws` | WebSocket | — | Real-time seat updates |

### simple-service-webapp-quarkus (Port 8085, Root: `/simple-service-webapp`)

**Primary files:**
- `src/main/java/com/jeet/ImageResource.java` — serves images from disk
- `Dockerfile` — mounts `pictures/` volume

**Key endpoints:**
| Endpoint | Purpose |
|----------|---------|
| `/image/{category}/{filename}` | Serve image (movies, venues, profiles) |
| `/health` | Health check |

## Database Schemas

### `login_` Schema (dalogin + mbook)

```sql
-- Core tables
user (id, username, password, salt, email, profile_picture, active, ...)
device (id, user_id, device_id, os_type, created_at, ...)
session (id, user_id, device_id, uuid, token2, time_, created_at, expires_at, ...)
voucher (id, code, state, user_id, issued_date, redeemed_date, value, ...)

-- Triggers (in login.sql)
user_insert_trigger — on user insert
device_insert_trigger — on device insert
session_update_trigger — on session update
```

**Key columns:**
- `user.password` — SHA3-512 hash (stored)
- `session.token2` — encrypted token (AES-256)
- `session.time_` — authentication timestamp (part of Ciphertext)
- `device.device_id` — browser fingerprint / iOS identifier

### `book` Schema (mbooks)

```sql
-- Catalog
movie (id, name, description, category, picture_url, ...)
location (id, name, address, picture_url, ...)
venues (id, location_id, screen_id, created_at, ...)
screen (id, movie_id, created_at, ...)
screening_dates (id, venues_id, screen_id, screening_date, available_seats, ...)

-- Booking
seats (id, screen_id, seat_row, seat_number, is_reserved, created_at, ...)
ticket (id, purchase_id, seats_id, price, tax, ...)
purchase (id, uuid, order_id, timestamp, total_amount, total_tax, braintree_customer_id, ...)

-- Indexes
idx_seats_screen_id_is_reserved — for seat availability queries
idx_ticket_purchase_id — for fetching tickets by purchase
idx_purchase_uuid — for user's purchases lookup
```

**Key columns:**
- `seats.is_reserved` — `"0"` (available) or `"1"` (reserved, string NOT boolean)
- `purchase.uuid` — links to user session
- `purchase.order_id` — client-supplied timestamp (for idempotency)

## Authentication & Authorization

### HMAC-SHA512 Flow

**Client (iOS + Web):**
```
1. POST /login/HelloWorld
   Body: username=USER&password=PASS&deviceId=FINGERPRINT
   
2. Server computes:
   passHash = SHA3-512(password)
   hmac = HMAC-SHA512(username, TIME_STRING + passHash)
   
3. Client must send same HMAC as X-HMAC-HASH header
```

**Downstream requests (after login):**
```
Headers:
  X-Token: <session token>
  X-Device: <browser fingerprint>
  X-HMAC-HASH: <HMAC-SHA512(username, timestamp + params)>
  X-MICRO-TIME: <current timestamp ms>
  Cookie: XSRF-TOKEN=<encrypted value>

Server validates:
  1. RequestFilter extracts session UUID from X-Token
  2. CiphertextFilter decrypts Ciphertext (X-Token) using AES-256
  3. CookieFilter verifies XSRF-TOKEN matches encrypted session state
  4. AuthFilter checks session not expired
  5. ActiveVoucherFilter checks account activated
  6. Request allowed if all checks pass
```

## Payment & Booking Flow

### End-to-End (Web or iOS)

```
┌─ CLIENT ──────────────────────────────────────┐
│ 1. Browse movies → pick movie, date, seats   │
│ 2. Get Braintree clientToken                 │
│ 3. Show payment form (Braintree Drop-in)     │
│ 4. User enters card → receives nonce         │
│ 5. Submit: payment_method_nonce + seats      │
└────────────────────────────────────────────────┘
           ↓ POST /login/CheckOut
┌─ dalogin (proxy servlet) ──────────────────┐
│ CheckOut.doPost()                           │
│   → RequestFilter validates session         │
│   → ServiceClient adds headers (uuid, etc.) │
│   → Forwards to /mbooks-1/rest/book/payment/fullcheckout2
└────────────────────────────────────────────┘
           ↓ POST /mbooks-1/rest/book/payment/fullcheckout2
┌─ mbooks (BookController) ──────────────────┐
│ fullcheckout2() {                           │
│   1. Parse seatsToBeReserved JSON           │
│   2. TicketService.reserveTickets()         │
│      → DAO.bookTickets():                   │
│        a. For each seat: SELECT...FOR UPDATE│
│        b. Check if available (is_reserved="0")
│        c. If reserved: ROLLBACK → error    │
│        d. Create Purchase + Tickets         │
│        e. Mark seats is_reserved="1"        │
│   3. Calculate total + tax from tickets     │
│   4. PaymentService.getOrCreateCustomerId()│
│   5. PaymentService.processTransaction()    │
│      → Braintree gateway.transaction().sale()
│   6. If Braintree fails: rollback tickets   │
│   7. If success: refresh seats, return JSON│
│ }                                           │
└────────────────────────────────────────────┘
           ↓ HMAC-validated requests
┌─ MySQL (pessimistic lock) ─────────────────┐
│ LOCK seats[id] FOR UPDATE                  │
│ INSERT INTO ticket VALUES (...)            │
│ INSERT INTO purchase VALUES (...)          │
│ UPDATE seats SET is_reserved="1" WHERE...  │
│ COMMIT (or ROLLBACK on error)             │
└────────────────────────────────────────────┘
```

### Rollback Scenarios
- ✗ Seat already reserved → No insert, ROLLBACK
- ✗ Braintree declined → Delete tickets+purchase, mark seats available
- ✓ Success → Tickets visible in purchase history

## API Contracts (Immutable)

**Checkout payload (must not change):**
```json
POST /login/CheckOut
Content-Type: application/x-www-form-urlencoded

payment_method_nonce=<braintree_nonce>
&orderId=<currentTimeMillis>
&seatsToBeReserved={"seatsToBeReserved":[{"screeningDateId":"5","seat":"A1-B2-C3-"}]}
```

**Response (success):**
```json
{
  "authCode": "...",
  "status": "1",
  "amount": "25.00",
  "tickets": [
    { "ticketId": 123, "seat": "A1", "row": "A", "price": "12.50", "tax": "2.50" }
  ],
  "seatsforscreen": [
    { "seatId": 1, "row": "A", "number": "1", "reserved": "1" }
  ]
}
```

**Ticket cancellation payload:**
```json
POST /login/ManagePurchases
Content-Type: application/x-www-form-urlencoded

purchaseId=<id>
&ticketsToBeCancelled={"ticketIds":[42,43]}
```

**Header names (iOS ↔ Web must match exactly):**
- `X-Token` — session token
- `X-HMAC-HASH` — HMAC signature
- `X-MICRO-TIME` — timestamp
- `X-Device` — browser/device fingerprint
- `uuid` — session owner UUID
- `Ciphertext` — encrypted token2
- `XSRF-TOKEN` — cookie (encrypted)

## Hibernate & Caching

### Entity Fetch Strategies (Decision Tree)

**Should `@FetchType.EAGER`?**
```
├─ YES if:
│  └─ Entity is ALWAYS accessed with parent (e.g., Screen.movie)
│  └─ Eagerness prevents N+1 queries in hot path
│
└─ NO if:
   └─ Entity is rarely accessed (e.g., Movie.screens in list)
   └─ Entity collection is large (e.g., Screen.seats with 1000s)
   └─ Avoiding circular load (e.g., Seats ↔ Screen ↔ Seats)
```

**Example decisions:**
- ✅ `Screen.movie` — EAGER (needed for seat map display)
- ✅ `Screen.screeningDates` — EAGER (needed for ticket history)
- ✅ `Screen.seats` — EAGER (needed for seat map JSON assembly)
- ❌ `Movie.screens` — LAZY (loaded on-demand per movie selection)
- ❌ `Location.venues` — LAZY (venues fetched separately)
- ❌ `Seats` — NOT CACHEABLE (must be fresh for availability)

### L2 Cache Regions & Invalidation

| Region | Entities | When to Evict |
|--------|----------|---------------|
| `movies` | Movie | After admin adds/edits movie |
| `venues` | Venues | After admin adds/edits venue |
| `location` | Location | After admin adds/edits location |
| `ticket` | Ticket | After purchase or cancellation |

**Invalidation code:**
```java
Cache cache = sessionFactory.getCache();
cache.evictAll();  // Clear all L2 cache
// Or specific region:
cache.evict(Movie.class);
```

## Observability Stack

### Prometheus Metrics
- **Enabled in:** All four services (quarkus-micrometer-registry-prometheus)
- **Scrape endpoint:** `/q/metrics` (port 8080/8888/8085)
- **Scrape interval:** 15 seconds
- **Retention:** 7 days
- **Datasource in Grafana:** Auto-provisioned

**Custom metrics to track:**
- Booking success rate (`bookings.total` counter)
- Payment processing time (`payment.duration_ms` histogram)
- Seat lock contention (`seats.lock_wait_ms` gauge)

### Tempo Tracing
- **Protocol:** OTLP over gRPC (dalogin, simple-service-webapp) or HTTP (mbook, mbooks)
- **Export port:** 4317 (gRPC), 4318 (HTTP)
- **Service:** `grafana/tempo:2.7.2`
- **Configuration:** `application.properties` + K8s env vars

**Trace sampling (in K8s):**
```yaml
QUARKUS_OTEL_EXPORTER_OTLP_ENDPOINT: http://tempo:4318
QUARKUS_OTEL_ENABLED: "true"
```

### Grafana Dashboards
- **URL:** `https://milo.crabdance.com/grafana/`
- **Dashboard:** "Cinemas — Overview" (pre-provisioned)
- **12 panels:**
  - HTTP request rate per service
  - p95 latency per service
  - 5xx error rate per service
  - JVM heap % per service
  - Thread count per service
  - GC pause (ms) per service
  - MySQL queries/s
  - MySQL connections active
  - Slow queries (> 1 sec)
  - Uptime
  - InnoDB buffer pool hit %
  - Open tables

## Run Configurations (IntelliJ `.run/`)

| Config | Type | Command | Notes |
|--------|------|---------|-------|
| dalogin - package | Maven | `package -DskipTests -f dalogin-quarkus/` | |
| mbook - package | Maven | `package -DskipTests -f mbook-quarkus/` | |
| mbooks - package | Maven | `package -DskipTests -f mbooks-quarkus/` | |
| mbooks - quarkus:dev | Maven | `quarkus:dev -f mbooks-quarkus/` | Hot reload |
| simple-service-webapp - package | Maven | `package -DskipTests -f simple-service-webapp-quarkus/` | |
| appium - compile | Maven | `compile test-compile -f appium/` | Build classpath |
| appium - mvn test | Maven | `test -f appium/` | Surefire + testng.xml |
| appium - java direct (testng) | Shell | `mvn ... java ... TestNG testng.xml` | No exec plugin |
| appium - CreateXml GUI | Shell | `java ... qa.ios.util.CreateXml` | Swing GUI |
| k8s - test-login.py | Python | `k8infra/test-login.py` | API smoke test |
| k8s - test-login-admin.py | Python | `k8infra/test-login-admin.py` | Admin API test |
| ALL - package | Shell | Builds all 4 services | Sequential |
| ALL - docker build (minikube) | Shell | Docker build all images | Direct to Minikube |

## Debugging Checklist

| Symptom | Check |
|---------|-------|
| 401 Unauthorized | RequestFilter → session UUID extraction; AuthFilter registration in web.xml |
| 403 Forbidden | ActiveVoucherFilter → account activation status in DB |
| 500 NullPointerException | RequestFilter.getSessionUUID() returns null → session expired |
| Payment succeeds in iOS, fails in web | HMAC interceptor in app.js → returns data; Braintree SDK versions match |
| Seats show as available but can't book | L2 cache stale; call cache.evict(Seats.class) after booking |
| WebSocket not connecting | WebSocket ProxyPass comes **before** HTTP ProxyPass in Apache config |
| Slow queries | Check entity relationships → N+1 queries from EAGER loading of large collections |

---

**For more details, see:**
- AGENTS.md — comprehensive architecture, payment workflow, entity relationships
- k8infra/README-k8s-local.md — local deployment runbook
- docs/system-documentation.html — system diagrams, detailed flows

