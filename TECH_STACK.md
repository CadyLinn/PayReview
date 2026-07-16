# PayReview 技術選型 v0.2

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
| 財務計算 | 獨立 Swift `FinanceEngine` | 預算、目標日期與恢復方案 |
| 資料庫 | Cloud Firestore | 正式財務資料、持久化快取與跨裝置同步 |
| 帳號 | Firebase Authentication | Sign in with Apple、Google 登入與帳號生命週期 |
| 後端工作 | Firebase Cloud Functions、Google Cloud Tasks | 帳號狀態建立、durable 帳號刪除與其他不可信任客戶端的操作 |
| 內購訂閱 | StoreKit 2 | 年費、月費、試用、權益與恢復購買 |
| 分析 | Firebase Analytics | 經隱私審查的 AARRR 事件 |
| 錯誤監控 | Firebase Crashlytics | 當機與非致命錯誤診斷 |
| 開源聲明 | LicensePlist | 產生第三方授權資訊 |

MVP 建議支援 iOS 17 以上，以使用現代 SwiftUI 與 Swift Concurrency。正式最低版本仍須由團隊確認。

## 明確不納入 MVP

- 自動爬取商城價格、折扣、優惠券或商品資料。
- CloudKit 或 Firebase 以外的第二套財務同步來源。
- 銀行、信用卡或支付帳戶串接。
- Share Extension、截圖 OCR 與自動擷取價格。
- 網路爬蟲與商城功能。
- AI 決定或修改財務計算結果。

MVP 可提供使用者手動輸入的方案比較，計算實付金額、額外購買內容與對既有目標的機會成本。比較結果必須由本機可測試的規則產生，不得宣稱已找到市場最低價。

## SwiftUI App

使用 SwiftUI 建立：

- 今天：安心可花額度、下一筆預期支出、目標狀態與評估入口。
- 評估：快速金額輸入、預算與目標影響、恢復方案、購買或延後選項。
- 計畫：目標、收入週期、固定支出、彈性預算與安全緩衝。
- 紀錄：收入、支出、轉帳、類別、標籤與回顧。
- 設定：登入、訂閱、隱私、資料匯出、帳號刪除與客服。通知設定待 P1 加入本機通知時再提供。

### 原生 SwiftUI 元件原則

1. 導覽使用 `NavigationStack`、`navigationDestination`、`sheet` 與 `TabView`。
2. 設定與資料輸入優先使用 `Form`、`List`、`Section`、`TextField`、`Picker`、`DatePicker`、`Slider`、`Stepper` 與 `ProgressView`。
3. 按鈕、工具列、警告與確認使用 `Button`、`ToolbarItem`、`confirmationDialog` 與 `alert`；常見圖示使用 SF Symbols。
4. 優先採用 Apple 已提供的安全區域、padding、列間距、Dynamic Type、VoiceOver、深色模式與 Reduce Motion 行為，不用大量 `ZStack`、`offset` 或硬編碼座標重畫系統元件。
5. 只有吉祥物對話框、品牌卡片、完成粒子與 PayReview 專屬資料視覺可以建立自訂 View，且仍須支援 Dynamic Type 與至少 44 × 44 pt 點擊範圍。
6. Figma 的浮動底部導覽在 SwiftUI 中優先對應原生 `TabView`，不直接照像素重建。

### Prototype 對應流程

首次設定使用 `C Setup Income → D Setup Expenses → E Setup Budget → F Setup Complete → A5 Building Plan · 自訂目標`。方案 A 整合測試使用 `NT$960`、類別 `購物`、超出可用額度 `NT$280` 的 fixture，並驗證 B2、D4a、D5a 的資料一致性。

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
- 以剩餘彈性預算與保守安心可花下限中較低者作為 `classified_spendable_before`，再計算 `within_flexible`、`uses_buffer`、`requires_plan_change` 與 `insufficient_data`。
- 計算最低儲蓄速度、目標日期影響與恢復方案。
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
accountStates/{uid}  # server-owned; client read-only
deletionRequests/{requestId}  # server-owned; status only
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

比較方案與 `SpendScenario` 在確認前只保留於本機，不寫入 Firestore，也不得自動建立交易。

## Firebase Authentication

支援：

- Sign in with Apple。
- Google Sign-In。

