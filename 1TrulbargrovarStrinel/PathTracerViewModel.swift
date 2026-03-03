import SwiftUI
import Combine

final class PathTracerViewModel: ObservableObject {
    @Published var pathPoints: [CGPoint] = []
    @Published var userTracePoints: [CGPoint] = []
    @Published var livesRemaining: Int
    @Published var accuracy: Double = 1.0
    @Published var progress: Double = 0.0
    @Published var isCompleted: Bool = false
    @Published var isFailed: Bool = false

    let levelIndex: Int
    let difficulty: GameDifficulty

    private let baseTolerance: CGFloat
    @Published var currentTolerance: CGFloat
    private let hasTimeLimit: Bool
    private let timeLimitSeconds: Int
    @Published var remainingTime: Int

    private var startDate: Date = Date()
    private var timerCancellable: AnyCancellable?
    private var timeCancellable: AnyCancellable?
    private var sampleCount: Int = 0
    private var insideCount: Int = 0
    private var isCurrentlyOffPath: Bool = false

    init(levelIndex: Int, difficulty: GameDifficulty) {
        self.levelIndex = levelIndex
        self.difficulty = difficulty

        let tol: CGFloat
        switch difficulty {
        case .easy:
            livesRemaining = 3
            tol = 0.10
            hasTimeLimit = false
            timeLimitSeconds = 0
        case .normal:
            livesRemaining = 2
            tol = 0.06
            hasTimeLimit = false
            timeLimitSeconds = 0
        case .hard:
            livesRemaining = 1
            tol = 0.04
            hasTimeLimit = true
            timeLimitSeconds = max(10, 25 - levelIndex * 2)
        }
        baseTolerance = tol
        currentTolerance = tol
        remainingTime = timeLimitSeconds

        pathPoints = PathTracerViewModel.buildPath(for: levelIndex)
        startDate = Date()

        if hasTimeLimit {
            startTimeLimit()
        }
    }

    var showsTimeLimit: Bool {
        hasTimeLimit && timeLimitSeconds > 0
    }

    private func startTimeLimit() {
        let publisher = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
        timeCancellable = publisher.sink { [weak self] _ in
            guard let self = self, self.hasTimeLimit, !self.isCompleted, !self.isFailed else { return }
            if self.remainingTime > 0 {
                self.remainingTime -= 1
            } else {
                self.fail()
            }
        }
    }

    func handleDrag(normalizedPoint: CGPoint, isEnded: Bool) {
        guard !isCompleted && !isFailed else { return }

        userTracePoints.append(normalizedPoint)

        let distance = distanceToPath(from: normalizedPoint)
        let isInside = distance <= currentTolerance

        sampleCount += 1
        if isInside {
            insideCount += 1
        }
        accuracy = sampleCount > 0 ? Double(insideCount) / Double(sampleCount) : 1.0

        // Мягкая адаптация сложности: если игрок сильно промахивается в начале пути, чуть расширяем допуск
        if !isInside && livesRemaining == 1 && progress < 0.3 && accuracy < 0.45 {
            let increased = currentTolerance + baseTolerance * 0.15
            currentTolerance = min(baseTolerance * 1.5, increased)
        }

        if isInside {
            let pathProgress = projectionProgress(for: normalizedPoint)
            progress = max(progress, pathProgress)
        }

        if !isInside && !isCurrentlyOffPath {
            isCurrentlyOffPath = true
            livesRemaining -= 1
            if livesRemaining <= 0 {
                fail()
            }
        } else if isInside {
            isCurrentlyOffPath = false
        }

        if progress >= 0.98 {
            complete()
        }

        if isEnded && !isCompleted && !isFailed && hasTimeLimit && remainingTime <= 0 {
            fail()
        }
    }

    private func complete() {
        guard !isCompleted else { return }
        isCompleted = true
        stopTimers()
    }

    private func fail() {
        guard !isFailed else { return }
        isFailed = true
        stopTimers()
    }

    private func stopTimers() {
        timerCancellable?.cancel()
        timerCancellable = nil
        timeCancellable?.cancel()
        timeCancellable = nil
    }

    func starsEarned() -> Int {
        guard isCompleted else { return 0 }
        switch accuracy {
        case 0.9...:
            return 3
        case 0.7...:
            return 2
        default:
            return 1
        }
    }

    func elapsedSeconds() -> Int {
        max(0, Int(Date().timeIntervalSince(startDate)))
    }

    private func distanceToPath(from point: CGPoint) -> CGFloat {
        guard pathPoints.count >= 2 else { return 1.0 }
        var minDistance = CGFloat.greatestFiniteMagnitude

        for index in 0..<(pathPoints.count - 1) {
            let a = pathPoints[index]
            let b = pathPoints[index + 1]
            let distance = distanceFrom(point, toSegmentFrom: a, to: b)
            if distance < minDistance {
                minDistance = distance
            }
        }

        return minDistance
    }

