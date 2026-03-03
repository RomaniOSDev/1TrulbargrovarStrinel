import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var currentPage: Int = 0
    @State private var animateIllustration: Bool = false

    private let totalPages = 3

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                onboardingPage(
                    index: 0,
                    title: "Master the drop",
                    description: "Time your taps to land perfectly on moving targets.",
                    illustration: AnyView(PrecisionDropIllustration(isAnimated: animateIllustration))
                )
                .tag(0)

                onboardingPage(
                    index: 1,
                    title: "Trace the path",
                    description: "Follow glowing trails with steady, precise moves.",
                    illustration: AnyView(PathTracerIllustration(isAnimated: animateIllustration))
                )
                .tag(1)

                onboardingPage(
                    index: 2,
                    title: "Build the stack",
                    description: "Align sliding blocks to reach new heights.",
                    illustration: AnyView(StackRushIllustration(isAnimated: animateIllustration))
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: 390)

            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.appPrimary : Color.appTextSecondary.opacity(0.4))
                        .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.top, 16)

            Button(action: handleNext) {
                Text(currentPage == totalPages - 1 ? "Get Started" : "Next")
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundColor(.appBackground)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 32)
                    .frame(minWidth: 160, minHeight: 44)
                    .background(Color.appPrimary)
                    .cornerRadius(16)
                    .shadow(color: Color.appPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .scaleEffect(animateIllustration ? 1.0 : 0.98)
            }
            .buttonStyle(ScaledButtonStyle())
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateIllustration = true
            }
        }
        .onChange(of: currentPage) { _ in
            animateIllustration = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateIllustration = true
            }
        }
    }

    private func onboardingPage(index: Int, title: String, description: String, illustration: AnyView) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                illustration
                    .frame(height: 260)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)

                    Text(description)
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func handleNext() {
        if currentPage < totalPages - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage += 1
            }
        } else {
            onFinish()
        }
    }
}

private struct PrecisionDropIllustration: View {
    let isAnimated: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.appSurface.opacity(0.95), Color.appBackground.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)

                VStack {
                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: width * 0.18, height: width * 0.18)
                        .offset(y: isAnimated ? -height * 0.18 : -height * 0.28)
                        .opacity(isAnimated ? 1.0 : 0.0)
                        .animation(.linear(duration: 0.8).repeatForever(autoreverses: true), value: isAnimated)

                    Spacer()

                    HStack(spacing: 16) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(index == 1 ? Color.appAccent : Color.appSurface.opacity(0.7))
                                .frame(width: width * 0.18, height: 18)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            .scaleEffect(isAnimated ? 1.0 : 0.8)
            .opacity(isAnimated ? 1.0 : 0.0)
        }
    }
}

private struct PathTracerIllustration: View {
    let isAnimated: Bool

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.appSurface.opacity(0.96), Color.appBackground.opacity(0.9)],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)

                Path { path in
                    let w = size.width
                    let h = size.height
                    path.move(to: CGPoint(x: w * 0.1, y: h * 0.8))
                    path.addCurve(
                        to: CGPoint(x: w * 0.9, y: h * 0.2),
                        control1: CGPoint(x: w * 0.3, y: h * 0.1),
                        control2: CGPoint(x: w * 0.7, y: h * 0.9)
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [Color.appAccent, Color.appPrimary],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                )
                .opacity(0.9)

                Circle()
                    .fill(Color.appPrimary)
                    .frame(width: 18, height: 18)
                    .offset(x: isAnimated ? size.width * 0.32 : -size.width * 0.3, y: isAnimated ? -size.height * 0.22 : size.height * 0.22)
                    .opacity(isAnimated ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isAnimated)
            }
            .scaleEffect(isAnimated ? 1.0 : 0.8)
            .opacity(isAnimated ? 1.0 : 0.0)
        }
    }
}

private struct StackRushIllustration: View {
    let isAnimated: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.appSurface.opacity(0.96), Color.appBackground.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)

                VStack(spacing: 8) {
                    Spacer()

                    ForEach(0..<3, id: \.self) { index in
                        let factor = CGFloat(index + 1)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(index == 0 ? Color.appPrimary : Color.appAccent)
                            .frame(
                                width: width * (0.5 + 0.15 * CGFloat(2 - index)),
                                height: height * 0.10
                            )
                            .offset(x: isAnimated && index == 0 ? width * 0.08 : 0)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.75)
                                    .delay(0.1 * factor),
                                value: isAnimated
                            )
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scaleEffect(isAnimated ? 1.0 : 0.8)
            .opacity(isAnimated ? 1.0 : 0.0)
        }
    }
}

