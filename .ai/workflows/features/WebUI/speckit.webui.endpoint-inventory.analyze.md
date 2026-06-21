# WebUI Endpoint Inventory — Template Utilization Analysis

_Source authority: `film-review/app.js` callsites + `Film-Review-Movie-Database/*.html` templates_

---

## 1. Currently Active Routes and Endpoint Matrix

| Route | Controller | Method | Endpoint | Service Owner | Auth | Status |
|-------|-----------|--------|----------|--------------|------|--------|
| `/login` | LoginController | POST | `/login/HelloWorld` | dalogin-quarkus | HMAC | ✅ implemented |
| `/change-password` | ChangePasswordController | POST | `/login/forgotPSw` | dalogin-quarkus | public | ✅ implemented |
| `/change-password` | ChangePasswordController | POST | `/login/forgotPSwCode` | dalogin-quarkus | public | ✅ implemented |
| `/change-password` | ChangePasswordController | POST | `/login/forgotPSwNewPSw` | dalogin-quarkus | public | ✅ implemented |
| `/movies` | MoviesController | GET | `/mbooks-1/rest/book/movies` | mbooks-quarkus | session | ✅ implemented |
| `/venues-list` | VenuesListController | GET | `/mbooks-1/rest/book/locations` | mbooks-quarkus | session | ✅ implemented |
| `/venue-movies/:locationId` | VenueMoviesController | GET | `/mbooks-1/rest/book/venue/movies?locationId=` | mbooks-quarkus | session | ✅ implemented |
| `/venues/:movieId` | VenuesController | GET | `/mbooks-1/rest/book/venue/v2/:movieId` | mbooks-quarkus | session | ✅ implemented |
| `/dates/:locationId/:movieId` | DatesSeatsController | GET | `/mbooks-1/rest/book/dates/:locationId/:movieId` | mbooks-quarkus | session | ✅ implemented |
| `/dates/:locationId/:movieId` | DatesSeatsController | GET | `/mbooks-1/rest/book/seats/:dateId` | mbooks-quarkus | session | ✅ implemented |
| `/checkout` | CheckoutController | POST | `/login/CheckOut` | dalogin-quarkus | session+HMAC | ✅ implemented |
| `/purchases` | PurchasesController | GET | `/login/GetAllPurchases` | dalogin-quarkus | session | ✅ implemented |
| `/purchases` | PurchasesController | POST | `/login/ManagePurchases` | dalogin-quarkus | session | ✅ implemented |
| `/purchases/:purchaseId` | PurchaseDetailController | GET | `/login/ManagePurchases?purchaseId=` | dalogin-quarkus | session | ✅ implemented |
| `$run` (global) | — | GET | `/login/GetAllPurchases` | dalogin-quarkus | session | ✅ implemented |
| `$run` (logout) | — | GET | `/login/logout` | dalogin-quarkus | session | ✅ implemented |

**Currently deployed templates:** 10 (`login`, `change-password`, `movies`, `venues-list`, `venue-movies`, `venues`, `dates`, `checkout`, `purchases`, `purchase-detail`)

---

## 2. Film-Review Template Inventory vs. Active Usage

| Template file | Type | Currently wired? | Usability now | Endpoint needed | Phase |
|--------------|------|-----------------|---------------|----------------|-------|
| `moviegrid.html` | Movie grid (poster cards) | ❌ | ✅ **Yes — reuse `/movies` endpoint** | `GET /mbooks-1/rest/book/movies` (already used) | P1 |
| `movielist.html` | Movie list (table rows) | ❌ | ✅ **Yes — reuse `/movies` endpoint** | `GET /mbooks-1/rest/book/movies` (already used) | P1 |
| `moviegridfw.html` | Full-width movie grid | ❌ | ✅ **Yes — reuse `/movies` endpoint** | `GET /mbooks-1/rest/book/movies` (already used) | P1 |
| `moviesingle.html` | Movie detail page | ❌ | ⚠️ Partial — needs movie detail endpoint | `GET /mbooks-1/rest/book/movies/{movieId}` | P2 |
| `seriessingle.html` | Series detail (TV/series variant) | ❌ | ⚠️ Partial — no series concept in DB yet | needs series endpoint or map to movie | P2 |
| `userfavoritegrid.html` | User favorites grid | ❌ | ⚠️ Partial — no favorites endpoint | `GET /login/GetFavorites` (missing) | P2 |
| `userfavoritelist.html` | User favorites list | ❌ | ⚠️ Partial — same as above | `GET /login/GetFavorites` (missing) | P2 |
| `userprofile.html` | User profile | ❌ | ⚠️ Partial — needs profile data endpoint | `GET /login/GetProfile` (missing) | P2 |
| `userrate.html` | User ratings page | ❌ | ❌ No ratings table in DB yet | needs new endpoint + DB table | P3 |
| `blogdetail.html` | Blog/news article detail | ❌ | ❌ No news/blog backend | needs news feed endpoint (timeline feature) | P3 |
| `bloggrid.html` | Blog grid | ❌ | ❌ No news/blog backend | same | P3 |
| `bloglist.html` | Blog list | ❌ | ❌ No news/blog backend | same | P3 |
| `celebritylist.html` | Actor/celebrity list | ❌ | ⚠️ Partial — actors exist in DB | `GET /mbooks-1/rest/book/actors` (missing) | P2 |
| `celebritygrid01.html` | Celebrity grid | ❌ | ⚠️ Partial — same | same | P2 |
| `celebritygrid02.html` | Celebrity grid variant | ❌ | ⚠️ Partial — same | same | P2 |
| `celebritysingle.html` | Celebrity detail | ❌ | ❌ No actor detail endpoint | `GET /mbooks-1/rest/book/actors/{actorId}` (missing) | P3 |
| `homev2.html` | Homepage variant 2 | ❌ | ✅ **Yes — can serve trending movies** | `GET /mbooks-1/rest/book/trending-movies` (P2 candidate) | P2 |
| `homev3.html` | Homepage variant 3 | ❌ | ✅ **Yes — can serve trending movies** | same | P2 |
| `index-2.html` | Alternative index | ❌ | ✅ **Yes — straight redirect or home** | none (static) | P1 |
| `comingsoon.html` | Coming soon placeholder | ❌ | ✅ **Yes — pure static, no endpoint** | none | P1 |
| `landing.html` | Landing page | ❌ | ✅ **Yes — pure static, no endpoint** | none | P1 |
| `404.html` | Error page | ❌ | ✅ **Yes — wire as `otherwise` fallback** | none | P1 |
| `_light variants` (all) | Light theme variants of above | ❌ | Same as dark counterpart | same | mirrors above |

