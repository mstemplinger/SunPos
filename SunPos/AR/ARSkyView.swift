import ARKit
import SwiftUI

/// Bindet die ARKit-/SceneKit-Ansicht in SwiftUI ein und hält die Szene
/// mit dem App-Zustand synchron.
struct ARSkyView: UIViewRepresentable {

    @ObservedObject var state: AppState
    /// Meldet den Trackingzustand nach außen (für Hinweise im HUD).
    var onTrackingState: (ARCamera.TrackingState) -> Void
    var onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTrackingState: onTrackingState, onError: onError)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let controller = context.coordinator.controller
        controller.startSession()
        return controller.sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        let coordinator = context.coordinator
        let controller = coordinator.controller

        let optionsKey = "\(state.showsHourMarkers)|\(state.showsNightArc)|\(state.showsSolsticePaths)"
        let needsRebuild = coordinator.lastRevision != state.pathRevision
            || coordinator.lastOptionsKey != optionsKey

        if needsRebuild, let day = state.day {
            coordinator.lastRevision = state.pathRevision
            coordinator.lastOptionsKey = optionsKey
            controller.rebuildPaths(
                day: day,
                summerSolstice: state.summerSolstice,
                winterSolstice: state.winterSolstice,
                showsHourMarkers: state.showsHourMarkers,
                showsNightArc: state.showsNightArc,
                showsSolsticePaths: state.showsSolsticePaths,
                timeZone: state.timeZone
            )
        }

        controller.updateMarkers(
            now: state.nowSample,
            selected: state.selectedSample,
            isLive: state.followsRealTime
        )
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        coordinator.controller.pauseSession()
    }

    final class Coordinator {
        let controller = SunSceneController()
        var lastRevision = -1
        var lastOptionsKey = ""

        init(onTrackingState: @escaping (ARCamera.TrackingState) -> Void,
             onError: @escaping (String) -> Void) {
            controller.onTrackingStateChange = onTrackingState
            controller.onSessionError = onError
        }
    }
}

extension ARCamera.TrackingState {
    /// Nutzerlesbarer Hinweis – `nil`, wenn alles in Ordnung ist.
    var advice: String? {
        switch self {
        case .normal:
            return nil
        case .notAvailable:
            return "AR-Tracking startet …"
        case .limited(let reason):
            switch reason {
            case .initializing:
                return "Bewege das Gerät langsam, bis die Umgebung erkannt ist."
            case .relocalizing:
                return "Position wird wiederhergestellt …"
            case .excessiveMotion:
                return "Zu schnelle Bewegung – halte das Gerät ruhiger."
            case .insufficientFeatures:
                return "Zu wenig Struktur im Bild – richte die Kamera auf eine texturierte Fläche."
            @unknown default:
                return "AR-Tracking eingeschränkt."
            }
        @unknown default:
            return nil
        }
    }
}
