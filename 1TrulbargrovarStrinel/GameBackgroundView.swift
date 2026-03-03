import SwiftUI

struct GameBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.appBackground, .appSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                // Мягкие светящиеся круги
                let circleCount = 10
                for index in 0..<circleCount {
                    let progress = CGFloat(index) / CGFloat(circleCount)
                    let radius: CGFloat = 80 + 40 * progress
                    let x = size.width * CGFloat.random(in: 0.1...0.9)
                    let y = size.height * progress
                    var path = Path(ellipseIn: CGRect(x: x - radius / 2, y: y - radius / 2, width: radius, height: radius))
                    context.fill(path, with: .radialGradient(
                        .init(colors: [Color.appAccent.opacity(0.22), Color.clear]),
                        center: .init(x: x, y: y),
                        startRadius: 0,
                        endRadius: radius
                    ))
                }

                // Лёгкие диагональные штрихи
                let stripeCount = 6
                for index in 0..<stripeCount {
                    let progress = CGFloat(index) / CGFloat(stripeCount)
                    let y = size.height * progress
                    var path = Path()
                    path.move(to: CGPoint(x: -40, y: y))
                    path.addLine(to: CGPoint(x: size.width + 40, y: y + 80))
                    context.stroke(
                        path,
                        with: .color(Color.appPrimary.opacity(0.05)),
                        lineWidth: 1.0
                    )
                }
            }
            .blendMode(.plusLighter)
            .opacity(0.8)
        }
        .ignoresSafeArea()
    }
}

