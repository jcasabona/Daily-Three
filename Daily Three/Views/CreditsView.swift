//
//  CreditsView.swift
//  Daily Three
//

import SwiftUI

struct CreditsView: View {
    let theme: ThemePalette

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Navy in light mode, cream in dark mode (see CreditsLogo in the asset catalog).
            Image("CreditsLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 96)
                .accessibilityLabel("Joe Casabona")

            Text("Created by Joe Casabona with the help of Claude Code. Initial codebase by Codex by OpenAI.")
                .font(.system(.body, design: .serif))
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Link(destination: URL(string: "https://streamlined.fm/#work")!) {
                    Text("Hire Me")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)

                Link(destination: URL(string: "https://casabona.org/donate")!) {
                    Text("☕ Donate")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(theme.accent)
            }

            Spacer()

            Text(verbatim: "© \(Calendar.current.component(.year, from: Date())) Good House Media, LLC")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .navigationTitle("Credits")
        .inlineNavigationBarTitle()
    }
}
