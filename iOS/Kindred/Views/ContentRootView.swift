import SwiftUI

/// Navigation root. Will be replaced with a proper tab/stack structure in Phase 3.
struct ContentRootView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        VStack(spacing: KSpacing.lg) {
            Text("Kindred")
                .font(KTypeScale.title)
                .foregroundStyle(KColor.textPrimary)

            Text("Phase 1 scaffold — engines loading…")
                .font(KTypeScale.body)
                .foregroundStyle(KColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KColor.background)
    }
}
