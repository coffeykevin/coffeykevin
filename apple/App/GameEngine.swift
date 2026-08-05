// Match orchestrator — port of the Godot main.gd state machine onto
// BananarcCore, driving SceneRenderer and publishing HUD state to SwiftUI.

import Foundation
import BananarcCore

struct DebriefInfo: Identifiable {
    let id = UUID()
    let who: String
    let accentIsP1: Bool
    let n: Int
    let angle: Int
    let power: Int
    let time: Double
    let apex: Double
    let dist: Double
    let drift: Double
    let note: String
}

@MainActor
final class GameEngine: ObservableObject {
    enum State { case title, aiming, flying, pause, matchEnd }

    static let pointsToWin = 3
    static let gravity = 9.8
    static let names = ["KILO", "NEWTON"]
    static let gorillaRadius = 2.2

    @Published var state: State = .title
    @Published var power: Double = 60
    @Published var angle: Double = 45
    @Published var windText = ""
    @Published var weatherName = ""
    @Published var weatherTime = ""
    @Published var banner = ""
    @Published var bannerIsP1 = true
    @Published var scores = [0, 0]
    @Published var debrief: DebriefInfo?
    @Published var endText = ""

    var renderer: SceneRenderer?
    private(set) var vsAI = false
    private(set) var current = 0
    private var matchSeed = 0
    private var roundIndex = 0
    private var throwCount = 0
    private var aiAttempts = [0, 0]
    private var aim: [(angle: Double, power: Double)] = [(45, 60), (45, 60)]
    private var city: CityData?
    private var prevCity: CityData?
    private var roundRng = Lcg(1)
    private var wind = 0.0
    private var playbackTask: Task<Void, Never>?

    func startMatch(vsAI: Bool) {
        self.vsAI = vsAI
        matchSeed = Int(Date().timeIntervalSince1970) % 100_000
        roundIndex = 0
        throwCount = 0
        scores = [0, 0]
        debrief = nil
        nextRound()
    }

    func rematch() { startMatch(vsAI: vsAI) }

    private func isAI(_ p: Int) -> Bool { vsAI && p == 1 }

    private func targets() -> [Target] {
        guard let city else { return [] }
        return (0..<2).map {
            Target(pos: city.gorillaSpots[$0] + Vec2(0, 2.0),
                   radius: Self.gorillaRadius, player: $0)
        }
    }

    private func nextRound() {
        roundIndex += 1
        roundRng = Lcg(matchSeed * 31 + roundIndex * 7919)
        let cond = Weather.conditions[roundRng.randiRange(0, Weather.conditions.count - 1)]
        weatherName = cond.name
        weatherTime = cond.time

        prevCity = city
        let newCity = CityGen.generate(rng: roundRng, gravity: Self.gravity, prev: prevCity)
        city = newCity
        wind = Sim.rollWind(roundRng)
        windText = "WIND  \(wind >= 0 ? "→" : "←")  \(Sim.windMph(wind)) MPH"

        renderer?.buildRound(city: newCity, condition: cond,
                             seed: matchSeed + roundIndex)
        current = (roundIndex - 1) % 2
        aiAttempts = [0, 0]
        beginTurn(msg: "ROUND \(roundIndex) — \(Self.names[current]) THROWS FIRST")
    }

    private func beginTurn(msg: String) {
        state = .aiming
        banner = msg
        bannerIsP1 = current == 0
        angle = aim[current].angle
        power = aim[current].power
        refreshAim()
        if isAI(current) {
            Task { await aiTurn() }
        }
    }

    func setAngle(_ v: Double) {
        guard state == .aiming, !isAI(current) else { return }
        angle = min(max(v, 0), 90)
        aim[current].angle = angle
        refreshAim()
    }

    func setPower(_ v: Double) {
        guard state == .aiming, !isAI(current) else { return }
        power = min(max(v, 1), 100)
        aim[current].power = power
        refreshAim()
    }

    func nudge(angleDelta: Double, powerDelta: Double) {
        setAngle(angle + angleDelta)
        setPower(power + powerDelta)
    }

    private func refreshAim() {
        guard state == .aiming else { return }
        renderer?.updateAim(player: current, angle: aim[current].angle,
                            power: aim[current].power)
    }

    private func aiTurn() async {
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        guard state == .aiming, let city else { return }
        let facing = current == 0 ? 1 : -1
        let hand = city.gorillaSpots[current] + Vec2(Double(facing) * 2.0, 4.5)
        let plan = AiBrain.plan(city: city, shooterPos: hand, facing: facing,
                                targets: targets(), shooter: current, wind: wind,
                                gravity: Self.gravity, rng: roundRng,
                                attempt: aiAttempts[current])
        aiAttempts[current] += 1
        aim[current] = (plan.angle, plan.power)
        angle = plan.angle
        power = plan.power
        renderer?.updateAim(player: current, angle: plan.angle, power: plan.power)
        try? await Task.sleep(nanoseconds: 700_000_000)
        if state == .aiming { performThrow() }
    }

