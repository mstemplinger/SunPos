import Foundation
import ARKit
import SceneKit
import UIKit

func allNodes(_ n: SCNNode) -> [SCNNode] { [n] + n.childNodes.flatMap(allNodes) }
var fails = 0
func check(_ n: String, _ ok: Bool, _ d: String) {
    print("\(ok ? "PASS" : "FAIL")  \(n) — \(d)"); if !ok { fails += 1 }
}
func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return c.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
}

let tz = TimeZone(identifier: "Europe/Berlin")!
let lat = 49.0134, lon = 12.1016
let today = SolarDay(date: day(2026, 8, 12), latitude: lat, longitude: lon, timeZone: tz)
let summer = SolarDay(date: day(2026, 6, 21), latitude: lat, longitude: lon, timeZone: tz)
let winter = SolarDay(date: day(2026, 12, 21), latitude: lat, longitude: lon, timeZone: tz)

let controller = SunSceneController()
check("ARSCNView + Szene erzeugt", !controller.sceneView.scene.rootNode.childNodes.isEmpty, "Szene mit Wurzelknoten")

controller.rebuildPaths(day: today, summerSolstice: summer, winterSolstice: winter,
                        showsHourMarkers: true, showsNightArc: true,
                        showsSolsticePaths: true, timeZone: tz)

// Knotenbaum einsammeln
let root = controller.sceneView.scene.rootNode
let nodes = allNodes(root)
check("Szenengraph aufgebaut", nodes.count > 200, "\(nodes.count) Knoten")

// Himmelsknoten mit den sechs Gruppen
let sky = root.childNodes.first!
check("Himmelsknoten hat 6 Gruppen", sky.childNodes.count == 6, "\(sky.childNodes.count)")

let horizon = sky.childNodes[0], path = sky.childNodes[1]
let solstice = sky.childNodes[2], hours = sky.childNodes[3]
let sun = sky.childNodes[4], selected = sky.childNodes[5]

check("Horizontgruppe gefüllt (Ring, Höhenkreise, 8 Richtungen)", horizon.childNodes.count >= 20, "\(horizon.childNodes.count)")
check("Bahngruppe gefüllt", path.childNodes.count > 10, "\(path.childNodes.count)")
// Gestrichelte Bahnen liegen je Segment in einem Container – rekursiv zählen.
check("Sonnenwendbahnen vorhanden (2 Bahnen + Beschriftungen)",
      solstice.childNodes.count == 4 && allNodes(solstice).count > 100,
      "\(solstice.childNodes.count) Container, \(allNodes(solstice).count) Knoten gesamt")
check("Stundenmarken vorhanden", hours.childNodes.count >= 20, "\(hours.childNodes.count)")
check("Sonnenknoten: Scheibe + Lichthof", sun.childNodes.count == 2, "\(sun.childNodes.count)")
check("Auswahlmarke initial verborgen", selected.isHidden, "isHidden = \(selected.isHidden)")

// Marker-Update: Sonne muss exakt auf der berechneten Richtung liegen
let noon = today.solarNoon
controller.updateMarkers(now: noon, selected: noon, isLive: true)
let expected = SkyGeometry.vector(for: noon)
let actual = sun.position
let delta = sqrt(pow(actual.x-expected.x,2) + pow(actual.y-expected.y,2) + pow(actual.z-expected.z,2))
check("Sonne auf Höchststand positioniert", delta < 0.001,
      String(format: "Azimut %.1f° Höhe %.1f° → (%.2f, %.2f, %.2f), Δ=%.5f",
             noon.azimuth, noon.apparentElevation, actual.x, actual.y, actual.z, delta))
// Höchststand im Süden ⇒ +Z groß, X ≈ 0
check("Höchststand zeigt nach Süden (+Z)", actual.z > 15 && abs(actual.x) < 0.3, String(format: "X=%.2f Z=%.2f", actual.x, actual.z))
check("Höchststand über Augenhöhe (+Y)", actual.y > 20, String(format: "Y=%.2f", actual.y))

