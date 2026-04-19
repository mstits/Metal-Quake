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
import GroupActivities

// MARK: - SharePlay Group Activity

// Declares a joinable Quake session as a GroupActivity. FaceTime picks
// this up when the user starts a share and any of their call
// participants can click "Join" to land in the same server. The C side
// (MQ_Ecosystem.m) only ever flipped a flag; this is the real plumbing.
@available(macOS 13.0, *)
struct QuakeGroupActivity: GroupActivity {
    let serverAddress: String   // e.g. "192.168.1.5:27500" or "host.example.com"
    let mapName: String

    static let activityIdentifier = "com.metalquake.sharedsession"

    var metadata: GroupActivityMetadata {
        var md = GroupActivityMetadata()
        md.type    = .generic
        md.title   = "Quake — \(mapName)"
        md.subtitle = serverAddress
        md.fallbackURL = URL(string: "https://github.com/mstits/Quake")
        return md
    }
}

// @objc(MQSharePlayManager) pins the Objective-C runtime name so the C
// bridge's NSClassFromString(@"MQSharePlayManager") resolves without
// having to chase the Swift module-mangled symbol. Needed because
// the engine looks up this class by string name at startup.
@available(macOS 13.0, *)
@objc(MQSharePlayManager)
public class MQSharePlayManager: NSObject {
    @objc public static let shared = MQSharePlayManager()

    @objc public func startSession(serverAddress: String, mapName: String) {
        Task {
            let activity = QuakeGroupActivity(serverAddress: serverAddress, mapName: mapName)
            do {
                switch await activity.prepareForActivation() {
                case .activationPreferred:
                    _ = try await activity.activate()
                    NSLog("SharePlay: activated session for %@", serverAddress)
                case .activationDisabled:
                    NSLog("SharePlay: activation disabled (no FaceTime call in progress)")
                case .cancelled:
                    break
                @unknown default:
                    break
                }
            } catch {
                NSLog("SharePlay: activation failed: %@", error.localizedDescription)
            }
        }
    }

