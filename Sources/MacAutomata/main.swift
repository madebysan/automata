import Cocoa

// Automata — menu bar automation app.
// No sandbox (needs launchd access), runs as LSUIElement (no dock icon).

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
