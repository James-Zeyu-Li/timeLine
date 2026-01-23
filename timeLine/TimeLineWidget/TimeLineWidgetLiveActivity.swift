import ActivityKit
import WidgetKit
import SwiftUI
import TimeLineCore

@available(iOS 26.0, *)
struct TimeLineWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusSessionAttributes.self) { context in
            // MARK: - Lock Screen / Banner UI
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "hourglass.bottomhalf.filled")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(context.attributes.modeName)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Timer
                VStack(alignment: .trailing) {
                    if let endTime = context.state.endTime {
                        // Countdown
                        Text(timerInterval: context.state.startTime...endTime, countsDown: true)
                            .monospacedDigit()
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.yellow)
                    } else {
                        // Count Up (Focus Group / Flexible)
                        Text(timerInterval: context.state.startTime...Date().addingTimeInterval(36000), countsDown: false)
                            .monospacedDigit()
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.yellow)

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "hourglass.bottomhalf.filled")
                            .foregroundColor(.yellow)
                        Text(context.attributes.modeName)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Timer
                    if let endTime = context.state.endTime {
                        Text(timerInterval: context.state.startTime...endTime, countsDown: true)
                            .monospacedDigit()
                            .font(.headline)
                            .foregroundColor(.yellow)
                            .padding(.trailing, 8)
                    } else {
                        Text(timerInterval: context.state.startTime...Date().addingTimeInterval(36000), countsDown: false)
                            .monospacedDigit()
                            .font(.headline)
                            .foregroundColor(.yellow)
                            .padding(.trailing, 8)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // Title and Progress Bar (if strict)
                    VStack {
                        Text(context.attributes.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if let endTime = context.state.endTime {
                             ProgressView(timerInterval: context.state.startTime...endTime, countsDown: false)
                                .tint(.yellow)
                        }
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                // MARK: - Compact Leading
                Image(systemName: "hourglass.bottomhalf.filled")
                    .foregroundColor(.yellow)
                    .padding(.leading, 4)
            } compactTrailing: {
                // MARK: - Compact Trailing
                if let endTime = context.state.endTime {
                    Text(timerInterval: context.state.startTime...endTime, countsDown: true)
                        .monospacedDigit()
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .frame(minWidth: 40)
                        .padding(.trailing, 4)
                } else {
                    Text(timerInterval: context.state.startTime...Date().addingTimeInterval(36000), countsDown: false)
                        .monospacedDigit()
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .frame(minWidth: 40)
                        .padding(.trailing, 4)
                }
            } minimal: {
                // MARK: - Minimal
                Image(systemName: "hourglass")
                    .foregroundColor(.yellow)
            }
            .keylineTint(Color.yellow)
        }
    }
}
