//
//  Extensions.swift
//  Daily Three
//

import SwiftUI

extension View {
    @ViewBuilder
    func inlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

extension DayEntry {
    var hasAllTasksSet: Bool {
        !taskOne.trimmed.isEmpty && !taskTwo.trimmed.isEmpty && !taskThree.trimmed.isEmpty
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
