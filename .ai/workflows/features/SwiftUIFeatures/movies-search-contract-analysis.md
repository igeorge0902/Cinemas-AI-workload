# Movies Search Contract Analysis

Date: 2026-05-10
Status: Analysis only
Scope: iOS MoviesVC search request vs `mbooks` backend search endpoint

## Conclusion

The iOS request path you showed is **aligned correctly** with the backend search endpoint:

- iOS request: `/mbooks-1/rest/book/movies/search?setFirstResult=0&match=bloo`
- Backend endpoint: `@Path("/book/movies/search")`
- Full base URL is correct through `URLManager.mbooks(...)`

Query parameter order does **not** matter here; the backend reads them by name.

---

## Backend contract

### Backend file
- `mbooks-quarkus/src/main/java/com/jeet/rest/BookController.java:540-579`

### Required/accepted parameters
- `match` (required in practice; backend immediately calls `match.length()`)
- `setFirstResult` (parsed as `Integer.parseInt(setFirstResult)`)
- `category` (optional; defaults to empty string when null)

### Backend behavior
- If `match.length() < 3`, backend throws an error.
- If results exist, backend returns JSON with `searchedMovies` array.
- If no results exist, backend returns:
  - `{"NotFoundMovies":"No such movie(s)"}`

---

## iOS contract

### iOS request path
- `SwiftCinemas/SwiftLoginScreen/Networking/BackendServices.swift:98-104`
  - `moviesSearch(query:)` → `GET mbooks-1/rest/book/movies/search`

### iOS response parsing
- `SwiftCinemas/SwiftLoginScreen/DataManagers/MoviesDataManager.swift:65-81`
  - Searches for `searchedMovies` first, then `movies`
  - If neither array exists, it throws `AppError.decodingFailed`

---

## Most likely reason the request "fails"

If the backend returns **no matches** for `bloo`, the backend response shape is **not an array**. The iOS client currently treats that as a decoding failure, so from the app it looks like the request failed even though the HTTP request itself succeeded.

In other words:
- **Endpoint alignment:** correct
- **Failure mode:** response-shape mismatch for empty results

---

## Secondary client-side note

`MoviesVC.searchBar(_:textDidChange:)` clears `SearchData` before dispatching the query, which means paging state for search always starts from 0 on the next request. That is not the primary failure here, but it does make the search flow more brittle than necessary.

---

## Safe fix direction

1. Keep the endpoint path as-is.
2. Update iOS search decoding to handle `NotFoundMovies` as an empty result set rather than a decoding failure.
3. Optionally surface a user-friendly empty-state message.
4. Keep `match` length >= 3.

---

## Bottom line

Your request path is correct:

```text
/mbooks-1/rest/book/movies/search?setFirstResult=0&match=bloo
```

The more likely issue is that the backend is returning a non-array empty-result payload and the iOS parser is rejecting it.

