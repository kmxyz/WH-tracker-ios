import SwiftUI

struct InProgressSession: Codable {
    let startTime: Date
    let isWorking: Bool
}

class WorkSessionStore: ObservableObject {
    @Published var sessions: [WorkSession] = []
    @Published var inProgressSession: InProgressSession?
    
    private let saveKey = "WorkSessions"
    private let inProgressKey = "InProgressSession"
    
    init() {
        loadSessions()
        loadInProgressSession()
        
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
    
    func updateSession(_ session: WorkSession, newStartTime: Date, newEndTime: Date, newLocation: String, newNote: String, newCompanyName: String) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            let timeInterval = newEndTime.timeIntervalSince(newStartTime)
            let newTotalHours = timeInterval / 3600
            
            let updatedSession = WorkSession(
                id: session.id,
                startTime: newStartTime,
                endTime: newEndTime,
                totalHours: newTotalHours,
                locationString: newLocation,
                latitude: session.latitude,
                longitude: session.longitude,
                note: newNote,
                companyName: newCompanyName
            )
            
            sessions[index] = updatedSession
            saveSessions()
        }
    }
    
    func saveInProgressSession(startTime: Date, isWorking: Bool) {
        let session = InProgressSession(startTime: startTime, isWorking: isWorking)
        inProgressSession = session
        
        do {
            let encoded = try JSONEncoder().encode(session)
            UserDefaults.standard.set(encoded, forKey: inProgressKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("Error saving in-progress session: \(error.localizedDescription)")
        }
    }
    
    func clearInProgressSession() {
        inProgressSession = nil
        UserDefaults.standard.removeObject(forKey: inProgressKey)
        UserDefaults.standard.synchronize()
    }
    
    @objc private func saveOnBackground() {
        saveSessions()
    }
    
    private func saveSessions() {
        do {
            let encoded = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(encoded, forKey: saveKey)
            UserDefaults.standard.synchronize()
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
            sessions = []
        }
    }
    
    private func loadInProgressSession() {
        if let data = UserDefaults.standard.data(forKey: inProgressKey) {
            do {
                let session = try JSONDecoder().decode(InProgressSession.self, from: data)
                inProgressSession = session
            } catch {
                print("Error loading in-progress session: \(error.localizedDescription)")
            }
        }
    }
} 