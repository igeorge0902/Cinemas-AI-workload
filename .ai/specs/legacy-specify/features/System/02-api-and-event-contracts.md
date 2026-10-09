# Screen News WebSocket — API and Event Contracts

**Status:** Proposed implementation contract  
**Date:** 2026-10-04

## 1. WebSocket contract

### Endpoint

```text
wss://milo.crabdance.com/mbook-1/ws?deviceId=<deviceId>
```

`deviceId` is the existing iOS value returned by:

```swift
currentDeviceId()
```

No new client identifier is generated.

### Connection rules

| Condition | Result |
|---|---|
| Missing deviceId | Not eligible for screen news |
| Empty deviceId | Not eligible |
| Exactly one active-session user | Continue |
| Same deviceId maps to multiple users | Not eligible |
| DeviceId not found | Not eligible |
| Active-session service unavailable | Not eligible |
| User blank | Not eligible |
| User cannot resolve to `logins.id` | Not eligible |

The WebSocket may remain open for other independently valid traffic if the implementation requires it; screen-news eligibility is separate.

## 2. Subscription REST API

Base path:

```text
/mbook-1/rest/news-settings/screen
```

### GET

```http
GET /mbook-1/rest/news-settings/screen
Cookie: <existing authenticated session>
```

Response:

```http
200 OK
Content-Type: application/json
```

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

Invalid database state:

```text
500 Internal Server Error
```

The server must not turn invalid data or a DB failure into `enabled:false`.

### PUT

```http
PUT /mbook-1/rest/news-settings/screen
Content-Type: application/json
Cookie: <existing authenticated session>
```

Request:

```json
{
  "enabled": true
}
```

Response:

```json
{
  "enabled": true
}
```

The response is returned only after the DB transaction commits.

### Identity rule

The request MUST NOT contain or rely on:

```text
user
username
loginId
uuid
deviceId
```

for ownership.

The authenticated server-side session determines the user.

## 3. Database semantics

Existing table:

```text
login_.news_settings
```

Relevant fields:

```text
id
logins_id
newsScreening
```

Canonical values:

```text
yes = subscribed
no  = unsubscribed
```

Missing row:

```text
not subscribed
```

Invalid values:

```text
error
```

The write must modify only:

```text
newsScreening
```

It must preserve:

- `id`;
- `logins_id`;
- future preference columns;
- unrelated values.

## 4. WebSocket screen-news event

JSON:

```json
{
  "category": "screening",
  "eventType": "created",
  "movie": {},
  "date": "2026-10-04T20:00:00",
  "venue": {},
  "screeningId": 123,
  "screeningDatesId": 456
}
```

### `category`

Required for new screen-news messages:

```text
screening
```

### `eventType`

Allowed:

```text
created
updated
deleted
```

Compatibility:

```text
null -> created
```

### Existing fields

Existing `AddMovie` field names must remain compatible.

Do not rename existing fields during this feature.

## 5. Event semantics

### Created

A new screening/screen is successfully created.

### Updated

An existing screen/screening is successfully changed.

### Deleted

An existing screen/screening is successfully removed.

Delete event data must be captured before deletion.

## 6. Delivery algorithm

```text
Kafka event
    |
    v
Get open WebSocket registrations
    |
    v
Fetch current active-session membership
    |
    v
For each registered deviceId:
    |
    +-- exactly one matching authenticated user?
    |       no -> skip
    |
    +-- resolve user -> logins.id
    |       fail -> skip
    |
    +-- newsScreening == exact "yes"?
            no -> skip
            yes -> send
```

Delivery is best effort.

No offline queue is introduced.

## 7. Error policy

Never send screen news when:

- active-session lookup fails;
- active-session response is malformed;
- device ID is blank;
- multiple users match;
- user is blank;
- user does not resolve to a valid account;
- subscription value is NULL;
- subscription value is unknown;
- subscription is not exact lowercase `yes`.

Do not log normal `newsScreening=no` as an error.

## 8. Backward compatibility

Old Kafka events:

```text
eventType absent/null
```

are interpreted as:

```text
created
```

iOS must ignore messages it does not recognize.

User notification messages and other WebSocket traffic are not changed by this contract.
