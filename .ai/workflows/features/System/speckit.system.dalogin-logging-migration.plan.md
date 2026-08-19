# dalogin Logging Migration Plan

## Goal
Migrate `dalogin-quarkus` from legacy Log4j-style API usage to Quarkus-style logging configuration while keeping:
- existing operational visibility,
- `LOG-HTTP-CLIENT` observability flow,
- separate file routing for log categories,
- security redaction rules for token/session/payment fields.

This plan is combined with `speckit.system.dalogin-http-client-observability.*` and should be executed as one cohesive stream.

## Scope
- Module: `dalogin-quarkus`
- In-scope files:
  - `dalogin-quarkus/pom.xml`
  - `dalogin-quarkus/src/main/resources/application.properties`
  - `dalogin-quarkus/src/main/resources/META-INF/resources/WEB-INF/log4j.xml`
  - `dalogin-quarkus/src/main/resources/META-INF/resources/WEB-INF/log4j.properties`
  - `dalogin-quarkus/src/main/java/com/dalogin/servlets/*`
  - `dalogin-quarkus/src/main/java/com/dalogin/listeners/*`
  - `dalogin-quarkus/src/main/java/com/dalogin/filters/*`
  - `dalogin-quarkus/src/main/java/com/dalogin/client/*`

### Compatibility notes
- Category naming and file split conventions should remain compatible with existing `LOG-*` usage in the repository.
- For dalogin outbound HTTP calls, keep the low-intrusion strategy documented for this module:
  - JAX-RS request/response filter instrumentation (START/END/ERROR)
  - no CDI interceptor dependency for `ServiceClient` (`new ServiceClient(...)` call path)
- OpenTelemetry is already enabled; logs should complement traces with concise operational context.
- RestAssured smoke tests are recommended for verification, but are not a hard dependency of this plan.

## Target State
1. Code uses one consistent logger API (`org.jboss.logging.Logger`) and no new Log4j usages are introduced.
2. Quarkus logging configuration is the active runtime source of truth for dalogin logging.
3. Logging categories are routed via Quarkus properties with dedicated files:
   - general app logs
   - HTTP downstream call logs (`LOG-HTTP-CLIENT`)
4. Sensitive values remain redacted/omitted from all log streams.
5. Migration is fully executable and verifiable as a standalone plan.

## Migration Phases

### Phase 0 - Baseline and safety checks
- Create inventory of current logger imports and logger names.
- Capture sample logs for critical flows:
  - login (`HelloWorld`)
  - checkout (`CheckOut`)
  - purchases (`GetAllPurchases`, `ManagePurchases`)
- Freeze expected minimum fields to preserve (timestamp, level, source, message).

### Phase 1 - Dependency and runtime alignment
- In `dalogin-quarkus/pom.xml`:
  - keep Quarkus logging path as primary,
  - remove/avoid unnecessary legacy bridge/runtime combos that can cause ambiguity.
- Decide final runtime config source:
  - Quarkus `application.properties` as primary runtime source,
  - legacy `log4j.xml/properties` retained temporarily only if required for rollback.

### Phase 2 - Logger API migration in code
- Replace imports from:
  - `org.apache.log4j.Logger`
- To:
  - `org.jboss.logging.Logger`
- Migrate class-by-class in priority order:
  1. `CheckOut`, `GetAllPurchases`, `ManagePurchases`
  2. listener classes (`CustomServletContextListener`, `CustomHttpSessionListener`, `SessionAttributeListener`)
  3. `RequestFilter`, `ServiceClient`
  4. remaining servlets and filters
- Keep log messages semantically equivalent during migration.
- Add servlet method-level DEBUG logs in `doGet`/`doPost` with servlet name and method/URI context.
- Add servlet-listener DEBUG lifecycle logs with safe structured fields.

### Phase 3 - Category and file routing
- Define and apply category map:
  - `LOG-HTTP-CLIENT` -> `logs/http-client.log`
  - `com.dalogin` (default app) -> `logs/dalogin.log`
- Configure rotation and retention in Quarkus file handlers.
- Ensure no category mixing between `http-client.log` and generic app logs.

### Phase 4 - Observability hardening
- Keep START/END/ERROR event structure for downstream calls.
- In `ServiceClient`, log request URI/path and sanitized params at DEBUG; do not log request/response body.
- In `ServiceClient`, log response status for every outbound call at DEBUG.
- Ensure `RequestFilter` logs only header names and fallback flags, never values.
- Add/align filter completion log format:
  `HTTP request completed: method={}, uri={}, status={}`.
- Keep request/response logging concise and meaningful (downstream service, method, status, duration, correlation).
- Verify masked fields policy:
  - `token2`, `Ciphertext`, `uuid`, `payment_method_nonce`, cookie values.
  - response body content in all environments (including DEBUG).

### Phase 5 - Validation and rollout
- Functional checks:
  - all 8 ServiceClient call paths produce expected logs.
- Security checks:
  - grep-based scan on produced logs for forbidden sensitive fields.
- Performance checks:
  - verify no meaningful latency regression in checkout/purchases path.
- Rollout strategy:
  - canary in local/k8s dev first,
  - then full switch to Quarkus-only logging config.

## Rollback Plan
- Keep legacy config files untouched for one migration iteration.
- Feature-toggle style fallback:
  - if routing fails, temporarily route all categories to a single file in Quarkus config.
- If logger API migration causes build/runtime issues, revert module by module (starting from lowest-risk classes).

## Definition of Done
- `org.apache.log4j.Logger` imports removed from `dalogin-quarkus` source.
- Servlet `doGet`/`doPost` DEBUG logs include servlet name and completion summary.
- Servlet listener DEBUG lifecycle logs exist with safe structures.
- `ServiceClient` DEBUG logs include request URI/path/params and response status only (no request/response body logging).
- Quarkus logging config is the effective source for dalogin module logging behavior.
- `LOG-HTTP-CLIENT` in dedicated `http-client.log` file.
- Security redaction checks pass.
- Logs remain queryable and usable in Grafana/Loki pipeline.

## Review Questions
1. Keep two files only (`dalogin.log`, `http-client.log`) or split further by package?
2. Do we need backward-compatible file path names for external tooling?
3. Should migration be done in one PR or phased PRs by component group?
