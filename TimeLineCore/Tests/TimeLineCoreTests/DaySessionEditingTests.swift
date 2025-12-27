import XCTest
@testable import TimeLineCore

final class DaySessionEditingTests: XCTestCase {
    
    // MARK: - Update Tests
    
    func testUpdateNode() {
        // Setup
        let originalBoss = Boss(name: "Old Name", maxHp: 1800, style: .focus, category: .work)
        let node = TimelineNode(type: .battle(originalBoss), isLocked: false)
        let session = DaySession(nodes: [node])
        
        let updatePayload = CardTemplate(
            id: node.id,
            title: "New Name",
            icon: TaskCategory.rest.icon,
            defaultDuration: 3600,
            tags: [],
            energyColor: .rest,
            category: .rest,
            style: .passive
        )
        
        // Action
        session.updateNode(id: node.id, payload: updatePayload)
        
        // Assert
        guard case .battle(let updatedBoss) = session.nodes[0].type else {
            XCTFail("Node type changed or lost")
            return
        }
        
        XCTAssertEqual(updatedBoss.name, "New Name")
        XCTAssertEqual(updatedBoss.maxHp, 3600)
        XCTAssertEqual(updatedBoss.style, .passive)
        XCTAssertEqual(updatedBoss.category, .rest)
        
        // Ensure ID remains same
        XCTAssertEqual(updatedBoss.id, originalBoss.id)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteFutureNode() {
        // [Active, Locked]
        let node1 = TimelineNode(type: .battle(Boss(name: "1", maxHp: 60)), isLocked: false)
        let node2 = TimelineNode(type: .battle(Boss(name: "2", maxHp: 60)), isLocked: true)
        
        let session = DaySession(nodes: [node1, node2])
        session.currentIndex = 0
        
        // Action: Delete node 2
        session.deleteNode(id: node2.id)
        
        // Assert
        XCTAssertEqual(session.nodes.count, 1)
        XCTAssertEqual(session.currentIndex, 0)
        XCTAssertEqual(session.nodes[0].id, node1.id)
    }
    
    func testDeleteActiveNode() {
        // [Active, Locked]
        let node1 = TimelineNode(type: .battle(Boss(name: "1", maxHp: 60)), isLocked: false)
        let node2 = TimelineNode(type: .battle(Boss(name: "2", maxHp: 60)), isLocked: true)
        
        let session = DaySession(nodes: [node1, node2])
        session.currentIndex = 0
        
        // Action: Delete active node (node1)
        session.deleteNode(id: node1.id)
        
        // Assert
        // Should have 1 node left (node2)
        XCTAssertEqual(session.nodes.count, 1)
        // Current index should still be 0 (pointing to the new first node)
        XCTAssertEqual(session.currentIndex, 0)
        // The new active node should be unlocked
        XCTAssertFalse(session.nodes[0].isLocked)
        XCTAssertEqual(session.nodes[0].id, node2.id)
    }
    
    func testDeletePastNode() {
        // [Complete, Active]
        let node1 = TimelineNode(type: .battle(Boss(name: "1", maxHp: 60)), isCompleted: true, isLocked: false)
        let node2 = TimelineNode(type: .battle(Boss(name: "2", maxHp: 60)), isLocked: false)
        
        let session = DaySession(nodes: [node1, node2])
        session.currentIndex = 1
        
        // Action: Delete past node (node1)
        session.deleteNode(id: node1.id)
        
        // Assert
        XCTAssertEqual(session.nodes.count, 1)
        // Index should decrement to stay on node2 (which is now at index 0)
        XCTAssertEqual(session.currentIndex, 0)
        XCTAssertEqual(session.nodes[0].id, node2.id)
    }
    
    // MARK: - Duplicate Tests
    
    func testDuplicateNode() {
        let node = TimelineNode(type: .battle(Boss(name: "Task", maxHp: 60, category: .study)), isLocked: false)
        let session = DaySession(nodes: [node])
        
        // Action
        session.duplicateNode(id: node.id)
        
        // Assert
        XCTAssertEqual(session.nodes.count, 2)
        
        let original = session.nodes[0]
        let duplicate = session.nodes[1]
        
        // Check content match
        if case .battle(let b1) = original.type, case .battle(let b2) = duplicate.type {
            XCTAssertEqual(b1.name, b2.name)
            XCTAssertEqual(b1.maxHp, b2.maxHp)
            XCTAssertEqual(b1.category, b2.category)
            // ID should differ
            XCTAssertNotEqual(b1.id, b2.id)
        } else {
            XCTFail("Node types mismatch")
        }
        
        // Check state
        XCTAssertTrue(duplicate.isLocked) // Duplicates start locked
        XCTAssertNotEqual(original.id, duplicate.id)
    }
}
