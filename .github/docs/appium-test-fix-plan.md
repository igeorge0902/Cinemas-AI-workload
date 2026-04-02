# Appium Test Fix Plan — UI Element Inspection & Locator Corrections

**Date:** 2026-03-17
**Status:** Phase 2 complete — inspection results analysed

---

## Overview

The Appium test suite (`TestNavigations.pageObject()`) fails with `NoSuchElement` at
`SelectMovieFromCategory.movieFromCategory()` (line 12). The WDA session starts
successfully, the app launches on the simulator, but the UI locators in the test code
do not match the actual app elements.

### Root cause (confirmed by inspection)

**The backend system is not running.** The `UISegmentedControl` with "Reset/Categories/NA"
is added programmatically in `MoviesVC.viewForHeaderInSection` — it only renders when the
table has data (at least 1 section). Without the backend, the movies API returns nothing,
the table shows `"Empty list"`, and the segmented control never appears.

This means **steps 2b through 4f all require a running backend** — this is not a locator
bug but a missing prerequisite.

### Inspection evidence (2026-03-17, iOS 26.1, iPhone 16e)

Page source XML dumps are at `appium/target/page-sources/`.

| Step | File | Key finding |
|------|------|-------------|
| 1 | `01-app-launch.xml` | App lands on **Login screen** (SIGN IN visible). Movies/Menu buttons exist but `visible=false`. |
| 2 | `02-after-swipe.xml` | After swipe, Movies/Menu/Basket/Venues/ChangeUser are `visible=true`. |
| 3 | `03-movies-screen.xml` | After tapping Movies: table is `name="Empty list"`, search bar present, **0 segmented controls**, only "Back" button visible. |
| 4 | `04-after-categories.xml` | All 4 strategies (predicate, classChain/Button, classChain/Segment, accessibilityId) fail to find "Categories". |

---

## What works without a backend

| Step | Code | Status |
|------|------|--------|
| `HomeScreen.swipe()` | Swipe on the landing page indicator | ✅ |
| `PageObjects.movies().click()` | Tap "Movies" button | ✅ |
| Movies screen loads | Search bar + empty table visible | ✅ |
| Segmented control appears | ❌ **Needs backend** — no table data → no section header → no segmented control |
| Everything after (categories, movies, venues, dates, seats, checkout) | ❌ All depend on API data |

---

## Test flow vs. Swift source code (updated with inspection results)

---

### Step 2: `SelectMovieFromCategory.movieFromCategory()` — ❌ FAILS HERE

The method performs 5 sequential element interactions:

#### 2a. `PageObjects.movies().click()`

**Locator:** `By.xpath("//XCUIElementTypeButton[@name='Movies']")`

**App code:** `Storyboard.storyboard` line 113 — button with `title="Movies"` on the
HomeVC. This is a `UIButton` with title "Movies" on the Welcome screen (not a tab bar item).

**Likely issue:** After swiping, the button may not be visible. On different iPhone models
(especially smaller screens like iPhone 16e), the buttons may be laid out differently or
require scrolling. Also, on iOS 26, button accessibility names may have changed.

**Inspection needed:**
```
# After the swipe, dump the page source to see what elements are present:
driver.getPageSource()

# Or find all buttons:
driver.findElements(AppiumBy.className("XCUIElementTypeButton"))
```

#### 2b. Segmented control — "Categories" button

**Locator:**
```java
AppiumBy.iOSClassChain("**/XCUIElementTypeSegmentedControl/XCUIElementTypeButton[2]")
```
This looks for the 2nd button inside a `UISegmentedControl`.

**App code:** `MoviesVC.swift` line 385:
```swift
let control = UISegmentedControl(items: ["Reset", "Categories", "NA"])
```
The segmented control has 3 items. Button index `[2]` (1-based in class chain) = "Categories".

**Likely issues:**
1. The segmented control is added inside `tableView(_:viewForHeaderInSection:)` — it only
   appears in the header of section 0 of the table view. If the table has no data (because
   the backend is not running), the table header may not render.
