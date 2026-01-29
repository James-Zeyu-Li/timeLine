import SwiftUI

struct TimelineHorizontalPagerView: View {
    let days: [TimelineDay]
    let onToggleCompletion: (TimelineTask) -> Void
    @Binding var isTodayVisible: Bool
    @Binding var selection: Date
    
    var body: some View {
        TabView(selection: $selection) {
            ForEach(days) { day in
                ScrollView {
                    TimelineDayView(day: day, onToggleCompletion: onToggleCompletion)
                        .padding(.top, 20) // Extra padding for specific pager look
                }
                .tag(day.date)
                // Remove standard scroll indicators to clean up UI? 
                // User said "clean". Scroll indicators are fine.
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onAppear {
            checkVisibility()
        }
        .onChange(of: selection) { _, _ in
            checkVisibility()
        }
    }
    
    private func checkVisibility() {
        let isToday = Calendar.current.isDateInToday(selection)
        if isTodayVisible != isToday {
            isTodayVisible = isToday
        }
    }
}
