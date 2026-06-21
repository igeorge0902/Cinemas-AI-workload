---
description: Create a new reusable Claude skill in `.claude/skills/` from a natural-language request.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Create a production-ready skill scaffold under `.claude/skills/<skill-name>/` so it can be reused across tasks in this repository.

## Behavior

1. Parse `$ARGUMENTS` as:
   - skill purpose
   - optional preferred skill name
   - optional examples
2. If arguments are empty, stop and ask for:
   - what the skill should do
   - when it should be used
   - one example input/output
3. Derive a slugged skill name:
   - lowercase, kebab-case
   - preserve acronyms where meaningful
   - 2-5 words when possible

## Files To Create

Create these files:

- `.claude/skills/<slug>/SKILL.md`
- `.claude/skills/<slug>/examples.md`

If missing, create:

- `.claude/skills/README.md` (index of available skills)

If present, update:

- `.claude/skills/README.md` (append new skill entry only; do not rewrite existing entries)

## `SKILL.md` Required Structure

```markdown
# <Skill Name>

## Purpose
One paragraph describing what this skill solves.

## Use When
- Trigger condition 1
- Trigger condition 2

## Do Not Use When
- Out-of-scope condition 1

## Inputs
- Required input(s)
- Optional input(s)

## Outputs
- What the skill returns or changes

## Constraints
- Safety/quality boundaries
- Repository-specific conventions

## Workflow
1. Step-by-step method
2. Validation step
3. Completion criteria

## Validation Checklist
- [ ] Output is complete
- [ ] Output follows repo conventions
- [ ] No destructive actions without explicit approval
```
```

## `examples.md` Required Structure

```markdown
# Examples: <Skill Name>

## Example 1
### Input
...

### Output
...

## Example 2
### Input
...

### Output
...
```

## Quality Bar

- Keep language concise and actionable.
- Prefer repo-specific references when available (paths, scripts, conventions).
- Avoid implementation fluff; optimize for repeatable execution.
- Include at least one negative boundary in "Do Not Use When".

## Completion Output

Report:

- Skill name
- Created/updated file paths
- One-line summary of skill behavior
- Suggested next command to use the skill

