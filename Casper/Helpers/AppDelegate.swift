import SwiftUI
import AppKit
import Combine
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: ClickThroughWindow!
    var statusBarItem: NSStatusItem!
    var menu: NSMenu!
    var appStateManager: AppStateManager
    var spotifyService: SpotifyService

    override init() {
        appStateManager = AppStateManager.shared
        spotifyService = SpotifyService(appStateManager: appStateManager)
        super.init()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // Create the window and set its properties
        window = ClickThroughWindow(
            contentRect: NSRect(x: 100, y: 40, width: 300, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = true
        // Create the content view with the environment object
        let contentView = CasperIconView()
            .environmentObject(appStateManager)
            .environmentObject(AppStateManager.shared) // Ensure environment object is provided
        // Set the content view and make the window visible
        window.contentView = NSHostingView(rootView: contentView.environmentObject(spotifyService))
        window.makeKeyAndOrderFront(nil)
        
        if let button = statusBarItem.button {
            if let iconImage = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil) {
                iconImage.isTemplate = true // SF Symbols should generally be used as templates
                button.image = iconImage
            }
        }

        
        // Create the menu
        menu = NSMenu()
        
        // Add some menu items
        menu.addItem(
            withTitle: "Show_Casper",
            action: #selector(showCasper),
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: "Spotify_DJ",
            action: #selector(Spotify_DJ),
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: "Hide_Casper",
            action: #selector(hideCasper),
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: "CalendarHelp",
            action:#selector(calendarHelp),
            keyEquivalent: ""
        )
        
        // Attach the menu to the status bar item
        statusBarItem.menu = menu
    }
    
    // Menu item functions
    @objc func showCasper() {
        AppStateManager.shared.appState = .login
        window.ignoresMouseEvents = false // The window will respond to mouse events again.
        window.makeKeyAndOrderFront(nil) // Show the window.
    }
    @objc func Spotify_DJ() {
        AppStateManager.shared.appState = .autoMonitoring
    }

    @objc func hideCasper() {
        AppStateManager.shared.appState = .hide
        window.ignoresMouseEvents = true // The window will ignore all mouse events.
        window.orderOut(nil) // Hide the window without deactivating the application.
    }
    @objc func calendarHelp(){
        AppStateManager.shared.appState = .calendarHelp
    }
    @objc func terminate() {
        NSApplication.shared.terminate(self)
    }


}

enum AppState {
    case login, 
         idle,
         functionSelection,
         startNLInput,
         userFinishedInput,
         autoMonitoring,
         hide,
         calendarHelp,
         calendarReply,
         systemReply
}
struct SimpleEvent {
    var title: String
    var startDate: Date
    var endDate: Date
    // Add any other relevant information
}
class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    @Published var appState: AppState = .login
    @Published var CalendarEvents: [SimpleEvent] = []
    @Published var systemMessage = ""
    init() {} // Ensures AppStateManager is a singleton
    
    func setEvents(_ events: [SimpleEvent]) {
        self.CalendarEvents = events
    }
    func updateSystemMessage(_ message: String) {
        DispatchQueue.main.async {
            self.systemMessage = message
        }
    }
}
