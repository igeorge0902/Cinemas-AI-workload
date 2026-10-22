---
name: swift-mvvm-migration-planner
description: Plan a repository-grounded, incremental MVVM migration for the SwiftCinemas UIKit app under Swift 6. Use when asked to assess, scope, sequence, or create a migration plan that separates ViewControllers from presentation state and data loading while preserving existing AppServices injection, DataManagers, API behavior, navigation, and tests. Planning only unless the user explicitly asks for implementation.
---

# SwiftCinemas MVVM Migration Planner

## Mission

Produce a repository-specific plan for migrating SwiftCinemas from ViewControllers that combine UI, state, and loading logic toward MVVM, one screen or migration slice at a time.

The goal is separation of responsibilities, not an architectural rewrite. Preserve UIKit, the current service/data-manager layer, dependency injection, API contracts, caching, navigation, and behavior unless the user explicitly approves a change.

Default to **planning and inspection only**. Do not edit application files or generate a broad implementation unless the user explicitly asks to implement.

## Mandatory first steps: inspect the real repository

1. Inspect the current workspace and identify the app target, Swift sources, tests, project/workspace, and any existing architecture documentation.
2. Read the actual files for the selected screen and its dependencies before proposing code or asserting how they work.
3. Trace the complete flow:
   - screen construction and dependency injection;
   - lifecycle methods and initial loading;
   - user actions and loading calls;
   - success, empty, loading, and error paths;
   - shared/global state and caches;
   - navigation, segues, selected-item handoff, and notifications;
   - other callers of the data managers and shared state;
   - tests, mocks, and app configuration.
4. Use exact type, method, property, and file names from the current source. Mark unverified details as questions, not facts. Do not rely on an old conversation summary when the repository source is available.
5. Before planning a migration that moves or removes state, search for all references to that state and identify compatibility risks.

If the repository is unavailable, say which files or source access are missing. Ask for the minimum needed material rather than inventing APIs.

## Existing architecture constraints

The repository's architecture documentation describes:

- `AppServices` as the dependency container for `APIClient`, `MbooksService`, `LoginGatewayService`, `ImageResourceService`, and `RapidMovieDatabaseService`.
- `HasAppServices` as the protocol used to expose the container.
- `AppDelegate.bootstrapDataManagers()` as the startup injection point for shared data managers.
- `injectAppServicesIfNeeded()` as a lazy fallback used by view controllers.
- Shared data managers as the existing state/data-access layer; they should not be replaced by new repositories solely to introduce MVVM.

## Architectural target

Prefer this responsibility split:

### ViewController / UIKit view
- Own UIKit controls, layout, table/collection data-source and delegate integration where appropriate.
- Translate UI events into ViewModel inputs.
- Render ViewModel state.
- Keep UIKit navigation, segue preparation, view lifecycle, and presentation-specific behavior unless a separately reviewed design says otherwise.
- Do not directly orchestrate new API loading flows once those flows have been migrated.

### ViewModel
- Own screen-specific presentation state and UI-facing loading orchestration.
- Expose clear state such as loading, content, empty state, and error where appropriate to the screen.
- Handle screen-level actions such as reload, search, filter/category selection, and pagination.
- Coordinate existing data managers/services; do not duplicate networking, JSON decoding, caching, URL construction, or authentication.
- Be testable without instantiating UIKit views where practical.
- Keep state transitions deterministic and documented.

### Existing DataManagers and services
- Remain the source of existing data-loading/API behavior.
- Preserve their public APIs in the initial migration unless a concrete incompatibility requires a separate, justified change.
- Continue owning responsibilities already assigned to them, such as API calls, decoding, persistence/cache operations, and shared cross-screen data where applicable.
- Do not add a repository protocol or another abstraction layer without a demonstrated need.