2. On iOS 26, `UISegmentedControl` rendering may differ — it might be a
   `XCUIElementTypeSegmentedControl` with child segments, not child buttons.
3. **This is the line that fails** — the element is not found.

**Inspection needed:**
```
# After tapping Movies, dump the view hierarchy:
driver.getPageSource()

# Specifically look for segmented controls:
driver.findElements(AppiumBy.className("XCUIElementTypeSegmentedControl"))

# And all its children:
driver.findElements(AppiumBy.iOSClassChain("**/XCUIElementTypeSegmentedControl/*"))
```

**Possible fixes:**
- Change to predicate-based search: `AppiumBy.iOSNsPredicateString("label == 'Categories'")`
- Or use accessibility: `AppiumBy.accessibilityId("Categories")`
- Add explicit wait before looking for the segmented control

#### 2c. Tap "Drama"

**Locator:** `AppiumBy.iOSNsPredicateString("label == 'Drama'")`

**App code:** `MoviesVC.swift` line 411:
```swift
CategoryData = ["Action", "Drama", "Crime", "Romance", "Troll"]
```
These are table view cells displayed after selecting "Categories" in the segmented control.

**Likely issue:** Depends on step 2b succeeding. If categories load, "Drama" should appear
as a table cell label.

#### 2d. Tap "12 Angry Men"

**Locator:** `AppiumBy.iOSNsPredicateString("label == '12 Angry Men'")`

**App code:** After selecting "Drama", `MoviesVC` calls `addData(category: "Drama")` which
fetches movies from the backend API.

**Critical issue:** If the backend is **not running**, this API call returns nothing and
the table will be empty — "12 Angry Men" will never appear.

#### 2e. Tap "Cinema City Allee"

**Locator:** `AppiumBy.iOSNsPredicateString("label == 'Cinema City Allee'")`

**App code:** After selecting a movie, a segue goes to `VenuesVC` which loads venues from
the backend. Again, requires a running backend.

---

### Step 3: `VenueDetails.selectPickerDate()` — depends on step 2

#### 3a. Tap "Dates"

**Locator:** `AppiumBy.iOSNsPredicateString("label == 'Dates'")`

**App code:** `VenuesDetailsVC.swift` line 168 — programmatically created `UIButton` with
title "Dates". This should work if the screen loads.

#### 3b. Select picker date

**Locator:** `AppiumBy.className("XCUIElementTypePickerWheel")`
**Value sent:** `"Sep 12, 2021 at 9:00 PM"`

**App code:** `PopOverDates` presents a `UIPickerView` showing screening dates from the
backend. The hardcoded date string `"Sep 12, 2021 at 9:00 PM"` is stale — it won't match
any real data.

**Fix needed:** Either use a dynamic approach to pick the first available date, or update
the test data.

#### 3c. Dismiss popup

**Locator:** `AppiumBy.iOSNsPredicateString("label == 'dismiss popup'")`

**App code:** The `PopOverDates` is a popover. Dismissing it on iOS is typically done by
tapping outside the popover. The label `"dismiss popup"` is an iOS accessibility label
automatically added to the dimming view behind popovers.

**Likely issue:** On iOS 26, the dismiss label may have changed (e.g., `"Dismiss pop-up"`
or similar localized variation). Need to inspect.

---

### Step 4: `VenueDetails.bookChair()` — depends on step 3

#### 4a. Tap "Book"

**Locator:** `AppiumBy.iOSNsPredicateString("label == 'Book'")`

**App code:** `VenuesDetailsVC.swift` line 168 — button with title "Book".

#### 4b. Tap seats A1, A2, A3

**Locators:** `AppiumBy.iOSNsPredicateString("label == 'A1'")` etc.

**App code:** `PopOver.swift` → `TableViewCell` → `SeatCells` — seats are rendered as
collection view cells. Seat labels come from the backend (seat row + column).

**Requires:** Backend running with seats loaded for the selected screening.

#### 4c. Scroll to row B, tap B5

**Locator:** Complex class chain for the 2nd table cell, then scroll + tap B5.

