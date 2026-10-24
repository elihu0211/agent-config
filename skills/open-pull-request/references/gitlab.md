# GitLab

需要先 `glab auth login`。每個 `glab api` 都要帶 `--hostname <host>`：不帶會預設打 gitlab.com，回來的 404 看起來像認證失敗。用 `:id`，不要寫死專案路徑。

先確認身分：`glab auth status --hostname <host>`。只綁單一專案 bot 的 token，即使 SSH push 可用，也不能呼叫其他專案的 API（404／401）；請改用個人或群組 token 登入。

## 開啟

沒有 TTY 時 `glab mr create` 可能卡住。在 agent shell 裡一律這樣跑：

```bash
GLAB_NO_PROMPT=1 perl -e 'alarm 60; exec @ARGV' glab mr create \
  --source-branch <分支> --target-branch <預設分支> \
  --squash-before-merge --remove-source-branch \
  --title "<type(scope): 摘要>" --description "$(cat body.md)" --yes </dev/null
```

逾時就先列出 MR：MR 可能已經建好。沒有的話改用 API，不要重試指令：

```bash
glab api --hostname <host> -X POST "projects/:id/merge_requests" \
  -f source_branch=<分支> -f target_branch=<預設分支> -f squash=true \
  -f remove_source_branch=true -f "title=<標題>" -F "description=@body.md"
```

## auto-merge

用 API。`glab mr merge` 可能印出成功訊息卻只是排入佇列，或在 pipeline 還在啟動時回 405（上游 issue [#7243](https://gitlab.com/gitlab-org/cli/-/work_items/7243)）：

```bash
glab api --hostname <host> -X PUT "projects/:id/merge_requests/<iid>/merge" \
  -f auto_merge=true -f squash=true -f should_remove_source_branch=true \
  -f sha="$(git rev-parse HEAD)"
```

`sha` 必填，即使文件標為選填；沒 push 的本機 commit 會得到 409。17.11 之前的實例要用 `merge_when_pipeline_succeeds`，不是 `auto_merge`。

## 查驗

```bash
glab api --hostname <host> "projects/:id/merge_requests/<iid>" \
  | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["state"],d["merge_when_pipeline_succeeds"],d["detailed_merge_status"],d.get("squash_commit_sha"))'
```

- `merged`：完成（squash 合併沒有 merge commit，讀 `squash_commit_sha`）。
- `opened`、true、`ci_still_running` 或 `approvals_syncing`：已正確排入佇列。
- `opened`、false：沒有設定成功。原因：pipeline 失敗、討論串未解決，或較新的 push 重置了旗標。

## 對同一個 MR 再 push 之後

旗標會重置，仍在跑的舊 pipeline 也不會自動取消。用新的 `sha` 重新設定 auto-merge，並用 `POST projects/:id/pipelines/<id>/cancel` 取消過期的 pipeline。使用 merged-results pipeline 時，pipeline 的 `sha` 是暫時的 merge commit，絕不要拿來和 `HEAD` 比對；保留 `head_pipeline.id` 與最新的 pipeline，只取消其他的。

## 永遠不會成功的 pipeline

job 指向不存在的 runner 時，pipeline 會一直是 `running`，排隊中的 auto-merge 會永遠等下去。先讀 job 清單確認，檢查專案設定的 `only_allow_merge_if_pipeline_succeeds` 是 false，取消該 pipeline，再不帶 `auto_merge` 直接合併。

## push 選項（API 不可用時）

```bash
git push -u origin HEAD -o merge_request.create -o merge_request.target=<預設分支> \
  -o merge_request.remove_source_branch -o merge_request.squash \
  -o merge_request.title="<標題>" -o merge_request.description="第一行%0A第二行"
```

描述不能含真正的換行；用 `%0A`。
