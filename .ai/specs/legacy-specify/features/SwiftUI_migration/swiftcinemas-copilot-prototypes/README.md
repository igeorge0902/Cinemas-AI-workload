# SwiftCinemas Copilot UI Prototypes

UIKit-first prototypes for:
- A top login-summary banner showing added, updated, and deleted screenings.
- A bottom live-event toast.
- A grouped Screen Events detail list.

These are UI prototypes, not claims about the exact current source layout. Keep the refactored WebSocket receiver and reconnect lifecycle intact. Map its existing DTO to `ScreenEvent` and call the presentation coordinator. No networking is performed by views.

## Files
- `Prototypes/ScreenEventModels.swift`
- `Prototypes/ScreenEventsSummaryBannerView.swift`
- `Prototypes/ScreenEventToastView.swift`
- `Prototypes/ScreenEventsViewController.swift`
- `Prototypes/ScreenEventPresentationCoordinator.swift`
- `.github/copilot-instructions.md`
- `Docs/COPILOT_IMPLEMENTATION_TASKS.md`

Design defaults: UIKit, programmatic Auto Layout, iOS 15+, main-actor UI, translucent rounded cards, green Added / blue Updated / red Deleted, banner below the top safe area, toast above the bottom safe area, toast auto-dismiss after four seconds.
