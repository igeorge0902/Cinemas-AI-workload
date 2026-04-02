# AI Agent Documentation Guide

This `.github` folder contains comprehensive guides for AI coding assistants working on the Cinemas project.

## Quick Navigation

### 🚀 Getting Started
- **New to the project?** Start with [`.github/docs/QUICKSTART.md`](docs/QUICKSTART.md) (5-10 min setup)
- **Need system overview?** Read [`.github/agents/AGENTS.md`](agents/AGENTS.md) (comprehensive architecture)

### 📋 Working on Features
- **Step-by-step instructions:** [`.github/instructions.md`](instructions/instructions.md)
- **Practical code patterns:** [`.github/skills.md`](skills/skills.md)
- **API reference & contracts:** [`.github/references/REFERENCE.md`](references/REFERENCE.md)

### 🐛 Debugging & Review
- **Troubleshooting:** See `instructions.md` → "Gotchas & Common Mistakes" or `references/REFERENCE.md` → "Debugging Checklist"
- **Code review checklist:** See `skills.md` → Section 16

---

## File Descriptions

| File | Lines | Purpose | Audience |
|------|-------|---------|----------|
| `instructions.md` | 187 | Primary workflow guide, critical file locations, common mistakes | All developers & AI agents |
| `skills.md` | 527 | 16 practical patterns, code examples, best practices, review checklist | Backend/frontend/test/infra developers |
| `docs/QUICKSTART.md` | 191 | 5-minute local setup, deploy steps, common tasks, troubleshooting | New developers, quick onboarding |
| `references/REFERENCE.md` | 470 | Complete API reference, database schemas, entity relationships, debugging | Reference documentation |
| `agents/AGENTS.md` | 457 | Comprehensive system architecture, entity relationships, refactoring roadmap | Architecture review, entity decisions |

---

## Reading Recommendations by Task

### "I want to add a new API endpoint"
1. Read: `instructions.md` → "When Working on Different Areas" → relevant section
2. Find pattern: `skills.md` → "1. Adding a REST Endpoint"
3. Reference: `references/REFERENCE.md` → "Backend Services Reference" → relevant service section
4. Implement, test, commit

### "I want to fix a payment bug"
1. Reference: `references/REFERENCE.md` → "Payment & Booking Flow"
2. Find pattern: `skills.md` → "4. Booking & Payment Flow"
3. Check: `instructions.md` → "Gotchas & Common Mistakes"
4. Fix, test, commit

### "I want to setup a local environment"
1. Follow: `docs/QUICKSTART.md` (entire guide)
2. Verify: Services accessible at URLs listed
3. Run: Sample tests to confirm

### "I want to review a PR"
1. Check: `skills.md` → "16. Code Review Checklist for PRs"
2. Verify: Key sections of `instructions.md` not violated
3. Review, comment, approve

### "I'm confused about entity relationships"
1. Read: `instructions.md` → "When Working on Different Areas" → "Database Queries & DAO"
2. Reference: `agents/AGENTS.md` → "Hibernate entity relationships"
3. Cross-check: `references/REFERENCE.md` → "Hibernate & Caching"

---

## Key Concepts at a Glance

### HMAC Authentication
Every request signed with `HMAC-SHA512(username, timestamp + password_hash)`. Headers must match exactly (iOS ↔ Web):
- `X-Token`, `X-HMAC-HASH`, `X-MICRO-TIME`, `X-Device`, `uuid`, `Ciphertext`, `XSRF-TOKEN`

See: `instructions.md` → "Hardcoded Values" or `skills.md` → "3. Session & Authentication Flow"

### Booking & Payment Flow
1. Get Braintree client token
2. User enters card → receives nonce
3. POST payment + seats to checkout
4. Server locks seats (pessimistic write), creates Purchase + Ticket, charges Braintree
5. If Braintree fails: rollback (free seats), return error
6. If success: return tickets + seat map

See: `references/REFERENCE.md` → "Payment & Booking Flow" or `skills.md` → "4. Booking & Payment Flow"

### L2 Cache (Infinispan)
Movies, Venues, Location, Ticket entities cached. Seats are **NOT cached** (always fresh from DB).

See: `instructions.md` → "Gotchas" → "L2 cache stale reads"

### WebSocket Broadcasting
iOS connects to `/mbook-1/ws` or `/mbooks-1/ws`. Server broadcasts via Kafka → WebSocket.

See: `skills.md` → "5. WebSocket Broadcasting"

---

