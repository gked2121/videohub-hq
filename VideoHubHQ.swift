import SwiftUI
import AppKit

// MARK: - App Entry

@main
struct VideoHubHQApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 560)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.07, alpha: 1.0)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - Color System

extension Color {
    static let bg = Color(red: 0.08, green: 0.08, blue: 0.07)
    static let cardBg = Color(red: 0.12, green: 0.12, blue: 0.10)
    static let cardHover = Color(red: 0.16, green: 0.15, blue: 0.13)
    static let inputBg = Color(red: 0.10, green: 0.10, blue: 0.09)
    static let sand = Color(red: 0.85, green: 0.75, blue: 0.58)
    static let terra = Color(red: 0.78, green: 0.50, blue: 0.36)
    static let warmWhite = Color(red: 0.93, green: 0.91, blue: 0.87)
    static let dimText = Color(red: 0.55, green: 0.53, blue: 0.48)
    static let borderColor = Color(red: 0.20, green: 0.19, blue: 0.17)
    static let successGreen = Color(red: 0.40, green: 0.72, blue: 0.45)
    static let errorRed = Color(red: 0.82, green: 0.35, blue: 0.30)
}

// MARK: - Generation State

enum GenerationState: Equatable {
    case idle
    case generating
    case snapshotting
    case success(path: String)
    case error(message: String)
}

// MARK: - Recent Project Model

struct RecentProject: Codable, Identifiable, Equatable {
    var id: String { path }
    let path: String
    let name: String
    let prompt: String
    let lastOpened: Date
}

