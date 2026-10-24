# GitLab adapter。契約：forge_mr_query <repo> <branch> 印出正規化 JSON 陣列，
# 每筆含 iid / state（小寫）/ merge_commit_sha / title。
#
# 用 source_branch 直查單一分支，不用 `glab mr list --merged`：後者的 --per-page
# 有上限，打滿時漏掉更早的 MR，拿它做交集比對會漏刪也會誤判。
#
# 正規化：GitLab 的 squash 合併（含 auto-merge）不產生 merge commit，merge_commit_sha 是 null，
# 落地的 commit 在 squash_commit_sha。兩者都是「合併前 main 的單親 commit」之後的那一顆，
# 引擎用 SHA^1..SHA 取這次合併帶進 main 的變更，對兩種都成立（見 TRAPS.md）。不補這一步，
# 每一支 squash 合併的分支都會被判成 NEEDS_HUMAN「無 merge_commit_sha」。
# 解析失敗（glab 報錯、非 JSON）原樣放行，讓引擎走既有的 PARSE_FAIL 路徑。
forge_mr_query() {
  ( cd "$1" && glab api "projects/:id/merge_requests?source_branch=$(urlenc "$2")&state=all&per_page=20" ) \
    | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception:
    sys.stdout.write(raw); raise SystemExit
if isinstance(d, list):
    for m in d:
        if isinstance(m, dict):
            m["merge_commit_sha"] = m.get("merge_commit_sha") or m.get("squash_commit_sha")
print(json.dumps(d))
'
}

# 刪遠端分支走 API，不要 `git push --delete`：後者會觸發本機 pre-push hook，
# lefthook 用「目前 checkout 分支 vs upstream」的 diff 判斷，跟這次要刪的 ref 無關，
# 會把整套測試拖下水甚至被無關失敗擋下。
forge_delete_remote_cmd() { printf 'glab api "projects/:id/repository/branches/%s" --method DELETE\n' "$1"; }
