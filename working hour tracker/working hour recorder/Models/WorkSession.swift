import Foundation

struct WorkSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let totalHours: Double
    
    init(id: UUID = UUID(), startTime: Date, endTime: Date, totalHours: Double) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.totalHours = totalHours
    }
} 