import SwiftUI
import UIKit
import Foundation
import TimeLineCore

extension PlanSheetView {
    func commitAndFeedback() {
        let count = timelineStore.inbox.count
        
        viewModel.launchExpedition(dismissAction: {})
        
        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        commitMessage = "Successfully planted \(count) seeds into the timeline."
        showCommitSuccess = true
        
        // Auto dismiss after 1.5s if user doesn't tap OK
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if showCommitSuccess {
                dismiss()
            }
        }
    }
    
    func handleDrop(items: [String], into timeSlot: FinishBySelection) {
        viewModel.handleDrop(items: items, into: timeSlot)
    }
}
