# SunPos

Native iOS-App, die den Sonnenverlauf per **ARKit** direkt ins Kamerabild zeichnet: wo die
Sonne jetzt steht, wo sie zu jedem Zeitpunkt des Tages stehen wird, und wie die Bahn am
längsten und kürzesten Tag des Jahres verläuft.

Swift 5 · SwiftUI · ARKit + SceneKit · iOS 17+ · iPhone und iPad

---

## Was die App macht

**AR-Ansicht** — Handy hochhalten und über den Himmel schwenken. Die Szene wird mit
`worldAlignment = .gravityAndHeading` an Schwerkraft *und* Kompass ausgerichtet, dadurch liegt
die virtuelle Himmelskugel deckungsgleich über dem echten Himmel:

- **Goldene Bahn** – Tagbogen über dem Horizont, mit Perlenkette für Sichtbarkeit auf Distanz
- **Blaue gestrichelte Bahn** – Nachtbogen unter dem Horizont
- **Leuchtende Sonnenscheibe** mit Lichthof an der aktuellen Position
- **Türkiser Ring** an der Position des frei gewählten Zeitpunkts
- **Stundenmarken 00–23** mit Beschriftung
- **Gestrichelte Referenzbahnen** für den längsten und kürzesten Tag des Jahres
- **Horizontring**, Höhenkreise bei 30° und 60°, Himmelsrichtungen N/O/S/W + Diagonalen

**Diagrammansicht** — klassisches Sonnenbahndiagramm (Azimut waagerecht, Höhe senkrecht) mit
farbigen Dämmerungsbändern. Braucht weder Kamera noch Kompass und dient als Referenz. Die
waagerechte Achse zentriert sich automatisch auf die Richtung des Sonnenhöchststands, damit
der Bogen auf beiden Erdhalbkugeln mittig liegt.

**Zeitleiste** — der Farbverlauf der 24-Stunden-Leiste bildet die tatsächliche Sonnenhöhe des
Tages ab (Nacht → astronomische/nautische/bürgerliche Dämmerung → goldene Stunde → Tag),
darüber die Höhenkurve als Sparkline. Ziehen wählt jeden Moment des Tages.

**Sonnenzeiten** — Auf- und Untergang, Höchststand, goldene und blaue Stunde, alle drei
Dämmerungsstufen; dazu Tageslänge, Differenz zum Vortag, Deklination, Zeitgleichung,
Erdentfernung und die Auf-/Untergangsrichtungen. Tippen springt zum Zeitpunkt.

**Ort und Datum frei wählbar** — jedes Datum (mit Schnellauswahl für Sonnenwenden und
Äquinoktien) und jeder Ort per Koordinateneingabe oder Vorlage, inklusive Zeitzone. Damit
lässt sich planen, ob die Sonne im Dezember über das Nachbarhaus reicht oder wann am
Urlaubsort die goldene Stunde beginnt.

**Randfälle** — Mitternachtssonne und Polarnacht werden erkannt und benannt; ohne
ARKit-Unterstützung fällt die App auf die Diagrammansicht zurück; bei ungenauem Kompass
erscheint ein Kalibrierhinweis, weil dann die Drehung der Bahn – nicht ihre Höhe – leidet.

---

## Bauen und starten

### Im Simulator (Diagrammansicht, Berechnungen, Bedienung)

```bash
open SunPos.xcodeproj
```

Schema `SunPos` wählen, Simulator starten (⌘R). ARKit läuft im Simulator nicht – dort greift
automatisch die Diagrammansicht. Standort im Simulator setzen:

```bash
xcrun simctl location booted set 49.0134,12.1016
```

### Auf einem echten iPhone (für die AR-Ansicht nötig)

1. Projekt in Xcode öffnen, Target `SunPos` → *Signing & Capabilities*
2. Eigenes *Team* auswählen; die Bundle-ID `com.TobiasAufschlaeger.SunPos` bei Bedarf auf eine eigene ändern
3. iPhone per Kabel verbinden, als Ziel wählen, ⌘R
4. Beim ersten Start Standort- und Kamerazugriff erlauben

Voraussetzung für AR: iPhone mit A9-Chip oder neuer (iPhone 6s und aufwärts).

### Kommandozeile

