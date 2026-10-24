//
//  SurfaceStyle.swift
//  Daily Three
//

import SwiftUI

/// How content cards render. iOS keeps boxed cards; the Mac uses a flat, list-like look.
enum SurfaceStyle {
    case card
    case flat
}

extension EnvironmentValues {
    @Entry var surfaceStyle: SurfaceStyle = .card
}

/// Accent-colored section title with a thin rule underneath, used by the flat style.
struct FlatSectionHeader: View {
    let title: String
    let theme: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(theme.accent)
            Divider()
        }
    }
}
