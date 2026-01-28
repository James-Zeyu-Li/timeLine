import SwiftUI
import UIKit

struct LongPressDraggable: UIViewRepresentable {
    let minimumDuration: TimeInterval
    let movementThreshold: CGFloat
    let exclusionRect: CGRect?
    let onLongPress: (UIGestureRecognizer.State, CGPoint) -> Void
    let onPressing: (Bool) -> Void
    
    func makeUIView(context: Context) -> JsonPassthroughView {
        let view = JsonPassthroughView()
        view.backgroundColor = .clear
        view.coordinator = context.coordinator
        view.exclusionRectGlobal = exclusionRect
        
        let coordinator = context.coordinator
        view.onPressingChanged = { [weak coordinator] isPressing in
            coordinator?.onPressing(isPressing)
        }
        
        // 长按手势只用于检测长按开始
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = minimumDuration
        // If the finger moves beyond this before the long-press fires, treat it as scroll.
        longPress.allowableMovement = movementThreshold
        longPress.cancelsTouchesInView = false
        longPress.delaysTouchesBegan = false
        longPress.delegate = context.coordinator
        view.addGestureRecognizer(longPress)
        
        context.coordinator.gestureView = view
        
        return view
    }
    
    func updateUIView(_ uiView: JsonPassthroughView, context: Context) {
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onPressing = onPressing
        uiView.exclusionRectGlobal = exclusionRect
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            minimumDuration: minimumDuration,
            onLongPress: onLongPress,
            onPressing: onPressing
        )
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onLongPress: (UIGestureRecognizer.State, CGPoint) -> Void
        var onPressing: (Bool) -> Void
        weak var gestureView: UIView?
        
        private let minimumDuration: TimeInterval
        var isDragging = false
        private weak var parentScrollView: UIScrollView?
        private var wasScrollEnabled = true
        
        init(
            minimumDuration: TimeInterval,
            onLongPress: @escaping (UIGestureRecognizer.State, CGPoint) -> Void,
            onPressing: @escaping (Bool) -> Void
        ) {
            self.minimumDuration = minimumDuration
            self.onLongPress = onLongPress
            self.onPressing = onPressing
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            let location = gesture.location(in: gesture.view?.window)
            print("🎯 [LongPress Gesture] State: \(gesture.state.rawValue)")
            
            switch gesture.state {
            case .began:
                isDragging = true
                disableParentScrollView(for: gesture.view)
                onLongPress(.began, location)
                
            case .changed:
                if isDragging {
                    onLongPress(.changed, location)
                }

            case .ended:
                // 手势正常结束
                print("✅ [LongPress] Gesture ended normally")
                if isDragging {
                    onLongPress(.ended, location)
                    restoreParentScrollView()
                    isDragging = false
                }
                
            case .cancelled, .failed:
                // 手势被取消，直接结束避免卡住
                print("⚠️ [LongPress] Gesture cancelled/failed, but touches still tracking")
                if isDragging {
                    onLongPress(.cancelled, location)
                    restoreParentScrollView()
                    isDragging = false
                }
                
            default:
                break
            }
        }
        
        func handleTouchMoved(location: CGPoint) {
            guard isDragging else { return }
            onLongPress(.changed, location)
        }
        
        func handleTouchEnded(location: CGPoint) {
            print("👆 [Touch] touchesEnded called, isDragging: \(isDragging)")
            guard !isDragging else { return }
        }
        
        func handleTouchCancelled(location: CGPoint) {
            print("❌ [Touch] touchesCancelled called, isDragging: \(isDragging)")
            guard !isDragging else { return }
        }
        
        private func disableParentScrollView(for view: UIView?) {
            guard let view = view else { return }
            var current: UIView? = view.superview
            while let parent = current {
                if let scrollView = parent as? UIScrollView {
                    parentScrollView = scrollView
                    wasScrollEnabled = scrollView.isScrollEnabled
                    scrollView.isScrollEnabled = false
                    print("🔒 [ScrollView] Disabled")
                    return
                }
                current = parent.superview
            }
        }
        
        private func restoreParentScrollView() {
            parentScrollView?.isScrollEnabled = wasScrollEnabled
            parentScrollView = nil
            print("🔓 [ScrollView] Restored")
        }
        // ✅ Allow coexistence with ScrollView pan so long-press doesn't get cancelled mid-drag.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            otherGestureRecognizer is UIPanGestureRecognizer
        }
    }
}

// MARK: - 自定义 View：使用 touchesMoved 追踪而不是手势
class JsonPassthroughView: UIView {
    var onPressingChanged: ((Bool) -> Void)?
    var exclusionRectGlobal: CGRect?
    weak var coordinator: LongPressDraggable.Coordinator?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        clipsToBounds = false
        isMultipleTouchEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("👇 [Touch] touchesBegan")
        super.touchesBegan(touches, with: event)
        onPressingChanged?(true)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        // ✅ 使用 Window 坐标追踪移动
        guard let touch = touches.first, let window = self.window else { return }
        let location = touch.location(in: window)
        coordinator?.handleTouchMoved(location: location)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("👆 [Touch] touchesEnded in View")
        super.touchesEnded(touches, with: event)
        onPressingChanged?(false)
        
        guard let touch = touches.first, let window = self.window else { 
            print("⚠️ [Touch] No touch or window in touchesEnded")
            coordinator?.handleTouchEnded(location: .zero)
            return 
        }
        let location = touch.location(in: window)
        coordinator?.handleTouchEnded(location: location)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("❌ [Touch] touchesCancelled in View")
        super.touchesCancelled(touches, with: event)
        onPressingChanged?(false)
        
        guard let touch = touches.first, let window = self.window else {
            print("⚠️ [Touch] No touch or window in touchesCancelled")
            coordinator?.handleTouchCancelled(location: .zero)
            return
        }
        let location = touch.location(in: window)
        coordinator?.handleTouchCancelled(location: location)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard bounds.contains(point) else { return false }
        guard let exclusion = exclusionRectGlobal, let window = window else { return true }
        let pointInWindow = convert(point, to: window)
        return !exclusion.contains(pointInWindow)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.point(inside: point, with: event) ? self : nil
    }
}
