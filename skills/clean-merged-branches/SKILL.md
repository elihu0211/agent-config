---
name: clean-merged-branches
description: >-
  稽核並刪除 GitHub 或 GitLab 上 PR／MR 已合併的遠端分支、失效的本機追蹤分支與各分支的 git worktree，
  並逐檔驗證分支內容確實進了預設分支。用於被要求清理分支、刪除舊的或已合併的分支、
  清 worktree 或整理工作區時。
compatibility: 需要 git、python3，以及已登入的 gh（GitHub）或 glab（GitLab）。有 lsof 時會使用；wt CLI 為選用。
license: MIT
---

# 清理已合併的分支

判定由內附腳本完成，不在對話裡即興：稽核是唯讀的，只產生計畫；計畫執行前不會刪任何東西。

## 先讀

- 消費端 repo 的 `AGENTS.md`：受保護的分支名稱與 worktree 慣例優先於本技能。
- 修改任何腳本前先讀 [references/traps.md](references/traps.md)。每一條都是實際踩過的假結論。

## 步驟

1. 執行稽核（唯讀）。平台由 `origin` URL 自動判斷；可用 `FORGE=github` 或 `FORGE=gitlab` 覆寫：

   ```bash
   bash scripts/audit.sh [REPO_PATH] [OUTDIR]
   ```

   它會印出逐分支判定（`SAFE` 或 `NEEDS_HUMAN`）、每個 worktree 的佔用訊號，並寫出 `OUTDIR/plan.sh`，但不執行。
2. 把 `SAFE` 清單（附 PR／MR 編號）與每個被跳過的項目及理由列給使用者。除非使用者已說明全刪，否則先確認。
3. 執行計畫：

   ```bash
   bash "$OUTDIR/plan.sh"
   ```

   計畫在移除每個 worktree 前會重查佔用，並跳過稽核後分支頂端已移動的分支。計畫是快照，不是授權。
4. 回報刪了哪些（附編號）、清了哪些 worktree、跳過哪些及理由。

## 規則

- 只刪「已合併」**且**逐檔驗證內容已進預設分支的分支。絕不動有開啟中 PR／MR 的分支。
- 絕不刪 `main`、`master`、`develop`、`staging`、`release*`，也不刪有常駐用途的 worktree。
- 破壞性動作與其確認不放在同一個指令；同一次呼叫裡先檢查再刪除，等於沒有檢查。
- squash 合併是常態。`git branch -d` 會把 squash 合併的分支回報為未合併，那不是分岔。
- 遠端分支走平台 API 刪（見 `scripts/forge-*.sh`），不要 `git push --delete`，後者會觸發無關的 pre-push hook。

## 驗證腳本

修改腳本後執行 `bash scripts/test.sh`。每個測試都做過突變驗證：拿掉對應的修正，它必須變紅；只有綠燈不構成證據。
