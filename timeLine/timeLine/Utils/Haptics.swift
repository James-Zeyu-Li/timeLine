import CoreHaptics
import UIKit

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled, isSupported else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    /// 极轻微的「选择」震动，用于进入有效放置区（如离开恒等移动死区、第一个 Ghost 出现时）
    static func selection() {
        guard isEnabled, isSupported else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
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
