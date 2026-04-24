# Naming Rules

## Spec Artifact Naming

Convention:
- `speckit.<module>.<feature-or-task>.<type>`

Examples:
- `speckit.backendendpoints.timeline-feed.specify`
- `speckit.webui.endpoint-inventory.tasks`

Rules:
- lowercase only
- kebab-case in `<feature-or-task>` segments
- `<type>` must be one of: `plan`, `specify`, `tasks`

## Endpoint Naming (new endpoints)

Rules for newly added endpoint paths:
- lowercase kebab-case path segments
- avoid camelCase or mixed case in new path segments
- path params must use `{paramName}` and be stable

Examples:
- good: `/rest/book/timeline-feed`
- good: `/rest/book/trending-movies`
- avoid new mixed-case endpoints

