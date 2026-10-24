#!/usr/bin/env bash
# 分支清理稽核（唯讀）。不刪除任何東西。GitLab／GitHub 共用同一份判定，
# forge 差異只在 forge-*.sh adapter。
#
# 輸出：
#   stdout          逐分支判定 + 每棵 worktree 的佔用訊號
#   $OUTDIR/plan.sh 通過驗證者的刪除指令，需人工檢視後自行執行
#
# 用 bash 執行、不依賴呼叫端互動 shell，是刻意的：本腳本的結論曾被 zsh 的 echo
# 展開跳脫序列、以及使用者把 diff 別名成 delta 這兩件事悄悄污染。內部一律
# printf / cmp / comm，JSON 一律寫檔再解析。
#
# 用法：audit.sh [REPO_PATH] [OUTDIR]
#   ACTIVE_WINDOW_SECS  worktree reflog 多新算「最近有人在動」（預設 1800）
#   FORGE               gitlab|github（預設從 origin URL 自動認）
set -uo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=occupancy.sh
. "$LIB_DIR/occupancy.sh"
urlenc() { python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }

REPO="$(git -C "${1:-$PWD}" rev-parse --show-toplevel 2>/dev/null)" || {
  printf '不是 git repo: %s\n' "${1:-$PWD}" >&2; exit 1; }
OUTDIR="${2:-$(mktemp -d)}"
ACTIVE_WINDOW_SECS="${ACTIVE_WINDOW_SECS:-1800}"
mkdir -p "$OUTDIR/mr"
NOW=$(date +%s)
PROTECTED_RE='^(main|master|develop|staging|release)$'

# forge 差異只有「怎麼查 MR/PR」這一處，收在 adapter 裡；判定邏輯兩邊共用同一份。
# FORGE 未指定就從 origin URL 認，少一個要人記得帶的旗標。
if [ -z "${FORGE:-}" ]; then
  case "$(git -C "$REPO" remote get-url origin 2>/dev/null)" in
    *github.com*) FORGE=github ;;
    *)            FORGE=gitlab ;;
  esac
fi
[ -f "$LIB_DIR/forge-$FORGE.sh" ] || { printf '未知的 forge: %s\n' "$FORGE" >&2; exit 1; }
# shellcheck source=/dev/null
. "$LIB_DIR/forge-$FORGE.sh"
# MR_QUERY 可覆寫成 stub 供離線測試（test.sh 用）。
MR_QUERY="${MR_QUERY:-forge_mr_query}"

printf '== repo: %s\n== forge: %s\n== outdir: %s\n\n' "$REPO" "$FORGE" "$OUTDIR"

# ---- 1. 同步遠端 ---------------------------------------------------------
# 裸 git，不走 rtk：rtk 改寫輸出，且曾對 fetch 靜默 rebase + force-push。
git -C "$REPO" fetch --prune origin >/dev/null 2>&1 || { printf 'fetch 失敗，中止\n' >&2; exit 1; }

# ---- 2. 候選分支：本機還在、upstream 已 gone -----------------------------
# `*`/`+` 與分支名是獨立的 awk 欄位，名稱在 $2。對 $1 做 sed 去前綴會讓名稱
# 整個消失（目前分支與被 worktree checkout 的分支都會中招）。
git -C "$REPO" branch -vv | grep ': gone]' \
  | awk '{ if ($1 == "*" || $1 == "+") print $2; else print $1 }' \
  | grep -Ev "$PROTECTED_RE" > "$OUTDIR/candidates.txt"
TOTAL=$(wc -l < "$OUTDIR/candidates.txt" | tr -d ' ')
printf '候選分支（upstream gone，已排除保護分支）：%s 支\n\n' "$TOTAL"
[ "$TOTAL" -eq 0 ] && { printf '無事可做。\n'; exit 0; }

# 分支自己 touch 的檔案。--no-renames 是關鍵：預設 rename 偵測讓 --name-only
# 只吐新路徑，舊路徑被排除在後續 pathspec 外，限定範圍的 diff 因此失去 rename
# 配對，整個檔案變成「純新增」而誤判為內容不符。
branch_files() { git -C "$REPO" diff -z --name-only --no-renames "$1" "$2"; }

# 把 diff 正規化成增刪行集合。不用 patch-id：它連 context 行一起雜湊，分支基準
# 與 squash 基準不同（別的 MR 先進 main）就必然不同——對 squash 工作流是系統性
# 假警報，而非真的內容落差。
normdiff() { grep -E '^[+-]' | grep -Ev '^(\+\+\+|---)' | LC_ALL=C sort; }

