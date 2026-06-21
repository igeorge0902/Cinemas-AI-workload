# Swift DataManager Integration

## Purpose
Standardize API response to DataManager integration in iOS flows by using centralized services and DataManagers instead of global mutable state.

## Use When
- Migrating VC-level networking/parsing into DataManagers.
- Replacing globals with manager-owned state.
- Aligning UIKit/SwiftUI screens to shared service/data flow.

## Do Not Use When
- You are changing backend contracts/endpoints.
- The task is pure UI styling with no data-flow impact.

## Inputs
- Required: `SwiftCinemas/SwiftLoginScreen/Networking/BackendServices.swift`.
- Required: DataManagers in `SwiftCinemas/SwiftLoginScreen/DataManagers/`.
- Reference: `/.ai/workflows/features/SwiftUI_migration/skills.datamanager-api-integration.swift`.

## Outputs
- DataManager-based fetch/parse/update flow with async/await.
- Removed or reduced global-state writes in touched flows.
- Stable UI update behavior using manager state.

## Constraints
- Keep networking in service classes (`MbooksService`, `LoginGatewayService`, etc.).
- Keep parse/mapping in DataManagers.
- Keep writes on main actor when updating UI-bound state.
- Preserve existing payload keys and endpoint paths.

## Workflow
1. Identify current global-state read/write points in target flow.
2. Move API request to existing service method if missing.
3. Parse payload and map model data in DataManager.
4. Update manager-owned state in one coherent assignment path.
5. Update VC usage to read from DataManager state.
6. Validate errors and recovery behavior remain explicit.

## Validation Checklist
- [ ] No new VC-local network duplication was introduced.
- [ ] No new global mutable arrays were introduced.
- [ ] Data parsing lives in DataManager layer.
- [ ] Service endpoints are called through `AppServices`.
- [ ] Touched flow behavior remains contract-compatible.

