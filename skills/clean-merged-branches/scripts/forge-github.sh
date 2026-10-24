# GitHub adapter。契約同 forge-gitlab.sh。
#
# GitHub 的 mergeCommit 對 squash-merge 的 PR 是 main 上那顆單親 squash commit，
# GitLab 則是雙親 merge commit——兩者的 SHA^1 都等於「合併前的 main」，所以
# 引擎用 diff(SHA^1, SHA) 取「這次合併帶進來的變更」對兩邊都成立。
forge_mr_query() {
  ( cd "$1" && gh pr list --head "$2" --state all --limit 100 \
       --json number,state,mergeCommit,title ) 2>/dev/null | python3 -c '
import json, sys
try: prs = json.load(sys.stdin)
except Exception: prs = []
out = []
for p in prs if isinstance(prs, list) else []:
    out.append({"iid": p.get("number"),
                "state": (p.get("state") or "").lower(),
                "merge_commit_sha": (p.get("mergeCommit") or {}).get("oid"),
                "title": p.get("title") or ""})
print(json.dumps(out, ensure_ascii=False))'
}

# 同樣走 API 而非 git push --delete，理由見 forge-gitlab.sh。
forge_delete_remote_cmd() {
  printf 'gh api -X DELETE "repos/{owner}/{repo}/git/refs/heads/%s"\n' "$1"
}
