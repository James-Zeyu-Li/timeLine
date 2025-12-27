import Foundation
import SwiftUI

public enum TaskCategory: String, Codable, CaseIterable {
    case work, study, rest, gym, other
    
    public var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .study: return "book.fill"
        case .rest: return "cup.and.saucer.fill"
        case .gym: return "dumbbell.fill"
        case .other: return "star.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .work: return .blue
        case .study: return .purple
        case .rest: return .orange
        case .gym: return .green
        case .other: return .gray
        }
    }
}
