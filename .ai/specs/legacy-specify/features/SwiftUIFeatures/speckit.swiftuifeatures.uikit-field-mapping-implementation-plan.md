# UIKit Field Mapping Implementation Plan

This plan is the required field-contract baseline for task execution.

## Rules
- Use existing functions/endpoints only.
- Do not add new backend methods or payload keys.
- Any field not provided by current backend contracts must remain local UI state/mock data.

## AdminVC + AdminUpdateVC Mapping

| Screen | UI field | UIKit target | Model/key | DataManager method | Service method / endpoint | Source |
|---|---|---|---|---|---|---|
| AdminVC/AdminUpdateVC | Movie name | `AdminVC` / `AdminUpdateVC` select field | `AdminScreeningModel.movie` | `fetchScreenings`, `searchScreenings` | `adminMoviesOnVenues*` | backend |
| AdminVC/AdminUpdateVC | Movie ID (internal only) | selection payload only | `AdminScreeningModel.movieId` | `updateMovie` | `adminUpdateScreen` | backend |
| AdminVC/AdminUpdateVC | Venue name | select field | `AdminScreeningModel.venue` | `fetchScreenings`, `searchScreenings` | `adminMoviesOnVenues*` | backend |
| AdminVC/AdminUpdateVC | Venue ID | payload only | `AdminScreeningModel.venueId` | `updateVenue` | `adminUpdateScreen` | backend |
| AdminVC/AdminUpdateVC | Screening date | date input | `AdminScreeningModel.date` | `resolveScreenContext` | `adminMoviesOnVenues*` | backend |
| AdminVC/AdminUpdateVC | Screen ID | screen field | `AdminScreeningModel.screeningId` | `resolveScreenContext` | `adminMoviesOnVenues*` | backend |
| AdminVC/AdminUpdateVC | Category | optional field | `AdminScreeningModel.category` | `resolveScreenContext` | `adminMoviesOnVenues*` | backend |
| AdminVC/AdminUpdateVC | ScreeningDatesId | update/delete context | `AdminScreeningModel.screeningDatesId` | `resolveScreenContext` | `adminMoviesOnVenues*` | backend |
| AdminUpdateVC | Changed venue marker `(original)/(new selection)` | venue list row sublabel | n/a | local compare selected vs original | n/a | local UI state |
| Admin popovers | List row visual style, reusable row/button composition | shared reusable cells/helpers | n/a | n/a | n/a | local UI implementation |

## MenuVC + PurchasesVC + TicketsVC Mapping

| Screen | UI field | UIKit target | Model/key | DataManager method | Service method / endpoint | Source |
|---|---|---|---|---|---|---|
| MenuVC | Username | profile label | `UserProfileModel.username` (`user`) | `fetchUserProfile` | `getUser` (`/login/admin`) | backend |
| MenuVC | Email | profile label | `UserProfileModel.email` (`email`) | `fetchUserProfile` | `getUser` (`/login/admin`) | backend |
| MenuVC | Profile picture URL/image | avatar image | `UserProfileModel.profilePicture` | `fetchUserProfile` + image fetch | `getUser` + image URL fetch | backend |
| PurchasesVC | Movie title | row text | `PurchaseSummaryModel.movieName` (`movie_name`) | `fetchAllPurchases` | `getAllPurchases` (`/login/GetAllPurchases`) | backend |
| PurchasesVC | Movie image | row image | `PurchaseSummaryModel.moviePicture` (`movie_picture`) | `fetchAllPurchases` + image fetch | `getAllPurchases` + image URL fetch | backend |
| PurchasesVC | Screening date | row subtext | `PurchaseSummaryModel.screeningDate` | `fetchAllPurchases` | `getAllPurchases` | backend |
| PurchasesVC | Purchase ID | row metadata | `PurchaseSummaryModel.purchaseId` | `fetchAllPurchases` | `getAllPurchases` | backend |
| PurchasesVC | Refund action | row swipe action | request key `purchaseId` | `refundPurchase` | `postManagePurchases` (`/login/ManagePurchases`) | backend |
| PurchasesVC | Long-press enables swipe | gesture state | n/a | n/a | n/a | local UI state |
| PurchasesVC | Gray cumulative refund bubble | overlay text list | n/a | n/a | n/a | local UI state/mock |
| TicketsVC | Movie title | ticket row | `TicketDetailModel.movieName` (`movie_name`) | `fetchTickets` | `getManagePurchases` (`/login/ManagePurchases`) | backend |
| TicketsVC | Movie image | ticket row image | `TicketDetailModel.moviePicture` (`movie_picture`) | `fetchTickets` + image fetch | `getManagePurchases` + image URL fetch | backend |
| TicketsVC | Venue | ticket row | `TicketDetailModel.venueName` (`venue_name`) | `fetchTickets` | `getManagePurchases` | backend |
| TicketsVC | Seat row/number | ticket row | `TicketDetailModel.seatRow`/`seatNumber` | `fetchTickets` | `getManagePurchases` | backend |
| TicketsVC | Screening date | ticket row | `TicketDetailModel.screeningDate` (`screening_date`) | `fetchTickets` | `getManagePurchases` | backend |
| TicketsVC | Ticket ID | ticket metadata | `TicketDetailModel.ticketId` | `fetchTickets` | `getManagePurchases` | backend |
| TicketsVC | QR image | QR view | generated from seat data | local generation | n/a | local generated |
| TicketsVC | Cancel ticket action | ticket row action | request keys `purchaseId`, `ticketsToBeCancelled` | `cancelTickets` | `postManagePurchases` (`/login/ManagePurchases`) | backend |
| TicketsVC | PDF preview state and share refresh message | panel/toast | n/a | existing PDF flow in VC | n/a | local UI state/mock |

## Task Gating Checklist
- [ ] Every implemented UI field maps to one row above.
- [ ] Every backend field uses existing DataManager + Service method only.
- [ ] Every local/mock field is explicitly marked as local UI state in task PR notes.
- [ ] No new endpoints/functions/payload keys introduced.

