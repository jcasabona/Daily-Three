//
//  ThemePalette.swift
//  Daily Three
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
typealias PlatformColor = UIColor
#else
typealias PlatformColor = NSColor
#endif

struct ThemePalette {
    let option: ThemeOption

    var accent: Color {
        dynamicColor(light: palette.accentLight, dark: palette.accentDark)
    }

    var background: Color {
        dynamicColor(light: palette.backgroundLight, dark: palette.backgroundDark)
    }

    var card: Color {
        dynamicColor(light: palette.cardLight, dark: palette.cardDark)
    }

    var field: Color {
        dynamicColor(light: palette.fieldLight, dark: palette.fieldDark)
    }

    var border: Color {
        dynamicColor(light: palette.borderLight, dark: palette.borderDark)
    }

    var muted: Color {
        Color.secondary
    }

    #if os(iOS)
    private func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
    #else
    private func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
    #endif

    private var palette: ThemePaletteValues {
        switch option {
        case .sunrise:
            return ThemePaletteValues(
                backgroundLight: PlatformColor(red: 0.99, green: 0.95, blue: 0.90, alpha: 1),
                backgroundDark: PlatformColor(red: 0.16, green: 0.12, blue: 0.11, alpha: 1),
                accentLight: PlatformColor(red: 0.95, green: 0.48, blue: 0.30, alpha: 1),
                accentDark: PlatformColor(red: 0.99, green: 0.67, blue: 0.44, alpha: 1)
            )
        case .ocean:
            return ThemePaletteValues(
                backgroundLight: PlatformColor(red: 0.91, green: 0.96, blue: 0.99, alpha: 1),
                backgroundDark: PlatformColor(red: 0.09, green: 0.12, blue: 0.18, alpha: 1),
                accentLight: PlatformColor(red: 0.16, green: 0.47, blue: 0.78, alpha: 1),
                accentDark: PlatformColor(red: 0.46, green: 0.73, blue: 0.92, alpha: 1)
            )
        case .forest:
            return ThemePaletteValues(
                backgroundLight: PlatformColor(red: 0.92, green: 0.97, blue: 0.93, alpha: 1),
                backgroundDark: PlatformColor(red: 0.10, green: 0.14, blue: 0.11, alpha: 1),
                accentLight: PlatformColor(red: 0.18, green: 0.54, blue: 0.34, alpha: 1),
                accentDark: PlatformColor(red: 0.50, green: 0.78, blue: 0.60, alpha: 1)
            )
        case .graphite:
            return ThemePaletteValues(
                backgroundLight: PlatformColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1),
                backgroundDark: PlatformColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1),
                accentLight: PlatformColor(red: 0.32, green: 0.33, blue: 0.36, alpha: 1),
                accentDark: PlatformColor(red: 0.72, green: 0.73, blue: 0.76, alpha: 1)
            )
        }
    }

    private struct ThemePaletteValues {
        let backgroundLight: PlatformColor
        let backgroundDark: PlatformColor
        let accentLight: PlatformColor
        let accentDark: PlatformColor

        var cardLight: PlatformColor { backgroundLight.withAlphaComponent(0.8) }
        var cardDark: PlatformColor { PlatformColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1) }
        var fieldLight: PlatformColor { PlatformColor.white.withAlphaComponent(0.75) }
        var fieldDark: PlatformColor { PlatformColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1) }
        var borderLight: PlatformColor { PlatformColor.black.withAlphaComponent(0.12) }
        var borderDark: PlatformColor { PlatformColor.white.withAlphaComponent(0.12) }
    }
}

extension ThemeOption {
    var displayName: String {
        switch self {
        case .sunrise:
            return "Sunrise"
        case .ocean:
            return "Ocean"
        case .forest:
            return "Forest"
        case .graphite:
            return "Graphite"
        }
    }
}

extension AppearanceMode {
    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
