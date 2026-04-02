# Speckit Constitution: Cinemas Project

## Project Identity
**Cinemas** is a multi-service Quarkus-based cinema booking system with iOS client, web UI (AngularJS), and Kubernetes infrastructure. The system handles user authentication, seat reservation, Braintree payments, and real-time availability tracking.

## Technology Stack
- **Runtime:** Java 17, Quarkus 3.19.4
- **Frontend:** AngularJS 1.x (Film-Review SPA), iOS SwiftUI/AppKit
- **Backend Services:** 4 Quarkus microservices (dalogin, mbook, mbooks, simple-service-webapp)
- **Database:** MySQL 8 (dual schemas: `login_` for auth, `book` for cinema data)
- **Messaging:** Kafka 3.x, Zookeeper
- **Observability:** Prometheus 2.x, Grafana 10.x, Tempo (OpenTelemetry traces)
- **Container/Orchestration:** Docker, Kubernetes (Minikube locally)
- **API Gateway/Proxy:** Apache HTTP Server 2.4 (reverse proxy, SSL termination)
- **Testing:** Appium 3.x (iOS UI), TestNG, Python pytest (API tests)
- **Payment Gateway:** Braintree Sandbox API (JS 1.44.1, iOS 5.26.0, Java 3.36.0)

## Critical Architecture Decisions

### 1. Dual Database Schemas
- **`login_` schema:** User credentials, authentication state, devices, sessions, vouchers
  - File: `mysql_8/login.sql`
  - Services: dalogin (primary), mbook/mbooks (queries via dalogin proxy)
  - Key tables: `user_`, `device_`, `session_login`, `voucher_`

- **`book` schema:** Cinema catalog, venue data, seat inventory, purchases
  - File: `mysql_8/book.sql`
  - Service: mbooks (direct access + pessimistic locking)
  - Key tables: `movie`, `venue`, `screen`, `screening_date`, `seat`, `ticket`, `purchase`

### 2. Pessimistic Locking for Seat Availability
- **Lock level:** `PESSIMISTIC_WRITE` on `Seat` entity during `bookTickets()`
- **Lock duration:** Transaction scope only (released after payment confirmation or rollback)
- **Cache invalidation:** After seat/purchase mutations, evict `ticket` cache region
- **Atomic operation flow:**
  ```
  BEGIN TRANSACTION
    → SELECT seats FOR UPDATE (acquire X-lock)
    → Verify availability (seat.isReserved == "0")
    → Create Ticket records
    → CREATE Purchase record
    → Call Braintree /transactions
    → IF payment fails: DELETE tickets+purchase, UPDATE seats.isReserved = "0"
    → IF payment succeeds: UPDATE seats.isReserved = "1", COMMIT
  END TRANSACTION
  ```

### 3. Microservice Communication Contracts
- **Service-to-service:** ServiceClient injects authentication headers (X-Token, X-HMAC-HASH)
- **Client-to-service:** Session-based (X-Token cookie) OR HMAC-based (X-HMAC-HASH header)
- **Header injection:** dalogin acts as auth gateway; downstream services read pre-authenticated headers
- **Cross-origin:** Apache ProxyPass preserves headers; CORS headers include `Access-Control-Expose-Headers: X-Token`

### 4. Payment Workflow (iOS + Web)
```
[Client Login] → Session established (X-Token cookie)
  ↓
GET /login/CheckOut → Redirects to GET /mbooks-1/rest/book/payment/clientToken
  ↓ (GET successful)
POST /login/CheckOut (payment_method_nonce, orderId, seatsToBeReserved)
  ↓
dalogin proxy → POST /mbooks-1/rest/book/payment/fullcheckout2
  ↓
[Pessimistic lock seats] → [Create Purchase] → [Braintree transaction]
  ↓ (failure)
Rollback: DELETE tickets+purchase, UPDATE seat.isReserved="0"
  ↓ (success)
Return: { tickets: [...], seatMap: {...}, transactionId: "..." }
```

