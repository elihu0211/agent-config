#!/usr/bin/env bash
# 分支清理引擎的離線回歸測試（GitLab／GitHub 共用同一份判定）。用合成 repo 重現「曾經真的壞掉」的每一種情形。
# 不需要 glab／網路：MR 查詢經由 MR_QUERY 注入 stub。
#   bash test.sh
set -uo pipefail
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$LIB_DIR/audit.sh"
# pwd -P：macOS 的 /var/folders 是 /private/var/folders 的 symlink，git worktree
# list 回報解析後的實體路徑，測試若拿未解析的路徑比對會假性 FAIL。
TMP=$(cd "${KEEP_TMP:-$(mktemp -d)}" && pwd -P); [ -z "${KEEP_TMP:-}" ] && trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n     ↳ %s\n' "$1" "$2"; }

ORIGIN="$TMP/origin.git"; REPO="$TMP/repo"; FIX="$TMP/mrfix"; mkdir -p "$FIX"
git init -q --bare "$ORIGIN"
git init -q -b main "$REPO"
git -C "$REPO" config user.email t@example.com
git -C "$REPO" config user.name  tester
git -C "$REPO" remote add origin "$ORIGIN"

mkdir -p "$REPO/old"
python3 -c 'print("\n".join("line %d" % i for i in range(600)))' > "$REPO/old/data.yaml"
printf 'def keep():\n    return 1\n' > "$REPO/keep.py"
mkdir -p "$REPO/legacy"
python3 -c 'print("\n".join("legacy %d" % i for i in range(600)))' > "$REPO/legacy/doc.yaml"
git -C "$REPO" add -A && git -C "$REPO" commit -qm base
BASE=$(git -C "$REPO" rev-parse HEAD)
git -C "$REPO" push -q -u origin main

# --- 情形 1：分支含 rename，且 main 在分支開出去之後又前進過 -----------------
# 這正是舊技能誤判成「582 行純新增、內容沒進 main」的形狀。
git -C "$REPO" switch -qc feat/rename
mkdir -p "$REPO/new"
git -C "$REPO" mv old/data.yaml new/data.yaml
printf 'def keep():\n    return 2\n' > "$REPO/keep.py"
git -C "$REPO" commit -qam "rename + change"
git -C "$REPO" push -q -u origin feat/rename

git -C "$REPO" switch -q main
printf 'unrelated\n' > "$REPO/other.txt"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "main 前進，讓兩側基準不同"
M=$(git -C "$REPO" rev-parse HEAD)
# 複製 GitLab squash+merge 的形狀：squash commit 疊在 main tip 上，再產生
# 一個雙親 merge commit（parent1 = 合併前的 main）。
git -C "$REPO" merge -q --squash feat/rename
git -C "$REPO" commit -qm "squash: rename + change"
TREE=$(git -C "$REPO" rev-parse 'HEAD^{tree}')
MERGE=$(git -C "$REPO" commit-tree "$TREE" -p "$M" -p feat/rename -m "Merge branch 'feat/rename' into 'main'")
git -C "$REPO" reset -q --hard "$MERGE"
git -C "$REPO" push -q origin main
printf '[{"iid":101,"state":"merged","merge_commit_sha":"%s","title":"rename case"}]\n' "$MERGE" > "$FIX/feat-rename.json"

# --- 情形 2：分支內容根本沒進 main ------------------------------------------
git -C "$REPO" switch -q -c feat/unlanded main
printf 'never merged\n' > "$REPO/ghost.txt"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "沒進 main 的工作"
git -C "$REPO" push -q -u origin feat/unlanded
# MR 謊稱已合併，且給一個真的在 main 裡的 merge commit：祖先檢查會過，
# 只有逐檔內容比對擋得下來。
printf '[{"iid":102,"state":"merged","merge_commit_sha":"%s","title":"unlanded"}]\n' "$MERGE" > "$FIX/feat-unlanded.json"

# --- 情形 3：rename 只有一半進 main（新檔加了，舊檔沒刪）---------------------
# --no-renames 真正保護的是這個：預設 rename 偵測下，--name-only 只吐新路徑，
# 舊路徑根本不在檢查範圍，「刪除沒落地」就永遠看不見。
git -C "$REPO" switch -q -c feat/partial-rename main
mkdir -p "$REPO/modern"
git -C "$REPO" mv legacy/doc.yaml modern/doc.yaml
git -C "$REPO" commit -qm "把 legacy/doc.yaml 搬到 modern/"
git -C "$REPO" push -q -u origin feat/partial-rename

