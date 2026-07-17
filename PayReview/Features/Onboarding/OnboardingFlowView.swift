import SwiftUI

private enum OnboardingPage: Int, CaseIterable, Identifiable {
    case futureInSight
    case swipeDifference
    case revealImpact
    case personalRoute

    var id: Int { rawValue }
}

struct OnboardingFlowView: View {
    let completion: () -> Void
    let skip: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: OnboardingPage

    init(completion: @escaping () -> Void) {
        self.completion = completion
        skip = completion
        _selection = State(initialValue: .futureInSight)
    }

    init(
        startsAtFinalPage: Bool,
        completion: @escaping () -> Void,
        skip: @escaping () -> Void
    ) {
        self.completion = completion
        self.skip = skip
        _selection = State(initialValue: startsAtFinalPage ? .personalRoute : .futureInSight)
    }

    var body: some View {
        ZStack {
            PayReviewTheme.background.ignoresSafeArea()

            if reduceMotion {
                OnboardingDesignCanvas {
                    pageContent(selection)
                }
                .id(selection)
                .transition(.opacity)
                .gesture(reducedMotionSwipe)
            } else {
                TabView(selection: $selection) {
                    ForEach(OnboardingPage.allCases) { page in
                        OnboardingDesignCanvas {
                            pageContent(page)
                        }
                        .tag(page)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(PayReviewMotion.easeOut(PayReviewMotion.reveal), value: selection)
                .background(PayReviewTheme.background)
                .ignoresSafeArea()
            }
        }
    }

    private var reducedMotionSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let nextValue: Int
                if value.translation.width < -36 {
                    nextValue = min(selection.rawValue + 1, OnboardingPage.allCases.count - 1)
                } else if value.translation.width > 36 {
                    nextValue = max(selection.rawValue - 1, 0)
                } else {
                    return
                }
                guard let next = OnboardingPage(rawValue: nextValue), next != selection else { return }
                withAnimation(.easeOut(duration: 0.25)) { selection = next }
            }
    }

    @ViewBuilder
    private func pageContent(_ page: OnboardingPage) -> some View {
        switch page {
        case .futureInSight:
            FutureInSightPage(selection: $selection, skip: skip, isActive: selection == page)
        case .swipeDifference:
            SwipeDifferencePage(selection: $selection, skip: skip, isActive: selection == page)
        case .revealImpact:
            RevealImpactPage(selection: $selection, skip: skip, isActive: selection == page)
        case .personalRoute:
            PersonalRoutePage(selection: $selection, completion: completion, skip: skip, isActive: selection == page)
        }
    }
}

private struct OnboardingDesignCanvas<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 393, proxy.size.height / 852)

            content
                .frame(width: 393, height: 852)
                .scaleEffect(scale)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}

private struct FutureInSightPage: View {
    @Binding var selection: OnboardingPage
    let skip: () -> Void
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathes = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            PayReviewTheme.background

