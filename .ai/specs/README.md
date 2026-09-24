# AI Specs and Layout Guards

This folder is the canonical home for specifications, feature workflows, templates, and
automation guards under `.ai/`.

Feature artifacts formerly stored under `.ai/workflows/features` now live under
`.ai/specs/legacy-specify/features`.

## Guard: legacy path reintroduction

Script: `check_ai_layout.py`

Purpose:
- fails when legacy AI content is reintroduced outside `.ai/*`
- allows compatibility pointer stubs in known legacy locations

Run from repo root:

```zsh
python3 .ai/specs/check_ai_layout.py --root .
```

Exit code:
- `0` = pass
- `1` = violations found
