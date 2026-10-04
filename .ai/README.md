# .ai Workspace

This folder is the canonical home for AI-agent assets in this repository.

## Layout

- `constitution/` - project constitutional rules and immutable contracts
- `memory/` - project memory maps and compact references
- `skills/` - reusable domain skills (debug, deployment, flow guides)
- `workflows/` - feature-level specs, plans, and tasks
- `prompts/` - operator prompts and command templates
- `retrieval/` - searchable reference docs and dependency analyses
- `agents/` - agent role definitions and architecture guidance
- `specs/` - spec templates and baseline artifacts
- `generated/` - generated integration/config migration outputs

## Source Migration

Assets were synchronized from the existing locations:

- `.ai/specs/legacy-specify/*`
- `.ai/skills/*`
- `.ai/prompts/*`
- `.ai/agents/*`
- `.ai/retrieval/*`
- `.ai/generated/*`

## Canonical Usage

New AI-oriented content should be added under `.ai/*` first.
Compatibility copies may still exist in legacy locations during transition.

The `Cinemas Router` is the umbrella entry point for cross-domain work. Its
canonical definition and specialists live under `.ai/agents/definitions/`;
`.github/agents/` contains discovery symlinks only. Routing telemetry is disabled;
existing records and `.ai/agents/ROUTING-TELEMETRY.md` are preserved as reference.
No routing manifests or token/AI-credit handoff tables are generated while disabled.
