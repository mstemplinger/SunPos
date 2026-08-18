import Foundation
import SceneKit

var fails = 0
func near(_ a: Float, _ b: Float, _ tol: Float = 0.01) -> Bool { abs(a - b) < tol }
func check(_ n: String, _ ok: Bool, _ d: String) {
    print("\(ok ? "PASS" : "FAIL")  \(n) — \(d)"); if !ok { fails += 1 }
}
func s(_ v: SCNVector3) -> String { String(format: "(%.2f, %.2f, %.2f)", v.x, v.y, v.z) }

let r = SkyGeometry.radius   // 30
// ARKit .gravityAndHeading:  +X = Ost, +Y = oben, −Z = Nord
let north = SkyGeometry.vector(azimuth: 0, elevation: 0)
let east  = SkyGeometry.vector(azimuth: 90, elevation: 0)
let south = SkyGeometry.vector(azimuth: 180, elevation: 0)
let west  = SkyGeometry.vector(azimuth: 270, elevation: 0)
let zenith = SkyGeometry.vector(azimuth: 123, elevation: 90)

check("Nord → −Z", near(north.x, 0) && near(north.y, 0) && near(north.z, -r), s(north))
check("Ost → +X",  near(east.x, r) && near(east.y, 0) && near(east.z, 0), s(east))
check("Süd → +Z",  near(south.x, 0) && near(south.y, 0) && near(south.z, r), s(south))
check("West → −X", near(west.x, -r) && near(west.y, 0) && near(west.z, 0), s(west))
check("Zenit → +Y", near(zenith.y, r) && near(zenith.x, 0, 0.02) && near(zenith.z, 0, 0.02), s(zenith))

// Südost auf halber Höhe: beide Komponenten positiv (Ost+, Süd+), Radius erhalten
let se = SkyGeometry.vector(azimuth: 135, elevation: 45)
let len = sqrt(se.x*se.x + se.y*se.y + se.z*se.z)
check("Südost/45°: X>0, Y>0, Z>0", se.x > 0 && se.y > 0 && se.z > 0, s(se))
check("Radius bleibt 30 m", near(len, r), "\(len)")

// Höhe unter dem Horizont → unter der Augenhöhe
let below = SkyGeometry.vector(azimuth: 0, elevation: -30)
check("negative Höhe → Y<0", below.y < 0, s(below))

// Horizontkreis: 181 Punkte, geschlossen, alle auf Y=0
let circle = SkyGeometry.circle(elevation: 0, segments: 180)
check("Horizontkreis geschlossen", circle.count == 181 && near(circle[0].x, circle[180].x) && near(circle[0].z, circle[180].z),
      "\(circle.count) Punkte")
check("Horizontkreis liegt in Augenhöhe", circle.allSatisfy { near($0.y, 0) }, "alle Y = 0")

// Azimut-Drehsinn: von Nord über Ost (im Uhrzeigersinn von oben betrachtet)
let a10 = SkyGeometry.vector(azimuth: 10, elevation: 0)
check("Azimut dreht im Uhrzeigersinn (N→O)", a10.x > 0 && a10.z < 0, s(a10))

print("\n\(fails == 0 ? "ALLE GEOMETRIE-TESTS BESTANDEN" : "\(fails) FEHLGESCHLAGEN")")
exit(fails == 0 ? 0 : 1)
