# Copilot Instructions for Cinemas Project

## Overview
This is a **multi-service Quarkus-based cinema booking system** with an iOS client, web UI, and Kubernetes infrastructure. The project consists of four backend services, a MySQL database, and a comprehensive test suite using Appium for iOS automation.

## Key Tech Stack
- **Runtime:** Java 17, Quarkus 3.19.4
- **Frontend:** AngularJS 1.x (Film-Review SPA), iOS (SwiftCinemas)
- **Backend Services:** Quarkus services (dalogin, mbook, mbooks, simple-service-webapp)
- **Database:** MySQL 8, Kafka, Zookeeper
- **Observability:** Prometheus, Grafana, Tempo (OpenTelemetry)
- **Infrastructure:** Kubernetes (Minikube locally), Docker, Apache reverse proxy
- **Testing:** Appium 3, TestNG, Python pytest

## Critical Files & Directories

### Backend Services
| Service | Port | Root Path | Database | Primary File |
|---------|------|-----------|----------|--------------|
| `dalogin-quarkus` | 8080 | `/login` | `login_` | `CheckOut.java`, `HelloWorld.java` |
| `mbook-quarkus` | 8888 | `/mbook-1` | `login_` | `UserController.java` |
| `mbooks-quarkus` | 8080 | `/mbooks-1` | `book` | `BookController.java` |
| `simple-service-webapp` | 8085 | `/simple-service-webapp` | N/A | `ImageResource.java` |

### Documentation (Reference Before Editing)
- **Architecture & Design:** `.github/agents/AGENTS.md` (comprehensive system overview)
- **Local Deployment:** `k8infra/README-k8s-local.md` (step-by-step runbook)
- **System HTML Docs:** `docs/system-documentation.html`, `docs/appium-test-documentation.html`
- **iOS Client Docs:** `SwiftCinemas/swiftcinemas-documentation.html`

### Database
- `mysql_8/login.sql` — `login_` schema (users, devices, sessions, vouchers)
- `mysql_8/book.sql` — `book` schema (movies, venues, screens, tickets, purchases)
- Both are **self-contained** with triggers, stored procedures, and all fixes included

## When Working on Different Areas

### Payment/Booking Flow
Start in `mbooks-quarkus/src/main/java/com/jeet/rest/BookController.java` (1170 lines):
- Line 1–300: Movie browsing, venue selection, dates/seats
- Line 300–600: Seat reservation (`bookTickets()`, pessimistic locking)
- Line 600–1170: Braintree payment flow (`clientToken()`, `fullcheckout2()`, rollback logic)
- Supporting classes: `service/PaymentService.java`, `booking/TicketService.java`, `db/DAO.java`

**Payment Workflow (iOS + Web):**
```
GET /login/CheckOut → GET /mbooks-1/rest/book/payment/clientToken
POST /login/CheckOut → POST /mbooks-1/rest/book/payment/fullcheckout2
  ↓
[Pessimistic lock seats] → [Create Purchase] → [Braintree transaction]
  ↓ (failure) → Rollback: delete tickets+purchase, free seats
  ↓ (success) → Return tickets + updated seat map
```

### iOS Service Calls (SwiftCinemas Refactoring)
iOS client refactored to use modern async/await + centralized networking layer:
- `SwiftLoginScreen/Networking/APIClient.swift` — Main HTTP client (async/await, error handling, response caching)
- `SwiftLoginScreen/Networking/Endpoint.swift` — Request builder (path, method, query, body, cache key, absolute URL support)
- `SwiftLoginScreen/Networking/BackendServices.swift` — Service wrappers:
  - `MbooksService` — `/mbooks-1/rest/book` endpoints (movies, venues, seats, payment, admin)
  - `LoginGatewayService` — `/login` proxy servlets (login, checkout, purchases, activation)
  - `ImageResourceService` — Image downloads (absolute URL, optional caching)
  - `RapidMovieDatabaseService` — External IMDb API (RapidAPI)
- `SwiftLoginScreen/Networking/HeaderProvider.swift` — Protocol + implementations:
  - `SessionHeaderProvider` — Session headers (X-Token, Ciphertext, X-Device)
  - `HMACLoginHeaderProvider` — HMAC-SHA512 login headers (X-HMAC-HASH, X-MICRO-TIME)
  - `MinimalGETHeaderProvider` — No auth headers (for public/image requests)
  - `RapidMovieDatabaseHeaderProvider` — RapidAPI keys
