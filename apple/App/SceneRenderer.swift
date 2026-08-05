// SceneKit renderer — a truly 3D scene with real lighting (PRD section 9/12):
// perspective camera in the classic side-on frame, a DirectionalLight sun/moon
// positioned per weather condition with real shadows, fog, rain/snow
// particles, run-length-boxed destructible city, and primitive gorillas
// carrying the animation contract (idle, aim, throw, flinch, defeat, victory).

import SceneKit
import BananarcCore

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#else
import AppKit
typealias PlatformColor = NSColor
#endif

extension RGB {
    var platform: PlatformColor {
        PlatformColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)
    }
}

@MainActor
final class SceneRenderer {
    let scene = SCNScene()
    let cameraNode = SCNNode()

    private let cityRoot = SCNNode()
    private let staticRoot = SCNNode()
    private let traceRoot = SCNNode()
    private let aimRoot = SCNNode()
    private var gorillas: [SCNNode] = []
    private var armPivots: [SCNNode] = []
    private let bananaNode = SCNNode()
    private let sunNode = SCNNode()
    private let ambientNode = SCNNode()
    private var precipNode: SCNNode?
    private var city: CityData?
    private var windowSeed = 0
    private var litFraction = 0.3

    init() {
        scene.rootNode.addChildNode(cityRoot)
        scene.rootNode.addChildNode(staticRoot)
        scene.rootNode.addChildNode(traceRoot)
        scene.rootNode.addChildNode(aimRoot)

        let cam = SCNCamera()
        cam.fieldOfView = 32
        cam.zFar = 600
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.castsShadow = true
        sun.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.shadowSampleCount = 8
        sun.shadowRadius = 4
        sunNode.light = sun
        scene.rootNode.addChildNode(sunNode)

        let amb = SCNLight()
        amb.type = .ambient
        ambientNode.light = amb
        scene.rootNode.addChildNode(ambientNode)

        let banana = SCNSphere(radius: 0.55)
        banana.firstMaterial?.diffuse.contents = RGB(hex: 0xF2BE4C).platform
        bananaNode.geometry = banana
        bananaNode.scale = SCNVector3(1.5, 0.55, 0.55)
        bananaNode.isHidden = true
        scene.rootNode.addChildNode(bananaNode)

        for i in 0..<2 {
            let g = makeGorilla(p1: i == 0)
            gorillas.append(g.root)
            armPivots.append(g.arm)
            scene.rootNode.addChildNode(g.root)
        }
    }

    // MARK: - Round build

    func buildRound(city: CityData, condition: WeatherCondition, seed: Int) {
        self.city = city
        windowSeed = seed
        litFraction = condition.litWindowFraction
        rebuildCity(city: city)
        buildStatic(city: city, seed: seed)
        applyWeather(condition, cityWidth: city.worldWidth())
        clearTrace()
        clearAim()
        for i in 0..<2 {
            let spot = city.gorillaSpots[i]
            gorillas[i].removeAllActions()
            gorillas[i].position = SCNVector3(spot.x, spot.y, 0)
            gorillas[i].eulerAngles = SCNVector3(0, i == 0 ? 0 : Double.pi, 0)
            idle(gorillas[i])
        }
        fitCamera(width: city.worldWidth())
    }

    private func fitCamera(width: Double) {
        let aspect = 16.0 / 9.0
        let halfH = 32.0 * Double.pi / 360.0
        let halfW = atan(tan(halfH) * aspect)
        let dist = (width * 0.5 + 10.0) / tan(halfW)
        cameraNode.position = SCNVector3(width * 0.5, 22, dist)
        cameraNode.look(at: SCNVector3(width * 0.5, 18, 0))
    }

    // MARK: - City (run-length boxes per column; rebuild = collision truth)

