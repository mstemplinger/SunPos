# App-Store-Einreichung SunPos

Alles, was in App Store Connect eingetragen werden muss. Die Rechtstexte selbst stehen
in `SunPos/Views/LegalView.swift` (in der App) und in `docs/` (als Webseiten).

## Grunddaten

| Feld | Wert |
| --- | --- |
| Name | SunPos |
| Untertitel (max. 30) | Sonnenverlauf in AR sehen |
| Bundle-ID | `com.TobiasAufschlaeger.SunPos` |
| Team | NY363CML59 (Tobias Aufschläger) |
| Version | 1.0 (Build 1) |
| Mindestsystem | iOS 17.0 |
| Geräte | iPhone, iPad (nur Hochformat) |
| Primäre Kategorie | Wetter |
| Sekundäre Kategorie | Bildung |
| Preis | Kostenlos |
| Sprache | Deutsch (Primärsprache) |
| Urheberrecht | 2026 Tobias Aufschläger |

## Support- und Rechts-URLs

GitHub Pages ist aktiv (Repository `mstemplinger/SunPos`, Branch `main`, Ordner `/docs`):

| Feld in App Store Connect | URL |
| --- | --- |
| Datenschutzrichtlinien-URL (**Pflicht**) | `https://mstemplinger.github.io/SunPos/datenschutz.html` |
| Support-URL (**Pflicht**) | `https://mstemplinger.github.io/SunPos/` |
| Marketing-URL (optional) | `https://mstemplinger.github.io/SunPos/` |

Das Impressum liegt unter `https://mstemplinger.github.io/SunPos/impressum.html`.
Apple prüft die Datenschutz-URL bei der Einreichung, sie muss erreichbar bleiben.

## Werbetext (max. 170 Zeichen)

> Halte das iPhone hoch und sieh, wo die Sonne heute entlangzieht – wo sie untergeht,
> wann die goldene Stunde beginnt, und ob sie im Dezember über das Nachbarhaus reicht.

## Beschreibung

> SunPos zeichnet die Bahn der Sonne direkt in das Kamerabild. Halte das Gerät hoch und
> schwenke über den Himmel: Die virtuelle Himmelskugel wird an Schwerkraft und Kompass
> ausgerichtet, dadurch liegt die eingezeichnete Bahn deckungsgleich über dem echten Himmel.
>
> DIE AR-ANSICHT
> • Goldene Bahn für den Tagbogen über dem Horizont, blau gestrichelt darunter für die Nacht
> • Leuchtende Sonnenscheibe an der aktuellen Position, türkiser Ring am gewählten Zeitpunkt
> • Stundenmarken von 00 bis 23 mit Beschriftung
> • Referenzbahnen für den längsten und den kürzesten Tag des Jahres
> • Horizontring, Höhenkreise bei 30° und 60°, Himmelsrichtungen
>
> DIAGRAMM ALS REFERENZ
> Ein klassisches Sonnenbahndiagramm mit farbigen Dämmerungsbändern – ohne Kamera und
> Kompass nutzbar und damit auch dann, wenn das Gerät kein AR unterstützt.
>
> JEDER MOMENT DES TAGES
> Der Farbverlauf der Zeitleiste bildet die tatsächliche Sonnenhöhe ab: von der Nacht über
> die astronomische, nautische und bürgerliche Dämmerung bis zur goldenen Stunde. Ziehen
> wählt jeden Augenblick.
>
> ALLE SONNENZEITEN
> Auf- und Untergang, Höchststand, goldene und blaue Stunde, alle drei Dämmerungsstufen.
> Dazu Tageslänge, Differenz zum Vortag, Deklination, Zeitgleichung, Erdentfernung und die
> Auf- und Untergangsrichtungen.
>
> JEDER ORT, JEDES DATUM
> Jedes Datum mit Schnellauswahl für Sonnenwenden und Äquinoktien, jeder Ort per
> Koordinateneingabe samt Zeitzone. Damit lässt sich planen, wo im Sommer der Schatten
> liegt oder wann am Urlaubsort die goldene Stunde beginnt. Mitternachtssonne und
> Polarnacht werden erkannt und benannt.
>
> GENAUIGKEIT
> Der Sonnenstand folgt dem Verfahren des NOAA Solar Calculator (Meeus, Astronomical
> Algorithms) inklusive atmosphärischer Refraktion – die Abweichung liegt deutlich unter
> einer Bogenminute. Tagesereignisse werden als Nulldurchgänge der Höhenfunktion bestimmt
> und sind deshalb auch an den Polarkreisen zuverlässig. In der AR-Ansicht ist die Höhe der
> Bahn rechnerisch exakt; ihre Drehung nach Norden hängt am Magnetkompass des Geräts.
>
> RECHNET AUF DEM GERÄT
> Kein Konto, kein Server, keine Analyse, keine Werbung, kein Tracking. Der Standort dient
> allein der Berechnung und verlässt das Gerät nur, damit Apple den Ortsnamen dazu liefert.
>
> Blicke nie direkt in die Sonne – auch nicht über die Kamera.

