/**
 * @file MetalQuakeLauncher.swift
 * @brief Metal Quake — SwiftUI Launcher with Liquid Glass Design
 *
 * Native Tahoe (macOS 26) launcher overlay for the Quake engine.
 * Features server browser, settings panel, and map gallery with
 * Liquid Glass materials and depth-aware animations.
 *
 * Embedded in the NSWindow via NSHostingView when the user presses Escape.
 */

import SwiftUI
import AppKit

// MARK: - C Bridge

/// Persistent settings store — singleton so values survive panel close/reopen
@available(macOS 26.0, *)
class MQSettingsStore: ObservableObject {
    static let shared = MQSettingsStore()
    
    @AppStorage("mq_rtEnabled") var rtEnabled: Bool = true
    @AppStorage("mq_rtQuality") var rtQuality: Int = 2
    @AppStorage("mq_metalfxMode") var metalfxMode: Int = 1
    @AppStorage("mq_metalfxScale") var metalfxScale: Double = 2.0
    @AppStorage("mq_neuralDenoise") var neuralDenoise: Bool = false
    @AppStorage("mq_meshShaders") var meshShaders: Bool = false
    @AppStorage("mq_liquidGlassUI") var liquidGlassUI: Bool = true
    
    @AppStorage("mq_audioMode") var audioMode: Int = 0
    @AppStorage("mq_spatialAudio") var spatialAudio: Bool = false
    @AppStorage("mq_masterVolume") var masterVolume: Double = 0.7
    
    @AppStorage("mq_mouseSensitivity") var mouseSensitivity: Double = 3.0
    @AppStorage("mq_autoAim") var autoAim: Bool = true
    @AppStorage("mq_invertY") var invertY: Bool = false
    @AppStorage("mq_rawMouse") var rawMouse: Bool = true
    @AppStorage("mq_controllerDeadzone") var controllerDeadzone: Double = 0.15
    
    @AppStorage("mq_coremlTextures") var coremlTextures: Bool = false
    @AppStorage("mq_neuralBots") var neuralBots: Bool = false
    
    @AppStorage("mq_soundSpatializer") var soundSpatializer: Bool = false
    @AppStorage("mq_highContrastHUD") var highContrastHUD: Bool = false
    @AppStorage("mq_subtitles") var subtitles: Bool = false
}

// MARK: - Map Model

struct QuakeMap: Identifiable, Hashable {
    let id: String
    let name: String
    let episode: String
    let description: String
    
    static let episodes: [(name: String, maps: [QuakeMap])] = [
        ("Episode 1: Dimension of the Doomed", [
            QuakeMap(id: "e1m1", name: "The Slipgate Complex", episode: "E1", description: "Welcome to Quake"),
            QuakeMap(id: "e1m2", name: "Castle of the Damned", episode: "E1", description: "Medieval fortress"),
            QuakeMap(id: "e1m3", name: "The Necropolis", episode: "E1", description: "City of the dead"),
            QuakeMap(id: "e1m4", name: "The Grisly Grotto", episode: "E1", description: "Underground caverns"),
            QuakeMap(id: "e1m5", name: "Gloom Keep", episode: "E1", description: "Dark castle keep"),
            QuakeMap(id: "e1m6", name: "The Door to Chthon", episode: "E1", description: "Ancient gateway"),
            QuakeMap(id: "e1m7", name: "The House of Chthon", episode: "E1", description: "Boss arena"),
        ]),
        ("Episode 2: The Realm of Black Magic", [
            QuakeMap(id: "e2m1", name: "The Installation", episode: "E2", description: "Military complex"),
            QuakeMap(id: "e2m2", name: "The Ogre Citadel", episode: "E2", description: "Ogre stronghold"),
            QuakeMap(id: "e2m3", name: "The Crypt of Decay", episode: "E2", description: "Rotting crypts"),
            QuakeMap(id: "e2m4", name: "The Ebon Fortress", episode: "E2", description: "Dark fortress"),
            QuakeMap(id: "e2m5", name: "The Wizard's Manse", episode: "E2", description: "Arcane mansion"),
            QuakeMap(id: "e2m6", name: "The Dismal Oubliette", episode: "E2", description: "Prison depths"),
        ]),
        ("Episode 3: The Netherworld", [
            QuakeMap(id: "e3m1", name: "Termination Central", episode: "E3", description: "Processing center"),
            QuakeMap(id: "e3m2", name: "The Vaults of Zin", episode: "E3", description: "Hidden vaults"),
            QuakeMap(id: "e3m3", name: "The Tomb of Terror", episode: "E3", description: "Ancient tomb"),
            QuakeMap(id: "e3m4", name: "Satan's Dark Delight", episode: "E3", description: "Hellish realm"),
            QuakeMap(id: "e3m5", name: "Wind Tunnels", episode: "E3", description: "Vertical maze"),
            QuakeMap(id: "e3m6", name: "Chambers of Torment", episode: "E3", description: "Pain chambers"),
        ]),
        ("Episode 4: The Elder World", [
            QuakeMap(id: "e4m1", name: "The Sewage System", episode: "E4", description: "Underground sewers"),
            QuakeMap(id: "e4m2", name: "The Tower of Despair", episode: "E4", description: "Towering fortress"),
            QuakeMap(id: "e4m3", name: "The Elder God Shrine", episode: "E4", description: "Sacred shrine"),
            QuakeMap(id: "e4m4", name: "The Palace of Hate", episode: "E4", description: "Hateful palace"),
            QuakeMap(id: "e4m5", name: "Hell's Atrium", episode: "E4", description: "Grand atrium"),
            QuakeMap(id: "e4m6", name: "The Pain Maze", episode: "E4", description: "Labyrinth of pain"),
            QuakeMap(id: "e4m7", name: "Azure Agony", episode: "E4", description: "Blue torment"),
        ]),
        ("Deathmatch Arenas", [
            QuakeMap(id: "dm1", name: "Place of Two Deaths", episode: "DM", description: "Classic arena"),
            QuakeMap(id: "dm2", name: "Claustrophobopolis", episode: "DM", description: "Tight corridors"),
            QuakeMap(id: "dm3", name: "The Abandoned Base", episode: "DM", description: "Military base"),
            QuakeMap(id: "dm4", name: "The Bad Place", episode: "DM", description: "Vertical arena"),
            QuakeMap(id: "dm5", name: "The Cistern", episode: "DM", description: "Water hazard"),
            QuakeMap(id: "dm6", name: "The Dark Zone", episode: "DM", description: "Dark corridors"),
        ]),
    ]
}

