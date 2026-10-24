# /// script
# requires-python = ">=3.11"
# ///
"""量測每個技能的觸發率：對 evals/<skill>.json 的每個情境跑 `claude -p`，
檢查 agent 是否載入了預期的技能（呼叫 Skill 工具，或直接讀該技能的 SKILL.md）。另外跑一組「不該觸發」的對照情境，量測誤觸發。

安全：每次都在全新的暫時 git repo 裡，以 plan 模式執行，並禁用 Bash／Edit／Write，
所以不會真的開 PR、刪分支或改檔；只看第一輪是否選中技能。

用法：uv run scripts/run_evals.py [--runs 3] [--model sonnet] [--only <skill>]
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVALS = ROOT / "evals"

# 不該觸發任何本 repo 技能的對照情境
NEGATIVES = [
    "解釋一下 Python 的 asyncio 事件迴圈怎麼運作。",
    "解釋 TCP 三向交握與四向揮手的差別。",
    "幫我寫一個計算費氏數列的函式，附單元測試。",
    "這個專案的 git log 最近 5 筆是什麼？",
]


def run_once(query: str, model: str, setup: dict | None = None) -> set[str]:
    """回傳這次對話裡被呼叫的技能名稱集合。"""
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["git", "init", "-q", "-b", "main", tmp], check=True)
        # 六個技能都以專案技能形式提供，與全域已安裝與否無關
        shutil.copytree(ROOT / "skills", Path(tmp) / ".claude" / "skills")
        # 情境可帶 setup：files 先 commit，dirty 寫成未提交的變更，讓 agent 面對真實的 repo 狀態
        setup = setup or {}
        for rel, text in (setup.get("files") or {}).items():
            (Path(tmp) / rel).parent.mkdir(parents=True, exist_ok=True)
            (Path(tmp) / rel).write_text(text, encoding="utf-8")
        git = ["git", "-C", tmp, "-c", "user.name=eval", "-c", "user.email=eval@example.com"]
        subprocess.run([*git, "add", "-A"], check=True)
        subprocess.run([*git, "commit", "-q", "--allow-empty", "-m", "init"], check=True)
        for rel, text in (setup.get("dirty") or {}).items():
            (Path(tmp) / rel).parent.mkdir(parents=True, exist_ok=True)
            (Path(tmp) / rel).write_text(text, encoding="utf-8")
        for br in setup.get("branches") or []:
            subprocess.run([*git, "branch", br], check=True)
        cmd = [
            "claude", "-p", query,
            "--model", model,
            "--output-format", "stream-json", "--verbose",
            "--permission-mode", "plan",
            "--disallowedTools", "Bash", "Edit", "Write", "NotebookEdit",
            "--max-turns", "6",
        ]
        try:
            out = subprocess.run(cmd, cwd=tmp, capture_output=True, text=True, timeout=240).stdout
        except subprocess.TimeoutExpired:
            return {"<timeout>"}
    used: set[str] = set()
    for line in out.splitlines():
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if ev.get("type") != "assistant":
            continue
        for block in ev.get("message", {}).get("content", []):
            if not (isinstance(block, dict) and block.get("type") == "tool_use"):
                continue
            inp = block.get("input", {})
            if block.get("name") == "Skill":
                used.add(str(inp.get("skill", "")).split(":")[-1])
            elif block.get("name") == "Read":
                # 直接讀技能檔，等同載入該技能
                parts = Path(str(inp.get("file_path", ""))).parts
                if "skills" in parts and parts[-1] == "SKILL.md":
                    used.add(parts[-2])
    return used


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--model", default="sonnet")
    ap.add_argument("--only")
    args = ap.parse_args()

    jobs = []  # (kind, skill, case_id, query, setup)
    for f in sorted(EVALS.glob("*.json")):
        data = json.loads(f.read_text(encoding="utf-8"))
        if args.only and data["skill"] != args.only:
            continue
        for c in data["cases"]:
            jobs.append(("optional" if c.get("trigger") is False else "positive", data["skill"], c["id"], c["query"], c.get("setup")))
    if not args.only:
        for i, q in enumerate(NEGATIVES):
            jobs.append(("negative", "-", f"neg-{i + 1}", q, None))

    tasks = [(j, r) for j in jobs for r in range(args.runs)]
    with ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(lambda t: (t[0], run_once(t[0][3], args.model, t[0][4])), tasks))

    table: dict[tuple, list[bool]] = {}
    seen: dict[tuple, list[set[str]]] = {}
    for (kind, skill, cid, _, _s), used in results:
        key = (kind, skill, cid)
        hit = (skill in used) if kind in ("positive", "optional") else not (used & {p.stem for p in EVALS.glob("*.json")})
        table.setdefault(key, []).append(hit)
        seen.setdefault(key, []).append(used)

    print(f"{'類型':<9}{'技能':<26}{'情境':<28}{'通過':<8}實際呼叫")
    pos_hit = pos_all = neg_hit = neg_all = 0
    for key in sorted(table):
        kind, skill, cid = key
        hits = sum(table[key])
        shown = sorted({s for u in seen[key] for s in u})
        print(f"{kind:<9}{skill:<26}{cid:<28}{hits}/{len(table[key]):<6}{', '.join(shown) or '-'}")
        if kind == "positive":
            pos_hit += hits; pos_all += len(table[key])
        elif kind == "optional":
            pass  # 不要求觸發（例如 repo 規定直接 push 時，agent 可不載入技能）
        else:
            neg_hit += hits; neg_all += len(table[key])
    print(f"\n觸發率（應觸發）：{pos_hit}/{pos_all}")
    if neg_all:
        print(f"正確不觸發（對照）：{neg_hit}/{neg_all}")


if __name__ == "__main__":
    main()
