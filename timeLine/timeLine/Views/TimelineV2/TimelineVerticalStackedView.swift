import SwiftUI

struct TimelineVerticalStackedView: View {
    @ObservedObject var store: TimelineV2Store
    let days: [TimelineDay]
    let onToggleCompletion: (TimelineTask) -> Void
    @Binding var isTodayVisible: Bool

    @State private var todayID: Date?
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(days) { day in
                        TimelineDayView(day: day, onToggleCompletion: onToggleCompletion)
                            .id(day.date)
                            .padding(.vertical, 12)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onChange(of: geo.frame(in: .named("VerticalScrollSpace"))) { _, frame in
                                            updateTodayVisibility(for: day, frame: frame)
                                        }
                                }
                            )
                            .scrollTargetLayout()
                    }
                }
                .scrollTargetBehavior(.viewAligned)
            }
            .coordinateSpace(name: "VerticalScrollSpace")
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { viewportHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, newValue in
                            viewportHeight = newValue
                        }
                }
            )
            .onAppear {
                if let today = days.first(where: { Calendar.current.isDateInToday($0.date) }) {
                    todayID = today.date
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(today.date, anchor: .top)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToTodayVertical)) { _ in
                if let todayID {
                    withAnimation {
                        proxy.scrollTo(todayID, anchor: .top)
                    }
                }
            }
        }
    }

    private func updateTodayVisibility(for day: TimelineDay, frame: CGRect) {
        guard Calendar.current.isDateInToday(day.date) else { return }
        let isVisible = frame.maxY > 0 && frame.minY < viewportHeight
        if isTodayVisible != isVisible {
            isTodayVisible = isVisible
        }
    }
}

