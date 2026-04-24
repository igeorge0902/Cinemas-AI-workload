# Governance Docs

This folder defines lightweight AI/dev governance for feature delivery.

Files:
- `DEFINITION_OF_DONE_TEMPLATE.md` - required completion gates for every feature/task.
- `RELEASE_SMOKE_MATRIX.md` - release smoke lanes and pass criteria.
- `NAMING_RULES.md` - naming conventions for spec artifacts and new endpoints.

Related references:
- Canonical contracts index: `.github/references/CONTRACTS_INDEX.md`
- CI checks: `k8infra/ci/check_doc_drift.py`, `k8infra/ci/lint_governance_names.py`

## Local one-command check

```bash
cd /Users/gyorgy.gaspar/work/cinemas/cinemas
python3 k8infra/ci/check_governance.py
```

Advanced range (optional):

```bash
cd /Users/gyorgy.gaspar/work/cinemas/cinemas
python3 k8infra/ci/check_governance.py --base origin/main --head HEAD
```

