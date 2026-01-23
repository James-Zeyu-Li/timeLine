import SwiftUI
import TimeLineCore

struct MagicInputBar: View {
    @Binding var text: String
    let onCommit: () -> Void
    
    @FocusState private var isFocused: Bool
    
    // Simple duration parser for highlighting (visual only)
    private var detectedDuration: String? {
        // Regex to find " 45m" or " 1h" at end
        let pattern = "\\s+(\\d+)(m|h)$"
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return String(text[range]).trimmingCharacters(in: .whitespaces)
    }
    
    var autoFocus: Bool = true
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)
            
            // Input TextField
            TextField("What's your quest? e.g. 'Code 45m'", text: $text)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .submitLabel(.done)
                .focused($isFocused)
                .onSubmit {
                    onCommit()
                }
                .onChange(of: text) { _, _ in
                    // Haptic feedback if duration detected?
                }
            
            // Duration Highlight (if detected)
            if let duration = detectedDuration {
                Text(duration)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.accentColor)
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // Add Button (if text not empty)
            if !text.isEmpty {
                Button(action: onCommit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.accentColor)
                }
                .transition(.scale)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(isFocused ? 0.3 : 0), lineWidth: 2)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: text.isEmpty)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: detectedDuration)
        .onAppear {
            if autoFocus {
                isFocused = true
            }
        }
    }
}
