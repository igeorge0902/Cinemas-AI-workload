# Kubernetes Startup Orchestrator - Implementation Clarification

## Overview
This document clarifies the design decisions, assumptions, and edge cases in `k8infra/k8s-orchestrator.sh`.

## Implementation Status (Current)

### Completed in script
- Implemented command contract: `up [--seed]`, `status`, `restart <service> [--build]`, `down`, `help`.
- Implemented dependency-aware startup gating with `wait_rollout()` for `mysql`, `dalogin`, `mbook`, `mbooks`, `simple-service-webapp`.
- Implemented optional DB seeding via `seed_mysql()` (`mysql_8/login.sql`, `mysql_8/book.sql`).
- Implemented service-scoped rebuild/restart flow via `build_and_load_service()` and `cmd_restart()`.
- Implemented deterministic fail-fast paths, including missing command checks and unsupported CLI argument checks.
- Implemented manifest precheck via `ensure_manifest_exists()`.

### Verified locally (script-level)
- `bash -n k8infra/k8s-orchestrator.sh` syntax check passes.
- `k8infra/k8s-orchestrator.sh help` prints usage.
- Invalid argument path (example: `up --bad-flag`) exits non-zero with a clear failure message.

### Pending full environment validation
- End-to-end `up`/`status`/`restart`/`down` execution against a running local minikube stack.
- Role sign-offs in `speckit.system.k8s-startup-orchestrator.tasks` (`@testing-engineer`, `@security-specialist`, `@performance-engineer`).

## Design Principles

### 1. Fail-fast with clear diagnostics
- All functions use `set -euo pipefail` to exit on first error.
- Output format: `[INFO]`, `[PASS]`, `[FAIL]` for operator clarity.
- Exit codes: `0` for success, `1` for any failure.
- Each step includes context (what is being done, which service, which endpoint).

### 2. Dependency-aware sequencing
- Startup order enforced strictly in `cmd_up()`:
  - `mysql` → `dalogin` → `mbook` → `mbooks` → `simple-service-webapp`
  - Each waits for readiness (via `kubectl rollout status`) before the next starts.
- Rationale: later services depend on earlier service functionality (e.g., `dalogin` proxy used by `mbook`).

### 3. Idempotent operations
- Runtime checks (`ensure_runtime()`) test status before starting; existing processes are skipped.
- Manifest apply (`kubectl apply -f`) is idempotent by design.
- Service-scoped restart only touches one deployment, leaving others untouched.

### 4. Minimal assumptions about the operator's environment
- Gracefully handles missing `colima` (assumes alternative Docker runtime exists).
- Tries docker CLI first, then falls back to podman for image builds.
- Uses `kubectl` with namespace scoping (`-n cinemas`).

## Key Functions

### `ensure_runtime()`
**Purpose**: Verify and start container runtime + Kubernetes cluster if not running.

| Scenario | Action | Exit behavior |
|----------|--------|---------------|
| `colima` not installed | Log info, assume Docker running elsewhere | Continue |
| `colima` not running | Start with `--cpu 4 --memory 4 --disk 20` | Continue if successful |
| `minikube` not running | Start with `--driver=docker --cpus=4 --memory=3900` | Exit 1 if fails |
| `kubectl` missing | Exit 1 immediately | Fail |
| Ingress addon disabled | Enable via `minikube addons enable ingress` | Continue |

**Important**: The script assumes `kubectl` is always available and on `$PATH`. If not, `require_cmd kubectl` exits with `exit 1`.

### `patch_ingress_lb_if_needed()`
**Purpose**: Patch the ingress controller service from `NodePort` to `LoadBalancer` for `minikube tunnel` support.

| Condition | Action |
|-----------|--------|
| Service type is `LoadBalancer` | Skip (already patched or manually configured) |
| Service type is `NodePort` | Patch to `LoadBalancer` |
| Service does not exist | Silently skip (ingress addon may not be ready yet) |

**Why needed**: Minikube's ingress addon sometimes creates the service as `NodePort` instead of `LoadBalancer`. The tunnel needs `LoadBalancer` to assign a stable external IP (`127.0.0.1`).

### `wait_rollout(deployment)`
**Purpose**: Block until a deployment reaches ready state (all replicas running, no failed pods).

**Implementation**:
```bash
kubectl -n cinemas rollout status deployment/${deployment} --timeout=300s
```

