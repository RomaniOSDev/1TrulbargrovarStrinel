//
//  ContentView.swift
//  1TrulbargrovarStrinel
//
//  Created by Роман Главацкий on 03.03.2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var storage = GameStorage()
    @State private var showOnboarding: Bool

    init() {
        let hasSeen = UserDefaults.standard.bool(forKey: GameStorage.Keys.hasSeenOnboarding)
        _showOnboarding = State(initialValue: !hasSeen)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.appBackground, .appSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Group {
                if showOnboarding {
                    OnboardingView {
                        storage.markOnboardingSeen()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showOnboarding = false
                        }
                    }
                } else {
                    RootGameContainerView()
                }
            }
            .environmentObject(storage)
        }
    }
}