git -C "$REPO" switch -q main
M3=$(git -C "$REPO" rev-parse HEAD)
mkdir -p "$REPO/modern"
git -C "$REPO" show feat/partial-rename:modern/doc.yaml > "$REPO/modern/doc.yaml"
git -C "$REPO" add -A
git -C "$REPO" commit -qm "只加了新檔，舊檔沒刪（rename 只落地一半）"
TREE3=$(git -C "$REPO" rev-parse 'HEAD^{tree}')
MERGE3=$(git -C "$REPO" commit-tree "$TREE3" -p "$M3" -p feat/partial-rename \
         -m "Merge branch 'feat/partial-rename' into 'main'")
git -C "$REPO" reset -q --hard "$MERGE3"
git -C "$REPO" push -q origin main
printf '[{"iid":103,"state":"merged","merge_commit_sha":"%s","title":"partial rename"}]\n' "$MERGE3" \
  > "$FIX/feat-partial-rename.json"

# --- 情形 4：分支在 MR 合併後又 git merge main 同步過 -----------------------
# 分支的 diff-from-merge-base 因此含大量「別人早就合併進 main」的工作，A ⊄ B。
# 但那些檔案與現在的 main 逐位元組相同，刪分支不可能弄丟它們——沒有「與現在
# main 比對」這道收斂就會誤判成 NEEDS_HUMAN。
git -C "$REPO" switch -q -c feat/synced "$BASE"
printf 'synced work\n' > "$REPO/synced.txt"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "feat/synced 自己的工作"
git -C "$REPO" push -q -u origin feat/synced

git -C "$REPO" switch -q main
M4=$(git -C "$REPO" rev-parse HEAD)
git -C "$REPO" merge -q --squash feat/synced
git -C "$REPO" commit -qm "squash: feat/synced"
TREE4=$(git -C "$REPO" rev-parse 'HEAD^{tree}')
MERGE4=$(git -C "$REPO" commit-tree "$TREE4" -p "$M4" -p feat/synced \
         -m "Merge branch 'feat/synced' into 'main'")
git -C "$REPO" reset -q --hard "$MERGE4"
git -C "$REPO" push -q origin main
printf '[{"iid":104,"state":"merged","merge_commit_sha":"%s","title":"synced"}]\n' "$MERGE4" \
  > "$FIX/feat-synced.json"

# 合併後 main 又前進（別人的 MR 陸續進來）
printf 'later work by others\n' > "$REPO/later.txt"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "合併之後別人又進了東西"
git -C "$REPO" push -q origin main

# 該分支的 session 這時才把 main 併回自己的樹（很常見的同步動作）。分支的
# diff-from-merge-base 因此含 later.txt——它不在自己那次 squash 的 diff 裡，
# 但與現在的 main 逐位元組相同。
git -C "$REPO" switch -q feat/synced
git -C "$REPO" merge -q main -m "sync with main"

# --- 情形 5：分支合併後被同步成 main 上較早的一顆 commit ---------------------
# 實地形狀（2026-09-06）：分支 tip 的訊息是 "Merge branch '<別支>' into 'main'"——它早
# 被快轉/重置到當時的 main，之後 main 又繼續前進。分支的 diff-from-merge-base 因此涵蓋
# 期間別人的工作，而那些檔案 main 後來又改過，「與現在 main 逐位元組相同」整批失效，
# 22 個檔案一起誤報 NEEDS_HUMAN。tip 落在 first-parent 主線上就該直接放行。
git -C "$REPO" switch -qc feat/ff-to-main "$BASE"
printf 'ff work\n' > "$REPO/ff.txt"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "feat/ff-to-main 自己的工作"
git -C "$REPO" push -q -u origin feat/ff-to-main

