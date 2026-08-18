import SceneKit
import UIKit

/// Umrechnungen zwischen Horizontkoordinaten (Azimut/Höhe) und der
/// ARKit-Weltachse sowie Bausteine für die Himmelsgeometrie.
///
/// Bei `ARWorldTrackingConfiguration.worldAlignment == .gravityAndHeading` gilt:
/// **+X = Ost, +Y = oben, −Z = geografisch Nord**.
enum SkyGeometry {

    /// Radius der virtuellen Himmelskugel in Metern.
    static let radius: Float = 30

    /// Wandelt Azimut (° von Nord, im Uhrzeigersinn) und Höhe (° über Horizont)
    /// in eine Position auf der Himmelskugel um.
    static func vector(azimuth: Double, elevation: Double, radius: Float = radius) -> SCNVector3 {
        let az = Float(azimuth * .pi / 180)
        let el = Float(elevation * .pi / 180)
        let horizontal = cos(el) * radius
        return SCNVector3(
            horizontal * sin(az),
            sin(el) * radius,
            -horizontal * cos(az)
        )
    }

    static func vector(for sample: SunSample, radius: Float = radius) -> SCNVector3 {
        vector(azimuth: sample.azimuth, elevation: sample.apparentElevation, radius: radius)
    }

    // MARK: - Linien

    /// Erzeugt eine Polylinie als SceneKit-Geometrie (Primitivtyp `.line`).
    static func polyline(points: [SCNVector3], color: UIColor, opacity: CGFloat = 1) -> SCNNode? {
        guard points.count >= 2 else { return nil }

        let source = SCNGeometrySource(vertices: points)
        var indices: [Int32] = []
        indices.reserveCapacity((points.count - 1) * 2)
        for index in 0..<(points.count - 1) {
            indices.append(Int32(index))
            indices.append(Int32(index + 1))
        }
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [source], elements: [element])

        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = color
        material.emission.contents = color
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = false
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.opacity = opacity
        node.renderingOrder = 10
        return node
    }

    /// Gestrichelte Polylinie – jedes zweite Segment wird ausgelassen.
    static func dashedPolyline(points: [SCNVector3], color: UIColor, opacity: CGFloat = 1) -> SCNNode? {
        guard points.count >= 2 else { return nil }
        let container = SCNNode()
        var index = 0
        while index < points.count - 1 {
            if let segment = polyline(points: [points[index], points[index + 1]], color: color, opacity: opacity) {
                container.addChildNode(segment)
            }
            index += 2
        }
        return container.childNodes.isEmpty ? nil : container
    }

    /// Kreis auf der Himmelskugel bei konstanter Höhe (z. B. der Horizontring).
    static func circle(elevation: Double, segments: Int = 180, radius: Float = radius) -> [SCNVector3] {
        (0...segments).map { step in
            vector(azimuth: Double(step) / Double(segments) * 360, elevation: elevation, radius: radius)
        }
    }

    // MARK: - Beschriftungen

    /// Textknoten, der sich immer zur Kamera dreht.
    static func label(_ text: String, color: UIColor, size: CGFloat = 10, scale: Float = 0.16,
                      weight: UIFont.Weight = .semibold) -> SCNNode {
        let geometry = SCNText(string: text, extrusionDepth: 0.2)
        geometry.font = UIFont.systemFont(ofSize: size, weight: weight)
        geometry.flatness = 0.15
        geometry.firstMaterial?.lightingModel = .constant
        geometry.firstMaterial?.diffuse.contents = color
        geometry.firstMaterial?.emission.contents = color
        geometry.firstMaterial?.writesToDepthBuffer = false
        geometry.firstMaterial?.readsFromDepthBuffer = false

        let node = SCNNode(geometry: geometry)
        // Textgeometrie um ihren Mittelpunkt zentrieren.
        let (minBound, maxBound) = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation(
            (minBound.x + maxBound.x) / 2,
            (minBound.y + maxBound.y) / 2,
            (minBound.z + maxBound.z) / 2
        )
        node.scale = SCNVector3(scale, scale, scale)
        node.constraints = [SCNBillboardConstraint()]
        node.renderingOrder = 20
        return node
    }

    // MARK: - Leuchtpunkte

    /// Kugel mit konstanter Eigenleuchtfarbe (keine Beleuchtung nötig).
    static func glowSphere(radius: CGFloat, color: UIColor, emissionIntensity: CGFloat = 1) -> SCNNode {
        let sphere = SCNSphere(radius: radius)
        sphere.segmentCount = 24
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = color
        material.emission.contents = color
        material.emission.intensity = emissionIntensity
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = false
        sphere.materials = [material]
        let node = SCNNode(geometry: sphere)
        node.renderingOrder = 15
        return node
    }

    /// Weicher Lichthof als Billboard-Fläche mit radialem Farbverlauf.
    static func halo(diameter: CGFloat, color: UIColor) -> SCNNode {
        let plane = SCNPlane(width: diameter, height: diameter)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = radialGradientImage(color: color)
        // Additiv gemischt: Schwarz im Verlauf trägt nichts bei, der Hof verblasst weich.
        material.blendMode = .add
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = false
        plane.materials = [material]
        let node = SCNNode(geometry: plane)
        node.constraints = [SCNBillboardConstraint()]
        node.renderingOrder = 14
        return node
    }

    /// Ring als Zielmarkierung (z. B. für den gewählten Zeitpunkt).
    static func ring(diameter: CGFloat, thickness: CGFloat, color: UIColor) -> SCNNode {
        let torus = SCNTorus(ringRadius: diameter / 2, pipeRadius: thickness)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = color
        material.emission.contents = color
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = false
        torus.materials = [material]
        let node = SCNNode(geometry: torus)
        // Torus liegt standardmäßig in der XZ-Ebene – aufrichten, damit er zur Kamera zeigt.
        let holder = SCNNode()
        node.eulerAngles.x = .pi / 2
        holder.addChildNode(node)
        holder.constraints = [SCNBillboardConstraint()]
        holder.renderingOrder = 16
        return holder
    }

    private static var gradientCache: [String: UIImage] = [:]

    private static func radialGradientImage(color: UIColor, size: CGFloat = 256) -> UIImage {
        let key = "\(color.hashValue)-\(size)"
        if let cached = gradientCache[key] { return cached }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let cg = context.cgContext
            let colors = [
                color.withAlphaComponent(0.95).cgColor,
                color.withAlphaComponent(0.35).cgColor,
                color.withAlphaComponent(0.0).cgColor
            ] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors,
                                            locations: [0, 0.35, 1]) else { return }
            let center = CGPoint(x: size / 2, y: size / 2)
            cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                  endCenter: center, endRadius: size / 2,
                                  options: [])
        }
        gradientCache[key] = image
        return image
    }
}
