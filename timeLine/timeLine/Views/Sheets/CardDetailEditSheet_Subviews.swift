import SwiftUI
import Foundation
import TimeLineCore

extension CardDetailEditSheet {
    // MARK: - Subviews
    
    func categoryButton(for category: TaskCategory) -> some View {
        VStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 24))
                .foregroundColor(draft.selectedCategory == category ? .white : category.color)
            
            Text(category.rawValue.capitalized)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(draft.selectedCategory == category ? .white : .gray)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(
            draft.selectedCategory == category ?
                LinearGradient(
                    colors: [category.color, category.color.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(colors: [Color(white: 0.1)], startPoint: .top, endPoint: .bottom)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    draft.selectedCategory == category ? category.color : Color(white: 0.2),
                    lineWidth: draft.selectedCategory == category ? 2 : 1
                )
        )
    }
    
    func modeButton(for mode: TaskMode) -> some View {
        Text(taskModeLabel(mode))
            .font(.system(.subheadline, design: .rounded))
            .fontWeight(draft.taskMode == mode ? .bold : .medium)
            .foregroundColor(draft.taskMode == mode ? .white : .gray)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                draft.taskMode == mode
                ? taskModeTint(mode).opacity(0.35)
                : Color(white: 0.1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        draft.taskMode == mode ? taskModeTint(mode) : Color(white: 0.2),
                        lineWidth: draft.taskMode == mode ? 2 : 1
                    )
            )
            .cornerRadius(10)
    }
    
    var reminderSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            DatePicker(
                "Remind At",
                selection: $draft.reminderTime,
                displayedComponents: [.date, .hourAndMinute]
            )
            .colorScheme(.dark)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Lead Time")
                    .font(.system(.subheadline))
                    .foregroundColor(.white)
                
                Picker("Lead Time", selection: $draft.leadTimeMinutes) {
                    Text("On Time").tag(0)
                    Text("5m early").tag(5)
                    Text("10m early").tag(10)
                    Text("30m early").tag(30)
                    Text("1h early").tag(60)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(16)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
    
    var durationSettingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duration")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(durationPresets, id: \.0) { (label, value) in
                    Button(action: {
                        draft.duration = value
                    }) {
                        Text(label)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(draft.duration == value ? .bold : .medium)
                            .foregroundColor(draft.duration == value ? .white : .gray)
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)
                            .background(
                                draft.duration == value ?
                                    LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [Color(white: 0.1)], startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(draft.duration == value ? .green : Color(white: 0.2), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
    
    var completionWindowView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Complete Within")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                ForEach(deadlineOptions, id: \.self) { option in
                    Button(action: {
                        draft.deadlineWindowDays = option
                    }) {
                        Text(deadlineLabel(option))
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(draft.deadlineWindowDays == option ? .bold : .medium)
                            .foregroundColor(draft.deadlineWindowDays == option ? .white : .gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                draft.deadlineWindowDays == option ?
                                    Color.orange.opacity(0.35) :
                                    Color(white: 0.1)
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(draft.deadlineWindowDays == option ? Color.orange : Color(white: 0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    var repeatSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Repeat Schedule")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                ForEach(RepeatType.allCases) { type in
                    Button(action: {
                        draft.repeatType = type
                        if type == .none {
                            draft.selectedWeekdays.removeAll()
                        }
                    }) {
                        Text(type.rawValue)
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(draft.repeatType == type ? .white : .gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                draft.repeatType == type ?
                                    Color.purple.opacity(0.3) :
                                    Color(white: 0.1)
                            )
                            .cornerRadius(8)
                    }
                }
            }
            
            if draft.repeatType == .weekly {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Days")
                        .font(.system(.subheadline))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { day in
                            let dayName = Calendar.current.shortWeekdaySymbols[day - 1]
                            Button(action: {
                                if draft.selectedWeekdays.contains(day) {
                                    draft.selectedWeekdays.remove(day)
                                } else {
                                    draft.selectedWeekdays.insert(day)
                                }
                            }) {
                                Text(String(dayName.prefix(1)))
                                    .font(.system(.caption, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(draft.selectedWeekdays.contains(day) ? .white : .gray)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        draft.selectedWeekdays.contains(day) ?
                                            Color.blue :
                                            Color(white: 0.1)
                                    )
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
            } else if draft.repeatType == .monthly {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Days of Month")
                        .font(.system(.subheadline))
                        .foregroundColor(.gray)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(1...31, id: \.self) { day in
                            Button(action: {
                                if draft.selectedWeekdays.contains(day) {
                                    draft.selectedWeekdays.remove(day)
                                } else {
                                    draft.selectedWeekdays.insert(day)
                                }
                            }) {
                                Text("\(day)")
                                    .font(.system(.caption2, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(draft.selectedWeekdays.contains(day) ? .white : .gray)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        draft.selectedWeekdays.contains(day) ?
                                            Color.purple :
                                            Color(white: 0.1)
                                    )
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
            }
        }
    }
}
