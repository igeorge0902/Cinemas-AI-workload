# Claude Skills

## Available Skills

- `k8s-deploy-verify` - Build local images, deploy/update Kubernetes resources from `k8infra/quarkus-backend.yaml`, and run fast verification checks for this cinemas repo.
- `dalogin-auth-debug` - Diagnose cookie/session and HMAC authentication issues across web, iOS, and `dalogin-quarkus` filters with focused verification steps.
- `mbooks-controller-dao-flow` - Trace `mbooks-quarkus` request handling from `BookController` through service/DAO layers to isolate data-flow bugs with minimal-safe fixes.
- `hibernate-session-c3p0-debug` - Diagnose Hibernate session lifecycle, transaction boundaries, and c3p0 pool issues in `mbook-quarkus` and `mbooks-quarkus`.
- `dalogin-downstream-http-client-debug` - Trace and debug outbound HTTP calls from `dalogin-quarkus` servlets through `ServiceClient` into `mbook`/`mbooks` endpoints.
