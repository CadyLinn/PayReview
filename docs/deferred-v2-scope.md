# 延後到 v2 以後的規格（Phase 0 刪減紀錄）

v1 重建目標是純記帳（交易、分類、餘額）。以下功能不是被否決，只是延後，等 v1 穩定後再視需要疊加。保留這份文件是為了不遺失原本的設計思考。

## 資料模型（原 `FinancialRecords.swift` / `docs/firestore-data-model.md`）

| 項目 | 對應 v1 前狀態 | 延後原因 |
| --- | --- | --- |
| `FinancialPlanRecord` / `financialPlans` | 已有 struct + collection 規劃 | 純記帳不需要「計畫」這層抽象，先讓交易本身能運作 |
| `IncomeCycleRecord` / `incomeCycles` | 已有 struct + collection 規劃 | 屬於預算週期功能，依賴尚未存在的 plan 概念 |
| `FlexibleBudgetRecord` / `flexibleBudgets` | 已有 struct + collection 規劃 | 預算上限與追蹤，屬於「記帳+預算」的 v2 範圍 |
| `GoalRecord` / `goals` | 已有 struct + collection 規劃 | 儲蓄目標與進度計算，屬於「記帳+目標」的 v2 範圍 |
| `PlannedExpenseRecord` / `plannedExpenses` | 已有 struct + collection 規劃 | 預期支出追蹤與交易的 atomically 完成標記，先不做 |
| `TransferRecord` / `transfers` | 已有 struct + collection 規劃 | 轉帳不算收入/支出，v1 沒有多帳戶概念，暫不需要 |
| `TagRecord` / `tags` | 只在文件中規劃，未成 struct | 標籤是進階分類需求，先用 Category 就夠 |
| `decisionSnapshots` | 只在文件中規劃，未成 struct | 「安心可花額度」「決策快照」等進階評估功能，v1 沒有 FinanceEngine |
| `deferredPurchases` | 只在文件中規劃，未成 struct | 依賴 decisionSnapshots，一起延後 |
| `FinancialDataSnapshot`（聚合型別） | 已存在於 `FinancialRecords.swift` | 已決定 v1 改用 Repository 提供即時資料流，不再用單一聚合型別包住全部資料 |
| `CategoryRecord` / `categories` collection（結構化分類實體） | 已有 struct + collection 規劃 | 進一步簡化後決定 v1 不做管理型分類（沒有分類的建立/改名/刪除 UI 與 Repository），改用 `Transaction.categoryLabel` 自由文字欄位。類別小計改成讀取交易資料後在 client 端 `Dictionary(grouping:)` 分組計算，不額外查詢，成本可忽略。等 v2 真的需要「改名連動歷史交易」「合併分類」「刪除並轉移」這類管理需求時，再把 `categoryLabel` 升級成真正的 `Category` collection |
| `Transaction.kind`（income/expense enum 欄位） | 已存在於 `FinancialRecords.swift` | 決定用 `amountMinorUnits` 的正負號表達方向（正=收入、負=支出），不再需要獨立的 `kind` 欄位，避免金額與方向標記不一致的資料矛盾 |

## 後端 / 帳號刪除（原 `TECH_STACK.md` 帳號刪除章節）

`deletionRequests` collection 與 6 步驟 durable deletion job（重新驗證 → 停止本機寫入 → 呼叫 Cloud Function → 等待 receipt → 清除本機資料 → 後端遞迴刪除）**設計本身保留**，只是實作延後到：

1. v1 純記帳跑穩之後，且
2. 真的要送 App Review、需要重新確認 5.1.1(v) 要求的時候。

延後原因：這是「不可信任 client」才需要的伺服器信任邊界機制，v1 階段的 CRUD 需求用 Firestore Security Rules 就足夠，不需要先蓋這一層。

## 何時重新拿出來看

按照 `REBUILD_PLAN_V1.md` 的 Phase 7，建議順序是：分類預算 → 儲蓄目標 → 決策快照 → 帳號刪除 durable job。每項都應該在前一項於 v1+已加項目上穩定運作後才疊加，不要一次全上。