    func rebuildCity(city: CityData) {
        cityRoot.childNodes.forEach { $0.removeFromParentNode() }
        var colorOf: [RGB] = Array(repeating: CityGen.palette[0],
                                   count: city.widthCells)
        for b in city.buildings {
            for cx in b.x0..<min(b.x0 + b.w, city.widthCells) {
                colorOf[cx] = b.color
            }
        }
        for cx in 0..<city.widthCells {
            var cy = 0
            while cy < CityData.skyCells {
                if city.cellAt(cx, cy) == 0 { cy += 1; continue }
                var top = cy
                while top < CityData.skyCells, city.cellAt(cx, top) != 0 {
                    top += 1
                }
                let runLen = top - cy
                let box = SCNBox(width: CityData.cell, height: CGFloat(runLen),
                                 length: 10, chamferRadius: 0)
                let c = colorOf[cx]
                let jitter = 0.92 + 0.08 * Double((cx * 7 + cy * 13) % 10) / 10.0
                let ao = min(max(0.5 + Double(cy) / 40.0, 0.55), 1.0)
                box.firstMaterial?.diffuse.contents = RGB(
                    c.r * jitter * ao, c.g * jitter * ao, c.b * jitter * ao).platform
                box.firstMaterial?.roughness.contents = 0.9
                let node = SCNNode(geometry: box)
                node.position = SCNVector3(
                    Double(cx) + 0.5, Double(cy) + Double(runLen) * 0.5, 0)
                cityRoot.addChildNode(node)
                // Lit windows on the front face of this run.
                for wy in cy..<top where cx % 3 == 1 && wy % 4 == 2 {
                    let h = (cx * 131 + wy * 197 + windowSeed) % 100
                    guard h < Int(litFraction * 100) else { continue }
                    let win = SCNBox(width: 0.55, height: 0.72, length: 0.1,
                                     chamferRadius: 0)
                    win.firstMaterial?.diffuse.contents = PlatformColor.black
                    win.firstMaterial?.emission.contents =
                        RGB(hex: 0xFFB35C).platform
                    let wn = SCNNode(geometry: win)
                    wn.position = SCNVector3(Double(cx) + 0.5, Double(wy) + 0.5, 5.06)
                    cityRoot.addChildNode(wn)
                }
                cy = top
            }
        }
    }

    private func buildStatic(city: CityData, seed: Int) {
        staticRoot.childNodes.forEach { $0.removeFromParentNode() }
        let w = city.worldWidth()

        let ground = SCNBox(width: CGFloat(w + 400), height: 2, length: 320,
                            chamferRadius: 0)
        ground.firstMaterial?.diffuse.contents = RGB(hex: 0x1A1714).platform
        let groundNode = SCNNode(geometry: ground)
        groundNode.position = SCNVector3(w * 0.5, -1, -40)
        staticRoot.addChildNode(groundNode)

        let laneRng = Lcg(seed * 17 + 3)
        for lane in 0..<2 {
            let z = -26.0 - 22.0 * Double(lane)
            let shade = 0.55 - 0.18 * Double(lane)
            var x = -30.0
            while x < w + 30 {
                let bw = 8.0 + laneRng.randf() * 10.0
                let bh = 10.0 + laneRng.randf() * (34.0 + 10.0 * Double(lane))
                let box = SCNBox(width: CGFloat(bw), height: CGFloat(bh),
                                 length: 12, chamferRadius: 0)
                let base = CityGen.palette[laneRng.randiRange(0, CityGen.palette.count - 1)]
                box.firstMaterial?.diffuse.contents =
                    RGB(base.r * shade, base.g * shade, base.b * shade).platform
                let node = SCNNode(geometry: box)
                node.position = SCNVector3(x + bw * 0.5, bh * 0.5, z)
                staticRoot.addChildNode(node)
                x += bw + 2.0 + laneRng.randf() * 4.0
            }
        }

        // Landmark spire + trestle water tower (background dressing).
        let spire = SCNBox(width: 7, height: 58, length: 7, chamferRadius: 0)
        spire.firstMaterial?.diffuse.contents = RGB(0.27, 0.22, 0.17).platform
        let spireNode = SCNNode(geometry: spire)
        spireNode.position = SCNVector3(w * 0.62, 29, -52)
        staticRoot.addChildNode(spireNode)

        let tank = SCNCylinder(radius: 3.1, height: 4.5)
        tank.firstMaterial?.diffuse.contents = RGB(hex: 0x5E432C).platform
        let tankNode = SCNNode(geometry: tank)
        tankNode.position = SCNVector3(w * 0.34, 35, -27)
        staticRoot.addChildNode(tankNode)
        let cap = SCNCone(topRadius: 0.1, bottomRadius: 3.4, height: 2.2)
        cap.firstMaterial?.diffuse.contents = RGB(hex: 0x5E432C).platform
        let capNode = SCNNode(geometry: cap)
        capNode.position = SCNVector3(w * 0.34, 38.3, -27)
        staticRoot.addChildNode(capNode)
    }

    // MARK: - Weather (real light, fog, particles)

