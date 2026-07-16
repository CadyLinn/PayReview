import SwiftUI

enum PayReviewMotion {
    enum SlideEdge {
        case leading
        case trailing
        case bottom
    }

    static let quick = 0.28
    static let navigation = 0.42
    static let reveal = 0.55

    static func easeOut(_ duration: Double = navigation) -> Animation {
        .easeOut(duration: duration)
    }

    static let gentleSpring = Animation.spring(duration: 0.58, bounce: 0.22)
}

private struct SlideRevealModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    let isActive: Bool
    let edge: PayReviewMotion.SlideEdge
    let delay: Double
    let distance: CGFloat
    @State private var isPresented = false

    private var hiddenOffset: CGSize {
        switch edge {
        case .leading:
            CGSize(width: layoutDirection == .leftToRight ? -distance : distance, height: 0)
        case .trailing:
            CGSize(width: layoutDirection == .leftToRight ? distance : -distance, height: 0)
        case .bottom:
            CGSize(width: 0, height: distance)
        }
    }

    func body(content: Content) -> some View {
        content
            .opacity(isPresented ? 1 : 0)
            .offset(reduceMotion || isPresented ? .zero : hiddenOffset)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.25)
                    : PayReviewMotion.easeOut(PayReviewMotion.reveal).delay(isPresented ? delay : 0),
                value: isPresented
            )
            .onAppear {
                guard isActive else { return }
                DispatchQueue.main.async { isPresented = true }
            }
            .onChange(of: isActive) { _, active in
                isPresented = active
            }
    }
}

private struct DepthRevealModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isActive: Bool
    let delay: Double
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .opacity(isPresented ? 1 : 0)
            .scaleEffect(reduceMotion || isPresented ? 1 : 0.42)
            .offset(y: reduceMotion || isPresented ? 0 : 42)
            .blur(radius: reduceMotion || isPresented ? 0 : 7)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.25)
                    : .spring(duration: 0.72, bounce: 0.18).delay(isPresented ? delay : 0),
                value: isPresented
            )
            .onAppear {
                guard isActive else { return }
                DispatchQueue.main.async { isPresented = true }
            }
            .onChange(of: isActive) { _, active in
                isPresented = active
            }
    }
}

struct PayReviewPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.035 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct MotionEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let delay: Double
    let distance: CGFloat
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible || reduceMotion ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : distance)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.985)
            .onAppear {
                if reduceMotion {
                    isVisible = true
                } else {
                    withAnimation(.easeOut(duration: PayReviewMotion.reveal).delay(delay)) {
                        isVisible = true
                    }
                }
            }
    }
}

private struct PrototypeRevealModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isActive: Bool
    let delay: Double
    let distance: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .offset(y: isActive || reduceMotion ? 0 : distance)
            .scaleEffect(isActive || reduceMotion ? 1 : 0.98)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.25)
                    : PayReviewMotion.easeOut(PayReviewMotion.reveal).delay(delay),
                value: isActive
            )
    }
}

private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1.2

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.52), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: proxy.size.width * 0.32)
                        .rotationEffect(.degrees(18))
                        .offset(x: proxy.size.width * phase)
                    }
                    .allowsHitTesting(false)
                    .mask(content)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.7).repeatForever(autoreverses: false)) {
                    phase = 1.6
                }
            }
    }
}

extension View {
    func payReviewEntrance(delay: Double = 0, distance: CGFloat = 18) -> some View {
        modifier(MotionEntranceModifier(delay: delay, distance: distance))
    }

    func payReviewPrototypeReveal(
        isActive: Bool,
        delay: Double = 0,
        distance: CGFloat = 16
    ) -> some View {
        modifier(PrototypeRevealModifier(isActive: isActive, delay: delay, distance: distance))
    }

    func payReviewShimmer() -> some View {
        modifier(ShimmerModifier())
    }

    func payReviewSlideReveal(
        isActive: Bool,
        edge: PayReviewMotion.SlideEdge,
        delay: Double = 0,
        distance: CGFloat = 72
    ) -> some View {
        modifier(SlideRevealModifier(isActive: isActive, edge: edge, delay: delay, distance: distance))
    }