## Hardcoded Contracts (DO NOT CHANGE without coordinating iOS client)

**Header names:**
```
X-Token, uuid, token2, Ciphertext, TIME_, XSRF-TOKEN, X-HMAC-HASH, X-Device
```

**Checkout payload:**
```
payment_method_nonce, orderId, seatsToBeReserved
(JSON: {"seatsToBeReserved":[{"screeningDateId":"X","seat":"A1-B2-"}]})
```

**iOS base URL:** `milo.crabdance.com` (configurable in `URLManager.swift`)

**Braintree SDK versions:** JS 1.44.1, iOS 5.26.0, Java 3.36.0

See: `instructions.md` → "Hardcoded Values (Client-Visible Contracts)" for full list

---

## Services at a Glance

| Service | Port | Root | DB | Primary Logic |
|---------|------|------|----|----|
| `dalogin-quarkus` | 8080 | `/login` | `login_` | Session, HMAC login, proxy servlets |
| `mbook-quarkus` | 8888 | `/mbook-1` | `login_` | User profile, devices, sessions |
| `mbooks-quarkus` | 8080 | `/mbooks-1` | `book` | Movies, booking, payment, Braintree |
| `simple-service-webapp` | 8085 | `/simple-service-webapp` | — | Image serving |

See: `references/REFERENCE.md` → "Backend Services Reference" for full details

---

## Common File Locations

| What | Where |
|------|-------|
| Login/auth logic | `dalogin-quarkus/src/main/java/com/dalogin/` |
| Booking/payment | `mbooks-quarkus/src/main/java/com/jeet/rest/BookController.java` |
| Database schemas | `mysql_8/login.sql`, `mysql_8/book.sql` |
| Web UI | `dalogin-quarkus/src/main/resources/META-INF/resources/film-review/app.js` |
| K8s manifest | `k8infra/quarkus-backend.yaml` |
| iOS client | `SwiftCinemas/` |
| iOS tests | `appium/src/test/java/` |
| System docs | `docs/system-documentation.html` |

See: `instructions.md` → "Critical Files & Directories" or `skills.md` → "Quick Lookups"

---

## Troubleshooting Quick Links

| Problem | Solution |
|---------|----------|
| `curl: (7) Failed to connect` | Run `sudo minikube tunnel` |
| iOS app crash on login | Check `URLManager.swift` baseHost, verify tunnel |
| Appium test timeout | Verify iOS simulator running, check `appium/README.md` |
| Payment fails on web but works on iOS | Check HMAC interceptor in `app.js`, Braintree SDK version |
| Database not seeded | Run `kubectl exec -n cinemas mysql-0 -- mysql -uroot -prootpw < mysql_8/*.sql` |
| WebSocket not connecting | Check `/mbook-1/ws` ProxyPass **before** `/mbook-1` in Apache config |

See: `docs/QUICKSTART.md` → "Troubleshooting" table or `references/REFERENCE.md` → "Debugging Checklist"

---

## How Copilot Agents Should Use This

### Best Practice: Read Docs Before Coding
```
1. Understand the feature/fix → Search relevant section in docs
2. Find code patterns → `skills.md` section X
3. Reference contracts → `references/REFERENCE.md`
4. Write code → Apply pattern
5. Test → Use provided test patterns
6. Commit → Reference the docs in PR description
```

### Anti-Pattern: Coding Without Reading Docs
❌ Don't hardcode secrets in code (use env vars)  
❌ Don't change header names (iOS depends on them)  
❌ Don't modify entity `FetchType.EAGER` without reading AGENTS.md  
❌ Don't forget L2 cache invalidation after mutations  
❌ Don't commit Braintree credentials or encryption keys  

---

## Contributing to These Docs

When adding new features or patterns:
1. **Bug fix?** Update `instructions.md` → "Gotchas" section if it's a recurring issue
2. **New pattern?** Add to `skills.md` with code example + "Files to check" section
3. **API change?** Update `references/REFERENCE.md` + `agents/AGENTS.md` if architectural
4. **Deploy procedure change?** Update `docs/QUICKSTART.md` + `k8infra/README-k8s-local.md`

---

## Version & Last Updated

- **Created:** April 1, 2026
- **Tech Stack:** Java 17, Quarkus 3.19.4, iOS 26.1, Appium 3.2.2
- **Last Verified:** April 1, 2026 (against AGENTS.md 457 lines)

---

**Questions?** Start with the relevant section above, then check the detailed docs. If still stuck, search AGENTS.md or ask the team.

