# Mbooks Controller-to-DAO Flow

## Purpose

Trace and validate an `mbooks-quarkus` request through its family controller, request bean,
service, response mapper/record, and `DAO` operation. Use the trace to identify the earliest
safe fix location while preserving the public endpoint contract.

## Use When

- An `/mbooks-1/rest/book/...` endpoint has an incorrect status, payload, validation result, or
  database side effect.
- You need to identify which service and `DAO` methods a route invokes.
- You are changing endpoint behavior and must preserve current read/write, reservation, payment,
  or rollback semantics.
- You are adding an endpoint to one of the existing Movie, Venue, Purchase, or Checkout families.

## Do Not Use When

- The issue is isolated to `dalogin-quarkus` authentication or client filters.
- The issue is purely frontend rendering with no backend request/response mismatch.
- The route belongs to another backend module.

## Inputs

- Required: endpoint path and HTTP method, for example
  `POST /mbooks-1/rest/book/payment/fullcheckout2`.
- Required: observed behavior: status code, payload mismatch, database side effect, or stack
  trace.
- Optional: request headers, path/query/form parameters, or JSON body.
- Optional: relevant Quarkus, DAO, payment, or Kafka log window.

## Outputs

- Exact family controller and method handling the route.
- Bound request fields and any `@BeanParam` transformation/validation.
- Exact controller -> service -> DAO/payment/ticket call chain.
- Response mapper, response record, and `ApiResponseFactory` path.
- Ordered root-cause candidates based on where actual behavior first diverges.
- Minimal edit targets and focused verification steps.

## Current Architecture

The application root is configured as `/mbooks-1`; controllers use `@Path("/rest")`.

### Movie family

- Controller: `mbooks-quarkus/src/main/java/com/jeet/rest/MovieController.java`
- Service: `mbooks-quarkus/src/main/java/com/jeet/service/MovieService.java`
- Mapper: `mbooks-quarkus/src/main/java/com/jeet/rest/responsemapper/MovieMapper.java`
- Records:
  `mbooks-quarkus/src/main/java/com/jeet/rest/responserecord/movie/`

### Venue family

- Controller: `mbooks-quarkus/src/main/java/com/jeet/rest/VenueController.java`
- Service: `mbooks-quarkus/src/main/java/com/jeet/service/VenueService.java`
- Mapper: `mbooks-quarkus/src/main/java/com/jeet/rest/responsemapper/VenueMapper.java`
- Records:
  `mbooks-quarkus/src/main/java/com/jeet/rest/responserecord/venue/`
- Includes location, screening-date, seat-map, and screen-admin endpoints.
- `addScreen` also publishes an `AddMovie` Kafka event after successful persistence.

### Purchase family

- Controller: `mbooks-quarkus/src/main/java/com/jeet/rest/PurchaseController.java`
- Service: `mbooks-quarkus/src/main/java/com/jeet/service/booking/PurchaseService.java`
- Mapper: `mbooks-quarkus/src/main/java/com/jeet/rest/responsemapper/PurchaseMapper.java`
- Records:
  `mbooks-quarkus/src/main/java/com/jeet/rest/responserecord/purchase/`
- Includes purchase history, tickets per purchase, ticket cancellation, and purchase deletion.

### Checkout family

- Controller: `mbooks-quarkus/src/main/java/com/jeet/rest/CheckoutController.java`
- Service: `mbooks-quarkus/src/main/java/com/jeet/service/CheckoutService.java`
- Mapper: `mbooks-quarkus/src/main/java/com/jeet/rest/responsemapper/CheckoutMapper.java`
- Records:
  `mbooks-quarkus/src/main/java/com/jeet/rest/responserecord/checkout/`
- Collaborators:
  - `mbooks-quarkus/src/main/java/com/jeet/service/booking/TicketService.java`
  - `mbooks-quarkus/src/main/java/com/jeet/service/booking/PurchaseService.java`
  - `mbooks-quarkus/src/main/java/com/jeet/service/booking/PaymentService.java`

### Shared HTTP and persistence layers

- Request beans:
  `mbooks-quarkus/src/main/java/com/jeet/rest/requestbean/`
- Response construction:
  `mbooks-quarkus/src/main/java/com/jeet/rest/ApiResponseFactory.java`
- Persistence:
  `mbooks-quarkus/src/main/java/com/jeet/db/DAO.java`

`BookController` and `BookingHandlerImpl` no longer exist. Do not reintroduce either as a
pass-through layer.

## Layer Responsibilities

1. **Controller**
   - Owns JAX-RS route annotations and HTTP parameter binding.
   - Uses `@BeanParam` when a method has more than one bound request input.
   - Performs request-level guard checks.
   - Delegates orchestration to a family service.
   - Builds responses only through `ApiResponseFactory`.

2. **Request bean**
   - Carries `@PathParam`, `@QueryParam`, `@HeaderParam`, `@FormParam`, `@DefaultValue`, or
     `@Context` bindings.
   - May expose simple normalization or validation helpers.
   - Must not contain persistence, payment, reservation, or other business logic.

3. **Service**
   - Owns family orchestration and calls `DAO` or collaborating services.
   - Preserves transaction ordering, rollback behavior, and existing business rules.
   - Returns domain/service results or mapper-produced response records.

