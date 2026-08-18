import SwiftUI

/// Übersicht aller Tagesereignisse mit Kennzahlen; Tippen springt zum Zeitpunkt.
struct SunTimesSheet: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let day = state.day {
                    List {
                        summarySection(day: day)
                        eventSection(day: day)
                        detailSection(day: day)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                } else {
                    ContentUnavailableView("Kein Standort",
                                           systemImage: "location.slash",
                                           description: Text("Ohne Position lassen sich keine Sonnenzeiten berechnen."))
                }
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.11))
            .navigationTitle("Sonnenzeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Zusammenfassung

    private func summarySection(day: SolarDay) -> some View {
        Section(Format.date(day.dayStart, timeZone: state.timeZone)) {
            if day.isPolarDay {
                Label("Mitternachtssonne – die Sonne geht heute nicht unter.",
                      systemImage: "sun.max.circle.fill")
                    .foregroundStyle(Theme.sun)
            } else if day.isPolarNight {
                Label("Polarnacht – die Sonne bleibt heute unter dem Horizont.",
                      systemImage: "moon.stars.fill")
                    .foregroundStyle(Theme.night)
            }

            HStack(spacing: 12) {
                summaryTile(title: "Tageslänge",
                            value: day.dayLength.map { Format.duration($0) } ?? "—",
                            symbol: "hourglass")
                summaryTile(title: "Höchststand",
                            value: Format.angle(day.maxElevation),
                            symbol: "arrow.up.to.line")
                summaryTile(title: "Um",
                            value: Format.time(day.solarNoon.date, timeZone: state.timeZone),
                            symbol: "sun.max")
            }
            .padding(.vertical, 4)

            if let delta = dayLengthDelta(day: day) {
                HStack {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text("\(Format.signedDuration(delta)) gegenüber dem Vortag")
                }
                .font(.system(size: 13))
                .foregroundStyle(delta >= 0 ? Theme.sun : Theme.night)
            }
        }
    }

    private func summaryTile(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Differenz der Tageslänge zum Vortag – zeigt, ob die Tage länger oder kürzer werden.
    private func dayLengthDelta(day: SolarDay) -> TimeInterval? {
        guard let today = day.dayLength,
              let yesterdayDate = state.calendar.date(byAdding: .day, value: -1, to: day.dayStart) else { return nil }
        let yesterday = SolarDay(date: yesterdayDate, latitude: day.latitude,
                                 longitude: day.longitude, timeZone: day.timeZone)
        guard let previous = yesterday.dayLength else { return nil }
        return today - previous
    }

    // MARK: - Ereignisse

    private func eventSection(day: SolarDay) -> some View {
        Section("Tagesverlauf") {
            ForEach(day.events) { event in
                Button {
                    // Schließen, damit der Sprung sofort in Bahn und Diagramm sichtbar wird.
                    state.jump(to: event.date)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: event.kind.symbol)
                            .font(.system(size: 14))
                            .frame(width: 26)
                            .foregroundStyle(color(for: event.kind))
                        Text(event.kind.title)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(Format.time(event.date, timeZone: state.timeZone))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            let sample = day.sample(at: event.date)
                            Text("\(Solar.compassLabel(for: sample.azimuth)) · \(Format.angle(sample.apparentElevation, decimals: 0))")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func color(for kind: SunEvent.Kind) -> Color {
        switch kind {
        case .sunrise, .sunset, .solarNoon: return Theme.sun
        case .goldenHourEnd, .goldenHourStart: return Theme.sunDeep
        default: return Theme.night
        }
    }

    // MARK: - Details

    private func detailSection(day: SolarDay) -> some View {
        Section("Astronomische Details") {
            let noonPosition = Solar.position(date: day.solarNoon.date,
                                              latitude: day.latitude,
                                              longitude: day.longitude)
            detailRow("Deklination der Sonne", Format.angle(noonPosition.declination, decimals: 2))
            detailRow("Zeitgleichung", String(format: "%+.1f min", noonPosition.equationOfTime))
            detailRow("Entfernung", String(format: "%.4f AE (%.1f Mio. km)",
                                           noonPosition.distanceAU,
                                           noonPosition.distanceAU * 149.597870))
            detailRow("Azimut bei Höchststand",
                      "\(Format.angle(day.solarNoon.azimuth)) \(Solar.compassLabel(for: day.solarNoon.azimuth))")
            if let sunrise = day.sunrise {
                let sample = day.sample(at: sunrise)
                detailRow("Aufgangsrichtung",
                          "\(Format.angle(sample.azimuth)) \(Solar.compassName(for: sample.azimuth))")
            }
            if let sunset = day.sunset {
                let sample = day.sample(at: sunset)
                detailRow("Untergangsrichtung",
                          "\(Format.angle(sample.azimuth)) \(Solar.compassName(for: sample.azimuth))")
            }
            detailRow("Tiefster Stand", Format.angle(day.minElevation))
            detailRow("Zeitzone", day.timeZone.identifier)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
