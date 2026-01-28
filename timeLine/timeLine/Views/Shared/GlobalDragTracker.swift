import SwiftUI
import UIKit

struct GlobalDragTracker: UIViewRepresentable {
    let isActive: Bool
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void
    
    func makeUIView(context: Context) -> TrackerHostView {
        let view = TrackerHostView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: TrackerHostView, context: Context) {
        context.coordinator.isActive = isActive
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        uiView.updateWindowTracker()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isActive: isActive, onChanged: onChanged, onEnded: onEnded)
    }
    
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isActive: Bool
        var onChanged: (CGPoint) -> Void
        var onEnded: () -> Void
        
        private weak var attachedWindow: UIWindow?
        private var pan: UIPanGestureRecognizer?
        
        init(isActive: Bool, onChanged: @escaping (CGPoint) -> Void, onEnded: @escaping () -> Void) {
            self.isActive = isActive
            self.onChanged = onChanged
            self.onEnded = onEnded
        }
        
        func attach(to window: UIWindow?) {
            guard let window, pan == nil else { return }
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.cancelsTouchesInView = false
            pan.delaysTouchesBegan = false
            pan.delaysTouchesEnded = false
            pan.maximumNumberOfTouches = 1
            pan.minimumNumberOfTouches = 1
            pan.delegate = self
            window.addGestureRecognizer(pan)
            attachedWindow = window
            self.pan = pan
        }
        
        func detach() {
            if let pan, let window = attachedWindow {
                window.removeGestureRecognizer(pan)
            }
            attachedWindow = nil
            pan = nil
        }
        
        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard isActive else { return }
            let location = gesture.location(in: gesture.view?.window)
            switch gesture.state {
            case .began, .changed:
                onChanged(location)
            case .ended, .cancelled, .failed:
                onEnded()
            default:
                break
            }
        }
        
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

final class TrackerHostView: UIView {
    weak var coordinator: GlobalDragTracker.Coordinator?
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        coordinator?.attach(to: window)
    }
    
    override func willMove(toWindow newWindow: UIWindow?) {
        if newWindow == nil {
            coordinator?.detach()
        }
        super.willMove(toWindow: newWindow)
    }
    
    func updateWindowTracker() {
        coordinator?.attach(to: window)
    }
}
