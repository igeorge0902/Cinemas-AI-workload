# Speckit Constitution: Cinemas Project

## Project Identity
**Cinemas** is a multi-service Quarkus-based cinema booking system with iOS client, web UI (AngularJS), and Kubernetes infrastructure. The system handles user authentication, seat reservation, Braintree payments, and real-time availability tracking.

## Technology Stack
- **Runtime:** Java 17, Quarkus 3.19.4
- **Frontend:** AngularJS 1.x (Film-Review SPA), iOS SwiftUI/AppKit
- **Backend Services:** 4 Quarkus microservices (dalogin, mbook, mbooks, simple-service-webapp)
- **Database:** MySQL 8 (dual schemas: `login_` for auth, `book` for cinema data)
- **Messaging:** Kafka 3.x, Zookeeper
- **Observability:** Prometheus 2.x, Grafana 10.x, Tempo (OpenTelemetry traces)
- **Container/Orchestration:** Docker, Kubernetes (Minikube locally)
- **API Gateway/Proxy:** Apache HTTP Server 2.4 (reverse proxy, SSL termination)
- **Testing:** XCTest/XCUITest, Appium 3.x + XCUITest driver + TestNG, Java Rest Assured API smoke tests, experimental Quarkus `@QuarkusTest` coverage
- **Payment Gateway:** Braintree Sandbox API (JS 1.44.1, iOS 5.26.0, Java 3.36.0)

## Critical Architecture Decisions

### 1. Dual Database Schemas
- **`login_` schema:** User credentials, authentication state, devices, sessions, vouchers
  - File: `mysql_8/login.sql`
  - Services: dalogin (primary), mbook/mbooks (queries via dalogin proxy)
  - Key tables: `user_`, `device_`, `session_login`, `voucher_`

- **`book` schema:** Cinema catalog, venue data, seat inventory, purchases
  - File: `mysql_8/book.sql`
  - Service: mbooks (direct access + pessimistic locking)
  - Key tables: `movie`, `venue`, `screen`, `screening_date`, `seat`, `ticket`, `purchase`

### 2. Pessimistic Locking for Seat Availability
- **Lock level:** `PESSIMISTIC_WRITE` on `Seat` entity during `bookTickets()`
- **Lock duration:** Transaction scope only (released after payment confirmation or rollback)
- **Cache invalidation:** After seat/purchase mutations, evict `ticket` cache region
- **Atomic operation flow:**
  ```
  BEGIN TRANSACTION
    → SELECT seats FOR UPDATE (acquire X-lock)
    → Verify availability (seat.isReserved == "0")
    → Create Ticket records
    → CREATE Purchase record
    → Call Braintree /transactions
    → IF payment fails: DELETE tickets+purchase, UPDATE seats.isReserved = "0"
    → IF payment succeeds: UPDATE seats.isReserved = "1", COMMIT
  END TRANSACTION
  ```

### 3. Microservice Communication Contracts
- **Service-to-service:** ServiceClient injects authentication headers (X-Token, X-HMAC-HASH)
- **Client-to-service:** Session-based (X-Token cookie) OR HMAC-based (X-HMAC-HASH header)
- **Header injection:** dalogin acts as auth gateway; downstream services read pre-authenticated headers
- **Cross-origin:** Apache ProxyPass preserves headers; CORS headers include `Access-Control-Expose-Headers: X-Token`

### 4. Payment Workflow (iOS + Web)
```
[Client Login] → Session established (X-Token cookie)
  ↓
GET /login/CheckOut → Redirects to GET /mbooks-1/rest/book/payment/clientToken
  ↓ (GET successful)
POST /login/CheckOut (payment_method_nonce, orderId, seatsToBeReserved)
  ↓
dalogin proxy → POST /mbooks-1/rest/book/payment/fullcheckout2
  ↓
[Pessimistic lock seats] → [Create Purchase] → [Braintree transaction]
  ↓ (failure)
Rollback: DELETE tickets+purchase, UPDATE seat.isReserved="0"
  ↓ (success)
Return: { tickets: [...], seatMap: {...}, transactionId: "..." }
```

