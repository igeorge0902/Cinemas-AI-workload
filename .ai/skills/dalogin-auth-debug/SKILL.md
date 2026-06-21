# Dlogin Auth Debug

## Purpose
Diagnose and verify authentication issues in `dalogin-quarkus` related to cookie propagation, HMAC header validation, and downstream header forwarding.

## Use When
- Login works intermittently between iOS and web clients.
- Requests fail with auth errors after successful login.
- You need to verify `X-Token`, `X-HMAC-HASH`, `Ciphertext`, `uuid`, and cookie flow.

## Do Not Use When
- You need business-logic debugging unrelated to authentication/session handling.
- You are debugging only frontend rendering issues with no auth request involved.

## Inputs
- Required: failing endpoint/path and client type (`ios` or `web`).
- Required: recent request/response sample (headers + status code).
- Optional: pod name for targeted log collection.
- Optional: known-good request sample for comparison.

## Outputs
- Root-cause oriented auth-debug report.
- Header/cookie mismatch findings with exact request points.
- Suggested fix locations (filters/servlets/client header providers).
- Validation steps to confirm the fix.

## Constraints
- Preserve header contract names exactly: `X-Token`, `X-HMAC-HASH`, `Ciphertext`, `uuid`, `TIME_`, `XSRF-TOKEN`, `X-Device`.
- Prefer read-only diagnostics first (logs, curl, request diff) before code edits.
- Do not rotate secrets or modify auth algorithms unless explicitly requested.
- Keep diagnostics aligned with local Kubernetes routing and Apache proxy behavior.

## Workflow
1. Reproduce the failing request path and capture headers, cookies, status code, and body.
2. Verify session/cookie handling in `CookieFilter.java` and auth checks in `AuthFilter.java` / `CiphertextFilter.java`.
3. Validate HMAC inputs and expected headers across client and backend:
   - web: `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/app.js`
   - iOS: `SwiftCinemas/SwiftLoginScreen/Networking/HeaderProvider.swift`
4. Confirm gateway forwarding behavior in `client/ServiceClient.java` and servlet endpoints (`HelloWorld.java`, `CheckOut.java`).
5. Compare failing request against known-good flow and identify first divergence point.
6. Propose minimal fix with file-level target and verification commands.
7. Re-run auth flow and confirm no regression in both web and iOS path.

## Validation Checklist
- [ ] Failure is reproduced with concrete request evidence.
- [ ] Cookie and session handling verified at filter level.
- [ ] HMAC headers and timestamp/nonce expectations validated.
- [ ] Downstream forwarded headers checked end-to-end.
- [ ] Proposed fix includes exact file path and verification steps.