| Outcome | Exit |
|---------|------|
| All replicas ready within timeout | Exit 0 |
| Any pod still pending/failed at timeout | Exit 1 |
| Deployment doesn't exist | Exit 1 |

**Timeout**: Controlled by `$TIMEOUT_SECONDS` (default 300s, overridable via env var).

### `seed_mysql()`
**Purpose**: Load seed data from `mysql_8/login.sql` and `mysql_8/book.sql` into the running MySQL pod.

**Assumptions**:
- `mysql` deployment is running and accessible via service `mysql`.
- Root password is `rootpw` (hardcoded in `quarkus-backend.yaml`).
- Both SQL files exist in the repo; if missing, exit 1.

**Idempotency**:
- SQL scripts are designed to be re-entrant (use `CREATE TABLE IF NOT EXISTS`, etc.).
- Running seed twice should be safe.

### `build_and_load_service(service)`
**Purpose**: Maven package + container image build + load into Minikube.

**Service name mapping**:
```
dalogin         -> dalogin-quarkus (dir) + dalogin-quarkus:local (image) + dalogin (deployment)
mbook           -> mbook-quarkus (dir) + mbook-quarkus:local (image) + mbook (deployment)
mbooks          -> mbooks-quarkus (dir) + mbooks-quarkus:local (image) + mbooks (deployment)
simple-service-webapp -> simple-service-webapp-quarkus (dir) + simple-service-webapp-quarkus:local (image) + simple-service-webapp (deployment)
```

**Image build strategy** (in priority order):
1. Try `docker` CLI with `minikube docker-env`
   - Fastest: builds directly in Minikube's Docker daemon, no image loading step.
   - Assumes: Docker CLI is on `$PATH` and Minikube's Docker driver is active.
2. Fallback to `podman`
   - Builds with Podman, then pipes tarball into `minikube image load`.
   - Assumes: Podman is on `$PATH` and Minikube Docker driver is active.
3. Fail if neither available

**Why no native Podman image registry**: The script doesn't push to a registry because local dev clusters don't have one. Image load via tarball (`podman save | minikube image load`) is the standard local pattern.

## Command Behavior

### `up [--seed]`
**5-step startup flow**:

1. **Runtime checks** (`ensure_runtime()`)
   - Start colima/minikube if not running.
   - Enable ingress addon.
   - Patch ingress service to LoadBalancer.

2. **Manifest apply**
   - `kubectl apply -f k8infra/quarkus-backend.yaml`

3. **Dependency-aware rollout** (in order, blocking)
   - `mysql`
   - `dalogin`
   - `mbook`
   - `mbooks`
   - `simple-service-webapp`
   - If any fails to roll out, exit 1 at that step.

4. **Optional seed** (`--seed` flag)
   - If `--seed`: load `mysql_8/login.sql` + `mysql_8/book.sql`.
   - If not specified: skip seed (safe for re-runs).

5. **Endpoint checks** (blocking)
   - Verify:
     - `https://milo.crabdance.com/login/`
     - `https://milo.crabdance.com/mbooks-1/rest/book/locations`
     - `https://milo.crabdance.com/simple-service-webapp/webapi/myresource`
   - Uses `curl -sk --max-time 10` (ignore cert warnings, 10s timeout per URL).
   - If any URL fails, exit 1.

**Total time**: ~5-10 minutes on first run (includes Maven package + image builds). ~2-3 minutes on re-runs (cached images).

### `status`
**Non-blocking health snapshot** (always exits 0):

- Namespace resource table (deploys, pods, services, ingress)
- Per-service rollout status (with 5s timeout; warns if not ready)
- Per-endpoint curl check (with 5s timeout; warns if unreachable)

**Use case**: Quick health check during/after development work; doesn't fail on degraded state.

### `restart <service> [--build]`
**Service-scoped redeploy**:

1. Validate service name exists.
2. Optional: `--build` flag
   - If present: Maven package + build image + load into Minikube.
   - If absent: skip build (assumes image already loaded).
3. Scale service to 0 replicas, then back to 1 (or configured replicas).
4. Wait for rollout to be ready.

**Isolation**: Only the specified deployment is restarted; others are untouched.

**Example workflow**:
```bash
# After editing dalogin-quarkus source
./k8s-orchestrator.sh restart dalogin --build

# Or just restart without rebuilding (if image was pre-built)
./k8s-orchestrator.sh restart dalogin
```

