# Backend Logging Observability - Implementation Plan (Annotation-First Draft)

## Purpose
This draft updates the implementation direction to a low-intrusion model using annotations and interceptors.

## What Changed from Previous Draft
- Removed interface-heavy emitter pattern as default rollout path.
- Adopted annotation + interceptor instrumentation for minimal DAO code change.
- Kept strict separation of log files for Hibernate subtypes and new categories.

## Scope
- Services: `dalogin-quarkus`, `mbook-quarkus`, `mbooks-quarkus`, `simple-service-webapp-quarkus`
- First PoC: DAO layer (`mbook-quarkus` + `mbooks-quarkus`)
- Existing logs and Hibernate logs move to structured format.
- Hibernate subtype logs stay in separate files.
- New categories also use separate files.

## Delivery Phases

### Phase 1 - Annotation contract and policies
1. Define `@ObservedLog` annotation fields (`category`, `level`, `includeArgs`, `includeResult`).
2. Define interceptor behavior (`START`, `END`, `ERROR` emission).
3. Define threshold rules from system level (`quarkus.log.level`, optional app override).
4. Define category-to-file routing map.

**Review output**
- annotation contract approved
- interceptor lifecycle behavior approved
- file routing map approved

---

### Phase 2 - DAO proof of concept (minimal code changes)
1. Add `@ObservedLog` to selected DAO methods in:
   - `mbook-quarkus/src/main/java/com/jeet/db/DAO.java`
   - `mbooks-quarkus/src/main/java/com/jeet/db/DAO.java`
2. Keep method bodies unchanged except where custom error metadata is needed.
3. Validate INFO/DEBUG/TRACE thresholds and structured output.

**Review output**
- DAO PoC diff (annotation-only focus)
- log samples for success/failure paths
- overhead snapshot

---

### Phase 3 - Existing logging migration
1. Inventory current non-annotation logs and Hibernate logs.
2. Reformat existing outputs into shared structured schema.
3. Keep old coverage semantics; avoid event loss during migration.
4. Preserve separate files for Hibernate subtypes.

**Review output**
- before/after samples
- routed file map confirmed

---

### Phase 4 - Service rollout
1. Add `@ObservedLog` on service/filter/endpoint methods where applicable.
2. Keep special-case manual logs only for domain-specific payload details.
3. Route all new categories to dedicated files.

**Review output**
- rollout checklist by module

---

### Phase 5 - Grafana/Loki integration
1. Ensure all split files are ingested and labeled by service/category/level.
2. Add dashboards/Explore queries for key categories.
3. Verify no cross-mixing between Hibernate subtype streams.

**Review output**
- dashboard query pack
- category/file ingestion matrix

## Annotation Model (Example)

```java
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@InterceptorBinding
public @interface ObservedLog {
    String category();
    LogLevel level() default LogLevel.INFO;
    boolean includeArgs() default false;
    boolean includeResult() default false;
}
```

```java
public enum LogLevel {
    TRACE, DEBUG, INFO, WARN, ERROR
}
```

## InvocationContext Reference

`InvocationContext` is the CDI handle passed into every `@AroundInvoke` method. It provides everything the interceptor needs to build a structured log event without touching method bodies.

| Method | Used for |
|---|---|
| `ctx.getMethod().getName()` | method simple name (e.g. `"bookTickets"`) |
| `ctx.getTarget().getClass().getSimpleName()` | declaring class simple name (e.g. `"DAO"`) |
| `ctx.getParameters()` | argument values at call time (for `includeArgs = true`) |
| `ctx.proceed()` | calls the real method and returns its result |

### Reading the annotation with class-level fallback

```java
private ObservedLog resolveAnnotation(InvocationContext ctx) {
    ObservedLog cfg = ctx.getMethod().getAnnotation(ObservedLog.class);
    if (cfg == null) {
        cfg = ctx.getTarget().getClass().getAnnotation(ObservedLog.class);
    }
    return cfg;
}
```

### Building a structured log event from InvocationContext

```java
String methodName = ctx.getMethod().getName();                    // "bookTickets"
String className  = ctx.getTarget().getClass().getSimpleName();  // "DAO"
Object[] params   = ctx.getParameters();                         // [screeningDateId, seats, uuid, orderId]

// source field used in every log event:
String source = className + "." + methodName;  // "DAO.bookTickets"
```

Produces structured output:

```json
{
  "timestamp": "2026-04-12T10:00:00Z",
  "level": "INFO",
  "category": "LOG-HIBERNATE-TX",
  "source": "DAO.bookTickets",
  "event": "START",
  "durationMs": null
}
```

> **Security note:** `includeArgs` defaults to `false`. When enabled, parameter values are appended as `"args": [...]`. Sensitive parameters (uuid, tokens, payment fields) must be redacted before appending — enforced as part of SEC-001/002.

## CDI Proxy Constraint (PoC Prerequisite)

The interceptor **only fires when the bean is called through the CDI proxy** — not via direct instantiation or the manual `DAO.instance()` singleton pattern used in `mbooks-quarkus`.

| Call path | Interceptor fires? |
|---|---|
| `DAO.instance().getAllMovies(...)` | ❌ bypasses CDI proxy |
| `@Inject DAO dao; dao.getAllMovies(...)` | ✅ interceptor active |

