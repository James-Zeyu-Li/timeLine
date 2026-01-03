import SwiftUI
import TimeLineCore

struct ReminderBanner: View {
    let event: ReminderEvent
    let onComplete: () -> Void
    let onSnooze: () -> Void
    let onOpen: (() -> Void)?

    @AppStorage("use24HourClock") private var use24HourClock = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .foregroundColor(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("提醒")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                    Text(event.taskName)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                Spacer()
                if onOpen != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onOpen?()
            }

            Text(timingText)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 12) {
                Button(action: onComplete) {
                    Text("完成")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.cyan.opacity(0.9))
                        )
                }
                .buttonStyle(.plain)

                Button(action: onSnooze) {
                    Text("稍后 10 分钟")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var timingText: String {
        if event.isOverdue {
            return "已超过 \(formatClock(event.remindAt))"
        }
        let seconds = max(0, event.remainingSeconds)
        if let duration = CountdownFormatter.formatRemaining(seconds: seconds) {
            return "还有 \(duration)（\(formatClock(event.remindAt))）"
        }
        return "即将开始（\(formatClock(event.remindAt))）"
    }

    private func formatClock(_ date: Date) -> String {
        TimeFormatter.formatClock(date, use24Hour: use24HourClock)
    }
}