4. **Response mapper**
   - Converts domain entities/projections into family response records.
   - Preserves legacy field names, types, nullability, and root wrappers.

5. **Response record**
   - Represents a public success-path payload.
   - Lives in its family subpackage under `rest/responserecord`.
   - Must not contain orchestration or persistence behavior.

6. **DAO**
   - Owns Hibernate queries and database mutations.
   - Remains the lower persistence boundary used by services.

## Controller Flow Rules

- Use explicit guard clauses and `if` branches for validation and response selection.
- Do not use ternary expressions to choose between `ApiResponseFactory` calls, success/error
  responses, or exception paths.
- Do not add controller-local try/catch blocks when an existing `CustomExceptions` guard can be
  thrown and handled by JAX-RS.
- A ternary may be used only for a simple local value default when it materially improves
  readability; it must not control endpoint flow.
- Do not construct responses directly with
  `Response.status(...).entity(...).build()` in family controllers.
- Preserve existing status codes and error payload keys when calling
  `ApiResponseFactory#error(...)`.

## Contract Constraints

- Keep endpoint paths, parameter names, status codes, JSON roots, field names, field types, and
  nullability stable unless a contract change is explicitly requested.
- Preserve legacy snake_case and unusual capitalization such as `iMDB_url`, `ScreeningId`,
  `ResponseText`, and `Success`.
- Do not replace string-valued legacy booleans such as `"Success": "true"` with JSON booleans
  without consumer coordination.
- Preserve `isReserved` string semantics (`"0"` / `"1"`).
- Entity-backed nullable fields must remain nullable where legacy `JSONObject` output produced
  JSON `null`.
- Do not force entity-returning endpoints into new response records unless their public shape
  needs explicit mapping.

## Checkout Trace

For `POST /mbooks-1/rest/book/payment/fullcheckout2`:

1. `CheckoutController#fullcheckout2` binds `FullCheckoutParams`.
2. The controller rejects missing required values through `ApiResponseFactory`.
3. `CheckoutService#checkout` parses the seat groups.
4. `TicketService#reserveTickets` calls `DAO#bookTickets`.
5. Each successful reservation contributes ticket IDs, amount, tax, and updated seats.
6. Any reservation failure invokes `TicketService#rollbackTickets`.
7. `PurchaseService#getBrainTreeCustomer` and `PaymentService#getOrCreateCustomerId` resolve the
   Braintree customer.
8. `PurchaseService#setBrainTreeCustomerId` persists the customer ID.
9. `PaymentService#processTransaction` performs the charge.
10. A failed transaction rolls back reserved tickets.
11. `CheckoutMapper` creates `FullCheckoutResponse`.
12. `CheckoutController` returns the service outcome through `ApiResponseFactory`.

When debugging checkout, verify every step in this order. Do not move payment before successful
seat reservation or remove either rollback path.

## Workflow

1. Find the route annotation in the four family controllers; do not search for
   `BookController`.
2. Record every bound input, including fields supplied by a `@BeanParam`.
3. Follow the controller call into the owning family service.
4. Follow service calls into `DAO`, `TicketService`, `PurchaseService`, or `PaymentService`.
5. For writes, document mutation order, transaction boundary, external side effects, and rollback.
6. Follow the success result through the family mapper and response record.
7. Confirm the controller uses `ApiResponseFactory` and explicit `if`/guard flow.
8. Compare the actual response and database effects with the preserved endpoint contract.
9. Fix the earliest divergence in the correct layer; do not compensate in a later layer.
10. Verify a success path and at least one relevant failure/empty path.

## Validation

The environment default is Java 21; `mbooks-quarkus` compiles for Java 17. Do not force a
Java 17 `JAVA_HOME` when running local Maven commands.

For direct local development, start MySQL first and then run mbooks without Minikube:

```bash
cd mbooks-quarkus
mvn quarkus:dev -f pom.xml
```

Direct `quarkus:dev` mode has no Apache reverse proxy. Call mbooks through its configured
localhost port and `/mbooks-1` root path. Do not assume Apache route fan-out, TLS termination,
proxy-added headers, or Apache-managed CORS behavior when validating local requests.
The shell environment may export HTTP/HTTPS proxies by default; use `proxy_off` for the local
session or explicitly bypass `localhost,127.0.0.1` in the client.

Run tests on a random Quarkus test port when `quarkus:dev` is already active:

```bash
cd mbooks-quarkus
mvn -Dquarkus.http.test-port=0 test
```

For a live local request, bypass the configured proxy:

```bash
curl --noproxy localhost,127.0.0.1 \
  http://localhost:8080/mbooks-1/rest/book/movies
```

## Validation Checklist

- [ ] Route is mapped to the correct family controller.
- [ ] Multi-input binding uses the correct request bean.
- [ ] Full controller -> service -> DAO/collaborator path is documented.
- [ ] Mutating flows preserve transaction order and rollback behavior.
- [ ] Success output passes through the family mapper/record where applicable.
- [ ] Controller response construction uses `ApiResponseFactory`.
- [ ] Controller flow uses guard clauses/plain `if` branches, not response ternaries.
- [ ] Endpoint contract is unchanged unless a change was explicitly requested.
- [ ] Verification covers a success path and a relevant failure or empty path.
