# 花算 PayReview 技術選型 v0.1

## 技術目標

花算 PayReview 的第一版是 iOS-first 的個人財務決策 App。技術選型要支援三件事：

1. 消費前試算必須快速、可離線使用、可測試。
2. 使用者登入後可安全同步自己的計畫、交易與決策紀錄。
3. 不連結銀行或支付帳戶也能完整使用核心功能。

## 結論

| 層級 | 選擇 | 用途 |
| --- | --- | --- |
| App | Swift、SwiftUI | iOS 原生介面與動畫 |
| 財務計算 | 獨立 Swift `FinanceEngine` 模組 | 預算、目標、日期與比價計算 |
| 雲端資料庫 | Cloud Firestore | 登入後的資料同步與離線快取 |
| 帳號 | Firebase Authentication | Sign in with Apple、Google 登入、帳號生命週期 |
| 內購訂閱 | StoreKit 2 | 年費、月費、試用、恢復購買 |
| 後端安全工作 | Firebase Cloud Functions | 帳號刪除與不可相信客戶端的伺服器端任務 |
| 分析與錯誤 | Firebase Analytics、Crashlytics | AARRR 事件與當機診斷 |
| 通知 | UserNotifications | App 內提醒啟用後的本機通知 |
| 開源聲明 | LicensePlist | 產生 Settings bundle 的第三方授權資訊 |

MVP 建議支援 **iOS 17 以上**，以使用現代 SwiftUI、Swift Concurrency 與 SwiftData 作為匿名試用資料的本機儲存。

## iOS App

### SwiftUI

使用 SwiftUI 建立所有畫面與狀態導向導航：

- 今天：安心可花額度、下一筆預期支出、目標狀態、評估入口。
- 評估：快速金額輸入、價格比較、Decision Card、購買或延後選項。
- 計畫：目標、收入週期、固定支出、彈性預算與安全緩衝。
- 紀錄：收入、支出、轉帳、類別、標籤與歷史分析。
- 設定：登入、訂閱、通知、隱私、資料匯出、帳號刪除與客服。

使用原生 SwiftUI 動畫實作 Icon 開啟與 Decision Card 依序出現的效果。必須尊重系統的 Reduce Motion 設定。

### FinanceEngine

建立不依賴 SwiftUI 或 Firebase 的 Swift 模組。這是產品最重要的商業邏輯層，必須能離線執行與單元測試。

職責：

- 保留必要與預期型支出後，計算彈性可花額度。
- 計算 `within_flexible`、`uses_buffer`、`requires_plan_change` 三種決策狀態。
- 計算消費頻率、目標最低儲蓄速度、目標影響與恢復方案。
- 計算手動輸入商店方案的最終實付與單位價格。
- 產生可儲存的 `DecisionSnapshot`。

技術規則：

- 所有貨幣使用 `Decimal`，不可使用 `Double` 或 `Float`。
- 所有日期使用 `Calendar` 與明確時區，避免月底、閏年與跨時區錯誤。
- 財務計算不可由生成式 AI 決定；AI 未來只能將既有結果改寫成易懂文案。
- 所有程式碼註解使用英文，專案不使用 emoji。

### 本機資料

| 情況 | 儲存方式 |
| --- | --- |
| 未登入的試用使用者 | SwiftData 本機資料 |
| 已登入使用者 | Firestore 資料與 Firebase 的離線持久化快取 |
| 尚未確認的消費試算 | 僅本機暫存，不寫入交易歷史 |

使用者建立帳號時，必須讓他明確確認是否把本機試用資料遷移到 Firebase。

## Firebase

### Firebase Authentication

支援以下登入方式：

- Sign in with Apple。
- Google Sign-In。
- 未登入試用模式。

登入不是開始使用的前提。只有備份、跨裝置同步或帳號功能需要登入時，才引導使用者建立帳號。

### Cloud Firestore

Firestore 是已登入使用者的唯一雲端同步來源。建議以使用者 `uid` 隔離所有資料：

```text
users/{uid}/profile
users/{uid}/financialPlan
users/{uid}/goals/{goalId}
users/{uid}/plannedExpenses/{expenseId}
users/{uid}/transactions/{transactionId}
users/{uid}/transfers/{transferId}
users/{uid}/categories/{categoryId}
users/{uid}/tags/{tagId}
users/{uid}/decisionSnapshots/{snapshotId}
users/{uid}/priceComparisons/{comparisonId}
users/{uid}/deferredPurchases/{purchaseId}
```

Firestore Security Rules 必須限制使用者只能讀寫自己的 `uid` 路徑。不得使用公開讀寫規則，也不得將 Firebase service account 或其他伺服器端機密提交到 Git。

### Cloud Functions

第一版只在確實需要受信任伺服器端處理時使用：

- 刪除帳號時，協調刪除 Firestore、Firebase Storage 與 Firebase Authentication 的資料。
- 未來如有伺服器端匯出或需驗證的 Webhook，再以最小權限新增。

不要把 FinanceEngine 放在 Cloud Functions。消費前評估必須可以離線完成，並在手機端立即顯示。

### Firebase Storage

第一版不必儲存使用者截圖。若 P1 加入截圖 OCR 或資料匯入，才以 Firebase Storage 儲存使用者主動保留的原始檔，並提供刪除與保留期限。

### Analytics 與 Crashlytics