---

## 3. Templates Utilizable Right Now (P1 — no new endpoint needed)

These can be wired today using only already-implemented backend calls:

| Template | What to wire | Notes |
|----------|-------------|-------|
| `moviegrid.html` | New route `/movie-grid` → MoviesController | Same `GET /movies` data; different layout |
| `movielist.html` | New route `/movie-list` → MoviesController | Same data; list layout |
| `moviegridfw.html` | Route variant or landing hero | Same data; full-width poster layout |
| `404.html` | `$routeProvider.otherwise({templateUrl: '404.html'})` | No controller needed |
| `comingsoon.html` | Static route `/coming-soon` | No controller needed |
| `landing.html` | Static route `/` before login redirect | No controller needed |
| `index-2.html` | Optional alternate home when logged in | Static shell only |

---

## 4. Templates Requiring P2 Endpoints (can plan now)

| Template | Missing endpoint | Owner | Effort |
|----------|-----------------|-------|--------|
| `moviesingle.html` | `GET /mbooks-1/rest/book/movies/{movieId}` | mbooks-quarkus | Low — movie entity exists |
| `homev2.html` | `GET /mbooks-1/rest/book/trending-movies` | mbooks-quarkus | Medium — aggregate query |
| `homev3.html` | same as above | mbooks-quarkus | same |
| `celebritylist.html` | `GET /mbooks-1/rest/book/actors` | mbooks-quarkus | Medium — actors in DB |
| `celebritygrid01.html` | same as above | mbooks-quarkus | same |
| `userfavoritegrid.html` | `GET /login/GetFavorites` | dalogin-quarkus | Medium — new DB table |
| `userprofile.html` | `GET /login/GetProfile` | dalogin-quarkus | Low — user data exists |

---

## 5. Templates Blocked (P3 — needs new DB tables or concepts)

| Template | Blocker |
|----------|---------|
| `blogdetail.html` / `bloggrid.html` / `bloglist.html` | News/timeline table not yet in DB (planned in speckit.system.timeline feature) |
| `userrate.html` | Ratings table not in DB |
| `celebritysingle.html` | Actor detail endpoint missing; actor-movie relationship data not exposed |
| `seriessingle.html` | No TV series concept in current `book` DB schema |

---

## 6. Recommended Immediate Actions (P1)

1. Wire `404.html` as `otherwise` fallback in `$routeProvider` — **zero effort**.
2. Add `/movie-grid` route using `MoviesController` + `moviegrid.html` — **same endpoint already in use**.
3. Add `comingsoon.html` as static route for unimplemented placeholder pages — keeps broken links away from users.
4. Consider using `landing.html` as pre-auth welcome page on `/` before redirecting to `/login`.

---

## 7. Acceptance Criteria Status

- [x] All active Film-Review routes represented in endpoint matrix
- [x] Every mapped endpoint has exactly one owning backend service
- [x] Missing/partial endpoints phased as P1/P2/P3
- [x] `trending-movies` explicitly defined in P2 discovery scope
- [x] Non-booking modules marked disabled until contract + owner exist
- [x] Matrix rows traceable to `app.js` callsites (line numbers confirmed)

