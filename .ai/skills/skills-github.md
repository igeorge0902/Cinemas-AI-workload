# Skills & Common Tasks for Cinemas Project

## Document scope
- This file contains **implementation patterns and copy-paste snippets only**.
- Keep architecture, contracts, and system boundaries in `.ai/agents/AGENTS.md`.
- Keep task routing and "where to edit" navigation in `.ai/retrieval/instructions.md`.
- Keep immutable project principles in `.ai/constitution/constitution.md`.

## Governing rules for this document
- Use this file as a broad pattern catalog; if a dedicated skill exists for the task, use the dedicated skill first.
- Governance precedence for conflicts: `.ai/constitution/constitution.md` -> `.ai/agents/AGENTS.md` -> dedicated `/.ai/skills/*/SKILL.md` -> this file.
- Do not duplicate or fork contract definitions here; this file should reference canonical sources.

## Skill routing (use first when applicable)
- `/.ai/skills/html-prototype-uikit-redesign/SKILL.md` for UIKit parity work from prototypes/screenshots.
- `/.ai/skills/swift-datamanager-integration/SKILL.md` for iOS API-to-DataManager migration and global-state reduction.
- `/.ai/skills/swift-rest-contract-tests/SKILL.md` for deterministic iOS service contract tests.
- `/.ai/skills/api-smoke-restassured/SKILL.md` for backend smoke validation in `k8infra/api-smoke-restassured`.

## AI Assistant Proficiencies

This guide documents repeatable patterns and common tasks that AI assistants should handle efficiently in this codebase.

## Backend Service Patterns

### 1. Adding a REST Endpoint
**When:** Need to expose a new API.

**Pattern:**
```java
// 1. Create resource class (or add to existing)
@Path("/resource")
public class MyResource {
    
    // 2. If authenticated, inject request
    @POST
    @Path("/action")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response doAction(
        @Context HttpServletRequest request,
        MyPayloadDTO payload
    ) {
        // 3. Validate session/HMAC
        String sessionUUID = RequestFilter.getSessionUUID(request);
        if (sessionUUID == null) {
            return Response.status(401).build();
        }
        
        // 4. Call business logic
        MyServiceResult result = myService.process(sessionUUID, payload);
        
        // 5. Return JSON response
        return Response.ok(result).build();
    }
}
```

**Files to check:**
- `dalogin-quarkus/src/main/java/com/dalogin/client/ServiceClient.java` — if forwarding to downstream
- `mbooks-quarkus/src/main/java/com/jeet/rest/BookController.java` — for booking/payment patterns
- `web.xml` — ensure your resource is scanned

### 2. Adding a Hibernate Entity
**When:** Need to persist a new data type.

**Checklist:**
- Use `@Entity` + `@Table` with explicit schema (e.g., `@Table(name = "my_table", schema = "book")`)
- Set `@FetchType` deliberately:
  - LAZY: for collections or rarely-accessed references (saves DB roundtrips)
  - EAGER: only when the related entity is always needed (may cause large loads)
- Set `@CascadeType`:
  - PERSIST/MERGE for owned entities
  - `CascadeType.ALL` sparingly (can delete related data unintentionally)
- Add `@Cache` + `@Cacheable` if entity is read-heavy:
  - Movies, Venues, Location, Ticket — yes
  - Seats, Screens, ScreeningDates — no (need fresh data)
- **Document fetch strategy** in entity class Javadoc

**Files to reference:**
- `mbooks-quarkus/src/main/java/com/jeet/api/` — existing entities
- AGENTS.md "Hibernate entity relationships" section

### 3. Session & Authentication Flow
**When:** Adding filters, fixing login, validating requests.

**Flow (Web + iOS):**
```
1. POST /login/HelloWorld (HMAC-SHA512 password hash)
   ↓ (success) → Set-Cookie XSRF-TOKEN + X-Token response header
   
2. Subsequent requests include:
   - Cookie: XSRF-TOKEN
   - Header: X-Token, uuid, Ciphertext, TIME_
   
3. Server validates via RequestFilter:
   - Extract XSRF-TOKEN from cookie
   - Verify Ciphertext = AES_DECRYPT(token2, TIME_, SALT, IV)
   - Extract session UUID from token
   
4. Request allowed if all checks pass
```

