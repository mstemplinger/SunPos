import SwiftUI

/// Anbieterkennzeichnung nach § 5 DDG und Datenschutzerklärung.
///
/// Beide Ansichten hängen als `NavigationLink` in der Hilfe (`HelpSheet`). Die Texte
/// beschreiben genau das, was die App tatsächlich tut – bei Änderungen an
/// `LocationService`, `SunSceneController` oder der Ablage in `AppState` sind sie
/// mitzuführen. Insbesondere die Reverse-Geokodierung (Abschnitt 4) und der
/// gespeicherte manuelle Ort (Abschnitt 7) sind Zusagen, keine Beschreibungen.
enum Legal {

    /// Anbieter – identisch zu den übrigen Apps.
    static let providerName = "Tobias Aufschläger"
    static let providerStreet = "Hadamarstraße 22e"
    static let providerCity = "93051 Regensburg"
    static let providerCountry = "Deutschland"
    static let contactMail = "contact@golftrack.com"

    /// Stand der Datenschutzerklärung. Bei inhaltlichen Änderungen anheben.
    static let privacyDate = "18. August 2026"

    static var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "SunPos \(version) (Build \(build))"
    }
}

// MARK: - Impressum

struct ImprintView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LegalBlock(title: "Angaben nach § 5 DDG", symbol: "person.text.rectangle", lines: [
                    Legal.providerName,
                    Legal.providerStreet,
                    Legal.providerCity,
                    Legal.providerCountry
                ])

                LegalBlock(title: "Kontakt", symbol: "envelope", lines: [
                    "E-Mail: \(Legal.contactMail)"
                ])

                LegalBlock(title: "Art des Angebots", symbol: "hand.raised", lines: [
                    "SunPos ist ein privates Projekt und wird ohne Gewinnerzielungsabsicht bereitgestellt.",
                    "Eine Umsatzsteuer-Identifikationsnummer besteht daher nicht, ebenso keine Registereintragung."
                ])

                LegalBlock(title: "Haftung für die angezeigten Werte", symbol: "function", lines: [
                    "Sonnenstand und Tagesereignisse werden nach dem Verfahren des NOAA Solar Calculator (Meeus) berechnet und dienen der Information.",
                    "In der AR-Ansicht ist die Höhe der Bahn rechnerisch exakt; ihre Drehung nach Norden hängt am Magnetkompass des Geräts und kann neben Metall oder im Fahrzeug um mehrere Grad abweichen.",
                    "Für Entscheidungen mit Sicherheitsbezug – Navigation, Luft- und Seefahrt – sowie für bauliche Verschattungs- oder Ertragsnachweise ist die App nicht bestimmt.",
                    "Für die Richtigkeit, Vollständigkeit und Aktualität der Anzeige wird keine Haftung übernommen."
                ])

                LegalBlock(title: "Wichtiger Hinweis zur Nutzung", symbol: "exclamationmark.triangle", accent: Theme.summer, lines: [
                    "Blicke nie direkt in die Sonne – auch nicht über die Kamera und nicht durch die eingezeichnete Bahn hindurch. Das kann die Augen dauerhaft schädigen.",
                    "Achte in der AR-Ansicht auf deine Umgebung und nicht nur auf den Bildschirm."
                ])

                LegalBlock(title: "Urheberrecht", symbol: "c.circle", lines: [
                    "Gestaltung und Quellcode der App sind urheberrechtlich geschützt.",
                    "Die Sonnenstandsberechnung folgt der veröffentlichten Beschreibung des NOAA Solar Calculator nach Jean Meeus, „Astronomical Algorithms“.",
                    "Inhalte Dritter werden nicht eingebunden; Ortsnamen liefert der Geokodierungsdienst von Apple."
                ])

                LegalBlock(title: "App-Version", symbol: "number", lines: [
                    Legal.versionLine,
                    "Swift und SwiftUI, ARKit und SceneKit"
                ])
            }
            .padding(20)
        }
        .background(LegalBackground())
        .navigationTitle("Impressum")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Datenschutzerklärung

