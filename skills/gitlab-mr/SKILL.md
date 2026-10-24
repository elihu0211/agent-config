---
name: gitlab-mr
description: >-
  Open a GitLab merge request for the current branch with a conventional-commit
  title and summary, squash, remove-source-branch and auto-merge. Use when asked
  to open an MR, create a merge request or send for review in any GitLab repo.
---

# GitLab MR 建立技能

為目前 git 分支建立 GitLab Merge Request，套用 conventional commits 慣例，並設定 auto-merge。通用技能，不綁定特定 repo——在任何已 `glab auth login` 的 GitLab repo 目錄下皆可使用，`glab api` 呼叫一律用 `:id` 佔位符而非寫死 project path。

## 環境慣例

- **CLI**：`glab`（需已 `glab auth login`）
- **`glab api` 一律帶 `--hostname <gitlab-host>`**：不帶會預設打 `gitlab.com`，回來的 404／權限錯誤長得很像認證被別的 session 頂掉，其實是打錯站。自架 GitLab 尤其要注意。`glab auth status --hostname <host>` 可先確認登入身分
- **Conventional Commits**：`type(scope): 說明`，type = fix / feat / chore / refactor / docs / test / ci
- **MR 選項**：`--squash-before-merge --remove-source-branch`

### glab 認證隔離（每棵 worktree 一個 GLAB_CONFIG_DIR）

並行 session 共用全域 glab 設定，任一邊 `glab auth login` 會頂掉其他人的身分。每棵 `wt switch -c` 建的 worktree
已由 worktrunk hook 自動備好 `~/.config/glab-cli-worktrees/<branch-sanitized>/`（`<branch-sanitized>` ＝ 分支名
`/` 換 `-`），開 MR 前先 export，**絕對路徑、雙引號展開、先 `pwd` 確認不在容器根目錄**：

```bash
export GLAB_CONFIG_DIR="$HOME/.config/glab-cli-worktrees/<branch-sanitized>"
glab auth status --hostname gitlab.com
```

目錄不存在才手動 `mkdir -p`＋`cp "$HOME/.config/glab-cli/config.yml"` 補一份；不要自己跑 `glab auth login`。

⚠️ **在 shell 裡組 MR 描述、commit 訊息或要寫進檔案的 Markdown 時，heredoc 的結束字一律加引號**
（`<<'EOF'`），內文有反引號、`$` 時不加引號會被 shell 當成指令或變數展開——反引號包住的路徑會被
「執行」並替換成空字串（實測：表格的路徑欄變空，還 `permission denied`）。`--description "…"` 用雙引號
時同理，內文有反引號就改用單引號字串或先寫進檔案。

### 在 agent／背景 shell 內跑 `glab mr create` 會卡住（無 tty）

2026-10-22 實測（glab 1.124.0）：在 Claude Code 的 shell 裡跑 `glab mr create ... --yes`，`git push` 已完成、
遠端卻沒有 MR，指令停住超過兩分鐘不返回。同一組參數加 `</dev/null` 與逾時重跑則立刻回應，所以不是 API／網路問題。
根因**未證實**，推測是無 tty 下停在互動等待。這跟「MR 其實已建好」的那種卡住不同（見 memory
`feedback-glab-mr-create-can-hang-but-still-create-the-mr`）——**先列 MR 判斷是哪一種**。

在 agent 內一律：

```bash
GLAB_NO_PROMPT=1 perl -e 'alarm 60; exec @ARGV' glab mr create ... --yes </dev/null
```

（macOS 無 `timeout`，用 perl alarm；`NO_PROMPT` 已棄用，用 `GLAB_NO_PROMPT`。）逾時沒建出 MR 就改走 API，不要重試 `glab mr create`：

```bash
glab api --hostname gitlab.com -X POST "projects/:id/merge_requests" \
  -f source_branch=<branch> -f target_branch=main -f squash=true -f remove_source_branch=true \
  -f "title=<title>" -F "description=@<file.md>"
```

描述先寫進檔案再用 `-F description=@檔` 帶入，免得 shell 展開反引號。建好後照步驟 4 排 auto-merge。

### API 404 Project Not Found（必處理）

根因常見兩種，先辨識再選路徑：

1. **打錯站**：漏 `--hostname` → 補上正確 host 重試。
2. **身分只綁單一專案 bot**（例如 `project_<id>_bot_…`）：`glab auth status` 顯示 bot，但 `ssh -T git@gitlab.com` 是個人帳（如 `@your-username`）。Bot 的 Project Access Token **無法**跨專案呼叫 API（永遠 404／401），即使 SSH 能 push。

