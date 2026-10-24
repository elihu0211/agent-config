# GitHub

Needs `gh auth login`.

## Open

```bash
gh pr create --title "<type(scope): summary>" --body-file body.md
```

`body.md` holds a Summary section (what and why) and a Test plan checklist.

## Auto-merge

```bash
gh pr merge <number> --auto --squash --delete-branch
```

If CI has not started yet, wait a few seconds and retry once.

## Verify

```bash
gh pr view <number> --json state,autoMergeRequest,mergeStateStatus
```

`autoMergeRequest: null` means auto-merge is **not** armed. Two known causes: the repository has auto-merge disabled (`gh api repos/{owner}/{repo} --jq .allow_auto_merge`), or there are no required checks, in which case `--auto` merges immediately instead of queueing. Check the repository setting before assuming the command worked.

## Failures to recognise

- Every job fails to start with an account billing or spending-limit message: this is an account-level problem, not the change. Say so and stop; do not retry merges.
