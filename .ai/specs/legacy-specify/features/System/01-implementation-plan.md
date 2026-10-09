# Screen News WebSocket Subscriptions — Implementation Plan

**Status:** Proposed implementation baseline  
**Date:** 2026-10-04  
**Scope:** `mbooks-quarkus`, `mbook-quarkus`, `dalogin-quarkus`, `simple-service-webapp-quarkus`, `SwiftCinemas`

## 1. Goal

Deliver screen-news notifications over the existing `/mbook-1/ws` WebSocket so that:

1. The iOS client identifies itself with the existing `deviceId`.
2. The server resolves that device ID to exactly one currently authenticated user through the existing active-session lookup.
3. The user's `login_.news_settings.newsScreening` preference determines eligibility.
4. `created`, `updated`, and `deleted` screen events are delivered only to eligible connected clients.
5. The iOS Menu screen can enable/disable screen news.
6. Existing users notifications, seat traffic, and `/news/{user}` behavior remain unchanged.

The existing architecture already decides that device ID is the existing iOS `currentDeviceId()` value and that active-list membership is sufficient WebSocket identity under the accepted trust model. See the architecture and schema documents. 

## 2. Recommended decisions to unblock implementation

These are implementation recommendations, not claims about currently deployed APIs.

| Decision | Recommendation |
|---|---|
| WebSocket device ID transport | Query parameter: `/mbook-1/ws?deviceId=<UUID>` |
| WebSocket identity | `deviceId` -> fresh active-session lookup -> exactly one `user` -> `logins.id` |
| WebSocket caller session credential | Not required, per approved architecture |
| Internal active-session auth | Dedicated service credential/header, not browser Cookie forwarding |
| Active-session lookup | `mbook-quarkus` calls `simple-service-webapp` server-to-server |
| Lookup timeout | 1 second initially; make configurable |
| Preference read | `newsScreening` by resolved `logins.id` |
| Subscription API | `GET /mbook-1/rest/news-settings/screen` and `PUT /mbook-1/rest/news-settings/screen` |
| Subscription request | `{"enabled":true}` / `{"enabled":false}` |
| Subscription response | `{"enabled":true}` |
| WS event | JSON object containing existing AddMovie fields + `eventType` + `category` |
| `eventType` | `created`, `updated`, `deleted`; legacy/null interpreted as `created` |
| Delivery | Best-effort, fire-and-forget |
| Offline delivery | None |
| Persistence | Existing `login_.news_settings`; no new client table |
| DB hardening | `logins_id NOT NULL` + `UNIQUE(logins_id)` after reviewed reconciliation |
| `/mbooks-1/ws` | Do not alter seat traffic; suppress or gate screen-news forwarding before release |
| iOS UI | Toggle in `MenuVC`; server-confirmed state only |

## 3. Development order

### Phase 0 — Baseline and branch preparation

Create a feature branch, for example:

```text
feature/screen-news-websocket-subscriptions
```

Before editing:

- inspect the exact current versions of all target files;
- confirm current WebSocket endpoint and Kafka listener behavior;
- confirm current `AddMovie` serialization;
- confirm `VenueController` add/update/delete transaction behavior;
- confirm current `NewsSettings` DAO/entity;
- confirm `MenuVC` and networking conventions;
- do not modify the database yet.

### Phase 1 — Database hardening artifact

Deliver:

```text
k8infra/mysql_8/migrations/
  Vxxxx__screen_news_settings_owner_constraints.sql
  Vxxxx__screen_news_settings_owner_constraints_preflight.sql
```

The migration must:

1. Detect NULL `logins_id`.
2. Detect duplicate `logins_id`.
3. Detect invalid/unknown `newsScreening`.
4. Stop with an explicit error/report if reconciliation is required.
5. Add `logins_id NOT NULL`.
6. Add `UNIQUE(logins_id)`.
7. Preserve the existing FK and PK.
8. Not add the still-pending preference `CHECK`/`DEFAULT` unless separately approved.

Do not execute against production as part of implementation.

### Phase 2 — mbook subscription service

Implement a small service around `NewsSettings`.

