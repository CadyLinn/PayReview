# PayReview

PayReview 是一款在付款前協助使用者理解價格、預算影響與恢復方案的個人財務決策產品。

> 花錢前，先算價格與影響。

目前專案處於產品原型與 MVP 開發階段，介面、財務規則及雲端架構仍會持續調整。

## 官方資源

[PayReview 官方網站](https://payreview.yytttt420.chatgpt.site/)

[查看 PayReview Figma 互動原型](https://www.figma.com/proto/XtdsfXhoOOPbBdrvvt1AZT/PayReview?node-id=274-166&t=M1VCGDrYjRdRyyvK-0&scaling=min-zoom&content-scaling=fixed&page-id=66%3A5&starting-point-node-id=292%3A192&show-proto-sidebar=1)

[查看 PayReview Student Creator 專案頁](https://studentcreator.tw/apps/9220dab4-cc7a-4445-94be-c1ce51984231?event=848c34a8-d4da-4f02-9687-4d19335865cf)

## 產品方向

PayReview 會在消費發生前協助使用者了解：

1. 現在購買會帶來什麼改變。
2. 這筆消費是否影響預算或目標日期。
3. 哪些調整方式可以保留原本的預算或目標。

產品提供消費前評估、安心可花估算、固定支出管理、比價方案比較與交易紀錄等功能。系統只呈現計算結果與可行選項，不替使用者做最後決定。

## 核心功能

- 在付款前評估消費對彈性預算及財務目標的影響。
- 顯示安心可花估算與計算所採用的財務假設。
- 將評估情境與正式交易分開，只有確認購買後才建立紀錄。
- 管理收入週期、固定支出、彈性預算、安全緩衝及儲蓄目標。
- 比較兩個購買方案的實付金額、額外內容與機會成本。
- 支援收入、支出及轉帳紀錄；轉帳不計入收入或支出。

## 產品原則

- 提供資訊與調整選項，不替使用者做消費決定。
- 使用中性、不批判的語氣說明財務影響。
- 使用 `Decimal` 處理金額，不以浮點數計算貨幣。
- 消費評估不會直接修改正式預算、目標或交易紀錄。
- AI 僅能解釋已計算的結果，不能自行改寫財務數字。

## 技術方向

- iOS App：SwiftUI
- 驗證：Firebase Authentication
- 資料同步：Cloud Firestore
- 金額計算：使用 `Decimal` 的確定性財務規則

## Agentic AI 開發方式

PayReview 將 Agentic AI 用於產品與工程協作，不讓生成式 AI 直接決定或修改財務結果。Agent 會先讀取 repository 規則與產品規格，再依任務載入專用 Skill、修改程式、執行驗證並回報風險；涉及發布、金融規則、隱私或架構決策時，仍由團隊成員確認。

目前 repository 提供兩個 PayReview 專用 Skill：

| Skill | 使用時機 | 主要功能 |
| --- | --- | --- |
| `evaluate-impulse-spend` | 實作、測試或檢視消費前評估與 Decision Card | 驗證輸入、計算安心可花範圍、分類評估狀態、分析目標影響、產生恢復選項，並確保評估不會提前建立交易 |
| `payreview-release-check` | TestFlight、App Store 審核、預購或正式發布前 | 檢查財務完整性、隱私與帳號、訂閱、商店素材、法務、品質及發布授權，輸出 `pass`、`block`、`not applicable` 與 `GO`／`NO-GO` 報告 |

完整設計、執行流程及人工審核界線請參閱 [Agentic AI 與團隊協作](docs/agentic-ai-team-workflow.md)。

## 專案結構

```text
PayReview/
  App/            App 啟動與 Firebase 設定
  Core/           領域模型、財務規則與設計系統
  Data/           Repository 與資料存取
  Features/       Onboarding、Today、Plan、Records 等功能
  Services/       Authentication 與外部服務介面
firebase/         Firestore Rules 與索引
docs/             工程與資料模型文件
skills/           PayReview 專用 Agent 工作流程
```

## 開發需求

- macOS 與目前團隊核准版本的 Xcode
- iOS 17 或更新版本
- 已設定的 Firebase 專案
- Google Sign-In 所需的 iOS URL Scheme 與 Firebase Authentication 設定

請勿將個人測試資料、憑證、權杖、產生的建置檔案或 Xcode `xcuserdata` 提交到版本庫。

## 開始開發

1. Clone 此 repository。
2. 使用 Xcode 開啟 `PayReview.xcodeproj`。
3. 確認 Firebase 與 Google Sign-In 設定屬於正確的開發環境。
4. 選擇支援的 iOS Simulator 或測試裝置。
5. 建置並執行 `PayReview` target。

變更財務計算、日期、目標、交易確認或同步行為時，必須同步新增或更新測試。

## 專案文件

- [產品計畫](PRODUCT_PLAN_V0.2.md)
- [產品上線計畫](PRODUCT_LAUNCH_PLAN_V0.2.md)
- [技術架構](TECH_STACK.md)
- [Firestore 資料模型](docs/firestore-data-model.md)
- [Agentic AI 與團隊協作](docs/agentic-ai-team-workflow.md)

## 團隊與作者

PayReview 由 **PayReview Team** 設計與開發。

依 repository 提交紀錄整理的目前主要分工如下：

| 成員 | 主要角色 | 負責範圍 |
| --- | --- | --- |
| Cady | PM、產品與 iOS 整合 | 產品規格、上線規劃、Onboarding、登入體驗、技術決策、專用 Skill 與跨功能整合 |
| machshyi | UI/UX 與日常體驗 | Figma 對齊、Today、Plan、Records、日常財務互動與產品文件協作 |
| eli_liao | Firebase、驗證與資料安全 | Authentication、Firestore、Security Rules、帳號狀態、後端流程與資料模型 |

所有成員共同負責 Agentic AI 任務拆解、輸出檢視、測試驗證與 Pull Request review。此分工依目前 commit authorship 與修改範圍整理，正式職稱及責任歸屬仍以團隊確認版本為準。

## 貢獻方式

這是團隊協作專案。進行修改前請先閱讀 [AGENTS.md](AGENTS.md)，並遵循產品、隱私、測試及 Git 工作流程規則。

- 使用功能分支進行開發。
- 保持 commit 聚焦並使用清楚的命令式訊息。
- 提交 Pull Request 供團隊檢視。
- 未經明確授權，不得提交秘密、個人財務資料或使用者識別資訊。

## 授權

Copyright © 2026 PayReview Team. All rights reserved.

本 repository 目前不是開源專案。除非取得 PayReview Team 的事前書面許可，不得複製、修改、散布、再授權或商業使用本專案的程式碼、設計、文件與品牌資產。完整條款請參閱 [LICENSE](LICENSE)。

本授權聲明不會取代第三方套件各自的授權條款；發布前仍須產生並審查第三方授權聲明。