### 5. iOS Service Refactoring (Async/Await Pattern)
Modern async/await + centralized networking layer replaced callback-based implementation:
- **APIClient:** Main HTTP transport (request/response handling, caching, retry logic)
- **Endpoint:** Request descriptor (path, method, query, body, cache key, absolute URL)
- **BackendServices:** Service wrappers (MbooksService, LoginGatewayService, ImageResourceService, RapidMovieDatabaseService)
- **HeaderProvider protocol:** Multiple implementations for different auth schemes:
  - `SessionHeaderProvider` — Session cookies (X-Token, Ciphertext, X-Device)
  - `HMACLoginHeaderProvider` — HMAC-SHA512 (X-HMAC-HASH, X-MICRO-TIME, uuid)
  - `MinimalGETHeaderProvider` — No auth (public/image endpoints)
  - `RapidMovieDatabaseHeaderProvider` — External API keys

## Hardcoded Client-Visible Contracts

**DO NOT change without coordinating across iOS + Web clients:**

### HTTP Headers (All Services)
| Header | Value | Set By | Used By | Mutable? |
|--------|-------|--------|---------|----------|
| `X-Token` | Session token (string) | dalogin | All services | No |
| `Ciphertext` | Encrypted request body | iOS client | dalogin, mbooks | No |
| `uuid` | Device UUID | Client | dalogin, mbooks | No |
| `X-Device` | Device identifier | Client | mbooks (seat locks) | No |
| `TIME_` | Client timestamp | Client | dalogin (HMAC) | No |
| `X-HMAC-HASH` | HMAC-SHA512(body + secret) | Client | dalogin, mbooks | No |
| `XSRF-TOKEN` | CSRF protection | dalogin | Client (echoed back) | No |
| `X-Forwarded-For` | Client IP (via Apache) | Apache | All services | No |
| `APIKEY` | Braintree key (response header) | mbooks | Client (cached) | No |

### Payment Checkout Payload (EXACT format required)
```json
{
  "payment_method_nonce": "nonce_from_braintree_js",
  "orderId": "booking_reference",
  "seatsToBeReserved": "A1-B2-C3-"
}
```
- `seatsToBeReserved`: Concatenated seat numbers (e.g., `"A1-B2-"`), NOT seat IDs
- Encoding: Must match HTTP POST body encoding (form-urlencoded or JSON depending on client)
- Order: Preserve exact key order for HMAC calculation

### API Endpoints (Non-negotiable)
| Endpoint | Method | Port | Returns | Notes |
|----------|--------|------|---------|-------|
| `/login/HelloWorld` | POST | 8080 | `{ token: "...", uuid: "..." }` | HMAC login |
| `/login/CheckOut` | GET/POST | 8080 | Redirects to mbooks payment flow | Gateway servlet |
| `/mbooks-1/rest/book/movies` | GET | 8080 | `{ movies: [...] }` | Paged, cached |
| `/mbooks-1/rest/book/payment/clientToken` | GET | 8080 | `{ clientToken: "...", APIKEY: "..." }` | Braintree setup |
| `/mbooks-1/rest/book/payment/fullcheckout2` | POST | 8080 | `{ status: "...", tickets: [...], seatMap: {...} }` | Payment execution |
| `/mbooks-1/ws` | WebSocket | 8080 | Real-time seat updates | Via Apache ProxyPass |
| `/simple-service-webapp/rest/images/*` | GET | 8085 | Binary image data | Cache-friendly headers |

### Braintree SDK Versions (Sandbox Only)
- **JavaScript:** 1.44.1 (via CDN in index.html)
- **iOS:** 5.26.0 (via CocoaPods)
- **Java/Quarkus:** 3.36.0 (via Maven pom.xml)
- **Merchant ID:** `j3ndqpzrhy4gp2p7`
- **Public Key:** Available in Braintree dashboard
- **All endpoints:** https://sandbox.braintreegateway.com/

### HMAC Algorithm & Signature
- **Algorithm:** SHA-512
- **Input:** Concatenate (request body + client-side secret)
- **Header:** `X-HMAC-HASH: base64(hmac_sha512_bytes)`
- **Timing:** Included in login request; verified by dalogin for all authenticated calls

## File Navigation Map