git -C "$REPO" switch -q main
M5=$(git -C "$REPO" rev-parse HEAD)
git -C "$REPO" merge -q --squash feat/ff-to-main
git -C "$REPO" commit -qm "squash: feat/ff-to-main"
S5=$(git -C "$REPO" rev-parse HEAD)
# 真實 GitLab squash+merge：parent1=合併前的 main，parent2=squash commit（**不是**原
# 分支 tip）。原分支的 commit 因此完全不在 main 歷史裡——這正是實地 squash 分支
# 「tip 不是 main 祖先」的來源，用 -p <branch> 造出來的形狀測不到它。
MERGE5=$(git -C "$REPO" commit-tree "$S5^{tree}" -p "$M5" -p "$S5" \
         -m "Merge branch 'feat/ff-to-main' into 'main'")
git -C "$REPO" reset -q --hard "$MERGE5"
printf '[{"iid":105,"state":"merged","merge_commit_sha":"%s","title":"ff to main"}]\n' "$MERGE5" \
  > "$FIX/feat-ff-to-main.json"
# 合併之後別人又進了東西
printf 'other work\n' > "$REPO/other5.txt"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "合併後別人的工作"
git -C "$REPO" push -q origin main
# 該分支被同步成「當時的」main
git -C "$REPO" branch -qf feat/ff-to-main main
# main 再前進，並改掉上面那個檔案：分支不再與現在的 main 相同，第一道濾網失效
printf 'other work v2\n' > "$REPO/other5.txt"
git -C "$REPO" commit -qam "別人後來又改了 other5.txt"
git -C "$REPO" push -q origin main

# --- 情形 6：分支疊在另一支先合併的分支上（squash，tip 不在 main 歷史內）-----
# feat/upper 基於 feat/lower；lower 先 squash 進 main，upper 再 squash 進 main。upper 的
# diff-from-merge-base 因此含 lower 的工作（A ⊄ B），而 lower 碰的檔案 main 後來又改過，
# 第一道濾網同樣失效。此時 tip 不在 main 歷史內，判準 1 救不了，只有「那次合併當下有
# 沒有帶進去」問得出正確答案。
git -C "$REPO" switch -qc feat/lower "$BASE"
printf 'lower work\n' > "$REPO/lower.txt"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "feat/lower 的工作"
git -C "$REPO" switch -qc feat/upper
printf 'upper work\n' > "$REPO/upper.txt"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "feat/upper 疊在 lower 上的工作"
git -C "$REPO" push -q -u origin feat/lower feat/upper

git -C "$REPO" switch -q main
ML=$(git -C "$REPO" rev-parse HEAD)
git -C "$REPO" merge -q --squash feat/lower
git -C "$REPO" commit -qm "squash: feat/lower"
SL=$(git -C "$REPO" rev-parse HEAD)
MERGEL=$(git -C "$REPO" commit-tree "$SL^{tree}" -p "$ML" -p "$SL" \
         -m "Merge branch 'feat/lower' into 'main'")
git -C "$REPO" reset -q --hard "$MERGEL"
MU=$(git -C "$REPO" rev-parse HEAD)
git -C "$REPO" merge -q --squash feat/upper
git -C "$REPO" commit -qm "squash: feat/upper"
SU=$(git -C "$REPO" rev-parse HEAD)
MERGEU=$(git -C "$REPO" commit-tree "$SU^{tree}" -p "$MU" -p "$SU" \
         -m "Merge branch 'feat/upper' into 'main'")
git -C "$REPO" reset -q --hard "$MERGEU"
git -C "$REPO" push -q origin main
printf '[{"iid":106,"state":"merged","merge_commit_sha":"%s","title":"lower"}]\n' "$MERGEL" \
  > "$FIX/feat-lower.json"
printf '[{"iid":107,"state":"merged","merge_commit_sha":"%s","title":"upper"}]\n' "$MERGEU" \
  > "$FIX/feat-upper.json"

# --- 情形 7：情形 6 的對照——合併當下就沒帶進去，必須仍判 NEEDS_HUMAN -------
# 與情形 6 同形狀，差別只在多一行從頭到尾沒進過 main。放行條件若不檢查「新增行在
# 合併當下是否已存在」，這條就會跟著變綠，把真落差一起吃掉。
git -C "$REPO" switch -qc feat/upper-lost feat/upper
printf 'never landed anywhere\n' > "$REPO/lost.txt"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "feat/upper-lost 沒被帶進去的工作"
git -C "$REPO" push -q -u origin feat/upper-lost
printf '[{"iid":108,"state":"merged","merge_commit_sha":"%s","title":"upper-lost"}]\n' "$MERGEU" \
  > "$FIX/feat-upper-lost.json"

