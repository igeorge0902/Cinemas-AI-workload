# Cinemas operational playbook

## Start here

- Read `.ai/agents/AGENTS.md` for current architecture/contracts and
  `.ai/constitution/constitution.md` for durable safeguards.
- Use `.ai/agents/agents-role.yaml` for specialist ownership and tiers. Canonical agent
  definitions are in `.ai/agents/definitions/`; `.github/agents/` contains discovery symlinks.
  Explicit `/speckit.*` requests retain their lifecycle.
- Source/configuration wins over historical plans and generated docs. Do not rely on old
  controller line numbers, SDK versions, completed roadmaps or examples without checking.
- Work only in the affected module and preserve unrelated edits. Nested modules may have
  their own Git repositories; inspect the correct repository before Git operations.
  Never commit or push unless explicitly asked.

## Prefer domain MCP tools

- **Backend:** use `cinemas-backend` before generic searches for module/endpoint discovery,
  type/entity descriptions, services, request/response models, mappers, injection,
  persistence/configuration and source reads. Narrow by module and symbol/path.
  `reload` refreshes cached analysis after edits.
- **iOS:** use `swiftcinemas` for views/storyboards, references, networking, actor/DI wiring,
  configuration and source reads. Use `reload` after edits; `build_verify` supports preflight,
  scheme listing, build and test actions. Preflight is not an executed build/test.
- If an MCP is unavailable or lacks coverage, state the limitation and use repository tools.
  Heuristic reports are leads to verify, not proof. Retain focused executable validation.
- During application modernization, show Assess/Plan/Execute in the **Modernization Workflow**
  canvas and refresh it after Modernize CLI commands change repository artifacts.

## Where to edit

Java paths in this table are relative to each module's `src/main/java/`.

| Concern | Starting points |
|---------|-----------------|
| Login/session gateway | `dalogin-quarkus`: `com/dalogin/servlets/HelloWorld.java`, `filters/`, `crypto/CryptoService.java`, `persistence/` |
| Gateway request/response and forwarding | `dalogin-quarkus`: `com/dalogin/servlets/requestrecord/`, `servlets/responsemap/`, `client/ServiceClient.java`, `client/filter/RequestFilter.java` |
| Accounts, news, subscriptions | `mbook-quarkus`: `com/jeet/rest/AccountController.java`, `NewsController.java`, `NewsSettingsController.java`, then `service/` and `db/DAO.java` |
| Catalog, venues and seating | `mbooks-quarkus`: `com/jeet/rest/MovieController.java`, `VenueController.java`, then `service/` and `db/DAO.java` |
| Checkout and purchases | `mbooks-quarkus`: `com/jeet/rest/CheckoutController.java`, `PurchaseController.java`, `service/CheckoutService.java`, `service/booking/` |
| REST boundary mapping | mbook/mbooks: `com/jeet/rest/requestbean/`, `responserecord/`, `responsemapper/`, `ApiResponseFactory.java` |
| Images and active-session proxy | `simple-service-webapp-quarkus`: `com/example/rest/ImageResource.java` |
| Event delivery | mbook/mbooks: `com/jeet/broadcasting/`; mbook's `ActiveSessionResolver` resolves device ownership |

### iOS and web

iOS paths are relative to `SwiftCinemas/SwiftLoginScreen/`.

- **Composition/navigation:** `AppDelegate.swift`, `Networking/BackendServices.swift`
  (`AppServices`, services and injection helpers), storyboard controllers.
- **Transport/contracts:** `Networking/APIClient.swift`, `Endpoint.swift`, `HeaderProvider.swift`,
  `URLManager.swift`, and `DataManagers/`. URL helpers produce relative service paths.
- **Session bridging:** `WebViewController.swift`, `DataManagers/AuthDataManager.swift`,
  `MenuVC.swift`. Preserve shared cookies and secure/defaults session cleanup on logout.
- **SwiftUI venues:** `VenuesMigration/VenuesMigration.swift`; preserve storyboard return
  navigation and service injection.
- **Checkout:** `BasketVC.swift` (Braintree SwiftUI `CardFields`), checkout/basket data managers.
- **Screen news:** `MenuVC.swift` and gateway service methods; events use
  `BroadCasting/Websocket.swift`. Incoming events currently log rather than update UI.
