import SwiftUI
import LocalAuthentication

/// Face ID (or passcode) lock for the whole app.
enum AppLock {
    /// True when the iPhone has Face ID or a passcode set up.
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Asks for Face ID, falling back to the iPhone passcode.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

/// Covers the app when it's locked, and whenever it isn't on screen so spending
/// never shows in the app switcher.
struct AppLockModifier: ViewModifier {
    @AppStorage(SettingsKeys.faceIDLock) private var lockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked = false
    @State private var isAuthenticating = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if lockEnabled && (!isUnlocked || scenePhase != .active) {
                    LockScreen(showsButton: !isUnlocked && !isAuthenticating, onUnlock: unlock)
                }
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                switch phase {
                case .background:
                    isUnlocked = false
                case .active:
                    if lockEnabled && !isUnlocked { unlock() }
                default:
                    break
                }
            }
            .onChange(of: lockEnabled) { _, enabled in
                // Turning the lock on from Settings shouldn't lock you out straight away.
                if enabled { isUnlocked = true }
            }
    }

    private func unlock() {
        guard !isAuthenticating else { return }
        // If Face ID and the passcode were removed from the iPhone, the lock can't work,
        // so turn it off rather than lock the data away for good.
        guard AppLock.isAvailable else {
            lockEnabled = false
            isUnlocked = true
            return
        }
        isAuthenticating = true
        Task {
            isUnlocked = await AppLock.authenticate(reason: "Unlock SpendScan to see your spending")
            isAuthenticating = false
        }
    }
}

private struct LockScreen: View {
    let showsButton: Bool
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentDefault)
                Text("SpendScan is locked")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                if showsButton {
                    Button("Unlock", action: onUnlock)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

extension View {
    func appLock() -> some View {
        modifier(AppLockModifier())
    }
}
