import Combine
import Foundation
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isAvailable = true
    @Published private(set) var statusMessage: String?

    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
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
        let status = service.status
        isEnabled = status == .enabled
        isAvailable = status != .notFound

        switch status {
        case .notRegistered, .enabled:
            statusMessage = nil
        case .requiresApproval:
            statusMessage = "Allow Edf Controller in System Settings > General > Login Items."
        case .notFound:
            statusMessage = "Launch at Login is unavailable for this copy of Edf Controller."
        @unknown default:
            statusMessage = "Launch at Login status is unavailable."
        }
    }
}
