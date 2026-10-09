import Foundation
import Sparkle

/// Owns Sparkle for the lifetime of the app. Debug builds have an empty feed URL,
/// so they never start the updater or check GitHub for releases.
///
/// An update replaces the app bundle; on the next launch, `FilterController.start()`
/// asks macOS to swap in the new content filter, which keeps the user's approval.
@MainActor
final class UpdateController {
    static let shared = UpdateController()

    private var controller: SPUStandardUpdaterController?

    var isAvailable: Bool { controller != nil }

    func startIfConfigured(bundle: Bundle = .main) {
        guard controller == nil,
            let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String, !feedURL.isEmpty,
            let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String, !publicKey.isEmpty
        else { return }

        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
