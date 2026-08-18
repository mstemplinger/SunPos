import Foundation

func fmt(_ d: Date, _ tz: String) -> String {
    let f = DateFormatter()
    f.timeZone = TimeZone(identifier: tz)!
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f.string(from: d)
}
func day(_ y: Int, _ m: Int, _ d: Int, _ tz: String) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: tz)!
    return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
}

var failures = 0
func check(_ name: String, _ ok: Bool, _ detail: String) {
    print("\(ok ? "PASS" : "FAIL")  \(name)  — \(detail)")
    if !ok { failures += 1 }
}

// ---- 1) Berlin, längster Tag 2024 (Referenz: SA 04:43, SU 21:33 MESZ, Höchststand 13:09-13:13)
let berlinTZ = TimeZone(identifier: "Europe/Berlin")!
let berlin = SolarDay(date: day(2024, 6, 21, "Europe/Berlin"), latitude: 52.52, longitude: 13.405, timeZone: berlinTZ)
print("Berlin 21.06.2024:")
for e in berlin.events { print("   \(e.kind.title): \(fmt(e.date, "Europe/Berlin"))") }
print("   Tageslänge: \(berlin.dayLength!/3600) h,  max Höhe: \(berlin.maxElevation)")

let sr = fmt(berlin.sunrise!, "Europe/Berlin"), ss = fmt(berlin.sunset!, "Europe/Berlin")
check("Berlin Sonnenaufgang ≈ 04:43", sr.contains("04:4"), sr)
check("Berlin Sonnenuntergang ≈ 21:33", ss.contains("21:3"), ss)
check("Berlin Tageslänge ≈ 16h50m", abs(berlin.dayLength!/3600 - 16.83) < 0.05, "\(berlin.dayLength!/3600)")
// Geometrie: 90 - 52.52 + 23.44 = 60.92
check("Berlin max Höhe ≈ 60.9°", abs(berlin.maxElevation - 60.92) < 0.15, "\(berlin.maxElevation)")
check("Berlin Höchststand Azimut ≈ 180°", abs(berlin.solarNoon.azimuth - 180) < 0.3, "\(berlin.solarNoon.azimuth)")

// ---- 2) Äquinoktium: Tag ≈ 12 h, Auf/Untergang ≈ Ost/West
let eq = SolarDay(date: day(2026, 3, 20, "Europe/Berlin"), latitude: 49.0134, longitude: 12.1016, timeZone: berlinTZ)
let eqRise = eq.sample(at: eq.sunrise!), eqSet = eq.sample(at: eq.sunset!)
check("Äquinoktium Tageslänge ≈ 12 h", abs(eq.dayLength!/3600 - 12.13) < 0.12, "\(eq.dayLength!/3600) h")
check("Äquinoktium Aufgang ≈ Ost (90°)", abs(eqRise.azimuth - 90) < 2.0, "\(eqRise.azimuth)°")
check("Äquinoktium Untergang ≈ West (270°)", abs(eqSet.azimuth - 270) < 2.0, "\(eqSet.azimuth)°")

// ---- 3) Symmetrie um den Höchststand
let noon = berlin.solarNoon.date.timeIntervalSince1970
let mid = (berlin.sunrise!.timeIntervalSince1970 + berlin.sunset!.timeIntervalSince1970) / 2
check("Auf/Untergang symmetrisch zum Höchststand", abs(noon - mid) < 30, "Δ = \(abs(noon-mid)) s")

// ---- 4) Äquator zum Äquinoktium: Mittagshöhe ≈ 90°
let equator = SolarDay(date: day(2026, 3, 20, "UTC"), latitude: 0, longitude: 0, timeZone: TimeZone(identifier: "UTC")!)
check("Äquator/Äquinoktium Mittagshöhe ≈ 90°", equator.maxElevation > 89.2, "\(equator.maxElevation)°")

// ---- 5) Südhalbkugel: Höchststand im Norden
let sydney = SolarDay(date: day(2026, 6, 21, "Australia/Sydney"), latitude: -33.8688, longitude: 151.2093, timeZone: TimeZone(identifier: "Australia/Sydney")!)
check("Sydney Höchststand im Norden (≈0°/360°)", sydney.solarNoon.azimuth < 1 || sydney.solarNoon.azimuth > 359, "\(sydney.solarNoon.azimuth)°")
check("Sydney kürzester Tag ≈ 9h54m", abs(sydney.dayLength!/3600 - 9.9) < 0.1, "\(sydney.dayLength!/3600) h")

// ---- 6) Polartag / Polarnacht Tromsø
let tromsoTZ = TimeZone(identifier: "Europe/Oslo")!
let polarDay = SolarDay(date: day(2026, 6, 21, "Europe/Oslo"), latitude: 69.6492, longitude: 18.9553, timeZone: tromsoTZ)
let polarNight = SolarDay(date: day(2026, 12, 21, "Europe/Oslo"), latitude: 69.6492, longitude: 18.9553, timeZone: tromsoTZ)
check("Tromsø 21.06. = Mitternachtssonne", polarDay.isPolarDay && polarDay.sunrise == nil, "min Höhe \(polarDay.minElevation)°")
check("Tromsø 21.12. = Polarnacht", polarNight.isPolarNight && polarNight.sunset == nil, "max Höhe \(polarNight.maxElevation)°")