**Key files:**
- `dalogin-quarkus/src/main/java/com/dalogin/filters/RequestFilter.java` — extracts session UUID
- `dalogin-quarkus/src/main/java/com/dalogin/servlets/HelloWorld.java` — login logic
- `dalogin-quarkus/src/main/java/com/dalogin/utils/AesUtil.java` — encryption/decryption

**Common mistake:** Forgetting `ActiveVoucherFilter` — checks if account is activated (NOT just authenticated).

### 4. Booking & Payment Flow
**When:** Fixing checkout, seat reservation, or Braintree integration.

**Detailed flow:**

| Step | Endpoint | Method | What Happens |
|------|----------|--------|--------------|
| 1. Get client token | `GET /mbooks-1/rest/book/payment/clientToken` | GET | Braintree SDK initialized on client |
| 2. Submit payment | `POST /mbooks-1/rest/book/payment/fullcheckout2` | POST | seatsToBeReserved + payment nonce |
| 3. Lock seats | `DAO.bookTickets()` | DB | `PESSIMISTIC_WRITE` per seat + create Ticket + Purchase |
| 4. Braintree sale | `gateway.transaction().sale()` | API | Submit to Braintree Sandbox |
| 5. Success/Rollback | — | — | If Braintree fails: delete Ticket+Purchase, free seats |

**Files:**
- `mbooks-quarkus/src/main/java/com/jeet/rest/BookController.java` lines 600–1170
- `mbooks-quarkus/src/main/java/com/jeet/service/PaymentService.java`
- `mbooks-quarkus/src/main/java/com/jeet/booking/TicketService.java`
- `mbooks-quarkus/src/main/java/com/jeet/db/DAO.java` — `bookTickets()` method

**Gotchas:**
- Seat `isReserved` is string `"0"` or `"1"`, NOT boolean
- Checkout payload `seat` = seat numbers (e.g., `"A1-B2-"`), not IDs
- Braintree nonce expires — must submit quickly after generation
- Purchase + Ticket creation must be atomic (rollback all or none)

### 5. WebSocket Broadcasting
**When:** Adding real-time features (notifications, seat updates).

**Pattern (in both mbook + mbooks):**
```java
@ServerEndpoint("/ws")
public class WebSocketServer {
    private static Set<Session> sessions = ConcurrentHashMap.newKeySet();
    
    @OnOpen
    public void onOpen(Session session) {
        sessions.add(session);
        session.setMaxIdleTimeout(0); // No timeout
    }
    
    @OnMessage
    public void onMessage(String message, Session session) {
        // Handle pong frames (iOS sends ping every 30 sec)
        if ("pong".equals(message)) return;
    }
    
    @OnClose
    public void onClose(Session session) {
        sessions.remove(session);
    }
    
    // Broadcast to all
    public static void broadcast(String message) {
        sessions.forEach(s -> s.getAsyncRemote().sendText(message));
    }
}
```

**Kafka integration:**
- `KafkaListener` consumes events from Kafka topic
- Posts to WebSocket via `WebSocketServer.broadcast()`
- iOS client connects to `wss://milo.crabdance.com/mbook-1/ws` (via `URLManager`)

### 6. Quarkus Configuration & Environment Variables
**When:** Adding new config, environment-specific settings, secrets.

**Pattern:**
```java
@ApplicationScoped
public class MyConfig {
    @ConfigProperty(name = "my.setting", defaultValue = "default_value")
    String mySetting;
    
    @ConfigProperty(name = "my.secret")
    Optional<String> mySecret; // No default for secrets
}
```

**In `application.properties`:**
```properties
my.setting=production_value
```

**In K8s manifest (`quarkus-backend.yaml`):**
```yaml
env:
  - name: MY_SETTING
    value: "k8s_value"
  - name: MY_SECRET
    valueFrom:
      secretKeyRef:
        name: my-secrets
        key: my-secret-key
```

**Files:**
- Each service: `src/main/resources/application.properties`
- `k8infra/quarkus-backend.yaml` — env vars for K8s

## Frontend Patterns

### 7. Film-Review SPA: Adding a New Route
**When:** Adding a new screen/feature to the booking flow.

**Pattern (in `app.js`):**

```javascript
$routeProvider
    .when('/new-screen/:param', {
        templateUrl: 'templates/new-screen.html',
        controller: 'NewScreenController'
    });

app.controller('NewScreenController', ['$scope', '$http', '$routeParams', 
    function($scope, $http, $routeParams) {
    
    // 1. Fetch data (HMAC interceptor adds headers)
    $http.get('/mbooks-1/rest/book/endpoint')
        .then(function(response) {
            $scope.data = response.data;
        })
        .catch(function(error) {
            $scope.error = error;
        });
    
    // 2. Action handler
    $scope.doAction = function(item) {
        var request = {
            method: 'POST',
            url: '/login/CheckOut',
            data: 'payload=value&other=data'
            // HMAC interceptor automatically adds headers
        };
        $http(request).then(success, error);
    };
}]);
```

