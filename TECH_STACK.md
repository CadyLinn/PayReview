# 花算 PayReview 技術選型 v0.2

## 技術目標

PayReview MVP 是 iOS-first 的本機優先個人財務決策 App。技術架構必須確保：

1. 消費前評估快速、可離線、可測試。
2. 試算不會在確認前修改正式財務資料。
3. 不連結銀行、支付帳戶或雲端同步也能完整使用核心功能。
4. 未來能在不改寫財務規則的前提下加入帳號或單一雲端同步來源。

## MVP 技術結論

| 層級 | MVP 選擇 | 用途 |
| --- | --- | --- |
| App | Swift、SwiftUI | iOS 原生介面、導航與動畫 |
| 財務計算 | 獨立 Swift `FinanceEngine` 模組 | 預算、目標、頻率、日期與恢復方案 |
| 本機資料 | SwiftData | 財務計畫、交易、分類與決策紀錄 |
| 跨裝置同步 | 不納入 MVP | 完成架構決策後再選擇單一雲端來源 |
| 帳號 | Sign in with Apple、Google OAuth | 帳號功能；不得宣稱提供尚未實作的財務同步 |
| 內購訂閱 | StoreKit 2 | 年費、月費、試用、權益與恢復購買 |
| 通知 | UserNotifications | 使用者啟用提醒後的本機通知 |
| 開源聲明 | LicensePlist | 產生第三方授權資訊 |
| 分析與錯誤 | 待隱私評估後各選一套 | 產品漏斗與當機診斷 |

MVP 建議支援 iOS 17 以上，以使用現代 SwiftUI、Swift Concurrency 與 SwiftData。正式最低版本仍須由團隊確認。

## 明確不納入 MVP

- 商店方案、折扣、優惠券、單價或任何比價功能。
- CloudKit、Firestore 或其他 App 層級跨裝置財務資料同步。
- 銀行、信用卡或支付帳戶串接。
- Share Extension、截圖 OCR 與自動擷取價格。
- 網路爬蟲與商城功能。
- 自建 API 與自管伺服器。
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

- View 不直接計算財務結果或操作 SwiftData。
- View 透過 feature state 或 ViewModel 使用 Repository protocol。
- Repository 隔離 SwiftData 實作，保留未來替換或增加同步層的可能性。
- 動畫必須尊重 Reduce Motion。
- 關鍵流程支援 Dynamic Type、VoiceOver 與本地化金額／日期。

## FinanceEngine

建立不依賴 SwiftUI、SwiftData、登入、分析或網路服務的 Swift 模組。

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

## SwiftData

MVP 的正式財務資料只儲存在 SwiftData：

| 資料 | MVP 儲存方式 |
| --- | --- |
| 財務計畫與目標 | SwiftData |
| 預期支出與彈性預算 | SwiftData |
| 正式交易、分類與標籤 | SwiftData |
| 延後或略過的決策 | SwiftData，由使用者選擇保存 |
| 尚未確認的 `SpendScenario` | 記憶體或暫存，不寫入正式交易 |
| `DecisionSnapshot` | 確認保存或交易後寫入 SwiftData |

資料完整性規則：

- `SpendScenario` 不得改變正式預算。
- 建立交易與完成對應預期支出必須是單一一致操作。
- 重複點擊或重試不得建立重複交易。
- 轉帳不計入收入或支出。
- 刪除、匯出與資料模型 migration 必須有測試。

## 帳號與同步界線

登入不是核心功能的前提。MVP 財務資料即使登入後仍保留在 SwiftData，不得在 UI 或 App Store 文案中宣稱帳號會提供財務資料備份或跨裝置同步。

未來加入同步前，必須提交 Architecture Decision Record，至少決定：

1. 唯一雲端資料來源是 CloudKit、Firestore 或其他方案。
2. 本機與雲端的資料所有權。
3. 衝突解決與離線重試。
4. 刪除傳播與帳號生命週期。
5. 本機資料遷移與回復策略。
6. 權限、安全、隱私與營運成本。

禁止同時使用 CloudKit 與 Firestore 雙向同步同一份財務資料。

## 訂閱

使用 StoreKit 2，不在 MVP 導入額外訂閱服務。

| 方案 | 價格 | 試用 |
| --- | ---: | --- |
| 年費 | NT$800／年 | 符合資格者可試用七天 |
| 月費 | NT$120／月 | 預設無試用 |

實作要求：

- 以 StoreKit 回傳的在地化價格顯示，不在正式 UI 寫死價格字串。
- 顯示週期、試用資格、試用轉付費、續訂與取消方式。
- 支援 Restore Purchases 與 entitlement 更新。
- 在付費功能邊界確認前，不啟用正式付費牆。

## 權限與隱私

| 權限或資料 | MVP 做法 |
| --- | --- |
| 通知 | 使用者啟用提醒後才請求 |
| 相簿、相機、位置、聯絡人 | 不請求 |
| 銀行、信用卡、LINE、支付訊息 | 不讀取、不請求 |
| 財務計畫與交易 | 儲存在 SwiftData，供決策、匯出與使用者選擇的功能使用 |

若 App 支援建立帳號，設定頁必須能發起完整帳號刪除。導向網頁時，該頁必須是已驗證身分的實際刪除流程，不能只提供 Email 或一般表單。

## 分析與錯誤監控

先定義產品問題，再各選一個主要工具：

- 產品分析：TelemetryDeck 或 Firebase Analytics。
- 錯誤監控：Sentry 或 Crashlytics。

導入前必須完成 SDK 資料盤點與隱私標示。不得傳送精確財務金額、商店名稱、目標名稱、備註、標籤、自訂文字、Token 或個人資料。

## 開發工具

| 類別 | 選擇 |
| --- | --- |
| IDE | Xcode |
| 套件管理 | Swift Package Manager |
| 單元測試 | Swift Testing 或 XCTest |
| UI 測試 | XCUITest |
| CI | Xcode Cloud 或 GitHub Actions，MVP 只選一套 |
| App Store | App Store Connect 與經人工批准的 ASC CLI 流程 |

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
    LocalStore/
  Services/
    Authentication/
    Subscription/
    Notifications/
    Analytics/
  Tests/
    FinanceEngineTests/
    FeatureTests/
```

## 進入開發前清單

1. 確認最低 iOS 版本與專案模組邊界。
2. 建立 SwiftUI App、SwiftData schema 與 migration 測試策略。
3. 建立獨立 `FinanceEngine` 及金額、日期、目標、頻率與重複扣款測試。
4. 確認 MVP 是否必須登入；若需要，選定 authentication provider 並完成帳號刪除設計。
5. 確認免費與訂閱功能邊界，再建立 App Store Connect 商品。
6. 選定一套產品分析與一套錯誤監控工具，完成隱私盤點。
7. 完成隱私政策、使用條款、客服、資料匯出與帳號刪除流程。
8. 每次 TestFlight 或上架前執行 `skills/payreview-release-check/SKILL.md`。
