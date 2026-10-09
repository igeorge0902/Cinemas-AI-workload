# Screen News WebSocket — Database Migration Runbook

**Status:** Review artifact — NOT an execution script  
**Date:** 2026-10-04

## 1. Purpose

Prepare the existing:

```text
login_.news_settings
```

table for the approved ownership model:

```text
logins_id NOT NULL
UNIQUE(logins_id)
```

The current schema allows NULL and duplicate owners. The migration must not silently choose, merge, delete, or backfill data.

## 2. Preflight

Run against a disposable/authorized inspection environment first.

### NULL owners

```sql
SELECT COUNT(*)
FROM login_.news_settings
WHERE logins_id IS NULL;
```

### Duplicate owners

```sql
SELECT logins_id, COUNT(*) AS row_count
FROM login_.news_settings
WHERE logins_id IS NOT NULL
GROUP BY logins_id
HAVING COUNT(*) > 1;
```

Do not expose the actual IDs in logs or reports unless specifically authorized.

### Invalid preference values

The canonical values are:

```text
yes
no
```

Inspect counts for:

```text
NULL
empty
uppercase
trailing/leading whitespace
other text
```

Do not trim or normalize them automatically.

### Orphaned owners

```sql
SELECT COUNT(*)
FROM login_.news_settings ns
LEFT JOIN login_.logins l
  ON l.id = ns.logins_id
WHERE ns.logins_id IS NOT NULL
  AND l.id IS NULL;
```

## 3. Reconciliation rule

Migration is blocked if any of the following remain:

```text
NULL logins_id
duplicate logins_id
orphaned logins_id
ambiguous/invalid preference requiring an owner decision
```

Do not:

- delete a duplicate row automatically;
- choose the newest row automatically;
- merge unrelated future preferences automatically;
- turn NULL into `no` without an approved data decision;
- turn unknown values into `no`;
- blanket-create settings rows for all users.

## 4. Live-schema verification

Before DDL, compare:

```sql
SELECT VERSION();

SHOW CREATE TABLE login_.logins;

SHOW CREATE TABLE login_.news_settings;

SHOW INDEX FROM login_.news_settings;

SHOW TRIGGERS LIKE 'news_settings';
```

Also verify:

- signedness of `logins.id`;
- signedness of `news_settings.logins_id`;
- FK action;
- engine;
- charset/collation;
- grants;
- unexpected triggers.

The designated snapshot is evidence, not proof of current production state.

## 5. Approved target DDL

After reconciliation and explicit deployment authorization:

```sql
ALTER TABLE login_.news_settings
  MODIFY COLUMN logins_id INT NOT NULL,
  ADD UNIQUE KEY uq_news_settings_logins (logins_id);
```

This is the approved owner-constraint target.

It does **not** authorize:

```text
newsScreening NOT NULL
newsScreening DEFAULT 'no'
CHECK(newsScreening IN ('yes','no'))
```

Those remain separate decisions.

## 6. Post-migration verification

```sql
SHOW CREATE TABLE login_.news_settings;

SHOW INDEX FROM login_.news_settings;
```

Verify:

```text
logins_id = NOT NULL
uq_news_settings_logins exists
existing FK remains
existing PK remains
existing preference columns remain
```

Then test synthetic data in an isolated environment:

```text
one user + no
one user + yes
missing row
concurrent yes/no
duplicate attempt rejected
NULL owner rejected
```

## 7. Rollback

Do not assume the ALTER can be safely wrapped in:

```sql
START TRANSACTION;
...
ROLLBACK;
```

MySQL DDL can implicitly commit.

Rollback must therefore be a separately reviewed DDL operation, not an application transaction rollback.

Before production execution, prepare an explicit rollback procedure based on the actual live schema and migration tooling.

## 8. Important lifecycle issue

The existing FK behavior can block account deletion when a settings row exists.

Therefore:

```text
unsubscribe = retain row
```

but account deletion requires a separate approved lifecycle policy.

Do not introduce `ON DELETE CASCADE` as part of this feature.
