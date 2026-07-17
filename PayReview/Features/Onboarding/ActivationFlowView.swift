import SwiftUI

struct UnauthenticatedActivationView: View {
    @ObservedObject var viewModel: AuthenticationTestViewModel
    let replayIntroduction: () -> Void
    @State private var showsSignIn: Bool

    init(
        viewModel: AuthenticationTestViewModel,
        initiallyShowsSignIn: Bool = false,
        replayIntroduction: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.replayIntroduction = replayIntroduction
        _showsSignIn = State(initialValue: initiallyShowsSignIn)
    }

    var body: some View {
        if showsSignIn {
            PayReviewSignInView(viewModel: viewModel) {
                withAnimation(PayReviewMotion.easeOut(PayReviewMotion.quick)) { showsSignIn = false }
            }
            .transition(.move(edge: .trailing))
        } else {
            ValueHookView(
                replayIntroduction: replayIntroduction,
                continueAction: {
                    withAnimation(PayReviewMotion.easeOut(0.45)) { showsSignIn = true }
                }
            )
            .transition(.move(edge: .leading))
        }
    }
}

struct PersonalizedActivationView: View {
    @ObservedObject var store: SetupStore
    let backToSignIn: () -> Void
    let completion: () -> Void
    @State private var page = 0

    var body: some View {
        Group {
            if page == 0 {
                MoneyFrictionView(
                    backAction: backToSignIn,
                    continueAction: {
                        withAnimation(PayReviewMotion.easeOut(0.42)) { page = 1 }
                    }
                )
            } else {
                GoalChoiceView(store: store, backAction: {
                    withAnimation(PayReviewMotion.easeOut(PayReviewMotion.quick)) { page = 0 }
                }, completion: completion)
            }
        }
    }
}

private struct ValueHookView: View {
    let replayIntroduction: () -> Void
    let continueAction: () -> Void
    @State private var isPresented = false

    var body: some View {
        ActivationDesignCanvas {
            ZStack(alignment: .topLeading) {
                PayReviewTheme.surface

                ActivationBackButton(action: replayIntroduction)
                    .position(x: 46, y: 64)
                    .accessibilityLabel("重播動態介紹")
                    .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.04, distance: 32)

                Circle()
                    .fill(PayReviewTheme.subtle)
                    .frame(width: 220, height: 220)
                    .position(x: 196, y: 162)
                    .payReviewDepthReveal(isActive: isPresented, delay: 0.02)
                ActivationMascot(size: 176)
                    .modifier(PayReviewFloatingEffect())
                    .position(x: 196, y: 162)
                    .payReviewDepthReveal(isActive: isPresented, delay: 0.06)
                SpeechBubble("讓每一次的紀錄，\n都幫助你做出更有意識的消費決定")
                    .frame(width: 190, height: 78)
                    .position(x: 269, y: 244)
                    .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.26)

                Text("不要等到月底，")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(PayReviewTheme.primaryText)
                    .frame(width: 345, alignment: .leading)
                    .position(x: 196.5, y: 327)
                    .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.32)
                Text("才發現自己原來花了那麼多錢")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(PayReviewTheme.primary)
                    .frame(width: 345, alignment: .leading)
                    .position(x: 196.5, y: 369)
                    .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.38)

                Text("PayReview 會在付款前，先算預算、存錢目標與\n可以調整的方式")
                    .font(.system(size: 16))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(width: 345, alignment: .leading)
                    .position(x: 196.5, y: 431)
                    .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.44)

                Text("今天能花多少？\n這筆錢會延後財務目標達成嗎？")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PayReviewTheme.primaryText)
                    .padding(.horizontal, 18)
                    .frame(width: 345, height: 86, alignment: .leading)
                    .background(PayReviewTheme.subtle, in: RoundedRectangle(cornerRadius: 20))
                    .position(x: 196.5, y: 528)
                    .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.50)

                ActivationButton("建立我的用錢計畫", action: continueAction)
                    .position(x: 196.5, y: 674)
                    .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.58, distance: 110)
                ActivationSecondaryButton("我已經有帳號", action: continueAction)
                    .position(x: 196.5, y: 736)
                    .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.66, distance: 110)
            }
        }
        .onAppear { isPresented = true }
        .onDisappear { isPresented = false }
    }
}

private struct MoneyFrictionView: View {
    let backAction: () -> Void
    let continueAction: () -> Void
    @State private var selection = 1
    @State private var isPresented = false

    private let choices = [
        "不知道今天還能花多少",
        "存錢目標常常被臨時支出打亂",
        "記了很多，但不知道如何調整自己的消費習慣"
    ]

