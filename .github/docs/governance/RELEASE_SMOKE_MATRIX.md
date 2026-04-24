# Release Smoke Matrix

This matrix is the minimum release gate for quick confidence.

## Prioritized API Contracts

Priority endpoints (sample set):
- `CID-LOGIN-HELLOWORLD` -> `/login/HelloWorld`
- `CID-MBOOKS-MOVIES` -> `/mbooks-1/rest/book/movies`
- `CID-MBOOKS-LOCATIONS` -> `/mbooks-1/rest/book/locations`
- `CID-LOGIN-CHECKOUT-GET` -> `/login/CheckOut`

## Smoke Lanes

### Lane A: Backend API smoke (must pass)
Owner: `@testing-engineer`, support `@backend-dev`
- Validate login request/response contract.
- Validate movie and location list endpoints.
- Validate checkout token endpoint (`GET /login/CheckOut`).

Pass criteria:
- All priority endpoints return expected status codes and required keys.
- No auth regression in login flow.

### Lane B: Swift smoke (short login-focused)
Owner: `@ios-dev`, support `@testing-engineer`
- Run a short Swift smoke that covers login path and one post-login API call.
- Run in `mocked` mode for deterministic baseline.
- Run in `real` mode for release verification.

Pass criteria:
- Mocked lane passes.
- Real lane passes or has approved, documented infra exception.

### Lane C: Appium smoke (booking path sanity)
Owner: `@testing-engineer`, support `@frontend-dev`
- Run minimal Appium smoke navigation: login -> movies -> venues/categories sanity.

Pass criteria:
- Core navigation smoke path succeeds.
- Failures include page source/log artifacts.

## Future Regression Expansion

Planned next regression lanes:
- Registration flow regression.
- Activation flow regression.

