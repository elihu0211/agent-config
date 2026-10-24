---
name: github-pr
description: >-
  Create a branch, commit, push, open a GitHub PR and enable squash auto-merge
  from the current working tree. Use when asked to commit, open a pull request,
  send for review or merge to main, or when uncommitted changes sit on main.
---

# GitHub PR 建立技能

從目前 git 狀態一鍵完成：分支 → commit → push → PR → auto-merge。

## 例外情形

若目標 repo 的 `AGENTS.md` 規定直接 push 或另有流程，以該規定為準。若 auto-merge 設定後 `autoMergeRequest` 仍為 null，或 CI 因帳務／額度問題整批未啟動，先辨識根因再決定路徑，不要硬套步驟 5。

## 環境慣例

- **CLI**：`gh`（需已 `gh auth login`）
- **Conventional Commits**：`type(scope): 說明`，type = fix / feat / chore / refactor / docs / test / ci
- **PR 選項**：`--squash`（squash merge）+ `--auto`（CI 通過後自動合併）
- **Branch protection**：`main` 不可直接 push，所有變更須透過 PR

## 工作流程

### 1. 讀取目前狀態

```bash
git branch --show-current   # 確認目前分支
git status --short          # 確認未提交變更
git log main..HEAD --oneline  # 若已在 feature branch，確認 commit
git diff --stat             # 了解變更範圍
```

### 2. 決定起點

**情況 A：目前在 `main`，有未提交變更（最常見）**

從 diff 推導分支名稱（`type/brief-kebab-desc`，如 `feat/llm-model-env`），然後：

```bash
git checkout -b <branch-name>
git add <相關檔案>   # 精確 add，避免 .env、credentials
git commit -m "<conventional commit message>"
```

commit 訊息格式：
```
type(scope): 動詞 + 說明（英文）

- 條列主要變更（可選，超過 3 個檔案時加）

Co-Authored-By: Claude <目前使用的模型名稱，如 Claude Sonnet 5> <noreply@anthropic.com>
```

**情況 B：已在 feature branch，且有未提交變更**

先 commit 再繼續：

```bash
git add <相關檔案>
git commit -m "<message>"
```

**情況 C：已在 feature branch，commit 已完成**

直接進入 push 步驟。

### 3. Push

```bash
git push -u origin <branch-name>
```

若 pre-commit hook 失敗，修正問題後重新 commit，**不加 `--no-verify`**。

### 4. 建立 PR

從 `git diff main..HEAD` 推導 PR 標題與 body：

```bash
gh pr create \
  --title "<type(scope): 說明>" \
  --body "$(cat <<'EOF'
## Summary

- <bullet 說明做了什麼、為什麼>

## Test plan

- [ ] <可驗證的 checklist>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

記下回傳的 PR URL（如 `https://github.com/owner/repo/pull/N`）。

### 5. 設定 auto-merge

```bash
gh pr merge <PR-number> --auto --squash
```

若失敗（CI 尚未啟動），等 5 秒再試一次。

### 6. 回報

以繁體中文告知使用者：
- PR URL（格式：`owner/repo#N` 加完整 URL）
- auto-merge 是否設定成功
- 若 CI 失敗，列出失敗的 check 名稱，不嘗試 merge

## 注意事項

- `git add` 優先指定檔案名稱，避免 `git add .` 意外包含 `.env` 或 secrets
- pre-commit hook 觸發 ruff 等 linter 失敗時，修正後重新 commit，不跳過 hook
- PR body 的 Summary 與 Test plan 要具體，不要只寫「更新了一些東西」