### Backend Services
| Service | Location | Port | Primary Classes | Database |
|---------|----------|------|-----------------|----------|
| **dalogin** | `dalogin-quarkus/` | 8080 | `HelloWorld.java`, `CookieFilter.java`, `AuthFilter.java` | `login_` |
| **mbook** | `mbook-quarkus/` | 8888 | `UserController.java` | `login_` (read-only proxy) |
| **mbooks** | `mbooks-quarkus/` | 8080 | `BookController.java`, `PaymentService.java` | `book` |
| **simple-service-webapp** | `simple-service-webapp-quarkus/` | 8085 | `ImageResource.java` | N/A (serves files) |

### Web UI
- Location: `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/`
- Root: `index.html` (AngularJS SPA shell)
- Controllers: `app.js` (683 lines, HMAC interceptor, checkout flow)
- Templates: `movies.html`, `venues.html`, `dates.html`, `checkout.html`, `purchases.html`
- CSS: Inline in `index.html` (light/dark theme toggle)

### iOS Client
- Location: `SwiftCinemas/`
- Networking Layer: `SwiftLoginScreen/Networking/` (APIClient, Endpoint, BackendServices, HeaderProvider, URLManager)
- Views: `SwiftLoginScreen/Views/` (MovieListView, VenueSelectionView, SeatMapView, CheckoutView)
- Models: `SwiftLoginScreen/Models/` (Movie, Venue, Seat, Purchase, AppError)

### Database Initialization
- `mysql_8/login.sql` — User schema with triggers for session management
- `mysql_8/book.sql` — Cinema schema with stored procedures for availability queries

### Test Suites
| Framework | Location | Config | Command |
|-----------|----------|--------|---------|
| **XCUITest (iOS)** | `SwiftCinemas/` | `SwiftCinemasTests/SwiftCinemas.xctestplan` | Run via Xcode test plan / IDE test runner |
| **Appium (iOS)** | `appium/src/test/java/` | `.run/appium - mvn test` | `mvn test -f appium/pom.xml -s k8infra/settings-local.xml` |
| **Rest Assured API smoke** | `k8infra/api-smoke-restassured/` | Maven module + module README | `mvn test -f k8infra/api-smoke-restassured/pom.xml` |
| **Quarkus framework tests (experimental)** | `dalogin-quarkus/src/test/java/`, `mbooks-quarkus/src/test/java/`, `simple-service-webapp-quarkus/src/test/java/` | JUnit 5 + `@QuarkusTest` | Run via service Maven module / IDE test runner |

## Key Code Patterns

Implementation templates and copy-paste snippets are intentionally **not duplicated** in this constitution.
Use these canonical sources instead:
- `.ai/skills/skills-github.md` — reusable coding patterns (REST, auth, payment, WebSocket, tests, deployment helpers)
- `.ai/retrieval/instructions.md` — operational routing (where to edit, quick checks, gotchas)
- `.ai/agents/AGENTS.md` — architecture deep-dive and immutable service contracts

## Common Failure Modes

### Payment fails on Web, succeeds on iOS
1. ✅ Check `POST /login/CheckOut` parameters match exactly (seatsToBeReserved format)
2. ✅ Verify HMAC interceptor in web UI includes Authorization header in HMAC calculation
3. ✅ Compare Braintree SDK versions (JS 1.44.1 must match backend expectation)
4. ✅ Check Apache ProxyPass doesn't strip Content-Type header

### WebSocket disconnects after seat selection
1. ✅ Verify `sudo minikube tunnel` is running
2. ✅ Check WebSocket `ProxyPass` comes **before** HTTP routes in Apache config
3. ✅ Confirm Sec-WebSocket-Key header is present in browser dev tools
4. ✅ Check Quarkus WebSocket endpoint is registered (see mbook-quarkus pom.xml)

### Session not found after login
1. ✅ Verify `CookieFilter` is registered in `web.xml` (before `AuthFilter`)
2. ✅ Check cookie domain matches request origin (localhost vs 127.0.0.1)
3. ✅ Confirm `ActiveVoucherFilter` runs after `CookieFilter`
4. ✅ Validate session is stored in MySQL `session_login` table