### 5. iOS Service Refactoring (Async/Await Pattern)
Modern async/await + centralized networking layer replaced callback-based implementation:
- **APIClient:** Main HTTP transport (request/response handling, caching, retry logic)
- **Endpoint:** Request descriptor (path, method, query, body, cache key, absolute URL)
- **BackendServices:** Service wrappers (MbooksService, LoginGatewayService, ImageResourceService, RapidMovieDatabaseService)
- **HeaderProvider protocol:** Multiple implementations for different auth schemes:
  - `SessionHeaderProvider` — Session cookies (X-Token, Ciphertext, X-Device)
  - `HMACLoginHeaderProvider` — HMAC-SHA512 (X-HMAC-HASH, X-MICRO-TIME, uuid)
  - `MinimalGETHeaderProvider` — No auth (public/image endpoints)
  - `RapidMovieDatabaseHeaderProvider` — External API keys

## Hardcoded Client-Visible Contracts

**DO NOT change without coordinating across iOS + Web clients:**

### HTTP Headers (All Services)
| Header | Value | Set By | Used By | Mutable? |
|--------|-------|--------|---------|----------|
| `X-Token` | Session token (string) | dalogin | All services | No |
| `Ciphertext` | Encrypted request body | iOS client | dalogin, mbooks | No |
| `uuid` | Device UUID | Client | dalogin, mbooks | No |
| `X-Device` | Device identifier | Client | mbooks (seat locks) | No |
| `TIME_` | Client timestamp | Client | dalogin (HMAC) | No |
| `X-HMAC-HASH` | HMAC-SHA512(body + secret) | Client | dalogin, mbooks | No |
| `XSRF-TOKEN` | CSRF protection | dalogin | Client (echoed back) | No |
| `X-Forwarded-For` | Client IP (via Apache) | Apache | All services | No |
| `APIKEY` | Braintree key (response header) | mbooks | Client (cached) | No |

### Payment Checkout Payload (EXACT format required)
```json
{
  "payment_method_nonce": "nonce_from_braintree_js",
  "orderId": "booking_reference",
  "seatsToBeReserved": "A1-B2-C3-"
}
```
- `seatsToBeReserved`: Concatenated seat numbers (e.g., `"A1-B2-"`), NOT seat IDs
- Encoding: Must match HTTP POST body encoding (form-urlencoded or JSON depending on client)
- Order: Preserve exact key order for HMAC calculation

### API Endpoints (Non-negotiable)
| Endpoint | Method | Port | Returns | Notes |
|----------|--------|------|---------|-------|
| `/login/HelloWorld` | POST | 8080 | `{ token: "...", uuid: "..." }` | HMAC login |
| `/login/CheckOut` | GET/POST | 8080 | Redirects to mbooks payment flow | Gateway servlet |
| `/mbooks-1/rest/book/movies` | GET | 8080 | `{ movies: [...] }` | Paged, cached |
| `/mbooks-1/rest/book/payment/clientToken` | GET | 8080 | `{ clientToken: "...", APIKEY: "..." }` | Braintree setup |
| `/mbooks-1/rest/book/payment/fullcheckout2` | POST | 8080 | `{ status: "...", tickets: [...], seatMap: {...} }` | Payment execution |
| `/mbooks-1/ws` | WebSocket | 8080 | Real-time seat updates | Via Apache ProxyPass |
| `/simple-service-webapp/rest/images/*` | GET | 8085 | Binary image data | Cache-friendly headers |

### Braintree SDK Versions (Sandbox Only)
- **JavaScript:** 1.44.1 (via CDN in index.html)
- **iOS:** 5.26.0 (via CocoaPods)
- **Java/Quarkus:** 3.36.0 (via Maven pom.xml)
- **Merchant ID:** `j3ndqpzrhy4gp2p7`
- **Public Key:** Available in Braintree dashboard
- **All endpoints:** https://sandbox.braintreegateway.com/

### HMAC Algorithm & Signature
- **Algorithm:** SHA-512
- **Input:** Concatenate (request body + client-side secret)
- **Header:** `X-HMAC-HASH: base64(hmac_sha512_bytes)`
- **Timing:** Included in login request; verified by dalogin for all authenticated calls

## File Navigation Map

### Backend Services
| Service | Location | Port | Primary Classes | Database |
|---------|----------|------|-----------------|----------|
| **dalogin** | `dalogin-quarkus/` | 8080 | `HelloWorld.java`, `CookieFilter.java`, `AuthFilter.java` | `login_` |
| **mbook** | `mbook-quarkus/` | 8888 | `UserController.java` | `login_` (read-only proxy) |
| **mbooks** | `mbooks-quarkus/` | 8080 | `BookController.java`, `PaymentService.java` | `book` |
| **simple-service-webapp** | `simple-service-webapp-quarkus/` | 8085 | `ImageResource.java` | N/A (serves files) |

