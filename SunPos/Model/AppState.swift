import Combine
import CoreLocation
import Foundation
import SwiftUI

/// Zentraler Zustand: Ort, gewählter Zeitpunkt, berechnete Sonnenbahnen
/// und die Anzeigeoptionen für die AR-Szene.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Ort

    /// Manuell gesetzter Ort; überschreibt den GPS-Standort, wenn vorhanden.
    @Published var manualLocation: ManualLocation? {
        didSet { persistManualLocation(); rebuild() }
    }

    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var locationLabel: String = "Standort wird ermittelt …"
    /// Gespiegelt aus dem `LocationService`, damit Views, die nur den AppState
    /// beobachten, auf Berechtigungs- und Kompassänderungen reagieren.
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// Hinweistext bei unzuverlässigem Kompass, sonst `nil`.
    @Published private(set) var compassWarning: String?

    // MARK: - Zeit

    /// Gewählter Kalendertag (immer Tagesbeginn in der aktiven Zeitzone).
    @Published private(set) var selectedDay: Date = Date()
    /// Gewählte Uhrzeit als Sekunden seit Tagesbeginn.
    @Published private(set) var secondsIntoDay: Double = 0
    /// Wenn aktiv, folgt der gewählte Zeitpunkt der echten Uhr.
    @Published private(set) var followsRealTime = true

    // MARK: - Anzeigeoptionen

    @Published var showsSolsticePaths = true
    @Published var showsHourMarkers = true
    @Published var showsNightArc = true
    @Published var mode: DisplayMode = .augmentedReality

    enum DisplayMode: String, CaseIterable, Identifiable {
        case augmentedReality = "AR"
        case diagram = "Diagramm"
        var id: String { rawValue }
        var symbol: String { self == .augmentedReality ? "camera.viewfinder" : "chart.xyaxis.line" }
    }

    // MARK: - Ergebnisse

    @Published private(set) var day: SolarDay?
    @Published private(set) var summerSolstice: SolarDay?
    @Published private(set) var winterSolstice: SolarDay?
    /// Position zum gewählten Zeitpunkt.
    @Published private(set) var selectedSample: SunSample?
    /// Position zum Jetzt-Zeitpunkt.
    @Published private(set) var nowSample: SunSample?
    /// Zählt hoch, wenn sich die Bahnen (Tag/Ort) geändert haben – Trigger für den Szenenaufbau.
    @Published private(set) var pathRevision = 0

    // MARK: - Intern

    let location = LocationService()
    private var timer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var lastBuiltKey: String?
    /// Zeitzone, auf die `selectedDay` gerade ausgerichtet ist.
    private var anchoredTimeZone: TimeZone = .current

    var timeZone: TimeZone {
        manualLocation?.timeZone ?? .current
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Der aktuell gewählte absolute Zeitpunkt.
    var selectedDate: Date {
        selectedDay.addingTimeInterval(secondsIntoDay)
    }

    /// `true`, wenn Ortung freigegeben ist.
    var isLocationAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    init() {
        loadManualLocation()
        anchoredTimeZone = timeZone
        authorizationStatus = location.authorizationStatus
        selectedDay = calendar.startOfDay(for: Date())
        secondsIntoDay = Date().timeIntervalSince(selectedDay)

        location.$coordinate
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLocationFromServices() }
            .store(in: &cancellables)

        location.$placeName
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLocationLabel() }
            .store(in: &cancellables)

        location.$authorizationStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.authorizationStatus = status
                self?.updateLocationLabel()
            }
            .store(in: &cancellables)

        // Der Kompass meldet bis zu einmal pro Grad – nur veröffentlichen, wenn
        // sich der Hinweistext tatsächlich ändert, sonst rendert die Oberfläche unnötig neu.
        location.$headingAccuracy
            .receive(on: RunLoop.main)
            .sink { [weak self] accuracy in
                guard let self else { return }
                let warning: String?
                if let accuracy, accuracy < 0 || accuracy > 15 {
                    warning = "Kompass ungenau (±\(Int(max(accuracy, 0)))°). Gerät in einer Acht bewegen und Metall meiden."
                } else {
                    warning = nil
                }
                if warning != self.compassWarning { self.compassWarning = warning }
            }
            .store(in: &cancellables)

        rebuild()
        startClock()
    }

    // MARK: - Steuerung

    func onAppear() {
        location.requestAuthorization()
        location.start()
    }

    func onDisappear() {
        location.stop()
    }

    private func startClock() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        let now = Date()
        if followsRealTime {
            let today = calendar.startOfDay(for: now)
            if today != selectedDay {
                selectedDay = today
                rebuild()
            }
            secondsIntoDay = now.timeIntervalSince(selectedDay)
        }
        updateSamples(now: now)
    }

    /// Setzt die Uhrzeit (Sekunden seit Tagesbeginn) und verlässt den Live-Modus.
    func setTime(secondsIntoDay seconds: Double) {
        followsRealTime = false
        self.secondsIntoDay = min(max(0, seconds), 86_399)
        updateSamples(now: Date())
    }

    /// Springt zu einem konkreten Zeitpunkt (z. B. einem Tagesereignis).
    func jump(to date: Date) {
        let day = calendar.startOfDay(for: date)
        followsRealTime = false
        if day != selectedDay {
            selectedDay = day
            rebuild()
        }
        secondsIntoDay = date.timeIntervalSince(day)
        updateSamples(now: Date())
    }

    func setDay(_ date: Date) {
        let newDay = calendar.startOfDay(for: date)
        guard newDay != selectedDay else { return }
        followsRealTime = false
        selectedDay = newDay
        rebuild()
    }

    func shiftDay(by days: Int) {
        guard let shifted = calendar.date(byAdding: .day, value: days, to: selectedDay) else { return }
        setDay(shifted)
    }

    /// Zurück auf „jetzt“.
    func resetToNow() {
        followsRealTime = true
        let now = Date()
        let today = calendar.startOfDay(for: now)
        if today != selectedDay {
            selectedDay = today
            rebuild()
        }
        secondsIntoDay = now.timeIntervalSince(selectedDay)
        updateSamples(now: now)
    }

    var isToday: Bool {
        calendar.isDate(selectedDay, inSameDayAs: Date())
    }

    // MARK: - Berechnung

    private func updateLocationFromServices() {
        guard manualLocation == nil else { return }
        coordinate = location.coordinate
        updateLocationLabel()
        rebuild()
    }

    private func updateLocationLabel() {
        if let manual = manualLocation {
            locationLabel = manual.name
        } else if let name = location.placeName {
            locationLabel = name
        } else if let coordinate {
            locationLabel = Self.format(coordinate: coordinate)
        } else if !isLocationAuthorized {
            locationLabel = "Kein Standortzugriff"
        } else {
            locationLabel = "Standort wird ermittelt …"
        }
    }

    /// Richtet `selectedDay` neu auf Mitternacht der aktiven Zeitzone aus, wenn diese
    /// gewechselt hat. Der Kalendertag und die Uhrzeit bleiben erhalten – ein Ortswechsel
    /// bedeutet „gleicher Tag, gleiche Ortszeit, anderer Ort“.
    private func realignSelectedDayIfNeeded() {
        let zone = timeZone
        guard zone.identifier != anchoredTimeZone.identifier else { return }

        var previous = Calendar(identifier: .gregorian)
        previous.timeZone = anchoredTimeZone
        let components = previous.dateComponents([.year, .month, .day], from: selectedDay)

        anchoredTimeZone = zone
        if let realigned = calendar.date(from: components) {
            selectedDay = realigned
        }
    }

    /// Baut Tagesbahn und Sonnenwend-Referenzbahnen neu auf, wenn sich Ort oder Tag geändert haben.
    private func rebuild() {
        realignSelectedDayIfNeeded()

        if let manual = manualLocation {
            coordinate = CLLocationCoordinate2D(latitude: manual.latitude, longitude: manual.longitude)
        } else {
            coordinate = location.coordinate
        }
        updateLocationLabel()

        guard let coordinate else {
            day = nil
            summerSolstice = nil
            winterSolstice = nil
            selectedSample = nil
            nowSample = nil
            return
        }

        let key = "\(coordinate.latitude.rounded(toPlaces: 4))|\(coordinate.longitude.rounded(toPlaces: 4))|\(selectedDay.timeIntervalSince1970)|\(timeZone.identifier)"
        guard key != lastBuiltKey else { return }
        lastBuiltKey = key

        let zone = timeZone
        let today = SolarDay(date: selectedDay, latitude: coordinate.latitude,
                             longitude: coordinate.longitude, timeZone: zone)
        day = today

        let year = calendar.component(.year, from: selectedDay)
        let northern = coordinate.latitude >= 0
        // 21. Juni ist auf der Nordhalbkugel der längste, auf der Südhalbkugel der kürzeste Tag.
        if let june = calendar.date(from: DateComponents(year: year, month: 6, day: 21)),
           let december = calendar.date(from: DateComponents(year: year, month: 12, day: 21)) {
            let longDay = SolarDay(date: northern ? june : december, latitude: coordinate.latitude,
                                   longitude: coordinate.longitude, timeZone: zone)
            let shortDay = SolarDay(date: northern ? december : june, latitude: coordinate.latitude,
                                    longitude: coordinate.longitude, timeZone: zone)
            summerSolstice = longDay
            winterSolstice = shortDay
        }

        pathRevision += 1
        updateSamples(now: Date())
    }

    private func updateSamples(now: Date) {
        guard let coordinate else { return }
        selectedSample = SunSample(
            date: selectedDate,
            position: Solar.position(date: selectedDate,
                                     latitude: coordinate.latitude,
                                     longitude: coordinate.longitude)
        )
        nowSample = SunSample(
            date: now,
            position: Solar.position(date: now,
                                     latitude: coordinate.latitude,
                                     longitude: coordinate.longitude)
        )
    }

    // MARK: - Manueller Ort speichern

    private static let manualKey = "SunPos.manualLocation"

    private func persistManualLocation() {
        if let manualLocation, let data = try? JSONEncoder().encode(manualLocation) {
            UserDefaults.standard.set(data, forKey: Self.manualKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.manualKey)
        }
    }

    private func loadManualLocation() {
        guard let data = UserDefaults.standard.data(forKey: Self.manualKey),
              let decoded = try? JSONDecoder().decode(ManualLocation.self, from: data) else { return }
        manualLocation = decoded
    }

    // MARK: - Formatierung

    static func format(coordinate: CLLocationCoordinate2D) -> String {
        let lat = String(format: "%.4f° %@", abs(coordinate.latitude), coordinate.latitude >= 0 ? "N" : "S")
        let lon = String(format: "%.4f° %@", abs(coordinate.longitude), coordinate.longitude >= 0 ? "O" : "W")
        return "\(lat)  \(lon)"
    }
}

/// Ein manuell eingestellter Ort samt Zeitzone.
struct ManualLocation: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String

    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
