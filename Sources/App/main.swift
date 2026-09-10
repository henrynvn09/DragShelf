import AppKit

// Entry point — manual NSApplication bootstrap (no @main attribute)

NSLog("[DragShelf] 🚀 Binary starting...")
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
NSLog("[DragShelf] 🚀 Calling app.run()")
app.run()