    @objc public func observeIncoming() {
        // Called from engine startup; registers a task that listens for
        // remote-user session joins and wires them into the engine via
        // `connect <address>`.
        Task {
            for await session in QuakeGroupActivity.sessions() {
                let activity = session.activity
                NSLog("SharePlay: joined session %@ → %@", activity.mapName, activity.serverAddress)
                DispatchQueue.main.async {
                    let cmd = "connect \(activity.serverAddress)"
                    MQBridge_ConsoleCommand(cmd)
                }
                session.join()
            }
        }
    }
}

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
    @AppStorage("mq_hapticIntensity") var hapticIntensity: Double = 1.0

    @AppStorage("mq_coremlTextures") var coremlTextures: Bool = false
    @AppStorage("mq_neuralBots") var neuralBots: Bool = false

    @AppStorage("mq_soundSpatializer") var soundSpatializer: Bool = false
    @AppStorage("mq_highContrastHUD") var highContrastHUD: Bool = false
    @AppStorage("mq_subtitles") var subtitles: Bool = false

    // View controls — exposed sliders for settings that already exist as
    // engine cvars (fov, gamma) plus hud_scale which maps onto viewsize.
    @AppStorage("mq_fov") var fov: Double = 90.0
    @AppStorage("mq_gamma") var gamma: Double = 1.0
    @AppStorage("mq_hudScale") var hudScale: Double = 1.0

    // Separate music/SFX volumes so the user can keep gameplay audio
    // loud while ducking the title/track music.
    @AppStorage("mq_volumeMusic") var volumeMusic: Double = 0.5
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
    @State private var directConnectHost: String = ""
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
            
            // Status indicators — live from settings + hardware detection
            HStack(spacing: 12) {
                let pCoreCount: Int = {
                    var count: Int32 = 0
                    var size = MemoryLayout<Int32>.size
                    sysctlbyname("hw.perflevel0.physicalcpu", &count, &size, nil, 0)
                    return Int(count > 0 ? count : Int32(ProcessInfo.processInfo.activeProcessorCount))
                }()
                StatusPill(label: "\(pCoreCount) P-Cores", icon: "cpu", color: .green)
                StatusPill(
                    label: settings.rtEnabled ? "RT Active" : "RT Off",
                    icon: "rays",
                    color: settings.rtEnabled ? .orange : .secondary
                )
                StatusPill(
                    label: {
                        switch settings.metalfxMode {
                        case 0: return "MetalFX Off"
                        case 1: return "MetalFX Spatial"
                        case 2: return "MetalFX Temporal"
                        default: return "MetalFX ?"
                        }
                    }(),
                    icon: "arrow.up.right.and.arrow.down.left.rectangle.fill",
                    color: settings.metalfxMode == 0 ? .secondary : .blue
                )
            }
            Button {
                MQBridge_ConsoleCommand("screenshot")
            } label: {
                Label("Screenshot", systemImage: "camera.viewfinder")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .help("Writes to id1/quake00.pcx — requires an active map")

            Button {
                MQBridge_ToggleCvar("vid_fullscreen")
            } label: {
                Label("Fullscreen", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)

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
            TabButton(title: "Maps",      icon: "map.fill",             isSelected: selectedTab == 0) { selectedTab = 0 }
            TabButton(title: "Saves",     icon: "externaldrive.fill",    isSelected: selectedTab == 1) { selectedTab = 1 }
            TabButton(title: "Demos",     icon: "film.fill",             isSelected: selectedTab == 2) { selectedTab = 2 }
            TabButton(title: "Multiplayer", icon: "person.2.fill",        isSelected: selectedTab == 3) { selectedTab = 3 }
            TabButton(title: "Settings",  icon: "gearshape.fill",       isSelected: selectedTab == 4) { selectedTab = 4 }
            TabButton(title: "About",     icon: "info.circle.fill",     isSelected: selectedTab == 5) { selectedTab = 5 }
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
        case 1: savesView
        case 2: demosView
        case 3: multiplayerView
        case 4: settingsView
        case 5: aboutView
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
                
                // View — camera and HUD presentation settings.
                SettingsSection(title: "View", icon: "camera.viewfinder") {
                    SettingsSlider(title: "Field of View", value: $settings.fov, range: 60...130)
                    SettingsSlider(title: "Gamma",          value: $settings.gamma, range: 0.5...1.5)
                    SettingsSlider(title: "HUD Scale",       value: $settings.hudScale, range: 1.0...3.0)
                }

                // Audio
                SettingsSection(title: "Audio", icon: "speaker.wave.3.fill") {
                    SettingsPicker(title: "Audio Engine", selection: $settings.audioMode,
                                   options: ["Core Audio", "PHASE Spatial"])
                    SettingsToggle(title: "Spatial Audio", subtitle: "Personalized HRTF", isOn: $settings.spatialAudio)
                    SettingsSlider(title: "SFX Volume",    value: $settings.masterVolume, range: 0...1)
                    SettingsSlider(title: "Music Volume",   value: $settings.volumeMusic, range: 0...1)
                }

                // Input
                SettingsSection(title: "Input", icon: "gamecontroller.fill") {
                    SettingsSlider(title: "Mouse Sensitivity", value: $settings.mouseSensitivity, range: 1...20)
                    SettingsToggle(title: "Auto-Aim", subtitle: "Vertical auto-aim assist", isOn: $settings.autoAim)
                    SettingsToggle(title: "Invert Y Axis", subtitle: "Inverted vertical look", isOn: $settings.invertY)
                    SettingsToggle(title: "Raw Mouse Input", subtitle: "CGEvent delta (recommended)", isOn: $settings.rawMouse)
                    SettingsSlider(title: "Controller Deadzone", value: $settings.controllerDeadzone, range: 0...0.5)
                    SettingsSlider(title: "Rumble Intensity",    value: $settings.hapticIntensity, range: 0...1)
                }
                
                // Intelligence — Neural Bots removed (would require rewriting
                // Quake's monster AI; outside the scope of this port). CoreML
                // texture path kept because the asset-load upscaler wires
                // through MQ_CoreML_UpscaleTexture when the toggle is on.
                SettingsSection(title: "Intelligence", icon: "brain.fill") {
                    SettingsToggle(title: "CoreML Textures", subtitle: "Bilinear 4× stand-in for Real-ESRGAN", isOn: $settings.coremlTextures)
                }

                // Accessibility — Sound Spatializer removed (overlay was
                // never plumbed through the renderer). HUD contrast and
                // subtitles are wired to shader and console respectively.
                SettingsSection(title: "Accessibility", icon: "accessibility") {
                    SettingsToggle(title: "High Contrast HUD", subtitle: "Boost HUD saturation and contrast", isOn: $settings.highContrastHUD)
                    SettingsToggle(title: "Subtitles", subtitle: "Log sound events to the console", isOn: $settings.subtitles)
                }
            }
            .padding(24)
            // Hot-reload: apply settings live as sliders/toggles move so
            // the user can see FOV / gamma / volumes update without
            // returning to the game. Apply button still persists to
            // disk (the onChange path only writes cvars, not the cfg file).
            .onChange(of: settings.fov)                 { MQBridge_SyncSettings() }
            .onChange(of: settings.gamma)               { MQBridge_SyncSettings() }
            .onChange(of: settings.hudScale)            { MQBridge_SyncSettings() }
            .onChange(of: settings.masterVolume)        { MQBridge_SyncSettings() }
            .onChange(of: settings.volumeMusic)         { MQBridge_SyncSettings() }
            .onChange(of: settings.mouseSensitivity)    { MQBridge_SyncSettings() }
            .onChange(of: settings.controllerDeadzone)  { MQBridge_SyncSettings() }
            .onChange(of: settings.hapticIntensity)     { MQBridge_SyncSettings() }
            .onChange(of: settings.invertY)             { MQBridge_SyncSettings() }
            .onChange(of: settings.rawMouse)            { MQBridge_SyncSettings() }

            // Apply + Resume buttons
            HStack(spacing: 16) {
                Button(action: resetDefaults) {
                    Label("Reset Defaults", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .help("Revert every slider / toggle to the shipping default")

                Spacer()

                Button(action: resumeGame) {
                    Label("Close", systemImage: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Button(action: applyAndResume) {
                    Label("Save & Resume", systemImage: "checkmark.circle.fill")
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
    
    // MARK: - Saves
    // Lists save files that live in id1/*.sav. Click-to-load dispatches
    // the engine's `load` command through the bridge. The "Quick Save"
    // button fires `save quick` which slots into id1/quick.sav.

    var savesView: some View {
        let count = Int(MQBridge_GetSaveSlotCount())
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Saved Games").font(.system(size: 16, weight: .bold, design: .monospaced))
                    Spacer()
                    Button {
                        MQBridge_SaveCurrentGame("quick")
                    } label: {
                        Label("Quick Save", systemImage: "externaldrive.badge.plus")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)

                if count == 0 {
                    Text("No saves yet. Quick Save writes to id1/quick.sav; the `save <name>` console command writes named slots.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(24)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(0..<count, id: \.self) { i in
                            let name = String(cString: MQBridge_GetSaveSlotName(Int32(i)))
                            let ts   = MQBridge_GetSaveSlotTimestamp(Int32(i))
                            Button {
                                MQBridge_LoadSaveSlot(Int32(i))
                            } label: {
                                HStack {
                                    Image(systemName: "externaldrive.fill")
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading) {
                                        Text(name).font(.system(size: 14, weight: .semibold))
                                        if ts > 0 {
                                            Text(Date(timeIntervalSince1970: ts), style: .date)
                                                .font(.system(size: 11)).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Demos
    // Lists .dem files under id1/ and id1/demos/ and launches playback
    // through `playdemo <name>`.

    var demosView: some View {
        let count = Int(MQBridge_GetDemoCount())
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Demos").font(.system(size: 16, weight: .bold, design: .monospaced))
                    Spacer()
                    Button {
                        MQBridge_ConsoleCommand("record auto")
                    } label: {
                        Label("Record Here", systemImage: "record.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .help("Requires an active map. Writes to id1/auto.dem.")
                }
                .padding(.horizontal, 24)

                if count == 0 {
                    Text("No demos found. Classic demo files ship in pak0.pak (demo1/2/3) and play automatically on startup.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(24)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(0..<count, id: \.self) { i in
                            let name = String(cString: MQBridge_GetDemoName(Int32(i)))
                            Button {
                                MQBridge_PlayDemo(name)
                            } label: {
                                HStack {
                                    Image(systemName: "film").foregroundColor(.blue)
                                    Text(name).font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    Spacer()
                                    Image(systemName: "play.fill").foregroundStyle(.tertiary)
                                }
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Multiplayer
    // LAN server browser backed by Quake's native hostcache. "Scan LAN"
    // fires the `slist` console command which broadcasts a query over
    // UDP; responses arrive async and populate hostcache[]. We re-read
    // the list each time the view refreshes so new entries appear.

    @State private var lastScanTick: Int = 0

    var multiplayerView: some View {
        let count = Int(MQBridge_GetServerCount())
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("LAN Servers").font(.system(size: 16, weight: .bold, design: .monospaced))
                    Spacer()
                    Button {
                        MQBridge_ScanLAN()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            lastScanTick += 1
                        }
                    } label: {
                        Label("Scan LAN", systemImage: "wifi.circle")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    // SharePlay activation. Only meaningful inside an
                    // active FaceTime call; prepareForActivation gracefully
                    // reports "activationDisabled" otherwise.
                    if #available(macOS 13.0, *) {
                        Button {
                            let map = String(cString: MQBridge_GetCurrentMap())
                            let name = map.isEmpty ? "start" : map
                            MQSharePlayManager.shared.startSession(serverAddress: "127.0.0.1:27500", mapName: name)
                        } label: {
                            Label("SharePlay", systemImage: "person.2.wave.2")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        .help("Invite FaceTime participants to join the current session")
                    }
                }
                .padding(.horizontal, 24)

                HStack(spacing: 8) {
                    TextField("host:port", text: $directConnectHost)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                    Button("Connect") {
                        if !directConnectHost.isEmpty {
                            MQBridge_ConsoleCommand("connect \(directConnectHost)")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)

                if count == 0 {
                    Text("No servers found. Tap Scan LAN to broadcast a query on your local network, or paste an address above to direct-connect.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(24)
                } else {
                    ForEach(0..<count, id: \.self) { i in
                        let name = String(cString: MQBridge_GetServerName(Int32(i)))
                        let addr = String(cString: MQBridge_GetServerAddress(Int32(i)))
                        Button {
                            MQBridge_ConnectServer(Int32(i))
                        } label: {
                            HStack {
                                Image(systemName: "network").foregroundColor(.green)
                                VStack(alignment: .leading) {
                                    Text(name.isEmpty ? addr : name)
                                        .font(.system(size: 14, weight: .semibold))
                                    if !name.isEmpty {
                                        Text(addr).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill").foregroundColor(.orange)
                            }
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                    }
                }
            }
            .padding(.vertical, 20)
            .id(lastScanTick) // re-evaluate when scan completes
        }
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
                    AboutRow(label: "Threading", value: "GCD dispatch_apply across P-cores")
                    AboutRow(label: "Upscaling", value: "MetalFX Spatial + Temporal (user-configurable)")
                    AboutRow(label: "Input", value: "GameController + DualSense Adaptive Triggers + Gyro")
                    AboutRow(label: "Audio", value: "Core Audio mixer + PHASE spatial engine with BSP occluder")
                    AboutRow(label: "Denoise", value: "Bilateral à-trous with SVGF temporal reprojection opt-in")
                    AboutRow(label: "UI", value: "SwiftUI + Liquid Glass")
                    AboutRow(label: "Platform", value: "Apple Silicon Native (arm64, macOS 14+)")
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
        // Sync all settings from UserDefaults → MetalQuakeSettings → engine
        // cvars, then persist to disk so a crash or force-quit doesn't lose
        // the user's choices. The bridge function calls MQ_SaveSettings()
        // internally now.
        MQBridge_SyncSettings()
        MQBridge_SaveSettingsToDisk()
        MQBridge_SetLauncherVisible(0)
    }

    func resetDefaults() {
        // Mirrors MQ_InitSettings' defaults on the Swift side so the
        // sliders snap back without going through the engine. Next Apply
        // will sync the reset values back through to cvars / disk.
        settings.rtEnabled           = true
        settings.rtQuality           = 2
        settings.metalfxMode         = 1
        settings.metalfxScale        = 2.0
        settings.neuralDenoise       = false
        settings.meshShaders         = false
        settings.liquidGlassUI       = false
        settings.audioMode           = 0
        settings.spatialAudio        = false
        settings.masterVolume        = 0.7
        settings.volumeMusic         = 0.5
        settings.mouseSensitivity    = 3.0
        settings.autoAim             = true
        settings.invertY             = false
        settings.rawMouse            = true
        settings.controllerDeadzone  = 0.15
        settings.hapticIntensity     = 1.0
        settings.fov                 = 90.0
        settings.gamma               = 1.0
        settings.hudScale            = 1.0
        settings.coremlTextures      = false
        settings.highContrastHUD     = false
        settings.subtitles           = false
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
