import Foundation

public struct FocusGroupPayload: Codable, Equatable {
    public var memberTemplateIds: [UUID]
    public var activeIndex: Int
    
    public init(memberTemplateIds: [UUID], activeIndex: Int = 0) {
        self.memberTemplateIds = memberTemplateIds
        self.activeIndex = activeIndex
    }
}
