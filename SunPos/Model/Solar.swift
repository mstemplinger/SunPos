import Foundation

/// Sonnenstandsberechnung nach dem Algorithmus des NOAA Solar Calculator
/// (Meeus, *Astronomical Algorithms*). Genauigkeit ca. ±0,5 Bogenminuten
/// für die Jahre 1800–2100 – deutlich präziser als die Ausrichtung, die der
/// Magnetkompass eines Telefons liefern kann.
enum Solar {

    // MARK: - Winkelhelfer

    @inline(__always) static func rad(_ degrees: Double) -> Double { degrees * .pi / 180 }
    @inline(__always) static func deg(_ radians: Double) -> Double { radians * 180 / .pi }

    /// Normiert einen Winkel auf 0 ..< 360.
    @inline(__always) static func mod360(_ angle: Double) -> Double {
        let value = angle.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    // MARK: - Zeitbasis

    /// Julianisches Datum (UT) für einen Zeitpunkt.
    static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    // MARK: - Ergebnis

    struct Position {
        /// Azimut in Grad, von Nord aus im Uhrzeigersinn (Nord = 0, Ost = 90, Süd = 180, West = 270).
        var azimuth: Double
        /// Geometrische Höhe über dem Horizont in Grad (ohne Refraktion).
        var elevation: Double
        /// Scheinbare Höhe in Grad – geometrische Höhe plus atmosphärische Refraktion.
        var apparentElevation: Double
        /// Deklination der Sonne in Grad.
        var declination: Double
        /// Stundenwinkel in Grad (negativ = vormittags).
        var hourAngle: Double
        /// Zeitgleichung in Minuten.
        var equationOfTime: Double
        /// Entfernung Erde–Sonne in astronomischen Einheiten.
        var distanceAU: Double

        /// Himmelsrichtung als Kürzel, z. B. „SSO“.
        var compassLabel: String { Solar.compassLabel(for: azimuth) }

        /// Länge des Schattens eines 1 m hohen Objekts in Metern.
        /// `nil`, wenn die Sonne unter dem Horizont steht (kein Schatten).
        var shadowLengthFactor: Double? {
            guard apparentElevation > 0.1 else { return nil }
            return 1 / tan(Solar.rad(apparentElevation))
        }
    }

    // MARK: - Hauptberechnung

    /// Berechnet Azimut und Höhe der Sonne für Zeitpunkt und Ort.
    /// - Parameters:
    ///   - date: Zeitpunkt (absolut, zeitzonenunabhängig).
    ///   - latitude: Geografische Breite in Grad, Nord positiv.
    ///   - longitude: Geografische Länge in Grad, Ost positiv.
    static func position(date: Date, latitude: Double, longitude: Double) -> Position {
        let jd = julianDay(date)
        let t = (jd - 2_451_545.0) / 36_525.0   // julianische Jahrhunderte seit J2000.0

        // Geometrische mittlere Länge und mittlere Anomalie der Sonne
        let meanLongitude = mod360(280.46646 + t * (36_000.76983 + t * 0.0003032))
        let meanAnomaly = 357.52911 + t * (35_999.05029 - 0.0001537 * t)

        // Exzentrizität der Erdbahn
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        // Mittelpunktsgleichung
        let center = sin(rad(meanAnomaly)) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(rad(2 * meanAnomaly)) * (0.019993 - 0.000101 * t)
            + sin(rad(3 * meanAnomaly)) * 0.000289

        let trueLongitude = meanLongitude + center
        let trueAnomaly = meanAnomaly + center

        // Radiusvektor (Entfernung in AE)
        let radiusVector = (1.000001018 * (1 - eccentricity * eccentricity))
            / (1 + eccentricity * cos(rad(trueAnomaly)))

        // Nutation / scheinbare Länge
        let omega = 125.04 - 1_934.136 * t
        let apparentLongitude = trueLongitude - 0.00569 - 0.00478 * sin(rad(omega))

        // Ekliptikschiefe
        let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliquity = meanObliquity + 0.00256 * cos(rad(omega))

        // Deklination
        let declination = deg(asin(sin(rad(obliquity)) * sin(rad(apparentLongitude))))

        // Zeitgleichung in Minuten
        let y = pow(tan(rad(obliquity / 2)), 2)
        let equationOfTime = 4 * deg(
            y * sin(2 * rad(meanLongitude))
            - 2 * eccentricity * sin(rad(meanAnomaly))
            + 4 * eccentricity * y * sin(rad(meanAnomaly)) * cos(2 * rad(meanLongitude))
            - 0.5 * y * y * sin(4 * rad(meanLongitude))
            - 1.25 * eccentricity * eccentricity * sin(2 * rad(meanAnomaly))
        )

        // Wahre Sonnenzeit → Stundenwinkel
        let dayFraction = jd + 0.5 - (jd + 0.5).rounded(.down)
        let utcMinutes = dayFraction * 1_440
        var trueSolarTime = (utcMinutes + equationOfTime + 4 * longitude)
            .truncatingRemainder(dividingBy: 1_440)
        if trueSolarTime < 0 { trueSolarTime += 1_440 }
        var hourAngle = trueSolarTime / 4 - 180
        if hourAngle < -180 { hourAngle += 360 }

        // Horizontkoordinaten
        let latRad = rad(latitude)
        let declRad = rad(declination)
        let haRad = rad(hourAngle)

        let cosZenith = min(1, max(-1,
            sin(latRad) * sin(declRad) + cos(latRad) * cos(declRad) * cos(haRad)))
        let elevation = 90 - deg(acos(cosZenith))

        let azimuth = mod360(deg(atan2(
            sin(haRad),
            cos(haRad) * sin(latRad) - tan(declRad) * cos(latRad)
        )) + 180)

        return Position(
            azimuth: azimuth,
            elevation: elevation,
            apparentElevation: elevation + refraction(elevation),
            declination: declination,
            hourAngle: hourAngle,
            equationOfTime: equationOfTime,
            distanceAU: radiusVector
        )
    }

    /// Atmosphärische Refraktion in Grad für eine gegebene geometrische Höhe.
    static func refraction(_ elevation: Double) -> Double {
        guard elevation < 85 else { return 0 }
        let te = tan(rad(elevation))
        let arcSeconds: Double
        if elevation > 5 {
            arcSeconds = 58.1 / te - 0.07 / pow(te, 3) + 0.000086 / pow(te, 5)
        } else if elevation > -0.575 {
            arcSeconds = 1_735 + elevation * (-518.2 + elevation * (103.4 + elevation * (-12.79 + elevation * 0.711)))
        } else {
            arcSeconds = -20.774 / te
        }
        return arcSeconds / 3_600
    }

    // MARK: - Himmelsrichtungen

    static let compassPoints = ["N", "NNO", "NO", "ONO", "O", "OSO", "SO", "SSO",
                                "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]

    static func compassLabel(for azimuth: Double) -> String {
        let index = Int((mod360(azimuth) / 22.5).rounded()) % 16
        return compassPoints[index]
    }

    /// Ausgeschriebene Himmelsrichtung, z. B. „Südsüdost“.
    static func compassName(for azimuth: Double) -> String {
        let names = ["Nord", "Nordnordost", "Nordost", "Ostnordost",
                     "Ost", "Ostsüdost", "Südost", "Südsüdost",
                     "Süd", "Südsüdwest", "Südwest", "Westsüdwest",
                     "West", "Westnordwest", "Nordwest", "Nordnordwest"]
        let index = Int((mod360(azimuth) / 22.5).rounded()) % 16
        return names[index]
    }
}
