import SwiftUI
import TimeLineCore

// MARK: - Timeline Node Gesture Handlers

/// Swipe gesture handler for revealing edit actions
struct TimelineNodeSwipeGesture {
    let swipeThreshold: CGFloat
    let actionButtonWidth: CGFloat
    let showingEditActions: Bool
    let onSwipeChanged: (CGFloat) -> Void
    let onSwipeEnded: (Bool) -> Void
    
    var gesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = value.translation.width
                
                // Only allow left swipe to reveal edit actions
                if translation < 0 {
                    let progress = min(abs(translation), swipeThreshold * 2) / swipeThreshold
                    onSwipeChanged(-progress * (actionButtonWidth * 3))
                } else if showingEditActions {
                    // Allow right swipe to hide actions
                    let progress = max(0, 1 - (translation / swipeThreshold))
                    onSwipeChanged(-progress * (actionButtonWidth * 3))
                }
            }
            .onEnded { value in
                let translation = value.translation.width
                let velocity = value.velocity.width
                
                let shouldShow = translation < -swipeThreshold || velocity < -500
                onSwipeEnded(shouldShow)
            }
    }
}

/// Drag gesture handler for reordering nodes
struct TimelineNodeDragGesture {
    let isDragging: Bool
    let onDragChanged: (CGSize, Bool) -> Void
    let onDragEnded: (CGFloat) -> Void
    
    var gesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only start dragging on vertical movement
                let shouldStartDragging = !isDragging && 
                    abs(value.translation.height) > 15 && 
                    abs(value.translation.height) > abs(value.translation.width)
                
                if shouldStartDragging {
                    onDragChanged(value.translation, true)
                    Haptics.impact(.light)
                } else if isDragging {
                    onDragChanged(CGSize(width: 0, height: value.translation.height), false)
                }
            }
            .onEnded { value in
                if isDragging {
                    onDragEnded(value.translation.height)
                }
            }
    }
}

/// Combined gesture coordinator for timeline nodes
struct TimelineNodeGestureCoordinator {
    @Binding var swipeOffset: CGFloat
    @Binding var isDragging: Bool
    @Binding var dragOffset: CGSize
    @Binding var showingEditActions: Bool
    @Binding var preventTap: Bool
    
    let swipeThreshold: CGFloat = 80
    let actionButtonWidth: CGFloat = 70
    
    var swipeGesture: some Gesture {
        TimelineNodeSwipeGesture(
            swipeThreshold: swipeThreshold,
            actionButtonWidth: actionButtonWidth,
            showingEditActions: showingEditActions,
            onSwipeChanged: { offset in
                swipeOffset = offset
            },
            onSwipeEnded: { shouldShow in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if shouldShow {
                        showEditActions()
                    } else {
                        hideEditActions()
                    }
                }
            }
        ).gesture
    }
    
    var dragGesture: some Gesture {
        TimelineNodeDragGesture(
            isDragging: isDragging,
            onDragChanged: { translation, startDragging in
                if startDragging {
                    isDragging = true
                }
                dragOffset = translation
            },
            onDragEnded: { dragDistance in
                isDragging = false
                
                // Calculate move based on drag distance (每120pt移动一个位置)
                let nodeHeight: CGFloat = 120 + 26 // node height + spacing
                let moveSteps = Int(round(dragDistance / nodeHeight))
                
                if abs(moveSteps) >= 1 {
                    // This will be handled by the parent view
                    Haptics.impact(.medium)
                }
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    dragOffset = .zero
                }
            }
        ).gesture
    }
    
    func showEditActions() {
        showingEditActions = true
        swipeOffset = -(actionButtonWidth * 3)
    }
    
    func hideEditActions() {
        showingEditActions = false
        swipeOffset = 0
    }
    
    func calculateMoveSteps(from dragDistance: CGFloat) -> Int {
        let nodeHeight: CGFloat = 120 + 26 // node height + spacing
        return Int(round(dragDistance / nodeHeight))
    }
}