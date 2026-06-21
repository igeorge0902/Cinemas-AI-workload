# API Smoke RestAssured

## Purpose
Run and maintain minimal Java RestAssured smoke coverage for deployed `login` and `mbooks` APIs from `k8infra/api-smoke-restassured`.

## Use When
- You need a fast deployment sanity check after backend changes.
- You need to verify HMAC login compatibility used by iOS/web clients.
- You need one standard smoke framework (Java) instead of ad-hoc scripts.

## Do Not Use When
- You need deep business-rule testing (use service-level test suites).
- You need UI or end-to-end app journey testing.

## Inputs
- Required: `k8infra/api-smoke-restassured/pom.xml`.
- Required: test classes under `k8infra/api-smoke-restassured/src/test/java/com/cinemas/k8infra/smoke/`.
- Optional: runtime overrides (`baseUrl`, `user`, `passHash`, `deviceId`, `smokeLive`).

## Outputs
- Smoke pass/fail report for login and core mbooks endpoints.
- Clear failure localization by endpoint and contract id.

## Constraints
- Keep scope minimal: handshake + core read paths.
- Keep this as primary smoke path; do not add new Python smoke tests.
- Preserve iOS-compatible HMAC behavior in login test flow.
- Support local and CI execution with property/env overrides.

## Workflow
1. Execute smoke suite from `k8infra/api-smoke-restassured`.
2. Validate baseline endpoint set:
   - `POST /login/HelloWorld`
   - `GET /login/admin`
   - `GET /login/activeSessions`
   - `GET /mbooks-1/rest/book/locations`
   - `GET /mbooks-1/rest/book/hello`
3. Keep smoke assertions contract-oriented, not dataset-specific.
4. Update docs when endpoint scope changes.

## Validation Checklist
- [ ] `mvn test` runs smoke tests from `k8infra/api-smoke-restassured`.
- [ ] Login HMAC handshake remains compatible with current clients.
- [ ] Core smoke endpoint set is covered and green.
- [ ] Documentation references RestAssured as the primary smoke framework.