    private func projectionProgress(for point: CGPoint) -> Double {
        guard pathPoints.count >= 2 else { return 0.0 }
        var totalLength: CGFloat = 0.0
        var projectedLength: CGFloat = 0.0
        var bestProjectionLength: CGFloat = 0.0
        var minDistance = CGFloat.greatestFiniteMagnitude

        for index in 0..<(pathPoints.count - 1) {
            let a = pathPoints[index]
            let b = pathPoints[index + 1]
            let segment = distanceBetween(a, b)
            if segment > 0 {
                let (distance, projectionRatio) = distanceAndProjectionRatio(point, a, b)
                if distance < minDistance {
                    minDistance = distance
                    bestProjectionLength = totalLength + segment * max(0, min(1, projectionRatio))
                }
                totalLength += segment
            }
        }

        guard totalLength > 0 else { return 0.0 }
        projectedLength = bestProjectionLength
        return Double(projectedLength / totalLength)
    }

    private func distanceFrom(_ p: CGPoint, toSegmentFrom a: CGPoint, to b: CGPoint) -> CGFloat {
        let (distance, _) = distanceAndProjectionRatio(p, a, b)
        return distance
    }

    private func distanceAndProjectionRatio(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> (CGFloat, CGFloat) {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: p.x - a.x, y: p.y - a.y)
        let ab2 = ab.x * ab.x + ab.y * ab.y
        if ab2 == 0 {
            let dist = distanceBetween(p, a)
            return (dist, 0)
        }
        let t = (ap.x * ab.x + ap.y * ab.y) / ab2
        let clampedT = max(0, min(1, t))
        let projection = CGPoint(x: a.x + ab.x * clampedT, y: a.y + ab.y * clampedT)
        let dist = distanceBetween(p, projection)
        return (dist, t)
    }

    private func distanceBetween(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    private static func buildPath(for levelIndex: Int) -> [CGPoint] {
        let clampedLevel = max(0, min(levelIndex, 14))
        let segments = 10 + clampedLevel * 2       // уровни выше → больше точек и длиннее путь
        let pattern = clampedLevel % 3

        switch pattern {
        case 0:
            // Мягкая синусоида, чем выше уровень — тем больше "волн"
            var points: [CGPoint] = []
            let frequency = 1.0 + CGFloat(clampedLevel) / 4.0
            let amplitude: CGFloat = 0.25 + CGFloat(clampedLevel) * 0.015

            for i in 0...segments {
                let t = CGFloat(i) / CGFloat(segments)
                let x = 0.1 + 0.8 * t
                let yCenter: CGFloat = 0.5
                let rawY = yCenter + sin(t * .pi * frequency) * amplitude
                let y = min(0.9, max(0.1, rawY))
                points.append(CGPoint(x: x, y: y))
            }
            return points

        case 1:
            // Ярко выраженный "зигзаг" с подъёмом вверх
            var points: [CGPoint] = []
            var y: CGFloat = 0.15
            for i in 0...segments {
                let progress = CGFloat(i) / CGFloat(segments)
                // x скачет между тремя опорными точками
                let phase = i % 4
                let x: CGFloat
                switch phase {
                case 0: x = 0.15
                case 1: x = 0.85
                case 2: x = 0.25
                default: x = 0.75
                }
                points.append(CGPoint(x: x, y: y))
                // Медленный подъём вверх: уровни выше → чуть круче подъём
                y += 0.5 / CGFloat(segments) * (1.0 + CGFloat(clampedLevel) * 0.05)
                y = min(0.9, max(0.1, y))
            }
            return points

        default:
            // Ломаная "S‑образная" траектория: сначала вправо‑вверх, потом влево‑вверх
            var points: [CGPoint] = []
            let mid = segments / 2
            var x: CGFloat = 0.15
            var y: CGFloat = 0.2

            for i in 0...segments {
                let t = CGFloat(i) / CGFloat(segments)
                points.append(CGPoint(x: x, y: y))

                if i < mid {
                    // первая половина: вправо и немного вверх
                    x += 0.7 / CGFloat(mid)
                } else {
                    // вторая половина: влево и ещё выше
                    x -= 0.7 / CGFloat(segments - mid == 0 ? 1 : segments - mid)
                }

                y += (0.6 / CGFloat(segments)) * (1.0 + CGFloat(clampedLevel) * 0.03)
                x = min(0.9, max(0.1, x))
                y = min(0.9, max(0.1, y))
            }
            return points
        }
    }
}

struct PathTracerScreen: View {
    let game: GameIdentifier
    let levelIndex: Int
    let difficulty: GameDifficulty

