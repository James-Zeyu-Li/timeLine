import SwiftUI
import TimeLineCore

// MARK: - Header View
struct HeaderView: View {
    let focusedMinutes: Int
    let progress: Double
    var onDayTap: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                dayTapTarget {
                    HStack(spacing: 8) {
                        Text("Day")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        Text("1")
                            .font(.system(.title2, design: .rounded))
                            .bold()
                            .foregroundColor(.white)
                    }
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("\(focusedMinutes)")
                        .font(.system(.headline, design: .monospaced))
                        .bold()
                        .foregroundColor(.green)
                    Text("MIN")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.green.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TODAY'S PROGRESS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.white)
                }
                ProgressView(value: min(max(progress, 0), 1))
                    .progressViewStyle(.linear)
                    .tint(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24) // TimelineLayout.horizontalInset not available here, using 24
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.9))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .cyan.opacity(0.15), .clear], startPoint: .leading, endPoint: .trailing))
            .frame(height: 2)
        }
    }
    
    private func dayTapTarget<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Button(action: { onDayTap?() }) {
            content()
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(onDayTap == nil)
        .accessibilityLabel("Open stats")
        .accessibilityHint("Shows focus history and consistency")
    }
}

// MARK: - Section Header
struct TimelineSectionHeader: View {
    @Binding var isEditMode: Bool
    
    var body: some View {
        HStack {
            Text("YOUR JOURNEY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .tracking(1.2)
            Spacer()
            if !isEditMode {
                Button(action: { withAnimation { isEditMode = true } }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray.opacity(0.6))
                }
            } else {
                Button(action: { withAnimation { isEditMode = false } }) {
                    Text("Done")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Upcoming Label
struct TimelineUpcomingLabel: View {
    let timeText: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.system(size: 11))
                .foregroundColor(.cyan)
            Text(timeText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("— Upcoming")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
            Spacer()
        }
    }
}
