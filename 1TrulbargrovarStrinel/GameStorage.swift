import Foundation
import Combine

enum GameIdentifier: String, CaseIterable, Identifiable {
    case precisionDrop = "precision_drop"
    case pathTracer = "path_tracer"
    case stackRush = "stack_rush"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .precisionDrop:
            return "Precision Drop"
        case .pathTracer:
            return "Path Tracer"
        case .stackRush:
            return "Stack Rush"
        }
    }

    var shortDescription: String {
        switch self {
        case .precisionDrop:
            return "Tap to drop with perfect timing."
        case .pathTracer:
            return "Trace the glowing path with precision."
        case .stackRush:
            return "Stack sliding blocks as high as you can."
        }
    }

    var totalLevels: Int {
        // Shared level count per game; can be tuned independently if needed
        switch self {
        case .precisionDrop:
            return 15
        case .pathTracer:
            return 15
        case .stackRush:
            return 15
        }
    }
}

enum GameDifficulty: String, CaseIterable, Identifiable {
    case easy
    case normal
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        }
    }

    var indicatorDots: Int {
        switch self {
        case .easy: return 1
        case .normal: return 2
        case .hard: return 3
        }
    }
}

struct LevelResultSummary: Hashable {
    let game: GameIdentifier
    let levelIndex: Int
    let difficulty: GameDifficulty
    let starsEarned: Int
    let primaryMetricLabel: String
    let primaryMetricValue: String
    let didWin: Bool
}

struct AchievementDefinition: Identifiable, Hashable {
    enum Kind: Hashable {
        case totalGames(Int)
        case totalStars(Int)
        case bestLevel(game: GameIdentifier, level: Int)
        case highAccuracy
        case longSessionTime(Int)
    }

    let id: String
    let iconName: String
    let title: String
    let description: String
    let kind: Kind
}

struct AchievementState: Identifiable, Hashable {
    let definition: AchievementDefinition
    let isUnlocked: Bool
    let progress: Double

    var id: String { definition.id }
}

struct FocusGoalState: Identifiable, Hashable {
    enum Kind: Hashable {
        case completedLevels(Int)
        case totalStars(Int)
        case bestLevelAnyGame(Int)
    }

    let id: String
    let title: String
    let description: String
    let kind: Kind
    let progress: Double
    let isCompleted: Bool
}

extension Notification.Name {
    static let gameStorageDidReset = Notification.Name("gameStorageDidReset")
}

final class GameStorage: ObservableObject {
    struct Keys {
        static let starsPerLevel = "starsPerLevel"
        static let unlockedLevels = "unlockedLevels"
        static let totalGamesPlayed = "totalGamesPlayed"
        static let totalStarsEarned = "totalStarsEarned"
        static let bestLevelPerGame = "bestLevelPerGame"
        static let totalPlayTimeSeconds = "totalPlayTimeSeconds"
        static let hasSeenOnboarding = "hasSeenOnboarding"
    }

    @Published private(set) var starsPerLevel: [String: [Int]]
    @Published private(set) var unlockedLevels: [String: Int]
    @Published private(set) var totalGamesPlayed: Int
    @Published private(set) var totalStarsEarned: Int
    @Published private(set) var bestLevelPerGame: [String: Int]
    @Published private(set) var totalPlayTimeSeconds: Int
    @Published var hasSeenOnboarding: Bool

    @Published private(set) var lastUnlockedAchievement: AchievementDefinition?

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let starsDict = userDefaults.dictionary(forKey: Keys.starsPerLevel) as? [String: [Int]] ?? [:]
        let unlockedDict = userDefaults.dictionary(forKey: Keys.unlockedLevels) as? [String: Int] ?? [:]
        let bestLevelDict = userDefaults.dictionary(forKey: Keys.bestLevelPerGame) as? [String: Int] ?? [:]

