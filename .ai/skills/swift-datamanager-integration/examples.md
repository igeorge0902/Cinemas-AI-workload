# Examples: Swift DataManager Integration

## Example 1: VC Fetch Refactor
### Input
A ViewController fetches `locations` and appends directly to a global array.

### Output
- Keeps HTTP call in `MbooksService`.
- Moves payload mapping into `LocationsDataManager`.
- Replaces global writes with manager-owned state updates.

## Example 2: Admin Screening Update Flow
### Input
Admin flow updates screening payloads while relying on scattered context globals.

### Output
- Centralizes screening fetch/search/update/delete through `AdminDataManager`.
- Keeps API mutation calls in `MbooksService`.
- Preserves existing endpoint contracts and payload key names.

## Example 3: Mixed UIKit + SwiftUI Consumption
### Input
The same movies list is needed by UIKit screen and SwiftUI migration screen.

### Output
- Both consumers read from `MoviesDataManager` state.
- Avoids duplicate fetch logic in each UI layer.
- Keeps a single source of truth for movie browse/search data.