: > "$OUTDIR/verdict.tsv"
while IFS= read -r B; do
  [ -z "$B" ] && continue
  SAFE="${B//\//-}"
  # MR 查詢抽成可注入的一層，唯一目的是讓判定邏輯能離線回歸測試（test.sh 用
  # stub 餵固定 JSON）。沒有這層，rename／子集比對那幾條修好的判準沒有任何東西
  # 證明它們不會再壞。
  "$MR_QUERY" "$REPO" "$B" > "$OUTDIR/mr/$SAFE.json" 2>"$OUTDIR/mr/$SAFE.err"
  # 用 source_branch 直查，不用 `glab mr list --merged`：後者受 --per-page 上限
  # 影響，打滿時會漏掉更早的 MR，拿它做交集比對會漏刪也會誤判。
  read -r IID STATE SHA <<<"$(python3 - "$OUTDIR/mr/$SAFE.json" <<'PY'
import json,sys
try: mrs = json.load(open(sys.argv[1]))
except Exception: print("- PARSE_FAIL -"); raise SystemExit
if not isinstance(mrs, list) or not mrs: print("- NO_MR -"); raise SystemExit
merged = [m for m in mrs if m.get("state") == "merged" and m.get("merge_commit_sha")]
m = max(merged or mrs, key=lambda x: x["iid"])
print("%s %s %s" % (m["iid"], m["state"], m.get("merge_commit_sha") or "-"))
PY
)"

  TIP=$(git -C "$REPO" rev-parse --verify --quiet "refs/heads/$B")
  # 分支 tip 落在 origin/main 的 first-parent 主線上＝這支分支本身就是 main 演化路徑
  # 上的一個狀態（合併後被快轉／重置到後來的 main，tip 訊息長得像 "Merge branch '<別
  # 支>' into 'main'"）。main 只會從那個點繼續往前，分支不可能揣著 main 沒有的東西，
  # 逐檔內容比對不必再做，也不必仰賴 MR 狀態。
  #
  # 這裡**不能**只用 merge-base --is-ancestor：GitLab 雙親 merge commit 的 parent2 就
  # 是原分支 tip，「是 main 的祖先」因此對每一支正常合併的分支都成立，拿它當放行條件
  # 會把「合併時內容沒完整落地」（rename 只落地一半）也一起放行——test.sh 的情形 3
  # 正是為此存在，第一版判準就是被它擋下來的。first-parent 鏈才分得開「分支被同步成
  # main」與「分支只是被 merge 進去」。
  #
  # 用 grep -c 而非 grep -q：後者找到就結束，git rev-list 收到 SIGPIPE 回非 0，在
  # pipefail 下會把整條判斷變成偽陰。
  ON_MAINLINE=0
  [ -n "$TIP" ] && ON_MAINLINE=$(git -C "$REPO" rev-list --first-parent origin/main 2>/dev/null \
                                 | grep -cFx "$TIP" || true)
  if [ "${ON_MAINLINE:-0}" -gt 0 ]; then
    V=SAFE; NOTE="分支 tip 落在 origin/main 的 first-parent 主線上"
  elif [ "$STATE" != merged ] || [ "$SHA" = - ]; then
    V=NEEDS_HUMAN; NOTE="MR 狀態=${STATE}，無 merge_commit_sha"
  elif ! git -C "$REPO" merge-base --is-ancestor "$SHA" origin/main 2>/dev/null; then
    V=NEEDS_HUMAN; NOTE="merge commit 不在 origin/main 歷史內"
  else
    MB=$(git -C "$REPO" merge-base "$B" "$SHA^1" 2>/dev/null)
    if [ -z "$MB" ]; then
      V=NEEDS_HUMAN; NOTE="算不出 merge-base"
    else
      MISSING=""
      while IFS= read -r -d '' F; do
        git -C "$REPO" diff --no-renames "$MB"   "$B"   -- "$F" | normdiff > "$OUTDIR/.a"
        git -C "$REPO" diff --no-renames "$SHA^1" "$SHA" -- "$F" | normdiff > "$OUTDIR/.b"
        # 只要求 A ⊆ B：分支引入的每一行增刪都出現在 merge 帶進來的變更裡。
        # 不要求相等——main 基準較舊時 B 合理地更大，那不是落差。
        if [ -s "$OUTDIR/.a" ] && [ -n "$(comm -23 "$OUTDIR/.a" "$OUTDIR/.b")" ]; then
          # 該檔在分支上的內容若與現在的 origin/main 逐位元組相同，刪分支不可能
          # 弄丟它——差異來自 rebase 把別人已合併的工作帶進分支的 diff 範圍，
          # 是雜訊不是落差。只有真的還不一樣的檔案才算。
          if ! git -C "$REPO" diff --quiet origin/main "$B" -- "$F" 2>/dev/null; then
            # 上一道濾網以「現在的 main」為基準，會被合併之後的後續 commit 廢掉：檔案
            # 早被別人改過，當然不再逐位元組相同，於是雜訊又被算成落差。要問的其實是
            # 「那次合併當下，這個檔案有沒有變成分支要的樣子」——基準因此改成合併當下
            # 的 main。是的就代表落地了，之後的差異是別人的演化，不是這支分支還揣著沒
            # 交出來的東西。
            #
            # 比的是整檔內容而不是增刪行的集合：行集合分不出「刪掉某一處的 {children}」
            # 與「這行文字在檔案別處還在」，而 `)}`、`className,`、`return (` 這類 JSX/TS
            # 骨架一個檔案裡就有好幾份，拿它們做集合比對必然誤判成「刪除沒落地」（實地
            # 案例：dialog.tsx 的 18 行「落差」全是這種重複的語法行）。
            git -C "$REPO" diff --quiet "$B" "$SHA" -- "$F" 2>/dev/null || MISSING="$MISSING $F"
          fi
        fi
      done < <(branch_files "$MB" "$B")
      if [ -n "$MISSING" ]; then V=NEEDS_HUMAN; NOTE="變更未完整出現在 main：$MISSING"
      else V=SAFE; NOTE="貢獻已完整進 origin/main"; fi
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$B" "$IID" "$V" "$SHA" "$NOTE" "$TIP" >> "$OUTDIR/verdict.tsv"
done < "$OUTDIR/candidates.txt"