### Dependency injection
- Follow the project's actual `AppServices`, `HasAppServices`, and data-manager bootstrap patterns.
- Prefer explicit initializer injection for the new ViewModel where it fits existing construction.
- If a singleton must remain for compatibility, isolate that default at the composition boundary (for example, a default factory/initializer) while allowing a test double or alternate instance to be supplied.
- Do not let the ViewModel independently fetch global services from `UIApplication.shared` if the current app's composition/injection mechanism can supply its dependencies.
- Do not perform a broad dependency-injection migration as a side effect of one screen's MVVM migration.

## Swift 6 and concurrency rules

1. Inspect actor annotations and isolation of every dependency and call site.
2. Respect existing `@MainActor` types, including UIKit and main-actor data managers.
3. Keep UI-facing ViewModel state on `MainActor` unless repository evidence supports a different isolation model.
4. Follow the actual async/await, callback of the existing API. Do not wrap callback APIs in tasks or change async APIs merely for stylistic consistency.
5. Avoid `@unchecked Sendable`, `nonisolated(unsafe)`, detached tasks, and global mutable state as shortcuts to silence compiler diagnostics.
6. When an async load can be repeated, plan for stale results, cancellation, duplicate requests, and loading-state consistency where relevant.
7. Identify whether data manager methods mutate shared state. Do not assume a call is side-effect-free because it returns a value.
8. Distinguish compile-time actor isolation problems from runtime/UI behavior changes.

## Migration strategy

The user prefers a single, coherent migration edit batch rather than a sequence of independently implemented screen-by-screen changes. Plan the migration as one coordinated app-wide edit, with a clear scope, explicit compatibility boundaries, and one final review/check pass.

This means **one implementation batch**, not an uncontrolled rewrite. Before editing, perform repository-wide inspection and produce an implementation map. Then make the approved set of related changes together, review the complete diff against the original working-tree baseline, and run only the verification checks that are available and appropriate. Do not split the approved migration into a long series of user approval checkpoints unless an unresolved decision materially affects behavior or scope.

### Before the batch

1. Inventory all relevant ViewControllers, data managers, service dependencies, shared/global state, navigation paths, notifications, storyboard usage, and existing tests.
2. Build a migration matrix for every in-scope screen:
    - current loading/data flow;
    - current state and who else consumes it;
    - proposed ViewModel responsibility;
    - existing dependencies to inject;
    - behavior/API/navigation contracts that must remain unchanged;
    - files expected to change.
3. Identify cross-screen dependencies and choose the smallest complete set of changes that forms a coherent app-wide migration. Do not claim the inventory is complete unless repository-wide searches were actually performed.
4. Record the baseline working-tree state, including pre-existing dirty changes. Never overwrite, revert, or misattribute the user's existing edits.
5. Define the batch's acceptance criteria and verification commands before making edits.
6. Ask for clarification only when a real ambiguity could change behavior, public contracts, migration scope, or user-visible UI. Otherwise choose the least disruptive behavior-preserving option and document it.

### During the batch

1. Implement the agreed ViewModel boundaries and update the related ViewControllers in the same batch.
2. Keep UIKit rendering, lifecycle, and navigation in ViewControllers unless moving a specific responsibility is necessary and explicitly included in the plan.
3. Keep API paths, request/query construction, response decoding, cache behavior, authentication, error semantics, and existing data-manager contracts unchanged.
4. Preserve `AppServices`, `HasAppServices`, the current dependency-injection composition points, and existing data managers. Do not introduce a parallel repository/service layer solely for MVVM.
5. Preserve global/shared state and cross-screen behavior until all consumers are migrated in the same batch. Remove or replace shared state only when the migration map accounts for every usage.
6. Preserve admin/special flows, selected-item handoff, notifications, segues, and storyboard integration.
7. Follow existing Swift 6 concurrency and actor-isolation boundaries. Do not use `@unchecked Sendable`, `nonisolated(unsafe)`, detached tasks, or unrelated concurrency rewrites as shortcuts.
8. Do not add or edit tests, package/dependency files, CI configuration, project build settings, or unrelated files unless the user explicitly includes them in the batch or a new source file requires a minimal, justified project-file registration.
9. If new Swift files must be added to a classic Xcode project, update only the necessary project/group/source-build-phase references. Verify each new reference resolves to the exact on-disk path and appears once in the intended target. Do not change target membership, build settings, or dependencies unrelated to the migration.
10. Do not claim compilation, type-checking, tests, or app-wide inventory succeeded unless those actions were actually performed.