    var body: some View {
        ActivationDesignCanvas {
            ZStack(alignment: .topLeading) {
                PayReviewTheme.surface
                ActivationProgress(completedSteps: 1)
                    .position(x: 196.5, y: 17)
                ActivationBackButton(action: backAction)
                    .position(x: 34, y: 55)
                    .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.02, distance: 32)

                Text("哪一種時刻，最讓你不知道\n怎麼調整？")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(PayReviewTheme.primaryText)
                    .frame(width: 345, alignment: .leading)
                    .position(x: 196.5, y: 122)
                    .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.08)
                Text("選一個最接近現在的狀況；答案只用來調整你的體驗")
                    .font(.system(size: 15))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(width: 345, alignment: .leading)
                    .position(x: 196.5, y: 174)
                    .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.14)

                VStack(spacing: 16) {
                    ForEach(choices.indices, id: \.self) { index in
                        Button {
                            selection = index
                        } label: {
                            Text((selection == index ? "✓  " : "") + choices[index])
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(PayReviewTheme.primaryText)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                .padding(.horizontal, 18)
                        }
                        .frame(width: index == 2 ? 300 : 330, height: index == 1 ? 92 : 72)
                        .background(
                            selection == index ? PayReviewTheme.cautionSurface : (index == 2 ? PayReviewTheme.surface : PayReviewTheme.subtle),
                            in: RoundedRectangle(cornerRadius: 20)
                        )
                        .overlay {
                            if selection == index {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(PayReviewTheme.primary, lineWidth: 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: index == 1 ? .trailing : .leading)
                    }
                }
                .frame(width: 345)
                .position(x: 196.5, y: 357)
                .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.22, distance: 100)

                ActivationMascot(size: 72)
                    .position(x: 60, y: 571)
                    .modifier(PayReviewFloatingEffect())
                    .payReviewDepthReveal(isActive: isPresented, delay: 0.34)
                SpeechBubble("這不是你的標籤，只是讓我知道\n先從哪裡陪你整理")
                    .frame(width: 244, height: 55)
                    .position(x: 204, y: 564.5)
                    .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.38)

                ActivationButton("下一步：想完成的目標", action: continueAction)
                    .position(x: 196.5, y: 712)
                    .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.48, distance: 110)
            }
        }
        .onAppear { isPresented = true }
        .onDisappear { isPresented = false }
    }
}

private struct GoalChoiceView: View {
    @ObservedObject var store: SetupStore
    let backAction: () -> Void
    let completion: () -> Void
    @State private var showsGoalEditor = false
    @State private var isPresented = false

    var body: some View {
        ActivationDesignCanvas {
            ZStack(alignment: .topLeading) {
                PayReviewTheme.surface
                ActivationProgress(completedSteps: 3)
                    .position(x: 196.5, y: 17)
                ActivationBackButton(action: backAction)
                    .position(x: 46, y: 63)
                    .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.02, distance: 32)

                Text("你想先讓哪一筆錢，走向更\n重要的地方？")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(PayReviewTheme.primaryText)
                    .frame(width: 345, alignment: .leading)
                    .position(x: 208.5, y: 128)
                    .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.08)
                Text("先選一個方向；金額、日期與名稱之後都能調整")
                    .font(.system(size: 15))
                    .foregroundStyle(PayReviewTheme.secondaryText)
                    .frame(width: 345, alignment: .leading)
                    .position(x: 208.5, y: 180)
                    .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.14)

                GoalJourneyCard(store: store) {
                    showsGoalEditor = true
                }
                .payReviewInteractiveTilt(maximumAngle: 5, focusedScale: 1.018)
                .position(x: 196.5, y: 319)
                .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.22, distance: 100)

                Button {
                    showsGoalEditor = true
                } label: {
                    Label("設定達成目標日期", systemImage: "calendar")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(PayReviewTheme.primaryText)
                        .frame(width: 345, height: 58)
                }
                .background(PayReviewTheme.subtle, in: RoundedRectangle(cornerRadius: 18))
                .position(x: 196.5, y: 469)
                .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.30)

                HStack(spacing: 25) {
                    GoalOption(title: "緊急預備金", width: 160, selected: store.goalName == "緊急預備金") {
                        store.goalName = "緊急預備金"
                    }
                    GoalOption(title: "進修計畫", width: 160, filled: false, selected: store.goalName == "進修計畫") {
                        store.goalName = "進修計畫"
                    }
                }
                .position(x: 196.5, y: 540)
                .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.36)

                GoalOption(title: "自訂目標", width: 345, selected: !["緊急預備金", "進修計畫"].contains(store.goalName)) {
                    store.goalName = "自訂目標"
                    showsGoalEditor = true
                }
                .position(x: 196.5, y: 618)
                .payReviewSlideReveal(isActive: isPresented, edge: .trailing, delay: 0.42)

                ActivationButton("用這個目標建立計畫", action: completion)
                    .position(x: 196.5, y: 712)
                    .payReviewSlideReveal(isActive: isPresented, edge: .leading, delay: 0.50, distance: 110)
            }
        }
        .onAppear { isPresented = true }
        .onDisappear { isPresented = false }
        .sheet(isPresented: $showsGoalEditor) {
            NavigationStack {
                Form {
                    TextField("目標名稱", text: $store.goalName)
                    TextField("目標金額", value: $store.goalAmount, format: .currency(code: "TWD"))
                        .keyboardType(.decimalPad)
                    DatePicker("目標完成日期", selection: $store.targetDate, displayedComponents: .date)
                }
                .navigationTitle("調整目標")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showsGoalEditor = false }
                    }
                }
            }
        }
    }
}

