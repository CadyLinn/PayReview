import SwiftUI

private struct OnboardingPage: Identifiable {
    let id: Int
    let title: String
    let body: String
    let signalTitle: String
    let signalValue: String
}

struct OnboardingFlowView: View {
    let completion: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = 0
    @State private var isAnimating = false

    private let pages = [
        OnboardingPage(
            id: 0,
            title: "你想完成的目標，\n不該等到月底才被想起",
            body: "在每次付款前，先看見今天的選擇會把你帶向哪裡",
            signalTitle: "下一步",
            signalValue: "先看影響"
        ),
        OnboardingPage(
            id: 1,
            title: "先留住重要的，\n再看能花多少",
            body: "整理收入、必要支出與目標，讓每次建議都更貼近你的生活",
            signalTitle: "先預留",
            signalValue: "重要計畫"
        ),
        OnboardingPage(
            id: 2,
            title: "記帳有了目的，\n下一次更容易決定",
            body: "每筆紀錄都能用來改善下一次的消費決定",
            signalTitle: "評估後",
            signalValue: "再決定"
        ),
        OnboardingPage(
            id: 3,
            title: "先試算，\n決定後再記錄",
            body: "查看影響不會改變預算，只有確認購買後才會建立正式紀錄",
            signalTitle: "資料由你",
            signalValue: "完整掌握"
        )
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PayReviewTheme.background.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(pages) { page in
                    pageView(page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: selection)

            Button("略過介紹", action: completion)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PayReviewTheme.primary)
                .frame(minWidth: 88, minHeight: 44)
                .padding(.trailing, 12)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 0) {
            Text("PayReview")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PayReviewTheme.primaryText)
                .padding(.top, 18)

            Spacer(minLength: 28)

            hero(page)

            Spacer(minLength: 34)

            Text(page.title)
                .font(.title.weight(.bold))
                .foregroundStyle(PayReviewTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text(page.body)
                .font(.body)
                .foregroundStyle(PayReviewTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.top, 16)

            Spacer()

            Button(selection == pages.count - 1 ? "開始使用 PayReview" : "向左滑，看看記帳還能做到什麼") {
                if selection == pages.count - 1 {
                    completion()
                } else {
                    withAnimation { selection += 1 }
                }
            }
            .buttonStyle(PayReviewPrimaryButtonStyle())
            .padding(.horizontal, 24)

            HStack(spacing: 14) {
                ForEach(pages) { item in
                    Circle()
                        .fill(item.id == selection ? PayReviewTheme.primary : Color.clear)
                        .overlay(Circle().stroke(PayReviewTheme.secondaryText, lineWidth: 1))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.vertical, 30)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("介紹進度")
            .accessibilityValue("第 \(selection + 1) 頁，共 \(pages.count) 頁")
        }
    }

    private func hero(_ page: OnboardingPage) -> some View {
        ZStack {
            ForEach([184.0, 232.0, 286.0], id: \.self) { size in
                Circle()
                    .stroke(PayReviewTheme.safe.opacity(0.8), lineWidth: size == 232 ? 2 : 1)
                    .frame(width: size, height: size)
                    .scaleEffect(isAnimating && !reduceMotion ? 1.025 : 1)
            }

            Image("PayReviewMascot")
                .resizable()
                .scaledToFill()
                .frame(width: 168, height: 168)
                .clipShape(Circle())
                .scaleEffect(isAnimating && !reduceMotion ? 1.025 : 1)

            FinanceSignal(title: "今天可用", value: "NT$680")
                .offset(x: -112, y: -58)
            FinanceSignal(title: "日本旅遊", value: "11 個月")
                .offset(x: 108, y: -28)
            FinanceSignal(title: page.signalTitle, value: page.signalValue)
                .offset(x: -88, y: 98)
        }
        .frame(height: 300)
        .accessibilityElement(children: .combine)
    }
}

private struct FinanceSignal: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(PayReviewTheme.safe)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(PayReviewTheme.surface)
        }
        .padding(.horizontal, 12)
        .frame(width: 121, height: 58, alignment: .leading)
        .background(PayReviewTheme.darkRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 10, y: 8)
    }
}

#Preview {
    OnboardingFlowView(completion: {})
}
