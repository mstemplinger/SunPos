import SwiftUI

/// Datumsauswahl mit Schnellsprüngen zu markanten Tagen des Jahres.
struct DatePickerSheet: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Theme.sun)
                }

                Section("Schnellauswahl") {
                    quickRow("Heute", date: Date())
                    if let value = solstice(month: 6, day: 21) {
                        quickRow("Sommersonnenwende (21. Juni)", date: value)
                    }
                    if let value = solstice(month: 12, day: 21) {
                        quickRow("Wintersonnenwende (21. Dez.)", date: value)
                    }
                    if let value = solstice(month: 3, day: 20) {
                        quickRow("Frühlingsäquinoktium (20. März)", date: value)
                    }
                    if let value = solstice(month: 9, day: 22) {
                        quickRow("Herbstäquinoktium (22. Sep.)", date: value)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.05, green: 0.06, blue: 0.11))
            .navigationTitle("Datum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Übernehmen") {
                        state.setDay(date)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { date = state.selectedDay }
    }

    private func quickRow(_ title: String, date value: Date) -> some View {
        Button {
            state.setDay(value)
            dismiss()
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(Format.shortDate(value, timeZone: state.timeZone))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func solstice(month: Int, day: Int) -> Date? {
        let year = state.calendar.component(.year, from: state.selectedDay)
        return state.calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

/// Kurze Erklärung der Anzeige und der Bedienung.
struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section(
                        title: "So funktioniert die AR-Ansicht",
                        symbol: "camera.viewfinder",
                        text: "Halte das Telefon hoch und schwenke es langsam über den Himmel. SunPos richtet die virtuelle Himmelskugel an Schwerkraft und Kompass aus – die eingezeichnete Bahn liegt damit an der echten Position der Sonne am Himmel."
                    )

                    legendBlock

                    section(
                        title: "Zeit verschieben",
                        symbol: "clock.arrow.circlepath",
                        text: "Ziehe auf der Farbleiste, um jeden Moment des Tages zu prüfen. Der türkise Ring zeigt, wo die Sonne zur gewählten Uhrzeit steht. Mit der Uhr-Schaltfläche geht es zurück zum Jetzt-Zustand."
                    )

                    section(
                        title: "Anderer Tag, anderer Ort",
                        symbol: "calendar",
                        text: "Über das Datum lässt sich jeder Tag wählen – etwa um zu sehen, ob die Sonne im Dezember über das Nachbarhaus reicht. Oben links kannst du auch Koordinaten eines beliebigen Orts eingeben."
                    )

                    section(
                        title: "Kompassgenauigkeit",
                        symbol: "exclamationmark.triangle",
                        text: "Die Höhe der Bahn ist rechnerisch exakt; die Drehung nach Norden hängt vom Magnetkompass ab. Bei Metall in der Nähe oder im Auto kann sie um einige Grad verdreht sein. Eine Achterbewegung mit dem Gerät kalibriert den Kompass neu."
                    )

                    section(
                        title: "Genauigkeit der Berechnung",
                        symbol: "function",
                        text: "Sonnenstand nach dem NOAA-Algorithmus (Meeus) inklusive atmosphärischer Refraktion – Abweichung deutlich unter einer Bogenminute. Auf- und Untergang beziehen sich auf den Sonnenoberrand bei −0,833° geometrischer Höhe."
                    )

                    legalBlock
                }
                .padding(20)
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.11))
            .navigationTitle("Hilfe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func section(title: String, symbol: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.sun)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var legendBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Legende", systemImage: "list.bullet")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.sun)

            legendRow(color: Theme.sun, text: "Bahn über dem Horizont – die Sonne ist sichtbar")
            legendRow(color: Theme.night, text: "Bahn unter dem Horizont, gestrichelt – Nacht")
            legendRow(color: Theme.selected, text: "Gewählter Zeitpunkt")
            legendRow(color: Theme.summer, text: "Bahn am längsten Tag des Jahres")
            legendRow(color: Theme.winter, text: "Bahn am kürzesten Tag des Jahres")
            legendRow(color: .white, text: "Horizontring, Höhenkreise bei 30° und 60°, Himmelsrichtungen")
        }
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Impressum und Datenschutz – über die Hilfe erreichbar, damit die Angaben
    /// ohne Netzzugang in der App selbst stehen.
    private var legalBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Rechtliches", systemImage: "doc.plaintext")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.sun)

            NavigationLink { PrivacyView() } label: { legalRow("Datenschutz", symbol: "hand.raised") }
            NavigationLink { ImprintView() } label: { legalRow("Impressum", symbol: "info.circle") }
        }
        .padding(.top, 4)
    }

    private func legalRow(_ title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 16)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