private struct GoalJourneyCard: View {
    @ObservedObject var store: SetupStore
    let editAction: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            PayReviewTheme.cautionSurface
            Text(store.goalName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(PayReviewTheme.primaryText)
                .frame(width: 305, alignment: .leading)
                .position(x: 172.5, y: 33)
            Text("\(store.goalAmount.twdFormatted)　·　\(store.targetDate.formatted(.dateTime.year().month().day()))")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PayReviewTheme.secondaryText)
                .frame(width: 305, alignment: .leading)
                .position(x: 172.5, y: 69)

            Path { path in
                path.move(to: CGPoint(x: 62, y: 145))
                path.addLine(to: CGPoint(x: 282, y: 145))
            }
            .stroke(PayReviewTheme.primary, lineWidth: 3)
            Circle().fill(PayReviewTheme.primary).frame(width: 18, height: 18).position(x: 62, y: 145)
            ActivationMascot(size: 92).position(x: 274, y: 142)
            Text("距離目標約 11 個月\n名稱、金額、日期都能再調整")
                .font(.system(size: 12))
                .foregroundStyle(PayReviewTheme.secondaryText)
                .frame(width: 205, alignment: .leading)
                .position(x: 122.5, y: 190)
            Button(action: editAction) {
                Image(systemName: "pencil")
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(PayReviewTheme.primary)
            .position(x: 315, y: 32)
        }
        .frame(width: 345, height: 214)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

private struct GoalOption: View {
    let title: String
    let width: CGFloat
    var filled = true
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(PayReviewTheme.primaryText)
                .padding(.leading, 16)
                .frame(width: width, height: 58, alignment: .leading)
        }
        .background(filled ? PayReviewTheme.subtle : PayReviewTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(selected ? PayReviewTheme.primary : .clear, lineWidth: 2)
        }
        .scaleEffect(selected ? 1.035 : 0.985)
        .opacity(selected ? 1 : 0.78)
        .animation(PayReviewMotion.gentleSpring, value: selected)
        .buttonStyle(PayReviewPressButtonStyle())
    }
}

struct ActivationDesignCanvas<Content: View>: View {
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
        .ignoresSafeArea()
        .background(PayReviewTheme.surface.ignoresSafeArea())
    }
}

struct ActivationMascot: View {
    let size: CGFloat

    var body: some View {
        Image("PayReviewMascot")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .accessibilityLabel("PayReview 吉祥物")
    }
}

struct SpeechBubble: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(PayReviewTheme.primaryText)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color(red: 203 / 255, green: 221 / 255, blue: 211 / 255)) }
            .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
    }
}

struct ActivationBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PayReviewTheme.primary)
                .frame(width: 44, height: 44)
                .background(Color(red: 240 / 255, green: 247 / 255, blue: 242 / 255), in: Circle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .zIndex(20)
    }
}

struct ActivationProgress: View {
    let completedSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...4, id: \.self) { step in
                Capsule()
                    .fill(step <= completedSteps ? Color(red: 26 / 255, green: 120 / 255, blue: 97 / 255) : Color(red: 204 / 255, green: 227 / 255, blue: 217 / 255))
                    .frame(width: 81.75, height: 6)
            }
        }
    }
}

struct ActivationButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(PayReviewTheme.surface)
            .frame(width: 345, height: 48)
            .background(PayReviewTheme.primary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ActivationSecondaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(PayReviewTheme.primary)
            .frame(width: 343, height: 46)
            .background(PayReviewTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color(red: 203 / 255, green: 221 / 255, blue: 211 / 255)) }
    }
}

#Preview("A1") {
    ValueHookView(replayIntroduction: {}, continueAction: {})
}

#Preview("A3") {
    MoneyFrictionView(backAction: {}, continueAction: {})
}

#Preview("A4") {
    GoalChoiceView(store: SetupStore(), backAction: {}, completion: {})
}
