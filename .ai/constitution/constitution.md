# Speckit Constitution: Cinemas

## Purpose and authority

Cinemas is a cinema booking system spanning four Quarkus services, an AngularJS web UI,
a UIKit/storyboard iOS client with partial SwiftUI migration, and Kubernetes infrastructure.
This constitution defines durable change safeguards, not an endpoint inventory or deployment
runbook. Follow `.ai/agents/AGENTS.md` for current architecture and contracts,
`.ai/retrieval/instructions.md` for operational guidance, and source/configuration for evidence.
Explicit `/speckit.*` requests retain the Speckit lifecycle.

## Service and persistence boundaries

- Preserve service roots `/login`, `/mbook-1`, `/mbooks-1`, and `/simple-service-webapp`.
  TLS ingress precedes Apache reverse proxy routing.
- `dalogin` and `mbook` use MySQL `login_`; `mbooks` uses `book`.
  Schema sources are `mysql_8/login.sql` and `mysql_8/book.sql`.
- `dalogin` remains servlet-based with request/response helpers, injected persistence managers
  and `CryptoService`. Its managers use Quarkus `DataSource`; login and voucher registration
  participants must share their caller's connection/transaction without independently
  committing or closing it. Publish successful login state only after persistence succeeds.
- `mbook` uses controller/service/request/response mapping and a Quarkus-managed Hibernate
  `Session`. `mbooks` uses Movie, Venue, Checkout and Purchase controllers/services, but its
  CDI-managed DAO still opens sessions from `HibernateUtil`'s manual `SessionFactory`.
  Do not apply one module's transaction lifecycle to another without an explicit migration.
- Preserve fetch/cascade/cache behavior unless the change explicitly addresses it.
  Inspect entity and Hibernate configuration before changing persistence assumptions.

## Authentication and cross-client compatibility

- Preserve the custom HMAC/session scheme and header/cookie names: `X-Token`, `Ciphertext`,
  `X-Device`, `uuid`, `TIME_`, `token2`, `XSRF-TOKEN`, `X-HMAC-HASH`, `X-MICRO-TIME`.
  Use the actual header providers and gateway filters; do not invent a simplified signing
  algorithm or reinterpret identifiers.
- Keep checkout/purchase requests behind the login gateway. It forwards authenticated
  session attributes downstream, including the browser fallback from absent `Ciphertext`
  to session-derived `token2`.
- Response key casing, types, business-failure bodies and status semantics are contracts:
  mobile `success` and web `Success` differ; iOS treats HTTP 300 as activation required.
  Do not normalize these during unrelated cleanup.
- Backend payload/header/route changes require coordinated AngularJS and iOS impact analysis.
  Preserve endpoint consumers and error surfaces, or explicitly plan their migration.
- Never copy credentials, SDK keys or other secrets into documentation or new source.
  Read dependency versions from manifests rather than freezing them as immutable contracts.

## Booking and payment integrity

- `DAO.bookTickets()` must lock seats with `PESSIMISTIC_WRITE` before availability checks.
  Seat reservation flags remain string `"0"`/`"1"`; availability must not use stale cache data.
- Reservation transactions commit before external payment. Payment failure uses compensating
  cancellation to release seats and remove provisional booking records. Do not describe this
  as an atomic database/payment transaction or extend lock duration through payment.
- GET/POST `/login/CheckOut` remains the client checkout boundary. POST is form-encoded with
  `payment_method_nonce`, `orderId` (milliseconds), and `seatsToBeReserved` (JSON string).
  The JSON shape is `{"seatsToBeReserved":[{"screeningDateId":"5","seat":"A1-B2-"}]}`:
  seat numbers, not database IDs.
- Purchase management preserves `purchaseId` and the optional JSON string
  `ticketsToBeCancelled={"ticketIds":[42,43]}`. Absence of that cancellation field on POST
  means purchase deletion, not an empty cancellation.
- Preserve duplicate-submit guards, explicit payment cancellation and existing failure
  handling across native and web checkout.

## iOS and event behavior

- Preserve `AppDelegate`/`AppServices` ownership, `HasAppServices` injection, storyboard
  injection and `@MainActor` isolation. Use existing async/await services rather than
  introducing direct networking in view controllers.
- `Networking/URLManager.swift` supplies relative service paths; `Endpoint` composes requests.
  Preserve header providers, opt-in GET caching, secure session storage and the web-login
  cookie bridge. `refreshToken()` validates stored state; it is not token renewal.
- Keep storyboard/segue identifiers, selected movie/venue/location/screening context and
  service handoffs stable during SwiftUI migration. Venues use a SwiftUI host; checkout uses
  Braintree SwiftUI `CardFields`. The app has not migrated wholesale to a SwiftUI lifecycle.
- Screen-news GET/PUT `/login/admin/newsSettings/screen` uses a boolean `enabled`; ownership
  is session-derived and missing settings mean disabled. Failed saves must not appear confirmed.
- `/mbook-1/ws` requires `deviceId`. Screen-news delivery resolves one distinct active user
  for that device and checks subscription state. Preserve producer/consumer event models;
  Kafka Java serialization and client WebSocket JSON are separate contracts.
- iOS currently logs incoming screen events; automatic alerts, seat refresh or other UI
  reactions are behavior changes, not an existing guarantee.

## Implementation and review discipline

- Follow current request beans/records, response records/mappers, services and response
  factories. Do not reintroduce removed monolithic controllers or manual JSON patterns
  merely because old examples use them.
- Prefer `cinemas-backend` and `swiftcinemas` MCP analysis for their respective domains;
  use repository tools when coverage is insufficient. Refresh cached analysis after edits.
  Static analysis and preflight do not establish build/test success.
- Before redesign or migration, check backend/client mapping, transaction/locking behavior,
  navigation, async loading and error presentation. A visual redesign is presentation-only
  unless behavior changes were requested.
- Review findings should be severity-ordered with file/line evidence, distinguishing confirmed
  defects, conditional risks and accepted design choices. Runtime claims require actual
  focused validation; skipped tests are not passing coverage.
- Preserve application OpenTelemetry and Prometheus wiring. Agent-routing telemetry is
  separately disabled; preserve its records without generating new telemetry or cost tables.
- Follow `.ai/agents/agents-role.yaml` for ownership and protected areas. Never commit, push,
  deploy or modify persistent data without the applicable user authorization.

## Operational references

| Need | Canonical source |
|------|------------------|
| Architecture and client contracts | `.ai/agents/AGENTS.md` |
| Editing entry points and validation | `.ai/retrieval/instructions.md` |
| Reusable implementation examples | `.ai/skills/skills-github.md` (verify against current source) |
| Deployment, ingress and local networking | `k8infra/README-k8s-local.md` |
| Infrastructure and telemetry wiring | `k8infra/quarkus-backend.yaml` |
| API smoke tests and checkout expectations | `k8infra/api-smoke-restassured/README.md`, `CHECKOUT_CONTRACT.md` in that directory |
| iOS automation | `appium/README.md` |