            Text("PayReview")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PayReviewTheme.primaryText)
                .frame(width: 345, alignment: .center)
                .position(x: 196.5, y: 44)
                .payReviewSlideReveal(isActive: isActive, edge: .bottom, delay: 0.05, distance: 18)

            ForEach([286.0, 232.0, 184.0], id: \.self) { size in
                Circle()
                    .stroke(PayReviewTheme.safe, lineWidth: size == 232 ? 2 : 1)
                    .frame(width: size, height: size)
                    .position(x: 196.5, y: 243)
                    .scaleEffect(breathes && !reduceMotion ? 1.012 : 1)
            }
            .payReviewDepthReveal(isActive: isActive, delay: 0.02)

            mascot(size: 168)
                .position(x: 196.5, y: 243)
                .scaleEffect(breathes && !reduceMotion ? 1.008 : 1)
                .modifier(PayReviewFloatingEffect())
                .payReviewDepthReveal(isActive: isActive, delay: 0.06)

            FinanceSignal(title: "今天可用", value: "NT$680")
                .position(x: 74.5, y: 180)
                .payReviewSlideReveal(isActive: isActive, edge: .leading, delay: 0.28, distance: 96)
            FinanceSignal(title: "日本旅遊", value: "11 個月")
                .position(x: 318.5, y: 211)
                .payReviewSlideReveal(isActive: isActive, edge: .trailing, delay: 0.38, distance: 96)
            FinanceSignal(title: "下一步", value: "先看影響")
                .position(x: 98.5, y: 343)
                .payReviewSlideReveal(isActive: isActive, edge: .leading, delay: 0.48, distance: 96)

            Text("你想完成的目標，\n不該等到月底才被想起")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(PayReviewTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .frame(width: 345)
                .position(x: 196.5, y: 478)
                .payReviewSlideReveal(isActive: isActive, edge: .leading, delay: 0.50)

            Text("在每次付款前，先看見今天的選擇會把你帶向哪裡")
                .font(.system(size: 16))
                .foregroundStyle(PayReviewTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(width: 317)
                .position(x: 196.5, y: 548)
                .payReviewSlideReveal(isActive: isActive, edge: .trailing, delay: 0.56)

            onboardingCapsule("向左滑，看看記帳還能做到什麼　›") {
                withAnimation(PayReviewMotion.easeOut(PayReviewMotion.reveal)) { selection = .swipeDifference }
            }
            .position(x: 196.5, y: 719)
            .payReviewSlideReveal(isActive: isActive, edge: .leading, delay: 0.64)

            PageIndicator(selection: selection)
                .position(x: 196.5, y: 796)
                .payReviewSlideReveal(isActive: isActive, edge: .bottom, delay: 0.70, distance: 24)

            skipButton(skip)
                .payReviewSlideReveal(isActive: isActive, edge: .trailing, delay: 0.12, distance: 32)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                breathes = true
            }
        }
    }
}

private struct SwipeDifferencePage: View {
    @Binding var selection: OnboardingPage
    let skip: () -> Void
    let isActive: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            PayReviewTheme.background
            onboardingHeader("01　不只回頭看", selection: $selection, previous: .futureInSight, skip: skip)
                .payReviewSlideReveal(isActive: isActive, edge: .bottom, delay: 0.02, distance: 20)

            Text("記帳的下一步，是在花錢\n前先知道結果")
                .font(.system(size: 29, weight: .bold))
                .foregroundStyle(PayReviewTheme.primaryText)
                .frame(width: 345, alignment: .leading)
                .position(x: 196.5, y: 110)
                .payReviewSlideReveal(isActive: isActive, edge: .leading, delay: 0.08)

            afterSpendingCard
                .rotationEffect(.degrees(5))
                .opacity(0.58)
                .position(x: -5, y: 360)
                .payReviewSlideReveal(isActive: isActive, edge: .leading, delay: 0.16, distance: 110)

            beforeSpendingCard
                .position(x: 244, y: 355)
                .payReviewSlideReveal(isActive: isActive, edge: .trailing, delay: 0.24, distance: 110)

            mascot(size: 72)
                .position(x: 60, y: 602)
                .modifier(PayReviewFloatingEffect())
                .payReviewDepthReveal(isActive: isActive, delay: 0.32)

