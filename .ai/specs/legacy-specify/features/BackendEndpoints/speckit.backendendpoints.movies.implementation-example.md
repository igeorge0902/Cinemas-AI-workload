# Controller/Service Implementation Model (reference slice: Movie)

**This file is the single implementation model for all four controller/service slices** in
`speckit.backendendpoints.bookcontroller-response-records-all` — Movie, Venue, Purchase, and
Checkout. It is not movie-only documentation; Movie is used purely as the worked example because
it is the first slice being built. Every family follows the identical shape:

```
<Family>Controller  --(@BeanParam params)-->  <Family>Service  -->  <Family>Mapper  -->  records
        |                                                                                   |
        +-------------------------- ApiResponseFactory (shared, one instance) <-------------+
        |
        +-- guard clause: throw new CustomExceptions(...) on invalid input (no ternary, no try/catch)
```

| Generic component     | Movie (this file)     | Venue                | Purchase                | Checkout                |
|------------------------|------------------------|-----------------------|--------------------------|---------------------------|
| `<Family>Controller`   | `MovieController`      | `VenueController`     | `PurchaseController`    | `CheckoutController`    |
| `<Family>Service`      | `MovieService`         | `VenueService`        | `PurchaseService`\*     | `CheckoutService`       |
| `<Family>Mapper`       | `MovieMapper`          | `VenueMapper`         | `PurchaseMapper`        | `CheckoutMapper`        |
| `@BeanParam` classes   | `TrendingMoviesParams`, `MoviePagingParams` | e.g. screen/screening admin params | e.g. ticket/purchase params | e.g. `FullCheckoutParams` |
| Response records       | `MovieSummaryItem`, `TrendingMovieItem`, wrappers | venue/screen response records | purchase/ticket response records | checkout response records |

\* `PurchaseService` naming/ownership vs. the existing `com.jeet.booking.PurchaseService` is an
open decision tracked in the parent `.tasks` file (Phase 3) — resolve it before implementing the
Purchase slice; do not assume this table settles it.

**When implementing Venue, Purchase, or Checkout: copy the structure of every section below
(Target State, Response Shape Rules, Suggested Records/Service Responsibilities, example
controller/service/mapper code, `@BeanParam` params class, validation/error flow, migration
phases, verification checklist, rollback plan), substituting that family's own endpoints, records,
and params classes. Do not skip the guard-clause validation or `ApiResponseFactory` usage for
other families just because this file's worked examples are movie-specific.**

## Goal (movie reference slice)
Refactor the movie-related endpoint family out of `BookController` into a dedicated `MovieController` backed by `MovieService`, while preserving the exact public JSON contract and removing movie DTO/domain-shaping responsibilities from `BookingHandlerImpl`.

## Scope (movie reference slice)
- Module: `mbooks-quarkus`
- Controller slice: movie-related endpoints only
- Target endpoints:
  - `GET /rest/book/movies`
  - `GET /rest/book/movies/paging`
  - `GET /rest/book/movies/{name}/{order}`
  - `GET /rest/book/movies/search`
  - `GET /rest/book/trending-movies`
  - `GET /rest/book/venue/movies`
- Supporting classes:
  - `MovieController`
  - `MovieService`
  - `MovieMapper`
  - `MovieSummaryItem` / response wrapper records in `com.jeet.api`
  - `TrendingMoviesParams` (`@BeanParam`, for `days`/`limit`)
  - `MoviePagingParams` (`@BeanParam`, for `getAllMoviesWithPaging`)
  - `ApiResponseFactory` (shared across all four families, not movie-specific — see Phase 0 of
    the parent plan)

## Target State (movie reference slice)
1. `MovieController` handles only HTTP concerns:
   - request parameter binding via `@BeanParam` (for multi-input endpoints) or plain
     `@QueryParam`/`@PathParam` (for single-input endpoints)
   - validation via guard-clause checks that `throw new CustomExceptions(...)` (no ternary,
     no local try/catch — `CustomExceptions` extends `WebApplicationException` and JAX-RS
     unwraps its embedded `Response` automatically)
   - response building via the shared `ApiResponseFactory`, not ad-hoc
     `Response.status(...).entity(...).build()` chains
   - delegating to `MovieService`
2. `MovieService` owns movie-family orchestration and DTO shaping.
3. `MovieMapper` converts internal movie/domain rows into API response records.
4. `BookingHandlerImpl` no longer serves movie endpoint calls once this slice is complete.
5. JSON output remains byte-for-byte compatible for existing consumers.

## Response Shape Rules (movie reference slice)
- Preserve root keys exactly as they exist today:
  - `movies`
  - `searchedMovies`
  - `trendingMovies`
