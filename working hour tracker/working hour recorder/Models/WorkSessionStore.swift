import SwiftUI

class WorkSessionStore: ObservableObject {
    @Published var sessions: [WorkSession] = []
    
    private let saveKey = "WorkSessions"
    
    init() {
        loadSessions()
        
        // Add observer for app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveOnBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func addSession(_ session: WorkSession) {
        sessions.append(session)
        saveSessions()
    }
    
    func deleteSession(_ session: WorkSession) {
        sessions.removeAll { $0.id == session.id }
        saveSessions()
    }
    
    @objc private func saveOnBackground() {
        saveSessions()
    }
    
    private func saveSessions() {
        do {
            let encoded = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(encoded, forKey: saveKey)
            UserDefaults.standard.synchronize() // Force immediate save
        } catch {
            print("Error saving sessions: \(error.localizedDescription)")
        }
    }
    
    private func loadSessions() {
        do {
            if let data = UserDefaults.standard.data(forKey: saveKey) {
                sessions = try JSONDecoder().decode([WorkSession].self, from: data)
            }
        } catch {
            print("Error loading sessions: \(error.localizedDescription)")
            sessions = [] // Reset to empty array if loading fails
        }
    }
} 