import Foundation

/// Ein einzelner abgetasteter Punkt der Sonnenbahn.
struct SunSample: Hashable {
    let date: Date
    let azimuth: Double
    let elevation: Double
    let apparentElevation: Double

    init(date: Date, position: Solar.Position) {
        self.date = date
        self.azimuth = position.azimuth
        self.elevation = position.elevation
        self.apparentElevation = position.apparentElevation
    }

    /// Himmelsrichtung als Kürzel, z. B. „SSO“.
    var compassLabel: String { Solar.compassLabel(for: azimuth) }

    var isAboveHorizon: Bool { apparentElevation >= 0 }

    /// Schattenlänge eines 1 m hohen Objekts in Metern; `nil` unter dem Horizont.
    var shadowLengthFactor: Double? {
        guard apparentElevation > 0.1 else { return nil }
        return 1 / tan(Solar.rad(apparentElevation))
    }
}

/// Ein Ereignis im Tagesverlauf der Sonne.
struct SunEvent: Identifiable, Hashable {
    enum Kind: String, CaseIterable {
        case astronomicalDawn, nauticalDawn, civilDawn, sunrise, goldenHourEnd
        case solarNoon
        case goldenHourStart, sunset, civilDusk, nauticalDusk, astronomicalDusk

        var title: String {
            switch self {
            case .astronomicalDawn: return "Astronomische Dämmerung"
            case .nauticalDawn:     return "Nautische Dämmerung"
            case .civilDawn:        return "Blaue Stunde beginnt"
            case .sunrise:          return "Sonnenaufgang"
            case .goldenHourEnd:    return "Goldene Stunde endet"
            case .solarNoon:        return "Sonnenhöchststand"
            case .goldenHourStart:  return "Goldene Stunde beginnt"
            case .sunset:           return "Sonnenuntergang"
            case .civilDusk:        return "Blaue Stunde endet"
            case .nauticalDusk:     return "Nautische Dämmerung"
            case .astronomicalDusk: return "Astronomische Dämmerung"
            }
        }

        var symbol: String {
            switch self {
            case .astronomicalDawn, .astronomicalDusk: return "moon.stars"
            case .nauticalDawn, .nauticalDusk:         return "moon"
            case .civilDawn, .civilDusk:               return "cloud.moon"
            case .sunrise:                             return "sunrise"
            case .goldenHourEnd, .goldenHourStart:     return "sun.haze"
            case .solarNoon:                           return "sun.max"
            case .sunset:                              return "sunset"
            }
        }

        /// Geometrische Sonnenhöhe, bei der das Ereignis eintritt.
        var elevationThreshold: Double {
            switch self {
            case .astronomicalDawn, .astronomicalDusk: return -18
            case .nauticalDawn, .nauticalDusk:         return -12
            case .civilDawn, .civilDusk:               return -6
            case .sunrise, .sunset:                    return -0.833
            case .goldenHourEnd, .goldenHourStart:     return 6
            case .solarNoon:                           return .nan
            }
        }

        /// `true`, wenn das Ereignis auf dem aufsteigenden Ast der Bahn liegt.
        var isRising: Bool {
            switch self {
            case .astronomicalDawn, .nauticalDawn, .civilDawn, .sunrise, .goldenHourEnd:
                return true
            default:
                return false
            }
        }
    }

    let kind: Kind
    let date: Date
    var id: String { kind.rawValue }
}

/// Die vollständige Sonnenbahn eines Kalendertages an einem Ort –
/// abgetastet, mit allen Tagesereignissen und Kennzahlen.
struct SolarDay {

    /// Abtastung: alle zwei Minuten über 24 Stunden.
    private static let sampleStride: TimeInterval = 120

    let dayStart: Date
    let dayEnd: Date
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone
    let samples: [SunSample]
    let events: [SunEvent]
    let solarNoon: SunSample
    let solarMidnight: SunSample
    let maxElevation: Double
    let minElevation: Double

    /// `true`, wenn die Sonne den ganzen Tag über dem Horizont bleibt (Polartag).
    var isPolarDay: Bool { minElevation > -0.833 }
    /// `true`, wenn die Sonne den ganzen Tag unter dem Horizont bleibt (Polarnacht).
    var isPolarNight: Bool { maxElevation < -0.833 }

    var sunrise: Date? { events.first { $0.kind == .sunrise }?.date }
    var sunset: Date? { events.first { $0.kind == .sunset }?.date }

    /// Tageslänge zwischen Auf- und Untergang.
    var dayLength: TimeInterval? {
        if isPolarDay { return 24 * 3_600 }
        if isPolarNight { return 0 }
        guard let sunrise, let sunset, sunset > sunrise else { return nil }
        return sunset.timeIntervalSince(sunrise)
    }

    // MARK: - Aufbau

