import SwiftUI
import UIKit

struct ScrollViewAccessor: UIViewRepresentable {
    let onResolve: (UIScrollView?) -> Void

    func makeUIView(context: Context) -> ResolverView {
        let view = ResolverView()
        view.onResolve = onResolve
        return view
    }

    func updateUIView(_ uiView: ResolverView, context: Context) {
        uiView.onResolve = onResolve
        uiView.resolveIfNeeded()
    }
}

final class ResolverView: UIView {
    var onResolve: ((UIScrollView?) -> Void)?
    private weak var cachedScrollView: UIScrollView?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        resolveIfNeeded()
    }

    func resolveIfNeeded() {
        if let cached = cachedScrollView {
            onResolve?(cached)
            return
        }
        var current: UIView? = superview
        while let view = current {
            if let scroll = view as? UIScrollView {
                cachedScrollView = scroll
                onResolve?(scroll)
                return
            }
            current = view.superview
        }
        onResolve?(nil)
    }
}
