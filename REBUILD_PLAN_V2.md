# PayReview v2 規劃（在穩定的 v1 純記帳上疊加）

v1（見 `REBUILD_PLAN_V1.md`）已經是可用的純記帳：交易（金額正負號代表收入/支出）、自由文字 `categoryLabel`、衍生餘額。這份文件規劃 `docs/deferred-v2-scope.md` 裡列出的四項延後功能要怎麼疊加回來。

## 0. 執行原則

- **一次做一個，不要一次全上。** 每個項目做完、跑過、實際用過一段時間，再開始下一個。這是 v1 重建最重要的教訓：規格一次疊太多，之後想改會不知道從何改起。
- **每個項目開始前，先在對話裡把範圍定清楚**（哪些欄位、哪些簡化、哪些暫時不做），跟 v1 每個 Phase 開始前的做法一樣，再動手寫程式碼。
- 每個項目都是獨立的 git 分支/PR，跟 v1 重建那次一樣的節奏。

## 1. 建議順序與理由

1. **期間預算**——最單純，不需要新的計算引擎，只是把交易加總拿來跟一個上限比較。
2. **儲蓄目標**——需要決定「進度」怎麼算，比預算複雜一點，但還不需要 FinanceEngine。
3. **決策快照 / 消費前評估**——這是原本 `PRODUCT_PLAN_V0.2.md`、`TECH_STACK.md` 裡談的核心體驗（安心可花額度、購買前評估），需要建立獨立的 `FinanceEngine` 模組，依賴前兩項的資料（預算、目標）才有意義，所以排在後面。
4. **帳號刪除 durable job**——技術上跟前三項無關，是後端信任邊界問題（Cloud Functions），可以獨立排期，但建議放最後，因為前三項都是「使用者看得到的功能」，這項是「上架前才必須有」的基礎設施，優先度上可以往後放，但送審前一定要做完。

## 2. 期間預算（下一個要做的項目）

延續我們已經討論過的範圍：

- 不做結構化分類、不做「每個類別各自的預算」，只做一個整體的期間預算上限。
- 不做自訂收入週期，直接用日曆月當計算範圍。
- 新增 `BudgetRecord`：`limitMinorUnits: Int64`、`updatedAt: Date`，存在 `users/{uid}/budget/main`（單一文件，比照 `profile/main` 的模式）。
- 新增獨立的 `BudgetRepository` protocol（`observeBudget()`、`setBudgetLimit(_:)`），不跟 `TransactionRepository`混在一起，職責單一。
- 新增 `BudgetViewModel`：組合「本月已花費」（從 transactions 算）與「預算上限」，算出剩餘與是否超支。
- UI：在「紀錄」畫面上方加一個簡單的預算進度條/文字。

## 3. 儲蓄目標

初步構想（開始動手前還要再確認細節）：

- `GoalRecord`：`id`、`name`、`targetAmountMinorUnits`、`targetDate`、`savedAmountMinorUnits`。
- 待確認的關鍵問題：`savedAmountMinorUnits` 要怎麼更新？
  - 方案 A：使用者手動輸入「目前已存多少」，跟交易記錄完全脫鉤，最簡單但容易跟實際花費脫節。
  - 方案 B：新增一種「存入目標」的交易類型，扣款同時增加目標進度，邏輯上更一致，但會讓 `TransactionRecord` 或交易輸入流程變複雜。
  - 這個決定會影響資料模型設計，開始這個項目時要先討論定案，不要沿用舊規格照搬。

## 4. 決策快照 / 消費前評估（FinanceEngine）

這是四項裡最大的一塊，對應 `TECH_STACK.md` 的「FinanceEngine」章節：

- 建立獨立 Swift module，不依賴 SwiftUI/Firebase/登入，貨幣一律用 `Decimal`（這裡例外於其他部分用 `Int64` minor units的作法，因為要做比率／期間換算計算，需要看當時的實際計算需求再定案，不是照抄舊規格）。
- 依賴期間預算與儲蓄目標的資料，計算「安心可花額度」、「恢復方案」等。
- 產生 `DecisionSnapshot`，只在使用者確認後才寫入 Firestore。
- 這一項開始前，建議先重新檢視 `PRODUCT_PLAN_V0.2.md` 裡原始的體驗設計，確認哪些部分仍然符合現在的產品方向，哪些該簡化。

## 5. 帳號刪除 durable job

對應 `TECH_STACK.md` 的「Firebase Authentication」與「Cloud Functions」章節：

- 這是目前 `functions/` 資料夾第一次真的要寫程式碼的時候。
- 六步驟流程（重新驗證 → 停止本機寫入並等待 pending writes → 呼叫 Cloud Function 建立 durable deletion job → 收到 receipt 後清本機資料 → 後端遞迴刪除 → 保留 job 稽核紀錄）已經在 `TECH_STACK.md` 寫得很詳細，這裡不重複，實作時直接對照那份文件。
- 這是唯一真的需要 Cloud Functions 的項目——如果不打算近期上架，這項可以排在最後、甚至先不做。

## 6. 目前狀態

尚未開始任何一項。建議下一步從第 2 節「期間預算」開始，範圍已經確認過，可以直接進入設計/實作。