使用者必須使用 Apple 或 Google 帳號登入後才能進入首次設定與核心功能。不使用 Firebase Anonymous Authentication，也不提供訪客模式。

受信任後端必須在首次帳號建立時，以 Firebase token 的 `uid` 而非用戶端參數建立 `accountStates/{uid}`，初始狀態為 `active`。建立操作使用 transaction：文件不存在時建立、已是 `active` 時視為 idempotent success、已是 `deleting` 或 `deleted` 時永久拒絕覆寫或重新啟用。不得提供接受 caller-supplied `uid` 的初始化 API。Security Rules 只有在此 server-owned 文件存在且狀態恰為 `active` 時才允許使用者資料寫入；文件缺失、讀取失敗、`deleting` 或 `deleted` 一律拒絕。用戶端必須等候 account state 建立成功後才能開始首次設定。

跨裝置財務計畫與紀錄連續性是 MVP 的重要帳號功能，Firestore 是唯一正式資料來源。送審前必須依當時有效的 App Review Guideline 5.1.1(v) 再次驗證強制登入的必要性；若無法證明帳號對核心功能具有必要性，必須阻擋送審並先調整登入方案。

首次登入需要網路。若裝置已有有效登入狀態，且 Firestore 有可用快取，才允許在離線狀態進入可用的核心畫面。

帳號刪除必須從 App 內開始，且採用以下順序：

1. 要求近期重新驗證。Sign in with Apple 使用者必須取得新的 authorization code，並呼叫 `Auth.auth().revokeToken(withAuthorizationCode:)` 撤銷 Apple 授權。
2. 停止新的本機寫入並呼叫 `waitForPendingWrites`，最長等待 30 秒，且使用者可隨時取消等待。權限拒絕、驗證失效等 terminal error 立即停止等待；逾時、取消或 terminal error 時提供「重試同步」、「取消刪除」與「刪除帳號並捨棄未同步變更」。只有第三個選項經獨立的不可復原確認後，才可連同明確列出的 local-only 變更一併捨棄。帳號刪除需要網路，不得在離線時假裝完成。
3. 以穩定的 deletion request ID 呼叫受信任的 Cloud Function。Function 驗證 Firebase token 的 `auth_time` 符合近期重新驗證門檻，在 transaction 中把 `accountStates/{uid}` 從 `active` 改為 `deleting`，建立 server-owned deletion job，排入可持續重試的後端佇列，並只在以上操作全部持久化後回傳高熵度 opaque receipt。
4. 只有收到已持久化的 deletion receipt 後，App 才終止 Firestore instance、清除 persistent cache、未確認 `SpendScenario`、notes、snapshots 及其他本機敏感資料，然後登出。若 request 尚未被後端接受，App 必須保留 Firebase session 並顯示可重試錯誤，不得宣稱刪除已開始。
5. Durable backend job 遞迴刪除該 `uid` 的 Firestore 文件及相關雲端檔案，再刪除 Firebase Authentication 身分。所有步驟以同一 request ID 保證 idempotency；部分失敗由後端獨立重試，不依賴已登出的 client 或再次取得 Apple authorization code。
6. Firebase Authentication 刪除確認後，把 account state 設為 `deleted`。Tombstone 只保留 `uid`、狀態、request ID hash 與時間戳，至少保留完成後七天且不得由使用者修改；保留期限與用途必須寫入隱私政策。七天後只有在 Firebase Authentication 已確認不存在、沒有未完成 deletion job，且沒有任何 Admin 流程重用或自訂該舊 `uid` 時才可清除 tombstone；任一條件不成立就繼續保留並告警。所有新帳號必須由 Firebase Authentication 產生新 `uid`，禁止重用已刪除 `uid`。Opaque receipt 查詢只回傳 job status、不回傳個人或財務資料，七天後失效；receipt 遺失不影響後端繼續刪除。

不可只提供客服 Email 或一般表單。一般帳號切換必須有網路，停止新寫入並成功完成 `waitForPendingWrites`，最長等待 30 秒且可由使用者取消；逾時、取消、terminal error 或仍有 pending write 時，一律取消切換並保留目前帳號，不得為了切換而捨棄已確認的財務操作。成功後終止 Firestore instance、清除 persistent cache 與本機敏感資料，之後才能啟動新 `uid` 的資料工作階段。cache 清除失敗時必須阻擋新帳號進入核心功能。

