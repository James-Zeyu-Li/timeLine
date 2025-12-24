import SwiftUI
import Combine

// MARK: - Pet Visibility Controller

@MainActor
final class PetVisibilityController: ObservableObject {
    
    @Published var isKeyboardVisible = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupKeyboardObservers()
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] _ in
                self?.isKeyboardVisible = true
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                self?.isKeyboardVisible = false
            }
            .store(in: &cancellables)
    }
    
    func isPetVisible(appMode: AppMode) -> Bool {
        guard !isKeyboardVisible else { return false }
        
        switch appMode {
        case .homeCollapsed, .homeExpanded:
            return true
        case .deckOverlay, .dragging, .cardEdit, .deckEdit:
            return false
        }
    }
}