class RecentProjectsStore: ObservableObject {
    @Published var projects: [RecentProject] = []
    private let key = "VideoHubHQ_RecentProjects"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentProject].self, from: data) else { return }
        projects = decoded.sorted { $0.lastOpened > $1.lastOpened }
    }

    func add(path: String, prompt: String) {
        let name = (path as NSString).lastPathComponent
        projects.removeAll { $0.path == path }
        projects.insert(RecentProject(path: path, name: name, prompt: prompt, lastOpened: Date()), at: 0)
        if projects.count > 10 { projects = Array(projects.prefix(10)) }
        save()
    }

    func remove(_ project: RecentProject) {
        projects.removeAll { $0 == project }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Claude Runner

class ClaudeRunner: ObservableObject {
    @Published var state: GenerationState = .idle
    @Published var logLines: [String] = []
    @Published var thumbnailPath: String? = nil
    @Published var progress: Double = 0 // 0.0 to 1.0
    @Published var statusText: String = ""
    private var process: Process?

    private func updateProgress(from line: String) {
        let lower = line.lowercased()
        if lower.contains("starting") || lower.contains("initializ") {
            progress = 0.05; statusText = "Initializing project..."
        } else if lower.contains("hyperframes init") || lower.contains("scaffolding") || lower.contains("npx hyperframes") {
            progress = max(progress, 0.12); statusText = "Scaffolding project..."
        } else if lower.contains("creating") || lower.contains("writing") || lower.contains("wrote") {
            progress = max(progress, 0.20); statusText = "Writing files..."
        } else if lower.contains("composition") || lower.contains(".html") {
            progress = max(progress, 0.35); statusText = "Building compositions..."
        } else if lower.contains("gsap") || lower.contains("animation") || lower.contains("transition") {
            progress = max(progress, 0.50); statusText = "Adding animations..."
        } else if lower.contains("style") || lower.contains("css") || lower.contains("palette") || lower.contains("color") {
            progress = max(progress, 0.60); statusText = "Styling..."
        } else if lower.contains("font") || lower.contains("typography") {
            progress = max(progress, 0.65); statusText = "Setting typography..."
        } else if lower.contains("lint") || lower.contains("validat") {
            progress = max(progress, 0.80); statusText = "Validating..."
        } else if lower.contains("complete") || lower.contains("done") || lower.contains("success") {
            progress = 0.95; statusText = "Finishing up..."
        }
        // Slow crawl for lines that don't match known milestones
        if progress > 0.05 && progress < 0.80 {
            progress = min(progress + 0.008, 0.79)
        }
    }

    func generate(prompt: String, outputDir: String, completion: @escaping (String?) -> Void) {
        state = .generating
        logLines = ["Starting Claude Code..."]
        thumbnailPath = nil
        progress = 0.02
        statusText = "Starting Claude Code..."

        let projectName = slugify(prompt)
        let projectPath = (outputDir as NSString).appendingPathComponent(projectName)

        // Create project directory
        try? FileManager.default.createDirectory(atPath: projectPath, withIntermediateDirectories: true)

        let claudePath = findClaude()
        guard !claudePath.isEmpty else {
            DispatchQueue.main.async {
                self.state = .error(message: "Claude CLI not found. Install it: npm install -g @anthropic-ai/claude-code")
                self.logLines.append("ERROR: claude command not found")
            }
            completion(nil)
            return
        }

        let fullPrompt = """
        Create a HyperFrames video composition for: \(prompt)

        Use /hyperframes skill. Initialize with `npx hyperframes init \(projectName) --non-interactive --skip-skills` if needed, then build the composition HTML files. Make it visually polished with GSAP animations, good typography, and smooth transitions. Keep it under 60 seconds. Use dark premium palette with warm tones (sand, terra cotta accents). No purple. After creating files, run `npx hyperframes lint` to validate.
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: claudePath)
        proc.arguments = [
            "--print",
            "--dangerously-skip-permissions",
            fullPrompt
        ]
        proc.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        // Inherit user's shell environment
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = NSHomeDirectory()
        // Ensure node/npx are on PATH
        let extraPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(NSHomeDirectory())/.local/bin",
            "\(NSHomeDirectory())/.nvm/versions/node/v22.14.0/bin",
            "\(NSHomeDirectory())/.nvm/versions/node/v20.18.0/bin",
            "/usr/bin"
        ]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
        proc.environment = env

        let pipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = errPipe

        // Read stdout in background
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            let lines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
            DispatchQueue.main.async {
                self?.logLines.append(contentsOf: lines)
                for line in lines { self?.updateProgress(from: line) }
                // Keep last 200 lines
                if let count = self?.logLines.count, count > 200 {
                    self?.logLines = Array(self!.logLines.suffix(200))
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            let lines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
            DispatchQueue.main.async {
                self?.logLines.append(contentsOf: lines.map { "[stderr] \($0)" })
            }
        }

        proc.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                pipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil

                if process.terminationStatus == 0 {
                    self?.state = .snapshotting
                    self?.progress = 0.90
                    self?.statusText = "Capturing thumbnails..."
                    self?.logLines.append("Generation complete! Capturing thumbnails...")
                    self?.runSnapshot(projectPath: projectPath, env: env) {
                        self?.state = .success(path: projectPath)
                        completion(projectPath)
                    }
                } else {
                    self?.state = .error(message: "Claude exited with code \(process.terminationStatus)")
                    self?.logLines.append("ERROR: Process exited with code \(process.terminationStatus)")
                    completion(nil)
                }
            }
        }

        do {
            try proc.run()
            self.process = proc
            logLines.append("Claude Code is generating your video...")
        } catch {
            state = .error(message: "Failed to launch: \(error.localizedDescription)")
            logLines.append("ERROR: \(error.localizedDescription)")
            completion(nil)
        }
    }

    private func runSnapshot(projectPath: String, env: [String: String], completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let snapProc = Process()
            snapProc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            snapProc.arguments = ["-c", "cd '\(projectPath)' && npx hyperframes snapshot"]
            snapProc.environment = env

            let snapPipe = Pipe()
            let snapErrPipe = Pipe()
            snapProc.standardOutput = snapPipe
            snapProc.standardError = snapErrPipe

            snapPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                let lines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
                DispatchQueue.main.async {
                    self?.logLines.append(contentsOf: lines.map { "[snapshot] \($0)" })
                }
            }

            snapProc.terminationHandler = { [weak self] _ in
                DispatchQueue.main.async {
                    snapPipe.fileHandleForReading.readabilityHandler = nil
                    snapErrPipe.fileHandleForReading.readabilityHandler = nil

                    // Find first PNG in snapshots directory
                    let snapshotsDir = (projectPath as NSString).appendingPathComponent("snapshots")
                    if let files = try? FileManager.default.contentsOfDirectory(atPath: snapshotsDir) {
                        let pngs = files.filter { $0.hasSuffix(".png") }.sorted()
                        if let first = pngs.first {
                            self?.thumbnailPath = (snapshotsDir as NSString).appendingPathComponent(first)
                            self?.logLines.append("Thumbnail captured: \(first)")
                        }
                    }

                    if self?.thumbnailPath == nil {
                        self?.logLines.append("[snapshot] No thumbnails found")
                    }

                    completion()
                }
            }

            do {
                try snapProc.run()
                DispatchQueue.main.async {
                    self?.logLines.append("Running hyperframes snapshot...")
                }
            } catch {
                DispatchQueue.main.async {
                    self?.logLines.append("[snapshot] Failed to run: \(error.localizedDescription)")
                    completion()
                }
            }
        }
    }

    func cancel() {
        process?.terminate()
        process = nil
        state = .idle
        logLines.append("Cancelled.")
    }

    private func findClaude() -> String {
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // Try which
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = ["claude"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func slugify(_ s: String) -> String {
        let cleaned = s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(5)
            .joined(separator: "-")
        let timestamp = Int(Date().timeIntervalSince1970) % 100000
        return "\(cleaned)-\(timestamp)"
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var store = RecentProjectsStore()
    @StateObject private var runner = ClaudeRunner()
    @State private var appeared = false
    @State private var prompt = ""
    @State private var hoverProject: String? = nil
    @State private var showLog = false
    @State private var selectedTab = 0 // 0 = create, 1 = recent
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "VideoHubHQ_SeenOnboarding")
    @State private var onboardingOpacity: Double = 0
    @State private var showAdvanced = false
    @State private var videoLength = "30 seconds"
    @State private var videoGoal = "Marketing"
    @State private var videoStyle = "Dark Premium"
    @State private var advancedColorScheme = "Sand & Terra Cotta"
    @State private var animationSpeed = "Medium"
    @FocusState private var promptFocused: Bool

    private let lengthOptions = ["15 seconds", "30 seconds", "45 seconds", "60 seconds", "90 seconds"]
    private let goalOptions = ["Marketing", "Product Demo", "Social Media", "Explainer", "Announcement", "Tutorial", "Testimonial"]
    private let styleOptions = ["Dark Premium", "Clean Corporate", "Bold Energetic", "Warm Editorial", "Nature Earth", "Monochrome"]
    private let colorOptions = ["Sand & Terra Cotta", "Auto (from prompt)", "Warm Neutrals", "Cool Steel", "Forest & Gold", "Coral & Cream"]
    private let speedOptions = ["Slow", "Medium", "Fast", "Dynamic"]

    private var isGenerating: Bool { runner.state == .generating }

    private var advancedOptionsCount: Int {
        var count = 0
        if videoLength != "30 seconds" { count += 1 }
        if videoGoal != "Marketing" { count += 1 }
        if videoStyle != "Dark Premium" { count += 1 }
        if advancedColorScheme != "Sand & Terra Cotta" { count += 1 }
        if animationSpeed != "Medium" { count += 1 }
        return count
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag area
                HStack { Spacer() }
                    .frame(height: 28)

                // Header
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(.sand)
                            .rotationEffect(.degrees(appeared ? 0 : -10))
                            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.15), value: appeared)

                        Text("VideoHub HQ")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.warmWhite)
                    }
                    Text("AI Video Studio")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.dimText)
                        .tracking(1.5)
                        .textCase(.uppercase)
                }
                .padding(.top, 4)
                .padding(.bottom, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -12)
                .animation(.easeOut(duration: 0.4), value: appeared)

                // Tab switcher
                HStack(spacing: 0) {
                    TabButton(title: "Create", icon: "wand.and.stars", isSelected: selectedTab == 0) {
                        withAnimation(.easeOut(duration: 0.2)) { selectedTab = 0 }
                    }
                    TabButton(title: "Projects", icon: "film.stack", isSelected: selectedTab == 1) {
                        withAnimation(.easeOut(duration: 0.2)) { selectedTab = 1 }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.05), value: appeared)

                // Content
                if selectedTab == 0 {
                    createView
                } else {
                    projectsView
                }

                Spacer(minLength: 12)
            }

            // Onboarding overlay
            if showOnboarding {
                onboardingOverlay
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
            if showOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        onboardingOpacity = 1
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    promptFocused = true
                }
            }
        }
    }

    // MARK: - Onboarding Overlay

    private var onboardingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7 * onboardingOpacity)
                .ignoresSafeArea()
                .onTapGesture { dismissOnboarding() }

            VStack(spacing: 20) {
                // Title
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.sand)
                    Text("Welcome to VideoHub HQ")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.warmWhite)
                    Text("AI-powered video creation studio")
                        .font(.system(size: 13))
                        .foregroundColor(.dimText)
                }

                // Feature cards
                VStack(spacing: 8) {
                    // Prompt-to-video
                    featureRow(
                        icon: "wand.and.stars",
                        iconGradient: true,
                        title: "Prompt to Video",
                        desc: "Describe your video and Claude Code builds a full HyperFrames project with scenes, GSAP animations, and transitions."
                    )

                    // Advanced options
                    featureRow(
                        icon: "slider.horizontal.3",
                        iconGradient: false,
                        title: "Advanced Options",
                        desc: "Fine-tune duration, style, color palette, animation speed, and video goal for precise creative control."
                    )

                    // Live progress
                    featureRow(
                        icon: "chart.bar.fill",
                        iconGradient: false,
                        title: "Live Progress",
                        desc: "Watch real-time progress with a visual progress bar and streaming agent output as your video is built."
                    )

                    // Auto-thumbnails & preview
                    featureRow(
                        icon: "photo.on.rectangle.angled",
                        iconGradient: false,
                        title: "Thumbnails & Preview",
                        desc: "Auto-captures key frame thumbnails after generation. Preview in HyperFrames Studio with a dark-themed viewer."
                    )
                }

                // CLI skill tip
                HStack(spacing: 10) {
                    Image(systemName: "terminal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.terra)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Also works from the CLI")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.warmWhite)
                        Text("Install the VideoHub skill for Claude Code:")
                            .font(.system(size: 10))
                            .foregroundColor(.dimText)
                        Text("npx skills add gked2121/videohub-hq")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.sand)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.terra.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.terra.opacity(0.2), lineWidth: 0.5))

                // Dismiss button
                Button(action: dismissOnboarding) {
                    Text("Get Started")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.bg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            LinearGradient(colors: [.sand, .terra], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .frame(width: 420)
            .background(Color.bg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.borderColor, lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
            .scaleEffect(onboardingOpacity == 0 ? 0.92 : 1.0)
            .opacity(onboardingOpacity)
        }
    }

    private func dismissOnboarding() {
        withAnimation(.easeOut(duration: 0.25)) {
            onboardingOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showOnboarding = false
            UserDefaults.standard.set(true, forKey: "VideoHubHQ_SeenOnboarding")
            promptFocused = true
        }
    }

    private func featureRow(icon: String, iconGradient: Bool, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconGradient
                        ? AnyShapeStyle(LinearGradient(colors: [.sand.opacity(0.2), .terra.opacity(0.15)],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.cardHover))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.sand)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.warmWhite)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.dimText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 0.5))
    }

    // MARK: - Create Tab

    private var createView: some View {
        VStack(spacing: 16) {
            // Prompt input
            VStack(alignment: .leading, spacing: 8) {
                Text("Describe your video")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.dimText)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $prompt)
                        .font(.system(size: 14))
                        .foregroundColor(.warmWhite)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .focused($promptFocused)
                        .disabled(isGenerating)

                    if prompt.isEmpty {
                        Text("e.g. \"30-second LinkedIn video about AI agents for enterprise\"")
                            .font(.system(size: 14))
                            .foregroundColor(.dimText.opacity(0.5))
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 100)
                .background(Color.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(promptFocused ? Color.sand.opacity(0.4) : Color.borderColor, lineWidth: 1)
                )
            }
            .padding(.horizontal, 28)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

            // Advanced Options
            VStack(alignment: .leading, spacing: 0) {
                // Toggle button
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showAdvanced.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.dimText)
                            .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                            .animation(.easeOut(duration: 0.2), value: showAdvanced)
                        Text("Advanced Options")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.dimText)
                        if advancedOptionsCount > 0 {
                            Text("\(advancedOptionsCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.warmWhite)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.terra.opacity(0.5))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                if showAdvanced {
                    // Options grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], alignment: .leading, spacing: 12) {
                        // Duration
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DURATION")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.dimText)
                                .tracking(1.2)
                            Menu {
                                ForEach(lengthOptions, id: \.self) { opt in
                                    Button(opt) { videoLength = opt }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(videoLength)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.warmWhite)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.dimText)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 0.5))
                            }
                        }

                        // Goal
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GOAL")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.dimText)
                                .tracking(1.2)
                            Menu {
                                ForEach(goalOptions, id: \.self) { opt in
                                    Button(opt) { videoGoal = opt }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(videoGoal)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.warmWhite)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.dimText)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 0.5))
                            }
                        }

                        // Style
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STYLE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.dimText)
                                .tracking(1.2)
                            Menu {
                                ForEach(styleOptions, id: \.self) { opt in
                                    Button(opt) { videoStyle = opt }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(videoStyle)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.warmWhite)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.dimText)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 0.5))
                            }
                        }

                        // Colors
                        VStack(alignment: .leading, spacing: 4) {
                            Text("COLORS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.dimText)
                                .tracking(1.2)
                            Menu {
                                ForEach(colorOptions, id: \.self) { opt in
                                    Button(opt) { advancedColorScheme = opt }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(advancedColorScheme)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.warmWhite)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.dimText)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 0.5))
                            }
                        }

                        // Speed
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SPEED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.dimText)
                                .tracking(1.2)
                            Menu {
                                ForEach(speedOptions, id: \.self) { opt in
                                    Button(opt) { animationSpeed = opt }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(animationSpeed)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.warmWhite)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.dimText)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.borderColor, lineWidth: 0.5))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 0.5))
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 28)
            .disabled(isGenerating)

            // Generate button (hidden during generation)
            Group {
                if !isGenerating && runner.state != .snapshotting {
                    VStack(spacing: 4) {
                        Button(action: startGeneration) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Generate Video")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.bg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                LinearGradient(colors: [.sand, .terra], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        // Hidden button for Cmd+Enter shortcut
                        Button("") { startGeneration() }
                            .keyboardShortcut(.return, modifiers: .command)
                            .frame(width: 0, height: 0)
                            .opacity(0)

                        HStack {
                            Spacer()
                            Text("Cmd+Return to generate")
                                .font(.system(size: 10))
                                .foregroundColor(.dimText.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 28)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

            // Progress bar + terminal (visible during generation)
            if isGenerating || runner.state == .snapshotting {
                VStack(spacing: 10) {
                    // Progress bar
                    VStack(spacing: 6) {
                        HStack {
                            Text(runner.statusText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.warmWhite)
                            Spacer()
                            Text("\(Int(runner.progress * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.sand)

                            Button(action: { runner.cancel() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.dimText)
                            }
                            .buttonStyle(.plain)
                        }

                        // Bar track
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.inputBg)
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(colors: [.sand, .terra], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: max(0, geo.size.width * runner.progress), height: 6)
                                    .animation(.easeOut(duration: 0.3), value: runner.progress)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.horizontal, 28)

                    // Terminal output (always visible during generation)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.terra).frame(width: 6, height: 6)
                            Text("AGENT OUTPUT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.dimText)
                                .tracking(1.2)
                            Spacer()
                            Text("\(runner.logLines.count) lines")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.dimText.opacity(0.6))
                        }
                        .padding(.horizontal, 4)

                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 1) {
                                    ForEach(Array(runner.logLines.enumerated()), id: \.offset) { i, line in
                                        Text(line)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(
                                                line.contains("ERROR") ? .errorRed :
                                                line.contains("complete") || line.contains("success") ? .successGreen :
                                                line.contains("[snapshot]") ? .sand :
                                                line.hasPrefix("[stderr]") ? .dimText.opacity(0.6) :
                                                .dimText
                                            )
                                            .textSelection(.enabled)
                                            .id(i)
                                    }
                                }
                                .padding(10)
                            }
                            .frame(maxHeight: 180)
                            .background(Color(red: 0.06, green: 0.06, blue: 0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 0.5))
                            .onChange(of: runner.logLines.count) { _ in
                                withAnimation {
                                    proxy.scrollTo(runner.logLines.count - 1, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Status / result (when not generating)
            if !isGenerating && runner.state != .snapshotting {
                statusView
                    .padding(.horizontal, 28)

                // Collapsed log for reviewing after completion
                if !runner.logLines.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: { withAnimation(.easeOut(duration: 0.2)) { showLog.toggle() } }) {
                            HStack(spacing: 6) {
                                Image(systemName: showLog ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                Text("OUTPUT")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.2)
                                Spacer()
                                Text("\(runner.logLines.count) lines")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.dimText)
                        }
                        .buttonStyle(.plain)

                        if showLog {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 1) {
                                        ForEach(Array(runner.logLines.enumerated()), id: \.offset) { i, line in
                                            Text(line)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(
                                                    line.contains("ERROR") ? .errorRed :
                                                    line.contains("complete") ? .successGreen :
                                                    .dimText
                                                )
                                                .id(i)
                                        }
                                    }
                                    .padding(10)
                                }
                                .frame(maxHeight: 150)
                                .background(Color.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 0.5))
                                .onChange(of: runner.logLines.count) { _ in
                                    withAnimation {
                                        proxy.scrollTo(runner.logLines.count - 1, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch runner.state {
        case .idle:
            EmptyView()
        case .generating:
            EmptyView()
        case .snapshotting:
            HStack(spacing: 10) {
                PulsingDots(color: .sand)
                Text("Capturing thumbnails...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.dimText)
                Spacer()
            }
            .padding(12)
            .background(Color.sand.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sand.opacity(0.15), lineWidth: 0.5))
            .transition(.opacity)
        case .success(let path):
            VStack(spacing: 10) {
                // Thumbnail row (if captured)
                if let thumbPath = runner.thumbnailPath,
                   let nsImage = NSImage(contentsOfFile: thumbPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor.opacity(0.4), lineWidth: 0.5))
                }

                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.successGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Video project created")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.warmWhite)
                        Text((path as NSString).lastPathComponent)
                            .font(.system(size: 11))
                            .foregroundColor(.dimText)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                // Action buttons
                HStack(spacing: 6) {
                    Button(action: { launchPreview(path: path) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("Preview")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.sand)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button(action: { captureThumnails(path: path) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 10))
                            Text("Thumbnails")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.warmWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)

                    Button(action: { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path) }) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundColor(.dimText)
                            .frame(width: 34, height: 34)
                            .background(Color.cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderColor, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color.successGreen.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.successGreen.opacity(0.2), lineWidth: 0.5))
            .transition(.opacity.combined(with: .move(edge: .top)))

        case .error(let message):
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.errorRed)
                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.errorRed)
                        .lineLimit(3)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Button(action: { startGeneration() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                            Text("Retry")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.bg)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.errorRed)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message, forType: .string)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10, weight: .medium))
                            Text("Copy Error")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.warmWhite)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.borderColor, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)

                    Button(action: { showLog = true }) {
                        HStack(spacing: 5) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 10, weight: .medium))
                            Text("View Log")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.dimText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.borderColor, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(12)
            .background(Color.errorRed.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.errorRed.opacity(0.2), lineWidth: 0.5))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Projects Tab

    private var projectsView: some View {
        VStack(spacing: 12) {
            // Open folder button
            Button(action: openFolder) {
                HStack(spacing: 10) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                    Text("Open Existing Project")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.warmWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)

            if !store.projects.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RECENT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.dimText)
                            .tracking(1.5)
                            .padding(.leading, 4)

                        VStack(spacing: 4) {
                            ForEach(Array(store.projects.enumerated()), id: \.element.id) { index, project in
                                ProjectRow(
                                    project: project,
                                    isHovered: hoverProject == project.path,
                                    onOpen: { launchPreview(path: project.path) },
                                    onRemove: { withAnimation(.easeOut(duration: 0.2)) { store.remove(project) } }
                                )
                                .onHover { hovering in
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        hoverProject = hovering ? project.path : nil
                                    }
                                }
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 10)
                                .animation(.easeOut(duration: 0.35).delay(0.05 + Double(index) * 0.03), value: appeared)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 28))
                        .foregroundColor(.dimText.opacity(0.5))
                    Text("No recent projects")
                        .font(.system(size: 13))
                        .foregroundColor(.dimText)
                }
                Spacer()
            }
        }
    }

    // MARK: - Actions

    private func startGeneration() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        showLog = true
        let outputDir = (NSHomeDirectory() as NSString).appendingPathComponent("Desktop/videohub-projects")
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        var fullPrompt = trimmed
        if showAdvanced {
            fullPrompt += "\n\nVideo specifications:"
            fullPrompt += "\n- Duration: \(videoLength)"
            fullPrompt += "\n- Goal: \(videoGoal)"
            fullPrompt += "\n- Visual style: \(videoStyle)"
            if advancedColorScheme != "Auto (from prompt)" {
                fullPrompt += "\n- Color palette: \(advancedColorScheme)"
            }
            fullPrompt += "\n- Animation speed: \(animationSpeed)"
        }
        runner.generate(prompt: fullPrompt, outputDir: outputDir) { path in
            if let path = path {
                store.add(path: path, prompt: trimmed)
            }
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Preview"
        panel.message = "Select a HyperFrames project folder"

        if panel.runModal() == .OK, let url = panel.url {
            store.add(path: url.path, prompt: "")
            launchPreview(path: url.path)
        }
    }

    private func captureThumnails(path: String) {
        runner.logLines.append("Capturing thumbnails...")
        runner.thumbnailPath = nil

        DispatchQueue.global().async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-c", "cd '\(path)' && npx hyperframes snapshot"]
            var env = ProcessInfo.processInfo.environment
            let extraPaths = ["/opt/homebrew/bin", "\(NSHomeDirectory())/.local/bin", "/usr/local/bin", "/usr/bin"]
            env["PATH"] = (extraPaths + [env["PATH"] ?? ""]).joined(separator: ":")
            proc.environment = env

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            try? proc.run()
            proc.waitUntilExit()

            // Find first snapshot PNG
            let snapshotsDir = (path as NSString).appendingPathComponent("snapshots")
            if let files = try? FileManager.default.contentsOfDirectory(atPath: snapshotsDir) {
                let pngs = files.filter { $0.hasSuffix(".png") }.sorted()
                if let first = pngs.first {
                    let thumbPath = (snapshotsDir as NSString).appendingPathComponent(first)
                    DispatchQueue.main.async {
                        self.runner.thumbnailPath = thumbPath
                        self.runner.logLines.append("Captured \(pngs.count) thumbnails")
                        // Regenerate preview page with thumbnails
                        self.generatePreviewPage(projectPath: path)
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                self.runner.logLines.append("No thumbnails captured - check if project has compositions")
            }
        }
    }

    private func launchPreview(path: String) {
        // Generate a preview landing page with thumbnails
        generatePreviewPage(projectPath: path)

        let script = "cd \(shellQuote(path)) && npx hyperframes preview"
        DispatchQueue.global().async {
            let appleScript = """
            tell application "Terminal"
                activate
                do script "\(script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))"
            end tell
            """
            if let scriptObj = NSAppleScript(source: appleScript) {
                var error: NSDictionary?
                scriptObj.executeAndReturnError(&error)
            }
        }

        // Open the landing page in the browser
        let landingPath = (path as NSString).appendingPathComponent("_preview.html")
        if FileManager.default.fileExists(atPath: landingPath) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSWorkspace.shared.open(URL(fileURLWithPath: landingPath))
            }
        }
    }

    private func generatePreviewPage(projectPath: String) {
        let projectName = (projectPath as NSString).lastPathComponent
        let snapshotsDir = (projectPath as NSString).appendingPathComponent("snapshots")

        // Find all snapshot PNGs
        var thumbnails: [String] = []
        if let files = try? FileManager.default.contentsOfDirectory(atPath: snapshotsDir) {
            thumbnails = files.filter { $0.hasSuffix(".png") }.sorted()
        }

        let thumbnailHTML: String
        if thumbnails.isEmpty {
            thumbnailHTML = """
            <div style="text-align:center;padding:24px 0;color:#8C8A82;">
                <p style="font-size:13px;">No thumbnails yet. Generating after preview starts...</p>
            </div>
            """
        } else {
            let imgs = thumbnails.map { name in
                let relativePath = "snapshots/\(name)"
                return """
                <div class="thumb" onclick="this.classList.toggle('selected')">
                    <img src="\(relativePath)" alt="\(name)" />
                    <span>\(name.replacingOccurrences(of: ".png", with: ""))</span>
                </div>
                """
            }.joined(separator: "\n")

            thumbnailHTML = imgs
        }

        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(projectName) -- VideoHub HQ</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    background: #141412;
                    color: #EDE8DE;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                    height: 100vh;
                    overflow: hidden;
                    display: flex;
                    flex-direction: column;
                }
                /* Top bar */
                .topbar {
                    height: 48px; min-height: 48px;
                    background: #1A1918;
                    border-bottom: 1px solid #2A2824;
                    display: flex; align-items: center;
                    padding: 0 20px; gap: 12px;
                }
                .topbar-icon {
                    width: 28px; height: 28px;
                    background: linear-gradient(135deg, #D9BF94, #C7804E);
                    border-radius: 6px;
                    display: flex; align-items: center; justify-content: center;
                }
                .topbar-icon svg { width: 14px; height: 14px; fill: #141412; }
                .topbar h1 { font-size: 14px; font-weight: 600; }
                .topbar .sep { color: #33312C; font-weight: 300; }
                .topbar .project-name { color: #D9BF94; font-size: 13px; font-weight: 500; }
                .topbar-right { margin-left: auto; display: flex; gap: 8px; align-items: center; }
                .topbar-btn {
                    font-size: 11px; font-weight: 600; padding: 6px 14px;
                    border-radius: 6px; border: none; cursor: pointer;
                    text-decoration: none; display: inline-flex; align-items: center; gap: 5px;
                    transition: all 0.15s ease;
                }
                .btn-primary {
                    background: linear-gradient(90deg, #D9BF94, #C7804E);
                    color: #141412;
                }
                .btn-primary:hover { opacity: 0.9; }
                .btn-secondary {
                    background: #252420; color: #8C8A82;
                    border: 1px solid #33312C;
                }
                .btn-secondary:hover { border-color: #D9BF94; color: #EDE8DE; }
                /* Main layout */
                .main {
                    flex: 1; display: flex; overflow: hidden;
                }
                /* Studio iframe */
                .studio-pane {
                    flex: 1; position: relative;
                    border-right: 1px solid #2A2824;
                }
                .studio-pane iframe {
                    width: 100%; height: 100%; border: none;
                }
                .studio-loading {
                    position: absolute; inset: 0;
                    display: flex; flex-direction: column;
                    align-items: center; justify-content: center;
                    background: #141412; gap: 12px;
                    transition: opacity 0.4s ease;
                }
                .studio-loading.hidden { opacity: 0; pointer-events: none; }
                .dots { display: flex; gap: 6px; }
                .dots span {
                    width: 8px; height: 8px; border-radius: 50%;
                    background: #D9BF94;
                    animation: pulse 1s ease-in-out infinite;
                }
                .dots span:nth-child(2) { animation-delay: 0.15s; }
                .dots span:nth-child(3) { animation-delay: 0.3s; }
                @keyframes pulse {
                    0%, 100% { opacity: 0.3; transform: scale(0.8); }
                    50% { opacity: 1; transform: scale(1); }
                }
                /* Sidebar */
                .sidebar {
                    width: 220px; min-width: 220px;
                    background: #1A1918;
                    display: flex; flex-direction: column;
                    overflow: hidden;
                }
                .sidebar-header {
                    padding: 14px 16px 10px;
                    font-size: 10px; font-weight: 700; color: #8C8A82;
                    text-transform: uppercase; letter-spacing: 1.5px;
                    border-bottom: 1px solid #2A2824;
                }
                .sidebar-scroll {
                    flex: 1; overflow-y: auto; padding: 8px;
                    display: flex; flex-direction: column; gap: 6px;
                }
                .thumb {
                    border-radius: 6px; overflow: hidden;
                    border: 1px solid #2A2824; cursor: pointer;
                    transition: border-color 0.15s ease;
                    background: #1F1E1A;
                }
                .thumb:hover { border-color: #D9BF94; }
                .thumb.selected { border-color: #C7804E; border-width: 2px; }
                .thumb img {
                    display: block; width: 100%; height: auto;
                }
                .thumb span {
                    display: block; padding: 5px 8px;
                    font-size: 10px; color: #8C8A82;
                    white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
                }
                /* Path bar */
                .pathbar {
                    height: 28px; min-height: 28px;
                    background: #1A1918;
                    border-top: 1px solid #2A2824;
                    display: flex; align-items: center;
                    padding: 0 16px;
                    font-size: 11px; color: #5A5850;
                }
                .pathbar span { color: #8C8A82; }
                /* Animations */
                .fade-in { animation: fadeIn 0.4s ease forwards; opacity: 0; }
                @keyframes fadeIn { to { opacity: 1; } }
            </style>
        </head>
        <body>
            <div class="topbar fade-in">
                <div class="topbar-icon">
                    <svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
                </div>
                <h1>VideoHub HQ</h1>
                <span class="sep">/</span>
                <span class="project-name">\(projectName)</span>
                <div class="topbar-right">
                    <a class="topbar-btn btn-secondary" href="http://localhost:3002" target="_blank">
                        Open Studio Fullscreen
                    </a>
                </div>
            </div>
            <div class="main">
                <div class="studio-pane">
                    <div class="studio-loading" id="studioLoader">
                        <div class="dots"><span></span><span></span><span></span></div>
                        <div style="font-size:13px;color:#8C8A82;">Connecting to HyperFrames Studio...</div>
                    </div>
                    <iframe id="studioFrame" src="about:blank"></iframe>
                </div>
                <div class="sidebar">
                    <div class="sidebar-header">Key Frames</div>
                    <div class="sidebar-scroll">
                        \(thumbnailHTML)
                    </div>
                </div>
            </div>
            <div class="pathbar fade-in">
                <span>\(projectPath)</span>
            </div>
            <script>
                const iframe = document.getElementById('studioFrame');
                const loader = document.getElementById('studioLoader');
                const studioUrl = 'http://localhost:3002';
                let attempts = 0;
                function tryConnect() {
                    fetch(studioUrl, { mode: 'no-cors' })
                        .then(() => {
                            iframe.src = studioUrl;
                            iframe.onload = () => {
                                loader.classList.add('hidden');
                                // Auto-play: wait for the Studio's player to initialize, then send play
                                setTimeout(() => autoPlay(), 2000);
                            };
                        })
                        .catch(() => {
                            attempts++;
                            if (attempts < 30) setTimeout(tryConnect, 1000);
                            else loader.innerHTML = '<div style="color:#8C8A82;font-size:13px;">Studio not responding. <a href="' + studioUrl + '" target="_blank" style="color:#D9BF94;">Open directly</a></div>';
                        });
                }
                function autoPlay() {
                    try {
                        // Find the hyperframes-player inside the Studio and click play
                        const studioDoc = iframe.contentDocument || iframe.contentWindow.document;
                        const player = studioDoc.querySelector('hyperframes-player');
                        if (player && player.iframeElement) {
                            // Send play command via postMessage to the composition runtime
                            player.iframeElement.contentWindow.postMessage(
                                { source: 'hf-parent', type: 'control', action: 'play' }, '*'
                            );
                        } else {
                            // Fallback: broadcast play to all nested iframes
                            iframe.contentWindow.postMessage(
                                { source: 'hf-parent', type: 'control', action: 'play' }, '*'
                            );
                        }
                    } catch(e) {
                        // Cross-origin fallback: just postMessage into the studio iframe
                        iframe.contentWindow.postMessage(
                            { source: 'hf-parent', type: 'control', action: 'play' }, '*'
                        );
                    }
                }
                tryConnect();
            </script>
        </body>
        </html>
        """

        let outputPath = (projectPath as NSString).appendingPathComponent("_preview.html")
        try? html.write(toFile: outputPath, atomically: true, encoding: .utf8)
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(isSelected ? .warmWhite : .dimText)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(isSelected ? Color.cardBg : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.borderColor : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pulsing Dots Animation

struct PulsingDots: View {
    let color: Color
    @State private var dotPulse = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .scaleEffect(dotPulse ? 1.0 : 0.6)
                    .opacity(dotPulse ? 1.0 : 0.4)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: dotPulse
                    )
            }
        }
        .onAppear {
            dotPulse = true
        }
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: RecentProject
    let isHovered: Bool
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.cardBg)
                    .frame(width: 34, height: 34)
                Image(systemName: "film")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.sand)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.warmWhite)
                    .lineLimit(1)
                Text(project.prompt.isEmpty ? shortPath(project.path) : project.prompt)
                    .font(.system(size: 11))
                    .foregroundColor(.dimText)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.dimText)
                            .frame(width: 24, height: 24)
                            .background(Color.bg.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button(action: onOpen) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.bg)
                            .frame(width: 24, height: 24)
                            .background(Color.sand)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.cardHover : Color.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.borderColor, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpen() }
    }

    private func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
