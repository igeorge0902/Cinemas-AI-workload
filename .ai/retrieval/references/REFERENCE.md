# Cinemas reference guide

Use this as a navigation index, not a duplicate architecture or generated API catalog.
Current source/configuration takes precedence over historical examples.

## Documentation map

| Need | Reference |
|------|-----------|
| Architecture, persistence ownership and shared contracts | [AGENTS.md](../../agents/AGENTS.md) |
| Durable change safeguards | [Constitution](../../constitution/constitution.md) |
| Editing entry points, MCP tools and validation commands | [Operational playbook](../instructions.md) |
| Stable contract identifiers and implementation status | [Contracts index](CONTRACTS_INDEX.md) |
| Request/response mapping and source evidence | [Endpoint contracts](../endpoints/endpoint-contract-analysis.md) |
| Flow dependencies | [Dependency map](../endpoints/endpoint-dependency-map.md) |
| Client fallbacks and known limitations | [Gap reference](../gaps/ios-backend-gaps-quick-reference.md) |
| Findings at a glance | [Contract summary](../endpoints/endpoint-analysis-EXECUTIVE-SUMMARY.md) |
| UI redesign and migration boundaries | [Design guidance](design-spec.md) |
| Local infrastructure setup | [Deployment runbook](../../../k8infra/README-k8s-local.md) |
| Live API checks | [RestAssured smoke tests](../../../k8infra/api-smoke-restassured/README.md) |
| iOS automation setup | [Appium README](../../../appium/README.md) |

## Source discovery

Prefer `cinemas-backend` for endpoints, controllers/services, DTOs/mappers, entities,
Hibernate/CDI analysis and redacted source reads. Prefer `swiftcinemas` for iOS symbols,
views/storyboards, networking, actor/DI wiring and build verification. Narrow requests to
the affected module/symbol and refresh cached analysis after edits.
Use repository tools when MCP coverage is insufficient.

| Question | Source starting point |
|----------|-----------------------|
| Gateway login or request forwarding | `dalogin-quarkus/src/main/java/com/dalogin/servlets/`, `client/`, `persistence/` |
| Accounts or screen-news settings | `mbook-quarkus/src/main/java/com/jeet/rest/`, `service/`, `db/` |
| Movie/venue/checkout/purchase response shape | `mbooks-quarkus/src/main/java/com/jeet/rest/responserecord/`, `responsemapper/` |
| Booking transactions | `mbooks-quarkus/src/main/java/com/jeet/service/CheckoutService.java`, `service/booking/`, `db/DAO.java` |
| iOS transport, headers or paths | `SwiftCinemas/SwiftLoginScreen/Networking/` |
| Client parsing and business-success predicates | `SwiftCinemas/SwiftLoginScreen/DataManagers/` |
| Web request construction | `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/app.js` |
| Schema, entities or cache policy | `mysql_8/`, module entity sources and Hibernate configuration |
| Proxy/telemetry wiring | `k8infra/quarkus-backend.yaml` |

Do not infer database columns/indexes from model names, authentication from endpoint names,
or idempotency from timestamp order IDs. Inspect the corresponding implementation.
Static source inspection does not prove deployment health or passing integration tests.
