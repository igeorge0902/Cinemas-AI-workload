# Examples: Dlogin Auth Debug

## Example 1
### Input
Web checkout fails with 401 after successful login. Verify cookie and HMAC flow for `POST /login/CheckOut`.

### Output
- Captures request headers/cookies from failing web flow.
- Confirms whether `X-Token` cookie is present and readable in `CookieFilter`.
- Verifies `X-HMAC-HASH` generation/parsing path for web (`app.js` -> backend filter).
- Identifies mismatch (missing/invalid header or cookie propagation).
- Returns minimal fix target and re-test steps.

## Example 2
### Input
iOS purchase flow works, web fails for same user. Compare auth chain and isolate divergence.

### Output
- Compares iOS vs web request headers (`X-Token`, `Ciphertext`, `uuid`, `TIME_`, `X-HMAC-HASH`).
- Confirms downstream forwarding in `ServiceClient`.
- Checks pod logs around the failing timestamp for auth filter rejections.
- Produces root-cause summary and a targeted patch location.

