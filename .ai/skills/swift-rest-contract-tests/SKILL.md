# Swift REST Contract Tests

## Purpose
Define and maintain deterministic XCTest coverage for iOS service contracts in `SwiftCinemas` using mocked transport by default and opt-in live backend mode.

## Use When
- You need regression coverage for `MbooksService` or `LoginGatewayService` without UI coupling.
- You are migrating/refactoring DataManagers and want to detect request-shape drift.
- You need CI-safe API checks for iOS networking layers.

## Do Not Use When
- You are validating full backend behavior (use backend smoke/module tests).
- The task is visual UI testing (use Appium/XCUITest flows instead).

## Inputs
- Required: service files under `SwiftCinemas/SwiftLoginScreen/Networking/`.
- Required: test plan `SwiftCinemas/SwiftCinemas.xctestplan`.
- Required: workflow spec `/.ai/workflows/features/SwiftTest/speckit.swifttests.specify`.
- Optional: live backend toggle via `SWIFT_REST_BACKEND=real`.

## Outputs
- Service-focused XCTest files under `SwiftCinemas/SwiftCinemasTests/`.
- Mock fixtures for endpoint schemas.
- Request-contract assertions (method/path/query/headers/body type).
- Optional gated live smoke tests with explicit skip messaging.

## Constraints
- Default mode is mocked transport.
- Keep live mode opt-in and non-blocking for default local/CI runs.
- Test services directly; do not depend on ViewController side effects.
- Preserve existing `APIClient`, `Endpoint`, and `HeaderProvider` contracts.

## Workflow
1. Confirm active test plan wiring in `SwiftCinemas.xctestplan`.
2. Add/maintain mock transport + fixture mapping per endpoint.
3. Cover high-traffic iOS calls first:
   - `moviesPaging`, `moviesSearch`, `venue`, `locations`, `dates`, `seats`
   - `getUser`, `getCheckOut`, `postCheckOut`, purchases endpoints, `postActivation`
4. Assert contract shape (method/path/query/headers/body encoding).
5. Add response-shape assertions for key payload roots (`movies`, `locations`, `seatsforscreen`, etc.).
6. Gate live smoke tests behind `SWIFT_REST_BACKEND=real`.
7. Keep failures endpoint-specific and actionable.

## Validation Checklist
- [ ] Mocked mode passes without backend dependency.
- [ ] Endpoint contract assertions exist for current iOS service calls.
- [ ] HMAC/login header behavior is verified where relevant.
- [ ] Live tests are opt-in and clearly skipped when not enabled.
- [ ] Placeholder or stale test files are removed/reworked.

