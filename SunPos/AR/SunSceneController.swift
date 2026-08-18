import ARKit
import SceneKit
import UIKit

/// Baut und pflegt die AR-Szene: Sonnenbahn, Stundenmarken, Sonnenscheibe,
/// Horizontring, Himmelsrichtungen und die Referenzbahnen der Sonnenwenden.
final class SunSceneController: NSObject, ARSCNViewDelegate, ARSessionObserver {

    // MARK: - Farben

    enum Palette {
        static let daylight = UIColor(red: 1.00, green: 0.78, blue: 0.25, alpha: 1)
        static let night = UIColor(red: 0.35, green: 0.52, blue: 0.95, alpha: 1)
        static let sun = UIColor(red: 1.00, green: 0.87, blue: 0.45, alpha: 1)
        static let selected = UIColor(red: 0.35, green: 0.95, blue: 0.95, alpha: 1)
        static let horizon = UIColor(white: 1, alpha: 0.55)
        static let cardinal = UIColor(white: 1, alpha: 0.9)
        static let summer = UIColor(red: 1.00, green: 0.45, blue: 0.30, alpha: 1)
        static let winter = UIColor(red: 0.55, green: 0.80, blue: 1.00, alpha: 1)
    }

    // MARK: - Öffentlicher Zustand

    let sceneView = ARSCNView(frame: .zero)

    /// Wird gerufen, wenn sich der Trackingzustand ändert.
    var onTrackingStateChange: ((ARCamera.TrackingState) -> Void)?
    /// Wird gerufen, wenn die Sitzung fehlschlägt.
    var onSessionError: ((String) -> Void)?

    // MARK: - Knotenhierarchie

    /// Folgt der Kameraposition, damit die Himmelskugel immer um den Nutzer zentriert bleibt.
    private let skyNode = SCNNode()
    private let pathNode = SCNNode()
    private let hourNode = SCNNode()
    private let solsticeNode = SCNNode()
    private let horizonNode = SCNNode()
    private let sunNode = SCNNode()
    private let selectedNode = SCNNode()

    private var isConfigured = false

    // MARK: - Aufbau

    override init() {
        super.init()
        configureView()
    }

    private func configureView() {
        guard !isConfigured else { return }
        isConfigured = true

        let scene = SCNScene()
        sceneView.scene = scene
        // ARSCNView ist selbst Session-Delegate und leitet die Rückrufe an `delegate` weiter –
        // `session.delegate` darf hier nicht überschrieben werden.
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sceneView.antialiasingMode = .multisampling2X
        sceneView.rendersContinuously = true
        sceneView.preferredFramesPerSecond = 60

        scene.rootNode.addChildNode(skyNode)
        [horizonNode, pathNode, solsticeNode, hourNode, sunNode, selectedNode].forEach {
            skyNode.addChildNode($0)
        }

        buildHorizon()
        buildSun()
        buildSelectedMarker()
    }

    // MARK: - Sitzung

    static var isSupported: Bool { ARWorldTrackingConfiguration.isSupported }

