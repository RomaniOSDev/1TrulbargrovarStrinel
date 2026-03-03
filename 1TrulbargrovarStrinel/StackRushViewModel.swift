import SwiftUI
import Combine

struct StackBlock: Identifiable {
    let id = UUID()
    var centerX: CGFloat
    var width: CGFloat
}

final class StackRushViewModel: ObservableObject {
    @Published var blocks: [StackBlock] = []
    @Published var activeIndex: Int = 0
    @Published var isMoving: Bool = true
    @Published var isGameOver: Bool = false
    @Published var didWin: Bool = false
    @Published var maxCombo: Int = 0
    @Published var currentCombo: Int = 0

    let levelIndex: Int
    let difficulty: GameDifficulty

    private let speed: CGFloat
    private let minBlockWidth: CGFloat = 0.12
    private let requiredStackHeight: Int

    private var direction: CGFloat = 1.0
    private var timerCancellable: AnyCancellable?
    private var startDate: Date = Date()

    init(levelIndex: Int, difficulty: GameDifficulty) {
        self.levelIndex = levelIndex
        self.difficulty = difficulty

        // Базовая скорость от сложности
        let baseSpeed: CGFloat
        switch difficulty {
        case .easy:
            baseSpeed = 0.30
        case .normal:
            baseSpeed = 0.55
        case .hard:
            baseSpeed = 0.80
        }
        // С ростом уровня скорость плавно увеличивается
        let clampedLevel = CGFloat(min(max(levelIndex, 0), 14))
        let speedFactor: CGFloat = 1.0 + clampedLevel * 0.06
        speed = baseSpeed * speedFactor

        requiredStackHeight = min(5 + levelIndex / 2, 12)

        let baseBlock = StackBlock(centerX: 0.5, width: 0.6)
        let movingBlock = StackBlock(centerX: 0.1, width: 0.6)
        blocks = [baseBlock, movingBlock]
        activeIndex = 1
        startDate = Date()
        startMovement()
    }

    private func startMovement() {
        let publisher = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
        timerCancellable = publisher.sink { [weak self] _ in
            guard let self = self else { return }
            guard self.isMoving, !self.isGameOver else { return }
            var active = self.blocks[self.activeIndex]
            let delta = self.speed / 500.0
            active.centerX += delta * self.direction
            if active.centerX > 0.9 {
                active.centerX = 0.9
                self.direction = -1.0
            } else if active.centerX < 0.1 {
                active.centerX = 0.1
                self.direction = 1.0
            }
            self.blocks[self.activeIndex] = active
        }
    }

    private func stopMovement() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func tap() {
        guard !isGameOver else { return }
        isMoving = false

        let current = blocks[activeIndex]
        let previous = blocks[activeIndex - 1]

        let currentLeft = current.centerX - current.width / 2
        let currentRight = current.centerX + current.width / 2
        let prevLeft = previous.centerX - previous.width / 2
        let prevRight = previous.centerX + previous.width / 2

        let overlapLeft = max(currentLeft, prevLeft)
        let overlapRight = min(currentRight, prevRight)
        let overlapWidth = overlapRight - overlapLeft

        guard overlapWidth > 0, overlapWidth >= minBlockWidth else {
            endGame(won: false)
            return
        }

        var newWidth = overlapWidth
        if difficulty == .hard {
            newWidth *= 0.95
        }
        let newCenter = overlapLeft + newWidth / 2

        let isPerfect = abs(newWidth - previous.width) < 0.02 && abs(newCenter - previous.centerX) < 0.02
        if isPerfect {
            currentCombo += 1
            maxCombo = max(maxCombo, currentCombo)
        } else {
            currentCombo = 0
        }

        blocks[activeIndex] = StackBlock(centerX: newCenter, width: newWidth)

        if activeIndex + 1 >= requiredStackHeight + 1 {
            endGame(won: true)
            return
        }

        let nextStartX: CGFloat = direction > 0 ? 0.1 : 0.9
        let nextWidth = max(newWidth, minBlockWidth)
        let nextBlock = StackBlock(centerX: nextStartX, width: nextWidth)
        blocks.append(nextBlock)
        activeIndex += 1
        isMoving = true
    }

    private func endGame(won: Bool) {
        isGameOver = true
        didWin = won
        stopMovement()
    }

