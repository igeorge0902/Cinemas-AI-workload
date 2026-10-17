# Canonical Contracts Index

Stable contract identifiers for feature specs and tasks. This is a curated registry, not
an exhaustive generated endpoint catalog. See the [contract reference](../endpoints/endpoint-contract-analysis.md)
for current response shapes and implementation evidence.

Rules:
- Every new endpoint must have a `CID-*` entry here.
- Feature specs and tasks must reference applicable `CID-*` IDs.
- Module `README.md` files remain implementation docs, but this file is the single contract index.

## Contract Table

| Contract ID | Service | Method | Endpoint | Owner | Consumers | Priority | Status |
|---|---|---|---|---|---|---|---|
| CID-LOGIN-HELLOWORLD | dalogin-quarkus | POST | /login/HelloWorld | @backend-dev | @frontend-dev, @ios-dev | P0 | active |
| CID-LOGIN-CHECKOUT-GET | dalogin-quarkus | GET | /login/CheckOut | @backend-dev | @frontend-dev, @ios-dev | P0 | active |
| CID-LOGIN-CHECKOUT-POST | dalogin-quarkus | POST | /login/CheckOut | @backend-dev | @frontend-dev, @ios-dev | P0 | active |
| CID-LOGIN-PURCHASES | dalogin-quarkus | GET | /login/GetAllPurchases | @backend-dev | @frontend-dev, @ios-dev | P0 | implemented |
| CID-LOGIN-PURCHASE-TICKETS | dalogin-quarkus | GET | /login/ManagePurchases?purchaseId={id} | @backend-dev | @frontend-dev, @ios-dev | P0 | implemented |
| CID-LOGIN-PURCHASE-MANAGE | dalogin-quarkus | POST | /login/ManagePurchases | @backend-dev | @frontend-dev, @ios-dev | P0 | implemented |
| CID-MBOOKS-MOVIES | mbooks-quarkus | GET | /mbooks-1/rest/book/movies | @backend-dev | @frontend-dev, @ios-dev | P0 | active |
| CID-MBOOKS-LOCATIONS | mbooks-quarkus | GET | /mbooks-1/rest/book/locations | @backend-dev | @frontend-dev, @ios-dev | P0 | active |
| CID-MBOOKS-VENUE-V2 | mbooks-quarkus | GET | /mbooks-1/rest/book/venue/v2/{movieId} | @backend-dev | @frontend-dev, @ios-dev | P1 | active |
| CID-MBOOKS-DATES | mbooks-quarkus | GET | /mbooks-1/rest/book/dates/{locationId}/{movieId} | @backend-dev | @frontend-dev, @ios-dev | P1 | active |
| CID-MBOOKS-SEATS | mbooks-quarkus | GET | /mbooks-1/rest/book/seats/{screeningDateId} | @backend-dev | @frontend-dev, @ios-dev | P1 | active |
| CID-MBOOKS-TRENDING | mbooks-quarkus | GET | /mbooks-1/rest/book/trending-movies | @backend-dev | @ios-dev; web impact to verify | P2 | implemented |
| CID-MBOOKS-TIMELINE | mbooks-quarkus | GET | /mbooks-1/rest/book/timeline-feed | @backend-dev | @frontend-dev, @ios-dev | P2 | planned |
| CID-MBOOK-WS-SCREEN-NEWS | mbook-quarkus | WebSocket | /mbook-1/ws?deviceId={deviceId} | @backend-dev | @ios-dev (logging); web impact to verify | P2 | implemented |
| CID-MBOOK-NEWS-SETTINGS-SCREEN | mbook-quarkus via dalogin | GET/PUT | /mbook-1/rest/news-settings/screen via /login/admin/newsSettings/screen | @backend-dev | @ios-dev | P2 | implemented |

## Status and compatibility

- `planned`: proposed contract; `/timeline-feed` has no implementation found in current backend sources.
- `implemented`: present in current source; runtime validation is not established by this refresh.
- `active`: existing registry designation retained; it is not a new claim that tests passed.
- Promote implemented contracts to active only with implementation and test evidence.
- Preserve existing CID identifiers when implementations move between controllers/services.
- Purchase-management POST cancels when `ticketsToBeCancelled` is present and deletes when
  absent; neither route name nor an iOS `refundPurchase` method establishes financial refund behavior.

## Required References in Spec/Tasks

For each feature:
- Add a `Contract IDs` section in spec files listing all impacted `CID-*` IDs.
- Add at least one task that validates/updates this index entry.
- For new endpoints, start `planned`, use `implemented` for source-only completion, and switch
  to `active` after implementation and tests. Keep validation evidence with the feature.