    /// The throw trigger for human input (button A, Space, tap on scene).
    func requestThrow() {
        guard state == .aiming, !isAI(current) else { return }
        performThrow()
    }

    private func performThrow() {
        guard let city else { return }
        state = .flying
        throwCount += 1
        debrief = nil
        let a = aim[current].angle
        let p = aim[current].power
        banner = "\(Self.names[current]) — \(Int(a))° AT \(Int(p))"
        bannerIsP1 = current == 0
        renderer?.clearAim()
        renderer?.clearTrace()
        let facing = current == 0 ? 1 : -1
        let thrower = current
        renderer?.throwAnim(player: current, angle: a) { [weak self] in
            Task { @MainActor in self?.launch(city: city, angle: a, power: p,
                                             facing: facing, thrower: thrower) }
        }
    }

    private func launch(city: CityData, angle a: Double, power p: Double,
                        facing: Int, thrower: Int) {
        let hand = city.gorillaSpots[thrower] + Vec2(Double(facing) * 2.0, 4.5)
        let res = Sim.simulate(city: city, start: hand, angleDeg: a, power: p,
                               facing: facing, wind: wind, gravity: Self.gravity,
                               targets: targets(), shooter: thrower)
        let windless = Sim.simulate(city: city, start: hand, angleDeg: a, power: p,
                                    facing: facing, wind: 0, gravity: Self.gravity,
                                    targets: targets(), shooter: thrower,
                                    record: false)
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            await self?.playback(res: res, start: hand,
                                 driftRef: windless.impact, thrower: thrower)
        }
    }

    private func playback(res: SimResult, start: Vec2, driftRef: Vec2,
                          thrower: Int) async {
        let pts = res.points
        renderer?.bananaVisible(true)
        var i = 0
        var sinceTrace = 0
        while i < pts.count, !Task.isCancelled {
            renderer?.bananaMove(to: pts[i])
            sinceTrace += 2
            if sinceTrace >= 14 {
                sinceTrace = 0
                renderer?.traceAdd(pts[i])
            }
            i += 2  // 2 sim substeps per frame ≈ real time at 60fps
            try? await Task.sleep(nanoseconds: 16_600_000)
        }
        renderer?.bananaVisible(false)
        await resolve(res: res, start: start, driftRef: driftRef, thrower: thrower)
    }

    private func resolve(res: SimResult, start: Vec2, driftRef: Vec2,
                         thrower: Int) async {
        guard let city else { return }
        state = .pause
        var note = ""
        switch res.kind {
        case .gorilla:
            renderer?.explosion(at: res.impact, scale: 2.2)
            city.carveWorld(res.impact, 5.0)
            renderer?.rebuildCity(city: city)
            await scoreHit(victim: res.player, thrower: thrower)
            return
        case .building:
            renderer?.explosion(at: res.impact, scale: 1.0)
            city.carveWorld(res.impact, 3.5)
            renderer?.rebuildCity(city: city)
            note = "Hit a building — the crater is permanent."
        case .ground:
            note = "Into the street. Watch the wind line."
        case .oob:
            note = "Gone. The sun said nothing."
        }
        debrief = DebriefInfo(
            who: Self.names[thrower], accentIsP1: thrower == 0, n: throwCount,
            angle: Int(aim[thrower].angle), power: Int(aim[thrower].power),
            time: res.time, apex: res.apex, dist: abs(res.impact.x - start.x),
            drift: res.impact.x - driftRef.x, note: note)
        try? await Task.sleep(nanoseconds: 1_300_000_000)
        current = 1 - current
        beginTurn(msg: "\(Self.names[current])'S THROW")
    }

    private func scoreHit(victim: Int, thrower: Int) async {
        let scorer = 1 - victim
        scores[scorer] += 1
        renderer?.defeatAnim(player: victim)
        renderer?.victoryAnim(player: scorer)
        banner = victim == thrower
            ? "\(Self.names[victim]) HIT THEMSELF — POINT TO \(Self.names[scorer])"
            : "\(Self.names[scorer]) TAKES THE ROUND"
        bannerIsP1 = scorer == 0
        try? await Task.sleep(nanoseconds: 2_600_000_000)
        if scores[scorer] >= Self.pointsToWin {
            endText = "\(Self.names[scorer]) WINS THE MATCH  \(scores[0])–\(scores[1])"
            state = .matchEnd
        } else {
            nextRound()
        }
    }
}
