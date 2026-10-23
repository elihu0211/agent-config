# AGENTS.md

This repo is the **source of truth** for skills shared across my projects. Layout, install channels, update automation and releases: [`README.md`](README.md).

## Commands

```bash
uv run scripts/validate.py   # spec + repo rules; must pass before a PR
```

## Rules

- **Follow the [Agent Skills spec](https://agentskills.io/specification).** Directory name == `name` (lowercase, digits, single hyphens, ≤ 64); `description` says what the skill does **and** "Use when …" (≤ 1024 characters); `metadata` values are strings. `scripts/validate.py` enforces these.
- **Progressive disclosure.** `SKILL.md` holds the steps and rules (well under 500 lines); detail goes in `references/`, linked one level deep from `SKILL.md`. Code the agent runs goes in `scripts/`; templates and data in `assets/`.
- **Project-agnostic.** A skill defers to the consuming repo's `AGENTS.md` for commands, paths and stack; it never hardcodes them, and never names this repo (consumers find it through `skills-lock.json`).
- **Public repo.** No secrets, internal URLs, or client or project details.
- **Verify facts before writing them.** Laws, standards and papers are checked against the primary source; record how far (full text, abstract, bibliographic) and when. Values that drift (versions, counts, dates of amendment) are written as "checked on <date>" with a source to re-check.
- **Every skill is listed in `.claude-plugin/marketplace.json`**, one plugin per skill, same name.
- **CI templates are a public interface.** `ci/` and `.github/workflows/skills-update.yml` are consumed at the `v1` tag; keep them backward compatible or release `v2` (see README → Release).