            Text("每筆紀錄，會讓下一次評估更貼近你")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PayReviewTheme.primaryText)
                .frame(width: 245, alignment: .leading)
                .position(x: 230.5, y: 592)
                .payReviewSlideReveal(isActive: isActive, edge: .trailing, delay: 0.36)

            onboardingCapsule("繼續滑動，打開這筆錢的影響　›") {
                withAnimation(PayReviewMotion.easeOut(PayReviewMotion.reveal)) { selection = .revealImpact }
            }
            .position(x: 196.5, y: 719)
            .payReviewSlideReveal(isActive: isActive, edge: .leading, delay: 0.44)

            PageIndicator(selection: selection)
                .position(x: 196.5, y: 796)
                .payReviewSlideReveal(isActive: isActive, edge: .bottom, delay: 0.50, distance: 24)
        }
    }

    private var afterSpendingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("一般記帳").font(.system(size: 13, weight: .medium)).foregroundStyle(PayReviewTheme.safe)
            Text("花完才看到").font(.system(size: 25, weight: .bold))
            Text("餐飲 NT$8,000").font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("知道錢去了哪裡，\n但下一筆仍然只能猜")
                .font(.system(size: 15))
                .foregroundStyle(PayReviewTheme.safe)
            Spacer()
            VStack(alignment: .leading, spacing: 11) {
                Capsule().frame(width: 176, height: 12)
                Capsule().frame(width: 123, height: 12)
                Capsule().frame(width: 84, height: 12)
            }
            .foregroundStyle(PayReviewTheme.safe)
        }
        .foregroundStyle(PayReviewTheme.surface)
        .padding(22)
        .frame(width: 304, height: 338, alignment: .leading)
        .background(PayReviewTheme.darkRaised, in: RoundedRectangle(cornerRadius: 28))
    }

    private var beforeSpendingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PayReview").font(.system(size: 13, weight: .bold))
            Text("付款前先看影響").font(.system(size: 24, weight: .bold))
            Text("現在花 NT$1,000").font(.system(size: 26, weight: .semibold, design: .rounded))
            outcomeRow("預算", "超支 NT$320")
            outcomeRow("目標", "可能延後 4 天")
            outcomeRow("調整", "得每天少花 NT$80")
        }
        .foregroundStyle(PayReviewTheme.primaryText)
        .padding(22)
        .frame(width: 304, height: 358, alignment: .topLeading)
        .background(PayReviewTheme.cautionSurface, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.3), radius: 18, y: 14)
    }
}

private struct RevealImpactPage: View {
    @Binding var selection: OnboardingPage
    let skip: () -> Void
    let isActive: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            PayReviewTheme.background
            onboardingHeader("02　先揭曉，再決定", selection: $selection, previous: .swipeDifference, skip: skip)
                .payReviewSlideReveal(isActive: isActive, edge: .bottom, delay: 0.02, distance: 20)

