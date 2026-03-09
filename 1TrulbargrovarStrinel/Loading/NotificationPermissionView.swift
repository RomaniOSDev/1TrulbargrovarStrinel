//
//  NotificationPermissionView.swift
//  1TrulbargrovarStrinel
//
//  Custom notification permission screen before WebView.
//  Adapts to portrait and landscape.
//

import SwiftUI

struct NotificationPermissionView: View {
    var onAccept: () -> Void
    var onDecline: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appBackground, Color.appSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)
                    iconSection
                    Spacer(minLength: 28)
                    textSection
                    Spacer(minLength: 32)
                    buttonsSection
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 400)
            }
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 0) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 0) }
        }
    }

    private var iconSection: some View {
        Image(systemName: "bell.badge.fill")
            .font(.system(size: 56))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.appPrimary, Color.appAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var textSection: some View {
        VStack(spacing: 12) {
            Text("Enable Notifications")
                .font(.system(size: 22, weight: .semibold, design: .default))
                .foregroundColor(.appTextPrimary)
                .multilineTextAlignment(.center)
            Text("Stay updated with important news and offers. You can change this later in Settings.")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var buttonsSection: some View {
        VStack(spacing: 14) {
            Button(action: onAccept) {
                Text("Enable")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.appPrimary)
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)

            Button(action: onDecline) {
                Text("Not Now")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.appTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NotificationPermissionView(onAccept: {}, onDecline: {})
}
