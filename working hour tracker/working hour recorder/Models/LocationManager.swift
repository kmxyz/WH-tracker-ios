import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var locationString: String = "Location not available"
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var permissionDenied: Bool = false
    private var authorizationRequested = false
    
    // Cache and rate limiting properties
    private var locationCache: [String: (address: String, timestamp: Date)] = [:]
    private var lastGeocodingRequest: Date?
    private let minimumRequestInterval: TimeInterval = 2.0 // Minimum time between requests
    private let cacheExpirationInterval: TimeInterval = 3600.0 // Cache expires after 1 hour
    
    private func coordinateKey(_ location: CLLocation) -> String {
        // Round coordinates to reduce slight variations
        let lat = round(location.coordinate.latitude * 1000) / 1000
        let lon = round(location.coordinate.longitude * 1000) / 1000
        return "\(lat),\(lon)"
    }
    
    private func canMakeGeocodingRequest() -> Bool {
        guard let lastRequest = lastGeocodingRequest else { return true }
        return Date().timeIntervalSince(lastRequest) >= minimumRequestInterval
    }
    
    private func getCachedLocation(_ location: CLLocation) -> String? {
        let key = coordinateKey(location)
        guard let cached = locationCache[key] else { return nil }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cached.timestamp) <= cacheExpirationInterval {
            return cached.address
        } else {
            locationCache.removeValue(forKey: key)
            return nil
        }
    }
    
    private func cacheLocation(_ location: CLLocation, address: String) {
        let key = coordinateKey(location)
        locationCache[key] = (address, Date())
    }
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0 // Only update if moved more than 10 meters
        
        if #available(iOS 14.0, *) {
            authorizationStatus = locationManager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }
        
        updatePermissionDeniedState()
    }
    
    func requestPermission() {
        // Check if we've already requested authorization
        guard !authorizationRequested else { return }
        
        // Mark that we've requested authorization
        authorizationRequested = true
        
        // Handle based on current status
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch self.authorizationStatus {
            case .notDetermined:
                // Request authorization and wait for callback
                self.locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                self.startUpdatingLocation()
            case .denied, .restricted:
                self.permissionDenied = true
                self.locationString = "Location access denied. Please enable in Settings"
            @unknown default:
                break
            }
        }
    }
    
    private func handleCurrentAuthorizationStatus() {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .denied, .restricted:
            permissionDenied = true
            locationString = "Location access denied. Please enable in Settings"
        case .notDetermined:
            // Don't request authorization here, wait for explicit request
            break
        @unknown default:
            break
        }
    }
    
    private func updatePermissionDeniedState() {
        permissionDenied = authorizationStatus == .denied || authorizationStatus == .restricted
    }
    
    func startUpdatingLocation() {
        // Only start updating if we have permission
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if #available(iOS 14.0, *) {
                self.authorizationStatus = manager.authorizationStatus
            } else {
                self.authorizationStatus = CLLocationManager.authorizationStatus()
            }
            self.updatePermissionDeniedState()
            self.handleCurrentAuthorizationStatus()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.authorizationStatus = status
            self.updatePermissionDeniedState()
            self.handleCurrentAuthorizationStatus()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.location = location
            
            // Check cache first
            if let cachedAddress = self.getCachedLocation(location) {
                self.locationString = cachedAddress
                return
            }
            
            // Check rate limiting
            guard self.canMakeGeocodingRequest() else {
                // Skip this update if we're rate limited
                return
            }
            
            // Update last request time
            self.lastGeocodingRequest = Date()
            
            // Perform geocoding
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error {
                        print("Geocoding error: \(error.localizedDescription)")
                        self.locationString = "Location not available"
                        return
                    }
                    
                    if let placemark = placemarks?.first {
                        let address = [
                            placemark.thoroughfare,
                            placemark.locality,
                            placemark.administrativeArea,
                            placemark.country
                        ].compactMap { $0 }.joined(separator: ", ")
                        
                        // Cache the result
                        self.cacheLocation(location, address: address)
                        self.locationString = address
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("Location error: \(error.localizedDescription)")
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationString = "Location access denied. Please enable in Settings"
                    self.permissionDenied = true
                case .locationUnknown:
                    self.locationString = "Unable to determine location"
                default:
                    self.locationString = "Location not available"
                }
            } else {
                self.locationString = "Location not available"
            }
        }
    }
} 
