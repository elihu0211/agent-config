# agent-config

Personal, vendor-neutral AI agent skills in [Agent Skills](https://agentskills.io/specification) format. Projects install them with [`npx skills`](https://github.com/vercel-labs/skills); `skills-lock.json` in each project pins source and hash — no manual copying.

## Use

```bash
# Install into a project (writes .agents/skills/ + skills-lock.json)
DISABLE_TELEMETRY=1 npx skills add elihu0211/agent-config --skill '*' -a codex -y

# Sync after upstream changes
DISABLE_TELEMETRY=1 npx skills update -p -y
```

`-a codex` writes to `.agents/skills/`, which Codex, Cursor, GitHub Copilot and Gemini CLI read. Claude Code only scans `.claude/skills/`, so consuming projects symlink `.claude/skills → ../.agents/skills`.

## Skills

| Skill | Purpose |
|-------|---------|
| `maintain-agent-context` | Keep agent config neutral: canonical `AGENTS.md`, import-only `CLAUDE.md`, single skills tree |

## Changing a skill

1. Edit `skills/<name>/SKILL.md` here and open a PR.
2. After merge, run `npx skills update` in each consuming project.
