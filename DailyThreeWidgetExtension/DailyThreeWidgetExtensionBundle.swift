//
//  DailyThreeWidgetExtensionBundle.swift
//  DailyThreeWidgetExtension
//
//  Created by Joe Casabona on 3/5/26.
//

import WidgetKit
import SwiftUI

@main
struct DailyThreeWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        DailyThreeWidgetExtension()
        NextUpWidget()
        JournalWidget()
    }
}
