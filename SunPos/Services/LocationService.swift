import Combine
import CoreLocation

/// Liefert Standort, Ortsnamen und Kompasskurs.
/// Die Delegate-Rückrufe von `CLLocationManager` erfolgen auf der Queue, auf der
/// der Manager erzeugt wurde – hier also dem Main-Thread.
final class LocationService: NSObject, ObservableObject {

    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var altitude: Double?
    @Published private(set) var horizontalAccuracy: Double?
    @Published private(set) var placeName: String?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    /// Wahrer (geografischer) Nordkurs des Geräts in Grad.
    @Published private(set) var trueHeading: Double?
    /// Genauigkeit des Kompasses in Grad; Werte > 15 gelten als unzuverlässig.
    @Published private(set) var headingAccuracy: Double?
    @Published private(set) var lastError: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var isGeocoding = false
    private var lastGeocodedLocation: CLLocation?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
        manager.headingFilter = 1
        manager.headingOrientation = .portrait
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var hasReliableHeading: Bool {
        guard let headingAccuracy else { return false }
        return headingAccuracy >= 0 && headingAccuracy <= 15
    }

    func requestAuthorization() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            start()
        default:
            break
        }
    }

    func start() {
        guard isAuthorized else { return }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    // MARK: - Ortsname

    private func reverseGeocode(_ location: CLLocation) {
        guard !isGeocoding else { return }
        if let last = lastGeocodedLocation, location.distance(from: last) < 2_000, placeName != nil { return }
        isGeocoding = true
        lastGeocodedLocation = location
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            self.isGeocoding = false
            guard let placemark = placemarks?.first else { return }
            let parts = [placemark.locality ?? placemark.name, placemark.administrativeArea]
                .compactMap { $0 }
            self.placeName = parts.isEmpty ? placemark.country : parts.joined(separator: ", ")
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isAuthorized {
            lastError = nil
            start()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            lastError = "Ortungsdienste sind für SunPos deaktiviert."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        coordinate = location.coordinate
        altitude = location.altitude
        horizontalAccuracy = location.horizontalAccuracy
        lastError = nil
        reverseGeocode(location)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        headingAccuracy = newHeading.headingAccuracy
        trueHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard (error as? CLError)?.code != .locationUnknown else { return }
        lastError = error.localizedDescription
    }
}
