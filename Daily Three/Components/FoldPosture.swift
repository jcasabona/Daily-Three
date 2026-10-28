//
//  FoldPosture.swift
//  Daily Three
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

/// How a half-folded foldable (the iPhone Duo) is being held. It decides how Today arranges itself.
enum FoldPosture: Equatable {
    /// Open flat, closed, or a device that doesn't fold.
    case flat
    /// Half-folded with a wide window: the crease runs up and down, so there's a left half and a right half.
    case book
    /// Half-folded with a tall window: the crease runs side to side, so there's a top half and a bottom half.
    case laptop

    /// The crease sits on the same side of the device however it's held, so rotating the window picks the posture.
    /// A tall window means the crease crosses it side to side. Flip this if the crease runs the other way on screen.
    static let creaseCrossesTallWindow = true

    static func posture(isHalfFolded: Bool, windowSize: CGSize) -> FoldPosture {
        guard isHalfFolded, windowSize.width > 0, windowSize.height > 0 else { return .flat }
        let isWide = windowSize.width > windowSize.height
        return isWide == creaseCrossesTallWindow ? .book : .laptop
    }
}

extension EnvironmentValues {
    @Entry var foldPosture: FoldPosture = .flat
}

#if os(iOS)
/// Reports whether the hinge is partly open. It draws nothing and ignores touches.
struct HingeReader: UIViewRepresentable {
    @Binding var isHalfFolded: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        if #available(iOS 27.1, *) {
            let interaction = UIHingeInteraction { _, update in
                isHalfFolded = update.hinge?.status == .partiallyOpen
            }
            interaction.isEnabled = true
            view.addInteraction(interaction)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