- **Web SPA:** `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/`.
  `app.js` owns controllers, plain hash routing and HMAC interception; templates own screens.

## Change checks

- Preserve auth headers/cookies, response casing/status behavior and service roots listed in
  `AGENTS.md`. Compare backend changes with both `BackendServices.swift` and web consumers.
- Checkout remains form-encoded through `/login/CheckOut`; `seatsToBeReserved` is a JSON
  string containing screening IDs and dash-separated seat numbers, not seat IDs.
  Confirm outgoing body/Content-Type before investigating payment SDK compatibility.
- Persistence differs: dalogin uses injected `DataSource` managers, mbook uses managed
  `Session`/`@Transactional`, mbooks uses manual sessions/transactions in its CDI DAO.
  Preserve caller-owned connection boundaries and lock seats before availability checks.
- Reservation commits precede external payment; verify compensating cancellation on failure.
  Do not extend transaction/lock lifetime or change cache policy as an incidental fix.
- For persistence changes, inspect entity fetch/cascade annotations and Hibernate config.
  Do not assume every read is unsynchronized, entities are all DTO-mapped, or cache regions
  are explicitly evicted after every mutation.
- Screen-news settings use `/login/admin/newsSettings/screen` -> mbook news-settings;
  the session owns the user. WebSocket connections need a nonblank `deviceId`.
- UI work must preserve selected context, segues, service injection, actor isolation,
  nonblocking loading and existing error surfaces unless behavior changes are requested.

## Focused validation

Use the smallest existing command that covers the change. From the repository root, for example:

```bash
# Replace the module and test selector with those relevant to the change.
cd mbooks-quarkus
./mvnw -s ../k8infra/settings-local.xml -Dtest=ApiResponseFactoryTest test
```

- Backend modules have Maven wrappers; dev mode is `./mvnw quarkus:dev` inside the module.
  Packaging with `-DskipTests` is not test evidence.
- API smoke tests: `mvn -f k8infra/api-smoke-restassured/pom.xml test`; see that directory's
  `README.md` for live overrides and `CHECKOUT_CONTRACT.md` for booking assertions.
  Check skipped counts: an unavailable backend may skip tests.
- Appium uses system Maven: `mvn -f appium/pom.xml test`. Setup is in `appium/README.md`;
  `appium/src/test/java/TestNavigations.java` is the UI suite. Discover page objects under
  `appium/src/main/java/qa/ios/` rather than assuming a test-source package.
  Route Appium work to Cinemas Testing Engineer and follow `.ai/skills/appium/SKILL.md`.
- iOS: select the actual scheme/destination with MCP `build_verify` or existing Xcode tooling;
  distinguish dependency/project preflight issues from compilation or test failures.
- Shared IDE configurations live in `.run/`; inspect actual files instead of relying on
  a copied catalog. Reuse `k8infra/settings-local.xml` when Maven proxy bypass is needed.
- When asked to run validation, use the requested services/configuration and execute first.
  Investigate actual failures rather than pre-auditing unrelated code or starting extra services.
  Do not install/restore dependencies unless manifests changed or validation reports them missing.

## Deployment and troubleshooting

- `k8infra/README-k8s-local.md` is the setup/deployment runbook;
  `k8infra/quarkus-backend.yaml` owns routing, volumes and observability configuration.
  Do not deploy as a side effect of a code/documentation edit.
- WebSocket Apache `ProxyPass` rules must precede parent HTTP routes. Check device identity
  and active-user/subscription resolution as well as upgrade/network reachability.
- For local iOS connectivity, follow the runbook's hostname, ingress and tunnel setup.
  Do not copy old port-forward/firewall workarounds into normal operation.
- Preserve the `login_`/`book` split and MySQL case handling. Never reset PVCs or import/repair
  database state as incidental troubleshooting.
- Application OpenTelemetry/Tempo and Prometheus/Grafana remain separate from disabled
  agent-routing telemetry. Preserve routing records; do not generate manifests or cost tables.
- Avoid copying secrets into output, examples or source. Use supported configuration overrides.