    private func applyWeather(_ c: WeatherCondition, cityWidth: Double) {
        scene.background.contents = c.skyTop.platform
        scene.fogColor = c.skyHorizon.platform
        if c.fogDensity > 0 {
            scene.fogStartDistance = 20
            scene.fogEndDistance = CGFloat(30.0 / max(c.fogDensity, 0.001))
            scene.fogDensityExponent = 1.5
        } else {
            scene.fogEndDistance = 0  // disables fog
        }
        sunNode.eulerAngles = SCNVector3(
            -c.sunElevationDeg * Double.pi / 180.0,
            c.sunAzimuthDeg * Double.pi / 180.0, 0)
        sunNode.light?.color = c.sunColor.platform
        sunNode.light?.intensity = CGFloat(1000 * c.sunEnergy)
        ambientNode.light?.color = c.skyHorizon.platform
        ambientNode.light?.intensity = CGFloat(220 * c.ambient)

        precipNode?.removeFromParentNode()
        precipNode = nil
        if c.precip != .none {
            let ps = SCNParticleSystem()
            ps.birthRate = c.precip == .rain ? 900 : 350
            ps.particleLifeSpan = c.precip == .rain ? 2.2 : 12
            ps.particleVelocity = c.precip == .rain ? 30 : 3
            ps.particleVelocityVariation = 4
            ps.emittingDirection = SCNVector3(0, -1, 0)
            ps.spreadingAngle = 4
            ps.particleSize = c.precip == .rain ? 0.06 : 0.14
            ps.particleColor = c.precip == .rain
                ? PlatformColor(white: 0.8, alpha: 0.55)
                : PlatformColor.white
            ps.emitterShape = SCNBox(width: CGFloat(cityWidth * 1.4), height: 1,
                                     length: 40, chamferRadius: 0)
            let node = SCNNode()
            node.position = SCNVector3(cityWidth * 0.5, 52, 0)
            node.addParticleSystem(ps)
            scene.rootNode.addChildNode(node)
            precipNode = node
        }
        if c.lightning {
            let flash = SCNAction.repeatForever(.sequence([
                .wait(duration: 5.0, withRange: 5.0),
                .run { node in node.light?.intensity = 8000 },
                .wait(duration: 0.12),
                .run { [weak self] node in
                    node.light?.intensity = CGFloat(1000 * c.sunEnergy)
                    _ = self
                },
            ]))
            sunNode.runAction(flash, forKey: "lightning")
        } else {
            sunNode.removeAction(forKey: "lightning")
        }
    }

    // MARK: - Gorillas (primitive placeholders carrying the animation contract)

    private func makeGorilla(p1: Bool) -> (root: SCNNode, arm: SCNNode) {
        let fur = RGB(hex: 0x2E2822).platform
        let dark = RGB(hex: 0x1C1510).platform
        let accent = (p1 ? RGB(hex: 0xFFC93C) : RGB(hex: 0x35C4F0)).platform

        let root = SCNNode()
        let body = SCNNode(geometry: SCNCapsule(capRadius: 1.15, height: 2.6))
        body.geometry?.firstMaterial?.diffuse.contents = fur
        body.position = SCNVector3(0, 1.7, 0)
        root.addChildNode(body)

        let head = SCNNode(geometry: SCNSphere(radius: 0.62))
        head.geometry?.firstMaterial?.diffuse.contents = fur
        head.position = SCNVector3(0.35, 3.15, 0)
        root.addChildNode(head)

        let scarf = SCNNode(geometry: SCNTorus(ringRadius: 0.58, pipeRadius: 0.14))
        scarf.geometry?.firstMaterial?.diffuse.contents = accent
        scarf.position = SCNVector3(0.2, 2.75, 0)
        root.addChildNode(scarf)

        let armPivot = SCNNode()
        armPivot.position = SCNVector3(0.35, 2.75, 0.55)
        root.addChildNode(armPivot)
        let arm = SCNNode(geometry: SCNCapsule(capRadius: 0.34, height: 1.9))
        arm.geometry?.firstMaterial?.diffuse.contents = fur
        arm.position = SCNVector3(0, -0.85, 0)
        armPivot.addChildNode(arm)

        for side in [-0.45, 0.45] {
            let leg = SCNNode(geometry: SCNCapsule(capRadius: 0.42, height: 1.5))
            leg.geometry?.firstMaterial?.diffuse.contents = dark
            leg.position = SCNVector3(-0.1, 0.6, side)
            root.addChildNode(leg)
        }
        return (root, armPivot)
    }

    private func idle(_ node: SCNNode) {
        node.runAction(.repeatForever(.sequence([
            .moveBy(x: 0, y: 0.12, z: 0, duration: 1.2),
            .moveBy(x: 0, y: -0.12, z: 0, duration: 1.2),
        ])), forKey: "idle")
    }

    func updateAim(player: Int, angle: Double, power: Double) {
        armPivots[player].eulerAngles.z = SCNFloat(-(180.0 - angle) * Double.pi / 180.0 + Double.pi / 2)
        drawAimOverlay(player: player, angle: angle, power: power)
    }

    func throwAnim(player: Int, angle: Double, onRelease: @escaping () -> Void) {
        let pivot = armPivots[player]
        let windup = SCNAction.rotateTo(x: 0, y: 0, z: CGFloat(150.0 * Double.pi / 180),
                                        duration: 0.5, usesShortestUnitArc: true)
        let release = SCNAction.rotateTo(
            x: 0, y: 0, z: CGFloat((-(180.0 - angle) + 90) * Double.pi / 180),
            duration: 0.13, usesShortestUnitArc: true)
        pivot.runAction(.sequence([windup, release, .run { _ in
            DispatchQueue.main.async { onRelease() }
        }]))
    }

