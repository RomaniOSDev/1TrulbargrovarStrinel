import SwiftUI
import Combine

final class PrecisionDropViewModel: ObservableObject {
    @Published var targetPosition: CGFloat = 0.5
    @Published var ballProgress: CGFloat = 0.0
    @Published var isBallFalling: Bool = false
    @Published var dropsCompleted: Int = 0
    @Published var lastAccuracy: Double = 0.0
    @Published var averageAccuracy: Double = 0.0
    @Published var isLevelFinished: Bool = false
    @Published var didWin: Bool = false

    let maxDrops: Int
    let difficulty: GameDifficulty
    let levelIndex: Int

    private let targetSpeed: CGFloat
    let targetWidthFactor: CGFloat
    private let fakeZonesCount: Int
    private let obstacleCount: Int

    private var direction: CGFloat = 1.0

    private var timerCancellable: AnyCancellable?
    private var startDate: Date = Date()
    private var accumulatedAccuracy: Double = 0.0

    init(levelIndex: Int, difficulty: GameDifficulty) {
        self.levelIndex = levelIndex
        self.difficulty = difficulty

        let baseDrops = 4
        self.maxDrops = baseDrops + levelIndex / 2

        // Базовые параметры зависят от сложности
        let baseSpeed: CGFloat
        let baseWidth: CGFloat
        let baseFakeZones: Int
        let baseObstacles: Int

        switch difficulty {
        case .easy:
            baseSpeed = 0.30
            baseWidth = 0.22
            baseFakeZones = 0
            baseObstacles = 0
        case .normal:
            baseSpeed = 0.50
            baseWidth = 0.17
            baseFakeZones = 0
            baseObstacles = 1
        case .hard:
            baseSpeed = 0.75
            baseWidth = 0.15
            baseFakeZones = 1
            baseObstacles = 2
        }

        // Чем выше уровень, тем быстрее цель, уже зона и больше отвлекающих элементов
        let clampedLevel = CGFloat(min(max(levelIndex, 0), 14))
        let speedFactor: CGFloat = 1.0 + clampedLevel * 0.05
        let widthReduction: CGFloat = clampedLevel * 0.006

        targetSpeed = baseSpeed * speedFactor
        targetWidthFactor = max(0.08, baseWidth - widthReduction)
        fakeZonesCount = max(0, min(4, baseFakeZones + Int(clampedLevel / 3.0)))
        obstacleCount = max(0, min(5, baseObstacles + Int(clampedLevel / 2.0)))

        startTargetMotion()
        startDate = Date()
    }

    func startTargetMotion() {
        let publisher = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
        timerCancellable = publisher.sink { [weak self] _ in
            guard let self = self else { return }
            guard !self.isLevelFinished else { return }
            let delta: CGFloat = self.targetSpeed / 600.0
            self.targetPosition += delta * self.direction
            if self.targetPosition > 0.9 {
                self.targetPosition = 0.9
                self.direction = -1.0
            } else if self.targetPosition < 0.1 {
                self.targetPosition = 0.1
                self.direction = 1.0
            }
        }
    }

    func stopTargetMotion() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func dropBall() {
        guard !isBallFalling, !isLevelFinished else { return }
        isBallFalling = true
        ballProgress = 0.0

        withAnimation(.linear(duration: 0.7)) {
            self.ballProgress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.finishDrop()
        }
    }

    private func finishDrop() {
        guard isBallFalling else { return }
        isBallFalling = false
        dropsCompleted += 1

        let ballX: CGFloat = 0.5
        let distance = abs(ballX - targetPosition)
        let maxDistance: CGFloat = 0.5
        let accuracy = max(0.0, 1.0 - Double(distance / maxDistance))
        lastAccuracy = accuracy

        accumulatedAccuracy += accuracy
        averageAccuracy = accumulatedAccuracy / Double(dropsCompleted)

        if dropsCompleted >= maxDrops {
            completeLevel()
        }
    }

    private func completeLevel() {
        isLevelFinished = true
        stopTargetMotion()

        didWin = averageAccuracy > 0.25
    }

    func starsEarned() -> Int {
        guard didWin else { return 0 }
        switch averageAccuracy {
        case 0.8...:
            return 3
        case 0.55...:
            return 2
        default:
            return 1
        }
    }

    func elapsedSeconds() -> Int {
        max(0, Int(Date().timeIntervalSince(startDate)))
    }

    /// Нормализованные высоты (0–1) для горизонтальных препятствий
    func obstacleBands() -> [CGFloat] {
        guard obstacleCount > 0 else { return [] }
        let minY: CGFloat = 0.25
        let maxY: CGFloat = 0.75
        let step = (maxY - minY) / CGFloat(obstacleCount + 1)
        return (0..<obstacleCount).map { index in
            minY + step * CGFloat(index + 1)
        }
    }

