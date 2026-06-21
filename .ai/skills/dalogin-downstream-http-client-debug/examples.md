# Examples: Dlogin Downstream HTTP Client Debug

## Example 1
### Input
`POST /login/CheckOut` returns an error while direct downstream payment endpoint works.

### Output
- Traces `CheckOut` servlet to `ServiceClient` and purchases client mapping.
- Verifies forwarded headers/cookies and request body encoding.
- Confirms downstream filter prerequisites.
- Identifies the first mapping mismatch and patch location.

## Example 2
### Input
`POST /login/managepurchases` returns unexpected status for web only.

### Output
- Maps servlet path to downstream endpoint call and HTTP method.
- Compares web vs iOS call payload/header shapes.
- Detects response parsing or path-method mismatch in client code.
- Provides minimal fix + concise verify steps.

