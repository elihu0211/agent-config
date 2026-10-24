# AGENTS.md

本 repo 是跨專案共用技能的唯一來源。結構、安裝、更新與發布：見 [`README.md`](README.md)。

## 指令

```bash
uv run scripts/validate.py   # 規格 + repo 規則；開 PR 前必須通過
```

## 規則

- **遵循 [Agent Skills 規格](https://agentskills.io/specification)。** 目錄名 == `name`（小寫、數字、單一連字號，≤ 64）；`description` 要說明技能做什麼，**並**寫出「用於…」的使用時機（≤ 1024 字元）；`metadata` 的值必須是字串。`scripts/validate.py` 會強制檢查。
- **漸進揭露。** `SKILL.md` 放步驟與規則（遠低於 500 行）；細節放 `references/`，從 `SKILL.md` 直接連結、只深一層。agent 要執行的程式碼放 `scripts/`；範本與資料放 `assets/`。
- **與專案無關。** 技能的指令、路徑與技術棧一律交給消費端 repo 的 `AGENTS.md`，不寫死，也不提本 repo 名稱（消費端透過 `skills-lock.json` 找到來源）。
- **公開 repo。** 不放機密、內部網址，也不放客戶或專案細節。
- **寫入事實前先查證。** 法規、標準、論文要回到原始來源核對，並記錄核對程度（全文、摘要、書目）與日期。會漂移的值（版本、筆數、修正日期）寫成「於某日核對」並附可重查的來源。
- **每個技能都登記在 `.claude-plugin/marketplace.json`**，一個技能一個 plugin，名稱相同。
- **每個技能都要有 `evals/<name>.json`**，至少 3 個情境。
- **語言：繁體中文。** 技能本文、參考文件、評估與文件都用繁體中文；指令、程式碼識別字與技術名詞保留原文。
- **CI 範本是公開介面。** `ci/` 與 `.github/workflows/skills-update.yml` 以 `v1` 標籤被消費端引用；要維持向後相容，否則發 `v2`（見 README → 發布）。
