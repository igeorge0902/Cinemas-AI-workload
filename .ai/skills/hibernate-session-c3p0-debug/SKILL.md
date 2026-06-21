# Hibernate Session C3P0 Debug

## Purpose
Diagnose and fix Hibernate session lifecycle, transaction boundary, and c3p0 connection-pool issues in `mbook-quarkus` and `mbooks-quarkus`.

## Use When
- You see session/transaction errors (`Session is closed`, rollback anomalies, stale entity updates).
- Requests intermittently fail under load and look like pool exhaustion or connection timeout.
- You need to validate `HibernateUtil` + DAO session handling after refactoring.
- You are debugging `c3p0` behavior (also written as `c30p` in some notes).

## Do Not Use When
- The issue is authentication header/cookie validation in `dalogin-quarkus` only.
- The issue is frontend-only rendering with no backend DB/session interaction.

## Inputs
- Required: failing endpoint/method and service (`mbook` or `mbooks`).
- Required: representative error log line or stack trace.
- Optional: load profile (thread count / JMeter scenario).
- Optional: suspected DAO method(s).

## Outputs
- Root-cause oriented report (session lifecycle, pool, transaction, or query-level).
- Exact file-level fix target(s).
- Minimal configuration/code patch recommendation.
- Verification checklist for normal + load behavior.

## Constraints
- Preserve existing API contracts while fixing persistence internals.
- Keep checkout seat-lock semantics intact (`PESSIMISTIC_WRITE` where already used).
- Avoid broad pool-size increases without measuring error-rate impact.
- Do not log secrets or sensitive payment/session token material.

## Workflow
1. Confirm failing path and map to DAO method:
   - `mbooks-quarkus/src/main/java/com/jeet/db/DAO.java`
   - `mbook-quarkus/src/main/java/com/jeet/db/DAO.java`
2. Review session factory/bootstrap:
   - `mbooks-quarkus/src/main/java/com/jeet/db/HibernateUtil.java`
   - `mbook-quarkus/src/main/java/com/jeet/db/HibernateUtil.java`
3. Validate c3p0 and Hibernate settings:
   - `mbooks-quarkus/src/main/resources/hibernate.cfg.xml`
   - `mbook-quarkus/src/main/resources/hibernate.cfg.xml`
4. Check transaction/session handling in DAO methods:
   - open/close patterns
   - commit/rollback symmetry
   - exception paths leaving transactions open
5. Validate SQL/lock behavior for high-contention flows (for example booking/payment paths).
6. Propose smallest viable fix in one layer first (config or DAO code), then re-check logs and behavior.
7. Verify with representative endpoint calls and a short concurrent run.

## Validation Checklist
- [ ] Failing request is mapped to exact DAO method(s).
- [ ] Session open/close and transaction lifecycle are balanced on happy + error paths.
- [ ] c3p0 timeout/pool settings are reviewed against observed load.
- [ ] No regression in booking/payment lock semantics.
- [ ] Verification includes both functional and concurrent checks.

