import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var stateManager: AppStateManager
    
    @AppStorage("strictMode") private var strictMode = true
    @AppStorage("autoSave") private var autoSave = true
    @AppStorage("soundEnabled") private var soundEnabled = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("use24HourClock") private var use24HourClock = true
    @AppStorage("usePixelTheme") private var usePixelTheme = true
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Focus Settings")) {
                    HStack {
                        Image(systemName: "shield.fill")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Strict Mode")
                                .font(.headline)
                            Text("No pause button, backgrounding counts as wasted time")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $strictMode)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("App Behavior")) {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pixel Theme")
                                .font(.headline)
                            Text("Use warm pixel healing style vs smooth modern design")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $usePixelTheme)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto Save")
                                .font(.headline)
                            Text("Automatically save progress every 30 seconds")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $autoSave)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.cyan)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("24-Hour Time")
                                .font(.headline)
                            Text("Use 24-hour time format")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $use24HourClock)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Feedback")) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sound Effects")
                                .font(.headline)
                            Text("Play sounds for task completion and alerts")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $soundEnabled)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Haptic Feedback")
                                .font(.headline)
                            Text("Vibration feedback for interactions")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $hapticsEnabled)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.cyan)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TimeLineApp")
                                .font(.headline)
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    
                    Button(action: {
                        showResetConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            
                            Text("Reset All Data")
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.cyan)
                }
            }
            .alert("Reset All Data?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    stateManager.resetAllData()
                    dismiss()
                }
            } message: {
                Text("This will delete all tasks, history, and templates. This action cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView()
}
