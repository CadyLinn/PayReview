# PayReview 帳務核心重建計劃 v1（純記帳版）

本文件是重建計劃，不是實作結果。所有程式碼由你自己撰寫，我的角色是每個階段的規格說明、架構建議與 code review，不直接寫 Swift 檔案。

## 0. 決策紀錄

- **重建範圍**：資料層（Domain Model、Firestore 結構、Repository）與現有 Setup/Daily/Onboarding 等 Features 的商業邏輯一起重建。
- **後端平台**：維持 Firebase（Firestore + Cloud Functions），但大幅簡化用法。目前 `functions/` 資料夾其實沒有任何程式碼，只是空殼，等於是從零開始。
- **MVP 範圍**：純記帳 —— 交易（金額正負號代表收入/支出，含自由文字 `categoryLabel`）、餘額計算。結構化分類（獨立的 `Category` collection）、目標、預算、決策快照、延遲購買、訂閱等功能全部延後到 v2 以後。

## 1. 現況問題（為什麼要打掉重練）

檢視 `TECH_STACK.md`、`docs/firestore-data-model.md` 與 `PayReview/Core/Domain/FinancialRecords.swift` 後，問題不是「程式碼量太大」（目前 Domain 只有 86 行、Repository 只有 228 行），而是**還沒寫多少東西之前，規格就已經設計成一個很重的系統**：

1. Firestore 規劃了 11 個 collection（profile、financialPlans、incomeCycles、goals、plannedExpenses、flexibleBudgets、categories、tags、transactions、transfers、decisionSnapshots、deferredPurchases），彼此有交叉參照（例如 transaction 要 atomically 標記 plannedExpense 完成）。
2. 帳號刪除規劃了 6 步驟的 durable backend job + opaque receipt 機制，這是大型 SaaS 才需要的複雜度。
3. 「安心可花額度」「恢復方案」「決策快照」這些屬於進階功能的規格，在還沒有「新增一筆支出」這個最基本功能之前就已經定義好。
4. 目前 `InMemoryFinancialDataRepository` 只是假資料，`PlanSyncRepository` 也還沒有真正接上 Firestore —— 也就是說現在改資料模型的成本還很低，這是重來的最好時機。

結論：問題出在**規格複雜度**，不是程式碼技術債。重建的核心工作是「砍規格」，其次才是重寫程式碼。

## 2. v1 目標資料模型

只保留兩個 collection（不再有獨立的 `Category` collection）：

```text
users/{uid}/profile/main               使用者基本資料（顯示名稱、幣別）
users/{uid}/transactions/{transactionId}  一筆收入或支出
```

先移除（不是刪掉規格，是先不做）：`financialPlans`、`incomeCycles`、`goals`、`plannedExpenses`、`flexibleBudgets`、`categories`（結構化分類實體）、`tags`、`transfers`、`decisionSnapshots`、`deferredPurchases`、`deletionRequests`。詳見 `docs/deferred-v2-scope.md`。

### `Transaction`
| 欄位 | 型別 | 說明 |
| --- | --- | --- |
| id | String | Firestore 文件 ID |
| amountMinorUnits | Int64，可正可負 | 一律用最小貨幣單位存整數，禁止 Double/Float。正=收入、負=支出，不再需要獨立的 `kind` 欄位 |
| currencyCode | String | 初期固定 "TWD" |
| categoryLabel | String? | 自由文字分類標籤，不是對 Category collection 的參照 |
| occurredAt | Timestamp (UTC) | |
| note | String? | 選填備註 |
| source | enum: manual | 沿用現有慣例，之後可加 import/shareText |
| schemaVersion | Int | |
| createdAt / updatedAt | Timestamp | |

**餘額**不是存出來的欄位，是用 `sum(amountMinorUnits)` 在 client 端即時算出來的衍生值——因為金額本身已經帶正負號，不用再區分 income/expense 分別加總。這是純記帳最重要的簡化：不需要額外一個 "balance" 文件去維護一致性。

**類別小計**（例如「這個月餐飲花多少」）用同一批已經抓下來的 transactions 在 client 端依 `categoryLabel` 做 `Dictionary(grouping:)`，不用額外查詢、不用維護分類 collection。詳細取捨見 `docs/firestore-data-model.md` 的「Why `categoryLabel` instead of a `Category` collection」。

### Firestore Rules
現有規則已經很簡潔（`users/{uid}` 底下限定本人讀寫），v1 不需要改，直接沿用。

## 3. 後端 Cloud Functions 範圍

v1 建議：**不寫任何自訂 Cloud Function**。理由：

- 新增/讀取/刪除 transaction 和 category 都是使用者對自己資料的簡單 CRUD，client SDK + Security Rules 已經足夠安全。
- 帳號刪除、durable job、opaque receipt 這些「不可信任 client」才需要的機制，等真的要上架前、確認 App Review 5.1.1(v) 要求時再做，不要在 v1 先蓋。
- 這樣 `functions/` 資料夾在 v1 階段可以維持空的，等於是把「後端」這件事延後到真正需要伺服器信任邊界的時候才動手，降低現在的認知負擔。

若之後想練習 Cloud Functions，可以在 v1 穩定後，做一個「刪除帳號時清掉 Firestore 底下所有文件」的小 Function 當練習題，但那是 v2 的事。

## 4. Swift 架構分層（沿用現有模式，只是換血）

現有的分層本身沒有問題，繼續用：

