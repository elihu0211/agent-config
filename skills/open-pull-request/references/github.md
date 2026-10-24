# GitHub

需要先 `gh auth login`。

## 開啟

```bash
gh pr create --title "<type(scope): 摘要>" --body-file body.md
```

`body.md` 含「摘要」（做什麼、為什麼）與「測試計畫」檢核表。

## auto-merge

```bash
gh pr merge <編號> --auto --squash --delete-branch
```

CI 尚未啟動時，等幾秒再重試一次。

## 查驗

```bash
gh pr view <編號> --json state,autoMergeRequest,mergeStateStatus
```

`autoMergeRequest: null` 代表 auto-merge **沒有**設定成功。已知兩種原因：repo 關閉了 auto-merge（`gh api repos/{owner}/{repo} --jq .allow_auto_merge`），或沒有必要的 checks——這時 `--auto` 會直接合併而不是排隊。不要假設指令成功，先查 repo 設定。

## 要能辨識的失敗

- 每個 job 都因帳號帳務或額度上限而無法啟動：這是帳號層級問題，與變更無關。說明後停止，不要反覆重試合併。
