# Appium iOS UI Automation

## Purpose
Maintain and run the black-box iOS UI suite in `appium/` against the SwiftCinemas app on
simulators (local and CI) or physical devices, keeping configuration deterministic and CI-safe.

## Owner
Cinemas Testing Engineer (routing trigger `appium-ios`). Cinemas iOS Engineer supplies
app-side changes (accessibility identifiers, app fixes) and owns XCTest inside `SwiftCinemas/`.

## Use When
- Adding or fixing Appium tests, page objects, or navigation flows.
- Changing driver capabilities, simulator/device selection, or property handling.
- Running the suite locally or maintaining the CI smoke workflow.
- Diagnosing Appium session, WebDriverAgent, or simulator failures.

## Do Not Use When
- Writing XCTest unit/UI tests inside SwiftCinemas (use `swift-rest-contract-tests` / iOS Engineer).
- Backend API smoke checks (use `api-smoke-restassured`).
- Changing Swift app code; request it from Cinemas iOS Engineer.

## Stack
Java 17, Maven (system `mvn`), Appium java-client 11, TestNG, Appium server 3 with the
XCUITest driver. Appium manages WebDriverAgent (`usePreinstalledWDA=false`, no `webDriverAgentUrl`).

## Layout
- `src/main/java/qa/ios/base/` — `TestBase` (driver lifecycle), `DriverManager`
  (capabilities, simctl discovery), `DeviceConfiguration` (device detection), `Constants`.
- `src/main/java/qa/ios/page/PageObjects.java` — locators.
- `src/main/java/qa/ios/navigation/` — reusable flow steps (`HomeScreen`, `Menu`, `VenueDetails`, ...).
- `src/main/java/qa/ios/util/` — `PropertyUtils`, `Helpers`, `SystemCommands`.
- `src/main/java/qa/ios/testng/` — listeners.
- `src/test/java/` — `TestNavigations` (suite), `InspectUI` (page-source dump).
- `testng.xml`, `testng-inspect.xml`, `properties.properties`, `.github/mobile-smoke-test.yaml`.

## Configuration
All settings resolve through `PropertyUtils`: `-Dkey` → env var → `properties.properties` → default.

| Property | Env | Purpose |
|---|---|---|
| `sim.udid` | `SIM_UDID` | Target simulator; otherwise the booted simulator is auto-discovered |
| `app.path` | `APP_PATH` | `.app` to install; optional |
| `bundle.id` | `BUNDLE_ID` | Launch an already-installed app (default `com.georgegaspar.SwiftLoginScreen`) |
| `appium.host` / `appium.port` / `appium.basepath` | `APPIUM_HOST` / `APPIUM_PORT` / `APPIUM_BASEPATH` | Appium server |
| `sim.device` / `sim.version` | `SIM_DEVICE` / `SIM_VERSION` | Device name / iOS version hints |

App resolution: `APP_PATH` → TestNG `app` parameter (only if the file exists) → installed app
via `BUNDLE_ID` (`noReset=true`). If the bundle is missing on a known UDID, fail fast with a
`simctl install` hint. In CI the app is pre-installed on a dedicated simulator.

## Commands
```bash
# Build app (from repo root; Carthage deps already bootstrapped)
xcodebuild build -project SwiftCinemas/SwiftCinemas.xcodeproj -scheme SwiftCinemas \
  -sdk iphonesimulator -configuration Debug -derivedDataPath SwiftCinemas/build \
  ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO
xcrun simctl boot <UDID>
xcrun simctl install booted SwiftCinemas/build/Build/Products/Debug-iphonesimulator/SwiftCinemas.app
appium --relaxed-security --log-timestamp --local-timezone

# Run
mvn -f appium/pom.xml clean test                       # booted simulator, installed app
mvn -B -f appium/pom.xml clean test -Dsim.udid=<UDID>  # CI style
SIM_UDID=<UDID> APP_PATH=/path/SwiftCinemas.app mvn -f appium/pom.xml clean test
```
See `appium/README.md` for the full setup, including backend start-up.

## Invariants
- Never hardcode UDIDs, absolute paths, hosts, or ports in Java; add a `PropertyUtils` key instead.
- No static-init cycle between `TestBase` and `DeviceConfiguration`; keep device detection lazy.
- Prefer `AppiumBy.accessibilityId`; use XPath only when no identifier exists, and ask the
  iOS Engineer to add one.
- Prefer explicit waits (`WebDriverWait`/`ExpectedConditions`) over `Thread.sleep` in new code.
- New test classes extend `TestBase`, carry the existing `@Listeners`, and are registered in `testng.xml`.
- Keep runs non-interactive (`mvn -B`) and screenshots on failure (`CaptureScreenshotOnFailureListener`).

## Maintenance Checklist
1. Read `appium/docs/codebase/` (ARCHITECTURE, CONVENTIONS, CONCERNS) before structural changes.
2. Compile: `mvn -f appium/pom.xml -q test-compile`.
3. Run against a booted simulator with Appium up; confirm the TestNG report and no "Error getting devices".
4. Update `appium/README.md` and `appium/docs/codebase/` when properties, commands, or layout change.
5. Keep `.github/mobile-smoke-test.yaml` consistent with property names.

## References
- `appium/README.md`
- `appium/docs/codebase/*.md`
- `.ai/skills/skills-github.md` §10 (page object recipe)
