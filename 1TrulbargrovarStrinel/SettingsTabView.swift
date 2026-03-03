import SwiftUI
import StoreKit
import UIKit

struct SettingsTabView: View {
    @EnvironmentObject private var storage: GameStorage
    @State private var showResetAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                statsSection
                bestLevelsSection
                linksSection
                resetSection
            }
            .frame(maxWidth: 390)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .alert("Reset all progress?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                storage.resetAll()
            }
        } message: {
            Text("This will clear stars, levels, achievements progress, and statistics. This action cannot be undone.")
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .foregroundColor(.appTextPrimary)

            VStack(spacing: 10) {
                statRow(title: "Total games played", value: "\(storage.totalGamesPlayed)")
                statRow(title: "Total stars earned", value: "\(storage.totalStarsEarned)")
                statRow(title: "Total time played", value: formattedTime(storage.totalPlayTimeSeconds))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.appSurface, Color.appBackground.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)
            )
        }
    }

    private var bestLevelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Best progress")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .foregroundColor(.appTextPrimary)

            VStack(spacing: 10) {
                ForEach(GameIdentifier.allCases) { game in
                    let bestIndex = storage.bestLevelIndex(for: game)
                    let displayedLevel = bestIndex + 1
                    statRow(title: game.displayName, value: "Level \(displayedLevel)")
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.appSurface, Color.appBackground.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)
            )
        }
    }

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .foregroundColor(.appTextPrimary)

            Button {
                showResetAlert = true
            } label: {
                HStack {
                    Text("Reset All Progress")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.appBackground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .background(Color.appPrimary)
                .cornerRadius(14)
            }
            .buttonStyle(ScaledButtonStyle())
        }
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("More")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .foregroundColor(.appTextPrimary)

            VStack(spacing: 10) {
                settingsLinkRow(
                    icon: "star.bubble.fill",
                    title: "Rate this experience",
                    subtitle: "Share your feedback on the App Store",
                    action: rateApp
                )

                settingsLinkRow(
                    icon: "lock.shield",
                    title: "Privacy Policy",
                    subtitle: "How your data is handled",
                    action: openPrivacyPolicy
                )

                settingsLinkRow(
                    icon: "doc.text",
                    title: "Terms of Use",
                    subtitle: "Rules for using this app",
                    action: openTermsOfUse
                )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.appSurface, Color.appBackground.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)
            )
        }
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(.appTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(.appTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func settingsLinkRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(ScaledButtonStyle())
    }

    private func formattedTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func openPrivacyPolicy() {
        if let url = URL(string: "https://trulbargrovarstrinel847.site/privacy/45") {
            UIApplication.shared.open(url)
        }
    }

    private func openTermsOfUse() {
        if let url = URL(string: "https://trulbargrovarstrinel847.site/terms/45") {
            UIApplication.shared.open(url)
        }
    }

    private func rateApp() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}

