# Definition of Done Template

Use this checklist in every feature spec/tasks.

## Core Done Criteria

- [ ] Feature/task has a spec (`.specify/...*.specify`).
- [ ] Implementation is completed and aligned to spec.
- [ ] Implementation is tested and test evidence is attached.

## Required Role Gates

- [ ] `@testing-engineer`: unit/integration/smoke coverage defined and executed.
- [ ] `@security-specialist`: input validation, data exposure, and auth checks reviewed.
- [ ] `@performance-engineer`: performance impact reviewed and baseline checked.

## Contract and Docs Gates

- [ ] Contract IDs are listed and valid in `.github/references/CONTRACTS_INDEX.md`.
- [ ] Module README is updated (service-local docs).
- [ ] Feature tasks mention verification steps and outcomes.

