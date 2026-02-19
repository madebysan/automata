import Foundation

// Finds installed apps for the app picker UI.
// Scans /Applications and ~/Applications for .app bundles.
enum AppDiscoveryService {

    /// Get a sorted list of installed app names.
    static func installedApps() -> [String] {
        let fm = FileManager.default
        var apps = Set<String>()

        let searchDirs = [
            "/Applications",
            NSHomeDirectory() + "/Applications",
        ]

        for dir in searchDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let name = (item as NSString).deletingPathExtension
                apps.insert(name)
            }
        }

        return apps.sorted()
    }
}