struct PrivacyView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summary

                LegalBlock(title: "1 · Verantwortlicher", symbol: "person.text.rectangle", lines: [
                    Legal.providerName,
                    "\(Legal.providerStreet), \(Legal.providerCity), \(Legal.providerCountry)",
                    "E-Mail: \(Legal.contactMail)",
                    "Ein Datenschutzbeauftragter ist gesetzlich nicht zu bestellen; richte Anfragen bitte an die obige Adresse."
                ])

                LegalBlock(title: "2 · Keine Erhebung durch uns", symbol: "nosign", lines: [
                    "SunPos betreibt keinen eigenen Server. Es gibt kein Nutzerkonto und keine Registrierung.",
                    "Es sind keine Analyse-, Werbe- oder Absturzberichtsdienste Dritter eingebunden, und es findet kein geräte- oder app-übergreifendes Tracking statt.",
                    "Deshalb fragt die App auch nicht nach einer Tracking-Erlaubnis."
                ])

                LegalBlock(title: "3 · Standort", symbol: "location", lines: [
                    "Erteilst du im iOS-Dialog die Freigabe „Bei Verwendung der App“, liest SunPos die Position über CoreLocation mit einer angeforderten Genauigkeit von etwa 100 Metern.",
                    "Die Koordinaten dienen allein der Berechnung des Sonnenstands und der Ausrichtung der Bahn. Sie werden im Arbeitsspeicher gehalten und nicht an uns übertragen.",
                    "Ohne Freigabe bleibt die App nutzbar: Du gibst den Ort dann von Hand ein.",
                    "Rechtsgrundlage ist Art. 6 Abs. 1 lit. b DSGVO – die Berechnung ist die Funktion, die du aufgerufen hast."
                ])

                LegalBlock(title: "4 · Ortsname über Apple", symbol: "globe.europe.africa", accent: Theme.selected, lines: [
                    "Damit statt reiner Koordinaten ein Ortsname erscheint, übergibt die App die Koordinaten an den Geokodierungsdienst von Apple (CLGeocoder). Diese eine Anfrage verlässt das Gerät.",
                    "Verarbeitet wird sie von Apple Inc. beziehungsweise Apple Distribution International; dafür gilt die Datenschutzerklärung von Apple (apple.com/legal/privacy).",
                    "Die Anfrage erfolgt nur bei erteilter Standortfreigabe und erst dann erneut, wenn du dich um mehr als zwei Kilometer bewegt hast.",
                    "Für Übermittlungen in die USA stützt sich Apple nach eigenen Angaben auf das EU-US Data Privacy Framework beziehungsweise Standardvertragsklauseln."
                ])

                LegalBlock(title: "5 · Kamera", symbol: "camera", lines: [
                    "In der AR-Ansicht greift ARKit auf das rückseitige Kamerabild zu, um die Sonnenbahn darüber zu zeichnen.",
                    "Das Bild wird ausschließlich im Arbeitsspeicher verarbeitet: Es wird nicht gespeichert, nicht in die Fotobibliothek geschrieben und nicht übertragen.",
                    "Eine Gesichts-, Personen- oder Objekterkennung findet nicht statt."
                ])

                LegalBlock(title: "6 · Kompass und Bewegungssensoren", symbol: "safari", lines: [
                    "Kurs und Neigung liefern Magnetometer und Bewegungssensoren des Geräts. Diese Werte bleiben auf dem Gerät."
                ])

                LegalBlock(title: "7 · Was lokal gespeichert wird", symbol: "internaldrive", lines: [
                    "Gibst du Koordinaten von Hand ein, merkt sich die App diesen Ort in ihren Einstellungen (UserDefaults, Eintrag „SunPos.manualLocation“), damit er beim nächsten Start wieder da ist.",
                    "Das ist die einzige Speicherung. Sie liegt in der Sandbox der App auf dem Gerät und ist nach § 25 Abs. 2 Nr. 2 TTDSG ohne Einwilligung zulässig, weil sie der von dir gewünschten Funktion dient.",
                    "Du entfernst sie, indem du im Ortsdialog auf die automatische Ortung zurückschaltest oder die App löschst.",
                    "Datum, Uhrzeit und Anzeigeoptionen werden nicht dauerhaft gespeichert."
                ])

                LegalBlock(title: "8 · Empfänger", symbol: "arrow.left.arrow.right", lines: [
                    "Außer der unter 4 beschriebenen Geokodierung bei Apple werden keine Daten weitergegeben – wir haben keine.",
                    "Den Vertrieb über den App Store verantwortet Apple als eigener Verantwortlicher. Von Apple erhalten wir nur zusammengefasste Statistiken ohne Bezug zu einzelnen Personen."
                ])

                LegalBlock(title: "9 · Speicherdauer", symbol: "clock.arrow.circlepath", lines: [
                    "Bei uns läuft keine Frist, weil bei uns nichts gespeichert wird.",
                    "Der lokale Eintrag zum manuellen Ort bleibt, bis du ihn zurücksetzt oder die App entfernst."
                ])

                LegalBlock(title: "10 · Deine Rechte", symbol: "checkmark.shield", lines: [
                    "Du kannst Auskunft verlangen (Art. 15 DSGVO), Berichtigung (Art. 16), Löschung (Art. 17), Einschränkung der Verarbeitung (Art. 18) und Datenübertragung (Art. 20); außerdem kannst du widersprechen (Art. 21).",
                    "Da bei uns keine personenbezogenen Daten vorliegen, werden wir eine Anfrage in der Regel mit dieser Feststellung beantworten.",
                    "Du hast das Recht, sich bei einer Aufsichtsbehörde zu beschweren. Zuständig ist das Bayerische Landesamt für Datenschutzaufsicht, Promenade 27, 91522 Ansbach.",
                    "Eine automatisierte Entscheidungsfindung oder ein Profiling findet nicht statt."
                ])

                Text("Stand: \(Legal.privacyDate)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .background(LegalBackground())
        .navigationTitle("Datenschutz")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Kurz gesagt", systemImage: "hand.thumbsup")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.sun)
            Text("SunPos rechnet auf dem Gerät. Kein Konto, kein Server von uns, keine Analyse, keine Werbung, kein Tracking. Dein Standort verlässt das Gerät nur für eine Sache: den Ortsnamen, den Apple dazu liefert.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.sun.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.sun.opacity(0.30), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Bausteine

/// Abschnitt aus Überschrift und Aufzählung, passend zum dunklen Rahmen der App.
private struct LegalBlock: View {
    let title: String
    let symbol: String
    var accent: Color = Theme.sun
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Gleicher Grund wie in den übrigen Sheets.
private struct LegalBackground: View {
    var body: some View {
        Color(red: 0.05, green: 0.06, blue: 0.11).ignoresSafeArea()
    }
}
