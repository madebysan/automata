import Cocoa

// App lifecycle manager.
// Sets up the menu bar status item, shows onboarding on first launch.
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController!
    private var onboardingController: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the data directory if it doesn't exist
        FileLocations.ensureDirectoriesExist()

        // Set up the menu bar icon and dropdown
        statusBarController = StatusBarController()

        // Show onboarding on first launch
        if !OnboardingWindowController.isComplete {
            onboardingController = OnboardingWindowController()
            onboardingController?.show()
        }

        Log.info("Mac Automata launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.info("Mac Automata quit")
    }
}