**Template (in `templates/new-screen.html`):**
```html
<div ng-controller="NewScreenController">
    <h1>New Screen</h1>
    <ul>
        <li ng-repeat="item in data">{{ item.name }}</li>
    </ul>
    <button ng-click="doAction(item)">Submit</button>
</div>
```

**Files:**
- `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/app.js`
- `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/templates/`

### 8. HMAC Interceptor: Understanding Token Flow
**When:** Debugging authentication, missing headers, or token expiry.

**In `app.js`:**
```javascript
// Interceptor adds HMAC signature to every request
app.factory('hmacInterceptor', function() {
    return {
        transformRequest: function(data, headers) {
            // 1. Compute X-HMAC-HASH = HMAC-SHA512(token, timestamp + params)
            // 2. Add X-MICRO-TIME = current timestamp
            // 3. Add X-Device = browser fingerprint (guid)
            // 4. Return data (CRITICAL: must return, not undefined)
            return data;
        }
    };
});

// On startup, fetch APIKEY token
$http.get('/mbooks-1/rest/book/movies').then(function(response) {
    localStorage.sessionToken_ = response.headers('APIKEY');
});
```

**Token lifecycle:**
- Initial `/movies` call → server returns `APIKEY` header → stored in `localStorage`
- All subsequent HMAC requests use this token in the HMAC computation
- If token is missing/invalid → interceptor rejects request

**Common bug:** `/book/movies/paging` returns APIKEY but `/book/movies` doesn't → token never set → all authenticated requests fail. **Fix:** Mark browse endpoints as public in interceptor or fetch token from a different endpoint.

## Testing Patterns

### 9. API Smoke Testing (Java RestAssured)
**When:** Verifying deployed login + mbooks APIs quickly from local or CI.

**Default location:**
- `k8infra/api-smoke-restassured`

**Pattern:**
```bash
cd /Users/gyorgy.gaspar/work/cinemas/cinemas/k8infra/api-smoke-restassured
mvn test
```

**With explicit runtime overrides:**
```bash
cd /Users/gyorgy.gaspar/work/cinemas/cinemas/k8infra/api-smoke-restassured
mvn test \
  -DbaseUrl=https://milo.crabdance.com \
  -Duser=GI \
  -DpassHash=<sha3_512_password_hash> \
  -DdeviceId=test-device-001 \
  -DsmokeLive=true
```

**Covered test classes:**
- `src/test/java/com/cinemas/k8infra/smoke/LoginApiSmokeTest.java`
- `src/test/java/com/cinemas/k8infra/smoke/AdminApiSmokeTest.java`

**Key points:**
- Keep smoke coverage minimal and endpoint-focused (login handshake + core read paths).
- Prefer this module over ad-hoc scripts for API verification.
- Keep heavy service-level logic tests inside each Java service only when needed.

### 10. Appium iOS Test: Page Object + Test Case
**When:** Adding new iOS UI automation tests.

**Page Object (in `qa/ios/pages/MyPage.java`):**
```java
public class MyPage {
    private RemoteWebDriver driver;
    private static final String BUTTON_ID = "MY_BUTTON_ID";
    
    public MyPage(RemoteWebDriver driver) {
        this.driver = driver;
    }
    
    public void clickMyButton() {
        WebElement button = driver.findElement(MobileBy.id(BUTTON_ID));
        button.click();
    }
    
    public String getResultText() {
        return driver.findElement(MobileBy.id("RESULT_ID")).getText();
    }
}
```

**Test Case (in `qa/ios/test/TestMyFeature.java`):**
```java
public class TestMyFeature extends BaseTest {
    @Test(priority = 1)
    public void testMyFeature() {
        MyPage page = new MyPage(driver);
        page.clickMyButton();
        
        String result = page.getResultText();
        Assert.assertEquals(result, "Expected Value");
    }
}
```

**Files:**
- `appium/src/main/java/qa/ios/pages/` — page objects
- `appium/src/test/java/qa/ios/test/` — test cases