    func victoryAnim(player: Int) {
        gorillas[player].runAction(.repeat(.sequence([
            .moveBy(x: 0, y: 0.7, z: 0, duration: 0.16),
            .moveBy(x: 0, y: -0.7, z: 0, duration: 0.14),
        ]), count: 6))
    }

    func defeatAnim(player: Int) {
        gorillas[player].runAction(
            .rotateBy(x: CGFloat(78.0 * Double.pi / 180), y: 0, z: 0, duration: 0.5))
    }

    // MARK: - Banana, trace, aim overlay, explosions

    func bananaVisible(_ v: Bool) { bananaNode.isHidden = !v }

    func bananaMove(to p: Vec2) {
        bananaNode.position = SCNVector3(p.x, p.y, 0)
        bananaNode.eulerAngles.z -= 0.35
    }

    func traceAdd(_ p: Vec2) {
        let dot = SCNNode(geometry: SCNSphere(radius: 0.32))
        dot.geometry?.firstMaterial?.diffuse.contents = PlatformColor.white
        dot.geometry?.firstMaterial?.lightingModel = .constant
        dot.position = SCNVector3(p.x, p.y, 5.2)
        traceRoot.addChildNode(dot)
    }

    func clearTrace() {
        traceRoot.childNodes.forEach { $0.removeFromParentNode() }
    }

    private func drawAimOverlay(player: Int, angle: Double, power: Double) {
        clearAim()
        guard let city else { return }
        let facing: Double = player == 0 ? 1 : -1
        let origin = city.gorillaSpots[player] + Vec2(facing * 2.0, 4.5)
        let a = angle * Double.pi / 180.0
        let len = 2.0 + power * 0.09
        let tip = Vec2(origin.x + cos(a) * len * facing, origin.y + sin(a) * len)
        addLine(from: origin, to: tip,
                color: player == 0 ? RGB(hex: 0xFFC93C).platform
                                   : RGB(hex: 0x35C4F0).platform,
                radius: 0.14)
        addLine(from: origin, to: Vec2(origin.x + cos(a) * len * facing, origin.y),
                color: PlatformColor(white: 1, alpha: 0.55), radius: 0.06)
        addLine(from: origin, to: Vec2(origin.x, origin.y + sin(a) * len),
                color: PlatformColor(white: 1, alpha: 0.55), radius: 0.06)
    }

    func clearAim() {
        aimRoot.childNodes.forEach { $0.removeFromParentNode() }
    }

    private func addLine(from: Vec2, to: Vec2, color: PlatformColor, radius: Double) {
        let dx = to.x - from.x, dy = to.y - from.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 0.01 else { return }
        let cyl = SCNCylinder(radius: CGFloat(radius), height: CGFloat(len))
        cyl.firstMaterial?.diffuse.contents = color
        cyl.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: cyl)
        node.position = SCNVector3((from.x + to.x) / 2, (from.y + to.y) / 2, 5.2)
        node.eulerAngles.z = SCNFloat(atan2(dy, dx) - Double.pi / 2)
        aimRoot.addChildNode(node)
    }

    func explosion(at p: Vec2, scale: Double) {
        let light = SCNLight()
        light.type = .omni
        light.color = RGB(hex: 0xFF9E4A).platform
        light.intensity = CGFloat(6000 * scale)
        light.attenuationEndDistance = CGFloat(22 * scale)
        let node = SCNNode()
        node.light = light
        node.position = SCNVector3(p.x, p.y + 1, 4)
        scene.rootNode.addChildNode(node)
        node.runAction(.sequence([
            .customAction(duration: 0.6) { n, t in
                n.light?.intensity = CGFloat(6000 * scale) * (1 - t / 0.6)
            },
            .removeFromParentNode(),
        ]))

        let ps = SCNParticleSystem()
        ps.birthRate = 0
        ps.particleLifeSpan = 1.1
        ps.particleVelocity = CGFloat(10 * scale)
        ps.particleVelocityVariation = 5
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.spreadingAngle = 80
        ps.particleSize = 0.3
        ps.particleColor = RGB(hex: 0xC66A3A).platform
        ps.acceleration = SCNVector3(0, -14, 0)
        let pnode = SCNNode()
        pnode.position = SCNVector3(p.x, p.y, 0)
        pnode.addParticleSystem(ps)
        scene.rootNode.addChildNode(pnode)
        ps.birthRate = 300
        pnode.runAction(.sequence([
            .wait(duration: 0.15),
            .run { _ in ps.birthRate = 0 },
            .wait(duration: 2.0),
            .removeFromParentNode(),
        ]))
    }
}

#if canImport(UIKit)
typealias SCNFloat = Float
#else
typealias SCNFloat = CGFloat
#endif
