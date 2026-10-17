# UI design and migration boundaries

This is shared design guidance, not an approved feature specification or redesign backlog.
Feature-specific requirements belong in the applicable spec. See the
[constitution](../../constitution/constitution.md) and [architecture](../../agents/AGENTS.md).

## Current baseline

- iOS remains a UIKit/storyboard app with `AppDelegate` and injected `AppServices`.
  The venues flow embeds SwiftUI and returns to storyboard venue details; checkout uses
  Braintree SwiftUI `CardFields`.
- The web booking UI remains the AngularJS Film-Review SPA with plain `#/...` routes.
- Screen-news subscriptions are server-backed. iOS logs received screen events; notification
  UI, automatic seat refresh and timeline feeds are not implied by event delivery.
- Browse ratings currently use `ratings-mock.json`; they are not verified live ratings.
  Movie detail enrichment parses RapidAPI title and genre.

## Preserve during presentation changes

- Storyboard/segue identifiers, selected movie/venue/location/screening/seat context and
  injected service handoffs across UIKit/SwiftUI boundaries.
- Async loading, actor isolation, existing error surfaces, explicit payment Cancel/Pay
  actions and duplicate-submit guards.
- Authentication/cookie bridging, gateway routes, response casing and form payloads.
- Last server-confirmed subscription state while saving; failed saves must not appear confirmed.

Visual changes do not authorize new API fields, changed navigation, payment behavior or
event-driven UI. Make those requirements explicit and coordinate backend/web/iOS consumers.
Use `swiftcinemas` view/constraint/storyboard analysis and actual UI checks for the affected
screen; static inspection alone does not verify the user experience.

## Evidence

Paths under `SwiftCinemas/SwiftLoginScreen/`: `AppDelegate.swift`,
`Networking/BackendServices.swift`, `VenuesMigration/VenuesMigration.swift`,
`BasketVC.swift`, `MenuVC.swift`, `MoviesVC.swift`, `MovieDetailVC.swift`,
`BroadCasting/Websocket.swift`.
Web source: `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/`.