- Preserve item keys exactly as today, including snake_case fields:
  - `movieId`
  - `name`
  - `detail`
  - `large_picture`
  - `thumbnail_picture`
  - `iMDB_url`
  - `bookedTickets`
  - `lastBookingTime`
- Keep error payloads unchanged.

## `ApiResponseFactory` (shared across all four families)

This bean lives once in `com.jeet.rest`, is injected by every controller in every family, and is
the only place `Response` objects are constructed for success/validation paths.

```java
package com.jeet.rest;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@ApplicationScoped
public class ApiResponseFactory {

  public Response ok(Object body) {
    return ok(body, Response.Status.OK);
  }

  public Response ok(Object body, Response.Status status) {
    return Response.status(status).entity(body).type(MediaType.APPLICATION_JSON).build();
  }

  public Response error(Response.Status status, Object errorBody) {
    return Response.status(status).entity(errorBody).type(MediaType.APPLICATION_JSON).build();
  }
}
```

Usage:
- Success, default `200`: `responses.ok(movieService.getAllMovies());`
- Success with an explicit status (e.g. `201` on a create endpoint in another family):
  `responses.ok(created, Response.Status.CREATED);`
- Error with an explicit status (e.g. Venue family's `409 CONFLICT` on `addScreen`):
  `responses.error(Response.Status.CONFLICT, conflictBody);` — used for cases that are not a
  `CustomExceptions`-driven `400`/guard-clause throw (those still just `throw`, see below); the
  `error(...)` builder is for call sites that build an error response directly instead of
  throwing.

## Suggested Records (movie reference slice)
- `MovieSummaryItem`
  - movie list/search payload shape
- `TrendingMovieItem`
  - trending-movies item shape
- `MovieListResponse`
  - wrapper for `movies` or `searchedMovies`
- `TrendingMoviesResponse`
  - wrapper for `trendingMovies`

## Suggested Service Responsibilities (movie reference slice)
### `MovieService`
- Fetch movie lists from the lower layer
- Apply endpoint-specific filtering and pagination rules
- Delegate to `MovieMapper` for record assembly
- Return response records or equivalent service result objects

### `MovieMapper`
- Map `Movie` entities into `MovieSummaryItem`
- Map `TrendingMovieRow` into `TrendingMovieItem`
- Assemble response wrapper records

### Example Mapper

```java
package com.jeet.rest;

import com.jeet.api.Movie;
import com.jeet.rest.responserecord.MovieListResponse;
import com.jeet.rest.responserecord.MovieSummaryItem;
import com.jeet.rest.responserecord.TrendingMovieItem;
import com.jeet.api.TrendingMovieRow;
import com.jeet.rest.responserecord.TrendingMoviesResponse;
import jakarta.enterprise.context.ApplicationScoped;

import java.util.List;

@ApplicationScoped
public class MovieMapper {

  public MovieListResponse toMovieListResponse(List<Movie> movies) {
    return new MovieListResponse(movies.stream().map(this::toMovieSummaryItem).toList());
  }

  public TrendingMoviesResponse toTrendingMoviesResponse(List<TrendingMovieRow> rows) {
    return new TrendingMoviesResponse(rows.stream().map(this::toTrendingMovieItem).toList());
  }

  private MovieSummaryItem toMovieSummaryItem(Movie movie) {
    return new MovieSummaryItem(
        movie.getMovieId(),
        movie.getName(),
        movie.getDetail(),
        movie.getLarge_picture(),
        movie.getThumbnail_picture(),
        movie.getiMDB_url()
    );
  }

  private TrendingMovieItem toTrendingMovieItem(TrendingMovieRow row) {
    return new TrendingMovieItem(
        row.getMovieId(),
        row.getName(),
        row.getThumbnail_picture(),
        row.getLarge_picture(),
        row.getBookedTickets(),
        row.getLastBookingTime()
    );
  }
}
```

### Example Controller/Service Flow

```java
package com.jeet.rest;

import jakarta.inject.Inject;
import jakarta.ws.rs.BeanParam;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@Path("/rest")
public class MovieController {

  @Inject MovieService movieService;
  @Inject ApiResponseFactory responses;

  @GET
  @Path("/book/movies")
  @Produces(MediaType.APPLICATION_JSON)
  public Response getAllMovies() {
    return responses.ok(movieService.getAllMovies());
  }

  @GET
  @Path("/book/trending-movies")
  @Produces(MediaType.APPLICATION_JSON)
  public Response getTrendingMovies(@BeanParam TrendingMoviesParams params) {
    return responses.ok(movieService.getTrendingMovies(params.days, params.limit));
  }
}
```

```java
package com.jeet.rest;

import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.QueryParam;

public class TrendingMoviesParams {

    @QueryParam("days")
    @DefaultValue("30")
    public int days;

    @QueryParam("limit")
    @DefaultValue("10")
    public int limit;
}
```

```java
package com.jeet.rest;

import com.jeet.rest.responserecord.MovieListResponse;
import com.jeet.rest.responserecord.TrendingMovieItem;
import com.jeet.rest.responserecord.TrendingMoviesResponse;
import com.jeet.db.DAO;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class MovieService {

  @Inject DAO dao;
  @Inject MovieMapper movieMapper;

  public MovieListResponse getAllMovies() throws InterruptedException {
    return movieMapper.toMovieListResponse(dao.getAllMovies(-1, ""));
  }

  public TrendingMoviesResponse getTrendingMovies(int days, int limit) throws InterruptedException {
    return movieMapper.toTrendingMoviesResponse(dao.getTrendingMovies(days, limit));
  }

  public MovieListResponse searchMovies(String name, String order) throws InterruptedException {
    return movieMapper.toMovieListResponse(dao.searchMovies(name, order));
  }

  public MovieListResponse getMoviesForVenue(int locationId) throws InterruptedException {
    return movieMapper.toMovieListResponse(dao.getMoviesForVenue(locationId));
  }

  public MovieListResponse fullTextSearchMovies(String match, String category, int setFirstResult) throws InterruptedException {
    return movieMapper.toMovieListResponse(
        dao.fullTextSearchMovies(match, category, setFirstResult)
    );
  }
}
```

### Example Endpoint Usage

```java
@GET
@Path("/book/movies/{name}/{order}")
@Produces(MediaType.APPLICATION_JSON)
public Response searchMovies(@PathParam("name") String name, @PathParam("order") String order) throws InterruptedException {
  return responses.ok(movieService.searchMovies(name, order));
}

@GET
@Path("/book/venue/movies")
@Produces(MediaType.APPLICATION_JSON)
public Response getMoviesForVenue(@QueryParam("locationId") int locationId) throws InterruptedException {
  return responses.ok(movieService.getMoviesForVenue(locationId));
}
```

```java
@GET
@Path("/book/movies/search")
@Produces(MediaType.APPLICATION_JSON)
public Response fullTextSearchMovies(@BeanParam MoviePagingParams params) throws InterruptedException {
  return responses.ok(
      movieService.fullTextSearchMovies(params.match, params.category, params.setFirstResult)
  );
}
```

```java
package com.jeet.rest;

import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.QueryParam;

public class MoviePagingParams {

    @QueryParam("match")
    public String match;

    @QueryParam("category")
    public String category;

    @QueryParam("setFirstResult")
    @DefaultValue("0")
    public int setFirstResult;
}
```

### Example Validation/Error Flow (guard clause, no ternary)

Validation uses a plain guard clause that throws `CustomExceptions` directly. `CustomExceptions`
extends `WebApplicationException` and already carries its own `400` `Response` in its
constructor, so JAX-RS unwraps and returns it automatically — no `instanceof` checks, no
try/catch, no ternary-selected fallback object.

```java
package com.jeet.rest;

public final class MovieErrorMessages {

  private MovieErrorMessages() {}

  public static final String SEARCH_QUERY_TOO_SHORT = "Search query has to be at least 3 characters long.";
  public static final String WRONG_SORTING_ARGUMENT = "Wrong sorting argument";
  public static final String SEARCH_QUERY_EMPTY = "Search query cannot be empty.";
  public static final String ERROR_PREFIX = "Error!";
}
```

```java
package com.jeet.rest;

import com.jeet.utils.CustomExceptions;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@GET
@Path("/book/movies/{name}/{order}")
@Produces(MediaType.APPLICATION_JSON)
public Response searchMovies(@PathParam("name") String name, @PathParam("order") String order)
    throws InterruptedException {
  String normalizedName = name == null ? "" : name.trim();
  String normalizedOrder = order == null ? "asc" : order.trim();

  if (normalizedName.length() < 3) {
    throw new CustomExceptions(MovieErrorMessages.ERROR_PREFIX, MovieErrorMessages.SEARCH_QUERY_TOO_SHORT);
  }
  if (!"asc".equalsIgnoreCase(normalizedOrder) && !"desc".equalsIgnoreCase(normalizedOrder)) {
    throw new CustomExceptions(MovieErrorMessages.ERROR_PREFIX, MovieErrorMessages.WRONG_SORTING_ARGUMENT);
  }

  return responses.ok(movieService.searchMovies(normalizedName, normalizedOrder));
}
```

```java
package com.jeet.rest;

import com.jeet.utils.CustomExceptions;

public class MovieService {

  // ...existing code...

  public MovieListResponse searchMovies(String name, String order) throws InterruptedException {
    if (name == null || name.trim().isEmpty()) {
      throw new CustomExceptions(MovieErrorMessages.ERROR_PREFIX, MovieErrorMessages.SEARCH_QUERY_EMPTY);
    }

    return movieMapper.toMovieListResponse(dao.searchMovies(name, order));
  }
}
```

Note: ternary is still fine for simple value-defaulting (e.g.
`name == null ? "" : name.trim()`), just not for validation branching or exception dispatch —
`throw` is a statement in Java and cannot appear inside a ternary expression.


## Migration Phases (movie reference slice)

### Phase 0 - Baseline capture
- Capture sample responses for each movie endpoint.
- Record expected status codes for:
  - empty movie list
  - invalid sort parameter
  - invalid search input
  - trending endpoint invalid query params
- Identify any current differences in root keys between list/search endpoints.

### Phase 1 - Introduce records and mapper
- Add top-level response records in `com.jeet.api`.
- Add `MovieMapper` as an injectable application-scoped bean.
- Add `TrendingMoviesParams`/`MoviePagingParams` `@BeanParam` classes for the multi-input
  endpoints.
- Keep controller behavior unchanged until mapper outputs are verified.
- Add `CustomExceptions`-based guard-clause validation for invalid search/sort/query parameter
  cases (throw directly, no ternary/`instanceof`, no local try/catch — see Example
  Validation/Error Flow above).

### Phase 2 - Add `MovieService`
- Move movie endpoint orchestration from `BookController` into `MovieService`.
- Keep `BookController` thin if it still exists during the transition.
- Replace direct `BookingHandlerImpl` usage for movie methods with service calls.

### Phase 3 - Create `MovieController`
- Move movie routes into `MovieController`.
- Keep URI paths and response contracts unchanged.
- Bind multi-input routes via `@BeanParam`; leave single-input routes on plain
  `@QueryParam`/`@PathParam`.
- Route all responses through the shared `ApiResponseFactory` instead of ad-hoc
  `Response.status(...).entity(...).build()` calls.
- Preserve validation and error handling (guard-clause `throw`, not ternary).

### Phase 4 - Remove movie responsibilities from `BookingHandlerImpl`
- Delete or redirect the movie-facing methods from `BookingHandlerImpl`.
- Ensure the controller routes only depend on `MovieService`.

### Phase 5 - Verify and stabilize
- Compare before/after JSON for:
  - non-empty movie list
  - paged movie list
  - movie search by name/order
  - full-text search
  - trending movies
  - venue movie listing
- Confirm no contract regression in field names or nesting.

## Verification Checklist (movie reference slice)
- [ ] `MovieController` exists and owns the movie routes.
- [ ] `MovieService` exists and is injected by the controller.
- [ ] `MovieMapper` exists and produces record-based response models.
- [ ] Multi-input routes use `@BeanParam` classes; single-input routes keep plain
      `@QueryParam`/`@PathParam`.
- [ ] `MovieController` builds all responses via the shared `ApiResponseFactory`.
- [ ] Validation errors are thrown as `CustomExceptions` via guard clauses — no ternary or
      `instanceof`-based dispatch, no local try/catch.
- [ ] `BookController` no longer contains movie-family success-path JSON assembly.
- [ ] `BookingHandlerImpl` no longer handles movie-family DTO shaping.
- [ ] Movie endpoint JSON matches the current contract.
- [ ] Module compiles and relevant tests pass.

## Rollback Plan (movie reference slice)
- If any movie endpoint regresses, revert the movie slice only:
  - restore `BookController` route handlers
  - keep the new records and mapper behind a feature branch if needed
  - re-run captured-response comparisons before reattempting the split

## Notes
- This file is an implementation example plan, not the authoritative spec.
- It is the single shared implementation model for all four controller/service slices in
  `speckit.backendendpoints.bookcontroller-response-records-all` (Movie, Venue, Purchase,
  Checkout). The "Generic component" table near the top of this file maps every section here
  (structure, `@BeanParam` pattern, `ApiResponseFactory` usage, guard-clause validation,
  migration phases, verification checklist, rollback plan) onto the other three families —
  Movie is only the worked example, not a scope boundary.
- Keep purchase/payment orchestration work (`CheckoutService`) out of this specific movie slice —
  it follows the same shape but is implemented in its own phase.

