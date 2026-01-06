import Foundation

public class PersistenceManager {
    public static let shared = PersistenceManager()
    
    private let fileURL: URL
    
    private init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        self.fileURL = paths[0].appendingPathComponent("app_state.json")
    }
    
    public func save(state: AppState) {
        // Dispatch to background to avoid blocking Main Thread
        DispatchQueue.global(qos: .utility).async {
            do {
                let data = try JSONEncoder().encode(state)
                // Atomic write ensures we don't corrupt file if crash happens during write
                try data.write(to: self.fileURL, options: .atomic)
                print("[Persistence] Saved successfully to \(self.fileURL.path)")
            } catch {
                print("❌ [Persistence] Failed to save: \(error)")
            }
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
    
    /// Reset all saved data (for testing or first-time setup)
    public func resetData() {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("[Persistence] ✅ Data reset complete. File removed: \(fileURL.path)")
            } else {
                print("[Persistence] ℹ️ No data file to reset.")
            }
        } catch {
            print("[Persistence] ❌ Failed to reset data: \(error)")
        }
    }
    
    /// Helper to create a snapshot from engine

}
