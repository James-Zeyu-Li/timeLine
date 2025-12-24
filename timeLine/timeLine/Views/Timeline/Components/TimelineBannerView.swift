import SwiftUI
import TimeLineCore

// MARK: - UI Event Banners
enum BannerKind: Equatable {
    case distraction(wastedMinutes: Int)
    case restComplete
    case bonfireSuggested(reason: String)
}

struct BannerData: Identifiable, Equatable {
    let id = UUID()
    let kind: BannerKind
    let upNextTitle: String?
}

// MARK: - Info Banner
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
}
