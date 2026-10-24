---
name: name-files
description: >-
  讓檔案與目錄命名可攜，並規劃文件為主的 repo 結構（論文、報告、共用資源）。
  用於建立、改名或搬移檔案與目錄，把檔名改成小寫或統一命名慣例，決定文件、論文或報告該放哪裡，
  把 repo 從非 ASCII 或含空白的路徑遷移出來，或在 PR 中審查命名時。
license: MIT
---

# 檔案與目錄命名

路徑給機器看，標題給人看。每個路徑都用小寫 ASCII，人類可讀的標題（任何語言）放在文件的中繼資料，不放在檔名。

## 規則

1. **小寫 ASCII kebab-case。** 只用 `a-z`、`0-9`、`-`，副檔名用 `.`。不要空白、大寫、非 ASCII（含 CJK）；除非工具賦予意義（見下），不用 `_`。依據：[references/sources.md](references/sources.md)。
2. **順序重要時加零填補數字前綴。** `01-`、`02-` … `10-`，讓字典序等於閱讀順序。巢狀系列重複上層編號：`03-corpus/03-05-pending-source-integration.qmd`。順序不重要就不加數字。
3. **用字描述內容。** `03-05-pending-source-integration`，不要 `03-05-part-2` 或 `final-v3`。版本交給 git；日期只有在「日期就是身分」時才用 ISO 8601（`2026-10-23-incident.md`）。
4. **標題放中繼資料。** front matter 的 `title:`（Markdown、Quarto、Pandoc）、`\title{}`（LaTeX），或第一個標題。讀者看到標題，工具看到路徑。輸出（PDF、HTML）顯示標題，所以 ASCII 路徑不會損失任何東西。
5. **工具規定的名稱優先。** 保留工具要求的大小寫與形式：`README.md`、`AGENTS.md`、`CLAUDE.md`、`SKILL.md`、`LICENSE`、`Dockerfile`、`Makefile`、`_quarto.yml`、`index.qmd`、`.gitignore`。開頭的 `_` 保留工具含義（Quarto：僅供 include 的片段，不單獨渲染）。原始碼依其語言慣例（Python 模組 `snake_case`、Go 套件、Java 類別）。
6. **改名要保留歷史並驗證連結。** 每個檔案都用 `git mv`；重寫每個相對連結與 include：從舊位置解析，再依新位置重算；然後跑 repo 的連結檢查。改名絕不改變文件的標題。

## 文件為主的 repo 結構

| 路徑 | 放什麼 | 備註 |
|------|--------|------|
| `docs/` | 關於專案的文件（怎麼用、怎麼維運、怎麼決策） | 適用 Diátaxis：見 `structure-docs` 技能 |
| `papers/` | 獨立的文章或專著，一份一個檔案 | 數量多時分成編號的卷 |
| `reports/<name>/` | 一份報告一個目錄（Quarto 專案、LaTeX 專案…） | 上層用複數，之後多一份報告不必重整 |
| `shared/` | 超過一處共用的資源（LaTeX 序言、樣式、CSL） | 只留一份；不要複製進各個函式庫 |
| `references.bib` | 唯一的書目 | 多個函式庫引用時放在根目錄 |
| `_output/` | 渲染產物 | git 忽略；鏡射原始碼結構 |

`docs/` 在整個生態系都指「專案文件」（GitHub Pages、MkDocs、Cookiecutter Data Science）；不要拿來放研究論文或報告。

## 遷移檢核表

- [ ] 為每個受追蹤的檔案與目錄建立 舊 → 新 對照表；搬移前先確認沒有衝突。
- [ ] 全部在同一個 commit 用 `git mv`，歷史才會跟著走。
- [ ] 重寫相對連結與 include（從舊位置解析、依新位置重算）；更新設定中的路徑（建置設定、輸出目錄、書目、資源 include）。
- [ ] 在文字、註解與設定中搜尋殘留的舊路徑字串。
- [ ] 跑 repo 完整檢查與建置；確認搬移前後的連結數與輸出數一致。
- [ ] 更新列出被搬移路徑的索引（`AGENTS.md`、`README.md`、上層工作區索引）。

## 優先順序

本技能取代各 repo 自訂的命名規則：repo 的 `AGENTS.md` 指向這裡，不再重述。repo 必須偏離時（工具或外部系統強制另一種形式），由其 `AGENTS.md` 寫明例外與理由。