**Fragile:** Uses exact window/element indices (`XCUIElementTypeWindow[1]/XCUIElementTypeOther[6]/...`).
Very likely broken on different iOS versions and screen sizes.

#### 4d. Tap "Basket"

**Locator:** `AppiumBy.iOSClassChain("**/XCUIElementTypeButton[\\`label == 'Basket'\\`][2]")`

**App code:** `PopOver.swift` line 92 — button with title "Basket". Index `[2]` suggests
there are multiple Basket buttons (one on HomeVC, one on the PopOver).

#### 4e. Tap "CheckOut"

**Locator:** `AppiumBy.iOSNsPredicateString("label == 'CheckOut'")`

**App code:** `BasketVC.swift` line 51 — button with title "CheckOut".

#### 4f. Verify 502 error

**Locator:** `AppiumBy.iOSNsPredicateString("label == 'HTTP response was 502'")`

**Expected:** When backend is not running, the checkout call returns HTTP 502 and the app
displays it in an alert.

---

## Root cause analysis

| # | Issue | Severity | Backend needed? |
|---|-------|----------|-----------------|
| 1 | Segmented control locator may not work on iOS 26 (child element type changed) | **High** | No |
| 2 | Movies list empty without running backend (no "12 Angry Men") | **Critical** | Yes |
| 3 | Venues list empty without running backend (no "Cinema City Allee") | **Critical** | Yes |
| 4 | Screening dates list empty without running backend | **Critical** | Yes |
| 5 | Seats list empty without running backend | **Critical** | Yes |
| 6 | Hardcoded picker date `"Sep 12, 2021 at 9:00 PM"` is stale | **Medium** | Yes |
| 7 | `"dismiss popup"` label may differ on iOS 26 | **Medium** | No |
| 8 | Seat popover class chain uses exact window indices — fragile | **Medium** | No |
| 9 | No explicit waits between navigation steps | **Medium** | No |

**The fundamental problem:** Steps 2d–4f all require a **running backend** to populate
movie, venue, and seat data. Without it, the app shows empty lists.

---

## Inspection plan

### Phase 1 — Inspect element tree at each step (no backend needed)

Use a short Appium session to dump the page source at each navigation point.
This will reveal the actual element types, names, and hierarchy on iOS 26.

**Script approach:**
```java
// Add to TestNavigations or create a separate InspectUI test:

@Test
public void inspectHomeScreen() throws Exception {
    // After app launch, dump the full tree
    String source = driver.getPageSource();
    Files.writeString(Path.of("target/page-source-home.xml"), source);

    // Swipe
    HomeScreen.swipe();
    source = driver.getPageSource();
    Files.writeString(Path.of("target/page-source-after-swipe.xml"), source);

    // Tap Movies
    PageObjects.movies().click();
    Thread.sleep(3000); // wait for table to load
    source = driver.getPageSource();
    Files.writeString(Path.of("target/page-source-movies.xml"), source);
}
```

This produces XML files we can analyse to find correct locators.

### Phase 2 — Fix locators that don't need backend

Based on the XML dumps, fix:

1. **Segmented control** — determine if `XCUIElementTypeButton[2]` is still correct or
   needs to be `XCUIElementTypeSegment[2]` (iOS 26 changed this).
   Alternative: use `AppiumBy.iOSNsPredicateString("label == 'Categories'")` which is
   more resilient.

2. **Add explicit waits** — replace `Thread.sleep()` with `WebDriverWait` + expected
   conditions.

3. **Replace fragile class chain locators** — use predicate or accessibility-based
   locators where possible.

### Phase 3 — Fix tests that need a backend

Two options:

**Option A — Run with the full Kubernetes backend:**
Start the local K8s stack (MySQL, Kafka, mbook, mbooks, dalogin, etc.) so the app
can load real movie/venue/seat data.

**Option B — Stub the API responses:**
Modify the app to load from bundled JSON, or use Appium's `mobile: mockResponse`
capability to intercept API calls.

