# iOS/backend endpoint contracts

Source-reviewed baseline: 2026-10-17. Curated booking/client contracts, not an exhaustive
admin API catalog or live validation report. Use `cinemas-backend` endpoint/model queries
and `swiftcinemas` source analysis for changes. Stable IDs live in the
[contracts index](../references/CONTRACTS_INDEX.md).

## Browse and selection

Paths below are relative to `/mbooks-1/rest/book`. Field casing is significant.

| GET path | Inputs | Body/envelope |
|----------|--------|---------------|
| `/movies` | None | `movies` array; empty uses `NotFoundMovies: "EndOfFile:)"` |
| `/movies/paging` | `X-Device` header; `setFirstResult` (default -1), `category` | Same as movies; response adds `APIKEY`, `ApiKey` cookie and `Last-Modified` |
| `/movies/{name}/{order}` | Name substring; ASC/DESC order | `searchedMovies`; invalid order/no results gives 400 `Title`/`Message` |
| `/movies/search` | `match`, `setFirstResult` (default 0), `category` | `searchedMovies`; empty uses `NotFoundMovies: ["No such movie(s)"]`; supplied match shorter than 3 characters gives 400 |
| `/trending-movies` | `days` (default 30, >=1), `limit` (default 10, 1-50) | `trendingMovies`; validation/failure uses `error`/`message` with 400/500 |
| `/locations` | None | `locations` |
| `/venue/{movieId}` | Movie ID | `venues` |
| `/venue/v2/{movieId}` | Movie ID | `locations`, not venue rows; empty gives 400 |
| `/venue/movies` | `locationId` | `movies` and singular `venue` arrays |
| `/locations/venue` | `venuesId` | Bare location object, not an array envelope |
| `/dates/{locationId}/{movieId}` | Location/movie IDs | `dates` |
| `/seats/{screeningDateId}` | Screening-date ID | `seatsforscreen` |
| `/admin/moviesonvenues` | None | `venues` screening rows; empty gives `{}` |
| `/admin/moviesonvenuescategorized` | `category` | Same screening-row envelope |
| `/admin/moviesonvenuessearch` | `match` | Same screening-row envelope |

Paging uses 30 rows for normal paged queries; offset -1 with no category returns the full
list, not page one. Search clamps negative offsets to zero and uses substring `LIKE`,
not a full-text index. `APIKEY` is generated from `X-Device` on the paging response; it is
not a required incoming `APIKEY` header or the payment client token.

### Serialized selection records

Records are under `mbooks-quarkus/src/main/java/com/jeet/rest/responserecord/`.
Do not substitute entity fields or iOS fallback aliases for these wire names.

| Record | Serialized fields |
|--------|-------------------|
| `movie/MovieSummaryItem.java` | `movieId` (string), `name`, `detail`, `large_picture`, `thumbnail_picture`, `iMDB_url`; no category/rating/genre |
| `movie/TrendingMovieItem.java` | `movieId` (int), `name`, `thumbnail_picture`, `large_picture`, `bookedTickets` (long), `lastBookingTime` |
| `venue/VenueItem.java` | `venuesId`, `name`, `address`, `contact`, `venues_picture`, `screen_screenId`, `locationId` |
| `venue/LocationItem.java` | `locationId`, `formatted_address`, `name`, `latitude`, `longitude`, `thumbnail` |
| `venue/VenueScreeningItem.java` | `movie`, `movieId`, `category`, `large_picture`, `ScreeningId`, `venueId`, `venue`, `screeningDatesId`, `date` (strings) |
| `venue/ScreeningDateItem.java` | `screeningDatesId`, `screeningDate`, `movieId`, `venues_picture` |
| `venue/SeatItem.java` | `seatId`, `seatNumber`, `seatRow`, `isReserved` (string), `price`, `tax` |

## Gateway checkout and purchase management

Client routes retain `/login` session handling; downstream paths are relative to
`/mbooks-1/rest/book`. These are proxy calls, not HTTP redirects.

| Client method/path | Downstream | Input |
|--------------------|------------|-------|
| GET `/login/CheckOut` | GET `/payment/clientToken` | Session |
| POST `/login/CheckOut` | POST `/payment/fullcheckout2` | Form fields below |
| GET `/login/GetAllPurchases` | GET `/purchases` | Session owner forwarded as `uuid`; iOS also sends `book=GetAllPurchases` |
| GET `/login/ManagePurchases` | GET `/purchases/tickets` | Query `purchaseId` |
| POST `/login/ManagePurchases` | POST `/managepurchases` | Form `purchaseId` and `ticketsToBeCancelled` JSON string |
| POST `/login/ManagePurchases` | POST `/deletepurchases` | Form `purchaseId`, cancellation field absent |

