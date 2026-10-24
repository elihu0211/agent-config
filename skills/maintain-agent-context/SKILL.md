---
name: maintain-agent-context
description: >-
  維護 repo 內與廠商無關的 agent 指示檔。用於編輯 AGENTS.md、CLAUDE.md、
  .agents/skills、skills-lock.json、.claude/、.gemini/、.cursor/rules，
  或被要求新增 .cursorrules、複製一份 agent 設定時。
license: MIT
---

# 維護 agent 脈絡

## 唯一來源

分層定義在 **`AGENTS.md` →「分層」**：先讀它，不要在這裡或其他地方重述。技能格式：[Agent Skills 規格](https://agentskills.io/specification)。

## 硬規則

1. **`CLAUDE.md` 只做匯入。** 以 `@AGENTS.md` 開頭（Claude Code 官方建議；涵蓋讀不到 `AGENTS.md` 的 session），其餘只放 Claude 專屬備註。絕不把 AGENTS.md 的內容貼進去。
2. **不要建立 `.cursorrules`。** 那是舊制；只在需要 Cursor 專屬範圍時用 `.cursor/rules/*.mdc`。
3. **不要把 `AGENTS.md` 複製進規則或技能。** 用連結或引用；維持單一基準。
4. **技能放 `.agents/skills/`。** Claude Code 只掃 `.claude/skills/`，所以把每個技能連過去：`.claude/skills/<name>` → `../../.agents/skills/<name>`。連的是 `<name>` 項目，不是 `skills` 目錄本身（[官方文件](https://code.claude.com/docs/en/skills)只涵蓋技能項目的 symlink）。絕不把技能複製進 `.claude/skills/`。
5. **共用技能是「安裝」的，不是「編輯」的。** 列在 `skills-lock.json` 的技能，來源由其 `source` 欄位指定。要改就去來源改；消費端 repo 透過排程的 skills-update pipeline（或手動 `npx skills update -p -y`）取得變更。絕不手改安裝後的副本。
6. **合併技能更新前要審查。** 技能以 agent 的完整權限執行；更新 pipeline 只開合併請求，不推到預設分支。

## 內容該放哪裡

- 確切的安裝／測試／lint 指令 → `AGENTS.md` 的指令區
- 該 repo 專屬的流程 → 該 repo 的 `.agents/skills/` 技能
- 跨 repo 重用的流程 → 共用技能 repo 的技能，用 `npx skills add` 安裝
- 依檔案類型或路徑限定的 Cursor 指引 → 帶 `globs:` 的 `.cursor/rules/*.mdc`（優先 `alwaysApply: false`）
- 套件層級的覆寫 → 該套件旁的巢狀 `AGENTS.md`

## 技能檢核

- 目錄名 == frontmatter `name`；`description` 寫明做什麼 + 何時用（完整限制見上方規格）
- `SKILL.md` 保持精簡；深入細節放 `references/` 或 `scripts/`
- 連結權威來源（`AGENTS.md`、官方文件），不要複製會漂移的事實