# main 之後又改掉 lower.txt，廢掉 upper／upper-lost 的第一道濾網
git -C "$REPO" switch -q main
printf 'lower work v2\n' > "$REPO/lower.txt"
git -C "$REPO" commit -qam "別人後來又改了 lower.txt"
git -C "$REPO" push -q origin main

git -C "$REPO" push -q origin --delete feat/rename feat/unlanded feat/partial-rename feat/synced \
  feat/ff-to-main feat/lower feat/upper feat/upper-lost
git -C "$REPO" fetch -q --prune origin

cat > "$TMP/mrstub.sh" <<'STUB'
#!/usr/bin/env bash
f="$MR_FIXTURE/${2//\//-}.json"
[ -f "$f" ] && cat "$f" || printf '[]\n'
STUB
chmod +x "$TMP/mrstub.sh"

run_audit() {
  rm -rf "$TMP/out"; mkdir -p "$TMP/out"
  MR_FIXTURE="$FIX" MR_QUERY="$TMP/mrstub.sh" ACTIVE_WINDOW_SECS=0 \
    bash "$AUDIT" "$REPO" "$TMP/out" >"$TMP/audit.log" 2>&1
}
verdict() { awk -F'\t' -v b="$1" '$1==b{print $3}' "$TMP/out/verdict.tsv"; }

printf '\n判定邏輯\n'
run_audit
V=$(verdict feat/rename)
[ "$V" = SAFE ] && ok "含 rename 的 squash-merged 分支判為 SAFE" \
  || bad "含 rename 的 squash-merged 分支應為 SAFE" "實得 '${V:-空}'（舊技能在此誤判）"
V=$(verdict feat/unlanded)
[ "$V" = NEEDS_HUMAN ] && ok "內容沒進 main 的分支判為 NEEDS_HUMAN" \
  || bad "內容沒進 main 的分支應為 NEEDS_HUMAN" "實得 '${V:-空}'"
V=$(verdict feat/partial-rename)
[ "$V" = NEEDS_HUMAN ] && ok "rename 只落地一半（舊檔未刪）判為 NEEDS_HUMAN" \
  || bad "rename 只落地一半應為 NEEDS_HUMAN" "實得 '${V:-空}'（沒有 --no-renames 就看不見舊路徑）"
V=$(verdict feat/synced)
[ "$V" = SAFE ] && ok "合併後又同步過 main 的分支仍判為 SAFE" \
  || bad "同步過 main 的分支應為 SAFE" "實得 '${V:-空}'（缺少「與現在 main 比對」的收斂就會誤判）"
V=$(verdict feat/ff-to-main)
[ "$V" = SAFE ] && ok "分支 tip 已同步成 main 的一顆 commit → SAFE" \
  || bad "tip 在 main 歷史內應為 SAFE" "實得 '${V:-空}'（diff 範圍涵蓋別人的工作，濾網被後續 commit 廢掉）"
V=$(verdict feat/upper)
[ "$V" = SAFE ] && ok "疊在先合併分支上的 squash 分支 → SAFE" \
  || bad "疊層 squash 分支應為 SAFE" "實得 '${V:-空}'（下層工作已在合併當下進 main）"
V=$(verdict feat/upper-lost)
[ "$V" = NEEDS_HUMAN ] && ok "疊層形狀下、合併當下就沒帶進去的工作仍判 NEEDS_HUMAN" \
  || bad "真落差應為 NEEDS_HUMAN" "實得 '${V:-空}'（放行條件放太寬會吃掉真落差）"
grep -q 'del_branch feat/rename' "$TMP/out/plan.sh" \
  && ok "plan 只對 SAFE 分支產生刪除指令" || bad "plan 應含 feat/rename" "$(grep -c . "$TMP/out/plan.sh") 行"
grep -q 'del_branch feat/unlanded' "$TMP/out/plan.sh" \
  && bad "plan 不該含 feat/unlanded" "出現了刪除指令" || ok "NEEDS_HUMAN 分支不進 plan"

printf '\n執行期守衛（稽核後環境才改變）\n'
run_audit
git -C "$REPO" switch -q feat/rename
printf 'work after audit\n' > "$REPO/late.txt"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "稽核之後才長出來的工作"
git -C "$REPO" switch -q main
OUT=$(bash "$TMP/out/plan.sh" 2>&1)
grep -q 'SKIP feat/rename：tip 已從' <<<"$OUT" \
  && ok "分支 tip 在稽核後移動 → SKIP" || bad "tip 移動應 SKIP" "$(head -3 <<<"$OUT")"