### After the batch

1. Review the complete application diff against the retained pre-edit working-tree baseline, not just against `HEAD`.
2. Confirm that only the approved files and behaviors changed. Check for accidental formatting churn, unrelated refactors, API contract changes, and changes to pre-existing dirty content.
3. Run `git diff --check` on the scoped changed files.
4. Run available syntax checks with the correct SDK, target triple, and Swift language version. Clearly label syntax parsing as syntax-only; it is not type checking or a build.
5. Type-check only when the complete module dependencies and correct SDK/target can be supplied. Clearly identify the exact files/module checked and do not imply the whole app was type-checked if only isolated files were checked.
6. Inspect Xcode project-file changes, if any, by parsing the project and asserting that new file references, groups, and Sources build-phase entries resolve correctly and are present exactly once.
7. Run app-wide build/test actions only when the environment supports them and the user has authorized or requested them. If a target-wide MCP action is unavailable, do not invoke it merely to claim a check was attempted.
8. Report results in separate categories:
    - **Implementation:** one coherent batch and the behavior/contracts preserved.
    - **Actual final checks:** exact commands/actions and exit results.
    - **Limitations:** syntax-only checks, untested targets, missing simulator/toolchain, or any checks not run.
    - **Diff scope:** exact files changed and whether pre-existing dirty changes were retained.
9. If a check fails, determine whether the failure was caused by the batch before changing source. Do not make unrelated edits to silence environment/toolchain errors.

### Acceptance criteria for a coherent batch

- The planned ViewModel migration is applied consistently to the agreed scope in one coordinated edit.
- Existing dependency injection, data managers, API behavior, caching, navigation, and special flows are preserved.
- All migrated screen state and shared-state consumers are accounted for.
- Swift 6 actor isolation and asynchronous behavior are handled deliberately.
- No unrelated tests, dependency files, CI files, or project settings are changed without approval.
- The complete diff is reviewed against the original working-tree baseline.
- Verification claims precisely distinguish source assertions, syntax parsing, isolated type checking, full build, and tests.
- Any remaining unmigrated code or limitations are listed explicitly; the plan does not claim a whole-app migration if some screens or flows remain out of scope.


## Planning output format

Return a concrete plan with these sections:

1. **Repository facts** — selected files/types/methods inspected, with source evidence (file paths and line references when available).
2. **Current flow** — concise sequence from screen event to data manager/service and back to UI.
3. **Responsibility map** — what stays in the ViewController, what moves to the ViewModel, and what remains in DataManagers/services.
4. **Proposed ViewModel contract** — proposed state, actions, and injected dependencies using existing real types. Label proposed names as proposals.
5. **Migration tools** — one pass, when before editing files should be saved into .txt files for quicker validation of changes.
6. **Test plan** — only user owned manual testing.
7. **Risks and unresolved questions** — only questions that source inspection cannot resolve.
8. **Out of scope** — explicitly list architecture and behavior that will not change.

Provide small implementation example code with the plan, or small signatures and state sketches, that are labeled as best fit.

## Acceptance criteria

A plan is ready when:

- It is based on the current source, not inferred or invented APIs.
- Existing dependency injection and service/data-manager boundaries are preserved.
- API paths, query parameters, decoding, cache behavior, and error mapping remain unchanged.
- UIKit navigation, segues, selected-item handoff, notifications, and special/admin flows are accounted for.
- Swift 6 actor isolation and async behavior are explicitly considered.
- Shared/global state is mapped to all consumers before migration or removal.
- No unrelated screens or services are rewritten without an explicit reason.
