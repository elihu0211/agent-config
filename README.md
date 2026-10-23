# agent-skills

Vendor-neutral [Agent Skills](https://agentskills.io/specification) shared across my projects. One skill per directory under [`skills/`](skills); each `SKILL.md` front matter says what the skill does and when it applies, so the directory is the index.

## Layout

```
skills/<name>/                      one skill: SKILL.md (+ references/, scripts/, assets/)
template/                           starting point for a new skill
.claude-plugin/marketplace.json     Claude Code plugin marketplace (one plugin per skill)
scripts/validate.py                 spec and repo-rule validation (CI runs it)
.github/workflows/validate.yml      runs the validation on every PR
.github/workflows/skills-update.yml reusable workflow for consuming repos on GitHub
ci/skills-update.gitlab-ci.yml      CI template for consuming repos on GitLab
```

## Install into a project (any agent)

Projects install with the [`skills` CLI](https://github.com/vercel-labs/skills). It writes `.agents/skills/<name>/` and pins the source and content hash in `skills-lock.json`:

```bash
DISABLE_TELEMETRY=1 npx skills add elihu0211/agent-skills --skill <name> -a codex -y
```

`.agents/skills/` is read by Codex, Cursor, GitHub Copilot and Gemini CLI. Claude Code only scans `.claude/skills/`, so link each skill there: `.claude/skills/<name> → ../../.agents/skills/<name>`. The [docs](https://code.claude.com/docs/en/skills) cover symlinked `<name>` entries, not a symlinked `skills` directory.

## Keep projects up to date

Each consuming project runs a scheduled job that executes `npx skills update -p -y` and, when anything changed, opens a merge request. Nothing is merged automatically: skills run with the agent's full permissions, so a person reviews the diff.

**GitHub** — add `.github/workflows/skills-update.yml`:

```yaml
on:
  schedule: [{ cron: "0 21 * * 0" }]   # Monday 05:00 Asia/Taipei
  workflow_dispatch:
permissions:
  contents: write
  pull-requests: write
jobs:
  update:
    uses: elihu0211/agent-skills/.github/workflows/skills-update.yml@v1
```

Then turn on *Settings → Actions → General → Allow GitHub Actions to create and approve pull requests*.

**GitLab** — include the template and give the hidden job one of the repo's stages:

```yaml
include:
  - remote: https://raw.githubusercontent.com/elihu0211/agent-skills/v1/ci/skills-update.gitlab-ci.yml

skills-update:
  extends: .skills-update
  stage: <one of this repo's stages>
```

Then add the `SKILLS_UPDATE_TOKEN` variable and a pipeline schedule with `SKILLS_UPDATE=true`; the template header lists every step.

## Install for yourself in Claude Code

For skills you want in every session rather than pinned per project, add this repo as a plugin marketplace. Claude Code can refresh it in the background:

```
/plugin marketplace add elihu0211/agent-skills
/plugin install <name>@elihu0211-skills
```

Use one channel per project: a skill installed both ways loads twice.

## Change or add a skill

1. Copy [`template/`](template) to `skills/<name>/` (or edit an existing skill). Conventions: [`AGENTS.md`](AGENTS.md).
2. Add the skill to [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json).
3. Run `uv run scripts/validate.py`, then open a PR.

## Release

Consumers reference the CI templates at the `v1` tag. After merging a change to `ci/` or `.github/workflows/skills-update.yml`, move the tag:

```bash
git tag -f v1 origin/main && git push -f origin v1
```

Skill content itself is not tagged: `npx skills update` follows the default branch and the consumer's merge request is the review point. A breaking change to the CI templates gets a new major tag (`v2`) instead of moving `v1`.