    func fakeZones(totalWidth: CGFloat) -> [CGRect] {
        guard fakeZonesCount > 0 else { return [] }
        var rects: [CGRect] = []
        let height: CGFloat = 14
        for index in 0..<fakeZonesCount {
            let offset = CGFloat(index + 1) * (totalWidth * 0.2)
            let x = (index % 2 == 0) ? offset : totalWidth - offset
            let width = totalWidth * targetWidthFactor * 0.8
            let originX = max(0, min(totalWidth - width, x - width / 2))
            rects.append(CGRect(x: originX, y: 0, width: width, height: height))
        }
        return rects
    }
}

struct PrecisionDropScreen: View {
    let game: GameIdentifier
    let levelIndex: Int
    let difficulty: GameDifficulty

    let onLevelCompleted: (LevelResultSummary, Int) -> Void

    @StateObject private var viewModel: PrecisionDropViewModel
    @State private var highlightTarget: Bool = false

    init(game: GameIdentifier, levelIndex: Int, difficulty: GameDifficulty, onLevelCompleted: @escaping (LevelResultSummary, Int) -> Void) {
        self.game = game
        self.levelIndex = levelIndex
        self.difficulty = difficulty
        self.onLevelCompleted = onLevelCompleted
        print("PrecisionDropScreen init game=\(game) level=\(levelIndex) difficulty=\(difficulty)")
        _viewModel = StateObject(wrappedValue: PrecisionDropViewModel(levelIndex: levelIndex, difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            GameBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    dropArea
                    targetInfo
                    dropButton
                }
                .frame(maxWidth: 390)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .id("precision-\(game.rawValue)-\(levelIndex)-\(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Precision Drop")
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundColor(.appTextPrimary)
            }
        }
        .onChange(of: viewModel.lastAccuracy) { newValue in
            if newValue >= 0.85 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    highlightTarget = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        highlightTarget = false
                    }
                }
            }
        }
        .onChange(of: viewModel.isLevelFinished) { finished in
            if finished {
                let stars = viewModel.starsEarned()
                let accuracyPercent = Int(viewModel.averageAccuracy * 100)
                let summary = LevelResultSummary(
                    game: game,
                    levelIndex: levelIndex,
                    difficulty: difficulty,
                    starsEarned: stars,
                    primaryMetricLabel: "Average accuracy",
                    primaryMetricValue: "\(accuracyPercent)%",
                    didWin: viewModel.didWin
                )
                let elapsed = viewModel.elapsedSeconds()
                onLevelCompleted(summary, elapsed)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tap to drop when the target is aligned.")
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(.appTextSecondary)

            Text("Level \(levelIndex + 1)")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundColor(.appTextPrimary)

            if levelIndex == 0 && difficulty == .easy {
                Text("Tip: wait until the highlight zone is under the ball, then tap.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.appTextSecondary)
            }

            HStack {
                Text("Drop \(viewModel.dropsCompleted) of \(viewModel.maxDrops)")
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

    private var dropArea: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let targetWidth = width * viewModel.targetWidthFactor

            VStack {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.appSurface, Color.appBackground.opacity(0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.appPrimary.opacity(highlightTarget ? 0.8 : 0.0), lineWidth: highlightTarget ? 3 : 0)
                        )

                    VStack {
                        Circle()
                            .fill(Color.appPrimary)
                            .frame(width: 28, height: 28)
                            .offset(y: height * viewModel.ballProgress * 0.75)

                        Spacer()
                    }
                    .padding(.top, 16)

                    // Статические горизонтальные препятствия зависят от уровня
                    ForEach(viewModel.obstacleBands(), id: \.self) { band in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.appSurface.opacity(0.9))
                            .frame(height: 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.appAccent.opacity(0.8), lineWidth: 1)
                            )
                            .offset(y: band * height)
                    }

                    VStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.appSurface.opacity(0.9))
                                .frame(height: 18)

                            HStack(spacing: 0) {
                                targetBar(width: targetWidth, height: 18, widthTotal: width)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .frame(height: 260)
    }

    private func targetBar(width: CGFloat, height: CGFloat, widthTotal: CGFloat) -> some View {
        GeometryReader { _ in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appSurface.opacity(0.9))

                let targetCenter = viewModel.targetPosition * widthTotal
                let originX = max(0, min(widthTotal - width, targetCenter - width / 2))

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appAccent)
                    .frame(width: width, height: height)
                    .offset(x: originX)

                ForEach(Array(viewModel.fakeZones(totalWidth: widthTotal).enumerated()), id: \.offset) { _, rect in
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.appTextSecondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .frame(width: rect.width, height: height)
                        .offset(x: rect.origin.x)
                }
            }
        }
    }

    private var targetInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last drop accuracy")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.appTextSecondary)

            HStack {
                Text("\(Int(viewModel.lastAccuracy * 100))%")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundColor(.appTextPrimary)
                Spacer()
                Text("Average \(Int(viewModel.averageAccuracy * 100))%")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.appTextSecondary)
            }
        }
    }

    private var dropButton: some View {
        Button {
            viewModel.dropBall()
        } label: {
            HStack {
                Text("Drop")
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
            .cornerRadius(16)
        }
        .buttonStyle(ScaledButtonStyle())
        .disabled(viewModel.isBallFalling)
    }
}

