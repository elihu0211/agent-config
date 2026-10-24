---
name: structure-docs
description: >-
  Organize a repo's documentation with the Diátaxis framework. Use when adding,
  splitting, or reviewing files under docs/, writing a runbook, guide, reference,
  or design-decision page, or when a doc mixes steps with rationale.
license: MIT
---

# Structure docs (Diátaxis)

Each document does one job. Pick the type first, then write.

| Type | Reader wants to | Write as | Never include |
|------|-----------------|----------|---------------|
| Tutorial | learn by doing, start to finish | ordered steps with a visible result | background, options |
| How-to | finish one task | steps for a competent reader | teaching, rationale |
| Reference | look something up | dry, structured like the thing described | instructions, opinions |
| Explanation | understand why | prose, trade-offs, rejected options | commands to run |

Source: [diataxis.fr](https://diataxis.fr). Decision records are Explanation.

## Rules

1. **One type per file.** If a file needs two, split it; link instead of repeating.
2. **Register every doc** in the repo's `docs/README.md` with its type. Create that index if missing; it is the single index (do not also list files in `AGENTS.md`).
3. **Do not write values that drift** (versions, counts, hostnames, file lists). Point to the source file. A pin that must exist is written once, at the step that uses it, with the reason.
4. **Decisions are append-only.** Each carries a status (adopted, planned, accepted gap, superseded). To change one, add a new entry and mark the old one superseded; do not rewrite it.
5. **Docs change in the same change as the code or manifest** they describe.
6. **Keep it short.** Cut anything the reader cannot act on or look up elsewhere; link official docs for depth.

## Repo conventions win

If the consuming repo's `AGENTS.md` sets its own doc layout or style (language, numbering, build tooling), follow it. A repo whose docs are a single-genre publication (for example, a monograph library) does not need the four-way split.