    func starsEarned() -> Int {
        guard didWin else { return 0 }
        let heightReached = activeIndex
        if heightReached >= requiredStackHeight + 2 || maxCombo >= 3 {
            return 3
        } else if heightReached >= requiredStackHeight {
            return 2
        } else {
            return 1
        }
    }

    func elapsedSeconds() -> Int {
        max(0, Int(Date().timeIntervalSince(startDate)))
    }
}

struct StackRushScreen: View {
    let game: GameIdentifier
    let levelIndex: Int
    let difficulty: GameDifficulty

    let onLevelCompleted: (LevelResultSummary, Int) -> Void

    @StateObject private var viewModel: StackRushViewModel
    @State private var flashTower: Bool = false

    init(game: GameIdentifier, levelIndex: Int, difficulty: GameDifficulty, onLevelCompleted: @escaping (LevelResultSummary, Int) -> Void) {
        self.game = game
        self.levelIndex = levelIndex
        self.difficulty = difficulty
        self.onLevelCompleted = onLevelCompleted
        print("StackRushScreen init game=\(game) level=\(levelIndex) difficulty=\(difficulty)")
        _viewModel = StateObject(wrappedValue: StackRushViewModel(levelIndex: levelIndex, difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            GameBackgroundView()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    stackArea
                    infoSection
                    tapHint
                }
                .frame(maxWidth: 390)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .id("stack-\(game.rawValue)-\(levelIndex)-\(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Stack Rush")
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundColor(.appTextPrimary)
            }
        }
        .onChange(of: viewModel.isGameOver) { isOver in
            if isOver {
                let stars = viewModel.starsEarned()
                let summary = LevelResultSummary(
                    game: game,
                    levelIndex: levelIndex,
                    difficulty: difficulty,
                    starsEarned: viewModel.didWin ? stars : 0,
                    primaryMetricLabel: "Stack height",
                    primaryMetricValue: "\(viewModel.activeIndex) blocks • Combo x\(max(viewModel.maxCombo, 1))",
                    didWin: viewModel.didWin
                )
                let elapsed = viewModel.elapsedSeconds()
                onLevelCompleted(summary, elapsed)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.tap()
        }
        .onChange(of: viewModel.currentCombo) { newValue in
            if newValue >= 3 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    flashTower = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        flashTower = false
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stop each sliding block to keep it aligned and build a tall stack.")
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(.appTextSecondary)

            Text("Level \(levelIndex + 1)")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundColor(.appTextPrimary)

            if levelIndex == 0 && difficulty == .easy {
                Text("Tip: tap when the moving block is centered on the one below.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.appTextSecondary)
            }

            HStack {
                Text("Level goal: \(viewModel.levelIndex + 5) blocks")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.appTextSecondary)
                Spacer()
                Text(difficulty.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundColor(.appTextPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.appSurface)
                    .cornerRadius(10)
            }
        }
    }

    private var stackArea: some View {
        GeometryReader { geo in
            let size = geo.size
            let blockHeight = size.height * 0.08

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.appSurface, Color.appBackground.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                ForEach(Array(viewModel.blocks.enumerated()), id: \.element.id) { index, block in
                    let isActive = index == viewModel.activeIndex
                    let baseY = size.height * 0.78
                    let y = baseY - CGFloat(index) * (blockHeight + 4)
                    let width = block.width * size.width
                    let x = block.centerX * size.width

                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? Color.appPrimary : Color.appAccent)
                        .frame(width: width, height: blockHeight)
                        .position(x: x, y: y)
                        .shadow(color: isActive ? Color.appPrimary.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 4)
                        .scaleEffect(isActive ? 1.02 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
                }

                if flashTower {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.appPrimary.opacity(0.9), lineWidth: 3)
                        .shadow(color: Color.appPrimary.opacity(0.7), radius: 12, x: 0, y: 0)
                }
            }
        }
        .frame(height: 260)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Blocks placed")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.appTextSecondary)
                Spacer()
                Text("\(viewModel.activeIndex)")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.appTextPrimary)
            }
            HStack {
                Text("Current combo")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.appTextSecondary)
                Spacer()
                Text("x\(max(viewModel.currentCombo, 1))")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.appTextPrimary)
            }
        }
    }

    private var tapHint: some View {
        Text("Tap anywhere while the moving block is above the stack to place it.")
            .font(.system(size: 13, weight: .regular, design: .default))
            .foregroundColor(.appTextSecondary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
}