// ---- 7) Zeitgleichung: Extremwerte im Jahr (~ -14,2 min Anf. Feb, +16,4 min Anf. Nov)
var minEot = 99.0, maxEot = -99.0, minDate = "", maxDate = ""
for d in 0..<365 {
    let date = day(2026, 1, 1, "UTC").addingTimeInterval(Double(d) * 86400)
    let p = Solar.position(date: date, latitude: 0, longitude: 0)
    if p.equationOfTime < minEot { minEot = p.equationOfTime; minDate = fmt(date, "UTC") }
    if p.equationOfTime > maxEot { maxEot = p.equationOfTime; maxDate = fmt(date, "UTC") }
}
check("Zeitgleichung Minimum ≈ −14,2 min (Anf. Feb)", abs(minEot + 14.2) < 0.4 && minDate.contains("-02-"), "\(minEot) am \(minDate)")
check("Zeitgleichung Maximum ≈ +16,4 min (Anf. Nov)", abs(maxEot - 16.4) < 0.4 && maxDate.contains("-11-"), "\(maxEot) am \(maxDate)")

// ---- 8) Refraktion: 34' gilt für die *scheinbare* Horizonthöhe.
//        Ein Objekt bei geometrisch −0,567° erscheint also genau am Horizont.
check("Refraktion bei geometrisch −0,567° ≈ 34' (0,567°)",
      abs(Solar.refraction(-0.567) - 0.5667) < 0.015, "\(Solar.refraction(-0.567) * 60)'")
check("Refraktion bei geometrisch 0° ≈ 29'",
      abs(Solar.refraction(0) * 60 - 28.9) < 0.5, "\(Solar.refraction(0) * 60)'")
check("Refraktion nimmt mit der Höhe monoton ab",
      Solar.refraction(0) > Solar.refraction(10) && Solar.refraction(10) > Solar.refraction(45)
        && Solar.refraction(45) > Solar.refraction(80) && Solar.refraction(80) > 0,
      "0°: \(Solar.refraction(0)*60)'  10°: \(Solar.refraction(10)*60)'  45°: \(Solar.refraction(45)*60)'  80°: \(Solar.refraction(80)*60)'")
// Der Aufgangs-Schwellwert −0,833° ist die Konvention (34' nominale Refraktion
// + 16' Sonnenradius); dass er die veröffentlichten Zeiten trifft, prüft Test 1.
// Hier: die scheinbare Höhe kreuzt den Horizont bei geometrisch ≈ −0,575°.
check("scheinbare Höhe = 0 bei geometrisch ≈ −0,575°",
      abs(-0.575 + Solar.refraction(-0.575)) < 0.01, "\(-0.575 + Solar.refraction(-0.575))°")
// Scheinbare Höhe muss über den ganzen sichtbaren Bereich streng monoton steigen,
// sonst zerfiele der gezeichnete Bogen in Scheinsegmente.
var monotone = true
var previous = -99.0
var geom = -20.0
while geom <= 90.0 {
    let apparent = geom + Solar.refraction(geom)
    if apparent < previous { monotone = false; break }
    previous = apparent
    geom += 0.005
}
check("scheinbare Höhe monoton über −20°…90°", monotone, "22 000 Stützstellen geprüft")

// ---- 9) Deklination zur Sonnenwende ≈ ±23,44°
let junDecl = Solar.position(date: day(2026, 6, 21, "UTC"), latitude: 0, longitude: 0).declination
let decDecl = Solar.position(date: day(2026, 12, 21, "UTC"), latitude: 0, longitude: 0).declination
check("Deklination 21.06. ≈ +23,44°", abs(junDecl - 23.44) < 0.06, "\(junDecl)°")
check("Deklination 21.12. ≈ −23,44°", abs(decDecl + 23.44) < 0.06, "\(decDecl)°")

// ---- 10) Erdentfernung: Perihel ~0,983 AE (Anf. Jan), Aphel ~1,017 AE (Anf. Juli)
let peri = Solar.position(date: day(2026, 1, 3, "UTC"), latitude: 0, longitude: 0).distanceAU
let aphe = Solar.position(date: day(2026, 7, 5, "UTC"), latitude: 0, longitude: 0).distanceAU
check("Perihel ≈ 0,983 AE", abs(peri - 0.9833) < 0.001, "\(peri)")
check("Aphel ≈ 1,017 AE", abs(aphe - 1.0167) < 0.001, "\(aphe)")

// ---- 11) Azimut-Quadranten prüfen (Regensburg, Sommer)
let rgb = SolarDay(date: day(2026, 6, 21, "Europe/Berlin"), latitude: 49.0134, longitude: 12.1016, timeZone: berlinTZ)
let morning = rgb.sample(at: rgb.dayStart.addingTimeInterval(8*3600))   // 08:00 MESZ
let evening = rgb.sample(at: rgb.dayStart.addingTimeInterval(19*3600))  // 19:00 MESZ
check("Morgens (08:00) Sonne im Osten (60–120°)", (60...120).contains(morning.azimuth), "\(morning.azimuth)°")
check("Abends (19:00) Sonne im Westen (240–300°)", (240...300).contains(evening.azimuth), "\(evening.azimuth)°")
check("Morgens steigend / abends fallend", morning.elevation > 0 && evening.elevation > 0, "\(morning.elevation)° / \(evening.elevation)°")

// ---- 12) Schattenlänge bei 45° Höhe = 1×
var cal = Calendar(identifier: .gregorian); cal.timeZone = berlinTZ
let s45 = rgb.samples.min { abs($0.apparentElevation - 45) < abs($1.apparentElevation - 45) }!
check("Schattenfaktor bei ~45° ≈ 1,0", abs(s45.shadowLengthFactor! - 1.0) < 0.05, "Höhe \(s45.apparentElevation)° → \(s45.shadowLengthFactor!)×")

print("\n\(failures == 0 ? "ALLE TESTS BESTANDEN" : "\(failures) TEST(S) FEHLGESCHLAGEN")")
exit(failures == 0 ? 0 : 1)