## Firestore 安全與一致性

- Security Rules 必須限制使用者只能讀寫自己的 `uid` 路徑。
- Security Rules 必須另外檢查 server-owned account state；只有明確的 `active` 狀態允許使用者資料寫入，文件缺失、讀取失敗、`deleting` 或 `deleted` 一律拒絕，且用戶端不得建立、修改或刪除該狀態。
- 不得使用公開讀寫規則。
- 不得將 service account、私鑰或其他伺服器端機密提交到 Git。
- 交易建立與預期支出完成需要具備 idempotency，避免重複點擊或離線重試造成重複扣款。
- 為重要文件保留 schema version、createdAt、updatedAt 與必要的 rule version。
- 明確處理 server timestamp 尚未解析、離線 pending write 與刪除同步狀態。
- Firestore 離線 enqueue 可以更新 pending UI，但快取的 `active` 狀態不構成授權。恢復連線時由 Security Rules 讀取即時 server-owned account state；若伺服器拒絕寫入，Repository 必須回滾 optimistic state、標示該操作未保存並提供重試或修正入口。
- 使用 Firebase Emulator 測試跨使用者隔離、拒絕未授權寫入與資料驗證。
- 使用 Emulator 測試缺失 account state 與 deletion tombstone 都會拒絕新寫入、舊 token 寫入與離線 pending-write 重送，且初始化 function 無法覆寫 `deleting` 或 `deleted`。
- 測試登出、帳號切換與帳號刪除後的 cache 清除，確保新的 `uid` 無法讀取前一帳號的快取或本機敏感資料。
- 測試 pending-write 的成功、terminal error、使用者取消及 30 秒逾時分支，並測試 tombstone 清理不會在 Auth 身分或 deletion job 尚存時執行。

## Cloud Functions

只用於必須信任伺服器端的工作：

- 在首次登入時只從已驗證 token 取得 `uid`，以 fail-closed transaction 建立 server-owned `accountStates/{uid}`；不得接受 caller-supplied `uid` 或重新啟用已刪除狀態。
- 以穩定 request ID、durable queue 與最小化 deletion-status receipt 協調 Firestore、雲端檔案與 Firebase Authentication 的完整帳號刪除，並在 client 登出後繼續安全重試。
- 未來需要驗證的 Webhook 或伺服器端匯出。

不要把 FinanceEngine 移到 Cloud Functions。消費前評估必須能在手機端離線完成。

實作帳號刪除時依循 [Firebase Sign in with Apple token revocation](https://firebase.google.com/docs/auth/ios/apple#token_revocation) 與 [Apple account deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app)，並在每次送審前重新確認現行要求。

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
| 通知 | MVP 不實作或請求；P1 再加入本機提醒 |
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
    Analytics/
  Tests/
    FinanceEngineTests/
    FeatureTests/
    FirestoreRulesTests/
```

## 進入開發前清單

1. 確認現有 SwiftUI App 與 Firebase iOS App 可在乾淨環境建置。
2. 在 Firebase Authentication 啟用 Apple 與 Google 登入。
3. 建立 Firestore schema 與 repository data source。
4. 撰寫 Firestore Security Rules，並用 Firebase Emulator 測試使用者隔離。
5. 建立 Firestore 離線、重連、pending write、帳號切換 cache 隔離與去重複測試。
6. 建立獨立 `FinanceEngine` 及金額、日期、目標與重複扣款測試。
7. 確認免費與訂閱功能邊界，再建立 App Store Connect 商品。
8. 完成 Firebase SDK 隱私盤點、App Store 隱私標示與政策說明。
9. 完成資料匯出、Apple 授權撤銷、可重試的完整帳號刪除、本機清除、客服、隱私政策與使用條款。
10. 每次 TestFlight 或上架前執行 `skills/payreview-release-check/SKILL.md`。
11. 以原生 SwiftUI 導覽先完成可點擊的 C→F→A5 骨架，再逐頁套用 PayReview 品牌 View。
12. 加入方案 A 的 NT$960／購物／超出 NT$280 UI fixture 測試，並確認正式 View 不硬編碼測試數字。