### 11. iOS Service Call Refactoring
**When:** Adding/updating iOS API calls, centralizing networking logic, migrating to async/await.

**Implemented architecture (current codebase):**

1. **App service container** (`SwiftCinemas/SwiftLoginScreen/Networking/BackendServices.swift`):
   - `AppServices` wires `APIClient`, `MbooksService`, `LoginGatewayService`, `ImageResourceService`, `RapidMovieDatabaseService`.
   - ViewControllers and DataManagers consume services via `HasAppServices` + `injectAppServicesIfNeeded()`.

2. **Implemented DataManagers** (`SwiftCinemas/SwiftLoginScreen/DataManagers/`):
   - `AuthDataManager` (`signIn`, `fetchUser`, `activate`, `refreshToken`, `signUp`)
   - `MoviesDataManager` (`fetchPaging`, `search`, `fetchTrending`, `fetchMovieMetadata`, image preloading)
   - `VenuesDataManager` (`fetchVenuesForMovie`, `getScreens`, `getSeatsForScreen`, `fetchVenueMovieSelections`)
   - `SeatsDataManager` (`fetchSeats`, `reserveSeats`)
   - `DatesDataManager` (`fetchDates`)
   - `LocationsDataManager` (`fetchLocations`, `fetchLocationForVenue`)
   - `BasketDataManager` and `CheckoutDataManager` (token retrieval, checkout, purchases/tickets, refund/cancel)
   - `AdminDataManager` / `AdminScreeningsDataManager` (`fetchScreenings`, `searchScreenings`, `addScreen`, `updateScreen`, `deleteScreen`)

3. **Implemented backend service calls** (`SwiftCinemas/SwiftLoginScreen/Networking/BackendServices.swift`):
   - `MbooksService`: `moviesPaging`, `moviesSearch`, `adminMoviesOnVenues*`, `venue`, `locations`, `venueMovies`, `dates`, `seats`, `trendingMovies`, admin mutation endpoints.
   - `LoginGatewayService`: `signIn`, `getUser`, `getCheckOut`, `postCheckOut`, `getAllPurchases`, `getManagePurchases`, `postManagePurchases`, `postActivation`.
   - `ImageResourceService`: cached/uncached image fetch.
   - `RapidMovieDatabaseService`: IMDb metadata lookup.

**Pattern (async/await + centralized services):**

1. **Define Endpoint** (SwiftLoginScreen/Networking/Endpoint.swift):
```swift
let endpoint = Endpoint(
    path: "mbooks-1/rest/book/movies/paging",
    method: "GET",
    query: [URLQueryItem(name: "limit", value: "10")],
    body: nil,
    cacheKey: "movies_cache_key",  // Optional Realm caching
    absoluteURL: nil
)
```

2. **Create HeaderProvider** (in SwiftLoginScreen/Networking/HeaderProvider.swift):
```swift
struct MyCustomHeaderProvider: HeaderProvider {
    func headers() -> [String: String] {
        return [
            "X-Custom": "value",
            "Content-Type": "application/json"
        ]
    }
}
```

3. **Implement Service Method** (SwiftLoginScreen/Networking/BackendServices.swift):
```swift
@MainActor
final class MyService {
    private let apiClient: APIClient
    
    func myMethod(params: [String: String]) async throws -> Data {
        let endpoint = Endpoint(
            path: "my/path",
            method: "GET",
            query: params.map { URLQueryItem(name: $0.key, value: $0.value) },
            body: nil,
            cacheKey: nil,
            absoluteURL: nil
        )
        return try await apiClient.requestData(endpoint, headers: SessionHeaderProvider())
    }
}
```

4. **Inject & Use** (in View Controller):
```swift
class MyViewController: UIViewController, HasAppServices {
    var appServices: AppServices!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        injectAppServicesIfNeeded()
        
        Task {
            do {
                let data = try await appServices.mbooks.moviesPaging(query: [:])
                // Process response
            } catch {
                // Handle AppError
            }
        }
    }
}
```

**Key points:**
- All service calls are `@MainActor` bound (UI updates safe)
- `APIClient` handles response caching for GET requests (check `cacheKey`)
- `HeaderProvider` protocol enables flexible header injection
- Error handling via `AppError` enum (networkFailure, httpError, authRequired, decodingFailed, activationRequired)
- `URLManager` centralized for single-point baseHost changes

