#!/usr/bin/env python3
"""Guard script: prevent reintroducing legacy AI folders outside .ai."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

POINTER_PREFIX = "Legacy path replaced."

# Legacy locations that must not be reintroduced as full trees.
LEGACY_DIRS = [
    ".specify",
    ".claude/skills",
    ".claude/commands",
    ".github/agents",
    ".github/skills",
    ".github/references",
]

# Legacy compatibility files allowed only as pointer stubs.
LEGACY_FILES = [
    ".github/instructions/instructions.md",
    ".github/endpoint-analysis-EXECUTIVE-SUMMARY.md",
    ".github/endpoint-dependency-map.md",
    ".github/endpoint-contract-analysis.md",
    ".github/ios-backend-gaps-quick-reference.md",
]


def is_pointer_file(path: Path) -> bool:
    if not path.is_file():
        return False
    try:
        head = path.read_text(encoding="utf-8").strip()
    except Exception:
        return False
    return head.startswith(POINTER_PREFIX)


def check_dir(path: Path) -> str | None:
    if not path.exists():
        return None
    if not path.is_dir():
        return f"{path}: expected directory or missing, found non-directory"

    entries = list(path.iterdir())
    if not entries:
        # Empty legacy dir is tolerated but should be removed eventually.
        return f"{path}: empty legacy directory exists (remove it)"

    # Only a pointer README is allowed in legacy directories.
    if len(entries) == 1 and entries[0].name == "README.md" and is_pointer_file(entries[0]):
        return None

    names = ", ".join(sorted(e.name for e in entries))
    return f"{path}: legacy directory reintroduced with content [{names}]"


def check_file(path: Path) -> str | None:
    if not path.exists():
        return None
    if is_pointer_file(path):
        return None
    return f"{path}: legacy file exists but is not a pointer stub"


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate AI assets live under .ai only.")
    parser.add_argument(
        "--root",
        default=".",
        help="Repository root path (default: current directory)",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    errors: list[str] = []
    warnings: list[str] = []

    for rel in LEGACY_DIRS:
        issue = check_dir(root / rel)
        if issue:
            # empty legacy dirs are warnings, real reintroductions are errors
            if "empty legacy directory" in issue:
                warnings.append(issue)
            else:
                errors.append(issue)

    for rel in LEGACY_FILES:
        issue = check_file(root / rel)
        if issue:
            errors.append(issue)

    if warnings:
        print("AI layout warnings:")
        for w in warnings:
            print(f"  - {w}")

    if errors:
        print("AI layout check FAILED:")
        for e in errors:
            print(f"  - {e}")
        print("\nFix: move AI content under .ai/* and keep legacy paths as pointer stubs only.")
        return 1

    print("AI layout check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

