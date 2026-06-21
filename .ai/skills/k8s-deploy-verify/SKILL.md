# K8s Deploy Verify

## Purpose
Deploy backend changes for this cinemas repository to local Minikube and verify that core services are healthy and reachable.

## Use When
- You changed one or more backend services and need to redeploy locally.
- You updated `k8infra/quarkus-backend.yaml` and need a safe verification run.
- You need a repeatable deploy+smoke-check workflow for local development.

## Do Not Use When
- You need production or shared-cluster deployment procedures.
- You do not have Minikube access in the current environment.

## Inputs
- Required: target scope (`all` or specific service names).
- Optional: `skip_build=true` when image already exists in Minikube Docker.
- Optional: `run_api_smoke=true` to execute `k8infra/test-login.py`.

## Outputs
- Deployment summary (what was rebuilt/restarted).
- Verification summary (pods/services/HTTP checks).
- Any failed checks with concrete next-action hints.

## Constraints
- Use `k8infra/settings-local.xml` for Maven commands in this repo.
- For Minikube image builds, use `eval $(minikube docker-env)` and unset afterwards.
- Do not delete cluster resources unless explicitly requested.
- Keep checks read-only except deploy/restart actions.

## Workflow
1. Identify target services (`dalogin`, `mbook`, `mbooks`, `simple-service-webapp`).
2. Build artifacts if needed:
   - `./mvnw -s k8infra/settings-local.xml package -DskipTests`
3. Build target Docker images in Minikube Docker env.
4. Apply manifests: `kubectl apply -f k8infra/quarkus-backend.yaml`.
5. If only one service changed, run targeted restart: `kubectl rollout restart deployment/<name>`.
6. Wait for readiness with rollout/pod checks.
7. Verify:
   - `kubectl get pods`
   - `kubectl get svc`
   - gateway endpoint reachable via ingress/tunnel path used locally
   - optional smoke: `python k8infra/test-login.py`
8. Return concise pass/fail report with failing command output snippets.

## Validation Checklist
- [ ] Commands use repository paths and local settings correctly.
- [ ] Only requested services were rebuilt/restarted.
- [ ] Kubernetes resources are Ready after deploy.
- [ ] At least one API reachability check passed.
- [ ] Optional smoke test result recorded when requested.

