import CoreLocation
import SwiftUI

/// Standortverwaltung: GPS-Status, manuelle Koordinaten und Ortsvorlagen.
struct LocationSheet: View {
    @ObservedObject var state: AppState
    /// Direkt beobachtet, damit GPS- und Kompasswerte im Blatt live mitlaufen.
    @ObservedObject var location: LocationService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var timeZoneIdentifier = TimeZone.current.identifier
    @State private var validationError: String?

    private static let presets: [ManualLocation] = [
        ManualLocation(name: "Regensburg", latitude: 49.0134, longitude: 12.1016, timeZoneIdentifier: "Europe/Berlin"),
        ManualLocation(name: "Berlin", latitude: 52.5200, longitude: 13.4050, timeZoneIdentifier: "Europe/Berlin"),
        ManualLocation(name: "Wien", latitude: 48.2082, longitude: 16.3738, timeZoneIdentifier: "Europe/Vienna"),
        ManualLocation(name: "Zürich", latitude: 47.3769, longitude: 8.5417, timeZoneIdentifier: "Europe/Zurich"),
        ManualLocation(name: "Tromsø", latitude: 69.6492, longitude: 18.9553, timeZoneIdentifier: "Europe/Oslo"),
        ManualLocation(name: "Singapur", latitude: 1.3521, longitude: 103.8198, timeZoneIdentifier: "Asia/Singapore"),
        ManualLocation(name: "Sydney", latitude: -33.8688, longitude: 151.2093, timeZoneIdentifier: "Australia/Sydney"),
        ManualLocation(name: "Kapstadt", latitude: -33.9249, longitude: 18.4241, timeZoneIdentifier: "Africa/Johannesburg")
    ]

    var body: some View {
        NavigationStack {
            List {
                gpsSection
                manualSection
                presetSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.05, green: 0.06, blue: 0.11))
            .navigationTitle("Standort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear(perform: prefill)
    }

    // MARK: - GPS

    private var gpsSection: some View {
        Section("Gerätestandort") {
            if let coordinate = location.coordinate {
                LabeledContent("Position", value: AppState.format(coordinate: coordinate))
                    .font(.system(size: 13))
                if let accuracy = location.horizontalAccuracy {
                    LabeledContent("Genauigkeit", value: "± \(Int(accuracy)) m")
                        .font(.system(size: 13))
                }
                if let altitude = location.altitude {
                    LabeledContent("Höhe", value: "\(Int(altitude)) m")
                        .font(.system(size: 13))
                }
            } else {
                Text(location.isAuthorized ? "Position wird ermittelt …" : "Kein Standortzugriff erteilt.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            if let heading = location.trueHeading {
                LabeledContent("Kompass",
                               value: "\(Format.angle(heading, decimals: 0)) \(Solar.compassLabel(for: heading))")
                    .font(.system(size: 13))
            }
            if let accuracy = location.headingAccuracy {
                LabeledContent("Kompassgenauigkeit", value: "± \(Int(max(accuracy, 0)))°")
                    .font(.system(size: 13))
                    .foregroundStyle(location.hasReliableHeading ? .primary : Color.orange)
            }

            if state.manualLocation != nil {
                Button {
                    state.manualLocation = nil
                } label: {
                    Label("Gerätestandort verwenden", systemImage: "location.fill")
                }
            }
        }
    }

    // MARK: - Manuelle Eingabe

    private var manualSection: some View {
        Section {
            TextField("Bezeichnung", text: $name)
            HStack {
                Text("Breite")
                    .frame(width: 60, alignment: .leading)
                TextField("z. B. 49.0134", text: $latitudeText)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
            }
            HStack {
                Text("Länge")
                    .frame(width: 60, alignment: .leading)
                TextField("z. B. 12.1016", text: $longitudeText)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
            }
            Picker("Zeitzone", selection: $timeZoneIdentifier) {
                ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { identifier in
                    Text(identifier).tag(identifier)
                }
            }

            if let validationError {
                Text(validationError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            Button("Ort übernehmen", action: apply)
                .disabled(latitudeText.isEmpty || longitudeText.isEmpty)
        } header: {
            Text("Ort manuell festlegen")
        } footer: {
            Text("Nützlich, um die Sonnenbahn für einen anderen Ort zu planen – Breite von −90 bis 90, Länge von −180 bis 180 (Ost positiv).")
        }
    }

    // MARK: - Vorlagen

    private var presetSection: some View {
        Section("Vorlagen") {
            ForEach(Self.presets, id: \.name) { preset in
                Button {
                    state.manualLocation = preset
                    dismiss()
                } label: {
                    HStack {
                        Text(preset.name)
                        Spacer()
                        Text(String(format: "%.2f, %.2f", preset.latitude, preset.longitude))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: - Logik

    private func prefill() {
        if let manual = state.manualLocation {
            name = manual.name
            latitudeText = String(manual.latitude)
            longitudeText = String(manual.longitude)
            timeZoneIdentifier = manual.timeZoneIdentifier
        } else if let coordinate = state.coordinate {
            latitudeText = String(format: "%.4f", coordinate.latitude)
            longitudeText = String(format: "%.4f", coordinate.longitude)
            timeZoneIdentifier = TimeZone.current.identifier
        }
    }

    private func apply() {
        let normalizedLatitude = latitudeText.replacingOccurrences(of: ",", with: ".")
        let normalizedLongitude = longitudeText.replacingOccurrences(of: ",", with: ".")

        guard let latitude = Double(normalizedLatitude), let longitude = Double(normalizedLongitude) else {
            validationError = "Bitte gültige Dezimalzahlen eingeben."
            return
        }
        guard (-90...90).contains(latitude) else {
            validationError = "Die Breite muss zwischen −90 und 90 liegen."
            return
        }
        guard (-180...180).contains(longitude) else {
            validationError = "Die Länge muss zwischen −180 und 180 liegen."
            return
        }

        validationError = nil
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        state.manualLocation = ManualLocation(
            name: label.isEmpty ? String(format: "%.3f, %.3f", latitude, longitude) : label,
            latitude: latitude,
            longitude: longitude,
            timeZoneIdentifier: timeZoneIdentifier
        )
        dismiss()
    }
}
