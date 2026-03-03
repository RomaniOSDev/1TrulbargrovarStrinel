import SwiftUI

enum RootRoute: Hashable {
    case gameSelection(GameIdentifier)
    case precisionGame(GameIdentifier, Int, GameDifficulty, UUID)
    case pathGame(GameIdentifier, Int, GameDifficulty, UUID)
    case stackGame(GameIdentifier, Int, GameDifficulty, UUID)
    case levelResult(LevelResultSummary)
}

struct RootGameContainerView: View {
    @EnvironmentObject private var storage: GameStorage
    @State private var path: [RootRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            MainTabView(
                onSelectGame: { game in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        print("RootGameContainerView: select game \(game)")
                        path.append(.gameSelection(game))
                    }
                }
            )
            .navigationDestination(for: RootRoute.self) { route in
                switch route {
                case .gameSelection(let game):
                    GameSelectionView(
                        game: game,
                        onLevelSelected: { levelIndex, difficulty in
                            pushGame(for: game, levelIndex: levelIndex, difficulty: difficulty)
                        }
                    )
                case .precisionGame(let game, let levelIndex, let difficulty, _):
                    PrecisionDropScreen(
                        game: game,
                        levelIndex: levelIndex,
                        difficulty: difficulty
                    ) { summary, playTime in
                        handleLevelCompletion(summary: summary, playTime: playTime)
                    }
                case .pathGame(let game, let levelIndex, let difficulty, _):
                    PathTracerScreen(
                        game: game,
                        levelIndex: levelIndex,
                        difficulty: difficulty
                    ) { summary, playTime in
                        handleLevelCompletion(summary: summary, playTime: playTime)
                    }
                case .stackGame(let game, let levelIndex, let difficulty, _):
                    StackRushScreen(
                        game: game,
                        levelIndex: levelIndex,
                        difficulty: difficulty
                    ) { summary, playTime in
                        handleLevelCompletion(summary: summary, playTime: playTime)
                    }
                case .levelResult(let summary):
                    LevelResultView(
                        summary: summary,
                        lastUnlockedAchievement: storage.lastUnlockedAchievement,
                        onNextLevel: {
                            navigateToNextLevel(from: summary)
                        },
                        onRetry: {
                            retryLevel(for: summary)
                        },
                        onBackToLevels: {
                            popBackToSelection(for: summary.game)
                        }
                    )
                }
            }
        }
    }

    private func pushGame(for game: GameIdentifier, levelIndex: Int, difficulty: GameDifficulty) {
        let route = routeForGame(game, levelIndex: levelIndex, difficulty: difficulty)
        withAnimation(.easeInOut(duration: 0.3)) {
            let uiLevel = levelIndex + 1
            print("RootGameContainerView: pushGame \(game) level \(uiLevel) difficulty \(difficulty)")
            path.append(route)
        }
    }

    private func handleLevelCompletion(summary: LevelResultSummary, playTime: Int) {
        storage.registerLevelCompletion(summary: summary, playTimeSeconds: playTime)
        withAnimation(.easeInOut(duration: 0.3)) {
            let uiLevel = summary.levelIndex + 1
            print("RootGameContainerView: handleLevelCompletion game=\(summary.game) level=\(uiLevel) stars=\(summary.starsEarned) didWin=\(summary.didWin)")
            path.append(.levelResult(summary))
        }
    }

    private func navigateToNextLevel(from summary: LevelResultSummary) {
        let nextIndex = summary.levelIndex + 1
        guard nextIndex < summary.game.totalLevels else {
            print("RootGameContainerView: next level out of range, popping to selection")
            popBackToSelection(for: summary.game)
            return
        }
        let nextRoute = routeForGame(summary.game, levelIndex: nextIndex, difficulty: summary.difficulty)

        withAnimation(.easeInOut(duration: 0.3)) {
            let fromLevel = summary.levelIndex + 1
            let toLevel = nextIndex + 1
            print("RootGameContainerView: navigateToNextLevel game=\(summary.game) from \(fromLevel) to \(toLevel)")
            // Удаляем экран результата, если он последний
            if let last = path.last, case .levelResult(let s) = last, s == summary {
                path.removeLast()
            }

            // Заменяем предыдущий экран игры на новый уровень
            if let last = path.last {
                switch last {
                case .precisionGame(let g, _, _, _),
                     .pathGame(let g, _, _, _),
                     .stackGame(let g, _, _, _):
                    if g == summary.game {
                        path.removeLast()
                    }
                default:
                    break
                }
            }

            path.append(nextRoute)
        }
    }

    private func retryLevel(for summary: LevelResultSummary) {
        let sameRoute = routeForGame(summary.game, levelIndex: summary.levelIndex, difficulty: summary.difficulty)

        withAnimation(.easeInOut(duration: 0.3)) {
            let uiLevel = summary.levelIndex + 1
            print("RootGameContainerView: retryLevel game=\(summary.game) level=\(uiLevel)")
            // Удаляем экран результата, если он последний
            if let last = path.last, case .levelResult(let s) = last, s == summary {
                path.removeLast()
            }

            // Заменяем предыдущий экран игры на тот же уровень
            if let last = path.last {
                switch last {
                case .precisionGame(let g, _, _, _),
                     .pathGame(let g, _, _, _),
                     .stackGame(let g, _, _, _):
                    if g == summary.game {
                        path.removeLast()
                    }
                default:
                    break
                }
            }

            path.append(sameRoute)
        }
    }

    private func popBackToSelection(for game: GameIdentifier) {
        // Pop everything until we reach selection for this game, or root
        while let last = path.last {
            switch last {
            case .gameSelection(let g) where g == game:
                print("RootGameContainerView: popBackToSelection reached selection for \(game)")
                return
            default:
                print("RootGameContainerView: popBackToSelection removing \(last)")
                path.removeLast()
            }
        }
    }

    private func routeForGame(_ game: GameIdentifier, levelIndex: Int, difficulty: GameDifficulty) -> RootRoute {
        let token = UUID()
        switch game {
        case .precisionDrop:
            return .precisionGame(game, levelIndex, difficulty, token)
        case .pathTracer:
            return .pathGame(game, levelIndex, difficulty, token)
        case .stackRush:
            return .stackGame(game, levelIndex, difficulty, token)
        }
    }
}

