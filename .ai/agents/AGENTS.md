# Cinemas architecture and contracts

## Scope

Current service boundaries, implementation entry points, and cross-client contracts.
Source and configuration take precedence over historical specs or generated documentation.
Keep operational recipes in `.ai/retrieval/instructions.md`, coding examples in
`.ai/skills/skills-github.md`, and Speckit rules in `.ai/constitution/constitution.md`.
Do not treat completed refactoring plans as the current architecture.

## System map

Java 17 / Quarkus 3.19.4 backends, MySQL 8, an AngularJS booking SPA, and a
UIKit/storyboard iOS app with incremental SwiftUI adoption.

| Module | Responsibility | HTTP root | Database |
|--------|----------------|-----------|----------|
| `dalogin-quarkus/` | Login/session gateway, proxy servlets, web UI | `/login` | `login_` |
| `mbook-quarkus/` | Accounts, devices, news and news settings | `/mbook-1` (port 8888) | `login_` |
| `mbooks-quarkus/` | Movies, venues, checkout and purchases | `/mbooks-1` | `book` |
| `simple-service-webapp-quarkus/` | Images and active-session proxy | `/simple-service-webapp` (port 8085) | None |
| `SwiftCinemas/` | Native client and embedded web login | Gateway + service APIs | Client storage |
| `appium/` | iOS UI automation | Appium / XCUITest / TestNG | None |
| `k8infra/` | Kubernetes, Apache routing, observability and API smoke tests | NGINX ingress | Infrastructure |

Traffic flows `iOS/Web -> NGINX ingress (TLS) -> Apache -> backend services`.
`dalogin` forwards authenticated requests to downstream services; do not bypass it for
checkout or purchase management. Its historical `WILDFLY_URL` setting selects the downstream
base URL, not an application-server requirement.

## Backend implementation

Java paths below are relative to each module's `src/main/java/`.

- **dalogin:** `com/dalogin/servlets/` remains servlet-based. Request records and response
  helpers live in `servlets/requestrecord/` and `servlets/responsemap/`; servlets use
  `crypto/CryptoService.java` and injected managers under `persistence/`.
  `client/ServiceClient.java` and `client/filter/RequestFilter.java` own downstream forwarding.
- **mbook:** `com/jeet/rest/AccountController.java`, `NewsController.java`, and
  `NewsSettingsController.java` delegate to services. REST boundaries use request beans,
  response records, mappers and `ApiResponseFactory`.
- **mbooks:** `com/jeet/rest/` contains `MovieController`, `VenueController`,
  `CheckoutController`, and `PurchaseController`. Orchestration lives in `service/`,
  with booking helpers in `service/booking/`. Follow `requestbean/`, `responserecord/`,
  `responsemapper/`, and `ApiResponseFactory` patterns; some checkout responses still
  contain entities. `BookController` and `BookingHandlerImpl` are no longer entry points.
- **Images:** `com/example/rest/ImageResource.java` serves under `/webapi/myresource`;
  its admin resource proxies the gateway's `/login/activeSessions`.

### Persistence ownership

- **dalogin:** persistence managers inject Quarkus `DataSource`. Login device/session/token
  writes share one connection and transaction; publish successful session state only after
  persistence succeeds. Registration-with-voucher preserves voucher -> device -> session ->
  token-copy ordering. Connection-taking participant methods must not independently commit,
  close, or acquire another connection.
- **mbook:** `com/jeet/db/DAO.java` injects the Quarkus-managed Hibernate `Session` and uses
  `@Transactional`.
- **mbooks:** `com/jeet/db/DAO.java` is CDI-managed but still uses the manually bootstrapped
  `SessionFactory` in `HibernateUtil.java`, session-per-call and explicit transactions.
  Do not assume it has migrated to Quarkus-managed persistence.
- Schema sources are `mysql_8/login.sql` and `mysql_8/book.sql`. Preserve the `login_`/`book`
  split. Before changing fetch/cascade/cache behavior, inspect the actual entities and
  `mbooks-quarkus/src/main/resources/hibernate.cfg.xml`; seat availability must remain fresh.

## Cross-client contracts

Header names, response casing, form fields and legacy status semantics are shared by native
and web clients. Coordinate backend changes with both clients.

- Preserve `X-Token`, `Ciphertext`, `X-Device`, `uuid`, `TIME_`, `token2`, `XSRF-TOKEN`,
  `X-HMAC-HASH`, and `X-MICRO-TIME`. The gateway uses session-derived `token2` when browser
  proxy calls omit `Ciphertext`. Do not replace the custom auth scheme during unrelated work.
- Mobile login uses numeric `success`; web login uses string `Success`. Preserve existing
  HTTP 200 business-failure bodies and the paged movie response's `APIKEY` behavior.
- **Checkout:** GET/POST `/login/CheckOut` forwards to `/book/payment/clientToken` and
  `/book/payment/fullcheckout2` under mbooks' REST root. POST is form-encoded:
  `payment_method_nonce`, `orderId` (current milliseconds), and `seatsToBeReserved` (JSON string).
  Its shape is `{"seatsToBeReserved":[{"screeningDateId":"5","seat":"A1-B2-"}]}`.
  Seat strings contain seat numbers, not database IDs.
- **Purchases:** `/login/GetAllPurchases` lists purchases. `/login/ManagePurchases` uses
  `purchaseId`; POST with `ticketsToBeCancelled={"ticketIds":[42,43]}` cancels tickets,
  while POST without that field deletes the purchase.
