import SwiftUI
import UIKit

struct LongPressDraggable: UIViewRepresentable {
    var minimumDuration: TimeInterval = 0.4
    var movementThreshold: CGFloat = 10
    
    var onLongPress: (UIGestureRecognizer.State, CGPoint) -> Void
    var onPressing: (Bool) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        
        // Configure Gesture
        let gesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleGesture(_:)))
        gesture.minimumPressDuration = minimumDuration
        gesture.allowableMovement = movementThreshold
        gesture.cancelsTouchesInView = false // Critical: Let ScrollView receive touches too
        gesture.delegate = context.coordinator
        
        view.addGestureRecognizer(gesture)
        
        // Add a specialized "TouchDown" recognizer for visual feedback
        let touchDown = TouchDownGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTouchDown(_:)))
        touchDown.delegate = context.coordinator
        touchDown.cancelsTouchesInView = false
        view.addGestureRecognizer(touchDown)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update configuration if needed
        if let gesture = uiView.gestureRecognizers?.first(where: { $0 is UILongPressGestureRecognizer }) as? UILongPressGestureRecognizer {
            gesture.minimumPressDuration = minimumDuration
            gesture.allowableMovement = movementThreshold
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: LongPressDraggable
        var isPressing = false
        
        init(parent: LongPressDraggable) {
            self.parent = parent
        }
        
        @objc func handleGesture(_ gesture: UILongPressGestureRecognizer) {
            // Convert to global coordinates for the drag overlay.
            let globalLocation = gesture.location(in: nil) // nil = Window
            
            // State Mapping
            // .began -> Long Press Succeeded (0.4s elapsed) -> Drag Start
            // .changed -> Dragging
            // .ended/.cancelled -> Drop
            
            if gesture.state == .began {
                // Long press confirmed.
                // Reset pressing state since we are now dragging
                parent.onPressing(false) 
            }
            
            parent.onLongPress(gesture.state, globalLocation)
        }
        
        @objc func handleTouchDown(_ gesture: UIGestureRecognizer) {
            if gesture.state == .began {
                parent.onPressing(true)
            } else if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
                 parent.onPressing(false)
            }
        }
        
        // Allow simultaneous recognition with ScrollView's pan gesture
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

// Helper for immediate touch detection (Visual State)
class TouchDownGestureRecognizer: UIGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        state = .began
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        // If moved significantly, fail?
        // Let standard logic handle it. 
        // We just want to know "is finger down".
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        state = .ended
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .cancelled
    }
}
