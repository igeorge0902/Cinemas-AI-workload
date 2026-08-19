# dalogin Outbound HTTP Client Observability - Implementation Plan

## Purpose
Implement security-safe, structured observability for outbound HTTP calls in `dalogin-quarkus` and migrate servlet/client/filter logging to `org.jboss.logging.Logger`.

This plan is aligned with:
- `.ai/workflows/features/System/speckit.system.dalogin-http-client-observability.plan`
- `.ai/workflows/features/System/speckit.system.dalogin-http-client-observability.specify`
- `.ai/workflows/features/System/speckit.system.dalogin-http-client-observability.tasks`
- `.ai/workflows/features/System/speckit.system.dalogin-logging-migration.plan.md`

## Scope
- Module: `dalogin-quarkus`
- In scope:
  - `dalogin-quarkus/src/main/java/com/dalogin/servlets/*`
  - `dalogin-quarkus/src/main/java/com/dalogin/listeners/*`
  - `dalogin-quarkus/src/main/java/com/dalogin/client/ServiceClient.java`
  - `dalogin-quarkus/src/main/java/com/dalogin/client/filter/*`
  - `dalogin-quarkus/src/main/resources/application.properties`
- Out of scope:
  - Functional API behavior changes
  - Payload schema changes
  - Logging rollout in non-dalogin services

## Non-negotiable Requirements
1. Logger API migration target is `org.jboss.logging.Logger`.
2. Servlet `doGet` and `doPost` must log entry and completion with servlet name at DEBUG level.
3. `ServiceClient` must log request URI/path/params and response status at DEBUG level.
4. `payment_method_nonce` must be masked/truncated if referenced.
5. Request and response bodies must not be logged anywhere (including DEBUG).
6. Filter completion log must be DEBUG and use format:
   `HTTP request completed: method={}, uri={}, status={}`

## Current Call Inventory (must all be covered)
- `/login/CheckOut` GET -> `ServiceClient.clientToken()` -> `GET /mbooks-1/rest/book/payment/clientToken`
- `/login/CheckOut` POST -> `ServiceClient.checkOut()` -> `POST /mbooks-1/rest/book/payment/fullcheckout2`
- `/login/GetAllPurchases` GET -> `ServiceClient.callGetPurchases()` -> `GET /mbooks-1/rest/book/purchases`
- `/login/ManagePurchases` GET -> `ServiceClient.callGetTickets()` -> `GET /mbooks-1/rest/book/purchases/tickets`
- `/login/ManagePurchases` POST -> `ServiceClient.managePurchases()` -> `POST /mbooks-1/rest/book/managepurchases`
- `/login/ManagePurchases` POST -> `ServiceClient.deletePurchases()` -> `POST /mbooks-1/rest/book/deletepurchases`
- (internal) `ServiceClient.callGetData()` -> `GET /mbook-1/rest/user/{user}/{token1}`
- (internal) `ServiceClient.callGetDevice()` -> `GET /mbook-1/rest/device/{uuid}`

## Implementation Design

### 1) Logger API migration
- Replace all `org.apache.log4j.Logger` imports in servlets/listeners/client/filters.
- Use class loggers via `org.jboss.logging.Logger`.
- Keep existing semantic messages where useful; convert message style to structured key/value placeholders.

### 2) Servlet observability (entry + completion)
For each servlet `doGet` and `doPost`:
- Add entry DEBUG log with:
  - `servletName`
  - `method`
  - `uri`
- Add completion DEBUG log in `finally` with:
  - `method`, `uri`, `status`
- Do not log request body or response body.

Suggested completion line:
```java
log.debugf("HTTP request completed: method=%s, uri=%s, status=%d",
    method, uri, status);
```

### 2.1) Servlet listener observability
For `ServletContextListener`, `HttpSessionListener`, and `HttpSessionAttributeListener` classes:
- Add DEBUG lifecycle logs (init/destroy/create/invalidate/attribute-change) with class name and event type.
- Keep payload and credential-like values out of listener logs.

### 3) ServiceClient request/response summary logs
For each outbound method in `ServiceClient`:
- Before dispatch: log request summary at DEBUG with
  - downstream alias
  - HTTP method
  - URI/path
  - sanitized params map (names and masked values only)
- After response: log response summary at DEBUG with
  - downstream alias
  - status
  - URI/path
- Never log request or response payload bodies.