### Web UI
- Location: `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/`
- Root: `index.html` (AngularJS SPA shell)
- Controllers: `app.js` (683 lines, HMAC interceptor, checkout flow)
- Templates: `movies.html`, `venues.html`, `dates.html`, `checkout.html`, `purchases.html`
- CSS: Inline in `index.html` (light/dark theme toggle)

### iOS Client
- Location: `SwiftCinemas/`
- Networking Layer: `SwiftLoginScreen/Networking/` (APIClient, Endpoint, BackendServices, HeaderProvider, URLManager)
- Views: `SwiftLoginScreen/Views/` (MovieListView, VenueSelectionView, SeatMapView, CheckoutView)
- Models: `SwiftLoginScreen/Models/` (Movie, Venue, Seat, Purchase, AppError)

### Database Initialization
- `mysql_8/login.sql` — User schema with triggers for session management
- `mysql_8/book.sql` — Cinema schema with stored procedures for availability queries

### Test Suites
| Framework | Location | Config | Command |
|-----------|----------|--------|---------|
| **Appium (iOS)** | `appium/src/test/java/` | `.run/appium - mvn test` | `mvn test -s k8infra/settings-local.xml` |
| **TestNG direct** | `appium/src/test/java/` | `.run/appium - java direct (testng)` | Run via IDE test runner |
| **Python API tests** | `k8infra/` | `.run/k8s - test-login.py` | `python test-login.py` |

### Infrastructure as Code
- `k8infra/quarkus-backend.yaml` — Kubernetes manifests (services, deployments, configmaps, statefulsets)
- `k8infra/settings-local.xml` — Maven proxy settings (bypass external repos)
- `k8infra/README-k8s-local.md` — Deployment runbook (Minikube setup, tunnel, verification)

## Key Code Patterns

### Adding a New REST Endpoint
```java
@Path("/resource")
@Produces(MediaType.APPLICATION_JSON)
public class ResourceResource {

  @GET
  public Response getResource(@Context HttpServletRequest request) {
    // 1. Extract session if authenticated
    String sessionUUID = RequestFilter.getSessionUUID(request);
    if (sessionUUID == null) return Response.status(401).build();

    // 2. Perform business logic
    List<Object> result = dao.fetchResource();

    // 3. Return JSON
    return Response.ok(result).build();
  }
}
```

### Modifying Seat Availability
```java
// In DAO.java (synchronized method)
public synchronized void bookTickets(String screeningDateId, List<String> seats) {
  session.beginTransaction();
  try {
    // 1. Lock seats for update
    Query query = session.createQuery("FROM Seat WHERE screeningDateId = :id")
      .setLockMode(LockModeType.PESSIMISTIC_WRITE);
    List<Seat> lockedSeats = query.getResultList();

    // 2. Verify availability (NEVER use == for string comparison)
    for (Seat seat : lockedSeats) {
      if (!seat.getIsReserved().equals("0")) throw new Exception("Seat unavailable");
    }

    // 3. Create tickets + purchase
    // ... ticket creation logic ...

    // 4. Cache invalidation
    sessionFactory.getCache().evictRegion("ticket");

    session.getTransaction().commit();
  } catch (Exception e) {
    session.getTransaction().rollback();
    throw e;
  }
}
```

### iOS Async Service Call
```swift
// In BackendServices.swift
func getMovies(pageNumber: Int) async throws -> [Movie] {
  let endpoint = Endpoint(
    path: "/mbooks-1/rest/book/movies",
    method: .get,
    query: ["paging": String(pageNumber)],
    headerProvider: SessionHeaderProvider()
  )

  let response: [Movie] = try await apiClient.request(endpoint)
  return response
}
```

### HMAC Calculation (Web/iOS)
```javascript
// In web UI app.js
function calculateHMAC(body, secret) {
  const combined = body + secret;
  const hash = CryptoJS.SHA512(combined);
  return btoa(hash.toString(CryptoJS.enc.Base64));
}
```

## Common Failure Modes

### Payment fails on Web, succeeds on iOS
1. ✅ Check `POST /login/CheckOut` parameters match exactly (seatsToBeReserved format)
2. ✅ Verify HMAC interceptor in web UI includes Authorization header in HMAC calculation
3. ✅ Compare Braintree SDK versions (JS 1.44.1 must match backend expectation)
4. ✅ Check Apache ProxyPass doesn't strip Content-Type header

