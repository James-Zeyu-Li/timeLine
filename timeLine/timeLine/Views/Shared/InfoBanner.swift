import SwiftUI
import TimeLineCore

enum BannerKind: Equatable {
    case distraction(wastedMinutes: Int)
    case incompleteExit(focusedSeconds: TimeInterval, remainingSeconds: TimeInterval?)
    case explorationComplete(focusedSeconds: TimeInterval)
    case restComplete
    case bonfireSuggested(reason: String)
}

struct BannerData: Identifiable, Equatable {
    let id = UUID()
    let kind: BannerKind
    let upNextTitle: String?
}

struct InfoBanner: View {
    let data: BannerData
    var body: some View {
        HStack(spacing: 10) {
            switch data.kind {
            case .distraction(let wasted):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Retreat / Distraction")
                        .font(.caption).bold().foregroundColor(.white)
                    Text("Wasted +\(wasted) min")
                        .font(.caption2).foregroundColor(.gray)
                }
            case .incompleteExit(let focusedSeconds, let remainingSeconds):
                Image(systemName: "flag.fill")
                    .foregroundColor(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("撤退（未完成）")
                        .font(.caption).bold().foregroundColor(.white)
                    Text(incompleteExitSubtitle(focusedSeconds: focusedSeconds, remainingSeconds: remainingSeconds))
                        .font(.caption2).foregroundColor(.gray)
                }
            case .explorationComplete(let focusedSeconds):
                Image(systemName: "sparkles")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("探险结束")
                        .font(.caption).bold().foregroundColor(.white)
                    Text("已专注 \(formatDuration(focusedSeconds))")
                        .font(.caption2).foregroundColor(.gray)
                }
            case .restComplete:
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest complete")
                        .font(.caption).bold().foregroundColor(.white)
                    if let title = data.upNextTitle {
                        Text("Up next: \(title)")
                            .font(.caption2).foregroundColor(.gray)
                    }
                }
            case .bonfireSuggested(let reason):
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("前面有个篝火，要不要歇一会？")
                        .font(.caption).bold().foregroundColor(.white)
                    Text(reason)
                        .font(.caption2).foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.1).opacity(0.95))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
    private func incompleteExitSubtitle(focusedSeconds: TimeInterval, remainingSeconds: TimeInterval?) -> String {
        let focusedText = formatDuration(focusedSeconds)
        if let remaining = remainingSeconds {
            let remainingText = formatDuration(remaining)
            return "已造成 \(focusedText) 伤害，剩余 \(remainingText)"
        }
        return "已造成 \(focusedText) 伤害"
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds.rounded() / 60))
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}
