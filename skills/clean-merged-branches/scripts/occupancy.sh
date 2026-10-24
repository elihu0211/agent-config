# worktree 佔用判定的單一來源。audit.sh 與它產生的 plan.sh 都 source 這一份。
# 各寫一份的話，其中一邊修好的判準不會傳染到另一邊——這個 repo 有前科。
#
# 需要呼叫端先設好：REPO、ACTIVE_WINDOW_SECS
#
# 沒有任何單一訊號可靠，四個一起看：
#   髒檔     只抓寫過但未提交的
#   lsof     單次快照，會漏（實測命中 0，五分鐘後同一棵是 8）
#   wt 標記  🤖=agent 執行中；Ctrl+C 中斷或 session 被砍後會殘留
#   reflog   只反映 git 操作；純輪詢／編輯中的 session 抓不到

mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || printf 0; }

# 印出理由並回 0 ＝「此刻不要動這棵樹」；回 1 ＝沒有佔用訊號。
wt_busy() {
  local WT="$1" D H BR MJ MSYM MAGE RL A
  [ -d "$WT" ] || { printf '路徑已不存在'; return 0; }
  case "$PWD/" in "$WT"/*) printf '目前 shell 就在這棵樹裡'; return 0;; esac

  D=$(git -C "$WT" status --porcelain=v1 2>/dev/null | wc -l | tr -d ' ')
  [ "$D" != 0 ] && { printf '有 %s 個未提交變更' "$D"; return 0; }

  H=$(lsof +D "$WT" 2>/dev/null | awk 'NR>1{print $1"/"$2}' | sort -u | paste -sd, -)
  [ -n "$H" ] && { printf '行程佔用 %s' "$H"; return 0; }

  BR=$(git -C "$WT" symbolic-ref --short -q HEAD)
  if [ -n "$BR" ] && command -v wt >/dev/null 2>&1; then
    MJ=$(wt config state marker get --branch "$BR" --format json -C "$REPO" 2>/dev/null)
    MSYM=$(printf '%s' "$MJ" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("marker") or "")
except Exception: pass' 2>/dev/null)
    if [ "$MSYM" = "🤖" ]; then
      MAGE=$(printf '%s' "$MJ" | python3 -c 'import json,sys,time
try: print(int(time.time()) - int(json.load(sys.stdin).get("set_at") or 0))
except Exception: print(0)' 2>/dev/null)
      # 標記在 SessionEnd 才清除，session 被 Ctrl+C／砍掉就永遠留著。
      # 超過 STALE_MARKER_SECS（預設 6 小時）且上面的髒檔／lsof 都沒訊號，視為死 session 的殘留，
      # 不再擋、往下看 reflog——否則每次清理都要人工 marker clear。未達門檻的 🤖 仍擋（fail-safe）。
      if [ "$MAGE" -le "${STALE_MARKER_SECS:-21600}" ]; then
        if [ "$MAGE" -gt "$ACTIVE_WINDOW_SECS" ]; then
          printf 'wt 標記 🤖 %ss 前更新（未達 %ss 殘留門檻，可能仍有 session）' "$MAGE" "${STALE_MARKER_SECS:-21600}"
        else
          printf 'wt 標記 🤖（agent 執行中，%ss 前更新）' "$MAGE"
        fi
        return 0
      fi
    fi
  fi

  RL=$(git -C "$WT" rev-parse --git-path logs/HEAD 2>/dev/null)
  case "$RL" in /*) ;; *) RL="$WT/$RL";; esac
  A=$(( $(date +%s) - $(mtime "$RL") ))
  [ "$A" -lt "$ACTIVE_WINDOW_SECS" ] && { printf 'reflog %ss 前才動過' "$A"; return 0; }
  return 1
}