- `SwiftLoginScreen/Networking/URLManager.swift` — Centralized URL configuration (baseHost, paths, builders)
- `SwiftLoginScreen/Networking/AppError.swift` — Standard error types (networkFailure, httpError, authRequired, decodingFailed)
- **Service injection pattern:** `AppDelegate` creates `AppServices` container → injected via `UIViewController` extension protocols (`HasAPIClient`, `HasAppServices`)

### Authentication & Session Management
Start in `dalogin-quarkus/src/main/java/com/dalogin/`:
- `filters/` — `CookieFilter.java`, `CiphertextFilter.java`, `AuthFilter.java`, `ActiveVoucherFilter.java`
- `servlets/HelloWorld.java` — HMAC login, password hashing
- `client/ServiceClient.java` — header injection for downstream services
- **Key headers:** `X-Token`, `Ciphertext`, `uuid`, `TIME_`, `XSRF-TOKEN`, `X-HMAC-HASH`, `X-Device`
- **Keep these header names exactly** — iOS client depends on them (see `HeaderProvider` implementations in iOS)

### Film-Review Booking UI (Web)
Edit in `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/`:
- `app.js` — AngularJS controllers, HMAC interceptor, login/auth state (683 lines)
- `templates/movies.html`, `venues.html`, `dates.html`, `checkout.html`, `purchases.html`
- `index.html` — SPA shell, Braintree SDK (JS 1.44.1), CSS inline
- **DO NOT change HTTP header names or checkout parameter names** — backend contracts are hardcoded

### iOS Tests (Appium)
Edit in `appium/src/test/java/`:
- `qa.ios.pages/` — Page Object classes for UI elements
- `qa.ios.test/TestNavigations.java` — Main test suite (Movies → Category → Venues → Seats → Checkout)
- `qa.ios.util/CreateXml.java` — Swing GUI for building TestNG suites
- Run via `.run/appium - mvn test` or `.run/appium - java direct (testng)` configs

### Database Queries & DAO
`mbooks-quarkus/src/main/java/com/jeet/db/DAO.java`:
- Uses **session-per-call** (not spring-data)
- Read methods: NOT `synchronized`
- Write methods: `synchronized`
- Uses **Hibernate L2 cache** — invalidate when mutating entities
- **DO NOT** change entity `FetchType` or `CascadeType` without reading the "Hibernate entity relationships" section in AGENTS.md

### Kubernetes & Deployment
Edit `k8infra/quarkus-backend.yaml` for local K8s manifests:
- Services: dalogin, mbook, mbooks, simple-service-webapp
- Infrastructure: MySQL, Kafka, Zookeeper, Apache, Prometheus, Tempo, Grafana
- All services export traces to Tempo; Prometheus scrapes metrics
- **Important:** WebSocket `ProxyPass` routes must come **before** HTTP routes in Apache config

## Hardcoded Values (Client-Visible Contracts)

**DO NOT change without coordinating iOS client updates:**

- Header names: `X-Token`, `uuid`, `token2`, `Ciphertext`, `TIME_`, `XSRF-TOKEN`, `X-HMAC-HASH`, `X-Device`
- HMAC algorithm: SHA-512 (same iOS ↔ Web)
- Checkout payload: `payment_method_nonce`, `orderId`, `seatsToBeReserved` (JSON with `seat` = numbers, not IDs)
- iOS base URL: `URLManager.baseHost` = `milo.crabdance.com` (can be overridden locally in `URLManager.swift`)
- Braintree SDK versions: JS 1.44.1, iOS 5.26.0, Java 3.36.0 (all use same Sandbox gateway)

## Run Configurations (IntelliJ `.run/` directory)

| Config | Type | What It Does |
|--------|------|--------------|
| `dalogin - package` | Maven | Builds dalogin JAR |
| `mbooks - quarkus:dev` | Maven | Runs mbooks in dev mode (live reload) |
| `appium - mvn test` | Maven | Runs iOS UI tests via Surefire |
| `appium - java direct (testng)` | Shell | Direct TestNG (bypasses exec-maven-plugin) |
| `appium - CreateXml GUI` | Shell | Launches Swing GUI for building test suites |
| `ALL - package (skip tests)` | Shell | Builds all 4 backend services |
| `k8s - test-login.py` | Python | Runs API smoke tests |

