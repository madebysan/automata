import Cocoa

// App lifecycle manager.
// Sets up the menu bar status item and manages the main window.
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the data directory if it doesn't exist
        FileLocations.ensureDirectoriesExist()

        // Set up the menu bar icon and dropdown
        statusBarController = StatusBarController()

        Log.info("Mac Automata launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.info("Mac Automata quit")
    }
}
