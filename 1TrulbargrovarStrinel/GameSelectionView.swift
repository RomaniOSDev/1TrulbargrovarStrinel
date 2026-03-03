import SwiftUI

struct GameSelectionView: View {
    @EnvironmentObject private var storage: GameStorage

    let game: GameIdentifier
    let onLevelSelected: (Int, GameDifficulty) -> Void

    @State private var selectedDifficulty: GameDifficulty = .easy

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(game.displayName)
                        .font(.system(size: 24, weight: .bold, design: .default))
                        .foregroundColor(.appTextPrimary)

                    Text(game.shortDescription)
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.top, 8)

                difficultySelector

                VStack(alignment: .leading, spacing: 12) {
                    Text("Levels")
                        .font(.system(size: 18, weight: .semibold, design: .default))
                        .foregroundColor(.appTextPrimary)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(0..<game.totalLevels, id: \.self) { levelIndex in
                            LevelCell(
                                game: game,
                                levelIndex: levelIndex,
                                difficulty: selectedDifficulty,
                                isUnlocked: storage.isLevelUnlocked(game: game, levelIndex: levelIndex),
                                stars: storage.stars(for: game, levelIndex: levelIndex),
                                onTap: {
                                    if storage.isLevelUnlocked(game: game, levelIndex: levelIndex) {
                                        onLevelSelected(levelIndex, selectedDifficulty)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: 390)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(game.displayName)
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundColor(.appTextPrimary)
            }
        }
    }

    private var difficultySelector: some View {
        HStack(spacing: 8) {
            ForEach(GameDifficulty.allCases) { difficulty in
                let isSelected = selectedDifficulty == difficulty

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedDifficulty = difficulty
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(difficulty.displayName)
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(isSelected ? .appBackground : .appTextSecondary)

                        HStack(spacing: 2) {
                            ForEach(0..<difficulty.indicatorDots, id: \.self) { _ in
                                Circle()
                                    .fill(isSelected ? Color.appBackground.opacity(0.9) : Color.appTextSecondary.opacity(0.6))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(isSelected ? Color.appPrimary : Color.appSurface)
                    .cornerRadius(14)
                }
                .buttonStyle(ScaledButtonStyle())
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color.appSurface.opacity(0.98), Color.appBackground.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
        )
    }
}

private struct LevelCell: View {
    let game: GameIdentifier
    let levelIndex: Int
    let difficulty: GameDifficulty
    let isUnlocked: Bool
    let stars: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            if isUnlocked {
                onTap()
            }
        }) {
            VStack(spacing: 6) {
                HStack {
                    Text("\(levelIndex + 1)")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(isUnlocked ? .appTextPrimary : .appTextSecondary)
                    Spacer()
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.appTextSecondary)
                    }
                }

                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .foregroundColor(index < stars ? .appPrimary : .appTextSecondary.opacity(0.5))
                            .font(.system(size: 10, weight: .semibold))
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.appSurface.opacity(isUnlocked ? 1.0 : 0.5),
                                Color.appBackground.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(isUnlocked ? 0.25 : 0.15), radius: 6, x: 0, y: 4)
            )
        }
        .buttonStyle(ScaledButtonStyle())
        .disabled(!isUnlocked)
    }
}

