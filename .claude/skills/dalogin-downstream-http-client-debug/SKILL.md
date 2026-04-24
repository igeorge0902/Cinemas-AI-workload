# Dlogin Downstream HTTP Client Debug

## Purpose
Trace and debug outbound HTTP calls from `dalogin-quarkus` to downstream services (`mbook`, `mbooks`) and isolate routing, payload, or header-forwarding failures quickly.

## Use When
- A `dalogin` servlet endpoint fails after forwarding to downstream services.
- Web or iOS works differently for the same logical operation because downstream call shape differs.
- You need to verify how `ServiceClient` builds method/path/body/headers.

## Do Not Use When
- The issue is strictly in frontend rendering with no backend call mismatch.
- The issue is only local DB/Hibernate internals in downstream services (use DAO/session focused skills).

## Inputs
- Required: entry endpoint (`/login/...`) and failing status/behavior.
- Required: expected downstream target (`mbook` or `mbooks`) if known.
- Optional: request headers/body sample from browser/app logs.
- Optional: timestamp window for pod log correlation.

## Outputs
- End-to-end call chain map (Servlet -> ServiceClient -> downstream endpoint).
- First divergence point (path, method, headers, payload, or response handling).
- Minimal patch target in dalogin client/servlet layer.
- Verification steps for both web and iOS style calls.

## Constraints
- Preserve existing header contract names and cookie behavior.
- Keep servlet endpoint paths stable unless explicitly requested.
- Prefer smallest fix in `dalogin` client mapping before changing downstream APIs.
- Avoid leaking token/session material in diagnostic logs.

## Workflow
1. Map incoming servlet endpoint in:
   - `dalogin-quarkus/src/main/java/com/dalogin/servlets/CheckOut.java`
   - `dalogin-quarkus/src/main/java/com/dalogin/servlets/ManagePurchases.java`
   - `dalogin-quarkus/src/main/java/com/dalogin/servlets/GetAllPurchases.java`
   - `dalogin-quarkus/src/main/java/com/dalogin/servlets/AdminServlet.java`
2. Trace outbound call construction in:
   - `dalogin-quarkus/src/main/java/com/dalogin/client/ServiceClient.java`
   - `dalogin-quarkus/src/main/java/com/dalogin/client/service/Purchases.java`
   - `dalogin-quarkus/src/main/java/com/dalogin/client/service/User.java`
   - `dalogin-quarkus/src/main/java/com/dalogin/client/service/Device.java`
3. Validate request decoration/filter behavior in:
   - `dalogin-quarkus/src/main/java/com/dalogin/client/filter/RequestFilter.java`
4. Cross-check downstream filter expectations in:
   - `mbooks-quarkus/src/main/java/com/jeet/filters/CookieFilter.java`
   - `mbooks-quarkus/src/main/java/com/jeet/filters/CiphertextFilter.java`
5. Confirm base URL/path wiring from config/constants and deployment manifests.
6. Identify first mismatch (HTTP method, path, params/body, missing header/cookie, or response parsing).
7. Propose minimal fix and re-verify with one success and one failure-path request.

## Validation Checklist
- [ ] Servlet entrypoint and outbound target are mapped exactly.
- [ ] HTTP method/path/body/header mapping is validated in `ServiceClient` call chain.
- [ ] Downstream filter prerequisites are checked against forwarded headers/cookies.
- [ ] Proposed fix is minimal and localized.
- [ ] Verification includes web and iOS-compatible request shape checks.