- **Booking:** `DAO.bookTickets()` takes `PESSIMISTIC_WRITE` locks before checking seats;
  reservation flags remain `"0"`/`"1"`. Reservations commit before external payment.
  Payment failure invokes compensating cancellation; this is not one atomic DB/payment
  transaction or a guarantee of atomicity across multiple screening entries.
- **Screen news:** GET/PUT `/login/admin/newsSettings/screen` proxies
  `/mbook-1/rest/news-settings/screen`. PUT accepts `{"enabled":true}`; ownership comes from
  the session, not the body. Missing settings mean disabled; persistence uses `"yes"`/`"no"`.

## iOS implementation

Paths are relative to `SwiftCinemas/SwiftLoginScreen/`.

- `AppDelegate.swift` is the UIKit entry point. `AppServices` in
  `Networking/BackendServices.swift` owns `APIClient` and the Mbooks, login gateway, image,
  and RapidAPI services. Preserve `HasAppServices`, explicit programmatic injection and
  storyboard `injectAppServicesIfNeeded()`; services/data managers use `@MainActor`.
- `Networking/APIClient.swift` provides async/await transport; `Endpoint.swift` builds
  requests. `Networking/URLManager.swift` owns the host and service roots. Its path helpers
  return relative service paths; `Endpoint` combines them with the base URL.
  External URLs use `absoluteURL`. GET caching is opt-in via `cacheKey`.
- `Networking/HeaderProvider.swift` owns login/session headers. Tokens prefer `SecureStore`
  with a defaults fallback. HTTP 401/403 maps to authentication required; HTTP 300 maps to
  activation required. `AuthDataManager.refreshToken()` validates stored state via a profile
  request; it is not a token-renewal endpoint.
- `WebViewController.swift` bridges Film-Review web login into native session state by
  copying WKWebView cookies into shared storage. Successful menu logout calls the gateway
  and clears cookies, defaults and secure session values.
- SwiftUI migration is partial: `VenuesMigration/VenuesMigration.swift` hosts the venues flow
  from movies/movie detail and returns to storyboard `VenuesDetailsVC`, forwarding services.
  `BasketVC.swift` uses Braintree SwiftUI `CardFields`, not the legacy Drop-in checkout UI.
  Preserve duplicate-submit guards and explicit Cancel/Pay behavior.
- Prefer the **`swiftcinemas` MCP** for discovery, references, views, networking, actor/DI
  wiring and build verification. Refresh cached analysis with `reload` after edits.
  Fall back to repository tools when unavailable or insufficient; preflight is not a build.

## Events and web UI

- Screen events flow from mbooks through Kafka to mbook WebSockets. Kafka uses Base64 Java
  serialization; WebSocket JSON is a separate contract. Keep producer/consumer models aligned.
- `/mbook-1/ws` requires a nonblank `deviceId` query parameter. Screen-news delivery requires
  that device to resolve to one distinct active user with screen news enabled; unresolved
  sessions are skipped. Legacy user notifications retain a broadcast path.
- Screen JSON fields are `movie`, `date`, `venue`, `screeningId`, `screeningDatesId`,
  `eventType` (`created`, `updated`, `deleted`) and `category` (`screening`).
- iOS `BroadCasting/Websocket.swift` supplies the current vendor device identifier, pings
  every 30 seconds and reconnects after 3 seconds with stale-callback guards. Missing event
  metadata defaults to `created`/`screening`. Received messages are currently logged, not
  automatically applied to UI or seat state.
- The AngularJS SPA is in `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/`:
  `app.js` owns controllers, routing and HMAC interception; `templates/` owns screens.
  Preserve plain `#/...` routing and the shared gateway/payload contracts.

## Infrastructure and validation references

- `k8infra/quarkus-backend.yaml` is the deployment source; use `k8infra/README-k8s-local.md`
  for setup. Apache WebSocket proxy rules must precede parent HTTP routes (first-match).
  Preserve MySQL case handling and the `mysql-pvc`/`pictures-pvc` volumes.
- Application telemetry uses OpenTelemetry/Tempo and Prometheus/Grafana. Do not confuse it
  with disabled agent-routing telemetry. Do not reproduce credentials in docs or code.
- Use module Maven wrappers and focused tests; Appium uses system `mvn` and its own README.
  `.run/` holds shared IDE configurations. API smoke-test guidance lives in
  `k8infra/api-smoke-restassured/README.md`; checkout expectations are in its
  `CHECKOUT_CONTRACT.md`. Existing tests do not establish complete coverage.

## Agent routing

The `desktop-commander` MCP is generally available to all agents for supported local
file, search and process operations. Use it when appropriate, without replacing preferred
domain MCP tools or bypassing tool permissions and repository safeguards.

Canonical agent definitions live in `.ai/agents/definitions/`; `.github/agents/` contains
discovery symlinks. Select Cinemas Router for cross-domain work; directly selected specialists
retain ownership, and explicit `/speckit.*` commands retain that lifecycle.
Follow `agents-role.yaml` for routing, tiers, protected areas and specialist/Quick Engineer
handoffs rather than duplicating those policies here.

Routing telemetry is disabled: preserve existing records and protocol files, but do not
create/update manifests, query usage for telemetry or add routing-cost handoff tables.
Re-enablement requires an explicit user request. Never commit or push unless explicitly asked.
