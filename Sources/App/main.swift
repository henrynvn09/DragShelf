import AppKit

// Entry point — manual NSApplication bootstrap (no @main attribute)

NSLog("[DropoverClone] 🚀 Binary starting...")
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
NSLog("[DropoverClone] 🚀 Calling app.run()")
app.run()
