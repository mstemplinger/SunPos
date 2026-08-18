import SwiftUI

/// Klassisches Sonnenbahndiagramm: Azimut waagerecht, Höhe senkrecht.
/// Funktioniert ohne Kamera und Kompass und dient als Referenz zur AR-Ansicht.
struct DiagramView: View {
    @ObservedObject var state: AppState

    /// Sichtbarer Höhenbereich.
    private let minElevation: Double = -20
    private let maxElevation: Double = 90

    /// Platz für Kopfzeile und Bedienfeld, damit das Diagramm nicht darunter verschwindet.
    private let headerInset: CGFloat = 96
    private let panelInset: CGFloat = 214

    var body: some View {
        ZStack {
            background

            VStack(spacing: 6) {
                Spacer(minLength: 0).frame(height: headerInset)

                if let day = state.day {
                    Canvas { context, size in
                        // Innerhalb der Canvas nur noch Achsenbeschriftungen freihalten.
                        let plot = CGRect(x: 34, y: 10,
                                          width: size.width - 56,
                                          height: size.height - 52)
                        guard plot.width > 40, plot.height > 40 else { return }

                        drawGrid(context: context, plot: plot, day: day)
                        if state.showsSolsticePaths {
                            drawPath(context: context, plot: plot, day: state.summerSolstice,
                                     color: Theme.summer, dashed: true, lineWidth: 1.2)
                            drawPath(context: context, plot: plot, day: state.winterSolstice,
                                     color: Theme.winter, dashed: true, lineWidth: 1.2)
                        }
                        drawPath(context: context, plot: plot, day: day,
                                 color: Theme.sun, belowHorizonColor: Theme.night,
                                 dashed: false, lineWidth: 2.4)
                        if state.showsHourMarkers {
                            drawHourMarkers(context: context, plot: plot, day: day)
                        }
                        drawMarkers(context: context, plot: plot, day: day)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .tint(Theme.sun)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                legend

                Spacer(minLength: 0).frame(height: panelInset)
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.06, blue: 0.13),
                     Color(red: 0.02, green: 0.03, blue: 0.07)],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: Theme.sun, label: "Heute", dashed: false)
            if state.showsSolsticePaths {
                legendItem(color: Theme.summer, label: "Längster Tag", dashed: true)
                legendItem(color: Theme.winter, label: "Kürzester Tag", dashed: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glass(cornerRadius: 12)
        .padding(.horizontal, 12)
    }

    private func legendItem(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(color)
                .frame(width: 14, height: 2)
                .opacity(dashed ? 0.6 : 1)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Achsenabbildung

    /// Mittelpunkt der waagerechten Achse: die Richtung des Sonnenhöchststands.
    /// So liegt der Bogen auf beiden Erdhalbkugeln zentriert im Bild.
    private func axisCenter(for day: SolarDay) -> Double {
        day.solarNoon.azimuth
    }

    private func x(azimuth: Double, plot: CGRect, day: SolarDay) -> CGFloat {
        var delta = azimuth - axisCenter(for: day)
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return plot.minX + CGFloat((delta + 180) / 360) * plot.width
    }

    private func y(elevation: Double, plot: CGRect) -> CGFloat {
        let clamped = min(max(elevation, minElevation), maxElevation)
        let normalized = (clamped - minElevation) / (maxElevation - minElevation)
        return plot.maxY - CGFloat(normalized) * plot.height
    }

    // MARK: - Zeichnen

    private func drawGrid(context: GraphicsContext, plot: CGRect, day: SolarDay) {
        // Farbige Höhenbänder (Tag, goldene Stunde, Dämmerungsstufen)
        let bands: [(Double, Double)] = [(maxElevation, 6), (6, 0), (0, -6), (-6, -12), (-12, minElevation)]
        for (upper, lower) in bands {
            let rect = CGRect(x: plot.minX, y: y(elevation: upper, plot: plot),
                              width: plot.width,
                              height: y(elevation: lower, plot: plot) - y(elevation: upper, plot: plot))
            let mid = (upper + lower) / 2
            context.fill(Path(rect), with: .color(Theme.skyColor(elevation: mid).opacity(0.28)))
        }

        // Horizont
        var horizon = Path()
        horizon.move(to: CGPoint(x: plot.minX, y: y(elevation: 0, plot: plot)))
        horizon.addLine(to: CGPoint(x: plot.maxX, y: y(elevation: 0, plot: plot)))
        context.stroke(horizon, with: .color(.white.opacity(0.7)), lineWidth: 1)

        // Höhenlinien und Beschriftung
        for elevation in stride(from: 0.0, through: 90.0, by: 15.0) {
            let yPos = y(elevation: elevation, plot: plot)
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: yPos))
            line.addLine(to: CGPoint(x: plot.maxX, y: yPos))
            context.stroke(line, with: .color(.white.opacity(0.12)),
                           style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
            context.draw(
                Text("\(Int(elevation))°")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45)),
                at: CGPoint(x: plot.minX - 6, y: yPos), anchor: .trailing
            )
        }

        // Azimutlinien mit Himmelsrichtungen
        for step in stride(from: -180.0, through: 180.0, by: 45.0) {
            let azimuth = Solar.mod360(axisCenter(for: day) + step)
            let xPos = plot.minX + CGFloat((step + 180) / 360) * plot.width
            var line = Path()
            line.move(to: CGPoint(x: xPos, y: plot.minY))
            line.addLine(to: CGPoint(x: xPos, y: plot.maxY))
            context.stroke(line, with: .color(.white.opacity(0.12)),
                           style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
            // 360 als 0 anzeigen – bei einem Achsenmittelpunkt knapp unter 180° entstünde sonst „360°“.
            let rounded = Int(azimuth.rounded()) % 360
            context.draw(
                Text("\(Solar.compassLabel(for: azimuth))\n\(rounded)°")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5)),
                at: CGPoint(x: xPos, y: plot.maxY + 14), anchor: .top
            )
        }
    }

