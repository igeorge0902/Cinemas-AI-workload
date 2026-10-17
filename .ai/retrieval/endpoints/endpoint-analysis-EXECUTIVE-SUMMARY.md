# iOS/backend contract summary

Source-reviewed baseline: 2026-10-17. This is not a live integration result, a coverage
assessment or a blanket recommendation that no backend changes are needed.

## Current findings

| Area | Source-backed finding |
|------|-----------------------|
| REST structure | mbooks uses Movie, Venue, Checkout and Purchase controllers, services and response mappers; old monolithic controller references are obsolete. |
| Movie metadata | Ordinary movie summaries omit category/rating/genre. iOS browse ratings use a bundled fixture; RapidAPI detail parsing reads title/genre only. |
| Dates and venues | `/venue/v2/{movieId}` returns locations. Date DTO keys are `screeningDatesId` and `screeningDate`; legacy client fallbacks are not the canonical response schema. |
| Checkout | Form-encoded through `/login/CheckOut`. `ResponseText == "hello"` is the backend success marker; `Status` is Braintree transaction status, not a constant `"success"`. |
| Purchases | Gateway routes are `/login/GetAllPurchases` and `/login/ManagePurchases`, not invented `/login/purchases/...` routes. |
| Payment integrity | Reservations commit before payment; failure uses compensating cancellation. Checkout is not a single atomic DB/payment transaction. |
| Feature status | Trending, device-scoped screen events and screen-news settings exist in source. No timeline-feed endpoint was found. |
| Client limitations | Tolerant parsing can drop invalid records or turn missing arrays into empty results. This does not establish correct integration. |

## Use the focused references

- [Endpoint contracts](endpoint-contract-analysis.md): envelopes, fields and source evidence.
- [Dependency map](endpoint-dependency-map.md): booking, purchase and event flow boundaries.
- [Gap reference](../gaps/ios-backend-gaps-quick-reference.md): fallback behavior and risks.
- [Contracts index](../references/CONTRACTS_INDEX.md): stable CIDs and implementation status.
- [Operational playbook](../instructions.md): MCP discovery and focused validation.

Before changing a contract, compare the owning mapper/record with both client consumers and
validate the affected success, empty, failure and type-variant cases.
Do not treat HTTP 200, a registry label or a parsing fallback as proof of business success.
