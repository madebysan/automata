import Foundation

// Finds installed apps for the app picker UI.
// Scans /Applications and ~/Applications for .app bundles.
enum AppDiscoveryService {

    /// Get a sorted list of installed apps as (name, path) tuples.
    static func installedApps() -> [(name: String, path: String)] {
        let fm = FileManager.default
        var seen = Set<String>()
        var apps: [(name: String, path: String)] = []

        let searchDirs = [
            "/Applications",
            NSHomeDirectory() + "/Applications",
        ]

        for dir in searchDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let name = (item as NSString).deletingPathExtension
                if seen.insert(name).inserted {
                    apps.append((name: name, path: dir + "/" + item))
                }
            }
        }

        return apps.sorted { $0.name < $1.name }
    }
}
