# Copilot implementation tasks

Run one task at a time. Ask Copilot to inspect the actual repository before editing.

## 1. Inspect current architecture

> Inspect SwiftCinemas and the refactored WebSocket receive path. Identify exact files and methods for the event DTO, login success, root/tab/navigation controller, and movie/screening navigation. Do not modify code yet. Explain where presentation can be called without changing the WebSocket lifecycle.

Acceptance: exact paths and method names from the repository; current receiver/reconnect behavior preserved; current event payload and summary API contract documented.

## 2. Adapt event model

> Integrate `Prototypes/ScreenEventModels.swift` with the existing payload. Map the current DTO to `ScreenEvent` rather than changing the wire format solely for the view. Handle unknown types and optional fields safely.

Acceptance: valid messages still decode; malformed/unknown messages do not crash; event types map correctly.

## 3. Preview UI

> Add a temporary demo screen using sample data to preview `ScreenEventsSummaryBannerView` and `ScreenEventToastView`. Match the supplied design, render all three event types, and verify tap/close callbacks, narrow layouts, and Dynamic Type. Do not connect networking yet.

## 4. Wire login summary

> Find the actual login-success callback and existing API-client conventions. Call `showSummary` only after a successful response containing events. If no events exist, show nothing. Do not mark events acknowledged unless the server contract explicitly supports it.

## 5. Wire live events

> Connect the existing WebSocket callback to `showLiveEvent` after decoding a supported screen event. Do not add a WebSocket manager or alter reconnect behavior. Ensure UI work is on the main actor and unrelated message types do not trigger toasts.

## 6. Integrate navigation

> Replace the coordinator TODO using existing movie/screening navigation. Inspect actual identifiers and methods first. If a deleted screening no longer exists, handle it gracefully rather than navigating to a missing record.

## 7. Build and test

> Build and test using the actual Xcode project/workspace, scheme, and simulator destination found in the repository. Fix only issues introduced by this feature. Report exact commands and results.

Manual matrix: login with zero, added-only, updated-only, deleted-only, and mixed events; dismiss/tap banner; select a detail row; receive live events on different tabs; repeated events; WebSocket reconnect; unrelated messages; larger Dynamic Type.
