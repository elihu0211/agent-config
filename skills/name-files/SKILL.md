---
name: name-files
description: >-
  Name files and directories portably and lay out a documentation-heavy repo
  (papers, reports, shared assets). Use when creating, renaming, or moving files
  or directories, choosing where documents, papers or reports live, migrating a
  repo away from non-ASCII or space-containing paths, or reviewing names in a PR.
---

# Name files and directories

Paths are for machines; titles are for people. Every path is lowercase ASCII, and the human-readable title (in any language) lives in the document's metadata, not in its file name.

## Rules

1. **Lowercase ASCII kebab-case.** Use `a-z`, `0-9`, `-`, and `.` for the extension. No spaces, no uppercase, no non-ASCII (including CJK), no `_` except where a tool assigns it meaning (below). Evidence: [references/sources.md](references/sources.md).
2. **Zero-padded numeric prefix when order matters.** `01-`, `02-` … `10-`, so lexical order equals reading order. Nested series repeat the parent number: `03-corpus/03-05-pending-source-integration.qmd`. No numbers when order does not matter.
3. **The words describe the content.** `03-05-pending-source-integration`, not `03-05-part-2` or `final-v3`. Version lives in git, dates in ISO 8601 (`2026-10-23-incident.md`) only when the date is the identity.
4. **The title goes in metadata.** Front matter `title:` (Markdown, Quarto, Pandoc), `\title{}` (LaTeX), or the first heading. Readers see the title; tools see the path. Rendered output (PDF, HTML) shows the title, so nothing is lost by an ASCII path.
5. **Tool-mandated names win.** Keep the exact case and form a tool requires: `README.md`, `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, `LICENSE`, `Dockerfile`, `Makefile`, `_quarto.yml`, `index.qmd`, `.gitignore`. A leading `_` keeps its tool meaning (Quarto: include-only partial, not rendered on its own). Source code follows its language's convention (Python modules `snake_case`, Go packages, Java classes).
6. **Rename with history and verify links.** `git mv` each file; rewrite every relative link and include by resolving it from the file's old location and recomputing it from the new one; then run the repo's link check. Renaming never changes a document's title.

## Layout of a documentation-heavy repo

| Path | Holds | Note |
|------|-------|------|
| `docs/` | Documentation about the project (how to use, operate, decide) | Diátaxis applies: see the `structure-docs` skill |
| `papers/` | Standalone articles or monographs, each one file | Group into numbered volumes when there are many |
| `reports/<name>/` | One report per directory (a Quarto project, LaTeX project, …) | Plural parent so a second report needs no restructuring |
| `shared/` | Assets used by more than one of the above (LaTeX preamble, styles, CSL) | One copy; never duplicate into each library |
| `references.bib` | The single bibliography | At the root when more than one library cites it |
| `_output/` | Rendered artifacts | Ignored by git; mirrors the source layout |

`docs/` means project documentation across the ecosystem (GitHub Pages, MkDocs, Cookiecutter Data Science); do not use it for research papers or reports.

## Migration checklist

- [ ] Build an old → new mapping for every tracked file and directory; check it has no collisions before moving anything.
- [ ] `git mv` everything in one commit so history follows the rename.
- [ ] Rewrite relative links and includes (resolve from the old location, recompute from the new one); update config paths (build config, output directories, bibliography, asset includes).
- [ ] Search for remaining old path strings in prose, comments and config.
- [ ] Run the repo's full check and build; confirm link counts and output counts match before the move.
- [ ] Update the indexes that list the moved paths (`AGENTS.md`, `README.md`, parent workspace index).

## Precedence

This skill replaces per-repo naming rules: a repo's `AGENTS.md` points here instead of restating them. Where a repo must deviate (a tool or external system forces another form), its `AGENTS.md` names the exception and the reason.