    let onLevelCompleted: (LevelResultSummary, Int) -> Void

    @StateObject private var viewModel: PathTracerViewModel

    init(game: GameIdentifier, levelIndex: Int, difficulty: GameDifficulty, onLevelCompleted: @escaping (LevelResultSummary, Int) -> Void) {
        self.game = game
        self.levelIndex = levelIndex
        self.difficulty = difficulty
        self.onLevelCompleted = onLevelCompleted
        print("PathTracerScreen init game=\(game) level=\(levelIndex) difficulty=\(difficulty)")
        _viewModel = StateObject(wrappedValue: PathTracerViewModel(levelIndex: levelIndex, difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            GameBackgroundView()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    pathArea
                    infoSection
                }
                .frame(maxWidth: 390)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .id("pathTracer-\(game.rawValue)-\(levelIndex)-\(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Path Tracer")
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundColor(.appTextPrimary)
            }
        }
        .onChange(of: viewModel.isCompleted) { completed in
            if completed {
                fireCompletion(didWin: true)
            }
        }
        .onChange(of: viewModel.isFailed) { failed in
            if failed {
                fireCompletion(didWin: false)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Trace along the glowing path without leaving it.")
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(.appTextSecondary)

            Text("Level \(levelIndex + 1)")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundColor(.appTextPrimary)

            if levelIndex == 0 && difficulty == .easy {
                Text("Tip: move slowly and stay near the center of the glow.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.appTextSecondary)
            }

            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.appPrimary)
                        .font(.system(size: 13))
                    Text("\(viewModel.livesRemaining) life\(viewModel.livesRemaining == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.appTextSecondary)
                }
                Spacer()
                Text(difficulty.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundColor(.appTextPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.appSurface)
                    .cornerRadius(10)
            }

            if viewModel.showsTimeLimit {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .foregroundColor(.appTextSecondary)
                        .font(.system(size: 12))
                    Text("Time left: \(viewModel.remainingTime)s")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.appTextSecondary)
                    Spacer()
                }
            }
        }
    }

    private var pathArea: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.appSurface, Color.appBackground.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                let baseLineWidth: CGFloat = 7
                let extraWidth = CGFloat(viewModel.accuracy) * 4

                Path { path in
                    guard let first = viewModel.pathPoints.first else { return }
                    path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                    for point in viewModel.pathPoints.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.appAccent,
                            Color.appPrimary,
                            Color.appPrimary.opacity(0.7 + 0.3 * viewModel.accuracy)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: baseLineWidth + extraWidth, lineCap: .round, lineJoin: .round)
                )
                .opacity(0.9)

                Path { path in
                    guard let first = viewModel.userTracePoints.first else { return }
                    path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                    for point in viewModel.userTracePoints.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                    }
                }
                .stroke(
                    Color.appPrimary,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )

                if let last = viewModel.userTracePoints.last {
                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 18, height: 18)
                        .position(x: last.x * size.width, y: last.y * size.height)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = CGPoint(
                            x: max(0, min(1, value.location.x / size.width)),
                            y: max(0, min(1, value.location.y / size.height))
                        )
                        viewModel.handleDrag(normalizedPoint: point, isEnded: false)
                    }
                    .onEnded { value in
                        let point = CGPoint(
                            x: max(0, min(1, value.location.x / size.width)),
                            y: max(0, min(1, value.location.y / size.height))
                        )
                        viewModel.handleDrag(normalizedPoint: point, isEnded: true)
                    }
            )
        }
        .frame(height: 260)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Accuracy")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.appTextSecondary)
                Spacer()
                Text("\(Int(viewModel.accuracy * 100))%")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.appTextPrimary)
            }

            ProgressView(value: viewModel.accuracy)
                .progressViewStyle(LinearProgressViewStyle(tint: .appAccent))

            HStack {
                Text("Path progress")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.appTextSecondary)
                Spacer()
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.appTextSecondary)
            }

            ProgressView(value: viewModel.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .appAccent))
        }
    }

    private func fireCompletion(didWin: Bool) {
        let stars = viewModel.starsEarned()
        let accuracyPercent = Int(viewModel.accuracy * 100)
        let summary = LevelResultSummary(
            game: game,
            levelIndex: levelIndex,
            difficulty: difficulty,
            starsEarned: didWin ? stars : 0,
            primaryMetricLabel: "Trace accuracy",
            primaryMetricValue: "\(accuracyPercent)% • \(viewModel.livesRemaining) life\(viewModel.livesRemaining == 1 ? "" : "s") left",
            didWin: didWin
        )
        let elapsed = viewModel.elapsedSeconds()
        onLevelCompleted(summary, elapsed)
    }
}