    init(date: Date, latitude: Double, longitude: Double, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let start = calendar.startOfDay(for: date)
        self.dayStart = start
        self.dayEnd = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        self.latitude = latitude
        self.longitude = longitude
        self.timeZone = timeZone

        // Bahn abtasten (ein Punkt über das Tagesende hinaus, damit die Kurve schließt).
        let count = Int((dayEnd.timeIntervalSince(start) / Self.sampleStride).rounded()) + 1
        var samples: [SunSample] = []
        samples.reserveCapacity(count)
        for index in 0...count {
            let moment = start.addingTimeInterval(Double(index) * Self.sampleStride)
            samples.append(SunSample(
                date: moment,
                position: Solar.position(date: moment, latitude: latitude, longitude: longitude)
            ))
        }
        self.samples = samples

        let highest = samples.max { $0.elevation < $1.elevation } ?? samples[0]
        let lowest = samples.min { $0.elevation < $1.elevation } ?? samples[0]
        self.maxElevation = highest.elevation
        self.minElevation = lowest.elevation

        // Höchst- und Tiefststand auf die Sekunde verfeinern.
        self.solarNoon = Self.refineExtremum(around: highest.date, samples: samples,
                                             latitude: latitude, longitude: longitude, seekingMaximum: true)
        self.solarMidnight = Self.refineExtremum(around: lowest.date, samples: samples,
                                                 latitude: latitude, longitude: longitude, seekingMaximum: false)

        // Ereignisse als Nulldurchgänge der Höhenfunktion bestimmen.
        var events: [SunEvent] = []
        for kind in SunEvent.Kind.allCases {
            if kind == .solarNoon {
                events.append(SunEvent(kind: .solarNoon, date: solarNoon.date))
                continue
            }
            if let crossing = Self.crossing(
                threshold: kind.elevationThreshold,
                rising: kind.isRising,
                samples: samples,
                latitude: latitude,
                longitude: longitude
            ) {
                events.append(SunEvent(kind: kind, date: crossing))
            }
        }
        self.events = events.sorted { $0.date < $1.date }
    }

    // MARK: - Abfragen

    /// Interpolationsfreie, exakte Position zu einem beliebigen Zeitpunkt.
    func sample(at date: Date) -> SunSample {
        SunSample(date: date, position: Solar.position(date: date, latitude: latitude, longitude: longitude))
    }

    func event(_ kind: SunEvent.Kind) -> Date? {
        events.first { $0.kind == kind }?.date
    }

    /// Bahnabschnitte oberhalb des Horizonts (kann bei Polarnacht leer sein).
    var daylightSegments: [[SunSample]] { Self.segments(of: samples) { $0.apparentElevation >= 0 } }

    /// Bahnabschnitte unterhalb des Horizonts.
    var nightSegments: [[SunSample]] { Self.segments(of: samples) { $0.apparentElevation < 0 } }

    // MARK: - Numerik

    /// Sucht den ersten Zeitpunkt, an dem die Sonnenhöhe den Schwellwert
    /// in der gewünschten Richtung kreuzt, und verfeinert per Bisektion auf ±1 s.
    private static func crossing(
        threshold: Double,
        rising: Bool,
        samples: [SunSample],
        latitude: Double,
        longitude: Double
    ) -> Date? {
        guard samples.count > 1 else { return nil }
        for index in 0..<(samples.count - 1) {
            let a = samples[index]
            let b = samples[index + 1]
            let crossesUpward = a.elevation < threshold && b.elevation >= threshold
            let crossesDownward = a.elevation >= threshold && b.elevation < threshold
            guard rising ? crossesUpward : crossesDownward else { continue }

            var low = a.date
            var high = b.date
            while high.timeIntervalSince(low) > 1 {
                let mid = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
                let elevation = Solar.position(date: mid, latitude: latitude, longitude: longitude).elevation
                let midIsBefore = rising ? (elevation < threshold) : (elevation >= threshold)
                if midIsBefore { low = mid } else { high = mid }
            }
            return low.addingTimeInterval(high.timeIntervalSince(low) / 2)
        }
        return nil
    }

    /// Verfeinert ein Extremum der Höhenfunktion per goldenem Schnitt.
    private static func refineExtremum(
        around date: Date,
        samples: [SunSample],
        latitude: Double,
        longitude: Double,
        seekingMaximum: Bool
    ) -> SunSample {
        var low = date.addingTimeInterval(-sampleStride)
        var high = date.addingTimeInterval(sampleStride)
        let ratio = 0.6180339887498949

        func elevation(_ moment: Date) -> Double {
            let value = Solar.position(date: moment, latitude: latitude, longitude: longitude).elevation
            return seekingMaximum ? value : -value
        }

        var c = high.addingTimeInterval(-ratio * high.timeIntervalSince(low))
        var d = low.addingTimeInterval(ratio * high.timeIntervalSince(low))
        while high.timeIntervalSince(low) > 1 {
            if elevation(c) > elevation(d) {
                high = d
            } else {
                low = c
            }
            c = high.addingTimeInterval(-ratio * high.timeIntervalSince(low))
            d = low.addingTimeInterval(ratio * high.timeIntervalSince(low))
        }
        let best = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
        return SunSample(date: best, position: Solar.position(date: best, latitude: latitude, longitude: longitude))
    }

    /// Zerlegt die Abtastung in zusammenhängende Abschnitte, die das Prädikat erfüllen.
    private static func segments(of samples: [SunSample], where predicate: (SunSample) -> Bool) -> [[SunSample]] {
        var result: [[SunSample]] = []
        var current: [SunSample] = []
        for sample in samples {
            if predicate(sample) {
                current.append(sample)
            } else if !current.isEmpty {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