Suggested classes:

```text
com.jeet.news.ScreenNewsSubscriptionService
com.jeet.news.ScreenNewsPreference
com.jeet.news.ScreenNewsPreferenceResult
```

Responsibilities:

- read preference by server-resolved `logins.id`;
- distinguish:
  - `yes`
  - `no`
  - missing row
  - invalid data
  - database error;
- write only `newsScreening`;
- preserve unrelated preference columns;
- use parent `logins` row locking for concurrent subscribe/unsubscribe;
- acknowledge success only after commit.

Do not expose arbitrary `logins.id` in the REST API.

### Phase 3 — mbook authenticated REST API

Recommended endpoints:

```text
GET /mbook-1/rest/news-settings/screen
PUT /mbook-1/rest/news-settings/screen
```

Authentication:

- use the same authenticated session mechanism already used by mbook;
- derive the current user from the server-side session;
- resolve the user to `logins.id`;
- ignore any `user`, `loginId`, or `deviceId` supplied by the client.

GET response:

```json
{
  "enabled": true
}
```

Missing row:

```json
{
  "enabled": false
}
```

Invalid DB state:

```text
500 / controlled application error
```

PUT request:

```json
{
  "enabled": true
}
```

or:

```json
{
  "enabled": false
}
```

PUT response:

```json
{
  "enabled": true
}
```

The response represents the committed state.

### Phase 4 — WebSocket registry and identity

Change `mbook-quarkus` WebSocket handling from a broadcast-only model to:

```text
Session -> deviceId -> resolved logins.id
```

Recommended registry:

```java
ConcurrentHashMap<Session, ClientRegistration>
```

where:

```java
record ClientRegistration(
    String deviceId,
    int loginId
) {}
```

Registration sequence:

```text
WS connect
  -> read deviceId
  -> reject empty deviceId
  -> fetch fresh active-session list
  -> find exact deviceId match
  -> require exactly one non-blank user
  -> resolve user -> logins.id
  -> register Session
```

On disconnect/error/send failure:

```text
remove Session registration
```

On reconnect:

```text
perform the lookup again
```

Do not persist the registry.

### Phase 5 — Screen-news gate

Create a unit-testable component:

```java
ScreenNewsGate
```

Inputs:

```text
ClientRegistration
ScreenNewsEvent
current active-session state
current newsScreening preference
```

Eligibility:

```text
deviceId present
AND exactly one valid active-session user
AND user resolves to logins.id
AND newsScreening == exact "yes"
```

Anything else:

```text
DO NOT SEND
```

Important:

- missing preference row = off;
- `"no"` = off;
- `"YES"` = invalid;
- `"yes "` = invalid;
- NULL = invalid;
- lookup failure = no delivery;
- conflicting users = no delivery;
- account resolution failure = no delivery.

A normal `no` preference should not create noisy warning logs. Validation/infrastructure failures should.

### Phase 6 — Event model and publication

Extend `AddMovie`:

```java
private String eventType;
```

Allowed values:

```text
created
updated
deleted
```

For compatibility:

```text
null -> created
```

Add:

```java
private String category = "screening";
```

WS payload example:

```json
{
  "category": "screening",
  "eventType": "updated",
  "movie": { },
  "date": "...",
  "venue": { },
  "screeningId": 123,
  "screeningDatesId": 456
}
```

### Phase 7 — mbooks publisher

Change screen mutation flow:

```text
VenueController
  -> DAO operation
  -> transaction succeeds
  -> publish event
```

For:

```text
ADD      -> created
UPDATE   -> updated
DELETE   -> deleted
```

For delete, capture all event data before deleting it.

Do not publish after a failed/rolled-back operation.

`DAO.updateScreen` currently needs an explicit failure signal if it can swallow commit/rollback failures. Fix that before enabling update events.

### Phase 8 — Kafka / WebSocket delivery

`KafkaMoviesListener` receives the event and calls:

```java
screenNewsDispatcher.dispatch(event);
```

Dispatcher:

```text
get registered sessions
for each session:
    refresh active-session membership
    resolve loginId
    read newsScreening
    if exact "yes":
        send JSON
    else:
        skip
```

