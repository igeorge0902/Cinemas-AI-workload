# dalogin Logging Migration Plan

## Goal
Migrate `dalogin-quarkus` from legacy Log4j-style API usage to Quarkus-native logging (`org.jboss.logging.Logger`) while keeping:
- existing operational visibility,
- `LOG-HTTP-CLIENT` observability flow,
- separate file routing for log categories,
- security redaction rules for token/session/payment fields.

## Scope
- Module: `dalogin-quarkus`
- In-scope files:
  - `dalogin-quarkus/pom.xml`
  - `dalogin-quarkus/src/main/resources/application.properties`
  - `dalogin-quarkus/src/main/resources/META-INF/resources/WEB-INF/log4j.xml`
  - `dalogin-quarkus/src/main/resources/META-INF/resources/WEB-INF/log4j.properties`
  - `dalogin-quarkus/src/main/java/com/dalogin/servlets/*`
  - `dalogin-quarkus/src/main/java/com/dalogin/filters/*`
  - `dalogin-quarkus/src/main/java/com/dalogin/client/*`

### Compatibility notes
- Category naming and file split conventions should remain compatible with existing `LOG-*` usage in the repository.
- For dalogin outbound HTTP calls, keep the low-intrusion strategy documented for this module:
  - JAX-RS request/response filter instrumentation + method START logs
  - no CDI interceptor dependency for `ServiceClient` (`new ServiceClient(...)` call path)
- RestAssured smoke tests are recommended for verification, but are not a hard dependency of this plan.

## Target State
1. Code uses Quarkus-compatible logger API (`org.jboss.logging.Logger`) instead of `org.apache.log4j.Logger`.
2. Legacy Log4j runtime config is no longer the active source of truth.
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
  - keep Quarkus logging path as primary runtime,
  - remove/avoid unnecessary legacy bridge/runtime combos that can cause ambiguity.
- Decide final runtime config source:
  - Quarkus `application.properties` (primary),
  - legacy `log4j.xml/properties` retained temporarily only if required for rollback.

### Phase 2 - Logger API migration in code
- Replace imports from:
  - `org.apache.log4j.Logger`
- To:
  - `org.jboss.logging.Logger`
- Migrate class-by-class in priority order:
  1. `CheckOut`, `GetAllPurchases`, `ManagePurchases`
  2. `RequestFilter`, `ServiceClient`
  3. remaining servlets and filters
- Keep log messages semantically equivalent during migration.

### Phase 3 - Category and file routing
- Define and apply category map:
  - `LOG-HTTP-CLIENT` -> `logs/http-client.log`
  - `com.dalogin` (default app) -> `logs/dalogin.log`
- Configure rotation and retention in Quarkus file handlers.
- Ensure no category mixing between `http-client.log` and generic app logs.

### Phase 4 - Observability hardening
- Keep START/END/ERROR event structure for downstream calls.
- Ensure `RequestFilter` logs only header names and fallback flags, never values.
- Verify masked fields policy:
  - `token2`, `Ciphertext`, `uuid`, `payment_method_nonce`, cookie values.

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
- Quarkus logging config is the effective runtime source.
- `LOG-HTTP-CLIENT` in dedicated `http-client.log` file.
- Security redaction checks pass.
- Logs remain queryable and usable in Grafana/Loki pipeline.

## Review Questions
1. Keep two files only (`dalogin.log`, `http-client.log`) or split further by package?
2. Do we need backward-compatible file path names for external tooling?
3. Should migration be done in one PR or phased PRs by component group?