            Text("同一筆 NT$1,000，\n可以先看三種未來")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(PayReviewTheme.primaryText)
                .frame(width: 345, alignment: .leading)
                .position(x: 196.5, y: 111)
                .payReviewSlideReveal(isActive: isActive, edge: .leading, delay: 0.08)

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("正在考慮的花費").font(.system(size: 13, weight: .medium)).foregroundStyle(PayReviewTheme.safe)
                    Text("NT$1,000").font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundStyle(PayReviewTheme.surface)
                }
                Spacer()
                mascot(size: 70)
            }
            .padding(.horizontal, 18)
            .frame(width: 345, height: 96)
            .background(PayReviewTheme.darkRaised, in: RoundedRectangle(cornerRadius: 28))
            .position(x: 196.5, y: 212)
            .payReviewSlideReveal(isActive: isActive, edge: .trailing, delay: 0.15)

            revealCard("預算", "超出目前預算 NT$320", PayReviewTheme.cautionSurface, width: 345)
                .position(x: 196.5, y: 331)
                .payReviewSlideReveal(isActive: isActive, edge: .leading, delay: 0.22)

            revealGoalCard
                .position(x: 204.5, y: 431)
                .payReviewSlideReveal(isActive: isActive, edge: .trailing, delay: 0.29)

            revealCard("恢復", "接下來 4 天得每天少花 NT$80", PayReviewTheme.darkRaised, width: 305, dark: true)
                .position(x: 176.5, y: 531)
                .payReviewSlideReveal(isActive: isActive, edge: .leading, delay: 0.36)

            Text("PayReview 不替你說能不能買，\n而是先讓選擇變清楚")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PayReviewTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(width: 345)
                .position(x: 196.5, y: 624)
                .payReviewSlideReveal(isActive: isActive, edge: .trailing, delay: 0.43)

            onboardingCapsule("繼續滑動，看看它如何跟著你　›") {
                withAnimation(PayReviewMotion.easeOut(PayReviewMotion.reveal)) { selection = .personalRoute }
            }
            .position(x: 196.5, y: 719)
            .payReviewSlideReveal(isActive: isActive, edge: .leading, delay: 0.50)

            PageIndicator(selection: selection)
                .position(x: 196.5, y: 796)
                .payReviewSlideReveal(isActive: isActive, edge: .bottom, delay: 0.56, distance: 24)
        }
    }

    private var revealGoalCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("目標").font(.system(size: 12, weight: .bold)).foregroundStyle(PayReviewTheme.secondaryText)
            (Text("若不調整，").foregroundStyle(PayReviewTheme.primaryText) +
             Text("預估延後 4 天").foregroundStyle(.red))
                .font(.system(size: 16, weight: .bold))
        }
        .padding(16)
        .frame(width: 329, height: 82, alignment: .leading)
        .background(PayReviewTheme.subtle, in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct PersonalRoutePage: View {
    @Binding var selection: OnboardingPage
    let completion: () -> Void
    let skip: () -> Void
    let isActive: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            PayReviewTheme.background
            onboardingHeader("03　這是一條屬於你的路", selection: $selection, previous: .revealImpact, skip: skip)
                .payReviewSlideReveal(isActive: isActive, edge: .bottom, delay: 0.02, distance: 20)

            Text("PayReview 會把存錢目標，\n變成每天做得到的方向")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(PayReviewTheme.primaryText)
                .frame(width: 345, alignment: .leading)
                .position(x: 196.5, y: 111)
                .payReviewSlideReveal(isActive: isActive, edge: .leading, delay: 0.08)

            RouteStage(isActive: isActive)
                .position(x: 196.5, y: 341)
                .payReviewSlideReveal(isActive: isActive, edge: .trailing, delay: 0.16)

            Text("先用幾個簡單問題建立目標、收入、必要支出與彈性\n預算，再試算第一筆消費")
                .font(.system(size: 15))
                .foregroundStyle(PayReviewTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(width: 345)
                .position(x: 196.5, y: 566)
                .payReviewSlideReveal(isActive: isActive, edge: .leading, delay: 0.28)

            Button("開始認識 PayReview", action: completion)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PayReviewTheme.surface)
                .frame(width: 345, height: 48)
                .background(PayReviewTheme.primary, in: RoundedRectangle(cornerRadius: 12))
                .position(x: 196.5, y: 694)
                .buttonStyle(PayReviewPressButtonStyle())
                .payReviewSlideReveal(isActive: isActive, edge: .trailing, delay: 0.36)

            PageIndicator(selection: selection)
                .position(x: 196.5, y: 796)
                .payReviewSlideReveal(isActive: isActive, edge: .bottom, delay: 0.44, distance: 24)
        }
    }
}

private struct RouteStage: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var routeProgress: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            PayReviewTheme.darkRaised

            Path { path in
                path.move(to: CGPoint(x: 44, y: 255))
                path.addCurve(
                    to: CGPoint(x: 132, y: 179),
                    control1: CGPoint(x: 82, y: 257),
                    control2: CGPoint(x: 100, y: 184)
                )
                path.addCurve(
                    to: CGPoint(x: 229, y: 103),
                    control1: CGPoint(x: 177, y: 181),
                    control2: CGPoint(x: 193, y: 112)
                )
                path.addLine(to: CGPoint(x: 299, y: 103))
            }
            .trim(from: 0, to: reduceMotion ? 1 : routeProgress)
            .stroke(PayReviewTheme.safe, style: StrokeStyle(lineWidth: 4, lineCap: .round))

            routePoint(x: 30, y: 226, label: "今天", value: "NT$680")
            routePoint(x: 132, y: 150, label: "每週", value: "小任務")
            routePoint(x: 229, y: 74, label: "目標", value: "2027/06/01")

            mascot(size: 78)
                .position(x: 297.5, y: 66)

            Text("你的計畫會隨確認過的紀錄持續更新")
                .font(.system(size: 13))
                .foregroundStyle(PayReviewTheme.safe)
                .frame(width: 309)
                .position(x: 172.5, y: 306)
        }
        .frame(width: 345, height: 334)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .onChange(of: isActive, initial: true) { _, active in
            if reduceMotion {
                routeProgress = 1
            } else if active {
                routeProgress = 0
                withAnimation(PayReviewMotion.easeOut(PayReviewMotion.reveal).delay(0.12)) {
                    routeProgress = 1
                }
            } else {
                routeProgress = 0
            }
        }
    }
}

