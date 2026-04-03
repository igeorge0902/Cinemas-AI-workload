# Examples: K8s Deploy Verify

## Example 1
### Input
Deploy all backend services to local Minikube and verify pods plus API smoke tests.

### Output
- Builds all modules with local Maven settings.
- Builds `dalogin:local`, `mbook:local`, `mbooks:local`, `simple-service-webapp:local` in Minikube Docker env.
- Applies `k8infra/quarkus-backend.yaml`.
- Waits for deployments to be ready.
- Runs:
  - `kubectl get pods`
  - `kubectl get svc`
  - `python k8infra/test-login.py`
- Returns a pass/fail summary with failed step details.

## Example 2
### Input
Only redeploy `dalogin` after auth filter changes; skip full Maven package.

### Output
- Builds only `dalogin-quarkus` image in Minikube Docker env.
- Runs `kubectl rollout restart deployment/dalogin`.
- Verifies deployment rollout status and pod readiness.
- Performs minimal endpoint check through local ingress route.
- Returns quick verification result and next debugging command if check fails.

