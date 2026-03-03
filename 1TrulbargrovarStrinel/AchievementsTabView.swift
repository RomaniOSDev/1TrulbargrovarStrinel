import SwiftUI

struct AchievementsTabView: View {
    @EnvironmentObject private var storage: GameStorage

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(storage.achievements()) { achievement in
                    AchievementBadgeView(state: achievement)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: 390)
        }
        .navigationTitle("")
    }
}

private struct AchievementBadgeView: View {
    let state: AchievementState
    @State private var animateUnlock = false

    var body: some View {
        let isUnlocked = state.isUnlocked

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? Color.appPrimary : Color.appSurface.opacity(0.9))
                        .frame(width: 40, height: 40)

                    Image(systemName: state.definition.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isUnlocked ? .appBackground : .appTextSecondary)
                }
                .scaleEffect(animateUnlock && isUnlocked ? 1.1 : 1.0)

                Spacer()

                Image(systemName: isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isUnlocked ? .appPrimary : .appTextSecondary)
            }

            Text(state.definition.title)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(isUnlocked ? .appTextPrimary : .appTextSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(state.definition.description)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(.appTextSecondary)
                .lineLimit(3)
                .minimumScaleFactor(0.8)

            ProgressView(value: state.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .appAccent))
                .frame(height: 6)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.appSurface.opacity(0.9))
                )
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appSurface.opacity(isUnlocked ? 1.0 : 0.85),
                            Color.appBackground.opacity(isUnlocked ? 0.9 : 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .saturation(isUnlocked ? 1.0 : 0.0)
                .shadow(color: Color.black.opacity(isUnlocked ? 0.35 : 0.25), radius: 10, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.appPrimary.opacity(isUnlocked ? 0.9 : 0.0),
                            Color.appAccent.opacity(isUnlocked ? 0.7 : 0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isUnlocked ? 1.4 : 0.0
                )
        )
        .onAppear {
            if isUnlocked {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    animateUnlock = true
                }
            }
        }
    }
}