# ---- 3. worktree 佔用訊號 -----------------------------------------------
# 四個訊號一起看。沒有任何單一訊號可靠：
#   lsof     單次快照，會漏（實測：命中 0，五分鐘後同一棵是 10）
#   wt 標記  🤖=agent 執行中；被 Ctrl+C 中斷後會殘留，💬 也可能是活著但在等輸入
#   reflog   只反映 git 操作；純輪詢／編輯中的 session 抓不到
#   髒檔     只抓寫過但未提交的
: > "$OUTDIR/markers.tsv"
if command -v wt >/dev/null 2>&1 && wt list -C "$REPO" --format json > "$OUTDIR/wtlist.json" 2>/dev/null; then
  python3 - "$OUTDIR/wtlist.json" > "$OUTDIR/markers.tsv" <<'PY'
import json,sys
for it in json.load(open(sys.argv[1])).get("items", []):
    wt = it.get("worktree") or {}
    p = wt.get("path")
    if not p: continue
    sym = ((it.get("display") or {}).get("symbols") or "")
    print("%s\t%s" % (p, "🤖" if "🤖" in sym else ("💬" if "💬" in sym else "-")))
PY
fi

: > "$OUTDIR/worktrees.tsv"
git -C "$REPO" worktree list --porcelain \
  | awk '/^worktree /{wt=$2} /^branch /{sub("refs/heads/","",$2); print wt"\t"$2} /^detached$/{print wt"\tDETACHED"}' \
  > "$OUTDIR/wtmap.tsv"
while IFS=$'\t' read -r WT BR; do
  [ "$WT" = "$REPO" ] && continue
  DIRTY=$(git -C "$WT" status --porcelain=v1 2>/dev/null | wc -l | tr -d ' ')
  HOLD=$(lsof +D "$WT" 2>/dev/null | awk 'NR>1{print $1"/"$2}' | sort -u | paste -sd, -)
  MARK=$(awk -F'\t' -v p="$WT" '$1==p{print $2}' "$OUTDIR/markers.tsv" 2>/dev/null); MARK="${MARK:--}"
  RL=$(git -C "$WT" rev-parse --git-path logs/HEAD 2>/dev/null)
  case "$RL" in /*) ;; *) RL="$WT/$RL";; esac
  AGE=$(( NOW - $(mtime "$RL") ))
  INSIDE=no; case "$PWD/" in "$WT"/*) INSIDE=yes;; esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$WT" "$BR" "$DIRTY" "${HOLD:--}" "$MARK" "$AGE" "$INSIDE" \
    >> "$OUTDIR/worktrees.tsv"
done < "$OUTDIR/wtmap.tsv"

# ---- 4. 報表 -------------------------------------------------------------
printf '%-52s %-6s %-12s %s\n' 分支 MR 判定 說明
while IFS=$'\t' read -r B IID V SHA NOTE TIP; do
  printf '%-52s %-6s %-12s %s\n' "$B" "$IID" "$V" "$NOTE"
done < "$OUTDIR/verdict.tsv"

printf '\n%-52s %-6s %-5s %-5s %-8s %s\n' worktree 髒檔 標記 樹內 reflog 佔用行程
while IFS=$'\t' read -r WT BR DIRTY HOLD MARK AGE INSIDE; do
  printf '%-52s %-6s %-5s %-5s %-8s %s\n' "${WT##*/}" "$DIRTY" "$MARK" "$INSIDE" "${AGE}s" "$HOLD"
done < "$OUTDIR/worktrees.tsv"