git -C "$REPO" show-ref -q --verify refs/heads/feat/rename \
  && ok "被 SKIP 的分支確實沒被刪掉" || bad "分支被誤刪" "refs/heads/feat/rename 不見了"

printf '\n執行期守衛：worktree 在稽核後才變髒\n'
git -C "$REPO" branch -qf feat/rename "$(git -C "$REPO" rev-parse feat/rename~1)"
WT="$TMP/wt-rename"
git -C "$REPO" worktree add -q "$WT" feat/rename
run_audit
grep -q "remove_wt $WT" "$TMP/out/plan.sh" || bad "前置：乾淨 worktree 應進 plan" "plan 未含 $WT"
printf 'uncommitted\n' > "$WT/dirty.txt"
OUT=$(bash "$TMP/out/plan.sh" 2>&1)
grep -q "SKIP worktree ${WT}：有 1 個未提交變更" <<<"$OUT" \
  && ok "worktree 在稽核後變髒 → SKIP" || bad "變髒應 SKIP" "$(head -3 <<<"$OUT")"
[ -f "$WT/dirty.txt" ] && ok "未提交檔案沒被毀掉" || bad "未提交檔案不見了" "$WT/dirty.txt"

printf '\n佔用判定不得複製成兩份\n'
grep -q 'wt_busy()' "$TMP/out/plan.sh" \
  && bad "plan.sh 自己又定義了 wt_busy" "判定複製成兩份，修一邊不會傳染到另一邊" \
  || ok "plan.sh 不自帶 wt_busy"
grep -q '^\. .*occupancy\.sh$' "$TMP/out/plan.sh" \
  && ok "plan.sh source 共用的 occupancy.sh" || bad "plan.sh 應 source occupancy.sh" "$(grep -c . "$TMP/out/plan.sh") 行"

printf '\nwt 標記 🤖 會擋下移除\n'
if command -v wt >/dev/null 2>&1; then
  # 先清掉上一個測試留下的髒檔，否則 wt_busy 會在髒檔那關就短路，測不到標記。
  rm -f "$WT/dirty.txt"
  wt config state marker set 🤖 --branch feat/rename -C "$REPO" >/dev/null 2>&1 \
    || wt config state marker set 🤖 -C "$WT" >/dev/null 2>&1
  R=$(REPO="$REPO" ACTIVE_WINDOW_SECS=0 bash -c '. "'"$LIB_DIR"'/occupancy.sh"; wt_busy "'"$WT"'" || true')
  case "$R" in *🤖*) ok "🤖 標記擋下移除（訊息：${R:0:40}…）";;
                 *) bad "🤖 標記應擋下移除" "實得 '${R:-無}'";; esac
  sleep 2
  R=$(REPO="$REPO" ACTIVE_WINDOW_SECS=0 STALE_MARKER_SECS=1 bash -c '. "'"$LIB_DIR"'/occupancy.sh"; wt_busy "'"$WT"'" || echo FREE')
  case "$R" in FREE) ok "超過殘留門檻的 🤖 不再擋（自動視為死 session）";;
               *) bad "過期 🤖 應放行" "實得 '${R:-無}'";; esac
  wt config state marker clear --branch feat/rename -C "$REPO" >/dev/null 2>&1
else
  printf '  SKIP  未安裝 wt，略過標記測試\n'
fi