Parameter sanitation policy:
- `token2`, `Ciphertext`, `uuid`: omit or redact (`***`).
- `payment_method_nonce`: masked/truncated (`abcd...wxyz` at most).
- Cookies: names only.

### 4) Client filter instrumentation
Use two filters for consistent outbound telemetry:
- `ClientCallRequestFilter` for START event + start timestamp property.
- `ClientCallResponseFilter` for END/ERROR event + status + duration.

Severity policy:
- 2xx/3xx -> DEBUG
- 4xx -> WARN
- 5xx -> ERROR
- transport/SSL exceptions -> ERROR

### 5) RequestFilter safe debug traces
In `RequestFilter.filter()`:
- DEBUG log must include only header names and fallback flags.
- Must indicate Ciphertext fallback as boolean/enum only.
- Must not include token/cookie/header values.

### 6) Log category and routing
- Category for outbound HTTP observability: `LOG-HTTP-CLIENT`.
- Route this category to dedicated `http-client.log`.
- Keep stream separate from default app logs and Hibernate/SQL logs.

## Phased Execution Plan

### Phase A - API migration
- Migrate logger imports to `org.jboss.logging.Logger` in servlets/listeners/client/filters.
- Build and verify no `org.apache.log4j.Logger` imports remain under `dalogin-quarkus/src/main/java`.

### Phase B - Servlet logs
- Implement entry/completion DEBUG logs for `doGet`/`doPost` methods.
- Ensure completion log always runs (`finally` block).
- Add DEBUG logs to servlet listeners (`context`, `session`, `attribute` lifecycle events).

### Phase C - ServiceClient logs
- Add request summary and response status logs in all 8 call paths.
- Add helper sanitizers for sensitive parameters.

### Phase D - Filters
- Implement/register `ClientCallRequestFilter` and `ClientCallResponseFilter`.
- Add RequestFilter DEBUG header-name trace and fallback indicators.

### Phase E - Routing
- Configure `LOG-HTTP-CLIENT` -> `http-client.log` in runtime logging config.
- Verify no category cross-mixing.

### Phase F - Verification and evidence
- Validate success, 4xx, 5xx, and exception paths.
- Validate masking and no-body-logging constraints.
- Capture evidence bundle for all call paths.

## Log Fields (target)

### Servlet completion
- `event=HTTP_REQUEST_COMPLETED`
- `servletName`
- `method`
- `uri`
- `status`

### Servlet listener lifecycle
- `event` (`CONTEXT_INIT`, `CONTEXT_DESTROY`, `SESSION_CREATED`, `SESSION_DESTROYED`, `SESSION_ATTR_CHANGED`)
- `listenerName`
- `sessionId` (when applicable)
- `attributeName` (for attribute events, no value)

### ServiceClient request
- `event=OUTBOUND_START`
- `clientMethod`
- `downstream`
- `method`
- `uri`
- `path`
- `params` (sanitized)

### ServiceClient response
- `event=OUTBOUND_END` or `event=OUTBOUND_ERROR`
- `clientMethod`
- `downstream`
- `method`
- `uri`
- `status`

## Security Guardrails
- Forbidden in logs: raw `token2`, raw `Ciphertext`, raw `uuid`, raw `payment_method_nonce`, cookie values, request body, response body.
- Allowed: masked nonce, cookie/header names, boolean fallback indicators.

## Validation Checklist
- [ ] All servlet and client/filter classes use `org.jboss.logging.Logger`.
- [ ] All servlet and listener classes use `org.jboss.logging.Logger`.
- [ ] All servlet `doGet`/`doPost` methods have entry + completion DEBUG logs.
- [ ] Servlet listeners emit DEBUG lifecycle logs with safe structure.
- [ ] Completion line format matches required method/uri/status pattern.
- [ ] All 8 `ServiceClient` paths emit request + response summary logs.
- [ ] Request and response bodies are absent from all logs, including DEBUG.
- [ ] Sensitive fields are redacted/masked according to policy.
- [ ] `LOG-HTTP-CLIENT` is routed to `http-client.log` without cross-mixing.
- [ ] 4xx -> WARN and 5xx/exception -> ERROR are verified.

## Review Decisions (Resolved)
1. Request ID is not used in this feature's required log structure.
2. All `ServiceClient`, servlet, and servlet-listener logs are DEBUG for this observability stream.
3. Response body logging stays disabled in all environments, including DEBUG.
