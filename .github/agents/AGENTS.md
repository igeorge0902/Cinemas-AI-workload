# AGENTS.md

## Technology versions
- **Java 17** — all backend services and the Appium test suite.
- **Quarkus 3.19.4** — all four backend services (`quarkus-bom` version in each `pom.xml`).
- **Infinispan 15.0.10.Final** — L2 cache provider for `mbook-quarkus` and `mbooks-quarkus`.
- **Appium 3** (3.2.2) + XCUITest driver 10.32.1 + Java Client 9.3.0 + Selenium 4.27.0 + TestNG 7.10.2.
- **iOS target**: iPhone 16 Pro / iOS 26.1 (Appium pom defaults; override via `-Dsim.device`, `-Dsim.version`).

## Workspace map
- `dalogin-quarkus/`: Quarkus login gateway using servlet-style code (`quarkus-undertow`, `web.xml`), served under `/login`. Static HTML/JS UI lives in `src/main/resources/META-INF/resources/` (migrated from the original WildFly-era `WebContent/` folder with `.jsp` references rewritten to `.html`). Includes the **Film-Review Booking UI** at `film-review/` — an AngularJS SPA using the Film-Review Movie Database template for the full booking flow (movies → venues → dates/seats → checkout → purchases/tickets). The `ServiceClient` + proxy servlets (`CheckOut`, `GetAllPurchases`, `ManagePurchases`) bridge the web UI to `mbooks-quarkus` via session-authenticated requests; the `Purchases` JAX-RS client interface (`com.dalogin.client.service.Purchases`) defines the downstream API contracts.
- `Film-Review-Movie-Database/`: source HTML template files for the Film-Review dark cinema theme. Assets copied to `dalogin-quarkus/.../film-review/css/`, `js/`, `images/`.
- `mbook-quarkus/`: user/device/support API on port `8888`, root path `/mbook-1`, backed by MySQL schema `login_`.
- `mbooks-quarkus/`: movie/booking/payment API on port `8080`, root path `/mbooks-1`, backed by MySQL schema `book`.
- `simple-service-webapp-quarkus/`: image-serving API on port `8085`, root path `/simple-service-webapp`, serves pictures from the `pictures/` folder (movies, venues, profiles, general images).
- `pictures/`: shared image assets (movie posters, venue photos, profile pictures) served by `simple-service-webapp-quarkus`.
- `SwiftCinemas/`: iOS client (`SwiftLoginScreen`, `SwiftCinemas`) that still targets `milo.crabdance.com` by default.
- `appium/`: Appium 3 + XCUITest + TestNG test suite for automated iOS UI testing. Requires a running backend (see `appium/README.md`). Page-object classes live in `src/main/java/qa/ios/`, tests in `src/test/java/`. A second test class `InspectUI` (run via `testng-inspect.xml`) dumps page-source XML for UI element debugging. Includes a `CreateXml` Swing GUI (`qa.ios.util.CreateXml`) for building TestNG XML suites interactively. **No `mvnw` wrapper** — uses system `mvn`. Run via IntelliJ run configurations (see `.run/` directory) or `mvn test -f appium/pom.xml`.
- `k8infra/quarkus-backend.yaml`: current local Kubernetes manifest for the Quarkus stack; `k8infra/kubernetes.yaml` is the legacy WildFly-era topology reference.
- `k8infra/README-k8s-local.md`: step-by-step local deployment runbook (Minikube + Podman build + DB seed + TLS + iOS simulator networking). This is the canonical "how to run everything locally" guide.
- `k8infra/test-login.py`, `k8infra/test-login-admin.py`: Python end-to-end API smoke tests (stdlib-only, no pip). Reproduce the iOS HMAC-SHA512 handshake and verify login → user profile → mbooks flow over HTTPS. Run with `python3 k8infra/test-login.py`.
- `k8infra/settings-local.xml`: Maven settings for proxy-free builds (forces HTTPS Central repo). Use with `./mvnw -s ../k8infra/settings-local.xml` if behind a corporate proxy that strips Maven Central access.
- `k8infra/mysql_8/`, `k8infra/pictures/`: copies of the root-level `mysql_8/` and `pictures/` directories bundled inside the `k8infra` repo for self-contained deployment.
- `mysql_8/login.sql`: consolidated schema, seed data, triggers, and stored procedures for the `login_` database. Self-contained — all trigger casing, `login_.` table references, operator-precedence fixes, and the `profilePicture` column are included. No further fix scripts are needed.
- `mysql_8/book.sql`: schema + seed data for the `book` database (movies, venues, screens, tickets). Self-contained.
- `docs/system-documentation.html`: comprehensive system documentation with inline SVG diagrams (architecture, auth/booking/registration flows, entity relationships, Hibernate caching deep-dive, iOS client, refactoring suggestions). Also mirrored at `k8infra/system-documentation.html`.
- `docs/swiftcinemas-documentation.html`: iOS client documentation (also mirrored at `SwiftCinemas/swiftcinemas-documentation.html`).
- `docs/appium-test-documentation.html`: Appium test suite documentation (also mirrored at `appium/appium-test-documentation.html`).
- `docs/appium-test-fix-plan.md`: known issues and fix plan for the Appium tests (also mirrored at `appium/appium-test-fix-plan.md`).
- `.run/`: shared IntelliJ IDEA run configurations (version-controlled). See [IDE run configurations](#ide-run-configurations) for the full catalogue.

## Big picture first
- Request flow is `iOS/Web -> NGINX Ingress (TLS) -> Apache reverse proxy -> dalogin/mbook/mbooks/simple-service-webapp`; Apache is app routing inside Kubernetes, not a corporate proxy.
- `dalogin` is the session/auth gateway. Start in `src/main/java/com/dalogin/filters/`, `.../servlets/`, and `com/dalogin/client/ServiceClient.java`.
- `ServiceClient` forwards session-derived headers (`uuid`, `token2`, `TIME_`, cookies) to downstream APIs; preserve these names exactly.
- `SystemConstants.getServiceUrl()` reads env var `WILDFLY_URL`; in the Quarkus/K8s deployment it points to the Apache reverse-proxy service (`http://apache`, port 80). The env-var name is historical.
- Booking behavior is concentrated in `mbooks-quarkus/src/main/java/com/jeet/rest/BookController.java`; expect large controller methods and manual JSON assembly.
- Realtime behavior is Kafka consumer -> WebSocket broadcast in both services (`com.jeet.broadcasting.KafkaListener` + `WebSocketServer`). WebSocket servers set `maxIdleTimeout(0)` and handle `@OnMessage` pong frames; iOS client sends a ping every 30 seconds.

## Project-specific patterns
- Security is custom, not framework-default: filters such as `CookieFilter` and `CiphertextFilter` depend on `TIME_`, `token2`, `Ciphertext`, and `XSRF-TOKEN`.
- `mbooks-quarkus` uses singleton-style persistence (`DAO.instance()` + `HibernateUtil`), not CDI repositories. DAO methods use session-per-call (`factory.openSession()` in try-with-resources); read-only methods are not `synchronized`, write methods are.
- `mbook-quarkus` uses CDI-injected Hibernate session access (`com.jeet.db.DAO`) and often signals "not found" with sentinel entities (`id == 0`).
- Hardcoded paths/header names are client-visible contracts; avoid "cleanup" changes unless you also update the iOS client.
- iOS base URLs are centralised in `SwiftCinemas/SwiftLoginScreen/URLManager.swift` (`baseHost`, `baseURL`, `webSocketURL`, and path builders `login()`, `mbooks()`, `image()`). The former global `serverURL` in `GeneralRequestManager.swift` has been removed; all call sites use `URLManager` directly. Self-signed hosts in `CustomURLSessionDelegate` derive from `URLManager.baseHost`.
- The front-end UI is AngularJS 1.x (original Linear template from `WebContent/`). Quarkus cannot render `.jsp` files; all JSP references have been rewritten to `.html` equivalents (e.g. `index.jsp` → `index.html`, `tabularasa.jsp` → `tabularasa.html`). The canonical source is now `dalogin-quarkus/src/main/resources/META-INF/resources/`.
- **OpenTelemetry** is wired into all four backend services (`quarkus-opentelemetry` dependency + `okhttp` 4.12.0). Tracing is configured in `application.properties` (OTLP exporter). `dalogin` and `simple-service-webapp` use `http/protobuf` protocol (port 4318); `mbook` and `mbooks` use `grpc` (port 4317). In Kubernetes, all services export traces to **Grafana Tempo** (`grafana/tempo:2.7.2`); **Grafana** (`grafana/grafana:11.6.0`) provides the UI at `https://milo.crabdance.com/grafana/` with auto-provisioned Tempo datasource, node graphs, and service maps. To disable tracing on a service, set `QUARKUS_OTEL_ENABLED=false`.
- **Prometheus metrics** — all four backend services include `quarkus-micrometer-registry-prometheus` and expose Prometheus-format metrics at `/q/metrics`. **Prometheus** (`prom/prometheus:v3.2.1`) scrapes all four services and the MySQL exporter on a 15 s interval (7-day retention). **mysqld-exporter** (`prom/mysqld-exporter:v0.16.0`) runs as a sidecar in the MySQL pod, exposing MySQL server metrics on port 9104. Grafana has Prometheus as its default datasource and a pre-provisioned **"Cinemas — Overview"** dashboard with 12 panels: HTTP request rate, p95 latency, 5xx errors (per service); JVM heap, threads, GC pause (per service); MySQL queries/s, connections, slow queries, uptime, InnoDB buffer pool hit rate, open tables.

## Film-Review Booking UI

### Overview
A dark-themed AngularJS 1.x SPA at `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/`. Uses the Film-Review Movie Database CSS/JS template. Accessible at `https://milo.crabdance.com/login/film-review/`.

### File structure
| File | Purpose |
|------|---------|
| `index.html` | SPA shell — header/footer, CSS (inline), Braintree Drop-in SDK, AngularJS + ngRoute + CryptoJS includes |
| `app.js` | All controllers, HMAC interceptor, route config, login/auth state (~683 lines) |
| `templates/movies.html` | Movie grid with search, poster images from `simple-service-webapp` |
| `templates/venues.html` | Location selection for a chosen movie |
| `templates/venues-list.html` | Browse all cinema locations |
| `templates/venue-movies.html` | Movies screening at a selected venue |
| `templates/dates.html` | Date picker + interactive seat map with multi-select |
| `templates/checkout.html` | Braintree Drop-in payment form, order summary, login notice |
| `templates/login.html` | In-app HMAC login form (SHA3-512 password hashing, same flow as `/login/` page) |
| `templates/purchases.html` | Purchase history list with delete action |
| `templates/purchase-detail.html` | Tickets for a purchase with multi-select cancellation |

### Routes (hashbang mode)
| Hash path | Controller | Template | API endpoint |
|-----------|-----------|----------|--------------|
| `#!/` | `MoviesController` | `movies.html` | `GET /mbooks-1/rest/book/movies` (public) |
| `#!/venues-list` | `VenuesListController` | `venues-list.html` | `GET /mbooks-1/rest/book/locations` (public) |
| `#!/venue-movies/:locationId` | `VenueMoviesController` | `venue-movies.html` | `GET /mbooks-1/rest/book/venue/movies?locationId=X` (public) |
| `#!/venues/:movieId` | `VenuesController` | `venues.html` | `GET /mbooks-1/rest/book/venue/v2/:movieId` (HMAC) |
| `#!/dates/:locationId/:movieId` | `DatesSeatsController` | `dates.html` | `GET /mbooks-1/rest/book/dates/:lid/:mid` → `GET /mbooks-1/rest/book/seats/:sdId` (HMAC) |
| `#!/checkout` | `CheckoutController` | `checkout.html` | `GET /login/CheckOut` → `POST /login/CheckOut` (session) |
| `#!/purchases` | `PurchasesController` | `purchases.html` | `GET /login/GetAllPurchases` (session) |
| `#!/purchases/:purchaseId` | `PurchaseDetailController` | `purchase-detail.html` | `GET /login/ManagePurchases?purchaseId=X` (session) |
| `#!/login` | `LoginController` | `login.html` | `POST /login/HelloWorld` (HMAC login) |

### HMAC interceptor (`app.js`)
Every outgoing `$http` request goes through a `transformRequest` that computes `X-HMAC-HASH`, `X-MICRO-TIME`, `X-Device` headers using CryptoJS HMAC-SHA512 (same algorithm as the iOS client). Public endpoints (movies list, locations, venue/movies) and dalogin proxy URLs (`/login/*`) skip the `sessionToken_` requirement. The token is acquired from the `APIKEY` response header on the initial `/movies` call and stored in `localStorage.sessionToken_`.

### Global auth state (`app.js`)
The `app.run()` block manages `$rootScope.isLoggedIn` and `$rootScope.loggedInUser`, shared across all controllers. On startup, if `localStorage.filmReviewUser` is set, it probes `/login/GetAllPurchases` to verify the session is still valid. `$rootScope.logout()` calls `GET /login/logout` and clears local state. The header nav bar shows conditional Login/Sign Up links (when logged out) or username/Log Out (when logged in).

### In-app login (`LoginController`)
The `#!/login` route provides a login form within the Film-Review SPA, bypassing the need to redirect to `/login/`. It performs the same HMAC-SHA512 handshake as the original `/login/` page:
1. SHA3-512 hash of the password (CryptoJS, `sha3.js` loaded in `index.html`)
2. HMAC-SHA512 secret from `HmacSHA512(username, encodeURIComponent(passHash))`
3. Browser fingerprint as `deviceId` (same `guid()` function as the HMAC interceptor)
4. `POST /login/HelloWorld` with custom `transformRequest` (bypasses the Film-Review HMAC transform — the login has its own HMAC formula)
5. On success, stores `X-Token` in `localStorage.sessionToken_` and username in `localStorage.filmReviewUser`

### Proxy servlet flow (authenticated actions)
Checkout, purchases, and ticket management go through dalogin proxy servlets, NOT directly to mbooks:
```
Browser → /login/CheckOut        → CheckOut.java     → ServiceClient → /mbooks-1/rest/book/payment/clientToken (GET)
                                                                      → /mbooks-1/rest/book/payment/fullcheckout2 (POST)
Browser → /login/GetAllPurchases → GetAllPurchases.java → ServiceClient → /mbooks-1/rest/book/purchases (GET)
Browser → /login/ManagePurchases → ManagePurchases.java → ServiceClient → /mbooks-1/rest/book/purchases/tickets (GET)
                                                                        → /mbooks-1/rest/book/managepurchases (POST, cancel tickets)
                                                                        → /mbooks-1/rest/book/deletepurchases (POST, delete purchase)
```
These servlets are protected by `AuthFilter` (valid session + XSRF-TOKEN cookie) and `ActiveVoucherFilter`. Both iOS and the web UI use this proxy path (iOS: `URLManager.login("/CheckOut")`, web: `/login/CheckOut`). The user must log in (via `/login/` or the in-app `#!/login` route) before using checkout or purchase management.

### iOS ↔ Web payload contracts
The web UI payloads are aligned with the working iOS client (`SwiftCinemas/`). No backend changes required.

#### Checkout (`POST /login/CheckOut` → `fullcheckout2`)
```
payment_method_nonce=<braintree_nonce>&orderId=<currentTimeMillis>&seatsToBeReserved=<json>
```
Where `seatsToBeReserved` JSON structure (same as iOS `BasketVC.swift`):
```json
{"seatsToBeReserved":[{"screeningDateId":"5","seat":"A1-B2-C3-"}]}
```
- `seat` contains **seat numbers** (e.g. `"A1"`) NOT seat IDs — backend `DAO.bookTickets()` queries by `seatNumber`.
- Trailing dash after last seat number (iOS convention, harmless — Java `split("-")` ignores it).
- `screeningDateId` is a string value; `JSONObject.getInt()` parses both `"5"` and `5`.
- `orderId` is current time in millis (iOS: `zeroTime(0).getCurrentMillis()`).

#### Cancel tickets (`POST /login/ManagePurchases` with `ticketsToBeCancelled`)
```
purchaseId=<id>&ticketsToBeCancelled={"ticketIds":[42,43]}
```
Same as iOS `TicketsVC.swift` — JSON with `ticketIds` integer array.

#### Delete purchase (`POST /login/ManagePurchases` without `ticketsToBeCancelled`)
```
purchaseId=<id>
```
Same as iOS `PurchasesVC.swift` swipe-to-delete. `ManagePurchases` servlet dispatches to `ServiceClient.deletePurchases()` when `ticketsToBeCancelled` param is absent.

#### Get tickets (`GET /login/ManagePurchases?purchaseId=X`)
Same as iOS `TicketsVC.swift` — response: `{"tickets":[{ticketId, price, tax, seats_seatNumber, seats_seatRow, movie_name, venue_name, screening_date, movie_picture, ...}]}`.

### Bug fixes applied
- **`RequestFilter.java`**: Fixed NPE when `request.getCookies()` returns `null` (no cookies) — added null guard.
- **`Purchases.java`**: Fixed `deletePurchases()` `@Consumes` from `APPLICATION_JSON` to `APPLICATION_FORM_URLENCODED` to match the backend endpoint.
- **Checkout payload**: Fixed `seatsToBeReserved` to use seat numbers (not IDs), added trailing dash, send `screeningDateId` as string, use timestamp as `orderId` — all matching iOS client.
- **HMAC interceptor token gate**: The `/book/movies` endpoint does NOT return the `APIKEY` header (only `/book/movies/paging` does), so `localStorage.sessionToken_` was never set — causing the interceptor to reject all non-public requests. Fixed by marking venue, dates, and seats browse endpoints as public in the interceptor. The backend `CookieFilter`/`CiphertextFilter` only enforce auth on paths containing `purchases` or `payment`, so these browse endpoints don't need a session token.
- **Date selector**: Replaced `ng-repeat` inside `<select>` with `ng-options` — the `ng-repeat` + `value="{{...}}"` pattern is a known AngularJS 1.x issue where the model binding fails due to async digest timing. Added `date:'yyyy-MM-dd HH:mm'` filter for readable screening date display.
- **Venue-movies navigation**: Changed `venue-movies.html` click handler from `go('/venues/' + movie.movieId)` (which forced re-selecting a venue) to `go('/dates/' + locationId + '/' + movie.movieId)` — navigates directly to dates/seats since the location is already known.
- **Browser compatibility**: Fixed `navigator.mimeTypes` and `navigator.plugins` access in HMAC `guid()` function — these deprecated APIs may be undefined in modern browsers, causing a TypeError that silently breaks all `$http` requests.
- **HMAC `transformRequest` missing `return data`**: The pushed `transformRequest` function that adds HMAC headers did not return `data`, so AngularJS replaced every POST body with `undefined`. All POST operations (checkout, ticket cancellation, purchase deletion) arrived at the servlet with empty parameters. GET requests were unaffected (no body to lose). iOS was unaffected (native `URLSession`, not AngularJS). Fixed by adding `return data;` at the end of the transform.
- **Braintree Drop-in JS SDK**: Updated from 1.43.0 to 1.44.1 (latest). The JS SDK, iOS SDK (`Braintree` 5.26.0 / `BraintreeDropIn` 9.13.0), and backend Java SDK (`braintree-java` 3.36.0) all use the same Braintree Sandbox gateway — versions are cross-compatible.

## Hibernate entity relationships (mbooks-quarkus `book` schema)

### Entity graph overview
```
Movie (1) ──LAZY──< (N) Screen (1) ──EAGER──> (1) ScreeningDates
                         │                              │
                         │EAGER                         │EAGER
                         ▼                              ▼
                    (N) Seats                      (1) Venues ──EAGER──> (1) Location
                         │                              │
                         │EAGER                         │EAGER (via Screen)
                         ▼                              ▼
                    (N) Ticket ──LAZY──> (N) Purchase   Location (1) ──LAZY──< (N) Venues
```

### Fetch strategy per relationship (as annotated on entities)

| Owner Entity     | Relationship        | Target Entity   | Fetch   | Cascade                      | Notes / Refactoring Impact |
|------------------|---------------------|-----------------|---------|------------------------------|---------------------------|
| `Movie`          | `@OneToMany screens` | `Screen`       | **LAZY** | none                        | Movie browsing (list/search) does NOT load screens. Screens loaded on-demand when user picks a movie. Safe for pagination. |
| `Screen`         | `@ManyToOne movie`  | `Movie`         | **EAGER** | PERSIST, REFRESH             | Loading a screen always loads its movie. This powers the `getAllPurchases` ticket→screen→movie navigation. |
| `Screen`         | `@OneToOne screeningDates` | `ScreeningDates` | **EAGER** | ALL                    | Loading a screen always loads its screening date. Needed for venue/date display on seat maps and purchase history. |
| `Screen`         | `@OneToMany seat`   | `Seats`         | **EAGER** | ALL                          | ⚠️ Loading a screen loads ALL seats. This is intentional for seat-map rendering but causes large object graphs when navigating from Ticket→Screen. |
| `Seats`          | `@ManyToOne screen` | `Screen`        | **EAGER** | none                        | ⚠️ Bidirectional EAGER: Seat→Screen→Seats creates potential infinite recursion during serialization. JSON assembly in BookController manually breaks the cycle. |
| `ScreeningDates` | `@OneToOne venues`  | `Venues`        | **EAGER** | ALL                          | Loading a screening date always loads its venue. Needed for venue name/picture display. |
| `Venues`         | `@OneToOne screen`  | `Screen`        | **EAGER** | ALL                          | ⚠️ Venues→Screen→Seats is always loaded. Admin venue insertion cascades Screen/Seats creation. |
| `Venues`         | `@ManyToOne location` | `Location`    | **EAGER** | PERSIST, REFRESH             | Venue always loads its location (for map coordinates). |
| `Location`       | `@OneToMany venues` | `Venues`        | **LAZY** | none                        | Location listing does NOT load all venues. Venues fetched separately per location via DAO queries. |
| `Ticket`         | `@OneToOne screen`  | `Screen`        | **EAGER** | none                        | Ticket always loads its screen (→ movie, → seats, → dates). Powers purchase history display. |
| `Ticket`         | `@ManyToOne seats`  | `Seats`         | **EAGER** | none                        | Ticket always knows which seat it represents. |
| `Ticket`         | `@ManyToOne purchase` | `Purchase`    | **LAZY** | none                        | Ticket does NOT auto-load its parent purchase. Purchase is accessed from the other direction. |
| `Purchase`       | `@OneToMany ticket` | `Ticket`        | **EAGER** | PERSIST, REFRESH (no REMOVE) | ⚠️ Loading a purchase loads ALL tickets → each ticket loads Screen → all Seats. Can be very expensive for large purchases. `@BatchSize(size=10)` on Purchase helps with batch loading. |

### Use-case: User selects a movie to book tickets

1. **Browse movies** → `DAO.getAllMovies()` — HQL `from Movie`, query-cached in `movies` region. `Movie.screens` is LAZY → **no joins**, just movie rows. Fast, paginated.
2. **Select movie → venues** → `DAO.getVenuesForMovie(movieId)` — joins `Venues→Screen→Movie`. `Venues.location` is EAGER → Location auto-loaded. `Venues.screen` is EAGER → Screen loaded → `Screen.screeningDates` EAGER → ScreeningDates loaded.
3. **Select venue → screening dates** → `DAO.getScreeningDatesForMovieOnVenue(locationId, movieId)` — returns ScreeningDates with `venues` (EAGER) populated.
4. **Select date → seat map** → `DAO.getSeatsForScreening(screeningDateId)` — HQL navigates `ScreeningDates→Venues→Screen→Seats`. All seats loaded. **NOT cached** (freshness for reservation state). This is where the EAGER `Screen.seat` pays off — seat map is fully loaded in one query.
5. **Reserve seats** → `DAO.bookTickets()` — `PESSIMISTIC_WRITE` lock on each Seat row. Creates Ticket + Purchase. Seats marked `isReserved="1"`.
6. **Post-booking seat refresh** → `DAO.updatetedSeats(screeningDateId)` — reloads `ScreeningDates→Venues→Screen→Seats` from DB (bypasses cache).

### Payment workflow (end-to-end)

Both iOS and web share the same proxy servlet path through `dalogin`. The flow below covers seat selection through payment to ticket creation (or rollback on failure).

#### Request chain
```
Client (iOS/Web)
  → GET /login/CheckOut          [session required]
      → AuthFilter (session + XSRF-TOKEN cookie)
      → ActiveVoucherFilter (account activated)
      → CheckOut.doGet()
          → buildAuthAttributes(session): uuid, token2, TIME_
          → ServiceClient → RequestFilter (copies X-Token, Ciphertext/token2, uuid, TIME_, cookies)
              → GET /mbooks-1/rest/book/payment/clientToken
                  → CiphertextFilter (Ciphertext == token2)
                  → CookieFilter (XSRF-TOKEN == AES(SALT, IV, TIME_, token2))
                  → BookController.clientToken() → gateway.clientToken().generate()
  ← {"clientToken": "..."}

Client initialises Braintree Drop-in (JS SDK 1.44.1 / iOS SDK 5.26.0)
  → User enters card details → requestPaymentMethod() → receives nonce

Client
  → POST /login/CheckOut         [session required]
      Body: payment_method_nonce=<nonce>&orderId=<currentTimeMillis>&seatsToBeReserved=<json>
      → Same dalogin filter chain as GET
      → CheckOut.doPost() → ServiceClient.checkOut(request)
          → POST /mbooks-1/rest/book/payment/fullcheckout2
              → Same mbooks filter chain
              → BookController.fullcheckout2():
                  1. Parse seatsToBeReserved JSON
                  2. TicketService.reserveTickets() → BookingHandlerImpl.returnTickets() → DAO.bookTickets():
                     a. Create Purchase entity (uuid, orderId, time)
                     b. For each seat number: HQL join SD→V→Screen→Seats + PESSIMISTIC_WRITE lock
                     c. If ANY seat isReserved != "0": ROLLBACK → throw CustomExceptions
                     d. All available: mark isReserved="1", create Ticket entities, COMMIT
                  3. Calculate totalAmount + totalTax from tickets
                  4. PaymentService.getOrCreateCustomerId(uuid) — reuse existing or create new Braintree customer
                  5. Store BraintreeCustomerId on Purchase
                  6. PaymentService.processTransaction() → gateway.transaction().sale()
                  7. IF Braintree fails: rollbackTickets() (delete tickets + purchase, free seats) → error response
                  8. IF Braintree succeeds: refresh seat map → return {AuthCode, Status, Amount, tickets, seatsforscreen}
```

#### Pessimistic locking in `DAO.bookTickets()`
The method is `synchronized` (JVM-level) and uses `PESSIMISTIC_WRITE` (database-level `SELECT ... FOR UPDATE`) on each seat row. Seats are locked **before** the availability check, preventing any concurrent session from reserving the same seat between the check and the update. If any seat is already reserved, the **entire** transaction rolls back — no partial bookings.

#### Rollback scenarios
| Trigger | Action | Method |
|---------|--------|--------|
| Seats already reserved | Delete provisionally created tickets + purchase, reset `isReserved="0"` | `ticketService.rollbackTickets()` → `DAO.cancelTicket()` |
| Braintree transaction declined | Same rollback — tickets + purchase deleted, seats freed | `ticketService.rollbackTickets()` → `DAO.cancelTicket()` |

#### Post-booking operations
| Operation | Client path | Proxy servlet | mbooks endpoint | DAO method |
|-----------|-------------|---------------|-----------------|------------|
| List purchases | `GET /login/GetAllPurchases` | `GetAllPurchases.java` | `GET /book/purchases` | `getAllPurchases(uuid)` |
| View tickets | `GET /login/ManagePurchases?purchaseId=X` | `ManagePurchases.java` | `GET /book/purchases/tickets` | `getTicketsForPurchase(id)` |
| Cancel tickets | `POST /login/ManagePurchases` | `ManagePurchases.java` | `POST /book/managepurchases` | `cancelTicket(ticketIds, purchaseId)` |
| Delete purchase | `POST /login/ManagePurchases` | `ManagePurchases.java` | `POST /book/deletepurchases` | `deletePurchase(purchaseId)` |

### Use-case: Admin inserts a new venue with a screen

1. **Admin UI** (iOS `AdminVC` or web admin) sends movie name, date, venue/location name, rows × seats, screeningId, category.
2. **Controller** → `BookController.addScreen()` → `BookingHandlerImpl.insertNewScreening()` → `DAO.insertNewScreen()`.
3. **DAO.insertNewScreen()** opens a **separate session** (`factory.openSession()`) to avoid deadlocking the singleton shared session:
   - Fetches `Location` by name (EAGER → no sub-queries needed).
   - Fetches/updates `Movie` (sets category).
   - Creates new `Venues` entity → associates with Location + a new `Screen`.
   - Creates new `ScreeningDates` entity → associates with Venues.
   - Creates new `Screen` entity → associates with Movie + ScreeningDates.
   - Batch-generates `Seats` (row×column loop, `session.save()` each). Batch size 20.
   - `CascadeType.ALL` on `Venues.screen` and `ScreeningDates.venues` propagates saves.
   - After commit: `movies` and `venues` L2 cache regions are invalidated for affected entities.
   - Publishes Kafka event via `KafkaMessageProducer` on background executor.
4. **Key gotchas**:
   - `Venues.screen` is `CascadeType.ALL` + `FetchType.EAGER` → inserting a Venue also persists its Screen and Seats.
   - `Screen.seat` is `CascadeType.ALL` + `FetchType.EAGER` → all seats are loaded into memory when the Screen is read back.
   - The separate session in `insertNewScreen` can cause stale reads in the main session if the shared session has cached entity state.
   - Max ID calculation (`SELECT MAX(venuesId) FROM Venues`) is not safe under concurrent admin operations — race condition on IDs.

### L2 cache configuration summary

| Entity          | `@Cacheable` | Cache Region | Strategy    | Rationale |
|-----------------|:------------:|:------------:|:-----------:|-----------|
| `Movie`         | ✅           | `movies`     | read-write  | Catalog changes infrequently; cache serves browse/search. |
| `Venues`        | ✅           | `venues`     | read-write  | Venue lookups are read-heavy during seat selection. |
| `Location`      | ✅           | `location`   | read-write  | Almost never mutated after seed data. |
| `Ticket`        | ✅           | `ticket`     | read-write  | Purchase history reads; new tickets visible after commit. |
| `Screen`        | ❌           | —            | —           | Intermediate entity; not directly queried by ID in hot paths. |
| `ScreeningDates`| ❌           | —            | —           | Screening queries are not query-cached (freshness). |
| `Seats`         | ❌           | —            | —           | **Deliberately uncached** — seat availability must always be fresh from DB. |
| `Purchase`      | ❌           | —            | —           | Purchase queries are query-cached (region `purchases`) but entity is not L2-cached. `@BatchSize(size=10)`. |

## Refactoring roadmap

### Phase 1 — Safety & correctness (no behaviour changes)
These changes fix real concurrency bugs and resource leaks without altering any API contracts, header names, or client-visible behaviour.

1. ~~**Remove static mutable state in servlets/filters**~~ (`dalogin HelloWorld.java`, `SQLAccess.java`, all filters).
   - **Done:** All 181 `volatile static` per-request fields converted to local variables across 18 files. `synchronized` removed from all `doPost()`/`doGet()`/`processRequest()` methods — servlets and filters are now stateless. Only `synchronized (session)` blocks remain (correct — protects session attribute writes). `AesUtil` moved from `static` to instance field initialized in `init()`. `SQLAccess` methods no longer `synchronized` (each already uses connection-per-call via `DBConnectionManager`). Fixed `==` string comparison to `.equals()` in `ActiveVoucherFilter` and `Registration`. `hmac512`/`sha512`/`SendHtmlEmail`/`jsonParser` utility classes also cleaned up.
   - Files: `dalogin-quarkus/src/main/java/com/dalogin/servlets/*.java`, `.../filters/*.java`, `SQLAccess.java`, `.../utils/hmac512.java`, `.../utils/sha512.java`, `.../utils/SendHtmlEmail.java`, `.../utils/jsonParser.java`, `.../listeners/CustomServletContextListener.java`, `.../listeners/CustomHttpSessionListener.java`.

2. **Replace raw JDBC with Quarkus DataSource** (`dalogin DBConnectionManager.java` → `@Inject DataSource`).
   - `QUARKUS_DATASOURCE_*` env vars are already set in K8s manifest.
   - Files: `dalogin-quarkus/.../DBConnectionManager.java`, `SQLAccess.java`.

3. ~~**Replace mbooks DAO singleton with CDI-managed sessions**~~ (partially done — session-per-call).
   - **Done:** Static volatile `Session`/`Transaction`/`Seats`/`Purchase`/`Screen` fields removed. Every method uses `try (Session session = factory.openSession())`. Read-only methods are no longer `synchronized`. Write methods retain `synchronized`. `bookTickets()` uses inline `PESSIMISTIC_WRITE` locks in a single session. Fixed empty HQL in `getlocationForVenue()`. `BookingHandlerImpl.getLocationForMovie()` creates detached copies for clean JSON serialisation.
   - **Remaining:** Full CDI migration — make `DAO` `@RequestScoped`, inject Quarkus-managed `Session`, remove `DAO.instance()` and `HibernateUtil`.
   - Files: `mbooks-quarkus/.../db/DAO.java`, `HibernateUtil.java`, `BookingHandlerImpl.java`.

4. **Externalise hardcoded secrets** (Braintree keys, AES SALT/IV).
    - Move to K8s Secrets or `@ConfigProperty` env-var overrides.
    - AES SALT/IV must be shared between `dalogin`, `mbook`, `mbooks` → shared K8s Secret.
    - Files: `BookController.java`, `PaymentService.java`, `HelloWorld.java`, `CookieFilter.java`, `CiphertextFilter.java`.

5. ~~**Refactor iOS service calls to async/await + centralized networking**~~ (done).
    - **Done:** Complete rewrite of iOS networking layer (`SwiftCinemas/SwiftLoginScreen/Networking/`):
    - `APIClient.swift` — Modern async/await HTTP client (response caching, error handling, cookie management)
    - `Endpoint.swift` — Reusable URL composition builder
    - `URLManager.swift` — Centralized URL configuration (single `baseHost` point to change)
    - `HeaderProvider.swift` — Protocol-based header injection (SessionHeaderProvider, HMACLoginHeaderProvider, MinimalGETHeaderProvider, RapidMovieDatabaseHeaderProvider)
    - `BackendServices.swift` — Service wrapper classes (@MainActor bound):
      - `MbooksService` — `/mbooks-1/rest/book` endpoints
      - `LoginGatewayService` — `/login` proxy servlets
      - `ImageResourceService` — Image downloads
      - `RapidMovieDatabaseService` — External RapidAPI
    - `AppError.swift` — Standard error enum (networkFailure, httpError, authRequired, activationRequired, decodingFailed)
    - `ResponseCache.swift` — Protocol for caching GET responses (Realm-backed)
    - Service injection pattern: `AppDelegate` creates `AppServices` container → injected via `UIViewController` extension protocols
    - **Replaces:** Legacy callback-based `GeneralRequestManager`, hardcoded `URLSession` in each ViewController
    - **Benefits:** Type-safe, testable, protocol-based extensibility, @MainActor thread safety, automatic response caching
    - Files: `SwiftCinemas/SwiftLoginScreen/Networking/*.swift`

### Phase 2 — Structural improvements
These changes improve maintainability and test coverage but require coordinated changes.

6. **Split BookController god-class** (1170 lines → 4 resources).
    - `MovieResource` — browse, search, paging.
    - `BookingResource` — seat selection, reservation, rollback.
    - `PaymentResource` — Braintree client token, checkout, web checkout.
    - `PurchaseResource` — purchase list, tickets per purchase, cancel, delete.
    - Use DTO classes with Jackson serialization instead of manual `JSONObject` assembly.

7. **Extract shared security module** (`cinemas-security` Maven module).
    - AES constants, HMAC utilities, XSRF token logic.
    - All three backend services depend on this module.
    - iOS client constants must continue to match (document in module README).

8. **Reduce dalogin proxy servlets** — move header-injection to Apache `mod_headers` or NGINX auth_request.
    - `CheckOut`, `GetAllPurchases`, `ManagePurchases` become thin Apache proxy rules.
    - Requires updating iOS client URLs from `/login/CheckOut` to direct `/mbooks-1/rest/...` paths.

9. **Add comprehensive tests**.
    - Quarkus `@QuarkusTest` for each REST endpoint in all services.
    - Unit tests for `hmac512`, `AesUtil`, `TicketService`, `PaymentService`.
    - Testcontainers-based tests for stored procedures.
    - Expand Python integration tests to cover registration, booking, and error paths.

### Phase 3 — Architecture modernisation (long-term)
10. **Migrate stored procedures to application logic** — move voucher state machine, token management, and user registration logic into Java service classes. Keep only audit triggers.
11. **Standardise error responses** — define a consistent error envelope across all services.
12. **Consider JWT/OAuth2** — replace the custom HMAC+XSRF+Ciphertext chain with a standard token-based auth flow.
13. ~~**Persistent pictures volume**~~ — **Done.** The `pictures-pvc` PVC is now wired into the `simple-service-webapp` deployment in `quarkus-backend.yaml`. Pictures persist across pod restarts. After first deployment, copy pictures once: `tar cf - -C pictures . | kubectl exec -n cinemas -i <pod> -- tar xf - -C /pictures/`.

## IDE run configurations

Shared IntelliJ IDEA run configurations live in `.run/` (version-controlled, auto-detected by IntelliJ on project open).

### Corporate proxy note
The corporate proxy blocks some Maven plugin downloads. All Maven-type run configurations use `myGeneralSettings` → `userSettingsFile` pointing to `$PROJECT_DIR$/k8infra/settings-local.xml` (forces HTTPS Central, no proxy). The appium module has **no `mvnw` wrapper** — shell-based configs use the system `mvn` command.

### Catalogue

| Run configuration | Type | Purpose |
|-------------------|------|---------|
| **dalogin - package** | Maven | `package -DskipTests` in `dalogin-quarkus/` |
| **mbook - package** | Maven | `package -DskipTests` in `mbook-quarkus/` |
| **mbooks - package** | Maven | `package -DskipTests` in `mbooks-quarkus/` |
| **mbooks - quarkus:dev** | Maven | `quarkus:dev` in `mbooks-quarkus/` |
| **simple-service-webapp - package** | Maven | `package -DskipTests` in `simple-service-webapp-quarkus/` |
| **appium - compile** | Maven | `compile test-compile` in `appium/` (prerequisite for java-direct configs) |
| **appium - mvn test** | Maven | `test` in `appium/` — runs `testng.xml` via Surefire |
| **appium - mvn test (inspect)** | Maven | `test -DtestngXml=testng-inspect.xml` — runs InspectUI suite |
| **appium - java direct (testng)** | Shell | Bypasses `exec-maven-plugin`: resolves classpath via `mvn dependency:build-classpath`, then runs `java … org.testng.TestNG testng.xml` directly |
| **appium - java direct (inspect)** | Shell | Same direct approach for `testng-inspect.xml` |
| **appium - CreateXml GUI** | Shell | Launches the `qa.ios.util.CreateXml` Swing GUI for interactive TestNG XML suite creation. Classpath includes `target/test-classes` so `Class.forName()` finds test classes like `TestNavigations` |
| **k8s - test-login.py** | Python | Runs `k8infra/test-login.py` end-to-end API smoke test |
| **k8s - test-login-admin.py** | Python | Runs `k8infra/test-login-admin.py` admin API smoke test |
| **ALL - package (skip tests)** | Shell | Builds all four backend services sequentially |
| **ALL - docker build (minikube)** | Shell | Builds Docker images directly into Minikube's Docker daemon |

### Adding new run configs
Create new `.run.xml` files in `.run/`. For Maven configs, set the settings file via `myGeneralSettings` → `MavenGeneralSettings` → `userSettingsFile` — do **not** put `--settings` or `-s` in `cmdOptions` (IntelliJ's Maven runner misinterprets it as `-f/--file`).

## Local build and run workflows
- **Prerequisites:** Docker CLI (`brew install docker`) + colima (`brew install colima`) — no Docker Desktop licence needed. Start with `colima start --cpu 4 --memory 8 --disk 60`.
- **Minikube:** `minikube start --driver=docker --cpus=4 --memory=8192 && minikube addons enable ingress`. The Docker driver replaces the legacy qemu2 driver — networking is stable via `sudo minikube tunnel` (no more `kubectl port-forward` + `pf` that dies on sleep/wake).
- Quarkus dev mode per service: `./mvnw quarkus:dev` inside each backend module (or use the IntelliJ run configurations in `.run/`).
- Package container-ready artifacts with `./mvnw package -DskipTests` in each backend module; Dockerfiles expect `target/quarkus-app/`.
- **Build images (Option A — fastest):** `eval $(minikube docker-env)` then `docker build -t <image>:local ./<dir>` — images are immediately available to K8s, no loading needed. Run `eval $(minikube docker-env --unset)` afterwards. Or use the **ALL - docker build (minikube)** run config.
- **Build images (Option B — Podman):** `podman build -t <image>:local ./<dir>` then `podman save localhost/<image>:local | minikube image load --daemon=false -`. With the Docker driver, no retag (`ctr images tag`) is needed.
- For the full local Kubernetes workflow, follow `k8infra/README-k8s-local.md`.
- If behind a corporate proxy, use the bundled Maven settings: `./mvnw -s ../k8infra/settings-local.xml package -DskipTests`. The IntelliJ run configurations already include this setting via `myGeneralSettings`.
- **Existing tests:**
  - `dalogin-quarkus`: `LoginFlowTest.java` — `@QuarkusTest` with 7 ordered tests covering HMAC login, bad HMAC, wrong password, missing params, and session-based `/admin` retrieval. Requires a running MySQL with `login_` schema and (for the admin test) a reachable `mbook` service at `WILDFLY_URL`.
  - `mbooks-quarkus`: `GreetingResourceTest.java` / `GreetingResourceIT.java` — smoke-level `@QuarkusTest` health-check tests.
  - `simple-service-webapp-quarkus`: `ImageResourceTest.java` — `@QuarkusTest` verifying the health endpoint returns `"Got it"` and missing images return 404.
  - Appium: `TestNavigations.java` — iOS UI test (Movies → Category → Venue → Seats → Checkout). Run via **appium - mvn test** or **appium - java direct (testng)** run configs. See `appium/README.md` for full setup.
  - Python: `k8infra/test-login.py` and `k8infra/test-login-admin.py` — end-to-end API smoke tests over HTTPS. Run via **k8s - test-login.py** / **k8s - test-login-admin.py** run configs.

## Git repositories
Each service is a separate Git repository under the `igeorge0902` organisation:

| Folder | Remote | Status |
|--------|--------|--------|
| `dalogin-quarkus/` | `git@github.com:igeorge0902/dalogin-quarkus.git` | existing |
| `mbook-quarkus/` | `git@github.com:igeorge0902/mbook-quarkus.git` | existing |
| `mbooks-quarkus/` | `git@github.com:igeorge0902/mbooks-quarkus.git` | existing |
| `k8infra/` | `git@github.com:igeorge0902/k8infra.git` | existing |
| `simple-service-webapp-quarkus/` | `git@github.com:igeorge0902/simple-service-webapp-quarkus.git` | existing |

## Kubernetes and integration gotchas
- The Quarkus stack expects four backend pods (dalogin, mbook, mbooks, simple-service-webapp) plus MySQL, Zookeeper, Kafka, Apache, Prometheus, Tempo, Grafana, and an NGINX ingress controller.
- MySQL is deployed with `--lower-case-table-names=1` because Hibernate entity names are lowercase but the original dump uses mixed case.
- A `mysql-init` ConfigMap auto-creates databases (`login_`, `book`) and grants access to `sqluser` on pod startup via `/docker-entrypoint-initdb.d`. Schema and seed data must still be imported separately from the SQL dumps (see below).
- Database split is intentional: `dalogin` + `mbook` use `login_`, while `mbooks` uses `book`. There must be **no** database named `login` (without underscore); only `login_` should exist.
- `mysql_8/login.sql` already targets the `login_` database; import directly with `mysql -uroot -prootpw < mysql_8/login.sql`. The script is self-contained — triggers, stored procedures, and the `profilePicture` column are all included with correct casing and `login_.` references.
- `BOOTSTRAP_URL` defaults to `localhost:9092`; set it explicitly in Kubernetes (`kafka:9092`).
- Kafka runs `apache/kafka:3.9.0` with a ConfigMap-driven `server.properties` (`kafka-config`); broker advertises as `kafka:9092`.
- Kafka movie topics are now aligned: producers and consumers both use `ios-movies-notifications2`; both `KafkaMessageProducer` classes read `BOOTSTRAP_URL` from the environment. Each consumer uses a distinct group ID (`mbooks-movies-group`, `mbook-movies-group`, `mbook-users-group`) so that consumers in different services receive all messages independently rather than competing for partitions.
- `mbook-quarkus` and `mbooks-quarkus` include `quarkus-smallrye-health`; `mbooks` has a custom `MyLivenessCheck` (`@Liveness`, returns "alive"). Standard Quarkus health endpoints are available at `/q/health`, `/q/health/live`, `/q/health/ready`. No readiness/liveness probes are configured in the K8s manifest for the application pods; only Tempo (`/ready` on port 3200) and Grafana (`/grafana/api/health` on port 3000) have readiness probes.
- WebSocket servers are exposed at `@ServerEndpoint("/ws")`; Apache proxies `/mbook-1/ws` and `/mbooks-1/ws`.
- iOS currently assumes production hostnames via `URLManager.baseHost` (`milo.crabdance.com`); the WebSocket URL (`wss://milo.crabdance.com/mbook-1/ws`) is built from `URLManager.webSocketURL`. To point the app at a local backend, change `baseHost` in `URLManager.swift`.
- A `pictures-pvc` PersistentVolumeClaim (500 Mi) is defined in the manifest and **wired** to the `simple-service-webapp` deployment. Pictures persist across pod restarts. After first deployment, copy pictures once with `tar cf - -C pictures . | kubectl exec -n cinemas -i <pod> -- tar xf - -C /pictures/`.
- MySQL uses `emptyDir: {}` by default — data is lost on pod restart; re-import from `mysql_8/*.sql` or from an external master dump. See `k8infra/README-k8s-local.md` step 4a for the full restore-from-master workflow (dump → import → re-grant → restart services to clear L2 cache).
- There are committed credentials/secrets in repo files; do not copy them into new docs or code when env/config overrides will do.

### Apache security headers
Apache `mod_headers` is enabled in the startup command and the `proxy.conf` ConfigMap includes a full `<IfModule mod_headers.c>` block with: HSTS (preload), `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy` (with `payment=(self)` for Braintree), and a `Content-Security-Policy` tailored to the actual resources (Braintree SDK, Google Fonts, WebSocket). CORS headers are also set here (`Access-Control-Allow-Origin: https://milo.crabdance.com`). The `CORSFilter.java` in dalogin is **not registered** (no `@WebFilter`, not in `web.xml`) — it is dead code kept for reference. Do not activate it without removing the Apache CORS directives first (duplicate headers break CORS).

### Apache proxy rule ordering (WebSocket)
Apache `mod_proxy` is **first-match**. The WebSocket `ProxyPass` rules (`/mbook-1/ws`, `/mbooks-1/ws`) **must** appear before their parent HTTP routes (`/mbook-1`, `/mbooks-1`) in `proxy.conf`. If the HTTP route is listed first, it swallows WebSocket upgrade requests and proxies them as plain HTTP — the `ws://` rules never match, and the iOS client gets `Socket is not connected`. The current `quarkus-backend.yaml` has the correct ordering; do not reorder the `ProxyPass` directives.

### Local networking for iOS simulator
The iOS simulator resolves DNS via the host Mac. Two things must be in place for `https://milo.crabdance.com` to reach the K8s ingress:

1. **`/etc/hosts`** — `127.0.0.1 milo.crabdance.com`
2. **`sudo minikube tunnel`** — assigns `127.0.0.1` as the external IP for the `ingress-nginx-controller` LoadBalancer service. Traffic to `127.0.0.1:443` goes directly to the NGINX ingress. The tunnel auto-reconnects after sleep/wake; stop with Ctrl+C.

If the tunnel is not running, the iOS app gets:
```
NSURLErrorDomain: -1003          (cannot find host)
NSPOSIXErrorDomain Code=57       (Socket is not connected)
```

> **Legacy (qemu2 driver only):** If using the qemu2 driver instead of Docker, `minikube tunnel` does not work. Use `kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443 &` plus a macOS `pf` redirect (`443 → 8443`). Both die on sleep/reboot. See the Appendix in `k8infra/README-k8s-local.md`.

### WebSocket verification
After setting up networking, verify WebSocket upgrade through the full chain:
```bash
curl -sk --http1.1 -o /dev/null -w "%{http_code}\n" \
  -H 'Upgrade: websocket' -H 'Connection: Upgrade' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  -H 'Sec-WebSocket-Version: 13' \
  https://milo.crabdance.com/mbook-1/ws
# → 101
```
The `--http1.1` flag is required — HTTP/2 strips `Connection: Upgrade` headers.

## Where to start editing
- Auth/session bugs: `dalogin-quarkus/src/main/java/com/dalogin/filters/` and `.../servlets/`.
- Booking/payment rules: `mbooks-quarkus/src/main/java/com/jeet/rest/BookController.java`, then `service/`, `booking/`, and `db/`.
- User/profile/device behavior: `mbook-quarkus/src/main/java/com/jeet/rest/` plus `db/` and broadcasting classes.
- Front-end UI: edit in `dalogin-quarkus/src/main/resources/META-INF/resources/` (AngularJS HTML + JS).
- Film-Review Booking UI: `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/` — `app.js` (controllers + HMAC interceptor + login/auth state), `templates/` (movies, venues, venues-list, venue-movies, dates, checkout, login, purchases, purchase-detail), `index.html` (shell + CSS). Proxy servlets: `CheckOut.java`, `GetAllPurchases.java`, `ManagePurchases.java`. Client interface: `com.dalogin.client.service.Purchases`. See the "Film-Review Booking UI" section above for payload contracts.
- Appium iOS UI tests: `appium/src/test/java/` for tests, `appium/src/main/java/qa/ios/` for page objects.
- Local deployment changes: `k8infra/quarkus-backend.yaml` first, `k8infra/kubernetes.yaml` only as legacy reference.
- Entity relationships & fetch strategies: `mbooks-quarkus/src/main/java/com/jeet/api/` — see the entity relationship table above before changing any `FetchType` or `CascadeType`.
- Hibernate & caching config: `mbooks-quarkus/src/main/resources/hibernate.cfg.xml` and `infinispan-configs-local.xml`.
- System documentation: `docs/system-documentation.html` — comprehensive HTML with inline SVG diagrams.
