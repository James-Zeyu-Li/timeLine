import Foundation

public class PersistenceManager {
    public static let shared = PersistenceManager()
    
    private let fileURL: URL
    
    private init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        self.fileURL = paths[0].appendingPathComponent("app_state.json")
    }
    
    public func save(state: AppState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL)
            print("[Persistence] Saved successfully to \(fileURL.path)")
        } catch {
            print("❌ [Persistence] Failed to save: \(error)")
        }
    }
    
    public func load() -> AppState? {
        do {
            let data = try Data(contentsOf: fileURL)
            let state = try JSONDecoder().decode(AppState.self, from: data)
            print("[Persistence] Loaded successfully.")
            return state
        } catch {
            print("⚠️ [Persistence] Failed to load (or no file): \(error)")
            return nil
        }
    }
    
    /// Helper to create a snapshot from engine

}
