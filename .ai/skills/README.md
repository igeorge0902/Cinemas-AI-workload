# Claude Skills

## Governing Rule

- Use dedicated skills first (`/.ai/skills/*/SKILL.md`) when a matching skill exists.
- Precedence for conflicts: `/.ai/constitution/constitution.md` -> `/.ai/agents/AGENTS.md` -> dedicated skill docs -> `/.ai/skills/skills-github.md`.
- `/.ai/skills/skills-github.md` is a broad pattern catalog, not the canonical source for contracts or architecture rules.

## Available Skills

- `k8s-deploy-verify` - Build local images, deploy/update Kubernetes resources from `k8infra/quarkus-backend.yaml`, and run fast verification checks for this cinemas repo.
- `dalogin-auth-debug` - Diagnose cookie/session and HMAC authentication issues across web, iOS, and `dalogin-quarkus` filters with focused verification steps.
- `mbooks-controller-dao-flow` - Trace `mbooks-quarkus` request handling from `BookController` through service/DAO layers to isolate data-flow bugs with minimal-safe fixes.
- `hibernate-session-c3p0-debug` - Diagnose Hibernate session lifecycle, transaction boundaries, and c3p0 pool issues in `mbook-quarkus` and `mbooks-quarkus`.
- `dalogin-downstream-http-client-debug` - Trace and debug outbound HTTP calls from `dalogin-quarkus` servlets through `ServiceClient` into `mbook`/`mbooks` endpoints.
- `html-prototype-uikit-redesign` - Implement UIKit parity from `/Users/gyorgy.gaspar/work/cinemas/cinemas/.ai/workflows/features/SwiftUIFeatures/prototypes` using Speckit-driven gap analysis and admin/adminupdate-tested layout patterns.
- `swift-rest-contract-tests` - Build deterministic XCTest service contract tests for `MbooksService`/`LoginGatewayService` with mocked default mode and opt-in live mode.
- `swift-datamanager-integration` - Apply API response to DataManager integration patterns to reduce global state and keep service/data boundaries stable.
- `api-smoke-restassured` - Run and maintain minimal Java RestAssured smoke tests in `k8infra/api-smoke-restassured` as the primary backend smoke path.