Prefer one active-session list lookup per Kafka event rather than one lookup per socket. Then resolve each registered device against that snapshot.

Preference reads should be grouped by resolved `loginId` so multiple devices belonging to the same user do not cause duplicate DB reads.

### Phase 9 — `/mbooks-1/ws`

Search all current senders before changing this endpoint.

The requirement is:

```text
seat traffic = unchanged
screen news = must not bypass filtering
```

Recommended first implementation:

```text
stop screen-news broadcast on /mbooks-1/ws
```

unless that endpoint is required by the current iOS app for screen-news reception. If it is required, apply the same gate.

### Phase 10 — iOS

#### WebSocket

Change:

```text
wss://milo.crabdance.com/mbook-1/ws
```

to:

```text
wss://milo.crabdance.com/mbook-1/ws?deviceId=<currentDeviceId>
```

Reuse:

```swift
currentDeviceId()
```

on every connect/reconnect.

Do not generate a second identifier.

Empty device ID:

```text
do not register as eligible
```

#### Decoder

Decode:

```swift
struct ScreenNewsEvent: Decodable {
    let category: String?
    let eventType: String?
    let movie: Movie?
    let date: String?
    let venue: Venue?
    let screeningId: Int?
    let screeningDatesId: Int?
}
```

Unknown WebSocket messages must remain ignored so existing traffic is not broken.

#### MenuVC

Add:

```text
Screening news
    [ ON ]
```

Loading:

```text
disabled + loading state
```

Save:

```text
disabled while PUT is pending
```

Failure:

```text
restore last confirmed state
show error
```

Do not optimistically persist a new state locally.

### Phase 11 — Toast/dialog presentation

Do not make `WebSocketManager` depend on UIKit.

Recommended flow:

```text
WebSocketManager
      ↓
ScreenNewsEvent
      ↓
NotificationCenter / app event bus
      ↓
ToastNotificationManager
      ↓
current UIViewController
```

Toast:

- top-positioned;
- rounded;
- non-blocking;
- auto-dismiss ~4 seconds;
- title: `New screening` / `Screening updated` / `Screening removed`;
- movie/venue/time in body;
- tap may open movie details later.

### Phase 12 — Validation

Compile-only:

```text
mbook-quarkus       ./mvnw -DskipTests compile
mbooks-quarkus      ./mvnw -DskipTests compile
dalogin-quarkus     ./mvnw -DskipTests compile
simple-service...   ./mvnw -DskipTests compile
```

iOS:

- parse changed Swift files;
- typecheck the target without launching the app;
- verify new Swift files are in the Xcode target.

Runtime tests are a separate authorized phase.

## 4. Definition of Done

Backend:

- [ ] DB migration artifact reviewed.
- [ ] Subscription GET/PUT implemented.
- [ ] Server-side user identity used.
- [ ] Device ID registration implemented.
- [ ] Active-session lookup protected internally.
- [ ] Screen-news gate unit tested.
- [ ] Add/update/delete events generated only after success.
- [ ] Legacy created events remain compatible.
- [ ] WebSocket sends only to eligible clients.
- [ ] `/mbooks-1/ws` cannot bypass screen-news filtering.
- [ ] Existing user notifications remain unchanged.
- [ ] Existing seat traffic remains unchanged.

iOS:

- [ ] Device ID appended on connect/reconnect.
- [ ] JSON screen-news event decoder implemented.
- [ ] Unknown WS messages ignored.
- [ ] Menu toggle reads server state.
- [ ] Toggle writes server state.
- [ ] Failed writes revert to confirmed state.
- [ ] Toast appears for eligible screen-news events.
- [ ] Toast presentation is UIKit/UI-main-thread safe.

## 5. Explicitly out of scope

- Push notification/offline replay.
- New persistent device table.
- New subscription table.
- New event persistence mechanism.
- Changing the existing user-notification topic.
- Changing seat WebSocket semantics.
- Cryptographic proof of device ownership.
- Automatic migration cleanup without reviewed reconciliation.
