import ARKit
import SwiftUI

struct RootView: View {

    @StateObject private var state = AppState()
    @State private var trackingAdvice: String?
    @State private var sessionError: String?
    @State private var showsTimes = false
    @State private var showsLocation = false
    @State private var showsDatePicker = false
    @State private var showsHelp = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            content
                .ignoresSafeArea()

            VStack(spacing: 0) {
                StatusHeader(
                    state: state,
                    trackingAdvice: state.mode == .augmentedReality ? trackingAdvice : nil,
                    sessionError: sessionError,
                    onTapLocation: { showsLocation = true },
                    onTapHelp: { showsHelp = true }
                )

                Spacer(minLength: 0)

                ControlPanel(
                    state: state,
                    onOpenTimes: { showsTimes = true },
                    onOpenDatePicker: { showsDatePicker = true }
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            if !state.isLocationAuthorized && state.manualLocation == nil {
                PermissionOverlay(state: state)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .onAppear { state.onAppear() }
        .onDisappear { state.onDisappear() }
        .sheet(isPresented: $showsTimes) {
            SunTimesSheet(state: state)
        }
        .sheet(isPresented: $showsLocation) {
            LocationSheet(state: state, location: state.location)
        }
        .sheet(isPresented: $showsDatePicker) {
            DatePickerSheet(state: state)
        }
        .sheet(isPresented: $showsHelp) {
            HelpSheet()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.mode {
        case .augmentedReality:
            if SunSceneController.isSupported {
                ARSkyView(
                    state: state,
                    onTrackingState: { trackingAdvice = $0.advice },
                    onError: { sessionError = $0 }
                )
            } else {
                UnsupportedARView(state: state)
            }
        case .diagram:
            DiagramView(state: state)
        }
    }
}

// MARK: - Kopfzeile

private struct StatusHeader: View {
    @ObservedObject var state: AppState
    let trackingAdvice: String?
    let sessionError: String?
    let onTapLocation: () -> Void
    let onTapHelp: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: onTapLocation) {
                    HStack(spacing: 6) {
                        Image(systemName: state.manualLocation == nil ? "location.fill" : "mappin.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(state.locationLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            if let coordinate = state.coordinate {
                                Text(AppState.format(coordinate: coordinate))
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .monospacedDigit()
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glass(cornerRadius: 14)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Picker("Ansicht", selection: $state.mode) {
                    ForEach(AppState.DisplayMode.allCases) { mode in
                        Image(systemName: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 96)

                Button(action: onTapHelp) {
                    Image(systemName: "questionmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .glass(cornerRadius: 17)
                }
                .buttonStyle(.plain)
            }

            if let notice = sessionError ?? trackingAdvice ?? headingNotice {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(notice)
                        .font(.system(size: 11, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.sun)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glass(cornerRadius: 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.25), value: sessionError)
        .animation(.easeInOut(duration: 0.25), value: trackingAdvice)
    }

    /// Warnung bei unzuverlässigem Kompass – die Bahn wäre dann horizontal verdreht.
    private var headingNotice: String? {
        guard state.mode == .augmentedReality, state.isLocationAuthorized else { return nil }
        return state.compassWarning
    }
}

// MARK: - Standortfreigabe

private struct PermissionOverlay: View {
    @ObservedObject var state: AppState

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Theme.sun)

                Text("Standort freigeben")
                    .font(.system(size: 21, weight: .bold, design: .rounded))

                Text("Der Sonnenstand hängt direkt von Breite und Länge deines Standorts ab. Ohne Position kann SunPos die Bahn nicht berechnen.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                if state.authorizationStatus == .notDetermined {
                    Button("Standort erlauben") { state.location.requestAuthorization() }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Einstellungen öffnen") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Text("Alternativ kannst du oben links einen Ort manuell eingeben.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .glass(cornerRadius: 22)
            .padding(24)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [Theme.sun, Theme.sunDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Kein AR verfügbar

private struct UnsupportedARView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.14), .black],
                           startPoint: .top, endPoint: .bottom)

            VStack(spacing: 14) {
                Image(systemName: "arkit")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.sun)
                Text("AR wird von diesem Gerät nicht unterstützt")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("Alle Berechnungen funktionieren trotzdem – wechsle zur Diagrammansicht.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button("Zum Diagramm") { state.mode = .diagram }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(30)
        }
    }
}

#Preview {
    RootView()
}