    /// Zeichnet eine Tagesbahn. Ist `belowHorizonColor` gesetzt, wird der Teil unter
    /// dem Horizont in dieser Farbe abgesetzt – wie in der AR-Ansicht.
    private func drawPath(context: GraphicsContext, plot: CGRect, day: SolarDay?,
                          color: Color, belowHorizonColor: Color? = nil,
                          dashed: Bool, lineWidth: CGFloat) {
        guard let day else { return }

        var above = Path()
        var below = Path()
        var isDrawingAbove = false
        var isDrawingBelow = false
        var previousX: CGFloat?
        var previousPoint: CGPoint?
        var previousWasAbove: Bool?

        for sample in day.samples where sample.apparentElevation >= minElevation {
            let point = CGPoint(x: x(azimuth: sample.azimuth, plot: plot, day: day),
                                y: y(elevation: sample.apparentElevation, plot: plot))
            let isAbove = belowHorizonColor == nil || sample.isAboveHorizon

            // Sprung über die Achsenkante (Norden) darf keine Linie quer durchs Bild ziehen.
            if let previousX, abs(point.x - previousX) > plot.width * 0.5 {
                isDrawingAbove = false
                isDrawingBelow = false
                previousPoint = nil
            }
            // Beim Horizontwechsel beide Teilpfade am gleichen Punkt verbinden.
            if let previousWasAbove, previousWasAbove != isAbove, let previousPoint {
                if isAbove {
                    above.move(to: previousPoint)
                    isDrawingAbove = true
                    isDrawingBelow = false
                } else {
                    below.move(to: previousPoint)
                    isDrawingBelow = true
                    isDrawingAbove = false
                }
            }

            if isAbove {
                if isDrawingAbove { above.addLine(to: point) } else { above.move(to: point); isDrawingAbove = true }
            } else {
                if isDrawingBelow { below.addLine(to: point) } else { below.move(to: point); isDrawingBelow = true }
            }

            previousX = point.x
            previousPoint = point
            previousWasAbove = isAbove
        }

        let style = dashed
            ? StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [5, 4])
            : StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        context.stroke(above, with: .color(color.opacity(dashed ? 0.7 : 1)), style: style)
        if let belowHorizonColor {
            context.stroke(below, with: .color(belowHorizonColor.opacity(0.8)),
                           style: StrokeStyle(lineWidth: max(1.2, lineWidth - 0.8), lineCap: .round, dash: [4, 4]))
        }
    }

    private func drawHourMarkers(context: GraphicsContext, plot: CGRect, day: SolarDay) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = state.timeZone

        for hour in 0..<24 {
            guard let moment = calendar.date(byAdding: .hour, value: hour, to: day.dayStart) else { continue }
            let sample = day.sample(at: moment)
            guard sample.apparentElevation >= minElevation + 2 else { continue }

            let point = CGPoint(x: x(azimuth: sample.azimuth, plot: plot, day: day),
                                y: y(elevation: sample.apparentElevation, plot: plot))
            let isDay = sample.isAboveHorizon
            let radius: CGFloat = isDay ? 3 : 2
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(isDay ? Theme.sun : Theme.night)
            )
            if hour % 2 == 0 {
                // Beschriftung zur Außenseite des Bogens versetzen, damit sie nicht auf der Linie liegt.
                let offsetX: CGFloat = point.x < plot.midX ? -11 : 11
                context.draw(
                    Text(String(format: "%02d", hour))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(isDay ? Theme.sun : Theme.night),
                    at: CGPoint(x: point.x + offsetX, y: point.y - 7), anchor: .center
                )
            }
        }
    }

    private func drawMarkers(context: GraphicsContext, plot: CGRect, day: SolarDay) {
        if let now = state.nowSample, state.isToday {
            let point = CGPoint(x: x(azimuth: now.azimuth, plot: plot, day: day),
                                y: y(elevation: now.apparentElevation, plot: plot))
            context.fill(Path(ellipseIn: CGRect(x: point.x - 11, y: point.y - 11, width: 22, height: 22)),
                         with: .color(Theme.sun.opacity(0.25)))
            context.fill(Path(ellipseIn: CGRect(x: point.x - 5.5, y: point.y - 5.5, width: 11, height: 11)),
                         with: .color(Theme.sun))
        }

        if let selected = state.selectedSample, !state.followsRealTime {
            let point = CGPoint(x: x(azimuth: selected.azimuth, plot: plot, day: day),
                                y: y(elevation: selected.apparentElevation, plot: plot))
            let ring = Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18))
            context.stroke(ring, with: .color(Theme.selected), lineWidth: 2)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)),
                         with: .color(Theme.selected))
        }
    }
}
