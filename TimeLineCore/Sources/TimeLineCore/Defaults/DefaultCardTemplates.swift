import Foundation

public enum DefaultCardTemplates {
    private static let emailId = UUID(uuidString: "8EFA43E2-2E7D-4D8E-9D6F-6B1E8C6C9A41")!
    private static let codingId = UUID(uuidString: "C9B4D2A1-8D2F-4C65-9A7E-2D0F6E5C4B12")!
    
    public static let email = CardTemplate(
        id: emailId,
        title: "Email",
        icon: "envelope",
        defaultDuration: 15 * 60,
        tags: ["work"],
        energyColor: .focus,
        category: .work,
        style: .focus
    )
    
    public static let coding = CardTemplate(
        id: codingId,
        title: "Coding",
        icon: "laptopcomputer",
        defaultDuration: 45 * 60,
        tags: ["work"],
        energyColor: .creative,
        category: .work,
        style: .focus
    )
    
    public static let all: [CardTemplate] = [email, coding]
}
