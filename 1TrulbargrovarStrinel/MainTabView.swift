import SwiftUI

enum MainTab: Hashable {
    case play
    case achievements
    case settings
}

struct MainTabView: View {
    @EnvironmentObject private var storage: GameStorage
    @State private var selectedTab: MainTab = .play

    let onSelectGame: (GameIdentifier) -> Void

    var body: some View {
        ZStack {
            BackgroundView()

            VStack(spacing: 0) {
                ZStack {
                    switch selectedTab {
                    case .play:
                        PlayTabView(onSelectGame: onSelectGame)
                    case .achievements:
                        AchievementsTabView()
                    case .settings:
                        SettingsTabView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 8)
            }
        }
    }
}

private struct BackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.appBackground, .appSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Canvas { context, size in
                let circles = 18
                for index in 0..<circles {
                    let normalized = CGFloat(index) / CGFloat(circles)
                    let x = size.width * CGFloat.random(in: 0.0...1.0)
                    let y = size.height * normalized
                    let opacity = 0.05 + 0.05 * normalized
                    let radius: CGFloat = 24
                    var path = Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius))
                    context.fill(path, with: .color(Color.appAccent.opacity(opacity)))
                }
            }
            .ignoresSafeArea()
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        HStack(spacing: 24) {
            tabButton(
                tab: .play,
                icon: "play.circle.fill",
                title: "Play"
            )
            tabButton(
                tab: .achievements,
                icon: "star.circle.fill",
                title: "Achievements"
            )
            tabButton(
                tab: .settings,
                icon: "slider.horizontal.3",
                title: "Settings"
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appSurface.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    private func tabButton(tab: MainTab, icon: String, title: String) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? .appPrimary : .appTextSecondary)
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundColor(isSelected ? .appPrimary : .appTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaledButtonStyle())
    }
}

