# agent-config

Personal, vendor-neutral AI agent skills in [Agent Skills](https://agentskills.io/specification) format. Projects install them with [`npx skills`](https://github.com/vercel-labs/skills); `skills-lock.json` in each project pins source and hash — no manual copying.

## Use

```bash
# Install into a project (writes .agents/skills/ + skills-lock.json)
DISABLE_TELEMETRY=1 npx skills add elihu0211/agent-config --skill '*' -a codex -y

# Sync after upstream changes
DISABLE_TELEMETRY=1 npx skills update -p -y
```

`-a codex` writes to `.agents/skills/`, which Codex, Cursor, GitHub Copilot and Gemini CLI read. Claude Code only scans `.claude/skills/`, so consuming projects symlink **each skill** there: `.claude/skills/<name> → ../../.agents/skills/<name>`. The [docs](https://code.claude.com/docs/en/skills) cover symlinked `<skill-name>` entries, not a symlinked `skills` directory.

## Skills

Each skill is a directory under [`skills/`](skills); its `SKILL.md` front matter states when it applies. The set changes over time, so the directory is the index.

## Changing a skill

1. Edit `skills/<name>/SKILL.md` here and open a PR (conventions: [`AGENTS.md`](AGENTS.md)).
2. After merge, run `npx skills update` in each consuming project.
