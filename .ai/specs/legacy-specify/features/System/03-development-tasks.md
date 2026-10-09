# Screen News WebSocket — Development Tasks

**Status:** Implementation backlog  
**Date:** 2026-10-04

## P0 — Confirm baseline

### T01 — Inspect current WebSocket implementation

Repositories:

```text
mbook-quarkus
mbooks-quarkus
SwiftCinemas
```

Verify:

- WebSocket endpoint classes;
- current session collection;
- current broadcast method;
- ping/reconnect behavior;
- all callers of the send/broadcast method.

**Done when:** exact current implementation is recorded before edits.

### T02 — Inspect current screen mutation flow

Repository:

```text
mbooks-quarkus
```

Verify:

- add screen transaction;
- update screen transaction;
- delete screen transaction;
- current Kafka publication;
- commit/rollback behavior.

**Done when:** publication can be placed after successful commit.

### T03 — Inspect current NewsSettings mapping

Repository:

```text
mbook-quarkus
```

Verify:

- entity;
- DAO;
- Hibernate configuration;
- existing query style.

**Done when:** implementation uses the existing persistence conventions.

---

## P1 — Database

### T04 — Create preflight SQL

Detect:

```sql
NULL logins_id
duplicate logins_id
NULL/unknown newsScreening
orphan owners
```

Do not expose data values in application logs.

### T05 — Create reviewed migration

Target:

```sql
logins_id INT NOT NULL
UNIQUE (logins_id)
```

Preserve existing:

```text
PK
FK
signed INT
InnoDB
existing columns
```

Do not include pending CHECK/DEFAULT changes.

### T06 — Migration review gate

Migration must not execute until:

- NULL/duplicate reconciliation is approved;
- live schema has been compared with the designated snapshot;
- deployment owner authorizes execution.

---

## P2 — Subscription API

### T07 — Implement subscription DAO/service

Methods:

```java
ScreenNewsPreference read(int loginId)
void set(int loginId, boolean enabled)
```

Result states must distinguish:

```text
YES
NO_OR_MISSING
INVALID
ERROR
```

### T08 — Implement GET endpoint

```text
GET /mbook-1/rest/news-settings/screen
```

Use authenticated session identity.

### T09 — Implement PUT endpoint

```text
PUT /mbook-1/rest/news-settings/screen
```

Input:

```json
{"enabled":true}
```

### T10 — Add API tests

Cover:

- signed-out;
- signed-in;
- subscribe;
- unsubscribe;
- repeated subscribe;
- repeated unsubscribe;
- missing row;
- invalid stored value;
- DB failure;
- cross-user access attempt.

---

## P3 — Device registration

### T11 — Add deviceId to iOS WebSocket URL

Use:

```swift
currentDeviceId()
```

on every connect/reconnect.

### T12 — Implement server registry

Recommended:

```java
ConcurrentHashMap<Session, ClientRegistration>
```

Registration contains:

```text
deviceId
loginId
```

### T13 — Implement active-session resolver

Call:

```text
GET /simple-service-webapp/webapi/myresource/admin
```

using a dedicated internal service credential.

Validate:

- HTTP status;
- response shape;
- nonblank deviceId;
- nonblank user;
- exactly one user;
- user -> `logins.id`.

### T14 — Add registry lifecycle handling

Remove registration on:

- close;
- WebSocket error;
- failed send;
- invalid replacement.

Reconnect must repeat identity resolution.

---

## P4 — Gate and events

### T15 — Implement ScreenNewsGate

Unit-testable pure decision logic.

Input:

```text
device registration
active-session snapshot
subscription state
```

Output:

```text
eligible / reason
```

### T16 — Extend event type

Add:

```text
created
updated
deleted
```

Keep old messages compatible.

### T17 — Publish update/delete events

`mbooks-quarkus`:

```text
update success -> updated
delete success -> deleted
```

Never publish on failure.

### T18 — Gate Kafka delivery

Replace broadcast with:

```java
screenNewsDispatcher.dispatch(event);
```

Send only to eligible sessions.

### T19 — Protect `/mbooks-1/ws`

Find screen-news forwarding.

Either:

1. remove screen-news from that endpoint; or
2. apply the identical gate.

Seat traffic must remain unchanged.

---

## P5 — iOS

### T20 — Decode screen-news JSON

Create:

```text
ScreenNewsEvent
```

Unknown messages ignored.

### T21 — Add MenuVC preference

Load:

```text
GET
```

Show loading state first.

### T22 — Save MenuVC preference

Write:

```text
PUT
```

Disable repeated taps while pending.

On failure:

```text
restore confirmed state
show error
```

### T23 — Add WebSocket event routing

Keep UIKit out of `WebSocketManager`.

Recommended:

```text
WebSocketManager
 -> event parser
 -> app event
 -> ToastNotificationManager
```

### T24 — Implement toast

States:

```text
created   -> New screening
updated   -> Screening updated
deleted   -> Screening removed
```

Display for approximately 4 seconds.

---

## P6 — Validation

### T25 — Backend compile

Run compile-only checks in each touched Maven module.

### T26 — iOS compile/typecheck

Run source parsing and whole-target typecheck without launching the app.

### T27 — Static contract review

Verify:

- endpoint paths;
- JSON names;
- event fields;
- device ID reuse;
- no client-supplied account identity;
- no unfiltered screen-news broadcast.

---

## P7 — Authorized runtime validation

### T28 — Preference scenarios

Test:

```text
missing row -> no delivery
no -> no delivery
yes -> delivery
unsubscribe -> same socket stays open
resubscribe -> next event delivered
```

### T29 — Identity scenarios

Test:

```text
valid device -> valid user -> delivery
unknown device -> no delivery
blank metadata -> no delivery
multiple matching users -> no delivery
user missing in DB -> no delivery
lookup outage -> no delivery
```

### T30 — Event scenarios

Test:

```text
created
updated
deleted
failed mutation -> no event
```

### T31 — Multi-device scenarios

Test:

```text
User A device 1 -> yes
User A device 2 -> yes
User B device 1 -> no
```

One event should reach both eligible devices of User A and not User B.

### T32 — Lifecycle scenarios

Test:

```text
disconnect
reconnect
logout
session expiry
same-device user switch
```

### T33 — Regression

Verify:

- user notifications;
- seat traffic;
- `/news/{user}`;
- existing WebSocket ping/reconnect.

---

## Task dependency graph

```text
T01 T02 T03
  \  |  /
   P0 baseline
      |
      +---- T04 -> T05 -> T06
      |
      +---- T07 -> T08 -> T09 -> T10
      |
      +---- T11 -> T12 -> T13 -> T14 -> T15
      |
      +---- T16 -> T17 -> T18 -> T19
      |
      +---- T20 -> T21 -> T22 -> T23 -> T24
                         |
                         v
                    T25 -> T26 -> T27
                                  |
                                  v
                         T28 -> T29 -> T30
                                  |
                                  v
                              T31 -> T32 -> T33
```
