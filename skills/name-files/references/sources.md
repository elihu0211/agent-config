# 來源

核對於 2026-10-23。「已讀」指讀過原始頁面或論文本身；「摘要」指只看過搜尋結果的摘要，引用前須重讀。

| 來源 | 它確立了什麼 | 核對程度 |
|------|--------------|----------|
| [arXiv submission guidelines](https://info.arxiv.org/help/submit/) | 檔名只能含 `a-z A-Z 0-9 _ + - . , =`；其他字元（含空白）一律拒收，為可攜與歸檔安全；檔名區分大小寫 | 摘要 |
| [CTAN pkgcheck error E0001](https://mirror.ircam.fr/pub/CTAN/support/pkgcheck/docs/errorsd.tex) | 檔名不應含非 ASCII 字元 | 摘要 |
| [Wilson et al. (2017), *Good enough practices in scientific computing*](https://arxiv.org/abs/1609.00037)，PLOS Computational Biology | 文字文件放在文件目錄，大型專案依文件類別分子目錄（4b）；檔名反映內容或功能（4f） | 已讀 |
| [Cookiecutter Data Science](https://cookiecutter-data-science.drivendata.org/) | `docs/` 是專案文件（MkDocs）；報告放 `reports/`；有序檔案用「一個數字（排序用）… 加上以 `-` 分隔的簡短描述」 | 已讀 |
| [The Turing Way: naming files and folders](https://book.the-turing-way.org/project-design/filenaming) | 名稱要人機皆可讀；避免空白與特殊字元；用連字號連接字詞；日期用 ISO 8601 | 摘要 |
| [Quarto manuscripts](https://quarto.org/docs/manuscripts/components.html) | 單篇文章專案的入口檔預設為 `index.qmd` | 已讀（官方文件） |
| [Quarto includes](https://quarto.org/docs/authoring/includes.html) | 被 include 的檔案以開頭 `_` 命名，專案渲染時會略過；不得自帶中繼資料區塊 | 已讀（官方文件） |
| [RFC 3986 §2](https://www.rfc-editor.org/rfc/rfc3986#section-2) | 非保留字元之外的字元在 URL 中要百分比編碼，所以非 ASCII 路徑在連結裡會變得不可讀 | 標準 |
