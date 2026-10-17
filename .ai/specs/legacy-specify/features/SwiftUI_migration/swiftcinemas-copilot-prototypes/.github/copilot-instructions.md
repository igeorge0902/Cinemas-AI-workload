# SwiftCinemas Copilot instructions — screen events

- Use UIKit and programmatic Auto Layout; keep the app's iOS deployment target (iOS 15+) intact.
- Keep UI types `@MainActor`-isolated.
- Do not add SwiftUI, third-party dependencies, another WebSocket manager, or a new networking layer.
- Do not change the existing WebSocket receive/reconnect implementation unless explicitly required.
- Inspect the repository and reuse actual service, navigation, and model conventions. Do not invent method names.
- Keep transport and presentation separate: existing receiver emits/maps an event model; coordinator presents it.
- Never use a client-supplied loginId to determine preference ownership.
- Avoid force unwraps and `try!`; avoid retain cycles.
- Add accessibility labels and support Dynamic Type.

## Behavior
- Login summary appears only when server returns events; show Added/Updated/Deleted counts.
- Banner slides down below the top safe area; tap opens details; close dismisses.
- Acknowledgement/read semantics belong to the server contract, not the view.
- Live toast sits above the bottom safe area/tab bar, uses event-type accent colors, slides up, and dismisses after ~4 seconds.
- Toast tap calls an app-specific navigation callback; close dismisses.
- Replace the current toast or queue one at a time; do not stack unbounded toasts.
- Group detail list by Added, Updated, Deleted and handle empty results.
- Do not make network calls from UIView subclasses.
- Test counts, grouping, dismissal, and malformed/unknown messages where project test infrastructure allows.
