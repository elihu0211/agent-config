---
name: clean-merged-branches
description: >-
  Audits and deletes remote branches whose pull or merge request is merged,
  stale local tracking branches and per-branch git worktrees, on GitHub or
  GitLab, verifying each branch's content actually reached the default branch.
  Use when asked to clean up branches, delete old or merged branches, prune
  worktrees or tidy the workspace.
compatibility: Requires git, python3, and gh (GitHub) or glab (GitLab) logged in. lsof is used when present; the wt CLI is optional.
---

# Clean merged branches

Judgment is done by bundled scripts, not improvised in conversation: the audit is read-only and produces a plan; nothing is deleted until the plan is run.

## Read first

- The consuming repo's `AGENTS.md`: protected branch names and worktree conventions win over this skill.
- [references/traps.md](references/traps.md) before changing any script. Every entry is a false conclusion that was hit in practice.

## Steps

1. Run the audit (read-only). The forge is detected from the `origin` URL; override with `FORGE=github` or `FORGE=gitlab`:

   ```bash
   bash scripts/audit.sh [REPO_PATH] [OUTDIR]
   ```

   It prints a verdict per branch (`SAFE` or `NEEDS_HUMAN`), the occupancy signals of every worktree, and writes `OUTDIR/plan.sh` without running it.
2. Show the user the `SAFE` list (with PR/MR numbers) and every skipped item with its reason. Ask for confirmation unless they already said to delete everything.
3. Run the plan:

   ```bash
   bash "$OUTDIR/plan.sh"
   ```

   The plan re-checks occupancy before each worktree removal and skips any branch whose tip moved since the audit. The plan is a snapshot, not an authorization.
4. Report what was deleted (with numbers), which worktrees were removed, and what was skipped and why.

## Rules

- Delete only branches that are merged **and** whose content is verified to be in the default branch file by file. Never touch branches with an open PR/MR.
- Never delete `main`, `master`, `develop`, `staging`, `release*` or worktrees that serve a standing purpose.
- Destructive actions and their confirmation never share one command; a check in the same call as the removal is no check.
- Squash-merge is the norm. `git branch -d` reports squash-merged branches as unmerged; that is not a divergence.
- Delete remote branches through the forge API (see `scripts/forge-*.sh`), not `git push --delete`, which triggers unrelated pre-push hooks.

## Verify the scripts

After any change to the scripts run `bash scripts/test.sh`. Each test was mutation-checked: removing its fix must turn it red; a green run alone proves nothing.