Checkout is `application/x-www-form-urlencoded` with `payment_method_nonce`, `orderId`
(current milliseconds), and `seatsToBeReserved`. The latter is a JSON string:

```json
{"seatsToBeReserved":[{"screeningDateId":"5","seat":"A1-B2-"}]}
```

The seat string contains seat numbers, not IDs. Cancellation JSON is `{"ticketIds":[42,43]}`.
Do not infer idempotency from `orderId`, or a financial refund from the iOS `refundPurchase`
method name.

### Responses and business success

- Client token: `{"clientToken":"..."}`; downstream null token produces 404 without a body.
- Checkout success fields: `ResponseText`, `purchaseId`, `AuthCode`, `ResponseCode`, `Status`,
  `Amount`, `TaxAmount`, `Success`, `tickets`, `seatsforscreen`.
  `ResponseText` is `"hello"`, `Success` is string `"true"`, and `Status` is the Braintree
  transaction status string, not fixed `"success"`. `Amount` is numeric; `TaxAmount` is a
  formatted string.
- Reservation failure can be HTTP 200 with `Error`, string `Success: "true"`, and `Message`.
  Transaction failure can be HTTP 200 with `Error with Transaction`.
  Missing checkout parameters produce 400 `{"error":"Missing required parameters"}`.
  Never use HTTP 200 or `Success` alone as checkout proof.
- iOS accepts `ResponseText == "hello" || (Status ?? status) == "success"` (case-sensitive).
  This is client compatibility logic, not a guarantee that backend emits either status alias.
- Checkout `tickets`/`seatsforscreen` still serialize entity lists; do not assume they have
  the purchase-ticket/seat DTO schema.
- Purchase list: `purchases`, or `{}` when empty. Tickets: `tickets`, or downstream 400 when
  absent. Cancel/delete success is `{"Success":"true"}`; cancellation authorization failure
  can return 200 `{"Error":"User not authorized!)"}`.

Purchase DTO fields:

| Record | Fields |
|--------|--------|
| `purchase/PurchaseSummaryItem.java` | `purchaseId`, `orderId`, `movie_name`, `movie_picture`, `screeningDate`, `venue_name`, `purchaseDate` (strings) |
| `purchase/TicketSummaryItem.java` | `ticketId`, `price`, `tax`, `seats_seatNumber`, `seats_seatRow`, `movie_name`, `venue_name`, `screening_date`, `screen_screenId`, `movie_picture`, `iMDB_url` |

Reservations lock before checking availability and commit before external payment.
Payment failure uses compensating cancellation; there is no atomic DB/payment transaction.

## Screen-news settings and events

- GET/PUT `/login/admin/newsSettings/screen` forwards to `/mbook-1/rest/news-settings/screen`.
  PUT requires a boolean `enabled`; response is `{"enabled":true}` or false. The gateway
  derives ownership from the session, ignoring body ownership fields. Missing settings mean
  disabled; storage uses `"yes"`/`"no"`.
- `/mbook-1/ws?deviceId=...` rejects blank/missing device identity. Screen events are delivered
  only for a device resolving to one distinct active user with screen news enabled.
- JSON keys: `movie`, `date`, `venue`, `screeningId`, `screeningDatesId`, `eventType`,
  `category`. Types are `created`/`updated`/`deleted`; category is event metadata `"screening"`,
  not movie genre. Missing type defaults to `created`.
- Kafka transport uses Base64 Java serialization; WebSocket JSON is constructed separately.
  iOS currently logs received events. No `/timeline-feed` implementation was found.

## Evidence and validation boundary

Backend sources under `mbooks-quarkus/src/main/java/com/jeet/`: `rest/MovieController.java`,
`VenueController.java`, `CheckoutController.java`, `PurchaseController.java`,
`rest/ApiResponseFactory.java`, `rest/requestbean/`, `rest/responserecord/`,
`rest/responsemapper/`, `service/CheckoutService.java`, `db/DAO.java`.
Gateway: `dalogin-quarkus/src/main/java/com/dalogin/servlets/` and `client/`.
Settings/events: mbook `rest/NewsSettingsController.java`, `service/NewsSettingsService.java`,
`broadcasting/WebSocketServer.java`, `ActiveSessionResolver.java`, `KafkaMoviesListener.java`.
iOS: `SwiftCinemas/SwiftLoginScreen/Networking/BackendServices.swift` and `DataManagers/`.

See [client gaps](../gaps/ios-backend-gaps-quick-reference.md) for parser behavior.
Before contract changes, exercise successful, empty, malformed and business-failure responses
with the affected clients; source inspection alone does not establish these outcomes.