# ---- 5. 產生刪除計畫（不執行）-------------------------------------------
# plan.sh 自帶「動手前再查一次」的守衛。稽核與執行之間環境會變（實測同一棵樹在
# 兩次稽核之間從無人佔用變成有 kubectl 行程佔用），計畫是快照，快照不能當授權。
{
  cat <<'PLANHDR'
#!/usr/bin/env bash
# 由 audit.sh 產生。人工檢視後自行執行。
# 不用 set -e：worktree remove 被未提交變更擋下是預期結果之一，不該中斷整批。
set -uo pipefail

run() { if "$@"; then printf 'OK   %s\n' "$*"; else printf 'FAIL %s\n' "$*"; fi; }

# 有 worktrunk 就走 wt remove：post-remove hook（清掉該分支的附屬資源）只會在它觸發，
# 直接 git worktree remove 會繞過，留下沒人收的殘渣。--no-delete-branch：分支只走 del_branch，
# 才有 tip 守衛；--foreground：del_branch 跑之前樹必須已經移除完（預設是背景移除）。
# 沒有 wt 時退回 git 原生，行為與 wt 一樣：有未提交變更就拒絕。
remove_wt() {
  local R
  if R=$(wt_busy "$1"); then printf 'SKIP worktree %s：%s\n' "$1" "$R"
  elif command -v wt >/dev/null 2>&1; then run wt remove -y --foreground --no-delete-branch -C "$REPO" "$1"
  else run git -C "$REPO" worktree remove "$1"; fi
}

# 分支 tip 若已不是稽核當下那顆，代表期間有人往上 commit，內容驗證整個失效。
# 這是唯一擋得住「稽核說 SAFE、執行前該分支長出新工作」的判準。
del_branch() {
  local B="$1" EXPECT="$2" NOW R WT
  NOW=$(git -C "$REPO" rev-parse --verify --quiet "refs/heads/$B") \
    || { printf 'SKIP %s：本機分支已不存在\n' "$B"; return; }
  [ "$NOW" = "$EXPECT" ] \
    || { printf 'SKIP %s：tip 已從 %s 移到 %s，稽核結論失效\n' "$B" "${EXPECT:0:9}" "${NOW:0:9}"; return; }
  while IFS= read -r WT; do
    [ -z "$WT" ] && continue
    if R=$(wt_busy "$WT"); then printf 'SKIP %s：worktree %s（%s）\n' "$B" "$WT" "$R"; return; fi
  done < <(git -C "$REPO" worktree list --porcelain \
           | awk -v b="branch refs/heads/$B" '/^worktree /{w=$2} $0==b{print w}')
  run git -C "$REPO" branch -D "$B"
}
PLANHDR
  # 判定邏輯不複製一份到 plan 裡，source 同一個檔——複製出去的那份不會跟著修。
  printf 'REPO=%q\nACTIVE_WINDOW_SECS=%q\n. %q\n\n' "$REPO" "$ACTIVE_WINDOW_SECS" "$LIB_DIR/occupancy.sh"
  # 刻意不加 --force：worktree 有未提交變更時 git 會拒絕，那是最後一道防線，
  # 為了「一次過」統一加 --force 等於把它關掉。
  # 目錄已不在、註冊還在的殘留（別的 session 直接 rm -rf 掉工作樹）：用 git 原生
  # 的 prune 收，不要自己發明。--expire 讓「正在被搬動」的樹不會被誤收。
  if awk -F'\t' '{print $1}' "$OUTDIR/worktrees.tsv" | while IFS= read -r w; do
       [ -d "$w" ] || { echo missing; break; }
     done | grep -q missing; then
    printf 'run git -C "$REPO" worktree prune --expire "%s seconds ago"\n\n' "$ACTIVE_WINDOW_SECS"
  fi
  while IFS=$'\t' read -r WT BR DIRTY HOLD MARK AGE INSIDE; do
    awk -F'\t' -v b="$BR" '$1==b && $3=="SAFE"{f=1} END{exit !f}' "$OUTDIR/verdict.tsv" || continue
    if R=$(wt_busy "$WT"); then
      printf '# 稽核時已被擋：%s（%s）\n' "$WT" "$R"
    else
      printf 'remove_wt %q\n' "$WT"
    fi
  done < "$OUTDIR/worktrees.tsv"
  printf '\n'
  while IFS=$'\t' read -r B IID V SHA NOTE TIP; do
    [ "$V" = SAFE ] || { printf '# 跳過分支 %s：%s\n' "$B" "$NOTE"; continue; }
    printf 'del_branch %q %q   # !%s\n' "$B" "$TIP" "$IID"
  done < "$OUTDIR/verdict.tsv"
} > "$OUTDIR/plan.sh"
chmod +x "$OUTDIR/plan.sh"
printf '\n刪除計畫（未執行）：%s\n' "$OUTDIR/plan.sh"