    func payReviewDepthReveal(isActive: Bool, delay: Double = 0) -> some View {
        modifier(DepthRevealModifier(isActive: isActive, delay: delay))
    }

    func payReviewInteractiveTilt(maximumAngle: Double = 7, focusedScale: CGFloat = 1.025) -> some View {
        modifier(InteractiveTiltModifier(maximumAngle: maximumAngle, focusedScale: focusedScale))
    }
}

struct PayReviewFloatingEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floats = false

    func body(content: Content) -> some View {
        content
            .offset(y: floats && !reduceMotion ? -3 : 2)
            .rotationEffect(.degrees(floats && !reduceMotion ? 0.25 : -0.25))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                    floats = true
                }
            }
    }
}

private struct InteractiveTiltModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var translation: CGSize = .zero
    @State private var isFocused = false

    let maximumAngle: Double
    let focusedScale: CGFloat

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : Double(translation.width / 18).clamped(to: -maximumAngle...maximumAngle)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.72
            )
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : Double(-translation.height / 22).clamped(to: -maximumAngle...maximumAngle)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.72
            )
            .scaleEffect(isFocused && !reduceMotion ? focusedScale : 1)
            .shadow(
                color: PayReviewTheme.primary.opacity(isFocused ? 0.24 : 0.10),
                radius: isFocused ? 22 : 8,
                x: translation.width / 18,
                y: 8 + translation.height / 22
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($translation) { value, state, _ in
                        guard !reduceMotion else { return }
                        state = value.translation
                    }
                    .onChanged { _ in
                        guard !reduceMotion, !isFocused else { return }
                        withAnimation(.easeOut(duration: 0.16)) { isFocused = true }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(duration: 0.48, bounce: 0.24)) { isFocused = false }
                    }
            )
            .animation(reduceMotion ? nil : .spring(duration: 0.42, bounce: 0.18), value: translation)
    }
}

extension Double {
    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

struct CelebrationBurst: View {
    enum Style { case fireworks, confetti }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let style: Style
    var particleCount = 34
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                particle(index)
            }

            if style == .fireworks {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(index.isMultiple(of: 2) ? PayReviewTheme.safe : .orange, lineWidth: 2)
                        .frame(width: 36, height: 36)
                        .scaleEffect(0.2 + progress * CGFloat(2.5 + Double(index) * 0.65))
                        .opacity(Double(1 - progress))
                        .offset(x: CGFloat(index - 1) * 76, y: CGFloat(index.isMultiple(of: 2) ? -30 : 26))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion {
                progress = 1
            } else {
                progress = 0
                withAnimation(.easeOut(duration: 1.25)) {
                    progress = 1
                }
            }
        }
    }

    @ViewBuilder
    private func particle(_ index: Int) -> some View {
        let unit = seeded(index)
        let angle = unit * .pi * 2
        let distance = CGFloat(72 + (index * 19) % 118)
        let x = cos(angle) * distance * progress
        let gravity = CGFloat(style == .confetti ? 62 : 22) * progress * progress
        let y = sin(angle) * distance * progress + gravity
        let color: Color = index % 3 == 0 ? PayReviewTheme.safe : index % 3 == 1 ? .orange : PayReviewTheme.primary

        Group {
            if index.isMultiple(of: 4) {
                Image(systemName: "sparkle")
                    .font(.system(size: CGFloat(8 + index % 7), weight: .bold))
            } else if index.isMultiple(of: 3) {
                Circle().frame(width: CGFloat(5 + index % 5), height: CGFloat(5 + index % 5))
            } else {
                Capsule().frame(width: 5, height: CGFloat(10 + index % 8))
            }
        }
        .foregroundStyle(color)
        .rotationEffect(.degrees(Double(index * 47) * Double(progress)))
        .offset(x: x, y: y)
        .opacity(reduceMotion ? 0 : Double(max(0, 1 - progress * 0.86)))
        .scaleEffect(0.65 + progress * 0.65)
    }

    private func seeded(_ index: Int) -> Double {
        let value = (index &* 73 &+ 31) % 997
        return Double(value) / 997
    }
}
