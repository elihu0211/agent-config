# Sources

Checked on 2026-10-23. "Read" means the primary page or paper itself; "summary" means a search-result summary of it, to be re-read before quoting.

| Source | What it establishes | Checked |
|--------|---------------------|---------|
| [arXiv submission guidelines](https://info.arxiv.org/help/submit/) | File names may contain only `a-z A-Z 0-9 _ + - . , =`; anything else (spaces, other characters) is rejected, for portability and archival safety; names are case-sensitive | Summary |
| [CTAN pkgcheck error E0001](https://mirror.ircam.fr/pub/CTAN/support/pkgcheck/docs/errorsd.tex) | File names should not contain non-ASCII characters | Summary |
| [Wilson et al. (2017), *Good enough practices in scientific computing*](https://arxiv.org/abs/1609.00037), PLOS Computational Biology | Put text documents in a documentation directory, with subdirectories per class of document in large projects (4b); name files to reflect their content or function (4f) | Read |
| [Cookiecutter Data Science](https://cookiecutter-data-science.drivendata.org/) | `docs/` is project documentation (MkDocs); reports live in `reports/`; ordered files use "a number (for ordering) … and a short `-` delimited description" | Read |
| [The Turing Way: naming files and folders](https://book.the-turing-way.org/project-design/filenaming) | Names readable by humans and machines; avoid spaces and special characters; dashes join words; ISO 8601 dates | Summary |
| [Quarto manuscripts](https://quarto.org/docs/manuscripts/components.html) | A single-article project's entry file is `index.qmd` by default | Read (official docs) |
| [Quarto includes](https://quarto.org/docs/authoring/includes.html) | Included files take a leading `_` so a project render skips them; they must not carry their own metadata block | Read (official docs) |
| [RFC 3986 §2](https://www.rfc-editor.org/rfc/rfc3986#section-2) | Characters outside the unreserved set are percent-encoded in URLs, so non-ASCII paths become unreadable in links | Standard |
