import CoreHaptics
import UIKit

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled, isSupported else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private static var isEnabled: Bool {
        if let value = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool {
            return value
        }
        return true
    }

    private static var isSupported: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return CHHapticEngine.capabilitiesForHardware().supportsHaptics
        #endif
    }
}
