import SwiftUI
import ServiceManagement
import Combine

@main
struct BehaveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class SettingsState: ObservableObject {
    @Published var frequency: Double
    @Published var sentences: [String]
    @Published var launchAtLogin: Bool
    
    init() {
        // Initialize with default values first
        self.frequency = 10
        self.sentences = [
            "Take a deep breath",
            "Stretch your legs",
            "Drink some water",
            "Check your posture",
            "Look away from the screen",
            "Do a quick exercise",
            "Take a short walk",
            "Practice mindfulness",
            "Review your goals",
            "Express gratitude"
        ]
        self.launchAtLogin = false
        
        // Then load saved values if they exist
        if let savedFrequency = UserDefaults.standard.object(forKey: "frequency") as? Double {
            self.frequency = savedFrequency
        }
        
        if let savedSentences = UserDefaults.standard.stringArray(forKey: "sentences") {
            self.sentences = savedSentences
        }
        
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        
        // Set up observers after initialization
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe frequency changes
        $frequency.sink { [weak self] newValue in
            UserDefaults.standard.set(newValue, forKey: "frequency")
        }.store(in: &cancellables)
        
        // Observe sentences changes
        $sentences.sink { [weak self] newValue in
            UserDefaults.standard.set(newValue, forKey: "sentences")
        }.store(in: &cancellables)
        
        // Observe launch at login changes
        $launchAtLogin.sink { [weak self] newValue in
            UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
            self?.setLaunchAtLogin(newValue)
        }.store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var timer: Timer?
    var sentenceWindow: NSWindow?
    var settingsWindow: NSWindow?
    let settingsState = SettingsState()
    private var isPaused = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupTimer(showImmediatePrompt: true)
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "Behave")
            button.imagePosition = .imageLeft
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        
        // Add Pause/Resume menu item
        let pauseResumeItem = NSMenuItem(
            title: "Pause",
            action: #selector(togglePause),
            keyEquivalent: "p"
        )
        menu.addItem(pauseResumeItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc private func togglePause() {
        isPaused.toggle()
        
        if isPaused {
            timer?.invalidate()
            timer = nil
            if let menu = statusItem?.menu {
                menu.items[2].title = "Resume"
            }
        } else {
            setupTimer(showImmediatePrompt: false)
            if let menu = statusItem?.menu {
                menu.items[2].title = "Pause"
            }
        }
    }
    
    private func setupTimer(showImmediatePrompt: Bool = false) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settingsState.frequency * 60, repeats: true) { [weak self] _ in
            self?.showRandomSentence()
        }
        // Show first sentence immediately only when app launches
        if showImmediatePrompt {
            showRandomSentence()
        }
    }
    
    @objc private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.center()
            settingsWindow?.title = "Behave Settings"
            settingsWindow?.level = .floating
        }
        
        let settingsView = SettingsView(
            frequency: Binding(
                get: { self.settingsState.frequency },
                set: { newValue in
                    self.settingsState.frequency = newValue
                    self.setupTimer(showImmediatePrompt: false)
                }
            ),
            sentences: Binding(
                get: { self.settingsState.sentences },
                set: { self.settingsState.sentences = $0 }
            )
        )
        .environmentObject(settingsState)
        
        settingsWindow?.contentView = NSHostingView(rootView: settingsView)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func showRandomSentence() {
        let randomSentence = settingsState.sentences.randomElement() ?? "Take a break"
        
        DispatchQueue.main.async {
            self.displaySentence(randomSentence)
        }
    }
    
    private func displaySentence(_ sentence: String) {
        // Create window if it doesn't exist
        if sentenceWindow == nil {
            sentenceWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 100),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            sentenceWindow?.level = .floating
            sentenceWindow?.backgroundColor = .clear
            sentenceWindow?.isOpaque = false
            sentenceWindow?.hasShadow = false
        }
        
        // Position window at the bottom left of the screen
        if let screen = NSScreen.main {
            let windowWidth = CGFloat(sentenceWindow?.frame.width ?? 700)
            let windowHeight = CGFloat(sentenceWindow?.frame.height ?? 100)
            let padding: CGFloat = 20 // Padding from screen edges
            
            sentenceWindow?.setFrameOrigin(NSPoint(x: screen.frame.minX + padding, y: screen.frame.minY + padding))
        }
        
        // Create and set the content view
        let contentView = SentenceView(sentence: sentence)
        sentenceWindow?.contentView = NSHostingView(rootView: contentView)
        
        // Show window
        sentenceWindow?.makeKeyAndOrderFront(nil)
        
        // Hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.sentenceWindow?.orderOut(nil)
        }
    }
} 