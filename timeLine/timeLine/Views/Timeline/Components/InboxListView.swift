import SwiftUI
import TimeLineCore

struct InboxListView: View {
    let items: [TaskTemplate]
    let onAdd: (TaskTemplate) -> Void
    let onRemove: (TaskTemplate) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("INBOX")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.gray)
                Spacer()
            }
            ForEach(items) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.category.icon)
                        .foregroundColor(item.category.color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.white)
                        Text(TimeFormatter.formatDuration(item.duration ?? 0))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button("Add") {
                        onAdd(item)
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyan)
                    Button {
                        onRemove(item)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(white: 0.06))
                .cornerRadius(10)
            }
        }
    }
}
