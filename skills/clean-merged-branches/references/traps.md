# 分支清理：已知會產生假結論的陷阱

`gitlab-branch-cleanup` / `github-branch-cleanup` 兩支 skill 共用的說明。以下每一條都已在
`audit.sh` / `occupancy.sh` 內處理掉，列出來是為了**不要**在對話裡重新發明這些判斷。

## 判定「貢獻是否已進 main」

1. MR/PR 狀態為 merged 且有 merge commit SHA
2. 該 merge commit 是 `origin/main` 的祖先
3. 對分支 touch 的**每個檔案**，分支自己的增刪行集合 ⊆ merge 帶進來的增刪行集合
4. 第 3 點若不成立，再看該檔在分支上的內容是否與**現在的** `origin/main` 逐位元組相同；
   相同就不算落差（差異來自 rebase／merge 把別人已合併的工作帶進 diff 範圍）

第 3 點只要求包含、不要求相等：main 基準較舊時後者合理地更大。

GitLab 的 merge_commit_sha 是雙親 merge commit（**但 squash 合併與 auto-merge 時它是 null，落地的 commit 在 `squash_commit_sha`**，adapter 已補，否則 squash 常態會全部被判 NEEDS_HUMAN），GitHub squash-merge 的 mergeCommit 是單親
squash commit——兩者的 `SHA^1` 都等於「合併前的 main」，所以 `diff(SHA^1, SHA)` 對兩邊都成立。

## 假結論陷阱

**patch-id 比對對 squash 工作流是系統性假警報。** 舊版技能用 `git diff MB..branch | git patch-id`
對比 squash 的 patch-id。patch-id 連 context 行一起雜湊，分支基準與 squash 基準不同（別的 MR 先
進 main）就必然不同。實測一批全 merged 的分支裡有兩支報 WARN，逐一追查後都是假警報。

**rename 會讓「刪除舊路徑」逃出檢查範圍。** `git diff --name-only` 對 rename 只吐新路徑，舊路徑
不在後續 pathspec 內，於是「rename 只落地一半（新檔加了、舊檔沒刪）」完全看不見。一律加
`--no-renames`，讓 rename 拆成 delete + add。

**zsh 的 `echo` 會展開跳脫序列。** `echo "$JSON" | python3` 把 GitLab/GitHub 回傳的 `\n` 轉成真
換行、破壞 JSON，`json.load` 失敗被 except 吞掉，整批分支回報「查無 MR」——一個形狀合理的假
結論。JSON 一律寫檔再解析，或用 `printf '%s'`。

**`diff` 可能被別名成 delta。** `diff -q` 直接報 unknown argument，`if` 判斷落到錯的分支。用
`cmp -s`／`comm`。腳本以 `#!/usr/bin/env bash` 執行時不吃互動 shell 的別名，這是主要防線。

**互動 shell 的 `find` 可能根本是別的程式。** 這台機器上 `find` 是 Claude Code shell snapshot 定義的
shell function（實際跑 bfs），不接受 `-newermt "-24 hours"` 這種相對時間格式，直接報錯；配上
`2>/dev/null` 就成了「查無檔案」的假結論——2026-09-06 據此誤判成「該 worktree 24 小時內沒有檔案被
寫過」，真實情況是 13 小時前才寫過。腳本以 bash 執行時拿到的是 `/usr/bin/find`，語法正常。同理
`ls` 是 eza，`ls -lt` 的 `-t` 會被當成 `--time <FIELD>` 而整條失敗。**這兩條專坑在對話裡即興下指令
的人，不坑腳本**——正是判定該留在腳本裡、而非在對話裡重新發明的另一個理由。診斷時也不要把輸出
接進 `2>/dev/null`／`| tail`，那會把失敗細節切掉再誤歸給被查的對象。

**列 MR/PR 清單不能當刪除依據。** `glab mr list --merged --per-page` / `gh pr list --limit` 都有上限，
打滿時漏掉更早的項目。改用 `source_branch=` / `--head` 直查單一分支。（另：`glab mr list` 沒有
`--state`，篩已合併是 `-M`／`--merged`。）

**`awk '{print $1}' | sed 's/^\*//'` 會讓分支名整個消失。** `*`／`+` 與分支名是各自獨立的欄位，
名稱在 `$2`；對 `$1` 做 sed 去前綴無效。用條件式 awk。

**zsh 不對未加引號的變數做 word-splitting。** `git diff ... -- $FILES` 會把整段多行字串當成單一
pathspec，diff 靜默回空。用 `-z` / `xargs -0`。

**macOS 的 grep 沒有 `-P`。** 欄位比對用 awk。

## worktree 佔用：四個訊號都要看，沒有一個單獨可靠

| 訊號 | 抓得到 | 抓不到 |
|------|--------|--------|
| `git status --porcelain` | 寫過但未提交 | 只讀著沒改的 session |
| `lsof +D` | 此刻 cwd 落在該樹的行程 | 單次快照。實測命中 0，五分鐘後同一棵是 8 |
| `wt list` 的 🤖 | agent 執行中 | Ctrl+C 中斷或 session 被砍後永久殘留 |
| worktree 私有 `logs/HEAD` mtime | 最近做過 git 操作 | 純輪詢／編輯中但沒下 git 指令的 session |

**這台機器上沒有行程層級的事實能證明佔用**：查證過所有 session 的 cwd 都是容器目錄，靠
`git -C <path>` 操作 worktree。所以 `ACTIVE_WINDOW_SECS` 這個啟發式消不掉，真正的根治是每個
session 主動寫帶 PID 的佔用聲明。

**不要為了「一次過」統一加 `--force`。** `git worktree remove` 在有未提交變更時會拒絕，那是最後
一道防線。`plan.sh` 刻意不加。

**髒檔數突然暴增，可能是另一個 session 正在刪這棵樹，不是有人在寫入。** 2026-09-06：一棵樹在稽核
當下 0 髒檔、無 lsof、reflog 停在 13 小時前，一分鐘後 `plan.sh` 執行時卻報「有 1520 個未提交變更」，
再一分鐘後整個目錄消失——那 1520 筆是 `git status` 看到大量檔案被移除而記下的刪除，是清理的中間態，
不是有人在編輯。擋下來的方向仍然正確（第二道防線本來就該保守），但讀報告時別據此推翻先前的殘留
判定、也別去追查「誰在寫」：先看目錄還在不在。並行 session 會同時清同一批，這是常態不是異常。

**🤖 過期時要講出來，不要靜默永久跳過。** 老標記仍然擋（fail-safe），但會印出年齡與
`wt config state marker clear` 指令——否則那棵樹會被早就死掉的 session 永久佔住。

**目錄被直接 `rm -rf` 掉的殘留註冊用 `git worktree prune --expire` 收。** 這種項目會被判「路徑已
不存在」而跳過，不另外處理就是另一個永久洩漏。`--expire` 讓正在被 `worktree move` 搬動的樹不會
被誤收。

**禁止刪掉目前視窗還開著的 worktree。** 對開著的 `*-wt` 做 remove 會留下空殼，Cursor 的
`move_agent_to_root` 會先對舊目錄 `git checkout --detach`，空殼必失敗。

## 刪遠端分支走 API，不要 `git push --delete`

後者會觸發本機 pre-push hook；lefthook 用「目前 checkout 分支 vs upstream」的 diff 判斷，跟這次
要刪的 ref 無關，會把整套測試拖下水甚至被無關失敗擋下。各 forge 的指令見 `forge-*.sh` 的
`forge_delete_remote_cmd`。
