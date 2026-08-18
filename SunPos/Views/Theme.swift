import SwiftUI

/// Farben, Formatierer und wiederverwendbare Bausteine der Oberfläche.
enum Theme {
    static let sun = Color(red: 1.00, green: 0.82, blue: 0.32)
    static let sunDeep = Color(red: 0.98, green: 0.60, blue: 0.16)
    static let night = Color(red: 0.42, green: 0.58, blue: 0.98)
    static let selected = Color(red: 0.35, green: 0.95, blue: 0.95)
    static let summer = Color(red: 1.00, green: 0.45, blue: 0.30)
    static let winter = Color(red: 0.55, green: 0.80, blue: 1.00)
    static let panel = Color.black.opacity(0.55)
}

enum Format {

    static func time(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func timeWithSeconds(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    static func date(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE, d. MMM yyyy"
        return formatter.string(from: date)
    }

    static func shortDate(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = timeZone
        formatter.dateFormat = "d. MMM"
        return formatter.string(from: date)
    }

    static func angle(_ value: Double, decimals: Int = 1) -> String {
        // „−0°“ vermeiden: Werte, die auf der Anzeigegenauigkeit null ergeben, ohne Vorzeichen zeigen.
        let scale = pow(10.0, Double(decimals))
        let normalized = (value * scale).rounded() == 0 ? 0 : value
        return String(format: "%.\(decimals)f°", normalized)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        return "\(hours) h \(String(format: "%02d", minutes)) min"
    }

    /// Signierte Minutenangabe, z. B. „+3 min 12 s“.
    static func signedDuration(_ seconds: TimeInterval) -> String {
        let sign = seconds >= 0 ? "+" : "−"
        let total = Int(abs(seconds).rounded())
        let minutes = total / 60
        let secs = total % 60
        if minutes == 0 { return "\(sign)\(secs) s" }
        return "\(sign)\(minutes) min \(String(format: "%02d", secs)) s"
    }
}

// MARK: - Bausteine

/// Kompakte Kennzahl mit Beschriftung.
struct MetricView: View {
    let label: String
    let value: String
    var accent: Color = .white
    var symbol: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 9, weight: .semibold))
                }
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
            }
            .foregroundStyle(.white.opacity(0.55))

            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Halbtransparenter Hintergrund für Overlays über dem Kamerabild.
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.black.opacity(0.25))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    }
            }
    }
}

extension View {
    func glass(cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}
