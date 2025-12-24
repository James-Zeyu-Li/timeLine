import Foundation

/// 🎯 统一的时间格式化工具，避免重复代码
struct TimeFormatter {
    private static let clock24Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    private static let clock12Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    /// 格式化时长为简洁显示 (如: "30m", "1h", "90m")
    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
        return "\(minutes)m"
    }
    
    /// 格式化计时器显示 (如: "25:30")
    static func formatTimer(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// 格式化统计显示 (如: "2h 30m" 或 "45m")
    static func formatStats(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
    
    static func formatClock(_ date: Date, use24Hour: Bool) -> String {
        if use24Hour {
            return clock24Formatter.string(from: date)
        }
        return clock12Formatter.string(from: date)
    }
}
