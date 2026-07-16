import Combine
import Foundation
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isAvailable = true
    @Published private(set) var statusMessage: String?

    private let service: SMAppService
    private let isDevelopmentBuild: Bool

    init(
        service: SMAppService = .mainApp,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) {
        self.service = service
        isDevelopmentBuild = bundleIdentifier?.hasSuffix(".dev") == true
        refresh()
    }

    func refresh() {
        updateState()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
            updateState()
        } catch {
            let errorMessage = "Could not update Launch at Login: \(error.localizedDescription)"
            updateState()
            if service.status != .requiresApproval {
                statusMessage = errorMessage
            }
        }
    }

    private func updateState() {
        if isDevelopmentBuild {
            isEnabled = false
            isAvailable = false
            statusMessage = "Launch at Login is unavailable for development builds."
            return
        }

        let status = service.status
        isEnabled = status == .enabled
        isAvailable = true

        switch status {
        case .notRegistered, .enabled, .notFound:
            statusMessage = nil
        case .requiresApproval:
            statusMessage = "Allow Edf Controller in System Settings > General > Login Items."
        @unknown default:
            statusMessage = "Launch at Login status is unavailable."
        }
    }
}
