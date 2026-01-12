import XCTest
@testable import TimeLineCore

@MainActor
final class TodoSaveTests: XCTestCase {
    
    func testCardTemplateEphemeralFlag() {
        // Test that CardTemplate can be created with isEphemeral = false
        var template = CardTemplate(title: "Test Task", defaultDuration: 1500)
        template.isEphemeral = false
        
        XCTAssertFalse(template.isEphemeral)
        XCTAssertEqual(template.title, "Test Task")
        XCTAssertEqual(template.defaultDuration, 1500)
    }
    
    func testCardTemplateWithDeadline() {
        // Test that CardTemplate can store deadline information
        var template = CardTemplate(title: "Task with Deadline", defaultDuration: 1800)
        let deadline = Date().addingTimeInterval(86400) // Tomorrow
        template.deadlineAt = deadline
        template.isEphemeral = false
        
        XCTAssertEqual(template.deadlineAt, deadline)
        XCTAssertFalse(template.isEphemeral)
    }
    
    func testCardTemplateRoundTrip() {
        // Test that CardTemplate with isEphemeral can be encoded/decoded
        var template = CardTemplate(title: "Persistent Task", defaultDuration: 2700)
        template.isEphemeral = false
        template.deadlineAt = Date().addingTimeInterval(172800) // 2 days from now
        
        // Encode
        let encoder = JSONEncoder()
        let data = try! encoder.encode(template)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try! decoder.decode(CardTemplate.self, from: data)
        
        XCTAssertEqual(decoded.title, template.title)
        XCTAssertEqual(decoded.defaultDuration, template.defaultDuration)
        XCTAssertEqual(decoded.isEphemeral, template.isEphemeral)
        
        // Compare deadlineAt with proper optional handling
        if let decodedDeadline = decoded.deadlineAt, let templateDeadline = template.deadlineAt {
            XCTAssertEqual(decodedDeadline.timeIntervalSince1970, 
                          templateDeadline.timeIntervalSince1970, 
                          accuracy: 1.0)
        } else {
            XCTAssertEqual(decoded.deadlineAt, template.deadlineAt)
        }
    }
    
    func testLibraryEntryCreation() {
        // Test that LibraryEntry can be created with proper deadline status
        let templateId = UUID()
        let addedAt = Date()
        
        let entry = LibraryEntry(
            templateId: templateId,
            addedAt: addedAt,
            deadlineStatus: .active
        )
        
        XCTAssertEqual(entry.templateId, templateId)
        XCTAssertEqual(entry.addedAt, addedAt)
        XCTAssertEqual(entry.deadlineStatus, .active)
    }
    
    func testLibraryEntryRoundTrip() {
        // Test that LibraryEntry can be encoded/decoded
        let entry = LibraryEntry(
            templateId: UUID(),
            addedAt: Date(),
            deadlineStatus: .active
        )
        
        // Encode
        let encoder = JSONEncoder()
        let data = try! encoder.encode(entry)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try! decoder.decode(LibraryEntry.self, from: data)
        
        XCTAssertEqual(decoded.templateId, entry.templateId)
        XCTAssertEqual(decoded.addedAt.timeIntervalSince1970, 
                      entry.addedAt.timeIntervalSince1970, 
                      accuracy: 1.0)
        XCTAssertEqual(decoded.deadlineStatus, entry.deadlineStatus)
    }
}