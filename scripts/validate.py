# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml>=6"]
# ///
"""Validate every skill against the Agent Skills spec and this repo's rules.

The reference validator (agentskills/skills-ref) is marked demonstration-only and is
not published to PyPI, so CI runs this instead. Run with `uv run scripts/validate.py`.
Exit status is 1 when any error is found; warnings do not fail the run.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
SKILLS = ROOT / "skills"
MARKETPLACE = ROOT / ".claude-plugin" / "marketplace.json"

# https://agentskills.io/specification
NAME = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
NAME_MAX = 64
DESCRIPTION_MAX = 1024
COMPATIBILITY_MAX = 500
BODY_LINES_MAX = 500
RESERVED = ("anthropic", "claude")
XML = re.compile(r"<[^>]+>")
PERSON = re.compile(r"\b(I can|I will|you can|You can)\b")
EVALS = ROOT / "evals"
EVALS_MIN = 3
REFERENCE_TOC_LINES = 100
KNOWN_FIELDS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
LINK = re.compile(r"\]\((?!https?://|mailto:|#)([^)\s]+)\)")

errors: list[str] = []
warnings: list[str] = []


def frontmatter(path: Path) -> tuple[dict, str]:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise ValueError("missing YAML frontmatter")
    head, sep, body = text[4:].partition("\n---\n")
    if not sep:
        raise ValueError("unterminated YAML frontmatter")
    data = yaml.safe_load(head)
    if not isinstance(data, dict):
        raise ValueError("frontmatter is not a mapping")
    return data, body


def check_skill(skill: Path) -> None:
    rel = skill.relative_to(ROOT)
    manifest = skill / "SKILL.md"
    if not manifest.is_file():
        errors.append(f"{rel}: missing SKILL.md")
        return
    try:
        meta, body = frontmatter(manifest)
    except (ValueError, yaml.YAMLError) as e:
        errors.append(f"{rel}/SKILL.md: {e}")
        return

    name = meta.get("name")
    if not isinstance(name, str) or not NAME.match(name) or len(name) > NAME_MAX:
        errors.append(f"{rel}: name {name!r} must be 1-{NAME_MAX} lowercase letters, digits and single hyphens")
    elif name != skill.name:
        errors.append(f"{rel}: name {name!r} must match the directory name")

    if isinstance(name, str) and any(w in name for w in RESERVED):
        errors.append(f"{rel}: name must not contain a reserved word ({', '.join(RESERVED)})")

    desc = meta.get("description")
    if not isinstance(desc, str) or not desc.strip():
        errors.append(f"{rel}: description is required")
    elif len(desc) > DESCRIPTION_MAX:
        errors.append(f"{rel}: description is {len(desc)} characters (max {DESCRIPTION_MAX})")
    elif "use when" not in desc.lower():
        warnings.append(f"{rel}: description should say when to use the skill ('Use when ...')")

    if isinstance(desc, str) and (XML.search(desc) or (isinstance(name, str) and XML.search(name))):
        errors.append(f"{rel}: name and description must not contain XML tags")
    if isinstance(desc, str) and PERSON.search(desc):
        warnings.append(f"{rel}: description should not use first or second person")

    compat = meta.get("compatibility")
    if compat is not None and (not isinstance(compat, str) or not 1 <= len(compat) <= COMPATIBILITY_MAX):
        errors.append(f"{rel}: compatibility must be 1-{COMPATIBILITY_MAX} characters")

    extra = meta.get("metadata")
    if extra is not None and (
        not isinstance(extra, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in extra.items())
    ):
        errors.append(f"{rel}: metadata must map strings to strings (quote numbers, e.g. version: \"1.0\")")

    tools = meta.get("allowed-tools")
    if tools is not None and not isinstance(tools, str):
        errors.append(f"{rel}: allowed-tools must be a space-separated string")

    unknown = set(meta) - KNOWN_FIELDS
    if unknown:
        warnings.append(f"{rel}: fields outside the spec: {', '.join(sorted(unknown))}")

    if body.count("\n") > BODY_LINES_MAX:
        warnings.append(f"{rel}: SKILL.md body exceeds {BODY_LINES_MAX} lines; move detail into references/")

    for md in skill.rglob("*.md"):
        for target in LINK.findall(md.read_text(encoding="utf-8")):
            path = target.split("#", 1)[0]
            if path and not (md.parent / path).exists():
                errors.append(f"{md.relative_to(ROOT)}: broken link {target}")


    skill_text = manifest.read_text(encoding="utf-8")
    for ref in sorted((skill / "references").glob("*.md")) if (skill / "references").is_dir() else []:
        if f"references/{ref.name}" not in skill_text:
            errors.append(f"{ref.relative_to(ROOT)}: not linked from SKILL.md")
        text = ref.read_text(encoding="utf-8")
        if text.count("\n") > REFERENCE_TOC_LINES and not re.search(r"^#+\s*(contents|目錄)", text, re.I | re.M):
            warnings.append(f"{ref.relative_to(ROOT)}: over {REFERENCE_TOC_LINES} lines without a Contents section")

    cases_file = EVALS / f"{skill.name}.json"
    try:
        cases = json.loads(cases_file.read_text(encoding="utf-8")).get("cases", [])
    except (OSError, ValueError):
        errors.append(f"evals/{skill.name}.json: missing or invalid")
        return
    good = [c for c in cases if c.get("query") and c.get("expected_behavior")]
    if len(good) < EVALS_MIN:
        errors.append(f"evals/{skill.name}.json: needs at least {EVALS_MIN} cases with query and expected_behavior")


def check_marketplace(names: set[str]) -> None:
    if not MARKETPLACE.is_file():
        errors.append(f"{MARKETPLACE.relative_to(ROOT)}: missing")
        return
    data = json.loads(MARKETPLACE.read_text(encoding="utf-8"))
    listed: set[str] = set()
    for plugin in data.get("plugins", []):
        for entry in plugin.get("skills", []):
            path = (ROOT / entry).resolve()
            if not (path / "SKILL.md").is_file():
                errors.append(f"marketplace: plugin {plugin.get('name')!r} lists {entry}, which has no SKILL.md")
            listed.add(path.name)
    for missing in sorted(names - listed):
        errors.append(f"marketplace: skill {missing!r} is not listed in any plugin")


def main() -> int:
    skills = sorted(p for p in SKILLS.iterdir() if p.is_dir())
    for skill in skills:
        check_skill(skill)
    check_marketplace({p.name for p in skills})
    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error: {e}")
    print(f"{len(skills)} skills, {len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
