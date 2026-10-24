---
name: open-pull-request
description: >-
  Takes the current working tree from uncommitted changes to an open pull request
  (GitHub) or merge request (GitLab) with a conventional-commit title, squash and
  auto-merge, then verifies the real merge state. Use when asked to commit, open
  a PR or MR, send for review, create a merge request, or when uncommitted
  changes sit on the default branch.
compatibility: Requires git and gh (GitHub) or glab (GitLab) logged in, with network access to the forge.
---

# Open a pull request

One flow for both forges: branch, commit, push, open, enable auto-merge, verify.

## Read first

- The consuming repo's `AGENTS.md`: commit format, branch naming, required trailers and whether the default branch is protected win over this skill. If it says to push directly, do that instead.
- The forge reference matching `git remote get-url origin`: [references/github.md](references/github.md) or [references/gitlab.md](references/gitlab.md).

## Steps

1. Inspect state: `git branch --show-current`, `git status --short`, `git fetch origin <default>`, `git log origin/<default>..HEAD --oneline`, `git diff --stat`.
2. Choose the starting point.
   - On the default branch with changes: name a branch `type/brief-kebab-desc`, `git switch -c`, add files by name, commit.
   - On a feature branch with uncommitted changes: commit first.
   - On a feature branch with commits only: continue.

   Commit message: `type(scope): imperative summary`, types fix, feat, chore, refactor, docs, test, ci. Add any trailer the repo or harness requires; do not invent one.
3. `git rebase origin/<default>` before the first push so a conflict never forces a second push and a duplicate pipeline.
4. Push with `git push -u origin <branch>`. If a hook fails, fix the cause and commit again; never `--no-verify`.
5. Open the PR/MR with a conventional-commit title (never type `Draft:` by hand; use the draft flag) and a body with Summary (what and why) and Test plan (done items checked, CI-only items unchecked). Commands per forge are in the reference.
6. Enable squash auto-merge and delete-source-branch, following the reference.
7. Verify the actual state by querying the forge, never from the text the CLI printed, then report: URL, pipeline status, whether auto-merge is armed. If a pipeline failed, list the failing job names and do not merge.

## Rules

- Add files by name; never `git add .` that could include `.env` or credentials.
- Write PR/MR bodies from a quoted heredoc (`<<'EOF'`) or a file, because backticks and `$` in an unquoted string are executed by the shell.
- A new push to an open MR resets auto-merge and can leave an older pipeline running; re-arm it and cancel the stale pipeline (see the reference).
