import SwiftUI

/// Bedienfeld am unteren Rand: Datum, Zeitschieber und Kennzahlen.
struct ControlPanel: View {
    @ObservedObject var state: AppState
    let onOpenTimes: () -> Void
    let onOpenDatePicker: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            metrics
            timeline
            controls
        }
        .padding(14)
        .glass(cornerRadius: 22)
    }

    // MARK: - Kennzahlen

    private var metrics: some View {
        HStack(alignment: .top, spacing: 10) {
            if let sample = state.selectedSample {
                MetricView(
                    label: state.followsRealTime ? "Jetzt" : "Zeitpunkt",
                    value: Format.timeWithSeconds(sample.date, timeZone: state.timeZone),
                    accent: state.followsRealTime ? Theme.sun : Theme.selected,
                    symbol: state.followsRealTime ? "clock.fill" : "clock.arrow.circlepath"
                )
                MetricView(
                    label: "Azimut",
                    value: "\(Format.angle(sample.azimuth)) \(Solar.compassLabel(for: sample.azimuth))",
                    symbol: "safari"
                )
                MetricView(
                    label: "Höhe",
                    value: Format.angle(sample.apparentElevation),
                    accent: sample.apparentElevation >= 0 ? .white : Theme.night,
                    symbol: "arrow.up.right"
                )
                MetricView(
                    label: "Schatten",
                    value: shadowText(for: sample),
                    symbol: "person.fill.and.arrow.left.and.arrow.right"
                )
            } else {
                Text("Warte auf Standort …")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Schattenlänge als Vielfaches der Objekthöhe.
    private func shadowText(for sample: SunSample) -> String {
        guard let factor = sample.shadowLengthFactor else { return "—" }
        if factor > 99 { return "> 99 ×" }
        return String(format: "%.1f ×", factor)
    }

    // MARK: - Zeitschieber

    private var timeline: some View {
        VStack(spacing: 4) {
            if let day = state.day {
                DayTimeline(
                    day: day,
                    timeZone: state.timeZone,
                    seconds: state.secondsIntoDay,
                    nowSeconds: state.isToday ? Date().timeIntervalSince(state.selectedDay) : nil,
                    onChange: { state.setTime(secondsIntoDay: $0) }
                )
                .frame(height: 46)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 46)
            }

            HStack {
                ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                    Text(hour == 24 ? "24" : String(format: "%02d", hour))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .monospacedDigit()
                    if hour != 24 { Spacer() }
                }
            }
        }
    }

    // MARK: - Bedienelemente

    private var controls: some View {
        HStack(spacing: 8) {
            Button { state.shiftDay(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(PillButtonStyle())

            Button(action: onOpenDatePicker) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                    Text(Format.date(state.selectedDay, timeZone: state.timeZone))
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 32)
            }
            .buttonStyle(PillButtonStyle())

            Button { state.shiftDay(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(PillButtonStyle())

            Button { state.resetToNow() } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(PillButtonStyle(isHighlighted: !state.followsRealTime || !state.isToday))

            Button(action: onOpenTimes) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(PillButtonStyle())

            Menu {
                Toggle("Stundenmarken", isOn: $state.showsHourMarkers)
                Toggle("Nachtbogen", isOn: $state.showsNightArc)
                Toggle("Sonnenwenden", isOn: $state.showsSolsticePaths)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
        }
    }
}

struct PillButtonStyle: ButtonStyle {
    var isHighlighted = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHighlighted ? .black : .white)
            .background(
                Capsule().fill(isHighlighted ? AnyShapeStyle(Theme.sun) : AnyShapeStyle(Color.white.opacity(0.12)))
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Tagesleiste

/// 24-Stunden-Leiste, deren Farbverlauf die tatsächliche Sonnenhöhe des Tages
/// abbildet – von Nacht über Dämmerung bis Tageslicht. Ziehen wählt die Uhrzeit.
struct DayTimeline: View {
    let day: SolarDay
    let timeZone: TimeZone
    let seconds: Double
    let nowSeconds: Double?
    let onChange: (Double) -> Void

    private let dayLength: Double = 86_400

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let thumbX = CGFloat(seconds / dayLength) * width

            ZStack(alignment: .leading) {
                // Himmelsfarbverlauf
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(stops: gradientStops,
                                         startPoint: .leading, endPoint: .trailing))

                // Sonnenhöhenkurve als Sparkline
                elevationCurve(width: width, height: height)
                    .stroke(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

                // Horizontlinie
                Path { path in
                    let y = yPosition(forElevation: 0, height: height)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))

                // Marke für die echte Uhrzeit
                if let nowSeconds, nowSeconds >= 0, nowSeconds <= dayLength {
                    let x = CGFloat(nowSeconds / dayLength) * width
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1, height: height)
                        .offset(x: x)
                }

                // Auf- und Untergangsmarken
                ForEach(markerPositions, id: \.0) { offset, symbol in
                    Image(systemName: symbol)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                        .offset(x: CGFloat(offset / dayLength) * width - 4, y: height / 2 - 8)
                }

                // Schieber
                Capsule()
                    .fill(Color.white)
                    .frame(width: 3, height: height)
                    .overlay(alignment: .top) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 9, height: 9)
                            .offset(y: -4)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 3)
                    .offset(x: max(0, min(width - 3, thumbX - 1.5)))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = min(max(0, value.location.x / width), 1)
                        onChange(ratio * dayLength)
                    }
            )
        }
    }

    // MARK: Verlauf

    /// Ein Farbstopp alle 20 Minuten – flüssig genug und günstig zu zeichnen.
    private var gradientStops: [Gradient.Stop] {
        stride(from: 0, through: 72, by: 1).map { step in
            let fraction = Double(step) / 72
            let moment = day.dayStart.addingTimeInterval(fraction * dayLength)
            let elevation = day.sample(at: moment).apparentElevation
            return Gradient.Stop(color: Theme.skyColor(elevation: elevation), location: fraction)
        }
    }

    private func yPosition(forElevation elevation: Double, height: CGFloat) -> CGFloat {
        // Sichtbarer Bereich: −20° bis +90°
        let normalized = (elevation + 20) / 110
        return height - CGFloat(min(max(normalized, 0), 1)) * height
    }

    private func elevationCurve(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            let steps = 144
            for step in 0...steps {
                let fraction = Double(step) / Double(steps)
                let moment = day.dayStart.addingTimeInterval(fraction * dayLength)
                let elevation = day.sample(at: moment).apparentElevation
                let point = CGPoint(x: CGFloat(fraction) * width,
                                    y: yPosition(forElevation: elevation, height: height))
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
    }

    private var markerPositions: [(Double, String)] {
        var result: [(Double, String)] = []
        if let sunrise = day.sunrise {
            result.append((sunrise.timeIntervalSince(day.dayStart), "sunrise.fill"))
        }
        if let sunset = day.sunset {
            result.append((sunset.timeIntervalSince(day.dayStart), "sunset.fill"))
        }
        return result
    }
}

extension Theme {
    /// Himmelsfarbe für eine Sonnenhöhe – gleiche Skala in Leiste und Diagramm.
    static func skyColor(elevation: Double) -> Color {
        switch elevation {
        case 25...:
            return Color(red: 0.32, green: 0.62, blue: 0.95)
        case 6..<25:
            return Color(red: 0.52, green: 0.72, blue: 0.96)
        case 0..<6:
            return Color(red: 0.98, green: 0.72, blue: 0.36)
        case -4..<0:
            return Color(red: 0.85, green: 0.45, blue: 0.38)
        case -6..<(-4):
            return Color(red: 0.42, green: 0.35, blue: 0.62)
        case -12..<(-6):
            return Color(red: 0.14, green: 0.20, blue: 0.44)
        case -18..<(-12):
            return Color(red: 0.06, green: 0.09, blue: 0.24)
        default:
            return Color(red: 0.02, green: 0.03, blue: 0.10)
        }
    }
}
