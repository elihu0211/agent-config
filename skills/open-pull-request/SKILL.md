---
name: open-pull-request
description: >-
  用於被要求開 PR 或 MR、提交（commit）變更、送審、建立 merge request、設定自動合併，
  或預設分支上有未提交變更時：把目前工作樹帶到已開啟的 GitHub PR 或 GitLab MR，
  含 conventional commit 標題、squash、auto-merge，並查驗真實的合併狀態。
compatibility: 需要 git，以及已登入的 gh（GitHub）或 glab（GitLab），且能連到該平台。
license: MIT
---

# 開 PR／MR

兩個平台共用一套流程：分支、commit、push、開啟、啟用 auto-merge、查驗。

## 先讀

- 消費端 repo 的 `AGENTS.md`：commit 格式、分支命名、必要的 trailer、預設分支是否受保護，都優先於本技能。它若規定直接 push，就照做。
- 依 `git remote get-url origin` 讀對應平台的參考：[references/github.md](references/github.md) 或 [references/gitlab.md](references/gitlab.md)。

## 步驟

1. 檢視狀態：`git branch --show-current`、`git status --short`、`git fetch origin <預設分支>`、`git log origin/<預設分支>..HEAD --oneline`、`git diff --stat`。
2. 決定起點。
   - 在預設分支且有變更：分支命名 `type/brief-kebab-desc`，`git switch -c`，依檔名 add，commit。
   - 在功能分支且有未提交變更：先 commit。
   - 在功能分支且只有 commit：繼續。

   commit 訊息：`type(scope): 祈使句摘要`，type 為 fix、feat、chore、refactor、docs、test、ci。repo 或環境要求的 trailer 照加，不要自己發明。
3. 第一次 push 前先 `git rebase origin/<預設分支>`，避免衝突逼出第二次 push 與重複的 pipeline。
4. `git push -u origin <分支>`。hook 失敗就修好原因再重新 commit；絕不用 `--no-verify`。
5. 開 PR／MR：標題用 conventional commit（草稿用旗標，絕不手打 `Draft:`），內文含「摘要」（做什麼、為什麼）與「測試計畫」（已做的打勾，只能靠 CI 驗證的不打勾）。各平台指令見參考文件。
6. 啟用 squash auto-merge 與合併後刪除來源分支，依參考文件操作。
7. 向平台查詢真實狀態（不要看 CLI 印出的文字），再回報：URL、pipeline 狀態、auto-merge 是否已設定。pipeline 失敗就列出失敗的 job 名稱，不要合併。

## 規則

- 依檔名 add；絕不用可能帶入 `.env` 或憑證的 `git add .`。
- PR／MR 內文用加引號的 heredoc（`<<'EOF'`）或檔案，因為未加引號的字串裡，反引號與 `$` 會被 shell 執行。
- 對已開啟的 MR 再 push，會重置 auto-merge，也可能留下仍在跑的舊 pipeline；要重新設定並取消舊 pipeline（見參考文件）。