**Option C — Split the test into backend-dependent and independent parts:**
```java
@Test
public void testHomeNavigation() throws Exception {
    // No backend needed
    HomeScreen.swipe();
    PageObjects.movies().click();
    // Assert the Movies screen loaded (segmented control visible)
    WebElement segControl = driver.findElement(
        AppiumBy.className("XCUIElementTypeSegmentedControl"));
    Assert.assertNotNull(segControl);
}

@Test(dependsOnMethods = "testHomeNavigation")
public void testMovieBooking() throws Exception {
    // Requires backend
    // ... existing flow
}
```

### Phase 4 — Update hardcoded test data

- Replace `"Sep 12, 2021 at 9:00 PM"` with dynamic date selection (pick first
  available date from the picker).
- Replace `"12 Angry Men"` and `"Cinema City Allee"` with configurable test data
  or dynamic first-element selection.

---

## Recommended immediate fixes

### Fix 1: Replace fragile segmented control locator

```java
// Before (fragile — depends on element type):
driver.findElement(AppiumBy.iOSClassChain(
    "**/XCUIElementTypeSegmentedControl/XCUIElementTypeButton[2]")).click();

// After (resilient — matches by label):
driver.findElement(AppiumBy.iOSNsPredicateString("label == 'Categories'")).click();
```

### Fix 2: Add explicit waits

```java
WebDriverWait wait = new WebDriverWait(driver, Duration.ofSeconds(10));

// Wait for Movies screen to load
wait.until(ExpectedConditions.presenceOfElementLocated(
    AppiumBy.iOSNsPredicateString("label == 'Categories'")));
```

### Fix 3: Replace hardcoded class chain locators in bookChair()

```java
// Before (fragile — exact window/element indices):
driver.findElement(AppiumBy.iOSClassChain(
    "**/XCUIElementTypeWindow[1]/XCUIElementTypeOther[6]/XCUIElementTypePopover/..."));

// After (resilient):
driver.findElement(AppiumBy.iOSClassChain(
    "**/XCUIElementTypePopover/**/XCUIElementTypeCell[2]"));
```

### Fix 4: Dynamic date selection in picker

```java
// Before (hardcoded stale date):
el.sendKeys("Sep 12, 2021 at 9:00 PM");

// After (pick the first available date):
// Scroll the picker to row 1 (first real date, row 0 is "Select date")
Map<String, Object> params = new HashMap<>();
params.put("order", "next");
params.put("offset", 0.15);
params.put("element", ((RemoteWebElement) el).getId());
driver.executeScript("mobile: selectPickerWheelValue", params);
```

---

## Files to modify

| File | Changes |
|------|---------|
| `SelectMovieFromCategory.java` | Fix segmented control locator, add waits |
| `VenueDetails.java` | Fix picker date, dismiss popup label, class chain locators |
| `PageObjects.java` | Add wait utilities |
| `TestNavigations.java` | Consider splitting into backend-dependent/independent tests |

---

## Next steps

1. ~~**Run the inspection test** to dump page source XML at each step~~ ✅ Done (2026-03-17)
2. ~~**Analyse the XML** to determine correct locators for iOS 26 / iPhone 16e~~ ✅ Done — see "Inspection evidence" above
3. **Start the Cinemas backend** — follow [local K8s runbook](../../k8infra/README-k8s-local.md)
4. **Re-run the inspection test** with backend running to see actual movie data, segmented control, and venue elements
5. **Apply fixes** from the "Recommended immediate fixes" section based on the with-backend page sources
6. **Test with backend** — verify the full booking flow end-to-end

### Quick checklist before re-running tests

- [ ] Minikube running, all pods in `cinemas` namespace are `Running`
- [ ] Databases seeded (`login_` and `book`)
- [ ] `milo.crabdance.com` in `/etc/hosts` → `127.0.0.1`
- [ ] Port-forward: ingress 443 → 8443, pf redirect active
- [ ] `curl -sk https://milo.crabdance.com/mbooks-1/rest/book/movies` returns JSON
- [ ] iOS app built for simulator (arm64), installed on booted simulator
- [ ] Appium server running on port 4723
- [ ] `SwiftCinemas.app` copied into `appium/` directory

