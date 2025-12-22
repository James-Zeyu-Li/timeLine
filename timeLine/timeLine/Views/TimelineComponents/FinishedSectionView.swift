import SwiftUI
import TimeLineCore

// MARK: - Finished Thumbnail Row
struct FinishedThumbnailRow: View {
    let node: TimelineNode
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.02))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            // Optional: could open details in the future
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .onLongPressGesture(minimumDuration: 0.3) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .contextMenu {
            Button { /* TODO: share */ } label: { Label("Share", systemImage: "square.and.arrow.up") }
            Button { /* TODO: details */ } label: { Label("View Details", systemImage: "doc.text.magnifyingglass") }
            Button { /* TODO: restore to upcoming */ } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
        }
    }
    private var iconName: String {
        switch node.type {
        case .battle(let boss): return boss.style == .passive ? "figure.walk" : "bolt.fill"
        case .bonfire: return "flame"
        case .treasure: return "star"
        }
    }
    private var title: String {
        switch node.type {
        case .battle(let boss): return boss.name
        case .bonfire: return "Rest"
        case .treasure: return "Reward"
        }
    }
    private var subtitle: String? {
        switch node.type {
        case .battle(let boss): return "\(Int(boss.maxHp / 60)) min"
        case .bonfire(let duration): return "Rest • \(Int(duration / 60)) min"
        case .treasure: return nil
        }
    }
}

// MARK: - PullDownProbeView
struct PullDownProbeView: View {
    @Binding var showFinished: Bool
    let hasFinishedNodes: Bool
    
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onChange(of: geo.frame(in: .named("scroll")).minY) { _, minY in
                    // 1. Overscroll down (pulling past top) reveals Finished
                    if minY > 120, !showFinished, hasFinishedNodes {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            showFinished = true
                        }
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                    // 2. Scroll up (content moves up) automatically hides Finished
                    else if minY < -60, showFinished {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                            showFinished = false
                        }
                    }
                }
        }
    }
}

// MARK: - Finished Section
struct FinishedSectionView: View {
    let finishedNodes: [TimelineNode]
    @Binding var showFinished: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with count - always visible when there are finished items
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    showFinished.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: showFinished ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("Completed")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Text("\(finishedNodes.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(6)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            
            // Expanded list of finished items
            if showFinished {
                VStack(spacing: 6) {
                    ForEach(finishedNodes) { node in
                        FinishedThumbnailRow(node: node)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 24)
        }
        .background(Color.black.opacity(0.3))
    }
}
