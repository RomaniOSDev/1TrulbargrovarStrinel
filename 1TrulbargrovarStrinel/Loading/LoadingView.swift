//
//  LoadingView.swift
//  1TrulbargrovarStrinel
//
//  Экран загрузки в стиле приложения: градиент, анимированный индикатор.
//  Адаптируется под портретную и альбомную ориентацию.
//

import SwiftUI

/// Три точки с последовательной пульсацией (анимированный индикатор).
struct AnimatedLoadingIndicator: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appPrimary, Color.appAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 16, height: 16)
                        .scaleEffect(bounceScale(t: t, index: index))
                }
            }
        }
    }

    private func bounceScale(t: TimeInterval, index: Int) -> CGFloat {
        let period: Double = 0.6
        let offset = Double(index) * 0.2
        let x = (t + offset).truncatingRemainder(dividingBy: period) / period
        let y = sin(x * .pi)
        return CGFloat(0.7 + 0.3 * max(0, y))
    }
}

/// Кольцо загрузки с вращением и градиентом.
struct RingLoadingIndicator: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.appSurface.opacity(0.5), lineWidth: 4)
                .frame(width: 56, height: 56)
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Color.appPrimary, Color.appAccent, Color.appPrimary]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

/// Полноэкранный экран загрузки: градиент как в приложении + анимированный индикатор.
struct LoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appBackground, Color.appSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                RingLoadingIndicator()
                AnimatedLoadingIndicator()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    LoadingView()
}
