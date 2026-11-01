import SwiftUI

/// The opening animation. It starts from the same picture as the launch screen
/// (LaunchScreen.storyboard), so there is no flash: the logo is scanned, the name
/// appears, then the logo grows and fades into the app.
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scanProgress: CGFloat = 0
    @State private var showScan = false
    @State private var showName = false
    @State private var leaving = false

    private let logoSize: CGFloat = 120

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()

            Image("LaunchLogo")
                .resizable()
                .frame(width: logoSize, height: logoSize)
                .overlay { scanLine }
                .scaleEffect(leaving ? 1.6 : 1)
                .opacity(leaving ? 0 : 1)

            Text("SpendScan")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .opacity(showName && !leaving ? 1 : 0)
                .offset(y: logoSize / 2 + 36 + (showName ? 0 : 8))
        }
        .opacity(leaving ? 0 : 1)
        .accessibilityHidden(true)
        .task { await play() }
    }

    /// A soft bright band that sweeps down the receipt, like a scanner. Only shows on the logo itself.
    private var scanLine: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.85), .white.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 18)
                .offset(y: scanProgress * (logoSize - 18))
        }
        .frame(width: logoSize, height: logoSize, alignment: .top)
        .opacity(showScan ? 1 : 0)
        .mask { Image("LaunchLogo").resizable().frame(width: logoSize, height: logoSize) }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    private func play() async {
        if reduceMotion {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.25)) { leaving = true }
            try? await Task.sleep(for: .milliseconds(250))
            onFinish()
            return
        }
        withAnimation(.easeOut(duration: 0.1)) { showScan = true }
        withAnimation(.easeInOut(duration: 0.7)) { scanProgress = 1 }
        withAnimation(.spring(duration: 0.5).delay(0.2)) { showName = true }
        try? await Task.sleep(for: .milliseconds(600))
        withAnimation(.easeOut(duration: 0.15)) { showScan = false }
        try? await Task.sleep(for: .milliseconds(400))
        withAnimation(.easeIn(duration: 0.35)) { leaving = true }
        try? await Task.sleep(for: .milliseconds(350))
        onFinish()
    }
}

#Preview {
    SplashView {}
}
