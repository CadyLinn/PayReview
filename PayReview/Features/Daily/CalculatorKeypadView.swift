//
//  CalculatorKeypadView.swift
//  PayReview
//

import SwiftUI

/// A pure-SwiftUI stand-in for "an iPhone Calculator app keyboard", used when
/// logging today's fixed expenses. SwiftUI has no built-in `.keyboardType` that
/// does arithmetic, so this is just a grid of buttons that append to a plain
/// `String` expression (e.g. "120+35"), evaluated with `NSExpression` once the
/// user taps "=" — it looks and behaves like a keyboard, but it's a regular view,
/// not a real text input method.
struct CalculatorKeypadView: View {
    @Binding var expression: String
    let onEquals: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("取消", action: onCancel)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("清除") { expression = "" }
                    .foregroundStyle(.secondary)
            }

            Text(expression.isEmpty ? "0" : expression)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.vertical, 4)

            HStack(spacing: 10) {
                digitButton("7")
                digitButton("8")
                digitButton("9")
                operatorButton("÷", appends: "/")
            }
            HStack(spacing: 10) {
                digitButton("4")
                digitButton("5")
                digitButton("6")
                operatorButton("×", appends: "*")
            }
            HStack(spacing: 10) {
                digitButton("1")
                digitButton("2")
                digitButton("3")
                operatorButton("−", appends: "-")
            }
            HStack(spacing: 10) {
                actionButton("C") { expression = "" }
                digitButton("0")
                backspaceButton
                operatorButton("+", appends: "+")
            }

            Button(action: onEquals) {
                Text("=")
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .background(PayReviewTheme.primary, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
        }
        .padding()
    }

    private func digitButton(_ digit: String) -> some View {
        actionButton(digit) { expression.append(digit) }
    }

    /// Appends the character `NSExpression` actually understands (`+ - * /`) even
    /// though the button shows the calculator-familiar symbol (`× ÷`) — the
    /// display and the evaluated syntax are deliberately different strings.
    private func operatorButton(_ symbol: String, appends operatorCharacter: Character) -> some View {
        Button {
            appendOperator(operatorCharacter)
        } label: {
            Text(symbol)
                .font(.title2.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(PayReviewTheme.todayExpenseSurface, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(PayReviewTheme.primary)
        }
    }

    private var backspaceButton: some View {
        actionButton("⌫") {
            if !expression.isEmpty { expression.removeLast() }
        }
    }

    private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.primary)
        }
    }

    /// Guards against two problems that would otherwise make `NSExpression` throw
    /// later: an operator with nothing before it yet (`expression` still empty),
    /// and two operators in a row (tapping "+" then "−" without a digit in
    /// between) — the second tap just replaces the first, the same way the real
    /// Calculator app behaves in that situation.
    private func appendOperator(_ operatorCharacter: Character) {
        guard !expression.isEmpty else { return }
        if let last = expression.last, "+-*/".contains(last) {
            expression.removeLast()
        }
        expression.append(operatorCharacter)
    }
}

extension CalculatorKeypadView {
    /// Evaluates an expression typed on this keypad into a positive whole NT$
    /// amount, or `nil` if it doesn't represent one — used by whatever calls
    /// `onEquals` to decide what to actually save. `nil` covers three cases the
    /// caller needs to treat the same way: an empty expression (nothing typed),
    /// an expression `NSExpression` can't parse, and a result that's zero or
    /// negative (this app has no "negative expense").
    ///
    /// A trailing operator (the user tapped "=" right after "120+" without
    /// finishing the second number) is trimmed rather than treated as invalid —
    /// friendlier than making the whole entry fail over an incomplete last tap.
    static func evaluatedAmount(from expression: String) -> Int64? {
        var trimmed = expression
        if let last = trimmed.last, "+-*/".contains(last) {
            trimmed.removeLast()
        }
        guard !trimmed.isEmpty else { return nil }

        let nsExpression = NSExpression(format: trimmed)
        guard let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber else {
            return nil
        }
        let rounded = result.doubleValue.rounded()
        guard rounded.isFinite, rounded > 0 else { return nil }
        return Int64(rounded)
    }
}

#Preview {
    CalculatorKeypadView(expression: .constant("120+35"), onEquals: {}, onCancel: {})
}
