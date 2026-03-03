import SwiftUI

struct PlayTabView: View {
    @EnvironmentObject private var storage: GameStorage

    let onSelectGame: (GameIdentifier) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                let totalStars = storage.totalStarsEarned
                let totalGames = storage.totalGamesPlayed
                let recommended = GameIdentifier.allCases.min { lhs, rhs in
                    storage.bestLevelIndex(for: lhs) < storage.bestLevelIndex(for: rhs)
                } ?? .precisionDrop

                HomeHeroView(
                    totalStars: totalStars,
                    totalGames: totalGames,
                    recommendedGame: recommended,
                    onQuickPlay: {
                        onSelectGame(recommended)
                    }
                )
                .padding(.top, 8)

                FocusGoalsSection(goals: storage.focusGoals())

                VStack(spacing: 16) {
                    ForEach(GameIdentifier.allCases) { game in
                        GameCardView(
                            game: game,
                            starsSummary: storage.starsString(for: game),
                            onPlay: {
                                onSelectGame(game)
                            }
                        )
                    }
                }
            }
            .frame(maxWidth: 390)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

private struct HomeHeroView: View {
    let totalStars: Int
    let totalGames: Int
    let recommendedGame: GameIdentifier
    let onQuickPlay: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color.appPrimary, Color.appAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 10)
                .overlay(
                    ZStack {
                        Circle()
                            .strokeBorder(Color.appBackground.opacity(0.18), lineWidth: 10)
                            .scaleEffect(1.2)
                            .offset(x: 80, y: -40)
                        Circle()
                            .strokeBorder(Color.appBackground.opacity(0.14), lineWidth: 6)
                            .scaleEffect(0.9)
                            .offset(x: -60, y: 50)
                    }
                )

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily precision journey")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundColor(.appBackground)

                    Text("Warm up your focus and continue where your skills are growing fastest.")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.appBackground.opacity(0.9))
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalStars)")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.appBackground)
                        Text("Total stars")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.appBackground.opacity(0.85))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalGames)")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.appBackground)
                        Text("Games played")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.appBackground.opacity(0.85))
                    }

                    Spacer()
                }

                Button(action: onQuickPlay) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appBackground)
                        Text("Quick play: \(recommendedGame.displayName)")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(.appBackground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(Color.appBackground.opacity(0.12))
                    .cornerRadius(16)
                }
                .buttonStyle(ScaledButtonStyle())
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FocusGoalsSection: View {
    let goals: [FocusGoalState]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus goals")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .foregroundColor(.appTextPrimary)

            VStack(spacing: 10) {
                ForEach(goals) { goal in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(goal.title)
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundColor(.appTextPrimary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            if goal.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.appPrimary)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }

                        Text(goal.description)
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.appTextSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        ProgressView(value: goal.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .appAccent))
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.appSurface.opacity(0.95))
                    )
                }
            }
        }
    }
}

private struct GameCardView: View {
    let game: GameIdentifier
    let starsSummary: String
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.displayName)
                        .font(.system(size: 18, weight: .semibold, design: .default))
                        .foregroundColor(.appTextPrimary)

                    Text(game.shortDescription)
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.appTextSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.appPrimary)
                            .font(.system(size: 14, weight: .semibold))
                        Text(starsSummary)
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.appTextSecondary)
                    }
                    Text("Total stars")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.appTextSecondary.opacity(0.8))
                }
            }

            Button(action: onPlay) {
                HStack {
                    Text("Play")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.appBackground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appBackground)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(Color.appPrimary)
                .cornerRadius(14)
            }
            .buttonStyle(ScaledButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.appPrimary.opacity(0.6), lineWidth: 1.2)
                )
        )
    }
}

