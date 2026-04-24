# Mbooks Controller DAO Flow

## Purpose
Trace and validate request flow from `BookController` endpoints to `DAO` operations in `mbooks-quarkus`, then pinpoint minimal-safe fix locations for booking/payment/data issues.

## Use When
- A `mbooks-1/rest/book/...` endpoint behaves incorrectly and root cause may be in controller-to-DAO mapping.
- You need to confirm which DAO method a controller path actually triggers.
- You are refactoring endpoint logic and must preserve current data-write/read behavior.

## Do Not Use When
- The issue is clearly in `dalogin-quarkus` authentication filters only.
- The issue is pure frontend rendering with no backend request/response mismatch.

## Inputs
- Required: endpoint path + HTTP method (example: `POST /rest/book/payment/fullcheckout2`).
- Required: observed behavior (status, payload mismatch, DB side effect, or stack trace).
- Optional: sample request body/params.
- Optional: relevant pod log window timestamp.

## Outputs
- Exact controller method handling the endpoint.
- Exact DAO/service methods involved in read/write flow.
- Root-cause candidate list ordered by request path position.
- Minimal edit target(s) and verification steps.

## Constraints
- Keep endpoint contract stable unless explicitly requested (path, params, JSON shape).
- Preserve transaction and seat-lock semantics in checkout flow.
- Do not change `isReserved` string semantics (`"0"` / `"1"`) without coordinated migration.
- Prefer surgical fixes in `mbooks-quarkus` over cross-service changes.

## Workflow
1. Map route to controller in `mbooks-quarkus/src/main/java/com/jeet/rest/BookController.java`.
2. Identify service and DAO calls from that method:
   - `mbooks-quarkus/src/main/java/com/jeet/service/PaymentService.java`
   - `mbooks-quarkus/src/main/java/com/jeet/booking/TicketService.java`
   - `mbooks-quarkus/src/main/java/com/jeet/db/DAO.java`
3. Confirm request parameter transformations (seat strings, IDs, paging params).
4. Validate transaction boundary and rollback path for mutating endpoints.
5. Compare expected DB side effects (Ticket/Purchase/Seat updates) against code path.
6. Propose minimal patch in the earliest divergence point.
7. Verify with focused API call and DB/log checks.

## Validation Checklist
- [ ] Endpoint method is mapped to the correct `BookController` handler.
- [ ] Full controller -> service -> DAO path is documented for the failing scenario.
- [ ] Mutating flow checks transaction/rollback behavior.
- [ ] Proposed fix preserves endpoint contract.
- [ ] Verification steps include at least one success and one failure path.

