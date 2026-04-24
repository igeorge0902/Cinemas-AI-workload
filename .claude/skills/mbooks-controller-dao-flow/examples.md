# Examples: Mbooks Controller DAO Flow

## Example 1
### Input
`POST /rest/book/payment/fullcheckout2` returns 200 but seats remain unreserved.

### Output
- Maps endpoint to `BookController` checkout handler.
- Traces into `TicketService` and `DAO.bookTickets()`.
- Verifies seat update writes (`isReserved`) and purchase/ticket insert sequence.
- Identifies divergence point and proposes minimal fix.

## Example 2
### Input
`GET /rest/book/movies/paging` returns data but sorting or filtering is incorrect.

### Output
- Locates controller method and downstream DAO query call.
- Confirms query parameter mapping (page, limit, filter inputs).
- Flags mismatch between request params and DAO query builder.
- Returns patch target plus quick verification call.

