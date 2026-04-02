# Quickstart Guide for Cinemas Project

**For a quick-start, read this first. For detailed architecture, read `.github/agents/AGENTS.md`.**

## 5-Minute Setup (Local Development)

### Prerequisites
```bash
# Install tools
brew install docker colima maven openjdk@17

# Install Minikube
brew install minikube

# Start Docker daemon (replace Docker Desktop)
colima start --cpu 4 --memory 8 --disk 60

# Start Kubernetes
minikube start --driver=docker --cpus=4 --memory=8192
minikube addons enable ingress
```

### Deploy Backend
```bash
# 1. Build all services
./mvnw -s k8infra/settings-local.xml package -DskipTests

# 2. Build Docker images into Minikube
eval $(minikube docker-env)
docker build -t dalogin:local ./dalogin-quarkus
docker build -t mbook:local ./mbook-quarkus
docker build -t mbooks:local ./mbooks-quarkus
docker build -t simple-service-webapp:local ./simple-service-webapp-quarkus
eval $(minikube docker-env --unset)

# 3. Deploy to K8s
kubectl apply -f k8infra/quarkus-backend.yaml

# 4. Wait for MySQL to seed (1–2 min)
kubectl wait -n cinemas --for=condition=ready pod -l app=mysql --timeout=180s

# 5. Import database (run once after first deploy)
kubectl exec -n cinemas mysql-0 -- mysql -uroot -prootpw < mysql_8/login.sql
kubectl exec -n cinemas mysql-0 -- mysql -uroot -prootpw < mysql_8/book.sql

# 6. Setup networking for iOS simulator
echo "127.0.0.1 milo.crabdance.com" | sudo tee -a /etc/hosts

# 7. Start tunnel (keep running in background)
sudo minikube tunnel &

# 8. Verify backend is running
curl -sk https://milo.crabdance.com/login/ | head -20
```

### Run Tests
```bash
# API smoke tests
python3 k8infra/test-login.py

# iOS UI tests (requires iOS simulator running)
mvn test -f appium/pom.xml
```

### Access Services
| Service | URL | Purpose |
|---------|-----|---------|
| Web UI | `https://milo.crabdance.com/login/film-review/` | Cinema booking (AngularJS) |
| Grafana | `https://milo.crabdance.com/grafana/` | Metrics dashboard |
| Prometheus | `https://milo.crabdance.com/prometheus/` | Metrics scraper |
| Tempo | `https://milo.crabdance.com/tempo/` | Distributed tracing |

## Common Tasks

### Add a New API Endpoint
1. Open `mbooks-quarkus/src/main/java/com/jeet/rest/BookController.java`
2. Add a new method:
   ```java
   @GET
   @Path("/my-endpoint")
   @Produces(MediaType.APPLICATION_JSON)
   public Response myEndpoint(@Context HttpHeaders headers) {
       // Your code
       return Response.ok(result).build();
   }
   ```
3. Rebuild: `./mvnw package -DskipTests -f mbooks-quarkus/`
4. Redeploy: `kubectl delete pod -n cinemas -l app=mbooks` (K8s will restart with new image)

### Fix a Bug in Booking
1. Open `mbooks-quarkus/src/main/java/com/jeet/rest/BookController.java` (payment flow lines 600–1170)
2. Or `mbooks-quarkus/src/main/java/com/jeet/service/PaymentService.java` (Braintree logic)
3. Or `mbooks-quarkus/src/main/java/com/jeet/db/DAO.java` (seat locking, pessimistic writes)
4. Make changes, rebuild, redeploy

### Check Logs
```bash
# All services
kubectl logs -n cinemas -f deployment/dalogin
kubectl logs -n cinemas -f deployment/mbook
kubectl logs -n cinemas -f deployment/mbooks
kubectl logs -n cinemas -f deployment/simple-service-webapp

# Database
kubectl exec -n cinemas mysql-0 -- tail -f /var/log/mysql/error.log

# Watch all pods
kubectl get pods -n cinemas -w
```

### Scale a Service (Replicas)
```bash
# Run 3 instances of mbooks
kubectl scale deployment -n cinemas mbooks --replicas=3

# Check rollout
kubectl rollout status deployment/mbooks -n cinemas
```

### Run a Single Test
```bash
# iOS UI test for movie browsing
mvn test -f appium/pom.xml -Dtest=TestNavigations#testBrowseMovies

# Login API test
python3 -c "from k8infra.test_login import test_login; test_login()"
```

### Update a Configuration
1. Edit `k8infra/quarkus-backend.yaml` (env vars, replicas, etc.)
2. Reapply: `kubectl apply -f k8infra/quarkus-backend.yaml`
3. Rolling restart: `kubectl rollout restart deployment/mbooks -n cinemas`

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `curl: (7) Failed to connect` | Run `sudo minikube tunnel` |
| iOS app crashes on login | Check `URLManager.swift` baseHost, verify tunnel running |
| Appium test timeout | Verify iOS simulator is open; check `appium/README.md` |
| Payment fails on web but works on iOS | Check HMAC interceptor in `app.js`; verify Braintree SDK version |
| Database not seeded | Run `kubectl exec -n cinemas mysql-0 -- mysql -uroot -prootpw < mysql_8/login.sql` |
| WebSocket not connecting | Check `/mbook-1/ws` ProxyPass comes **before** `/mbook-1` in Apache config |

## File Locations (Editing Cheat Sheet)

| What to Edit | Where |
|--------------|-------|
| Login logic | `dalogin-quarkus/src/main/java/com/dalogin/servlets/HelloWorld.java` |
| Booking/payment | `mbooks-quarkus/src/main/java/com/jeet/rest/BookController.java` |
| User profile | `mbook-quarkus/src/main/java/com/jeet/rest/UserController.java` |
| Web UI (AngularJS) | `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/app.js` |
| Web UI (templates) | `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/templates/` |
| Database schema | `mysql_8/login.sql`, `mysql_8/book.sql` |
| K8s manifest | `k8infra/quarkus-backend.yaml` |
| iOS client | `SwiftCinemas/` |
| iOS tests | `appium/src/test/java/` |

## Key Concepts

### HMAC Authentication
- Every request signed with `HMAC-SHA512(username, timestamp + password_hash)`
- Headers: `X-Token`, `X-HMAC-HASH`, `X-MICRO-TIME`, `X-Device`
- Same flow iOS ↔ Web — don't change header names

### Pessimistic Locking
- When reserving seats: `SELECT ... FOR UPDATE` (database lock)
- Ensures no race condition between availability check and seat reservation
- If seat already reserved: entire transaction rolls back (no partial bookings)

### L2 Cache (Infinispan)
- Movie, Venue, Location, Ticket entities are cached
- Seat availability is **NOT cached** (always fresh from DB)
- After mutations: invalidate cache region manually

### WebSocket Broadcasting
- iOS client connects to `/mbook-1/ws` or `/mbooks-1/ws`
- Server sends real-time updates via Kafka → WebSocket
- iOS sends ping every 30 seconds; server expects pong

## Next Steps

1. **Read AGENTS.md** — for comprehensive architecture overview
2. **Read `k8infra/README-k8s-local.md`** — for detailed local deployment steps
3. **Explore `.run/` directory** — pre-configured IntelliJ run configs
4. **Check `docs/system-documentation.html`** — for entity relationships and payment flows

---

**Questions?** Start by searching in `AGENTS.md` or checking the relevant README in each service folder.