**Resolution for PoC:**
- `mbook-quarkus` `DAO` uses `@RequestScoped` + `@Inject` → interceptor will fire without changes.
- `mbooks-quarkus` `DAO` uses `@Dependent` + `DAO.instance()` → callers in controllers must be verified; switch to `@Inject DAO dao` in controller if not already done.
- This verification is a **Phase 2 PoC prerequisite task**.

## Interceptor (Example)

```java
@ObservedLog(category = "")
@Interceptor
@Priority(Interceptor.Priority.APPLICATION)
public class ObservedLogInterceptor {

    @AroundInvoke
    public Object around(InvocationContext ctx) throws Exception {
        ObservedLog cfg = resolveAnnotation(ctx);
        long start = System.currentTimeMillis();

        String source = ctx.getTarget().getClass().getSimpleName()
                        + "." + ctx.getMethod().getName();

        emit(cfg.level(), cfg.category(), source, "START",
             cfg.includeArgs() ? ctx.getParameters() : null, null);
        try {
            Object result = ctx.proceed();
            emit(cfg.level(), cfg.category(), source, "END",
                 null, Map.of("durationMs", System.currentTimeMillis() - start));
            return result;
        } catch (Exception ex) {
            emit(LogLevel.ERROR, cfg.category(), source, "ERROR",
                 null, Map.of(
                     "durationMs", System.currentTimeMillis() - start,
                     "error", ex.getClass().getSimpleName()
                 ));
            throw ex;
        }
    }

    private ObservedLog resolveAnnotation(InvocationContext ctx) {
        ObservedLog cfg = ctx.getMethod().getAnnotation(ObservedLog.class);
        return cfg != null ? cfg : ctx.getTarget().getClass().getAnnotation(ObservedLog.class);
    }
}
```

## DAO PoC Usage (Example)

```java
@ObservedLog(category = "LOG-ENTITY", level = LogLevel.INFO)
public List<Movie> getAllMovies(int setFirstResult, String category) {
    // existing body unchanged
}

@Transactional
@ObservedLog(category = "LOG-HIBERNATE-TX", level = LogLevel.INFO)
public synchronized List<Ticket> bookTickets(int screeningDateId, List<String> seats, String uuid, String orderId) {
    // existing body unchanged
}
```

## System-Level Filtering (Example)

```java
boolean enabled(LogLevel eventLevel, LogLevel threshold) {
    return eventLevel.ordinal() >= threshold.ordinal();
}
```

```properties
quarkus.log.level=INFO
app.logging.threshold=INFO
```

## File Routing Rules (Required)

- Hibernate subtype streams are separate files.
- New categories also use dedicated files.
- No single merged file for all categories.

### Routing Config Example (Quarkus-style)

```properties
# Hibernate transaction stream
quarkus.log.handler.file.hibernate_tx.enable=true
quarkus.log.handler.file.hibernate_tx.path=logs/hibernate-tx.log

# Hibernate SQL stream
quarkus.log.handler.file.hibernate_sql.enable=true
quarkus.log.handler.file.hibernate_sql.path=logs/hibernate-sql.log

# Hibernate statistics stream
quarkus.log.handler.file.hibernate_stats.enable=true
quarkus.log.handler.file.hibernate_stats.path=logs/hibernate-stats.log

# New category streams
quarkus.log.handler.file.log_entity.enable=true
quarkus.log.handler.file.log_entity.path=logs/entity.log

quarkus.log.handler.file.log_endpoint.enable=true
quarkus.log.handler.file.log_endpoint.path=logs/endpoint.log

quarkus.log.handler.file.log_filter.enable=true
quarkus.log.handler.file.log_filter.path=logs/filter.log
```

## Category -> File Map (Draft)
- `LOG-HIBERNATE-TX` -> `hibernate-tx.log`
- `LOG-SQL` -> `hibernate-sql.log`
- `LOG-HIBERNATE-STATS` -> `hibernate-stats.log`
- `LOG-ENTITY` -> `entity.log`
- `LOG-ENDPOINT` -> `endpoint.log`
- `LOG-FILTER` -> `filter.log`
- `LOG-SESSION` -> `session.log`

## Validation Checklist
- [ ] Annotation contract approved for DAO PoC.
- [ ] Interceptor emits START/END/ERROR with structured fields.
- [ ] System threshold filtering works for INFO/DEBUG/TRACE.
- [ ] Existing + Hibernate logs are structured.
- [ ] Hibernate subtype logs remain in separate files.
- [ ] New categories are routed to separate files.
- [ ] Grafana queries work per service/category/level/file stream.

## Risks and Mitigations
- **Risk**: too many annotation points.
  - **Mitigation**: allow class-level annotation defaults with method overrides.
- **Risk**: noisy logs after migration.
  - **Mitigation**: keep default threshold at INFO and category-level controls.
- **Risk**: routing drift across services.
  - **Mitigation**: central routing map + CI drift check for log categories/files.

## Open Review Questions
1. Should DAO PoC use method-level annotations only, or class-level defaults plus method overrides?
2. Should `includeArgs` default to `false` globally for security-by-default?
3. Should Hibernate statistics stream be enabled by default or only in DEBUG/TRACE environments?