**Files to update:**
- Add endpoint methods to existing service classes (`MbooksService`, `LoginGatewayService`, `ImageResourceService`, `RapidMovieDatabaseService`) instead of creating per-screen network code.
- Keep parsing/mapping in DataManagers; keep raw transport concerns in `BackendServices.swift` + `APIClient.swift`.
- Register new services once in `AppDelegate` → `AppServices` container.
- Inject via `HasAppServices` in ViewControllers and DataManagers.

## Deployment & Infrastructure

### 13. Deploying a New Service Version
**When:** Updating backend code and pushing to Kubernetes.

**Steps:**
1. Build JAR: `./mvnw -s k8infra/settings-local.xml package -DskipTests` (in service dir)
2. Build image: `docker build -t myservice:local ./<service-dir>` (into Minikube if using `eval $(minikube docker-env)`)
3. Restart pod: `kubectl delete pod -n cinemas -l app=myservice` (triggers re-pull of image)
4. Verify: `kubectl logs -n cinemas -f deployment/myservice`

### 13. Adding a New Prometheus Metric
**When:** Want to track a custom business metric.

**Pattern (in Quarkus service):**
```java
@Singleton
public class MyMetrics {
    
    private final Counter bookingCounter;
    
    public MyMetrics(MeterRegistry registry) {
        this.bookingCounter = Counter.builder("bookings.total")
            .description("Total bookings processed")
            .register(registry);
    }
    
    public void recordBooking() {
        bookingCounter.increment();
    }
}
```

**In `application.properties`:**
```properties
quarkus.micrometer.enabled=true
quarkus.micrometer.registry-enabled-default=true
```

**Grafana dashboard:** Metrics appear at `http://localhost:3000` after scrape (15 s interval).

### 14. Adding a MySQL Stored Procedure or Trigger
**When:** Complex DB logic (validation, cascades, audits).

**Files:**
- Add procedure definition to `mysql_8/login.sql` or `mysql_8/book.sql`
- Test procedure in local MySQL
- Document in both SQL file AND in entity class Javadoc

**Example (in `mysql_8/login.sql`):**
```sql
DELIMITER //
CREATE PROCEDURE sp_validate_user(IN p_user_id INT, OUT p_is_valid TINYINT)
BEGIN
    SELECT COUNT(*) INTO p_is_valid FROM users WHERE id = p_user_id AND active = 1;
END //
DELIMITER ;
```

**Call from Java:**
```java
CallableStatement stmt = session.connection().prepareCall("{call sp_validate_user(?, ?)}");
stmt.setInt(1, userId);
stmt.registerOutParameter(2, Types.TINYINT);
stmt.execute();
boolean isValid = stmt.getInt(2) == 1;
```

## Documentation & Code Review

### 15. When to Update AGENTS.md
Update AGENTS.md if:
- Architecture changed (new service, removed component, altered boundaries)
- Entity relationships changed (added `FetchType`, `CascadeType`, removed entities)
- Major workflow changed (payment flow, booking flow, auth flow)
- New integration added (Kafka topic, external API, caching strategy)
- Run configuration procedure changed

**DO NOT** update AGENTS.md for:
- Bug fixes (document in commit message instead)
- Minor refactorings (no behavior change)
- Adding a single new endpoint (update relevant README instead)

### 16. Code Review Checklist for PRs
When reviewing Cinemas code changes:

- ✅ **No hardcoded secrets** — use env vars / `@ConfigProperty`
- ✅ **Thread safety** — synchronized blocks only on session/shared state; no static mutable fields
- ✅ **Entity relationships** — fetch strategies are intentional; no unintended N+1 queries
- ✅ **Error handling** — no silent failures; proper HTTP status codes
- ✅ **Cache invalidation** — after mutating entities, L2 cache is invalidated
- ✅ **Header names unchanged** — iOS client depends on exact header names
- ✅ **Payload contracts unchanged** — checkout params, login params untouched
- ✅ **Tests added/updated** — if new feature or bug fix
- ✅ **Documentation updated** — README, AGENTS.md, HTML docs if architecture changed
- ✅ **iOS service calls** — use `BackendServices` classes, proper `HeaderProvider`, async/await pattern
- ✅ **Response caching** — GET requests set `cacheKey` if Realm caching needed

## References (for navigation, not patterns)
- "Where is X?" and "How do I...?" quick lookup lists live in `.ai/retrieval/instructions.md`.
- Deep architecture and contract details live in `.ai/agents/AGENTS.md`.
- Speckit constitutional rules live in `.ai/constitution/constitution.md`.
