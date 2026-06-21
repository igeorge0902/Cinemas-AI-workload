# AI Workflow Guards

This folder contains automation guards for keeping AI assets centralized under `.ai/`.

## Guard: legacy path reintroduction

Script: `check_ai_layout.py`

Purpose:
- fails when legacy AI content is reintroduced outside `.ai/*`
- allows compatibility pointer stubs in known legacy locations

Run from repo root:

```zsh
python3 .ai/workflows/check_ai_layout.py --root .
```

Exit code:
- `0` = pass
- `1` = violations found