## Schlüsselwörter (max. 100 Zeichen, kommagetrennt)

```
Sonne,Sonnenstand,Sonnenbahn,AR,Schatten,goldene Stunde,Dämmerung,Sonnenuntergang,Azimut
```

## Neuerungen in dieser Version

> Erste Veröffentlichung.

## App-Datenschutz („App Privacy“ in App Store Connect)

Antwort auf „Erfasst deine App Daten?“ → **Nein**.

Begründung, falls Apple nachfragt: Standortdaten und Kamerabild werden ausschließlich auf
dem Gerät verarbeitet und nicht an den Entwickler oder Dritte übertragen. Die einzige
Anfrage, die das Gerät verlässt, ist die Reverse-Geokodierung des Ortsnamens über Apples
eigenen `CLGeocoder`-Dienst; sie wird von Apple verantwortet und dient nur der Anzeige.
Es gibt kein Konto, keine Analyse-SDKs, keine Werbung und keine Kennungen.

Deckungsgleich mit `SunPos/PrivacyInfo.xcprivacy`:
`NSPrivacyTrackingEnabled = false`, `NSPrivacyCollectedDataTypes` leer,
`NSPrivacyAccessedAPITypes` nur UserDefaults mit Grund `CA92.1`.

## Altersfreigabe

Alle Fragebogen-Punkte mit „Keine“ / „Nein“ beantworten → Ergebnis **4+**.
Kein nutzergenerierter Inhalt, keine Web-Ansicht, keine Werbung, kein Glücksspiel,
kein Standort-Teilen mit anderen Personen.

## Exportbestimmungen

Die App nutzt keine eigene Verschlüsselung und stellt keine eigenen Netzwerkverbindungen
her (nur Apples Geokodierung über das System). In App Store Connect bei „Verschlüsselung“
mit **Nein** antworten. Alternativ als Build-Setting hinterlegen:

```
ITSAppUsesNonExemptEncryption = NO
```

## Hinweise für die Prüfung („App Review Information“)

> Die AR-Ansicht braucht ein echtes Gerät mit A9-Chip oder neuer sowie Kamera- und
> Standortfreigabe. Im Simulator ist ARKit nicht verfügbar; die App fällt dort
> automatisch auf die Diagrammansicht zurück, die dieselben Berechnungen zeigt.
>
> Ein Konto ist nicht erforderlich, es gibt keine Anmeldung.
>
> Für einen schnellen Test ohne Blick zum Himmel: oben links auf die Ortsanzeige tippen und
> Koordinaten eingeben (z. B. 69.65 N, 18.96 O für Tromsø) sowie über das Datum den
> 21. Juni oder 21. Dezember wählen – dann werden Mitternachtssonne und Polarnacht benannt.

## Screenshots

Pflicht ist mindestens ein Satz für iPhone 6.9" und, weil die App iPad unterstützt,
ein Satz für iPad 13". Alle im Hochformat.

| Gerät | Auflösung (Hochformat) |
| --- | --- |
| iPhone 6.9" | 1290 × 2796 |
| iPad 13" | 2048 × 2732 |

Die Diagrammansicht, die Zeitleiste, die Sonnenzeiten und der Ortsdialog lassen sich im
Simulator aufnehmen (`AppStore/screenshots/`). **Die AR-Ansicht nicht** – ARKit läuft nur
auf einem echten Gerät. Für den Screenshot, der die eigentliche Funktion zeigt, ist eine
Aufnahme vom iPhone nötig.