### `down`
**Graceful shutdown** (always exits 0):

- Scales all deployments in namespace `cinemas` to 0 replicas.
- PVCs are **not** deleted (data persists on disk).
- Services, ingress, ConfigMaps, Secrets remain in place.

**Recovery**: `up` can be re-run after `down` to start the stack again; seed data is preserved in PVCs.

## Error Handling

### Fail-fast on critical errors
- Missing required command (kubectl, minikube, curl) → exit 1
- Manifest file not found → exit 1
- Deployment rollout timeout → exit 1
- Endpoint check failed → exit 1

### Graceful skip on optional errors
- `colima` not installed → continue (assume Docker running elsewhere)
- Ingress service patch fails → continue (may already be LoadBalancer)
- Endpoint check timeout in `status` mode → warn only, continue

## Assumptions and Constraints

| Assumption | Rationale | Risk |
|-----------|-----------|------|
| Kubernetes namespace is always `cinemas` | Defined in `quarkus-backend.yaml` | Hard to change; would need manifest + script updates |
| Timeout is 300s for rollouts | Covers normal pod spin-up + image pull | Longer on slow networks; override via `TIMEOUT_SECONDS=600` |
| TLS cert already generated + secret exists | One-time setup in `k8infra/tls/` + `kubectl create secret` | First-run users must follow README step 5 |
| `minikube tunnel` already running in background | Must be started separately in another terminal | Endpoint checks will fail if not running |
| `/etc/hosts` has `127.0.0.1 milo.crabdance.com` entry | Needed for DNS resolution | iOS simulator tests require this; set up in README step 5 |
| Service image names follow `${svc}-quarkus:local` pattern | Defined in script; matches Dockerfile image names | Adding a new service requires hardcoding service name mappings |

## Extension Points

### Adding a new service
1. Add service name → source dir mapping in `service_src_dir()`.
2. Add service name → image name mapping in `service_image()`.
3. Add deployment name to `wait_rollout` calls in `cmd_up()`.
4. Add any service-specific endpoint check to `check_endpoint` calls in `cmd_up()` and `cmd_status()`.

### Changing resource allocation
- Edit `colima start` flags (line 68): `--cpu`, `--memory`, `--disk`.
- Edit `minikube start` flags (line 79): `--cpus`, `--memory`.
- Keep in sync with `k8infra/README-k8s-local.md` for consistency.

### Adding pre-flight checks
- Add new function (e.g., `check_hosts_entry()`) and call from `ensure_runtime()`.

### CI/CD integration
- Check exit code: `./k8s-orchestrator.sh up && echo "OK"` or similar.
- Parse output: `[PASS]` / `[FAIL]` markers are stable and greppable.
- Capture logs: redirect stdout/stderr if needed.

## Testing Checklist

- [ ] `./k8s-orchestrator.sh help` prints usage and exits 0.
- [ ] `./k8s-orchestrator.sh up` completes all 5 steps and exits 0 on first run.
- [ ] `./k8s-orchestrator.sh up --seed` imports MySQL seed data idempotently.
- [ ] `./k8s-orchestrator.sh status` reports all deployments ready.
- [ ] `./k8s-orchestrator.sh restart mbook` restarts only mbook deployment.
- [ ] `./k8s-orchestrator.sh restart mbook --build` rebuilds mbook image.
- [ ] `./k8s-orchestrator.sh down` scales all deployments to 0 and exits 0.
- [ ] Second `up` after `down` re-uses PVC data (no need to re-seed).
- [ ] Missing `kubectl` causes exit 1 with clear error.
- [ ] Missing `/etc/hosts` entry causes endpoint check failure.
- [ ] Missing `minikube tunnel` causes endpoint check failure.
- [ ] `TIMEOUT_SECONDS=30 ./k8s-orchestrator.sh up` times out on slow network.

## Traceability

- Spec: `speckit.system.k8s-startup-orchestrator.specify` (contract IDs, acceptance criteria)
- Plan: `speckit.system.k8s-startup-orchestrator.plan` (implementation outline)
- Tasks: `speckit.system.k8s-startup-orchestrator.tasks` (phase checklist + role ownership)
- README: `k8infra/README-k8s-local.md` (usage examples + manual fallback)
- Script: `k8infra/k8s-orchestrator.sh` (this implementation)

