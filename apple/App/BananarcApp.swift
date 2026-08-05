// App entry point + game view + controller/remote input, shared by the
// iOS, tvOS, and macOS targets.

import SwiftUI
import SceneKit
import GameController

@main
struct BananarcApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
        }
    }
}

struct GameView: View {
    @StateObject private var engine = GameEngine()
    @State private var renderer = SceneRenderer()
    @State private var input: InputController?

    var body: some View {
        ZStack {
            SceneView(scene: renderer.scene,
                      pointOfView: renderer.cameraNode,
                      options: [])
                .ignoresSafeArea()
                #if !os(tvOS)
                .onTapGesture { engine.requestThrow() }
                #endif
            HUDView(engine: engine)
        }
        .onAppear {
            engine.renderer = renderer
            if input == nil {
                input = InputController(engine: engine)
            }
        }
        #if os(macOS)
        .background(KeyCatcher(onSpace: { engine.requestThrow() }))
        #endif
    }
}

/// Game Controller framework input: works for Xbox/DualSense/MFi pads on
/// every platform and for the Siri Remote (micro gamepad) on tvOS.
/// A = throw; left stick / dpad = angle (vertical) and power (horizontal).
@MainActor
final class InputController {
    private weak var engine: GameEngine?
    private var pollTimer: Timer?

    init(engine: GameEngine) {
        self.engine = engine
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] note in
            guard let pad = note.object as? GCController else { return }
            Task { @MainActor in self?.wire(pad) }
        }
        GCController.controllers().forEach { wire($0) }
        GCController.startWirelessControllerDiscovery()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0,
                                         repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollSticks() }
        }
    }

    private func wire(_ pad: GCController) {
        if let gp = pad.extendedGamepad {
            gp.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed {
                    Task { @MainActor in self?.engine?.requestThrow() }
                }
            }
            gp.dpad.up.pressedChangedHandler = { [weak self] _, _, p in
                if p { Task { @MainActor in self?.engine?.nudge(angleDelta: 1, powerDelta: 0) } }
            }
            gp.dpad.down.pressedChangedHandler = { [weak self] _, _, p in
                if p { Task { @MainActor in self?.engine?.nudge(angleDelta: -1, powerDelta: 0) } }
            }
            gp.dpad.right.pressedChangedHandler = { [weak self] _, _, p in
                if p { Task { @MainActor in self?.engine?.nudge(angleDelta: 0, powerDelta: 1) } }
            }
            gp.dpad.left.pressedChangedHandler = { [weak self] _, _, p in
                if p { Task { @MainActor in self?.engine?.nudge(angleDelta: 0, powerDelta: -1) } }
            }
        } else if let micro = pad.microGamepad {
            // Siri Remote: touch-surface swipes adjust, click throws.
            micro.reportsAbsoluteDpadValues = false
            micro.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed {
                    Task { @MainActor in self?.engine?.requestThrow() }
                }
            }
        }
    }

    private func pollSticks() {
        guard let engine else { return }
        for pad in GCController.controllers() {
            if let gp = pad.extendedGamepad {
                let ly = Double(gp.leftThumbstick.yAxis.value)
                let ry = Double(gp.rightThumbstick.yAxis.value)
                if abs(ly) > 0.25 { engine.nudge(angleDelta: ly * 0.9, powerDelta: 0) }
                if abs(ry) > 0.25 { engine.nudge(angleDelta: 0, powerDelta: ry * 1.0) }
            } else if let micro = pad.microGamepad {
                let x = Double(micro.dpad.xAxis.value)
                let y = Double(micro.dpad.yAxis.value)
                if abs(y) > 0.3 { engine.nudge(angleDelta: y * 0.9, powerDelta: 0) }
                if abs(x) > 0.3 { engine.nudge(angleDelta: 0, powerDelta: x * 1.0) }
            }
        }
    }
}

#if os(macOS)
import AppKit

/// Space-to-throw on the Mac without stealing focus from SwiftUI controls.
struct KeyCatcher: NSViewRepresentable {
    let onSpace: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onSpace = onSpace
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class KeyView: NSView {
        var onSpace: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] ev in
                if ev.keyCode == 49 {  // space
                    self?.onSpace?()
                    return nil
                }
                return ev
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
#endif