**根治（優先）**：用個人帳 OAuth／PAT 登入，不要用專案 bot 當預設 `gitlab.com` 身分：

```bash
glab auth login --hostname gitlab.com --web --git-protocol ssh
glab auth status --hostname gitlab.com   # 應顯示個人 username，不是 project_*_bot_*
glab api --hostname gitlab.com "projects/<group>%2F<project>"   # 應回 200，不是 404
```

CI／單一專案自動化仍可用專案 bot，但本機開發機的預設 `glab` **必須**是個人或 Group token，才能跨 repo 開 MR／auto-merge。

**當下繞路（SSH push options，API 仍掛時）**：

```bash
# 確認 git push 用的是個人 SSH（ssh -T git@gitlab.com → Welcome to GitLab, @you）
git push -u origin HEAD \
  -o merge_request.create \
  -o merge_request.target=main \
  -o merge_request.remove_source_branch \
  -o merge_request.squash \
  -o merge_request.title="<type(scope): 標題>" \
  -o merge_request.description="<單行描述；換行用 %0A>"

# 已有 MR 時排 auto-merge（同樣不需 API）
git push origin HEAD -o merge_request.merge_when_pipeline_succeeds
```

遠端會印 `View merge request for …` URL。`description` **不可含真實換行**（git 會拒），用 `%0A`。

**永久修好 API**（二選一，需人類在 GitLab UI 操作）：

- 用**個人或 Group Access Token**（scope: `api`）對 `gitlab.com` 跑 `glab auth login --hostname gitlab.com`，取代專案 bot；或
- 僅在該專案建 **Project Access Token**，以 `GITLAB_TOKEN=… glab -R <group/project> …` 單次覆寫（勿把 token 寫進 repo）。

專案 bot **不能**被加進其他專案當成員——換 token／改 login，不要空想「邀請 bot」。

## 工作流程

### 1. 確認目前分支、同步、與 diff

```bash
git branch --show-current
git fetch origin main
git rebase origin/main
git log origin/main..HEAD --oneline
git diff origin/main..HEAD --stat
```

⚠️ **Push 前必先對齊最新遠端（防止多發 Pipeline）**：在首次 `git push` 前，一律先跑 `git fetch origin main && git rebase origin/main`，確保本地分支已對齊最新遠端，杜絕開 MR 後才發現衝突需要二次 Force Push 而產生重複 Pipeline。用 `origin/main` 而非本機 `main` 當比對基準——本機 `main` 常常落後遠端（尤其是分支開好一段時間後），拿它當基準會讓 diff 統計失真、甚至漏算別人剛合併的內容。確認目前分支不是 `main`，且有 commit。

### 2. 從 diff 產生 MR 標題與 summary

**標題**：從 commit log 推斷，格式 `type(scope): 動詞 + 說明`（繁體中文 or 英文，與 commit 一致）。

⚠️ 需要 Draft MR 時，`--title` 字串本身**絕不手動加 `Draft: ` 前綴**——`glab mr create --draft`（或 `mr update --draft`）會自動加一次；標題裡再手動打一次會疊成 `Draft: Draft: ...`。前綴交給 `--draft` flag 全權處理。

**Summary**：
- 2–4 條 bullet 說明「做了什麼 + 為什麼」
- 若有安全考量（prune、delete、secret、CVE）加 Safety 段落
- Test plan：列出可驗證的 checklist（做過的打勾，CI 才能驗證的先列出來未勾）

### 3. 建立 MR

```bash
git push -u origin <current-branch>

glab mr create \
  --source-branch <current-branch> \
  --target-branch main \
  --squash-before-merge \
  --remove-source-branch \
  --title "<title>" \
  --description "<body>"
```

記下回傳的 MR IID（URL 末端數字）。

### 4. 設定 auto-merge

`glab mr merge --when-pipeline-succeeds`／`--auto-merge` 在這個環境下實測**一律**回傳 `405 Method Not Allowed`。直接呼叫 REST API，不要嘗試 `glab mr merge`：

⚠️ **2026-08-20 新變體：`glab mr merge` 不一定會回 405，有時會印出「ok merged !<IID>」這種看起來成功的訊息，但實際上只是把 `merge_when_pipeline_succeeds` 設成 `true`（排隊），MR 根本沒有真的合併**（實測：`glab mr merge <IID> --squash --remove-source-branch --yes`，pipeline 還在跑時）。這比 405 更危險——405 至少會讓人知道要往下查，這個假成功訊息會讓人誤以為已經合併，直接跳過步驟 4 的查詢驗證。**任何時候只要用了 `glab mr merge`（不管有沒有報錯），一律照步驟 4 的查詢重新確認 `state`/`merge_commit_sha`，不要相信 CLI 當下印出的文字。**