private struct PageIndicator: View {
    let selection: OnboardingPage

    var body: some View {
        HStack(spacing: 14) {
            ForEach(OnboardingPage.allCases) { page in
                Circle()
                    .fill(page == selection ? PayReviewTheme.secondaryText : Color.clear)
                    .overlay(Circle().stroke(PayReviewTheme.secondaryText, lineWidth: 1))
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("介紹進度")
        .accessibilityValue("第 \(selection.rawValue + 1) 頁，共 4 頁")
    }
}

private struct FinanceSignal: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PayReviewTheme.safe)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(PayReviewTheme.surface)
        }
        .padding(.horizontal, 12)
        .frame(width: 121, height: 58, alignment: .leading)
        .background(PayReviewTheme.darkRaised, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.28), radius: 10, y: 8)
    }
}

private func mascot(size: CGFloat) -> some View {
    Image("PayReviewMascot")
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("PayReview 吉祥物")
}

private func onboardingCapsule(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(PayReviewTheme.safe)
            .frame(width: 345, height: 58, alignment: .leading)
            .padding(.leading, 24)
            .background(PayReviewTheme.darkRaised, in: Capsule())
    }
    .buttonStyle(PayReviewPressButtonStyle())
}

private func skipButton(_ completion: @escaping () -> Void) -> some View {
    Button("略過介紹", action: completion)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(PayReviewTheme.primary)
        .frame(width: 88, height: 44)
        .position(x: 325, y: 42)
}

private func onboardingHeader(
    _ label: String,
    selection: Binding<OnboardingPage>,
    previous: OnboardingPage,
    skip: @escaping () -> Void
) -> some View {
    ZStack(alignment: .topLeading) {
        Button {
            withAnimation(PayReviewMotion.easeOut(PayReviewMotion.quick)) { selection.wrappedValue = previous }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PayReviewTheme.primary)
                .frame(width: 44, height: 44)
                .background(Color(red: 240 / 255, green: 247 / 255, blue: 242 / 255), in: Circle())
        }
        .position(x: 34, y: 38)

        Text(label)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(PayReviewTheme.secondaryText)
            .position(x: 179, y: 42)

        skipButton(skip)
    }
}

private func outcomeRow(_ label: String, _ value: String) -> some View {
    HStack(spacing: 10) {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(PayReviewTheme.secondaryText)
            .frame(width: 50, alignment: .leading)
        Text(value)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(PayReviewTheme.primaryText)
    }
    .padding(.horizontal, 16)
    .frame(width: 260, height: 54, alignment: .leading)
    .background(PayReviewTheme.subtle, in: RoundedRectangle(cornerRadius: 16))
}

private func revealCard(
    _ label: String,
    _ value: String,
    _ color: Color,
    width: CGFloat,
    dark: Bool = false
) -> some View {
    VStack(alignment: .leading, spacing: 9) {
        Text(label)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(dark ? PayReviewTheme.safe : PayReviewTheme.secondaryText)
        Text(value)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(dark ? PayReviewTheme.surface : PayReviewTheme.primaryText)
    }
    .padding(16)
    .frame(width: width, height: 82, alignment: .leading)
    .background(color, in: RoundedRectangle(cornerRadius: 24))
}

private func routePoint(x: CGFloat, y: CGFloat, label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
        Circle()
            .fill(PayReviewTheme.safe)
            .frame(width: 24, height: 24)
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(PayReviewTheme.safe)
        Text(value)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(PayReviewTheme.surface)
    }
    .position(x: x, y: y)
}

#Preview {
    OnboardingFlowView(completion: {})
}
