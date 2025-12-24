import Foundation

public enum DefaultCardTemplates {
    public static let email = CardTemplate(
        title: "Email",
        icon: "envelope",
        defaultDuration: 15 * 60,
        tags: ["work"],
        energyColor: .focus,
        category: .work,
        style: .focus
    )
    
    public static let coding = CardTemplate(
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
