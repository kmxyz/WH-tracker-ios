import Foundation
import CoreLocation

struct WorkSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let totalHours: Double
    let locationString: String
    let latitude: Double?
    let longitude: Double?
    let note: String
    let companyName: String
    
    init(id: UUID = UUID(), startTime: Date, endTime: Date, totalHours: Double, locationString: String = "Location not available", latitude: Double? = nil, longitude: Double? = nil, note: String = "", companyName: String = "") {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.totalHours = totalHours
        self.locationString = locationString
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
        self.companyName = companyName
    }
} 