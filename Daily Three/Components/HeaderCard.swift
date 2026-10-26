//
//  HeaderCard.swift
//  Daily Three
//

import SwiftUI

struct HeaderCard: View {
    let title: String
    let subtitle: String
    let theme: ThemePalette
    @Environment(\.surfaceStyle) private var style

    var body: some View {
        if style == .flat {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(.body))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                Text(subtitle)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
        }
    }
}
