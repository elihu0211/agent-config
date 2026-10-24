# agent-skills

跨專案共用、與廠商無關的 [Agent Skills](https://agentskills.io/specification)（個人使用）。每個技能一個目錄，放在 [`skills/`](skills) 下；每份 `SKILL.md` 的 front matter 說明技能做什麼、何時適用，所以目錄本身就是索引。

## 結構

```
skills/<name>/                      一個技能：SKILL.md（+ references/、scripts/、assets/）
evals/<name>.json                   每個技能至少 3 個評估情境（不隨技能安裝）
template/                           新技能的起點（SKILL.template.md）
.claude-plugin/marketplace.json     Claude Code plugin marketplace（一個技能對應一個 plugin）
scripts/validate.py                 規格與 repo 規則驗證（CI 會執行）
.github/workflows/validate.yml      每個 PR 都跑驗證
.github/workflows/skills-update.yml GitHub 消費端 repo 用的可重用 workflow
ci/skills-update.gitlab-ci.yml      GitLab 消費端 repo 用的 CI 範本
```

## 安裝到專案（任何 agent）

專案用 [`skills` CLI](https://github.com/vercel-labs/skills) 安裝。它會寫入 `.agents/skills/<name>/`，並把來源與內容雜湊釘在 `skills-lock.json`：

```bash
DISABLE_TELEMETRY=1 npx skills add elihu0211/agent-skills --skill <name> -a codex -y
```

Codex、Cursor、GitHub Copilot、Gemini CLI 會讀 `.agents/skills/`。Claude Code 只掃 `.claude/skills/`，所以要把每個技能連過去：`.claude/skills/<name> → ../../.agents/skills/<name>`。[官方文件](https://code.claude.com/docs/en/skills)只涵蓋「`<name>` 項目是 symlink」，不涵蓋整個 `skills` 目錄是 symlink。

## 讓專案保持最新

每個消費端專案跑排程工作，執行 `npx skills update -p -y`，有變更就開一個合併請求。不會自動合併：技能以 agent 的完整權限執行，所以由人審 diff。

**GitHub** — 新增 `.github/workflows/skills-update.yml`：

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

再開啟 *Settings → Actions → General → Allow GitHub Actions to create and approve pull requests*。

**GitLab** — include 範本，並把隱藏工作指定到該 repo 的某個 stage：

```yaml
include:
  - remote: https://raw.githubusercontent.com/elihu0211/agent-skills/v1/ci/skills-update.gitlab-ci.yml

skills-update:
  extends: .skills-update
  stage: <該 repo 的其中一個 stage>
```

接著加入 `SKILLS_UPDATE_TOKEN` 變數，以及帶 `SKILLS_UPDATE=true` 的 pipeline 排程；範本開頭列出所有步驟。

## 自己在 Claude Code 全域使用

想讓技能出現在每個 session、而不是逐專案釘版本，可把本 repo 加為 plugin marketplace，Claude Code 會在背景更新：

```
/plugin marketplace add elihu0211/agent-skills
/plugin install <name>@elihu0211-skills
```

每個專案只用一種管道：同一技能兩邊都裝會載入兩次。

## 修改或新增技能

1. 把 [`template/`](template) 複製成 `skills/<name>/`，並把 `SKILL.template.md` 改名為 `SKILL.md`（或直接改既有技能）。範本不叫 `SKILL.md`，是因為 skills CLI 會把它當成可安裝技能。規範見 [`AGENTS.md`](AGENTS.md)。
2. 把技能加進 [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json)。
3. 新增 `evals/<name>.json`，至少 3 個情境（`query` 與 `expected_behavior`）；先從「沒有此技能時 agent 會做錯的任務」寫起，再寫技能本文。放在 `skills/` 之外，消費端不會裝到。
4. 執行 `uv run scripts/validate.py`（技能若有腳本，也跑 `bash skills/<name>/scripts/test.sh`）。
5. 量測觸發率：`uv run scripts/run_evals.py --runs 3 [--only <name>]`。每個情境在全新的暫時 git repo 以 plan 模式執行（禁用 Bash／Edit／Write，不會產生副作用），統計 agent 是否載入預期技能，另有 4 個不該觸發的對照情境。情境可帶 `setup`（`files` 先 commit、`dirty` 為未提交變更、`branches` 為額外分支）；`"trigger": false` 表示不要求觸發。結果有隨機性，看趨勢，不看單次。
6. 開 PR。

## 發布

消費端以 `v1` 標籤引用 CI 範本。合併 `ci/` 或 `.github/workflows/skills-update.yml` 的變更後，要移動標籤：

```bash
git tag -f v1 origin/main && git push -f origin v1
```

技能內容本身不打標籤：`npx skills update` 跟隨預設分支，消費端的合併請求就是審查點。CI 範本若有破壞性變更，改發新的主版本（`v2`），不移動 `v1`。

## 授權

[MIT](LICENSE)。每份 `SKILL.md` 都帶 `license: MIT`，讓授權條款隨安裝的副本一起走。
