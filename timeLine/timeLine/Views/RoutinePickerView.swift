import SwiftUI
import TimeLineCore

struct RoutinePickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var daySession: DaySession
    
    let routines = RoutineProvider.defaults
    
    // Selection state for detail sheet
    @State private var selectedRoutine: RoutineTemplate? = nil
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Available Packs")) {
                    ForEach(routines) { routine in
                        Button(action: {
                            selectedRoutine = routine
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(routine.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text(routineDescription(routine))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "cube.box") // Pack icon
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Routine Packs")
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
            // Detail Sheet (The "Preview")
            .sheet(item: $selectedRoutine) { routine in
                RoutineDetailSheet(routine: routine) {
                    daySession.appendRoutine(routine)
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    func routineDescription(_ routine: RoutineTemplate) -> String {
        let count = routine.presets.count
        let totalDuration = routine.presets.reduce(0) { $0 + $1.duration }
        return "\(count) tasks • \(formatDuration(totalDuration))"
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration / 60)
        let h = m / 60
        if h > 0 { return "\(h)h \(m % 60)m" }
        return "\(m)m"
    }
}

// Separate Sheet for Details
struct RoutineDetailSheet: View {
    let routine: RoutineTemplate
    let onAdd: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "cube.box.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text(routine.name)
                    .font(.title2)
                    .bold()
                
                Text(routineDescription(routine))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.top, 40)
            
            Divider()
            
            // List of contents
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("CONTAINS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    ForEach(routine.presets) { preset in
                        HStack {
                            Image(systemName: preset.style == .focus ? "bolt.fill" : "alarm")
                                .foregroundColor(preset.style == .focus ? .yellow : .cyan)
                            Text(preset.title)
                            Spacer()
                            Text(formatDuration(preset.duration))
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(white: 0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
            }
            
            // Action Button
            Button(action: onAdd) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Pack to Journey")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
    
    func routineDescription(_ routine: RoutineTemplate) -> String {
        let totalDuration = routine.presets.reduce(0) { $0 + $1.duration }
        return "Adds \(routine.presets.count) tasks • Total \(formatDuration(totalDuration))"
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration / 60)
        let h = m / 60
        if h > 0 { return "\(h)h \(m % 60)m" }
        return "\(m)m"
    }
}
