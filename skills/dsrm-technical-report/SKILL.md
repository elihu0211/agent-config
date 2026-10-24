---
name: dsrm-technical-report
description: >-
  Write or review a technical report structured by the Design Science Research
  Methodology (DSRM), including Taiwanese master's technical reports that replace
  a thesis (學位授予法 §7, 認定準則 §10). Use when drafting, restructuring, or
  reviewing a report about a built system or artifact, mapping chapters to DSRM
  activities, classifying evaluations (FEDS), or checking a report before degree
  review or publication.
license: MIT
---

# DSRM 技術報告

把「已經建好或正在建的系統」寫成一份可以被檢驗的研究報告：問題有證據、目標可評估、設計說得出取捨、評估據實分類、貢獻不誇大。

## 先讀

1. **專案的 `AGENTS.md`**：目錄、建置工具、文體與引用格式以它為準；本技能不規定檔案放哪裡。
2. **學位用途時，系所公告的技術報告採計基準**：章名、格式、送繳資料以它為準；法定的四項內容不可缺。
3. 依需要讀 `references/`：

| 檔案 | 何時讀 |
|------|--------|
| [dsrm.md](references/dsrm.md) | 決定切入點、章節，或引用 DSRM、FEDS、發表綱要時 |
| [chapter-map.md](references/chapter-map.md) | 排章節、檢查每章該回答什麼時 |
| [taiwan-degree.md](references/taiwan-degree.md) | 學位用途；引用條文、處理學術倫理、生成式 AI、個資、送存時 |
| [writing-zh-tw.md](references/writing-zh-tw.md) | 繁體中文的標點、數字與術語 |
| [review-checklist.md](references/review-checklist.md) | 送審或發布前 |

## 流程

1. **定切入點**：產物先存在者是「設計與開發為中心」，不要寫成從問題出發；把後見之明的偏差列入限制。
2. **排章節**：依 [chapter-map.md](references/chapter-map.md) 的對應表；研究方法章放對應表。
3. **蒐集證據**：每章的主張連到證據（事故、量測、文件、程式碼）；專案已有設計文件時，報告只引用、不重述。
4. **寫評估**：每次評估標 FEDS 的兩個維度；只有總結性評估能支持「目標已達成」。
5. **寫貢獻與限制**：歸入四象限之一、標出抽象層次；限制寫會改變結論的。
6. **核對與檢核**：逐項走 [review-checklist.md](references/review-checklist.md)。

## 硬規則

- **不得虛構**：沒有跑過的量測、沒有發生的使用、沒有讀過的文獻，一律不寫。這同時是學術倫理（造假）與學位授予法第 17 條的問題。
- **核對紀錄**：文獻、條文、外部事實都回到原始來源核對，並記錄核對程度與日期（書目的 note 欄或附錄）。只讀過摘要的文獻，正文不轉述其細節。生成式 AI 的輸出不是來源。
- **形成性不等於總結性**：測試、模擬、結構論證只能支持「機制已實作」。
- **結論不強於評估**：每一個「能主張」都指得出支持它的評估；其餘寫成條件句或未來工作。
- **會漂移的值不寫死**：版本、筆數、條文修正日寫「於某日核對」並附可重查的來源。
