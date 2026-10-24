//
//  Pickers.swift
//  Daily Three
//

import SwiftUI

struct ThemePicker: View {
    @Binding var selection: ThemeOption
    let theme: ThemePalette

    var body: some View {
        VStack(spacing: 12) {
            ForEach(ThemeOption.allCases, id: \.self) { option in
                Button(action: { selection = option }) {
                    HStack {
                        Circle()
                            .fill(ThemePalette(option: option).accent)
                            .frame(width: 18, height: 18)
                        Text(option.displayName)
                        Spacer()
                        if selection == option {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .padding(12)
                    .background(theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct AppearancePicker: View {
    @Binding var selection: AppearanceMode
    let theme: ThemePalette

    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                Button(action: { selection = mode }) {
                    Text(mode.displayName)
                        .font(.system(.subheadline, design: .serif))
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selection == mode ? theme.accent : theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.headline, design: .serif))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
