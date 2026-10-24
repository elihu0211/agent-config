# agent-skills

與廠商無關的 [Agent Skills](https://agentskills.io/specification) 集合。

## 技能

| 技能 | 用途 |
|------|------|
| [`open-pull-request`](skills/open-pull-request) | 從未提交的變更到已開啟的 GitHub PR／GitLab MR，含 squash auto-merge 與狀態查驗 |
| [`clean-merged-branches`](skills/clean-merged-branches) | 稽核並刪除已合併的遠端分支、本機追蹤分支與 worktree |
| [`maintain-agent-context`](skills/maintain-agent-context) | 維護 `AGENTS.md`、`CLAUDE.md`、`.agents/skills` 與 `skills-lock.json` |
| [`name-files`](skills/name-files) | 檔案與目錄命名、文件為主的 repo 結構 |
| [`structure-docs`](skills/structure-docs) | 以 Diátaxis 組織 `docs/` |
| [`dsrm-technical-report`](skills/dsrm-technical-report) | 撰寫與審查 DSRM 技術報告 |

## 結構

```
skills/<name>/                      SKILL.md（+ references/、scripts/、assets/）
evals/<name>.json                   每個技能至少 3 個評估情境（不隨技能安裝）
template/                           新技能的起點
.claude-plugin/marketplace.json     Claude Code plugin marketplace
scripts/validate.py                 規格與 repo 規則驗證
scripts/run_evals.py                觸發率量測
.github/workflows/validate.yml      PR 驗證
.github/workflows/skills-update.yml GitHub 消費端用的可重用 workflow
ci/skills-update.gitlab-ci.yml      GitLab 消費端用的 CI 範本
```

## 安裝

### 專案

用 [`skills` CLI](https://github.com/vercel-labs/skills) 安裝；它寫入 `.agents/skills/<name>/`，並把來源與內容雜湊釘在 `skills-lock.json`：

```bash
DISABLE_TELEMETRY=1 npx skills add elihu0211/agent-skills --skill <name> -a codex -y
```

Codex、Cursor、GitHub Copilot、Gemini CLI 讀 `.agents/skills/`。Claude Code 只掃 `.claude/skills/`，需逐一連結：`.claude/skills/<name> → ../../.agents/skills/<name>`（[官方文件](https://code.claude.com/docs/en/skills)只涵蓋技能項目的 symlink，不涵蓋整個 `skills` 目錄）。

### Claude Code 全域

```
/plugin marketplace add elihu0211/agent-skills
/plugin install <name>@elihu0211-skills
```

同一專案只用一種管道，否則技能會載入兩次。

## 更新

消費端專案以排程工作執行 `npx skills update -p -y`，有變更就開合併請求，不自動合併（技能以 agent 的完整權限執行，需人工審 diff）。

**GitHub**：新增 `.github/workflows/skills-update.yml`，再開啟 *Settings → Actions → General → Allow GitHub Actions to create and approve pull requests*。

```yaml
on:
  schedule: [{ cron: "0 21 * * 0" }]   # 週一 05:00 Asia/Taipei
  workflow_dispatch:
permissions:
  contents: write
  pull-requests: write
jobs:
  update:
    uses: elihu0211/agent-skills/.github/workflows/skills-update.yml@v1
```

**GitLab**：include 範本，把隱藏工作指定到該 repo 的某個 stage，再加入 `SKILLS_UPDATE_TOKEN` 變數與帶 `SKILLS_UPDATE=true` 的 pipeline 排程。步驟見範本開頭。

```yaml
include:
  - remote: https://raw.githubusercontent.com/elihu0211/agent-skills/v1/ci/skills-update.gitlab-ci.yml

skills-update:
  extends: .skills-update
  stage: <該 repo 的其中一個 stage>
```

## 開發

1. 複製 [`template/`](template) 為 `skills/<name>/`，並把 `SKILL.template.md` 改名為 `SKILL.md`。範本不叫 `SKILL.md`，因為 skills CLI 會把它當成可安裝技能。規範見 [`AGENTS.md`](AGENTS.md)。
2. 加進 [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json)。
3. 新增 `evals/<name>.json`，至少 3 個情境（`query`、`expected_behavior`）。先從「沒有此技能時 agent 會做錯的任務」寫起，再寫技能本文。
4. 驗證：`uv run scripts/validate.py`；技能有腳本時加跑 `bash skills/<name>/scripts/test.sh`。
5. 量測觸發率：`uv run scripts/run_evals.py --runs 3 [--only <name>]`。
6. 開 PR。

### 觸發率量測

每個情境在全新的暫時 git repo 以 plan 模式執行 `claude -p`（禁用 Bash／Edit／Write，無副作用），統計 agent 是否載入預期技能，另有 4 個不該觸發的對照情境。

情境欄位：

| 欄位 | 說明 |
|------|------|
| `query`、`expected_behavior` | 使用者請求與預期行為（目前不評分，只量觸發） |
| `setup.files` | 先 commit 的檔案 |
| `setup.dirty` | 未提交的變更 |
| `setup.branches` | 額外建立的分支 |
| `trigger: false` | 不要求觸發 |

結果有隨機性，看多次的趨勢。

## 發布

消費端以 `v1` 標籤引用 CI 範本。合併 `ci/` 或 `.github/workflows/skills-update.yml` 的變更後移動標籤：

```bash
git tag -f v1 origin/main && git push -f origin v1
```

技能內容不打標籤：`npx skills update` 跟隨預設分支，審查點是消費端的合併請求。CI 範本有破壞性變更時發 `v2`，不移動 `v1`。

## 授權

[MIT](LICENSE)。
