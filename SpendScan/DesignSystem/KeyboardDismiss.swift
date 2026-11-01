import SwiftUI
import UIKit

/// Hides the keyboard when you tap anywhere outside a text field, across the whole app.
/// Taps still reach buttons, pickers and other fields as normal.
struct KeyboardDismissOnTap: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView {
        InstallerView()
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView, UIGestureRecognizerDelegate {
        private var installed = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, !installed else { return }
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            installed = true
        }

        @objc private func dismiss() {
            window?.endEditing(true)
        }

        /// Ignore taps on text fields so tapping another field moves to it instead of closing the keyboard.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

extension View {
    func dismissesKeyboardOnTap() -> some View {
        background(KeyboardDismissOnTap().allowsHitTesting(false))
    }
}

/// A £ amount field that updates its value as you type, not only when you leave the field,
/// so totals that depend on it change straight away.
struct PriceField: View {
    let title: String
    @Binding var value: Decimal
    /// Use .numbersAndPunctuation where a minus sign is needed (discounts).
    var keyboard: UIKeyboardType = .decimalPad
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 2) {
            Text("£").foregroundStyle(Color.textSecondary)
            TextField(title, text: $text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
        }
        .onAppear { text = Self.format(value) }
        .onChange(of: text) { _, newText in
            let cleaned = newText.replacingOccurrences(of: "£", with: "").replacingOccurrences(of: ",", with: "")
            if cleaned.isEmpty {
                value = 0
            } else if let parsed = Decimal(string: cleaned, locale: Locale(identifier: "en_GB")) {
                value = parsed
            }
        }
        .onChange(of: value) { _, newValue in
            // Keep the text in step when the value changes from outside (e.g. the total).
            if !isFocused { text = Self.format(newValue) }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { text = Self.format(value) }
        }
    }

    static func format(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(Locale(identifier: "en_GB")))
    }
}