> ✅ **根因已查明並確認（2026-07-21，glab 1.108.0 實測復現）**：這是 [GitLab CLI 官方 issue #7243](https://gitlab.com/gitlab-org/cli/-/work_items/7243) 記錄的已知缺陷——`glab mr merge`（含 `--auto-merge`）在 MR **當下 pipeline 還沒跑完/還沒通過**時，內部邏輯會直接判定「現在不能合併」並回 405，即使語意上是要「等 pipeline 過了再合併」。剛開完 MR 就呼叫 `glab mr merge --auto-merge` 幾乎必定命中此路徑（pipeline 通常還在初始化）。
>
> 下面的 REST API 呼叫之所以能繞過：明確傳 `merge_when_pipeline_succeeds=true` 時，GitLab 把這解讀成「排入佇列，等 pipeline 過了自動合併」的非同步指令，不會走到 `glab mr merge` 那個「立即檢查能不能合併」的判斷分支。**這不是保守繞路，是唯一正確做法**，除非未來 glab 自己修掉 #7243（截至查證時尚未修復）。

```bash
glab api --hostname <gitlab-host> -X PUT "projects/:id/merge_requests/<IID>/merge" \
  -f auto_merge=true \
  -f squash=true \
  -f should_remove_source_branch=true \
  -f sha="$(git rev-parse HEAD)"
```

⚠️ **`sha` 必帶**，即使官方 API 文件把它標為 optional。實測（2026-08-05，GitLab 19.2.1-ee + glab 1.111.0）不帶 `sha` 一律回 `400 {"message":"SHA must be provided when merging"}`，`auto_merge` 與 `merge_when_pipeline_succeeds` 兩種寫法都一樣會被擋——這不是參數選錯，是這個 GitLab 版本的要求。帶了之後兩種寫法都成功排入佇列。若之後改回 `400 SHA must be provided`，先確認 `git rev-parse HEAD` 真的等於遠端來源分支的 HEAD（本機還沒 push 的 commit 會讓 sha 對不上，回 `409 Conflict`）。

⚠️ **`auto_merge` vs `merge_when_pipeline_succeeds`**：官方自 GitLab 17.11 起把 `merge_when_pipeline_succeeds` 標為 deprecated，改用 `auto_merge`。兩者在 19.2 實測都有效且效果相同（回應與查詢欄位仍是 `merge_when_pipeline_succeeds`——**查詢時仍讀這個欄位名**，只有送出的參數名改了）。新寫法用 `auto_merge`，舊實例（< 17.11）才退回 `merge_when_pipeline_succeeds`。

**驗證實際狀態**（這次呼叫回傳的 JSON 只是當下快照，pipeline 還在跑的話狀態會持續變化——一律用下面的查詢確認最終結果，不要憑呼叫當下回傳的內容就下結論）：
```bash
glab api --hostname <gitlab-host> "projects/:id/merge_requests/<IID>" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('state:', d['state'])
print('merge_when_pipeline_succeeds:', d['merge_when_pipeline_succeeds'])
print('detailed_merge_status:', d['detailed_merge_status'])
print('merge_commit_sha:', d.get('merge_commit_sha'))
"
```

- `state: merged` → 真的已經合併了（`merge_commit_sha` 會有值）
- `state: opened` + `merge_when_pipeline_succeeds: true` + `detailed_merge_status: ci_still_running` → 正確排入佇列，等 pipeline 跑完會自動合併
- `state: opened` + `merge_when_pipeline_succeeds: true` + `detailed_merge_status: approvals_syncing` → 剛排入佇列、簽核狀態還在同步的暫態，稍後會轉成 `ci_still_running`，不是異常
- 合併後的 commit：squash 合併沒有 merge commit，`merge_commit_sha` 是 null，要看 `squash_commit_sha`
- `state: opened` + `merge_when_pipeline_succeeds: false` → 沒有排上，常見原因：pipeline 剛失敗過、approval/discussion 未解決，或是**這個 MR 之後又被 push 了新 commit**（GitLab 每次新 push 都會重置這個旗標，見步驟 5）

若 pipeline failed，用 `glab api --hostname <gitlab-host> "projects/:id/pipelines/<pipeline_id>/jobs"` 找出實際失敗的 job 名稱印出來，不嘗試 merge，交由使用者決定。

⚠️ **pipeline 結構性永遠不會 success 時，`merge_when_pipeline_succeeds` 會永遠排隊等不到**（例：部分 job 的 `tags:` 指向一個不存在/連不到的 runner，job 永遠卡 pending → `runner_system_failure` → retry → 再卡 pending，pipeline 狀態長期停在 `running`，永遠不會轉成 `success`）。這種情況先查證是不是真的結構性卡住（用步驟查 job 明細，不要猜），確認後：
1. 先確認專案設定 `only_allow_merge_if_pipeline_succeeds` 是不是 `false`（`glab api --hostname <gitlab-host> "projects/:id"` 查）——是 `false` 才代表卡住的 pipeline 不會擋合併，只是需要它先進入「終結狀態」（success/failed/canceled 皆可，就是不能是 `running`）
2. 取消該 pipeline 讓它變成終結狀態：`glab api --hostname <gitlab-host> -X POST "projects/:id/pipelines/<pipeline_id>/cancel"`
3. 改呼叫**不帶** `auto_merge`/`merge_when_pipeline_succeeds` 的直接合併（立即合併，不是排隊）：
   ```bash
   glab api --hostname <gitlab-host> -X PUT "projects/:id/merge_requests/<IID>/merge" \
     -f squash=true \
     -f should_remove_source_branch=true \
     -f sha="$(git rev-parse HEAD)"
   ```
   pipeline 還在 `running` 時這個呼叫一樣會回 405（跟帶 auto_merge 那版是同一個「pipeline 執行中禁止合併」保護，與 `only_allow_merge_if_pipeline_succeeds` 專案設定是兩層不同機制），取消 pipeline 之後才會成功。

### 5. 若之後又 push 新 commit 到同一個 MR（防止多重 Pipeline 競爭）

⚠️ **重推前／重推後必 Cancel 舊 Pipeline**：GitLab 預設只會 auto-cancel `pending` 狀態的舊流水線，若舊 pipeline 已被 Runner 拾取進入 `running`（尤其專案預設為 `interruptible: false` 時），二次 push 會導致新舊兩條 pipeline 同時並行，搶奪共用 Runner Quota（造成 `runner_system_failure`）。

在二次 push 後，**一律主動取消該 MR 既有的舊 pipeline**（⚠️ **注意 Merged Results Pipeline 陷阱**：啟用 Merged Results Pipeline 時，`merge_request_event` pipeline 的 `p['sha']` 是 GitLab 預先與 `main` 合併的暫態 merge SHA，**不等於** `$(git rev-parse HEAD)`！若只拿 `p['sha'] != latest_sha` 判斷，會把剛建立的最新 `head_pipeline` 當成舊 pipeline 誤砍。因此必須同時排除 `mr['head_pipeline']['id']` 與列表第一筆最新 pipeline `pipes[0]['id']`）：
```bash
# 查出該 MR 所有舊且處於 running/pending 的 pipeline 並立即取消（保留最新 head_pipeline）
head_pipe_id=$(glab api --hostname <gitlab-host> "projects/:id/merge_requests/<IID>" \
  | python3 -c "import json, sys; d = json.load(sys.stdin); print((d.get('head_pipeline') or {}).get('id') or '')" 2>/dev/null)

old_pipes=$(glab api --hostname <gitlab-host> "projects/:id/merge_requests/<IID>/pipelines" \
  | python3 -c "
import json, sys
latest_sha, head_id = sys.argv[1], sys.argv[2]
pipes = json.load(sys.stdin)
keep_ids = {int(head_id)} if head_id.isdigit() else set()
if pipes:
    keep_ids.add(pipes[0]['id'])
for p in pipes:
    if p['id'] not in keep_ids and p.get('sha') != latest_sha and p.get('status') in ('running', 'pending'):
        print(p['id'])
" "$(git rev-parse HEAD)" "$head_pipe_id" 2>/dev/null)

for pid in $old_pipes; do
  echo "正在取消舊 pipeline #$pid ..."
  glab api --hostname <gitlab-host> -X POST "projects/:id/pipelines/$pid/cancel"
done
```

**重新綁定 auto-merge**：
auto-merge 旗標（`merge_when_pipeline_succeeds`）會被 GitLab 重置為 `false`，需要重新執行一次步驟 4 的 `glab api -X PUT .../merge ...`，否則新的 pipeline 跑完也不會自動合併。**重跑時 `sha` 要重新取**（`$(git rev-parse HEAD)` 已經是新 commit）——沿用舊 sha 會回 `409 Conflict`。

### 6. 回報

告知使用者 MR URL、pipeline 狀態、auto-merge 是否設定成功——用步驟 4 的驗證查詢結果回報（`state`/`merge_when_pipeline_succeeds`/`detailed_merge_status`），不要只轉述 `glab api -X PUT` 呼叫當下回傳的 JSON 就下結論。