// Live-Modus: Auswahlring bleibt aus; Zeitreise-Modus: Ring erscheint
check("Live-Modus verbirgt den Auswahlring", selected.isHidden, "isHidden = \(selected.isHidden)")
let morning = today.sample(at: today.dayStart.addingTimeInterval(8 * 3600))
controller.updateMarkers(now: noon, selected: morning, isLive: false)
check("Zeitreise-Modus zeigt den Auswahlring", !selected.isHidden, "isHidden = \(selected.isHidden)")
let expectedMorning = SkyGeometry.vector(for: morning)
check("Auswahlring auf 08:00-Position", abs(selected.position.x - expectedMorning.x) < 0.001
        && abs(selected.position.z - expectedMorning.z) < 0.001,
      String(format: "Azimut %.1f° → X=%.2f Z=%.2f (Osten ⇒ X>0)", morning.azimuth, selected.position.x, selected.position.z))
check("Morgensonne im Osten (X>0, Z<0 … Nordost-Quadrant)", selected.position.x > 0, String(format: "X=%.2f", selected.position.x))

// Sonne unter dem Horizont wird gedimmt, nicht versteckt
let night = today.sample(at: today.dayStart.addingTimeInterval(2 * 3600))
controller.updateMarkers(now: night, selected: night, isLive: true)
check("Nachtsonne gedimmt statt versteckt", !sun.isHidden && sun.opacity < 0.5,
      String(format: "Höhe %.1f° → opacity %.2f", night.apparentElevation, sun.opacity))

// Optionen wirken: ohne Stundenmarken / ohne Sonnenwenden müssen die Gruppen leer sein
controller.rebuildPaths(day: today, summerSolstice: summer, winterSolstice: winter,
                        showsHourMarkers: false, showsNightArc: false,
                        showsSolsticePaths: false, timeZone: tz)
check("Option aus ⇒ keine Stundenmarken", hours.childNodes.isEmpty, "\(hours.childNodes.count)")
check("Option aus ⇒ keine Sonnenwendbahnen", solstice.childNodes.isEmpty, "\(solstice.childNodes.count)")
check("Bahn bleibt bestehen", !path.childNodes.isEmpty, "\(path.childNodes.count)")

// Neuaufbau darf keine Knoten anhäufen (Speicherleck-Test)
let before = allNodes(root).count
for _ in 0..<5 {
    controller.rebuildPaths(day: today, summerSolstice: summer, winterSolstice: winter,
                            showsHourMarkers: true, showsNightArc: true,
                            showsSolsticePaths: true, timeZone: tz)
}
let firstFull = allNodes(root).count
for _ in 0..<5 {
    controller.rebuildPaths(day: today, summerSolstice: summer, winterSolstice: winter,
                            showsHourMarkers: true, showsNightArc: true,
                            showsSolsticePaths: true, timeZone: tz)
}
check("Wiederholter Neuaufbau häuft keine Knoten an", allNodes(root).count == firstFull,
      "vor Optionen \(before) → nach 5× \(firstFull) → nach 10× \(allNodes(root).count)")

// Polarnacht: kein Tagbogen, App darf nicht scheitern
let polar = SolarDay(date: day(2026, 12, 21), latitude: 78.2, longitude: 15.6,
                     timeZone: TimeZone(identifier: "Europe/Oslo")!)
controller.rebuildPaths(day: polar, summerSolstice: nil, winterSolstice: nil,
                        showsHourMarkers: true, showsNightArc: true,
                        showsSolsticePaths: true, timeZone: TimeZone(identifier: "Europe/Oslo")!)
check("Polarnacht ohne Tagbogen verarbeitet", polar.daylightSegments.isEmpty && polar.isPolarNight,
      "max Höhe \(String(format: "%.1f", polar.maxElevation))°, Bahnknoten \(path.childNodes.count)")

print("\n\(fails == 0 ? "ALLE SZENEN-TESTS BESTANDEN" : "\(fails) FEHLGESCHLAGEN")")
exit(fails == 0 ? 0 : 1)
