import SwiftUI
import WidgetKit

@main
struct FastedWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FastStatusWidget()
        FastStageWidget()
        FastStreakWidget()
        EatingWindowWidget()
        FastControlWidget()
        FastSnoozeControlWidget()
        FastLiveActivity()
    }
}