使用 Firebase Analytics 追蹤必要的 AARRR 事件，例如：

- `initial_launch`
- `session_started`
- `screen_viewed`
- `onboarding_completed`
- `first_decision_card_viewed`
- `decision_evaluated`
- `purchase_recorded`
- `trial_started`
- `subscription_started`

Analytics 不得傳送原始金額、商店名稱、目標名稱、備註、標籤或其他自由輸入的財務內容。以類別、區間或布林值取代。

使用 Crashlytics 處理當機與非致命錯誤；上傳前確認錯誤紀錄不含金融內容、驗證 Token 或個人資料。

## iCloud 的定位

iCloud 可以作為使用者 Apple 裝置的系統備份選項，協助保留未登入試用資料。它不是 Firestore 之外的第二套即時同步資料庫。

原因是同一筆財務資料同時由 CloudKit 與 Firestore 同步，會產生衝突、重複交易與難以解釋的覆寫問題。正式的跨裝置同步以 Firebase 帳號與 Firestore 為準；若未來要完全改成 Apple-only 產品，才評估以 CloudKit 取代 Firebase，而不是兩者並行。

## 訂閱

使用 **StoreKit 2**，不在 MVP 導入額外訂閱服務。

| 方案 | 價格 | 試用 |
| --- | ---: | --- |
| 年費 | NT$800／年 | 符合資格者可試用七天 |
| 月費 | NT$120／月 | 預設無試用 |

功能需求：

- 顯示價格、週期、試用條件、續訂方式與取消途徑。
- 支援 Restore Purchases。
- 以 StoreKit entitlement 作為 App 內存取依據。
- 使用者在設定頁可前往系統訂閱管理。

若未來推出 Android 或 Web 付費版，再評估 RevenueCat 或自己的訂閱後端；不要在第一版同時導入。

## 權限與隱私實作

| 權限或資料 | MVP 做法 |
| --- | --- |
| 通知 | 使用者開啟提醒後才請求 `UserNotifications` 權限 |
| 相簿 | MVP 不請求；P1 截圖匯入時才先說明再請求 |
| 銀行、信用卡、LINE、支付訊息 | MVP 不讀取、不請求 |
| 位置、聯絡人、相機 | MVP 不需要 |
| 財務計畫與交易 | 僅為提供決策、同步、匯出與使用者明確選擇的功能而儲存 |

帳號刪除必須能從 App 設定頁開始。若將使用者導向網頁，該網頁必須是已驗證身分的實際刪除流程，不可只是客服信箱或聯絡表單。

## 開發工具與套件

| 類別 | 選擇 | 備註 |
| --- | --- | --- |
| IDE | Xcode | 建置、測試、簽署與 App Store 上傳 |
| 套件管理 | Swift Package Manager | 安裝 Firebase、Google Sign-In、LicensePlist 等依賴 |
| Firebase SDK | Firebase iOS SDK | Auth、Firestore、Functions、Analytics、Crashlytics、Storage（需要時） |
| Google 登入 | Google Sign-In for iOS | 搭配 Firebase Authentication |
| 單元測試 | Swift Testing 或 XCTest | FinanceEngine 必須有完整測試 |
| UI 測試 | XCUITest | 新手流程、登入、購買、刪除帳號等關鍵路徑 |
| 發版 | Xcode Cloud 或 GitHub Actions | MVP 先選一個，不重複設定兩套 CI |
| App Store 作業 | App Store Connect 與 ASC CLI | 人工確認後才上傳或送審 |

## 建議專案結構

```text
PayReview/
  App/
    PayReviewApp.swift
    AppRouter.swift
  Features/
    Onboarding/
    Today/
    Evaluate/
    PriceComparison/
    Plan/
    Records/
    Settings/
  Core/
    FinanceEngine/
    Domain/
    DesignSystem/
  Data/
    Repositories/
    LocalStore/
    Firebase/
  Services/
    Authentication/
    Subscription/
    Notifications/
    Analytics/
  Tests/
    FinanceEngineTests/
    FeatureTests/
```

Feature 的 SwiftUI View 不能直接呼叫 Firestore。View 透過 ViewModel 或 Observation state 使用 Repository；Repository 再選擇本機或 Firebase 資料來源。

## MVP 不納入的技術

- 自建 API 與自管伺服器。
- CloudKit 與 Firestore 的雙向同步。
- 銀行帳戶、信用卡或支付帳戶串接。
- LINE 或其他 App 的訊息爬取。
- 網路爬蟲與自動全網比價。
- 支付 App 上方覆蓋視窗或阻止付款。
- AI 決定財務計算結果。

## 進入開發前的設定清單

1. 建立 Xcode SwiftUI 專案與 Firebase iOS App。
2. 在 Firebase 啟用 Apple 與 Google 登入。
3. 設定開發、測試與正式環境的 Firebase 專案或清楚的環境隔離規則。
4. 撰寫 Firestore Security Rules，先用 Firebase Emulator 測試跨使用者隔離。
5. 建立 `FinanceEngine` 與金額、日期、目標、比價的單元測試。
6. 在 App Store Connect 建立年費與月費商品，完成試用與訂閱文案。
7. 設定隱私政策、使用條款、客服入口、資料匯出與帳號刪除流程。
8. 每次 TestFlight 與上架前執行 `skills/payreview-release-check/SKILL.md` 的檢查。
