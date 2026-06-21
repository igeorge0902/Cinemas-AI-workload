# Examples: Swift REST Contract Tests

## Example 1: MbooksService Contract Coverage
### Input
Add deterministic tests for movie browse/search and seat-flow endpoints during a DataManager refactor.

### Output
- Adds/updates service tests to assert request contracts for:
  - `moviesPaging(query:)`
  - `moviesSearch(query:)`
  - `venue(movieId:)`
  - `locations()`
  - `dates(locationId:movieId:)`
  - `seats(screeningDateId:)`
- Uses mocked responses and verifies payload root keys.
- Keeps all tests backend-independent by default.

## Example 2: LoginGateway Contract + Side Effects
### Input
Validate sign-in and checkout service requests while ensuring session persistence behavior remains intact.

### Output
- Verifies `signIn(...)` request shape and required generated headers.
- Verifies `getUser`, `getCheckOut`, `postCheckOut`, and purchases endpoints.
- Asserts success-path persistence keys (`JSESSIONID`, `X-Token`, flags) in mocked mode.

## Example 3: Opt-in Live Smoke
### Input
Run service smoke checks against a live backend without destabilizing CI defaults.

### Output
- Reads `SWIFT_REST_BACKEND`.
- Skips with clear reason unless set to `real`.
- Runs a minimal live subset only when explicitly enabled.

