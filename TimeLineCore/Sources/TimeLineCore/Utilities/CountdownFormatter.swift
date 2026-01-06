import Foundation

public enum CountdownFormatter {
    public static func formatRelative(seconds: TimeInterval) -> String? {
        let remaining = Int(seconds)
        guard remaining > 0 else { return nil }
        if remaining < 60 {
            return "in \(remaining)s"
        }
        let minutes = remaining / 60
        if minutes < 60 {
            return "in \(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "in \(hours)h"
        }
        return "in \(hours)h \(remainingMinutes)m"
    }

    public static func formatRemaining(seconds: TimeInterval) -> String? {
        let remaining = Int(seconds)
        guard remaining > 0 else { return nil }
        if remaining < 60 {
            return "\(remaining)s"
        }
        let minutes = remaining / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainingMinutes)m"
    }
}
