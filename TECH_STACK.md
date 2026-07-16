# 花算 PayReview 技術選型 v0.2

## 技術目標

PayReview MVP 採 SwiftUI + Firebase，並維持本機可完成消費前評估。

技術架構必須確保：

1. 消費前評估快速、可離線、可測試。
2. 登入使用者可安全同步財務計畫、交易與決策紀錄。
3. 使用者必須以 Apple 或 Google 帳號登入後才能使用核心功能。
4. 試算在確認前不修改正式財務資料。
5. 不連結銀行或支付帳戶也能完整使用 MVP。

## MVP 技術結論

| 層級 | 選擇 | 用途 |
| --- | --- | --- |
| App | Swift、SwiftUI | iOS 原生介面、導航與動畫 |
| 財務計算 | 獨立 Swift `FinanceEngine` | 預算、目標、頻率、日期與恢復方案 |
| 資料庫 | Cloud Firestore | 正式財務資料、持久化快取與跨裝置同步 |
| 帳號 | Firebase Authentication | Sign in with Apple、Google 登入與帳號生命週期 |
| 後端工作 | Firebase Cloud Functions | 帳號刪除與其他不可信任客戶端的操作 |
| 內購訂閱 | StoreKit 2 | 年費、月費、試用、權益與恢復購買 |
| 分析 | Firebase Analytics | 經隱私審查的 AARRR 事件 |
| 錯誤監控 | Firebase Crashlytics | 當機與非致命錯誤診斷 |
| 通知 | UserNotifications | 使用者啟用提醒後的本機通知 |
| 開源聲明 | LicensePlist | 產生第三方授權資訊 |

MVP 建議支援 iOS 17 以上，以使用現代 SwiftUI 與 Swift Concurrency。正式最低版本仍須由團隊確認。

## 明確不納入 MVP

- 商店方案、折扣、優惠券、單價或任何比價功能。
- CloudKit 或 Firebase 以外的第二套財務同步來源。
- 銀行、信用卡或支付帳戶串接。
- Share Extension、截圖 OCR 與自動擷取價格。
- 網路爬蟲與商城功能。
- AI 決定或修改財務計算結果。

比價功能目前不列入承諾中的後續版本。若未來重新提出，必須另寫產品規格、資料模型、隱私評估與測試計畫。

## SwiftUI App

使用 SwiftUI 建立：

- 今天：安心可花額度、下一筆預期支出、目標狀態與評估入口。
- 評估：快速金額輸入、預算／頻率／目標影響、購買或延後選項。
- 計畫：目標、收入週期、固定支出、彈性預算與安全緩衝。
- 紀錄：收入、支出、轉帳、類別、標籤與回顧。
- 設定：登入、訂閱、通知、隱私、資料匯出、帳號刪除與客服。

規則：

- View 不直接計算財務結果或直接呼叫 Firebase SDK。
- View 透過 feature state 或 ViewModel 使用 Repository protocol。
- Repository 使用 Firestore data source，並封裝離線與同步狀態。
- 動畫必須尊重 Reduce Motion。
- 關鍵流程支援 Dynamic Type、VoiceOver 與本地化金額／日期。

## FinanceEngine

建立不依賴 SwiftUI、Firebase、登入或分析服務的 Swift 模組。

職責：

- 預留必要與預期型支出後，計算彈性可花額度。
- 計算 `within_flexible`、`uses_buffer`、`requires_plan_change` 與 `insufficient_data`。
- 計算消費頻率、最低儲蓄速度、目標影響與恢復方案。
- 產生可保存的 `DecisionSnapshot`。

技術規則：

- 貨幣使用 `Decimal`，不可使用 `Double` 或 `Float`。
- 日期使用 `Calendar` 與明確時區。
- AI 只能改寫已計算結果，不得產生或覆寫數字。
- 所有程式碼註解使用英文，不使用 emoji。

## 資料來源

Cloud Firestore 是正式財務資料的唯一同步來源。Apple 平台預設啟用離線持久化；仍須明確確認 persistent disk cache 設定並測試。已成功登入且載入過的資料可在沒有網路時讀寫，並於恢復連線後同步。

首次登入、首次載入尚未快取的資料，以及部分需要伺服器確認的操作仍需要網路。介面必須區分快取資料、pending writes 與已由伺服器確認的資料，不能把離線結果表示為最新雲端狀態。

尚未確認的 `SpendScenario` 保持本機暫存，不寫入 Firestore。只有使用者選擇保存決策或「購買並記錄」後，才寫入正式資料。

建議資料路徑：

```text
users/{uid}/profile/main
users/{uid}/financialPlans/{planId}
users/{uid}/incomeCycles/{incomeCycleId}
users/{uid}/goals/{goalId}
users/{uid}/plannedExpenses/{expenseId}
users/{uid}/flexibleBudgets/{budgetId}
users/{uid}/transactions/{transactionId}
users/{uid}/transfers/{transferId}
users/{uid}/categories/{categoryId}
users/{uid}/tags/{tagId}
users/{uid}/decisionSnapshots/{snapshotId}
users/{uid}/deferredPurchases/{purchaseId}
```