```
View  →  ViewModel (ObservableObject/@Observable)  →  Repository (protocol)  →  Firestore data source
                                                              ↑
                                                     Domain models (struct, Codable)
```

規則不變：
- View 不直接算錢、不直接呼叫 Firebase SDK。
- 金額一律用 `Decimal` 或整數最小單位運算，不用 Double/Float。
- Domain model 保持 `Codable, Identifiable, Equatable, Sendable`。

## 5. 分階段執行計劃

每個階段結束時把你寫的檔案貼給我，我做 code review、指出問題、解釋原因，不會直接改你的檔案。

### Phase 0 — 清理規格與舊檔案（不寫程式碼）
- 決定 `FinancialRecords.swift` 裡哪些 struct 要保留（Transaction、Category、Money）、哪些先移到一個 `docs/deferred-v2-scope.md` 或直接刪除（Plan、IncomeCycle、Goal、PlannedExpense、FlexibleBudget、Transfer）。
- 更新 `docs/firestore-data-model.md`，只留 v1 的三個 collection。
- 目標：讓你自己先確認「刪掉這些不會可惜」，我可以陪你逐一討論每個被砍的功能要不要留痕跡。

### Phase 1 — Domain Model
- 重寫 `Money`、`Transaction`（含 `TransactionSource` enum）兩個型別，移除 `Category`、`kind` 欄位與其他已延後的 struct。
- 練習重點：整數最小單位運算、`Codable` 自訂 `CodingKeys`（如果 Firestore 欄位命名要跟 Swift property 不同）、用金額正負號取代 enum 表達方向。
- 驗收：寫一組 unit test 驗證 `Codable` encode/decode 往返正確、金額不會用到 Double、正負號語意正確（正=收入、負=支出）。

### Phase 2 — Repository 層
- 定義 `TransactionRepository` protocol（先不管 Firestore）。
- 練習重點：protocol-oriented design、async/await、Combine 或 AsyncStream 做即時監聽（`addSnapshotListener`）。
- 驗收：先用一個 in-memory 假實作跑通 ViewModel，再換成 Firestore 實作，兩者切換不用改 ViewModel 程式碼。

### Phase 3 — Firestore 串接
- 實作 `FirestoreTransactionRepository`，處理 DTO ↔ Domain model 轉換（Timestamp↔Date、Int64 minor units）。
- 練習重點：Firestore offline cache 行為、`waitForPendingWrites`、錯誤處理（權限、離線）。
- 驗收：在 Firebase Emulator 上跑過寫入/讀取/刪除，確認 Security Rules 擋住非本人資料。

### Phase 4 — ViewModel
- 建立「交易列表 + 新增交易 + 即時餘額」的 ViewModel。
- 練習重點：`@Observable`/`ObservableObject` 狀態管理、把 loading/error/empty 狀態明確建模（不要只有一個 Bool）。
- 驗收：手動測試離線新增一筆交易，UI 立即反映，恢復連線後不重複、不遺失。

### Phase 5 — 畫面重接
- 把 `Daily`、`Features` 底下對應畫面改成吃新的 ViewModel，移除依賴已刪除 collection 的程式碼（例如 Setup 流程裡跟 Goal/Budget 有關的步驟先隱藏或簡化成純記帳的 onboarding）。
- 練習重點：如何在不砍掉整個導覽流程的前提下，讓畫面只依賴 v1 的資料模型。

### Phase 6 — 收尾與驗收
- 移除 `InMemoryFinancialDataRepository` 裡對應已刪除 model 的程式碼、確認沒有 dead code。
- 更新 `TECH_STACK.md` 反映簡化後的資料流。
- 對照第 7 節的 Definition of Done 逐項打勾。

### Phase 7（v2，先不做）
- 之後再依序加回：分類預算 → 儲蓄目標 → 決策快照 → 帳號刪除的 durable job。每一個都應該是在 v1 穩定後才疊加，而不是一次全上。

## 6. 我如何提供指導（協作模式）

- 我不會產生或修改 `PayReview/` 底下的 Swift 檔案。
- 每個 Phase 開始前，我可以先跟你確認介面設計（protocol 簽章、struct 欄位）是否合理，用文字/虛擬碼討論，不落地成檔案。
- 你寫完後貼給我，我做 review：指出邏輯問題、Swift 慣用寫法、Firebase 用法是否符合 `TECH_STACK.md` 的規則（例如禁止 Double 存金額）。
- 需要的話我可以幫你在沙盒環境跑 `swift build` / unit test 幫你確認能不能過，但不會幫你修正錯誤本身，只會指出錯誤位置與原因。

## 7. v1 Definition of Done

- 使用者登入後可以新增一筆收入或支出交易，金額正負號代表方向，可選填 `categoryLabel` 自由文字。
- 交易列表即時顯示，餘額 = 所有交易金額加總（已含正負號），正確且即時更新。
- 離線新增交易，恢復連線後正確同步，沒有重複或遺失。
- Firestore Security Rules 有對應測試，確認使用者只能存取自己的資料。
- 程式碼與文件中不再殘留 v2 才要做的 collection/欄位（financialPlans、goals、decisionSnapshots 等）。

## 8. 時程建議

不建議訂死日期，因為這是你邊學 Swift 邊做的專案。建議用「階段完成」取代「幾月幾號」當里程碑，每個 Phase 結束時我們一起做一次 review 再進下一階段，卡住太久就先縮小範圍（例如 Phase 3 先只做 transaction、不做 category 的即時監聽）。