### WebSocket disconnects after seat selection
1. ✅ Verify `sudo minikube tunnel` is running
2. ✅ Check WebSocket `ProxyPass` comes **before** HTTP routes in Apache config
3. ✅ Confirm Sec-WebSocket-Key header is present in browser dev tools
4. ✅ Check Quarkus WebSocket endpoint is registered (see mbook-quarkus pom.xml)

### Session not found after login
1. ✅ Verify `CookieFilter` is registered in `web.xml` (before `AuthFilter`)
2. ✅ Check cookie domain matches request origin (localhost vs 127.0.0.1)
3. ✅ Confirm `ActiveVoucherFilter` runs after `CookieFilter`
4. ✅ Validate session is stored in MySQL `session_login` table

### Seat availability stale after purchase
1. ✅ Confirm `DAO.getSeatsForScreening()` is NOT using Hibernate query cache
2. ✅ Verify L2 cache is evicted after seat mutation (`cache.evictRegion("ticket")`)
3. ✅ Check `FetchType.EAGER` on bidirectional relationships (can cause cache confusion)

### Images not loading on iOS
1. ✅ Verify `simple-service-webapp` is deployed and responding on port 8085
2. ✅ Check `URLManager.swift` correctly resolves image URLs (should use absolute path)
3. ✅ Confirm Apache `ProxyPass` includes `/simple-service-webapp` route
4. ✅ Verify PVC for image storage is mounted (check `k8infra/quarkus-backend.yaml`)

## Observability Setup

### Prometheus Metrics
- Scrape endpoint: All services expose `/metrics` (Quarkus default)
- Targets: `k8infra/quarkus-backend.yaml` configures StatefulSet for auto-discovery
- Key metrics: `http_requests_total`, `jvm_memory_used_bytes`, `db_connection_pool_active`
- Retention: 15 days (configurable in `prometheus.yaml`)

### Grafana Dashboards
- **Service Health:** HTTP request rate, p95 latency, 5xx errors (per service)
- **JVM Metrics:** Heap memory, thread count, GC pause times (per service)
- **Database:** Connection pool, slow query log, replication lag
- Data source: Prometheus (http://prometheus:9090)

### Tempo Trace Collection
- Collector endpoint: `/metrics` exports traces to Tempo
- Query UI: Grafana Tempo plugin (https://localhost:3000/explore)
- Service graph: Automatically generated from trace metadata
- Retention: 48 hours (configurable in `values.yaml`)

## Deployment Quick Reference

### Build All Services
```bash
./mvnw -s k8infra/settings-local.xml package -DskipTests
```

### Deploy to Minikube
```bash
eval $(minikube docker-env)
docker build -t dalogin:local ./dalogin-quarkus
docker build -t mbook:local ./mbook-quarkus
docker build -t mbooks:local ./mbooks-quarkus
docker build -t simple-service-webapp:local ./simple-service-webapp-quarkus
eval $(minikube docker-env --unset)

kubectl apply -f k8infra/quarkus-backend.yaml
sudo minikube tunnel
```

### Verify Deployment
```bash
# Check pods
kubectl get pods -n default

# Check services
kubectl get svc

# Port forward for testing
kubectl port-forward svc/dalogin 8080:8080
```

### Run Test Suites
```bash
# API tests
python k8infra/test-login.py

# iOS UI tests
mvn test -f appium/pom.xml -s k8infra/settings-local.xml

# Direct TestNG (bypass Maven exec plugin)
cd appium && java -cp target/test-classes:target/classes:...libs/* org.testng.TestNG testng.xml
```

## IntelliJ Run Configurations

All `.run/` configs are pre-configured and ready to use:
- Maven configs use `myGeneralSettings` profile → `k8infra/settings-local.xml`
- Shell configs use bash on macOS
- Configs are NOT synced to Git; keep local

## References for Further Reading

| Topic | File | Lines |
|-------|------|-------|
| System architecture | `.github/instructions/instructions.md` | All |
| Entity relationships | `.github/agents/AGENTS.md` | (todo) |
| Kubernetes setup | `k8infra/README-k8s-local.md` | All |
| Appium test guide | `appium/README.md` | All |
| Backend API docs | `k8infra/system-documentation.html` | All |

---

**Last Updated:** April 2, 2026
**Maintained By:** Development Team
**Status:** Active — All services production-ready in Minikube

