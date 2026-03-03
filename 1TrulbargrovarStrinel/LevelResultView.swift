import SwiftUI

struct LevelResultView: View {
    let summary: LevelResultSummary
    let lastUnlockedAchievement: AchievementDefinition?

    let onNextLevel: () -> Void
    let onRetry: () -> Void
    let onBackToLevels: () -> Void

    @State private var shownStars: Int = 0
    @State private var showBanner: Bool = false
    @State private var showContent: Bool = false
    @State private var showMetricCard: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            // Градиентный фон результата
            LinearGradient(
                colors: [.appBackground, .appSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Лёгкий подсвет результата
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.appAccent.opacity(0.45), Color.clear]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .blur(radius: 40)
                .offset(y: -80)

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text(summary.didWin ? "Level complete" : "Try again")
                            .font(.system(size: 26, weight: .bold, design: .default))
                            .foregroundColor(.appTextPrimary)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 12)

                        Text("\(summary.game.displayName) • Level \(summary.levelIndex + 1)")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.appTextSecondary)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 12)
                    }
                    .padding(.top, 28)

                    starsSection

                    metricSection

                    buttonsSection
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: 390)
                .padding(.horizontal, 20)
            }

            if let achievement = lastUnlockedAchievement, showBanner {
                AchievementBannerView(achievement: achievement)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showContent = true
            }
            animateStars()
            animateMetricCard()
            if lastUnlockedAchievement != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showBanner = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showBanner = false
                        }
                    }
                }
            }
        }
    }

    private var starsSection: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                StarView(
                    filled: index < shownStars,
                    delay: Double(index) * 0.15
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.appSurface, Color.appBackground.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 8)
        )
    }

    private var metricSection: some View {
        VStack(spacing: 8) {
            Text(summary.primaryMetricLabel)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(.appTextSecondary)

            Text(summary.primaryMetricValue)
                .font(.system(size: 20, weight: .semibold, design: .default))
                .foregroundColor(.appTextPrimary)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color.appSurface, Color.appBackground.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)
        )
        .scaleEffect(showMetricCard ? 1.0 : 0.9)
        .opacity(showMetricCard ? 1.0 : 0.0)
    }

    private var buttonsSection: some View {
        VStack(spacing: 12) {
            Button(action: onBackToLevels) {
                HStack {
                    Text("Back to levels")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .background(Color.appSurface)
                .cornerRadius(16)
            }
            .buttonStyle(ScaledButtonStyle())
        }
    }

    private func animateStars() {
        shownStars = 0
        let clampedStars = max(0, min(3, summary.starsEarned))
        guard clampedStars > 0 else { return }

        for index in 0..<clampedStars {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    shownStars = index + 1
                }
            }
        }
    }

    private func animateMetricCard() {
        showMetricCard = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                showMetricCard = true
            }
        }
    }
}

private struct StarView: View {
    let filled: Bool
    let delay: Double

    @State private var animate: Bool = false

    var body: some View {
        Image(systemName: filled ? "star.fill" : "star")
            .font(.system(size: 28, weight: .semibold))
            .foregroundColor(filled ? .appPrimary : .appTextSecondary)
            .scaleEffect(animate && filled ? 1.2 : 1.0)
            .shadow(color: filled && animate ? Color.appPrimary.opacity(0.7) : Color.clear, radius: 10, x: 0, y: 0)
            .onAppear {
                guard filled else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        animate = true
                    }
                }
            }
    }
}

private struct AchievementBannerView: View {
    let achievement: AchievementDefinition

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.appBackground)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.appPrimary))

            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement unlocked")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundColor(.appTextPrimary)
                Text(achievement.title)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appSurface)
                .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