    func startSession() {
        guard Self.isSupported else { return }
        let configuration = ARWorldTrackingConfiguration()
        // Entscheidend: richtet die Weltachsen an Schwerkraft *und* Kompass aus,
        // −Z zeigt danach nach geografisch Nord.
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = []
        configuration.environmentTexturing = .none
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func pauseSession() {
        sceneView.session.pause()
    }

    // MARK: - Inhalt aktualisieren

    /// Baut die Bahnen neu – nur nötig, wenn sich Tag oder Ort geändert haben.
    func rebuildPaths(day: SolarDay,
                      summerSolstice: SolarDay?,
                      winterSolstice: SolarDay?,
                      showsHourMarkers: Bool,
                      showsNightArc: Bool,
                      showsSolsticePaths: Bool,
                      timeZone: TimeZone) {
        pathNode.childNodes.forEach { $0.removeFromParentNode() }
        hourNode.childNodes.forEach { $0.removeFromParentNode() }
        solsticeNode.childNodes.forEach { $0.removeFromParentNode() }

        // Tagbogen (über dem Horizont) – kräftig.
        for segment in day.daylightSegments {
            let points = segment.map { SkyGeometry.vector(for: $0) }
            if let line = SkyGeometry.polyline(points: points, color: Palette.daylight) {
                pathNode.addChildNode(line)
            }
            // Perlenkette macht die Linie auf Distanz besser sichtbar.
            for (index, sample) in segment.enumerated() where index % 8 == 0 {
                let bead = SkyGeometry.glowSphere(radius: 0.13, color: Palette.daylight)
                bead.position = SkyGeometry.vector(for: sample)
                pathNode.addChildNode(bead)
            }
        }

        // Nachtbogen (unter dem Horizont) – gestrichelt und gedämpft.
        if showsNightArc {
            for segment in day.nightSegments {
                let points = segment.map { SkyGeometry.vector(for: $0) }
                if let line = SkyGeometry.dashedPolyline(points: points, color: Palette.night, opacity: 0.75) {
                    pathNode.addChildNode(line)
                }
            }
        }

        // Stundenmarken.
        if showsHourMarkers {
            buildHourMarkers(day: day, timeZone: timeZone)
        }

        // Referenzbahnen der Sonnenwenden.
        if showsSolsticePaths {
            addSolsticePath(summerSolstice, color: Palette.summer, label: "Sommersonnenwende")
            addSolsticePath(winterSolstice, color: Palette.winter, label: "Wintersonnenwende")
        }
    }

    /// Aktualisiert nur die beweglichen Marker – günstig, wird jede Sekunde gerufen.
    func updateMarkers(now: SunSample?, selected: SunSample?, isLive: Bool) {
        if let now {
            sunNode.isHidden = false
            sunNode.position = SkyGeometry.vector(for: now)
            sunNode.opacity = now.apparentElevation >= -1 ? 1 : 0.35
        } else {
            sunNode.isHidden = true
        }

        if let selected, !isLive {
            selectedNode.isHidden = false
            selectedNode.position = SkyGeometry.vector(for: selected)
        } else {
            selectedNode.isHidden = true
        }
    }

    // MARK: - Statische Geometrie

    private func buildHorizon() {
        if let ring = SkyGeometry.polyline(points: SkyGeometry.circle(elevation: 0),
                                           color: Palette.horizon, opacity: 0.5) {
            horizonNode.addChildNode(ring)
        }

        // Höhenkreise als leichte Orientierungshilfe.
        for elevation in [30.0, 60.0] {
            if let ring = SkyGeometry.dashedPolyline(points: SkyGeometry.circle(elevation: elevation, segments: 120),
                                                     color: UIColor(white: 1, alpha: 0.35), opacity: 0.35) {
                horizonNode.addChildNode(ring)
            }
            let tick = SkyGeometry.label("\(Int(elevation))°", color: UIColor(white: 1, alpha: 0.5), size: 8, scale: 0.11, weight: .regular)
            tick.position = SkyGeometry.vector(azimuth: 180, elevation: elevation)
            horizonNode.addChildNode(tick)
        }

        // Himmelsrichtungen.
        let cardinals: [(String, Double, CGFloat)] = [
            ("N", 0, 1.0), ("O", 90, 1.0), ("S", 180, 1.0), ("W", 270, 1.0),
            ("NO", 45, 0.55), ("SO", 135, 0.55), ("SW", 225, 0.55), ("NW", 315, 0.55)
        ]
        for (text, azimuth, weight) in cardinals {
            let node = SkyGeometry.label(text, color: Palette.cardinal.withAlphaComponent(weight),
                                         size: weight > 0.9 ? 16 : 11,
                                         scale: weight > 0.9 ? 0.22 : 0.15)
            node.position = SkyGeometry.vector(azimuth: azimuth, elevation: 2.5)
            horizonNode.addChildNode(node)

            // Kurzer vertikaler Strich am Horizont.
            let from = SkyGeometry.vector(azimuth: azimuth, elevation: -1.5)
            let to = SkyGeometry.vector(azimuth: azimuth, elevation: weight > 0.9 ? 1.2 : 0.5)
            if let stroke = SkyGeometry.polyline(points: [from, to],
                                                 color: Palette.cardinal.withAlphaComponent(weight * 0.8)) {
                horizonNode.addChildNode(stroke)
            }
        }
    }

    private func buildSun() {
        let disc = SkyGeometry.glowSphere(radius: 0.75, color: Palette.sun, emissionIntensity: 1.4)
        let halo = SkyGeometry.halo(diameter: 6.5, color: Palette.sun)
        sunNode.addChildNode(halo)
        sunNode.addChildNode(disc)

        // Sanftes Pulsieren, damit die Sonne im Kamerabild auffällt.
        let pulse = SCNAction.sequence([
            SCNAction.scale(to: 1.08, duration: 1.6),
            SCNAction.scale(to: 0.94, duration: 1.6)
        ])
        halo.runAction(SCNAction.repeatForever(pulse))
    }

    private func buildSelectedMarker() {
        let ring = SkyGeometry.ring(diameter: 3.2, thickness: 0.075, color: Palette.selected)
        let core = SkyGeometry.glowSphere(radius: 0.3, color: Palette.selected, emissionIntensity: 1.2)
        selectedNode.addChildNode(ring)
        selectedNode.addChildNode(core)
        selectedNode.isHidden = true

        ring.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.fadeOpacity(to: 0.45, duration: 0.9),
            SCNAction.fadeOpacity(to: 1.0, duration: 0.9)
        ])))
    }

    private func buildHourMarkers(day: SolarDay, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        for hour in 0..<24 {
            guard let moment = calendar.date(byAdding: .hour, value: hour, to: day.dayStart) else { continue }
            let sample = day.sample(at: moment)
            // Unterhalb der bürgerlichen Dämmerung werden die Marken zu dicht – auslassen.
            guard sample.apparentElevation > -8 else { continue }

            let isDaylight = sample.apparentElevation >= 0
            let color = isDaylight ? Palette.daylight : Palette.night
            let position = SkyGeometry.vector(for: sample)

            let marker = SkyGeometry.glowSphere(radius: isDaylight ? 0.26 : 0.18,
                                                color: color.withAlphaComponent(isDaylight ? 1 : 0.7))
            marker.position = position
            hourNode.addChildNode(marker)

            let label = SkyGeometry.label(String(format: "%02d", hour),
                                          color: color,
                                          size: 11,
                                          scale: isDaylight ? 0.15 : 0.12)
            // Beschriftung leicht oberhalb der Bahn absetzen.
            label.position = SkyGeometry.vector(azimuth: sample.azimuth,
                                                elevation: sample.apparentElevation + 2.2)
            label.opacity = isDaylight ? 1 : 0.6
            hourNode.addChildNode(label)
        }
    }

    private func addSolsticePath(_ solstice: SolarDay?, color: UIColor, label: String) {
        guard let solstice else { return }
        var labelPlaced = false
        for segment in solstice.daylightSegments {
            let points = segment.map { SkyGeometry.vector(for: $0) }
            if let line = SkyGeometry.dashedPolyline(points: points, color: color, opacity: 0.5) {
                solsticeNode.addChildNode(line)
            }
            if !labelPlaced, let apex = segment.max(by: { $0.elevation < $1.elevation }) {
                let text = SkyGeometry.label(label, color: color.withAlphaComponent(0.85),
                                             size: 9, scale: 0.12, weight: .medium)
                text.position = SkyGeometry.vector(azimuth: apex.azimuth,
                                                   elevation: apex.apparentElevation + 3)
                solsticeNode.addChildNode(text)
                labelPlaced = true
            }
        }
    }

    // MARK: - ARSCNViewDelegate

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Himmelskugel dem Nutzer nachführen, damit sie bei Bewegung nicht „wegdriftet“.
        guard let pointOfView = sceneView.pointOfView else { return }
        skyNode.simdPosition = pointOfView.simdWorldPosition
    }

    // MARK: - ARSessionObserver

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        onTrackingStateChange?(camera.trackingState)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        onSessionError?(error.localizedDescription)
    }

    func sessionWasInterrupted(_ session: ARSession) {
        onTrackingStateChange?(.notAvailable)
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        startSession()
    }
}