// MARK: - Launcher View

@available(macOS 26.0, *)
struct MetalQuakeLauncherView: View {
    @State private var selectedTab = 0
    @State private var selectedMap: QuakeMap? = nil
    @ObservedObject private var settings = MQSettingsStore.shared
    @State private var showingMapDetail = false
    @State private var animateIn = false
    
    var body: some View {
        ZStack {
            // Frosted glass background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Title bar with Metal Quake branding
                headerView
                
                // Tab bar
                tabBar
                
                // Content area
                tabContent
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .opacity(animateIn ? 1 : 0)
        .scaleEffect(animateIn ? 1.0 : 0.95)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }
    
    // MARK: - Header
    
    var headerView: some View {
        HStack(spacing: 16) {
            // Quake logo / title
            VStack(alignment: .leading, spacing: 2) {
                Text("METAL_QUAKE")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Apple Silicon Native • Metal 4 • macOS Tahoe")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicators
            HStack(spacing: 12) {
                StatusPill(label: "12 P-Cores", icon: "cpu", color: .green)
                StatusPill(label: "RT Active", icon: "rays", color: .orange)
                StatusPill(label: "MetalFX 2×", icon: "arrow.up.right.and.arrow.down.left.rectangle.fill", color: .blue)
            }
            // Resume button
            Button(action: resumeGame) {
                Label("Resume", systemImage: "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Tab Bar
    
    var tabBar: some View {
        HStack(spacing: 0) {
            TabButton(title: "Maps", icon: "map.fill", isSelected: selectedTab == 0) { selectedTab = 0 }
            TabButton(title: "Settings", icon: "gearshape.fill", isSelected: selectedTab == 1) { selectedTab = 1 }
            TabButton(title: "Multiplayer", icon: "person.2.fill", isSelected: selectedTab == 2) { selectedTab = 2 }
            TabButton(title: "About", icon: "info.circle.fill", isSelected: selectedTab == 3) { selectedTab = 3 }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(.bar)
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    var tabContent: some View {
        switch selectedTab {
        case 0: mapGalleryView
        case 1: settingsView
        case 2: multiplayerView
        case 3: aboutView
        default: EmptyView()
        }
    }
    
    // MARK: - Map Gallery
    
    var mapGalleryView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(Array(QuakeMap.episodes.enumerated()), id: \.offset) { idx, episode in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(episode.name)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(.leading, 4)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                        ], spacing: 12) {
                            ForEach(episode.maps) { map in
                                MapCard(map: map, isSelected: selectedMap == map) {
                                    selectedMap = map
                                } onDoubleTap: {
                                    launchMap(map)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    if idx < QuakeMap.episodes.count - 1 {
                        Divider()
                            .padding(.horizontal, 24)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .overlay(alignment: .bottom) {
            if let map = selectedMap {
                // Bottom action bar
                HStack {
                    VStack(alignment: .leading) {
                        Text(map.name)
                            .font(.headline)
                        Text(map.id.uppercased())
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { launchMap(map) }) {
                        Label("Launch", systemImage: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding(16)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: selectedMap)
    }
    
    // MARK: - Settings
    
    var settingsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Rendering
                SettingsSection(title: "Rendering", icon: "rays") {
                    SettingsToggle(title: "Ray Tracing", subtitle: "Hardware RTGI + shadows", isOn: $settings.rtEnabled)
                    SettingsPicker(title: "RT Quality", selection: $settings.rtQuality,
                                   options: ["Off", "Low", "Medium", "High", "Ultra"])
                    SettingsPicker(title: "MetalFX", selection: $settings.metalfxMode,
                                   options: ["Off", "Spatial", "Temporal"])
                    SettingsSlider(title: "MetalFX Scale", value: $settings.metalfxScale, range: 1.0...4.0)
                    SettingsToggle(title: "Neural Denoise", subtitle: "ANE-accelerated (M3+)", isOn: $settings.neuralDenoise)
                    SettingsToggle(title: "Mesh Shaders", subtitle: "Movie-quality geometry (M3+)", isOn: $settings.meshShaders)
                }
                
                // Audio
                SettingsSection(title: "Audio", icon: "speaker.wave.3.fill") {
                    SettingsPicker(title: "Audio Engine", selection: $settings.audioMode,
                                   options: ["Core Audio", "PHASE Spatial"])
                    SettingsToggle(title: "Spatial Audio", subtitle: "Personalized HRTF", isOn: $settings.spatialAudio)
                    SettingsSlider(title: "Master Volume", value: $settings.masterVolume, range: 0...1)
                }
                
                // Input
                SettingsSection(title: "Input", icon: "gamecontroller.fill") {
                    SettingsSlider(title: "Mouse Sensitivity", value: $settings.mouseSensitivity, range: 1...20)
                    SettingsToggle(title: "Auto-Aim", subtitle: "Vertical auto-aim assist", isOn: $settings.autoAim)
                    SettingsToggle(title: "Invert Y Axis", subtitle: "Inverted vertical look", isOn: $settings.invertY)
                    SettingsToggle(title: "Raw Mouse Input", subtitle: "CGEvent delta (recommended)", isOn: $settings.rawMouse)
                    SettingsSlider(title: "Controller Deadzone", value: $settings.controllerDeadzone, range: 0...0.5)
                }
                
                // Intelligence
                SettingsSection(title: "Intelligence", icon: "brain.fill") {
                    SettingsToggle(title: "CoreML Textures", subtitle: "Real-ESRGAN upscaling (stretch goal)", isOn: $settings.coremlTextures)
                    SettingsToggle(title: "Neural Bots", subtitle: "ANE-powered bot AI (stretch goal)", isOn: $settings.neuralBots)
                }
                
                // Accessibility
                SettingsSection(title: "Accessibility", icon: "accessibility") {
                    SettingsToggle(title: "Sound Spatializer", subtitle: "Visual sound direction overlay", isOn: $settings.soundSpatializer)
                    SettingsToggle(title: "High Contrast HUD", subtitle: "Enhanced visibility", isOn: $settings.highContrastHUD)
                    SettingsToggle(title: "Subtitles", subtitle: "Event text descriptions", isOn: $settings.subtitles)
                }
            }
            .padding(24)
            
            // Apply + Resume buttons
            HStack(spacing: 16) {
                Spacer()
                Button(action: resumeGame) {
                    Label("Cancel", systemImage: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                
                Button(action: applyAndResume) {
                    Label("Apply & Resume", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Multiplayer
    
    var multiplayerView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Network.framework UDP")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
            Text("LAN discovery and server browser coming in Phase 3")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - About
    
    var aboutView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("METAL_QUAKE")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 40)
                
                Text("Apple Silicon Native Quake Engine")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Divider().padding(.horizontal, 100)
                
                VStack(alignment: .leading, spacing: 12) {
                    AboutRow(label: "Pipeline", value: "Metal 4 + Hardware Ray Tracing")
                    AboutRow(label: "Threading", value: "GCD dispatch_apply (12 P-cores)")
                    AboutRow(label: "Upscaling", value: "MetalFX Spatial Scaler 2×")
                    AboutRow(label: "Input", value: "GameController.framework + Adaptive Triggers")
                    AboutRow(label: "Audio", value: "Core Audio (PHASE scaffolded)")
                    AboutRow(label: "UI", value: "SwiftUI + Liquid Glass")
                    AboutRow(label: "Platform", value: "Apple Silicon Native")
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 60)
                
                Text("© 2026 Metal Quake Team • Original engine by id Software")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Actions
    
    func launchMap(_ map: QuakeMap) {
        MQBridge_StartMap(map.id)
    }
    
    func resumeGame() {
        MQBridge_SetLauncherVisible(0)
    }
    
    func applyAndResume() {
        // Sync all settings from UserDefaults → MetalQuakeSettings → engine cvars
        MQBridge_SyncSettings()
        MQBridge_SetLauncherVisible(0)
    }
}

// MARK: - Supporting Views

struct StatusPill: View {
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .orange : .secondary)
            .background(isSelected ? Color.orange.opacity(0.1) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct MapCard: View {
    let map: QuakeMap
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Map thumbnail placeholder with gradient
            ZStack {
                LinearGradient(
                    colors: episodeColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Text(map.id.uppercased())
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(map.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            
            Text(map.description)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .background(isSelected ? Color.orange.opacity(0.15) : (isHovering ? Color.primary.opacity(0.05) : .clear))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.orange : .clear, lineWidth: 2)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.2), value: isHovering)
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { onDoubleTap() }
        .onTapGesture { onTap() }
    }
    
    var episodeColors: [Color] {
        switch map.episode {
        case "E1": return [.brown, .orange]
        case "E2": return [.purple, .blue]
        case "E3": return [.red, .orange]
        case "E4": return [.indigo, .purple]
        case "DM": return [.green, .teal]
        default: return [.gray, .secondary]
        }
    }
}

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
            }
            .padding(.bottom, 4)
            
            content()
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
        .toggleStyle(.switch)
    }
}

struct SettingsPicker: View {
    let title: String
    @Binding var selection: Int
    let options: [String]
    
    var body: some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .medium))
            Spacer()
            Picker("", selection: $selection) {
                ForEach(0..<options.count, id: \.self) { i in
                    Text(options[i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 250)
        }
    }
}

struct SettingsSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .medium))
            Spacer()
            Slider(value: $value, in: range)
            .frame(maxWidth: 200)
            Text(String(format: "%.1f", value))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

struct AboutRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
        }
    }
}

// MARK: - NSVisualEffectView Bridge

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Hosting Controller (NSPanel child window approach)

@available(macOS 26.0, *)
@objc public class MetalQuakeLauncherController: NSObject {
    
    private var panel: NSPanel?
    
    @objc public static let shared = MetalQuakeLauncherController()
    
    @objc public func show(in window: NSWindow) {
        // Remove existing panel if any
        if let existing = panel {
            window.removeChildWindow(existing)
            existing.orderOut(nil)
            panel = nil
        }
        
        // Use the game window's screen frame for positioning
        let windowFrame = window.frame
        // Inset slightly for a nice overlay effect
        let inset: CGFloat = 40
        let panelFrame = NSRect(
            x: windowFrame.origin.x + inset,
            y: windowFrame.origin.y + inset,
            width: windowFrame.width - inset * 2,
            height: windowFrame.height - inset * 2
        )
        
        // Create a titled, closable, resizable panel
        let overlay = NSPanel(
            contentRect: panelFrame,
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        overlay.title = "Metal Quake Launcher"
        overlay.isFloatingPanel = true
        overlay.level = .floating
        overlay.isOpaque = false
        overlay.backgroundColor = NSColor(white: 0.1, alpha: 0.95)
        overlay.hasShadow = true
        overlay.acceptsMouseMovedEvents = true
        overlay.isMovableByWindowBackground = true
        
        // Create SwiftUI hosting view
        let hostingView = NSHostingView(rootView: MetalQuakeLauncherView())
        hostingView.frame = overlay.contentView?.bounds ?? panelFrame
        hostingView.autoresizingMask = [.width, .height]
        overlay.contentView = hostingView
        
        // Show as child window above the game
        window.addChildWindow(overlay, ordered: .above)
        overlay.makeKeyAndOrderFront(nil)
        
        panel = overlay
    }
    
    @objc public func hide() {
        if let overlay = panel, let parent = overlay.parent {
            parent.removeChildWindow(overlay)
            overlay.orderOut(nil)
            parent.makeKeyAndOrderFront(nil)
        }
        panel = nil
    }
    
    @objc public var isVisible: Bool {
        return panel != nil
    }
}
