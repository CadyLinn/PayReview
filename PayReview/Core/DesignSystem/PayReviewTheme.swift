import SwiftUI

enum PayReviewTheme {
    static let background = Color(red: 232 / 255, green: 242 / 255, blue: 234 / 255)
    static let surface = Color(red: 248 / 255, green: 245 / 255, blue: 236 / 255)
    static let subtle = Color(red: 220 / 255, green: 239 / 255, blue: 229 / 255)
    static let primary = Color(red: 11 / 255, green: 70 / 255, blue: 63 / 255)
    static let primaryText = Color(red: 8 / 255, green: 47 / 255, blue: 42 / 255)
    static let secondaryText = Color(red: 96 / 255, green: 113 / 255, blue: 105 / 255)
    static let safe = Color(red: 127 / 255, green: 209 / 255, blue: 176 / 255)
    static let cautionSurface = Color(red: 250 / 255, green: 239 / 255, blue: 214 / 255)
    static let darkSurface = Color(red: 7 / 255, green: 43 / 255, blue: 41 / 255)
    static let darkRaised = Color(red: 14 / 255, green: 68 / 255, blue: 61 / 255)
}

struct PayReviewPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundStyle(PayReviewTheme.surface)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                PayReviewTheme.primary.opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .contentShape(Rectangle())
    }
}

struct SetupProgressHeader: View {
    let completedSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...4, id: \.self) { step in
                Capsule()
                    .fill(step <= completedSteps ? PayReviewTheme.primary : PayReviewTheme.subtle)
                    .frame(height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("設定進度")
        .accessibilityValue("完成四步中的第 \(completedSteps) 步")
    }
}

struct MascotSpeechView: View {
    let message: String
    var avatarSize: CGFloat = 72
    var avatarOnTrailingEdge = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if !avatarOnTrailingEdge {
                mascot
            }

            Text(message)
                .font(.callout.weight(.bold))
                .foregroundStyle(PayReviewTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)

            if avatarOnTrailingEdge {
                mascot
            }
        }
    }

    private var mascot: some View {
        Image("PayReviewMascot")
            .resizable()
            .scaledToFill()
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())
            .accessibilityLabel("PayReview 吉祥物")
    }
}

extension View {
    func payReviewSetupBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(PayReviewTheme.background.ignoresSafeArea())
            .tint(PayReviewTheme.primary)
    }
}
