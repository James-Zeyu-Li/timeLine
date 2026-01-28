import SwiftUI
import Foundation
import TimeLineCore

extension AdventurerLogView {
    var navigationHeader: some View {
        HStack {
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PixelTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: PixelTheme.cardShadow, radius: 4, x: 0, y: 2)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Statistics")
                    .font(.system(.headline, design: .serif))
                    .fontWeight(.bold)
                    .foregroundColor(PixelTheme.textPrimary)
                Text("STATS & RECORDS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(PixelTheme.primary)
            }
            
            Spacer()
            
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PixelTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: PixelTheme.cardShadow, radius: 4, x: 0, y: 2)
            }
        }
        .padding(.bottom, 8)
    }
    
    var rangePicker: some View {
        HStack(spacing: 4) {
            ForEach(StatsTimeRange.allCases) { range in
                Button {
                    withAnimation {
                        viewModel.updateSelectedRange(range)
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.selectedRange == range ? PixelTheme.primary : PixelTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewModel.selectedRange == range ? Color.white : Color.clear)
                        .cornerRadius(20)
                        .shadow(color: viewModel.selectedRange == range ? PixelTheme.cardShadow : .clear, radius: 4, x: 0, y: 2)
                }
            }
        }
        .padding(4)
        .background(PixelTheme.woodLight.opacity(0.1)) // Subtle background
        .cornerRadius(24)
    }
    
    var progressHeaderText: String {
        switch viewModel.selectedRange {
        case .day: return "TODAY'S PROGRESS"
        case .week: return "WEEKLY PROGRESS"
        case .year: return "YEARLY PROGRESS"
        }
    }
    
    func headerText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1)
            .foregroundColor(PixelTheme.secondary)
            .opacity(0.8)
    }
    
    func calculateLevel(xp: Int) -> Int {
        // Simple linear level curve: 1000 XP per level
        return max(1, xp / 1000)
    }
}
