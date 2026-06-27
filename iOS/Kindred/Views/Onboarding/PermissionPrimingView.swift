import SwiftUI

struct PermissionPrimingView: View {
    @EnvironmentObject private var game: GameViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            header
            Spacer()
            disclosureList
            Spacer()
            footer
        }
        .padding(KSpacing.xl)
        .background(KColor.background)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: KSpacing.md) {
            Text("Kindred")
                .font(KTypeScale.title)
                .foregroundStyle(KColor.textPrimary)

            Text("Your creature is a portrait of how you actually live.")
                .font(KTypeScale.body)
                .foregroundStyle(KColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Data disclosure list

    private var disclosureList: some View {
        VStack(alignment: .leading, spacing: 0) {
            disclosureHeader

            Group {
                DisclosureRow(
                    icon:   "figure.walk",
                    title:  "Steps & Active Energy",
                    detail: "To understand your daily activity level."
                )
                DisclosureRow(
                    icon:   "clock.fill",
                    title:  "Time-of-Day Activity",
                    detail: "To learn whether you're a day or night person."
                )
                DisclosureRow(
                    icon:   "moon.zzz.fill",
                    title:  "Sleep Consistency",
                    detail: "To gauge how regular your rest patterns are."
                )
                DisclosureRow(
                    icon:   "hand.tap.fill",
                    title:  "In-App Interactions",
                    detail: "How often and how quickly you respond to your creature."
                )
            }
            .padding(.horizontal, KSpacing.md)

            Text("All processing happens on-device. Nothing leaves your phone.")
                .font(KTypeScale.caption)
                .foregroundStyle(KColor.textMuted)
                .padding(.horizontal, KSpacing.md)
                .padding(.top, KSpacing.md)
        }
        .padding(.vertical, KSpacing.md)
        .background(KColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: KRadius.lg))
    }

    private var disclosureHeader: some View {
        Text("What Kindred reads and why")
            .font(KTypeScale.bodyBold)
            .foregroundStyle(KColor.textPrimary)
            .padding(.horizontal, KSpacing.md)
            .padding(.bottom, KSpacing.sm)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: KSpacing.sm) {
            Button {
                game.acknowledgePermissions()
            } label: {
                Text("Start raising")
                    .font(KTypeScale.bodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(KSpacing.md)
                    .background(KColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: KRadius.md))
            }

            Text("What your data does to the creature is something you'll discover.")
                .font(KTypeScale.caption)
                .foregroundStyle(KColor.textMuted)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Row

private struct DisclosureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: KSpacing.md) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(KColor.accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(KTypeScale.bodyBold)
                    .foregroundStyle(KColor.textPrimary)
                Text(detail)
                    .font(KTypeScale.caption)
                    .foregroundStyle(KColor.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, KSpacing.sm)
    }
}
