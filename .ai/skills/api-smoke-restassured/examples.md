# Examples: API Smoke RestAssured

## Example 1: Post-Deploy Backend Sanity
### Input
A new image is deployed for `dalogin-quarkus` and `mbooks-quarkus`; verify core contracts quickly.

### Output
- Runs `mvn test` in `k8infra/api-smoke-restassured`.
- Verifies login handshake and key read endpoints.
- Reports any failing endpoint with direct class/test location.

## Example 2: Live Override Run
### Input
Run smoke against non-default environment using explicit credentials/hash.

### Output
- Uses system property overrides for `baseUrl`, `user`, `passHash`, `deviceId`, `smokeLive`.
- Produces environment-targeted smoke evidence without code changes.

## Example 3: Replace Legacy Script Usage
### Input
A task proposes adding a Python smoke checker under `k8infra`.

### Output
- Rejects new Python smoke path for primary validation.
- Adds equivalent Java RestAssured coverage in the existing module.
- Keeps smoke framework centralized and maintainable.