printf '\nremove_wt 走 wt remove（post-remove hook 才會觸發）\n'
# 直接 git worktree remove 會繞過 wt 的 post-remove hook（本機用它清該分支的 GLAB_CONFIG_DIR），
# 每移除一棵樹就留一份沒人收的殘渣。stub 只記錄呼叫並移除工作樹。
rm -f "$WT/dirty.txt"
run_audit
# 這兩個測試會讓 plan 真的把 feat/rename 刪掉，後面的測試還要用它：還原成「upstream gone 的同一顆 tip」。
RENAME_TIP=$(git -C "$REPO" rev-parse feat/rename)
restore_rename() {
  git -C "$REPO" branch -q feat/rename "$RENAME_TIP"
  git -C "$REPO" config branch.feat/rename.remote origin
  git -C "$REPO" config branch.feat/rename.merge refs/heads/feat/rename
}
BIN="$TMP/bin"; WTLOG="$TMP/wt-calls.log"; mkdir -p "$BIN"; : >"$WTLOG"
cat >"$BIN/wt" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$WTLOG"
git -C "$REPO" worktree remove "\${@: -1}"
STUB
chmod +x "$BIN/wt"
BASH_BIN=$(command -v bash)
PATH="$BIN:$PATH" "$BASH_BIN" "$TMP/out/plan.sh" >"$TMP/plan-run.log" 2>&1
if grep -q -- '--foreground' "$WTLOG" && grep -q -- '--no-delete-branch' "$WTLOG" && grep -q -- "$WT\$" "$WTLOG"; then
  ok "有 wt 時經 wt remove（--foreground、--no-delete-branch）移除"
else
  bad "有 wt 時應經 wt remove" "wt 收到：$(cat "$WTLOG") ／ plan 輸出：$(head -3 "$TMP/plan-run.log")"
fi
[ ! -d "$WT" ] && ok "worktree 確實移除" || bad "worktree 沒被移除" "$WT 還在"
git -C "$REPO" show-ref -q --verify refs/heads/feat/rename \
  && bad "分支應由 del_branch 刪" "refs/heads/feat/rename 還在" || ok "分支仍只由 del_branch（tip 守衛）刪除"

printf '\n沒有 wt 時退回 git worktree remove\n'
restore_rename
WT2="$TMP/wt-fallback"
git -C "$REPO" worktree add -q "$WT2" feat/rename
run_audit
: >"$WTLOG"
PATH="/usr/bin:/bin:/usr/sbin:/sbin" "$BASH_BIN" "$TMP/out/plan.sh" >"$TMP/plan-run.log" 2>&1
[ ! -d "$WT2" ] && [ ! -s "$WTLOG" ] && ok "沒有 wt 時用 git 原生移除，且沒呼叫 wt" \
  || bad "沒有 wt 時應退回 git worktree remove" "樹還在=$([ -d "$WT2" ] && echo 是 || echo 否) wt 呼叫=$(cat "$WTLOG") ／ $(head -3 "$TMP/plan-run.log")"
restore_rename

printf '\n目錄被直接砍掉的殘留註冊\n'
GHOST="$TMP/wt-ghost"
git -C "$REPO" worktree add -q "$GHOST" -b tmp/ghost main
rm -rf "$GHOST"            # 模擬別的 session 直接 rm -rf，沒走 worktree remove
run_audit
grep -q 'worktree prune --expire' "$TMP/out/plan.sh" \
  && ok "殘留註冊產生 git worktree prune" \
  || bad "應產生 worktree prune" "plan 未含 prune（殘留註冊會永遠清不掉）"
git -C "$REPO" worktree prune 2>/dev/null; git -C "$REPO" branch -qD tmp/ghost 2>/dev/null

printf '\n保護分支\n'
grep -qE '^(main|master)$' "$TMP/out/candidates.txt" \
  && bad "保護分支不該進候選" "$(cat "$TMP/out/candidates.txt")" || ok "main 不在候選清單"

printf '\nGitHub adapter 正規化\n'
mkdir -p "$TMP/fakebin"
cat > "$TMP/fakebin/gh" <<'FAKE'
#!/usr/bin/env bash
# 只回 pr list 的固定樣本；squash-merge 的 PR mergeCommit 是單親 squash commit。
cat <<'J'
[{"number":77,"state":"MERGED","mergeCommit":{"oid":"abc123def456"},"title":"squash 過的 PR"},
 {"number":78,"state":"CLOSED","mergeCommit":null,"title":"關掉沒合併"}]
J
FAKE
chmod +x "$TMP/fakebin/gh"
NORM=$(PATH="$TMP/fakebin:$PATH" bash -c '. "'"$LIB_DIR"'/forge-github.sh"; forge_mr_query "'"$REPO"'" any/branch')
python3 - "$NORM" <<'PY' && ok "gh 的 PR JSON 正規化成引擎要的形狀" || bad "GitHub adapter 正規化錯誤" "$NORM"
import json,sys
d=json.loads(sys.argv[1])
assert d[0]["iid"]==77 and d[0]["state"]=="merged" and d[0]["merge_commit_sha"]=="abc123def456", d
assert d[1]["state"]=="closed" and d[1]["merge_commit_sha"] is None, d
PY

