//
//  WelcomeView.swift
//  Daily Three
//

import SwiftUI

/// Shown on a device's first launch while the app waits for iCloud to deliver any existing settings.
struct WelcomeView: View {
    let theme: ThemePalette

    private var year: Int {
        Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image("WelcomeIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    .accessibilityHidden(true)

                Text("Welcome to Daily Three")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)

                Text("The Task Journaling app that helps you understand how you work, so you can work better.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 420)

                ProgressView()
                    .padding(.top, 8)

                Spacer()

                Text("© \(String(year)) Joe Casabona, Streamlined Solopreneur")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeView(theme: ThemePalette(option: .graphite))
}
