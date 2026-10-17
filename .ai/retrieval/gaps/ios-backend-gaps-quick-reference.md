# iOS/backend gaps and parsing behavior

Source-reviewed baseline: 2026-10-17. These observations distinguish backend output,
client tolerance and known limitations. They do not certify completeness, live integration
or that no changes are needed. See [wire contracts](../endpoints/endpoint-contract-analysis.md).

## Metadata and selection limitations

| Area | Current behavior | Consequence |
|------|------------------|-------------|
| Movie category | Ordinary movie summaries omit category; screening admin rows include it. iOS `Movie` has no category property. | Browse category chips use fixed labels, not categories extracted from movie summaries. |
| Browse rating | `MoviesVC` uses bundled `ratings-mock.json`; missing ratings use `"N/A"`. | Displayed ratings are fixture data, not live backend/RapidAPI ratings. |
| Detail enrichment | RapidAPI parsing reads `Title` and `Genre` only; failures are logged. | Do not claim current runtime/rating enrichment or guaranteed external availability. |
| Location-first selection | Client matches venue name to movie name, otherwise chooses first venue. Date may come from a per-movie request; failure is swallowed. | Fallback selection is not verified venue/date correctness. |
| Screen/date seat lookup | Screen IDs derive from venue fields; matching date falls back to first date. | Preserve context and test ambiguous/missing matches when changing navigation. |
| Event UI | Screen-news settings and event delivery exist; iOS logs events. | Notifications, automatic seat refresh and timeline UI need explicit implementation scope. |

## Verified parser rules

Paths below are under `SwiftCinemas/SwiftLoginScreen/DataManagers/`.
Accepted alternate fields are client behavior, not promises that the backend emits them.

| Source | Parsing behavior |
|--------|------------------|
| `MoviesDataManager.swift` | Requires convertible string/int `movieId` and string `name`. Detail: `detail` -> `description` -> empty. Image: `large_picture` -> `thumbnail_picture` -> empty. IMDb: `iMDB_url` -> `imdbUrl` -> empty. |
| `MoviesDataManager.swift` | Paging requires `movies`; search accepts `searchedMovies` -> `movies`; trending accepts `trendingMovies` -> `movies` -> `searchedMovies`. Missing accepted array throws; invalid rows are dropped. |
| `VenuesDataManager.swift` | Requires convertible venue/location IDs and string name. Address: `address` -> `formatted_address` -> empty. Image: `venues_picture` -> `thumbnail` -> empty. Screen ID accepts string/int. |
| `DatesDataManager.swift` | Requires `dates`; ID accepts `screeningDateId` -> canonical `screeningDatesId`, string/int. Date: `date` -> canonical `screeningDate` -> empty; time optional. Invalid rows are dropped. |
| `SeatsDataManager.swift` | Requires `seatsforscreen`; records require integer seat ID/price, double tax and string seat number/row/reservation. Only string `"1"` means reserved; there is no explicit boolean reservation fallback. |
| `CheckoutDataManager.swift` | `Amount`/`TaxAmount` accept string or number. Result arrays default empty; invalid rows drop. Error lookup: `Error` -> `Error with Transaction` -> `message`. |
| `CheckoutDataManager.swift` | Purchase/ticket array parsing can turn missing/non-array envelopes into empty lists. Purchase date uses `screeningDate`; ticket date uses `screening_date`. |

Do not silently broaden backend guarantees to match these defaults. Empty arrays and
`compactMap` can hide malformed data; use targeted fixtures to distinguish valid empty
responses from decoding loss.

## Business success is separate from transport

- APIClient accepts HTTP 2xx before business validation.
- Checkout client success is case-sensitive:
  `ResponseText == "hello" || (Status ?? status) == "success"`.
  Backend `Status` is the Braintree transaction status; it is not fixed `"success"`.
- A reservation failure can return HTTP 200 and `Success: "true"` alongside `Error`.
  Neither alone proves payment success.
- Ticket cancellation and purchase deletion require string `Success == "true"`.
  Both use POST `/login/ManagePurchases`; only cancellation includes `ticketsToBeCancelled`.
  The iOS `refundPurchase` name does not establish a financial refund.

## Change/verification checklist

Compare DTOs/mappers with data-manager requirements, then exercise missing/alternate fields,
numeric/string IDs, malformed rows, empty arrays and business-failure bodies. For metadata UI,
distinguish fixture data from external enrichment. For navigation, check venue/date identity
rather than merely accepting the first returned row.

Backend evidence: mbooks `rest/responserecord/` and `rest/responsemapper/`.
Additional iOS evidence: `MoviesVC.swift`, `MovieDetailVC.swift`,
`Networking/BackendServices.swift`, `Networking/APIClient.swift`,
`BroadCasting/Websocket.swift`. Validation entrypoints are in the
[operational playbook](../instructions.md).