printf '\nGitLab adapter 正規化\n'
# squash 合併的 MR：merge_commit_sha 是 null，落地 commit 在 squash_commit_sha。
cat > "$TMP/fakebin/glab" <<'FAKE'
#!/usr/bin/env bash
cat <<'J'
[{"iid":301,"state":"merged","merge_commit_sha":null,"squash_commit_sha":"sq123abc","title":"squash 合併"},
 {"iid":302,"state":"merged","merge_commit_sha":"mg456def","squash_commit_sha":null,"title":"merge commit 合併"},
 {"iid":303,"state":"closed","merge_commit_sha":null,"squash_commit_sha":null,"title":"關掉沒合併"}]
J
FAKE
chmod +x "$TMP/fakebin/glab"
GNORM=$(PATH="$TMP/fakebin:$PATH" bash -c '. "'"$LIB_DIR"'/forge-gitlab.sh"; urlenc() { printf %s "$1"; }; forge_mr_query "'"$REPO"'" any/branch')
python3 - "$GNORM" <<'PY' && ok "squash 合併的 squash_commit_sha 補進 merge_commit_sha" || bad "GitLab adapter 未補 squash_commit_sha" "$GNORM"
import json,sys
d=json.loads(sys.argv[1])
assert d[0]["merge_commit_sha"]=="sq123abc", d
assert d[1]["merge_commit_sha"]=="mg456def", d
assert d[2]["merge_commit_sha"] is None, d
PY
printf '{not json' > "$TMP/fakebin/glab.out"
cat > "$TMP/fakebin/glab" <<'FAKE'
#!/usr/bin/env bash
printf '404 Not Found'
FAKE
GERR=$(PATH="$TMP/fakebin:$PATH" bash -c '. "'"$LIB_DIR"'/forge-gitlab.sh"; urlenc() { printf %s "$1"; }; forge_mr_query "'"$REPO"'" any/branch')
[ "$GERR" = "404 Not Found" ] && ok "glab 報錯的非 JSON 輸出原樣放行" || bad "非 JSON 輸出被改動" "$GERR"

printf '\nforge 自動偵測 + GitHub adapter 端到端\n'
# origin 換成路徑含 github.com 的本地 bare repo：偵測條件成立，fetch 也還能動，
# 不必為了測偵測而把判斷邏輯抄一份出來測抄本。
mkdir -p "$TMP/github.com/x"
git init -q --bare "$TMP/github.com/x/y.git"
git -C "$REPO" push -q "$TMP/github.com/x/y.git" main:main
git -C "$REPO" remote set-url origin "$TMP/github.com/x/y.git"
git -C "$REPO" fetch -q --prune origin
cat > "$TMP/fakebin/gh" <<FAKE
#!/usr/bin/env bash
cat <<J
[{"number":204,"state":"MERGED","mergeCommit":{"oid":"$MERGE4"},"title":"synced via gh"}]
J
FAKE
chmod +x "$TMP/fakebin/gh"
rm -rf "$TMP/out"; mkdir -p "$TMP/out"
PATH="$TMP/fakebin:$PATH" ACTIVE_WINDOW_SECS=0 \
  bash "$AUDIT" "$REPO" "$TMP/out" >"$TMP/gh.log" 2>&1
grep -q '^== forge: github$' "$TMP/gh.log" \
  && ok "origin 在 github.com 上時自動選 github adapter" \
  || bad "forge 偵測應為 github" "$(grep '^== forge' "$TMP/gh.log")"
# 斷言 gh 的 mergeCommit.oid 真的流進引擎並被拿去算判定（未覆寫 MR_QUERY）。
GOT=$(awk -F'\t' '$1=="feat/rename"{print $4"|"$3}' "$TMP/out/verdict.tsv")
[ "$GOT" = "$MERGE4|SAFE" ] && ok "gh 的 mergeCommit.oid 流進引擎並算出判定" \
  || bad "gh adapter 端到端結果不符" "預期 '$MERGE4|SAFE'，實得 '${GOT:-空}'"
git -C "$REPO" remote set-url origin "$ORIGIN"

printf '\n合計：%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