**All Maven configs use:** `myGeneralSettings` → `userSettingsFile` pointing to `k8infra/settings-local.xml` (proxy bypass).

## Common Edits Checklist

### Adding a new API endpoint
1. Create `@Path`, `@GET/@POST`, `@Produces/Consumes` in a `*Resource.java` class
2. If authenticated: add `@Context HttpServletRequest request` + call `RequestFilter.getSessionUUID(request)`
3. If using HMAC: add `@Context HttpHeaders headers` + verify `X-HMAC-HASH`
4. **Inject headers via ServiceClient** if calling downstream (dalogin proxy servlets already do this)
5. Return JSON: use `JSONObject` or DTO with Jackson (prefer DTO for new code)

### Fixing a bug in seat availability
1. **Read:** `DAO.getSeatsForScreening(screeningDateId)` (NOT query-cached, always fresh)
2. **Check:** `seat.isReserved` — values are string `"0"` or `"1"` (not boolean)
3. **Lock:** `PESSIMISTIC_WRITE` before checking (in `DAO.bookTickets()`)
4. **Invalidate cache:** After update, call `cache.evict()` on the Seat/Screen entities

### Adding a new test
1. **Unit tests:** `@QuarkusTest` + `@Inject` for CDI beans (mbook-quarkus has examples)
2. **Integration tests:** Testcontainers for MySQL if needed
3. **E2E tests:** Python API tests in `k8infra/` (no dependencies, stdlib-only)
4. **iOS UI tests:** Appium via `appium/` module

## Gotchas & Common Mistakes

1. **String comparison:** Use `.equals()`, not `==` — several filters had this bug
2. **Null cookies:** Always null-check `request.getCookies()` before iterating
3. **Seat numbers vs IDs:** Checkout uses `seat` = numbers (e.g., `"A1-B2-"`), not IDs
4. **HMAC token missing:** Web UI needs `/book/movies/paging` endpoint to get `APIKEY` header (or mark browse endpoints as public in interceptor)
5. **Circular entity references:** JSON serialization breaks with bidirectional `EAGER` relationships — manually assemble JSON or use `@JsonIgnore`
6. **WebSocket upgrade fails:** Make sure WebSocket `ProxyPass` comes **before** HTTP routes in Apache config
7. **L2 cache stale reads:** After mutating entities, invalidate cache regions (`movies`, `venues`, `location`, `ticket`)
8. **iOS URLs hardcoded:** Check `URLManager.swift` before changing any API paths

## Quick Deploy Commands

```bash
# Build all backend services
./mvnw -s k8infra/settings-local.xml package -DskipTests

# Build Docker images into Minikube
eval $(minikube docker-env)
docker build -t dalogin:local ./dalogin-quarkus
docker build -t mbook:local ./mbook-quarkus
docker build -t mbooks:local ./mbooks-quarkus
docker build -t simple-service-webapp:local ./simple-service-webapp-quarkus
eval $(minikube docker-env --unset)

# Deploy to Minikube
kubectl apply -f k8infra/quarkus-backend.yaml

# Tunnel for iOS simulator (keep running)
sudo minikube tunnel

# Verify WebSocket
curl -sk --http1.1 -o /dev/null -w "%{http_code}\n" \
  -H 'Upgrade: websocket' -H 'Connection: Upgrade' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  -H 'Sec-WebSocket-Version: 13' \
  https://milo.crabdance.com/mbook-1/ws
```

## When You're Stuck

1. **Can't find an entity or method?** → Search in AGENTS.md first
2. **Payment failing on web but works on iOS?** → Check `POST /login/CheckOut` parameters + HMAC interceptor + Braintree SDK version
3. **WebSocket not connecting?** → Check `sudo minikube tunnel` is running + WebSocket `ProxyPass` ordering in Apache
4. **Tests failing?** → Run `appium - mvn test` or `k8s - test-login.py` configs; check MySQL is seeded
5. **Session not found?** → Verify `AuthFilter` + `ActiveVoucherFilter` are registered in `web.xml`

---

**Always reference AGENTS.md before editing architecture/entity relationships.** If in doubt, ask or read the system-documentation.html.

