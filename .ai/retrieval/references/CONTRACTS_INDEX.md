# Canonical Contracts Index

This is the canonical endpoint registry for the repo.

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
| CID-MBOOKS-MOVIES | mbooks-quarkus | GET | /mbooks-1/rest/book/movies | @backend-dev | @frontend-dev, @ios-dev | P0 | active |
| CID-MBOOKS-LOCATIONS | mbooks-quarkus | GET | /mbooks-1/rest/book/locations | @backend-dev | @frontend-dev, @ios-dev | P0 | active |
| CID-MBOOKS-VENUE-V2 | mbooks-quarkus | GET | /mbooks-1/rest/book/venue/v2/{movieId} | @backend-dev | @frontend-dev, @ios-dev | P1 | active |
| CID-MBOOKS-DATES | mbooks-quarkus | GET | /mbooks-1/rest/book/dates/{locationId}/{movieId} | @backend-dev | @frontend-dev, @ios-dev | P1 | active |
| CID-MBOOKS-SEATS | mbooks-quarkus | GET | /mbooks-1/rest/book/seats/{screeningDateId} | @backend-dev | @frontend-dev, @ios-dev | P1 | active |
| CID-MBOOKS-TRENDING | mbooks-quarkus | GET | /mbooks-1/rest/book/trending-movies | @backend-dev | @frontend-dev, @ios-dev | P2 | planned |
| CID-MBOOKS-TIMELINE | mbooks-quarkus | GET | /mbooks-1/rest/book/timeline-feed | @backend-dev | @frontend-dev, @ios-dev | P2 | planned |

## Required References in Spec/Tasks

For each feature:
- Add a `Contract IDs` section in spec files listing all impacted `CID-*` IDs.
- Add at least one task that validates/updates this index entry.
- If endpoint is new, add `Status: planned` first, then switch to `active` after implementation and tests.