        self.starsPerLevel = starsDict
        self.unlockedLevels = unlockedDict
        self.totalGamesPlayed = userDefaults.integer(forKey: Keys.totalGamesPlayed)
        self.totalStarsEarned = userDefaults.integer(forKey: Keys.totalStarsEarned)
        self.bestLevelPerGame = bestLevelDict
        self.totalPlayTimeSeconds = userDefaults.integer(forKey: Keys.totalPlayTimeSeconds)
        self.hasSeenOnboarding = userDefaults.bool(forKey: Keys.hasSeenOnboarding)
    }

    // MARK: - Public API

    func stars(for game: GameIdentifier, levelIndex: Int) -> Int {
        let array = normalizedStarsArray(for: game)
        guard levelIndex >= 0 && levelIndex < array.count else { return 0 }
        return array[levelIndex]
    }

    func highestUnlockedLevel(for game: GameIdentifier) -> Int {
        let stored = unlockedLevels[game.rawValue] ?? 0
        return min(max(stored, 0), game.totalLevels - 1)
    }

    func isLevelUnlocked(game: GameIdentifier, levelIndex: Int) -> Bool {
        levelIndex <= highestUnlockedLevel(for: game)
    }

    func bestLevelIndex(for game: GameIdentifier) -> Int {
        min(bestLevelPerGame[game.rawValue] ?? 0, game.totalLevels - 1)
    }

    func registerLevelCompletion(summary: LevelResultSummary, playTimeSeconds: Int) {
        let gameId = summary.game.rawValue

        totalGamesPlayed += 1
        totalPlayTimeSeconds = max(0, totalPlayTimeSeconds + max(playTimeSeconds, 0))

        var starsArray = normalizedStarsArray(for: summary.game)
        let previousStars = starsArray[summary.levelIndex]
        let newStars = max(previousStars, summary.starsEarned)
        starsArray[summary.levelIndex] = newStars
        starsPerLevel[gameId] = starsArray

        if newStars > previousStars {
            totalStarsEarned += (newStars - previousStars)
        }

        if summary.didWin && newStars > 0 {
            let currentUnlocked = highestUnlockedLevel(for: summary.game)
            if summary.levelIndex >= currentUnlocked && summary.levelIndex < summary.game.totalLevels - 1 {
                unlockedLevels[gameId] = summary.levelIndex + 1
            }

            let currentBest = bestLevelPerGame[gameId] ?? 0
            if summary.levelIndex > currentBest {
                bestLevelPerGame[gameId] = summary.levelIndex
            }
        }

        persist()
        evaluateAchievementsAfterUpdate()
    }

    func markOnboardingSeen() {
        hasSeenOnboarding = true
        userDefaults.set(true, forKey: Keys.hasSeenOnboarding)
    }

    func resetAll() {
        starsPerLevel = [:]
        unlockedLevels = [:]
        totalGamesPlayed = 0
        totalStarsEarned = 0
        bestLevelPerGame = [:]
        totalPlayTimeSeconds = 0
        hasSeenOnboarding = false
        lastUnlockedAchievement = nil

        userDefaults.removeObject(forKey: Keys.starsPerLevel)
        userDefaults.removeObject(forKey: Keys.unlockedLevels)
        userDefaults.removeObject(forKey: Keys.totalGamesPlayed)
        userDefaults.removeObject(forKey: Keys.totalStarsEarned)
        userDefaults.removeObject(forKey: Keys.bestLevelPerGame)
        userDefaults.removeObject(forKey: Keys.totalPlayTimeSeconds)
        userDefaults.removeObject(forKey: Keys.hasSeenOnboarding)

        NotificationCenter.default.post(name: .gameStorageDidReset, object: nil)
    }

    func starsString(for game: GameIdentifier) -> String {
        let array = normalizedStarsArray(for: game)
        let sum = array.reduce(0, +)
        let maxStars = game.totalLevels * 3
        return "\(sum) / \(maxStars)"
    }

    func achievements() -> [AchievementState] {
        let defs = Self.achievementDefinitions
        return defs.map { definition in
            let (unlocked, progress) = progress(for: definition)
            return AchievementState(definition: definition, isUnlocked: unlocked, progress: progress)
        }
    }

    func focusGoals() -> [FocusGoalState] {
        let completedLevels = totalCompletedLevels()
        let targetCompletedLevels = 5
        let progressCompleted = min(Double(completedLevels) / Double(targetCompletedLevels), 1.0)

        let targetStars = 15
        let progressStars = min(Double(totalStarsEarned) / Double(targetStars), 1.0)

        let bestAnyGame = GameIdentifier.allCases
            .map { bestLevelIndex(for: $0) }
            .max() ?? 0
        let targetBestLevel = 4 // уровень 5 с точки зрения игрока
        let progressBest = min(Double(bestAnyGame) / Double(targetBestLevel), 1.0)

        return [
            FocusGoalState(
                id: "goal_completed_levels",
                title: "Complete 5 levels",
                description: "Finish any 5 levels with at least 1 star.",
                kind: .completedLevels(targetCompletedLevels),
                progress: progressCompleted,
                isCompleted: completedLevels >= targetCompletedLevels
            ),
            FocusGoalState(
                id: "goal_earn_stars",
                title: "Earn 15 stars",
                description: "Collect stars across all games.",
                kind: .totalStars(targetStars),
                progress: progressStars,
                isCompleted: totalStarsEarned >= targetStars
            ),
            FocusGoalState(
                id: "goal_reach_level5_any",
                title: "Reach level 5",
                description: "Reach level 5 in any game.",
                kind: .bestLevelAnyGame(targetBestLevel),
                progress: progressBest,
                isCompleted: bestAnyGame >= targetBestLevel
            )
        ]
    }

    // MARK: - Private helpers

    private func normalizedStarsArray(for game: GameIdentifier) -> [Int] {
        let existing = starsPerLevel[game.rawValue] ?? []
        if existing.count >= game.totalLevels {
            return Array(existing.prefix(game.totalLevels))
        } else {
            return existing + Array(repeating: 0, count: game.totalLevels - existing.count)
        }
    }

    private func totalCompletedLevels() -> Int {
        GameIdentifier.allCases.reduce(0) { partial, game in
            let starsArray = normalizedStarsArray(for: game)
            let completedForGame = starsArray.filter { $0 > 0 }.count
            return partial + completedForGame
        }
    }

    private func persist() {
        userDefaults.set(starsPerLevel, forKey: Keys.starsPerLevel)
        userDefaults.set(unlockedLevels, forKey: Keys.unlockedLevels)
        userDefaults.set(totalGamesPlayed, forKey: Keys.totalGamesPlayed)
        userDefaults.set(totalStarsEarned, forKey: Keys.totalStarsEarned)
        userDefaults.set(bestLevelPerGame, forKey: Keys.bestLevelPerGame)
        userDefaults.set(totalPlayTimeSeconds, forKey: Keys.totalPlayTimeSeconds)
    }

    // MARK: - Achievements

    private static let achievementDefinitions: [AchievementDefinition] = [
        AchievementDefinition(
            id: "play_5_games",
            iconName: "gamecontroller",
            title: "Getting Started",
            description: "Play 5 games.",
            kind: .totalGames(5)
        ),
        AchievementDefinition(
            id: "play_20_games",
            iconName: "gamecontroller.fill",
            title: "Game Enthusiast",
            description: "Play 20 games.",
            kind: .totalGames(20)
        ),
        AchievementDefinition(
            id: "earn_15_stars",
            iconName: "star",
            title: "Rising Star",
            description: "Earn 15 stars.",
            kind: .totalStars(15)
        ),
        AchievementDefinition(
            id: "earn_40_stars",
            iconName: "star.fill",
            title: "Star Collector",
            description: "Earn 40 stars.",
            kind: .totalStars(40)
        ),
        AchievementDefinition(
            id: "precision_level_5",
            iconName: "target",
            title: "Focused Mind",
            description: "Reach level 6 in Precision Drop.",
            kind: .bestLevel(game: .precisionDrop, level: 5)
        ),
        AchievementDefinition(
            id: "path_level_5",
            iconName: "scribble.variable",
            title: "Path Master",
            description: "Reach level 6 in Path Tracer.",
            kind: .bestLevel(game: .pathTracer, level: 5)
        ),
        AchievementDefinition(
            id: "stack_level_5",
            iconName: "square.stack.3d.up",
            title: "Tower Builder",
            description: "Reach level 6 in Stack Rush.",
            kind: .bestLevel(game: .stackRush, level: 5)
        ),
        AchievementDefinition(
            id: "play_30_minutes",
            iconName: "clock",
            title: "Persistent Player",
            description: "Play for 30 minutes in total.",
            kind: .longSessionTime(30 * 60)
        )
    ]

    private func progress(for definition: AchievementDefinition) -> (Bool, Double) {
        switch definition.kind {
        case .totalGames(let target):
            let value = Double(totalGamesPlayed)
            let unlocked = totalGamesPlayed >= target
            let progress = min(value / Double(target), 1.0)
            return (unlocked, progress)
        case .totalStars(let target):
            let value = Double(totalStarsEarned)
            let unlocked = totalStarsEarned >= target
            let progress = min(value / Double(target), 1.0)
            return (unlocked, progress)
        case .bestLevel(let game, let level):
            let currentBest = bestLevelIndex(for: game)
            let unlocked = currentBest >= level
            let totalLevels = max(level, 1)
            let progress = min(Double(currentBest) / Double(totalLevels), 1.0)
            return (unlocked, progress)
        case .highAccuracy:
            // Derived dynamically per level, tracked via stars; treat as unlocked when enough stars earned.
            let targetStars = 25
            let value = Double(totalStarsEarned)
            let unlocked = totalStarsEarned >= targetStars
            let progress = min(value / Double(targetStars), 1.0)
            return (unlocked, progress)
        case .longSessionTime(let targetSeconds):
            let value = Double(totalPlayTimeSeconds)
            let unlocked = totalPlayTimeSeconds >= targetSeconds
            let progress = min(value / Double(targetSeconds), 1.0)
            return (unlocked, progress)
        }
    }

    private func evaluateAchievementsAfterUpdate() {
        let states = achievements()
        let newlyUnlocked = states.first(where: { $0.isUnlocked && lastUnlockedAchievement?.id != $0.id })
        lastUnlockedAchievement = newlyUnlocked?.definition
    }
}