```bash
xcodebuild -project SunPos.xcodeproj -scheme SunPos -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

---

## Tests

```bash
./Tests/run-tests.sh
```

Drei Gruppen ohne Xcode-Testtarget – die beiden letzten laufen headless im iOS-Simulator:

| Gruppe | Prüft |
| --- | --- |
| `SolarTests` | Sonnenstand gegen veröffentlichte Referenzwerte: Berlin am längsten Tag (SA 04:43, SU 21:33, 16 h 50 min, Höchststand 60,9°), Äquinoktium, Symmetrie um den Höchststand, Südhalbkugel, Mitternachtssonne und Polarnacht in Tromsø, Extrema der Zeitgleichung (−14,2 min / +16,4 min), Refraktion, Deklination ±23,44°, Perihel/Aphel, Azimutquadranten, Schattenlänge |
| `SkyGeometryTests` | Umrechnung Azimut/Höhe in die ARKit-Weltachsen: Nord → −Z, Ost → +X, Süd → +Z, West → −X, Zenit → +Y, Radiuserhaltung, Drehsinn |
| `SceneTests` | Aufbau des AR-Szenengraphen: Gruppenstruktur, Sonne exakt auf der berechneten Richtung, Live- vs. Zeitreisemodus, Dimmen unter dem Horizont, Wirkung der Anzeigeoptionen, kein Knotenwachstum bei wiederholtem Neuaufbau, Polarnacht |

---

## Aufbau

```
SunPos/
├── SunPosApp.swift              App-Einstieg
├── Model/
│   ├── Solar.swift              Sonnenstand nach NOAA/Meeus + Refraktion
│   ├── SolarDay.swift           Tagesbahn: Abtastung, Ereignisse, Kennzahlen
│   └── AppState.swift           Ort, Zeitpunkt, Anzeigeoptionen, Ergebnisse
├── Services/
│   └── LocationService.swift    CoreLocation: Position, Ortsname, Kompass
├── AR/
│   ├── SkyGeometry.swift        Horizontkoordinaten → Weltachsen, Linien/Marker
│   ├── SunSceneController.swift Szenenaufbau und AR-Sitzung
│   └── ARSkyView.swift          SwiftUI-Brücke zu ARSCNView
└── Views/
    ├── RootView.swift           Rahmen, Kopfzeile, Berechtigungen, AR-Fallback
    ├── DiagramView.swift        Sonnenbahndiagramm (Canvas)
    ├── ControlPanel.swift       Kennzahlen, Zeitleiste, Bedienelemente
    ├── SunTimesSheet.swift      Tagesereignisse und astronomische Details
    ├── LocationSheet.swift      GPS-Status, manuelle Koordinaten, Vorlagen
    ├── Sheets.swift             Datumsauswahl und Hilfe
    └── Theme.swift              Farben, Formatierer, Bausteine
```

Das Projekt nutzt eine `PBXFileSystemSynchronizedRootGroup` – neue Dateien im Ordner
`SunPos/` werden von Xcode automatisch übernommen, ohne die Projektdatei zu bearbeiten.

---

## Genauigkeit

Sonnenstand nach dem Algorithmus des *NOAA Solar Calculator* (Meeus, *Astronomical
Algorithms*), inklusive Nutationsterm und atmosphärischer Refraktion. Abweichung deutlich
unter einer Bogenminute für die Jahre 1800–2100 – um Größenordnungen genauer als die
Ausrichtung, die ein Magnetkompass liefern kann.

Tagesereignisse werden nicht über eine Näherungsformel, sondern als Nulldurchgänge der
Höhenfunktion bestimmt (Zwei-Minuten-Abtastung, danach Bisektion auf ±1 s); Höchst- und
Tiefststand per Verfahren des goldenen Schnitts. Das ist an Polarkreisen robust, wo
geschlossene Formeln für Auf- und Untergang keine Lösung haben.

Konventionen: Auf-/Untergang bei −0,833° geometrischer Höhe (34′ nominale Refraktion + 16′
Sonnenradius), goldene Stunde bis +6°, blaue Stunde/bürgerliche Dämmerung −6°, nautische
−12°, astronomische −18°. Azimut von Nord im Uhrzeigersinn, Länge mit Ost positiv.

**In der AR-Ansicht ist die Höhe der Bahn rechnerisch exakt, ihre Drehung nach Norden hängt
am Magnetkompass des Geräts.** In Fahrzeugen oder neben Metall kann sie um einige Grad
verdreht sein; die App weist darauf hin, sobald iOS eine Kompassgenauigkeit schlechter als
±15° meldet.