## Firebase Authentication

支援：

- Sign in with Apple。
- Google Sign-In。

使用者必須使用 Apple 或 Google 帳號登入後才能進入首次設定與核心功能。不使用 Firebase Anonymous Authentication，也不提供訪客模式。

首次登入需要網路。若裝置已有有效登入狀態，且 Firestore 有可用快取，才允許在離線狀態進入可用的核心畫面。

帳號刪除必須從 App 內開始，並刪除 Firebase Authentication 身分、Firestore 文件及使用者相關雲端檔案。不可只提供客服 Email 或一般表單。

## Firestore 安全與一致性

- Security Rules 必須限制使用者只能讀寫自己的 `uid` 路徑。
- 不得使用公開讀寫規則。
- 不得將 service account、私鑰或其他伺服器端機密提交到 Git。
- 交易建立與預期支出完成需要具備 idempotency，避免重複點擊或離線重試造成重複扣款。
- 為重要文件保留 schema version、createdAt、updatedAt 與必要的 rule version。
- 明確處理 server timestamp 尚未解析、離線 pending write 與刪除同步狀態。
- 使用 Firebase Emulator 測試跨使用者隔離、拒絕未授權寫入與資料驗證。

## Cloud Functions

只用於必須信任伺服器端的工作：

- 協調完整帳號刪除。
- 未來需要驗證的 Webhook 或伺服器端匯出。

不要把 FinanceEngine 移到 Cloud Functions。消費前評估必須能在手機端離線完成。

## CloudKit 與 iCloud

- 不使用 CloudKit 同步 PayReview 財務資料。
- 不建立 CloudKit 與 Firestore 雙向同步。
- iCloud Backup 可依使用者系統設定備份本機 App 資料，但不是 PayReview 的跨裝置同步來源。
- 正式跨裝置同步只以 Firebase Authentication + Cloud Firestore 提供。

## 訂閱

使用 StoreKit 2，不在 MVP 導入額外訂閱服務。

| 方案 | 價格 | 試用 |
| --- | ---: | --- |
| 年費 | NT$800／年 | 符合資格者可試用七天 |
| 月費 | NT$120／月 | 預設無試用 |

實作要求：

- 以 StoreKit 回傳的在地化價格顯示。
- 顯示週期、試用資格、試用轉付費、續訂與取消方式。
- 支援 Restore Purchases 與 entitlement 更新。
- 在付費功能邊界確認前，不啟用正式付費牆。

## 權限與隱私

| 權限或資料 | MVP 做法 |
| --- | --- |
| 通知 | 使用者啟用提醒後才請求 |
| 相簿、相機、位置、聯絡人 | 不請求 |
| 銀行、信用卡、LINE、支付訊息 | 不讀取、不請求 |
| 財務資料 | Firestore 儲存與同步 |
| 尚未確認的消費試算 | 記憶體或短期本機暫存，不寫入正式資料 |

在 App、官網、App Store 隱私標示與隱私權政策中，清楚說明 Firebase Authentication、Firestore、Analytics、Crashlytics 與 Cloud Functions 的資料用途。

## Analytics 與 Crashlytics

使用 Firebase Analytics 追蹤經核准的 AARRR 事件，使用 Crashlytics 診斷當機與非致命錯誤。

不得傳送：

- 精確收入、預算、支出或目標金額。
- 商店名稱、目標名稱、備註、標籤或其他自由文字。
- Email、姓名、Token、完整 `DecisionSnapshot` 或其他可識別資料。

需要分析金額影響時，只傳送經隱私審查的區間。Crashlytics log 與 custom key 也必須遵守相同限制。

## 建議專案結構

```text
PayReview/
  App/
  Features/
    Onboarding/
    Today/
    Evaluate/
    Plan/
    Records/
    Settings/
  Core/
    FinanceEngine/
    Domain/
    DesignSystem/
  Data/
    Repositories/
    Firebase/
  Services/
    Authentication/
    Subscription/
    Notifications/
    Analytics/
  Tests/
    FinanceEngineTests/
    FeatureTests/
    FirestoreRulesTests/
```

## 進入開發前清單

1. 建立 SwiftUI App 與 Firebase iOS App。
2. 在 Firebase Authentication 啟用 Apple 與 Google 登入。
3. 建立 Firestore schema 與 repository data source。
4. 撰寫 Firestore Security Rules，並用 Firebase Emulator 測試使用者隔離。
5. 建立 Firestore 離線、重連、pending write 與去重複測試。
6. 建立獨立 `FinanceEngine` 及金額、日期、目標、頻率與重複扣款測試。
7. 確認免費與訂閱功能邊界，再建立 App Store Connect 商品。
8. 完成 Firebase SDK 隱私盤點、App Store 隱私標示與政策說明。
9. 完成資料匯出、帳號刪除、客服、隱私政策與使用條款。
10. 每次 TestFlight 或上架前執行 `skills/payreview-release-check/SKILL.md`。
