# GitLab

Needs `glab auth login`. Pass `--hostname <host>` to every `glab api` call: without it the CLI targets gitlab.com, and the resulting 404 looks like an auth failure. Use `:id` instead of a hard-coded project path.

Check the identity first: `glab auth status --hostname <host>`. A token bound to a single project bot cannot call the API of other projects (404/401) even when SSH push works; log in with a personal or group token.

## Open

`glab mr create` can hang without a TTY. In an agent shell always:

```bash
GLAB_NO_PROMPT=1 perl -e 'alarm 60; exec @ARGV' glab mr create \
  --source-branch <branch> --target-branch <default> \
  --squash-before-merge --remove-source-branch \
  --title "<type(scope): summary>" --description "$(cat body.md)" --yes </dev/null
```

If it times out, list the MRs first: the MR may exist already. If not, use the API and do not retry the command:

```bash
glab api --hostname <host> -X POST "projects/:id/merge_requests" \
  -f source_branch=<branch> -f target_branch=<default> -f squash=true \
  -f remove_source_branch=true -f "title=<title>" -F "description=@body.md"
```

## Auto-merge

Use the API. `glab mr merge` can print a success message while only queueing, or fail with 405 while the pipeline is still starting (upstream issue [#7243](https://gitlab.com/gitlab-org/cli/-/work_items/7243)):

```bash
glab api --hostname <host> -X PUT "projects/:id/merge_requests/<iid>/merge" \
  -f auto_merge=true -f squash=true -f should_remove_source_branch=true \
  -f sha="$(git rev-parse HEAD)"
```

`sha` is required even though the docs mark it optional; a local commit that was not pushed gives 409. Instances older than 17.11 take `merge_when_pipeline_succeeds` instead of `auto_merge`.

## Verify

```bash
glab api --hostname <host> "projects/:id/merge_requests/<iid>" \
  | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["state"],d["merge_when_pipeline_succeeds"],d["detailed_merge_status"],d.get("squash_commit_sha"))'
```

- `merged`: done (squash merges have no merge commit; read `squash_commit_sha`).
- `opened`, true, `ci_still_running` or `approvals_syncing`: queued correctly.
- `opened`, false: not armed. Causes: failed pipeline, unresolved discussion, or a newer push reset the flag.

## After a further push to the same MR

The flag resets and an older running pipeline is not auto-cancelled. Re-arm auto-merge with a fresh `sha`, and cancel stale pipelines with `POST projects/:id/pipelines/<id>/cancel`. With merged-results pipelines the pipeline `sha` is a temporary merge commit, so never compare it with `HEAD`; keep `head_pipeline.id` and the newest pipeline and cancel only the others.

## A pipeline that can never succeed

If jobs target a runner that does not exist the pipeline stays `running` and a queued auto-merge waits forever. Confirm by reading the job list, check `only_allow_merge_if_pipeline_succeeds` is false in the project settings, cancel the pipeline, then merge directly without `auto_merge`.

## Push options (when the API is unavailable)

```bash
git push -u origin HEAD -o merge_request.create -o merge_request.target=<default> \
  -o merge_request.remove_source_branch -o merge_request.squash \
  -o merge_request.title="<title>" -o merge_request.description="line1%0Aline2"
```

The description cannot contain real newlines; use `%0A`.
