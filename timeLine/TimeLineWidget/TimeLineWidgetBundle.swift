//
//  TimeLineWidgetBundle.swift
//  TimeLineWidget
//
//  Created by Zeyu Li on 1/22/26.
//

import WidgetKit
import SwiftUI

@main
struct TimeLineWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimeLineWidget()
        TimeLineWidgetControl()
        if #available(iOS 26.0, *) {
            TimeLineWidgetLiveActivity()
        }
    }
}
