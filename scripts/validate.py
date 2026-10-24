# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml>=6"]
# ///
"""依 Agent Skills 規格與本 repo 的規則驗證每個技能。

官方參考驗證器（agentskills/skills-ref）標示為僅供示範，也沒有發布到 PyPI，
所以 CI 改跑這支。執行：`uv run scripts/validate.py`。
發現任何錯誤時結束碼為 1；警告不會讓執行失敗。
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
        errors.append(f"{rel}: 缺少 SKILL.md")
        return
    try:
        meta, body = frontmatter(manifest)
    except (ValueError, yaml.YAMLError) as e:
        errors.append(f"{rel}/SKILL.md: {e}")
        return

    name = meta.get("name")
    if not isinstance(name, str) or not NAME.match(name) or len(name) > NAME_MAX:
        errors.append(f"{rel}: name {name!r} 必須是 1-{NAME_MAX} 個小寫字母、數字與單一連字號")
    elif name != skill.name:
        errors.append(f"{rel}: name {name!r} 必須與目錄名稱相同")

    if isinstance(name, str) and any(w in name for w in RESERVED):
        errors.append(f"{rel}: name 不可含保留字 ({', '.join(RESERVED)})")

    desc = meta.get("description")
    if not isinstance(desc, str) or not desc.strip():
        errors.append(f"{rel}: 必須有 description")
    elif len(desc) > DESCRIPTION_MAX:
        errors.append(f"{rel}: description 有 {len(desc)} 字元（上限 {DESCRIPTION_MAX}）")
    elif not re.search(r"用於|使用時機|use when", desc, re.I):
        warnings.append(f"{rel}: description 應寫明使用時機（「用於…」）")

    if isinstance(desc, str) and (XML.search(desc) or (isinstance(name, str) and XML.search(name))):
        errors.append(f"{rel}: name 與 description 不可含 XML 標籤")
    if isinstance(desc, str) and PERSON.search(desc):
        warnings.append(f"{rel}: description 不宜使用第一或第二人稱")

    compat = meta.get("compatibility")
    if compat is not None and (not isinstance(compat, str) or not 1 <= len(compat) <= COMPATIBILITY_MAX):
        errors.append(f"{rel}: compatibility 必須是 1-{COMPATIBILITY_MAX} 字元")

    extra = meta.get("metadata")
    if extra is not None and (
        not isinstance(extra, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in extra.items())
    ):
        errors.append(f"{rel}: metadata 的鍵與值都必須是字串（數字要加引號，例如 version: \"1.0\"）")

    tools = meta.get("allowed-tools")
    if tools is not None and not isinstance(tools, str):
        errors.append(f"{rel}: allowed-tools 必須是以空白分隔的字串")

    unknown = set(meta) - KNOWN_FIELDS
    if unknown:
        warnings.append(f"{rel}: 規格以外的欄位：{', '.join(sorted(unknown))}")

    if body.count("\n") > BODY_LINES_MAX:
        warnings.append(f"{rel}: SKILL.md 本文超過 {BODY_LINES_MAX} 行；請把細節移到 references/")

    for md in skill.rglob("*.md"):
        for target in LINK.findall(md.read_text(encoding="utf-8")):
            path = target.split("#", 1)[0]
            if path and not (md.parent / path).exists():
                errors.append(f"{md.relative_to(ROOT)}: 連結失效 {target}")


    skill_text = manifest.read_text(encoding="utf-8")
    for ref in sorted((skill / "references").glob("*.md")) if (skill / "references").is_dir() else []:
        if f"references/{ref.name}" not in skill_text:
            errors.append(f"{ref.relative_to(ROOT)}: 沒有被 SKILL.md 連結")
        text = ref.read_text(encoding="utf-8")
        if text.count("\n") > REFERENCE_TOC_LINES and not re.search(r"^#+\s*(contents|目錄)", text, re.I | re.M):
            warnings.append(f"{ref.relative_to(ROOT)}: 超過 {REFERENCE_TOC_LINES} 行卻沒有「目錄」段落")

    cases_file = EVALS / f"{skill.name}.json"
    try:
        cases = json.loads(cases_file.read_text(encoding="utf-8")).get("cases", [])
    except (OSError, ValueError):
        errors.append(f"evals/{skill.name}.json: 不存在或格式無效")
        return
    good = [c for c in cases if c.get("query") and c.get("expected_behavior")]
    if len(good) < EVALS_MIN:
        errors.append(f"evals/{skill.name}.json: 至少需要 {EVALS_MIN} 個同時有 query 與 expected_behavior 的情境")


def check_marketplace(names: set[str]) -> None:
    if not MARKETPLACE.is_file():
        errors.append(f"{MARKETPLACE.relative_to(ROOT)}: 不存在")
        return
    data = json.loads(MARKETPLACE.read_text(encoding="utf-8"))
    listed: set[str] = set()
    for plugin in data.get("plugins", []):
        for entry in plugin.get("skills", []):
            path = (ROOT / entry).resolve()
            if not (path / "SKILL.md").is_file():
                errors.append(f"marketplace: plugin {plugin.get('name')!r} 列出 {entry}，但它沒有 SKILL.md")
            listed.add(path.name)
    for missing in sorted(names - listed):
        errors.append(f"marketplace: 技能 {missing!r} 沒有列在任何 plugin")


def main() -> int:
    skills = sorted(p for p in SKILLS.iterdir() if p.is_dir())
    for skill in skills:
        check_skill(skill)
    check_marketplace({p.name for p in skills})
    for w in warnings:
        print(f"警告：{w}")
    for e in errors:
        print(f"錯誤：{e}")
    print(f"{len(skills)} 個技能，{len(errors)} 個錯誤，{len(warnings)} 個警告")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
