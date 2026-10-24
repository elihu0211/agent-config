---
name: github-branch-cleanup
description: >-
  Delete merged or closed remote GitHub branches, stale local tracking branches
  and, where the repo uses them, per-branch git worktrees. Use when asked to clean
  up branches, delete old branches or tidy the workspace in any GitHub repo.
---

# GitHub 分支清理技能

清理已 merged／closed PR 對應的遠端分支殘留、本機已失效追蹤分支，以及（若該 repo 有此慣例）
per-branch git worktrees。

判定邏輯**不在這份文件裡，也不要在對話裡即興重寫**——共用引擎在
`~/.claude/lib/branch-cleanup/`，GitLab 與 GitHub 用同一份判定，差異只在 forge adapter。

| 檔案 | 用途 |
|------|------|
| `audit.sh` | 唯讀稽核，產出判定表與 `plan.sh`。不刪任何東西 |
| `occupancy.sh` | worktree 佔用判定的單一來源，`audit.sh` 與 `plan.sh` 都 source 它 |
| `forge-github.sh` | 本 forge 的 MR/PR 查詢與遠端分支刪除指令 |
| `test.sh` | 離線回歸測試（合成 repo + stub，不需網路）。改判定邏輯後必跑 |
| `TRAPS.md` | 已知會產生假結論的陷阱與佔用訊號的可靠度 |

`test.sh` 每一條都經過突變驗證：把對應修正拿掉、該條必須變紅。綠燈本身不是證據——第一版
有兩條在修正被移除後仍全綠，代表什麼都沒測到，補到會紅為止才算數。

## 安全原則

- 只刪已 merged 且**內容經逐檔驗證已進 `origin/main`** 的分支；不動 open PR 的分支
- 不刪 `main`／`master`／`develop`／`staging`／`release`，不刪常駐用途的 worktree
- **破壞性動作與其前置確認不可寫在同一個指令**。同一次呼叫裡先檢查再 remove ＝沒有確認：
  輸出回到眼前時刪除早就執行完了
- **squash-merge 是常態，不是例外**。`git branch -d` 的祖先檢查對 squash-merged 分支必定
  回報「未完全合併」，那不是異常分岔

## 工作流程

```bash
bash ~/.claude/lib/branch-cleanup/audit.sh [REPO_PATH] [OUTDIR]
```

forge 由 origin URL 自動判斷（可用 `FORGE=github` 覆寫）。輸出逐分支判定（`SAFE`／
`NEEDS_HUMAN`）、每棵 worktree 的四個佔用訊號，以及 `$OUTDIR/plan.sh`——**尚未執行**。

把 `SAFE` 清單（附 PR 編號）與被跳過的項目及理由列給使用者確認。使用者已明確說「全刪」
時可直接執行：

```bash
bash "$OUTDIR/plan.sh"
```

`plan.sh` 不是一串裸指令：每個 `remove_wt` 在移除前重跑四個佔用訊號，每個 `del_branch`
先比對分支 tip 是否還是稽核當下那顆——tip 動過代表期間有人往上 commit、內容驗證整個失效，
直接 SKIP。**計畫是快照，快照不能當授權**，所以不需要「執行前記得重跑稽核」這種靠人記得的
紀律。

遠端分支通常在合併時就被 `remove-source-branch` 清掉了；真的需要刪時走 API，不要
`git push --delete`（會觸發 pre-push hook 跑無關的測試），指令見 `forge-github.sh`。

最後回報：刪了哪些分支（附編號）、清了哪些 worktree、跳過哪些及理由。

## 動判定邏輯之前

先讀 `~/.claude/lib/branch-cleanup/TRAPS.md`。裡面每一條都是實測踩過才寫進腳本的，包括
patch-id 對 squash 的系統性假警報、rename 讓「舊路徑刪除」逃出檢查、zsh `echo` 破壞 JSON、
`diff` 被別名成 delta，以及四個佔用訊號各自抓不到什麼。改完必跑 `test.sh`。
