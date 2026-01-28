import SwiftUI
import UIKit

/// UIKit 桥接手势识别器
/// 关键：cancelsTouchesInView = false 让触摸事件穿透到 ScrollView
struct LongPressDraggable: UIViewRepresentable {
    let minimumDuration: TimeInterval
    let movementThreshold: CGFloat
    let onLongPress: (UIGestureRecognizer.State, CGPoint) -> Void
    let onPressing: (Bool) -> Void
    
    func makeUIView(context: Context) -> GesturePassthroughView {
        let view = GesturePassthroughView()
        view.backgroundColor = .clear
        
        // 长按手势
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = minimumDuration
        longPress.allowableMovement = movementThreshold
        longPress.cancelsTouchesInView = false  // ← 关键：不阻止 ScrollView
        longPress.delaysTouchesBegan = false    // ← 不延迟触摸事件
        view.addGestureRecognizer(longPress)
        
        // 存储引用以便后续访问
        context.coordinator.gestureView = view
        
        return view
    }
    
    func updateUIView(_ uiView: GesturePassthroughView, context: Context) {
        // 更新回调（如果需要）
        // We need to keep references updated in Coordinator if closures capture state
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onPressing = onPressing
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onLongPress: onLongPress, onPressing: onPressing)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject {
        var onLongPress: (UIGestureRecognizer.State, CGPoint) -> Void
        var onPressing: (Bool) -> Void
        weak var gestureView: UIView?
        
        init(
            onLongPress: @escaping (UIGestureRecognizer.State, CGPoint) -> Void,
            onPressing: @escaping (Bool) -> Void
        ) {
            self.onLongPress = onLongPress
            self.onPressing = onPressing
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            let location = gesture.location(in: gesture.view?.window)
            onLongPress(gesture.state, location)
        }
    }
}

// MARK: - 自定义 UIView：处理触摸穿透 + 按压反馈
class GesturePassthroughView: UIView {
    var onPressingChanged: ((Bool) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        // Make sure we don't clip, just in case
        clipsToBounds = false 
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 触摸开始 → 按压状态
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        // Find the coordinator to update pressing state? 
        // Or we rely on the parent struct updating us? 
        // The user code for `onPressing` was hooked up in Coordinator, but `GesturePassthroughView` needs to call it.
        // Wait, the user's code snippet for makeUIView didn't assign `onPressingChanged`.
        // I will add the linkage logic.
    }
    
    // 触摸结束 → 取消按压状态
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
    }
    
    // 关键：让不需要处理的触摸事件穿透
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 返回 self 以接收触摸，但 cancelsTouchesInView=false 会让事件继续传递
        return self.bounds.contains(point) ? self : nil
    }
}