### Seat availability stale after purchase
1. ✅ Confirm `DAO.getSeatsForScreening()` is NOT using Hibernate query cache
2. ✅ Verify L2 cache is evicted after seat mutation (`cache.evictRegion("ticket")`)
3. ✅ Check `FetchType.EAGER` on bidirectional relationships (can cause cache confusion)

### Images not loading on iOS
1. ✅ Verify `simple-service-webapp` is deployed and responding on port 8085
2. ✅ Check `URLManager.swift` correctly resolves image URLs (should use absolute path)
3. ✅ Confirm Apache `ProxyPass` includes `/simple-service-webapp` route
4. ✅ Verify PVC for image storage is mounted (check `k8infra/quarkus-backend.yaml`)

## Review Protocol (Quarkus + SwiftCinemas)

Use this review protocol before implementing UI redesign work or migration-heavy changes.

### Scope
- Quarkus backend apps:
  - `dalogin-quarkus`
  - `mbook-quarkus`
  - `mbooks-quarkus`
  - `simple-service-webapp-quarkus`
- iOS app:
  - `SwiftCinemas/SwiftLoginScreen`

### Review intent
- Confirm redesign work does not break immutable client-visible contracts.
- Confirm endpoint/data mapping assumptions used by Swift screens still match backend payloads.
- Keep existing storyboard/segue behavior stable while changing visual hierarchy.

### Quarkus backend review checklist
- Contract safety:
  - Header names remain exact (`X-Token`, `X-HMAC-HASH`, `Ciphertext`, `uuid`, `TIME_`, `XSRF-TOKEN`, `X-Device`).
  - Checkout payload keys remain exact (`payment_method_nonce`, `orderId`, `seatsToBeReserved`).
- Endpoint compatibility:
  - Verify paths used by iOS `BackendServices` still exist and response keys are unchanged.
  - For venue/movie/date/seat flows, confirm JSON keys consumed by DataManagers are still present.
- Concurrency/data integrity:
  - Preserve seat lock + rollback semantics in payment path.
  - Do not alter `seat.isReserved` string semantics (`"0"`/`"1"`) without coordinated migration.
- Observability/runtime parity:
  - Keep OpenTelemetry + Prometheus dependencies/config active in all four services.

### SwiftCinemas app review checklist
- Navigation safety:
  - Keep storyboard segue identifiers and destination handoff contracts unchanged.
  - Keep map/admin/standard mode branching behavior unchanged.
- DataManager safety:
  - Verify selected context propagation (`selectedMovie`, `selectedVenue`, `selectedLocationId`, screening/date/seat context).
  - Ensure redesign changes do not reintroduce direct network calls in VCs.
- UI redesign boundary:
  - Redesign should be layout/style/state presentation only, unless behavior change is explicitly requested.
  - Keep async loading and existing error surfaces non-blocking.

### Review output format
- Findings first, ordered by severity.
- Include file path + line references for each finding.
- Classify each item as one of:
  - `confirmed defect`
  - `conditional risk`
  - `accepted design choice`

### Current baseline note
- This protocol is based on repository-level inspection and intended as a pre-implementation guardrail.
- Runtime behavior confirmation should come from targeted smoke/E2E checks in the active environment.

## Observability, deployment, and IDE execution

This constitution intentionally keeps only durable system principles.
For operational procedures and command catalogs, use:
- `k8infra/README-k8s-local.md` — deployment, image build/load, TLS, tunnel, verification
- `k8infra/quarkus-backend.yaml` — canonical observability stack wiring (Prometheus, Tempo, Grafana)
- `.ai/retrieval/instructions.md` — day-to-day quick reminders
- `.run/` + `.ai/agents/AGENTS.md` — run configuration inventory

## References for Further Reading

| Topic | File | Lines |
|-------|------|-------|
| System architecture | `.ai/retrieval/instructions.md` | All |
| **Copy-paste code patterns** | **`.ai/skills/skills-github.md`** | **All (16 patterns)** |
| Entity relationships | `.ai/agents/AGENTS.md` | (todo) |
| Kubernetes setup | `k8infra/README-k8s-local.md` | All |
| Appium test guide | `appium/README.md` | All |
| Backend API docs | `k8infra/system-documentation.html` | All |

---

**Last Updated:** May 16, 2026
**Maintained By:** Development Team
**Status:** Active — All services production-ready in Minikube

