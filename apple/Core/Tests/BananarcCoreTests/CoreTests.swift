// Port of the Godot smoke test (game/tests/smoke.gd): RNG determinism,
// generation guarantees, trajectory + quadratic wind drift, destruction,
// and AI planning. Runs on Linux CI and macOS identically.

import XCTest
@testable import BananarcCore

final class CoreTests: XCTestCase {

    func testRngDeterminism() {
        let a = Lcg(42), b = Lcg(42)
        for _ in 0..<100 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testCityGenerationGuarantees() {
        var prev: CityData? = nil
        for seed in [7, 99, 12345, 777, 31337, 2026] {
            let rng = Lcg(seed)
            let city = CityGen.generate(rng: rng, gravity: 9.8, prev: prev)
            XCTAssertEqual(city.gorillaSpots.count, 2, "seed \(seed)")
            let roofMax = max(city.gorillaSpots[0].y, city.gorillaSpots[1].y)
            var tallest = 0.0
            for b in city.buildings.dropFirst(2).dropLast(2) {
                tallest = max(tallest, Double(b.h))
            }
            XCTAssertGreaterThanOrEqual(
                tallest, roofMax + 4.9,
                "seed \(seed): interceptor guarantee (profile \(city.profileName))")
            prev = city
        }
    }

    func testTrajectoryTravelsDownrange() {
        let rng = Lcg(5)
        let city = CityGen.generate(rng: rng, gravity: 9.8)
        let start = city.gorillaSpots[0] + Vec2(0, 2.5)
        let targets = [
            Target(pos: city.gorillaSpots[0] + Vec2(0, 2), radius: 2.2, player: 0),
            Target(pos: city.gorillaSpots[1] + Vec2(0, 2), radius: 2.2, player: 1),
        ]
        let res = Sim.simulate(city: city, start: start, angleDeg: 60, power: 80,
                               facing: 1, wind: 0, gravity: 9.8,
                               targets: targets, shooter: 0)
        XCTAssertGreaterThan(res.impact.x, start.x)
        XCTAssertGreaterThan(res.apex, start.y)
        XCTAssertFalse(res.points.isEmpty)
    }

    func testWindDriftIsMeaningful() {
        let open = CityData()
        open.setup(400)
        let start = Vec2(20, 30)
        let calm = Sim.simulate(city: open, start: start, angleDeg: 45, power: 70,
                                facing: 1, wind: 0, gravity: 9.8,
                                targets: [], shooter: 0, record: false)
        let windy = Sim.simulate(city: open, start: start, angleDeg: 45, power: 70,
                                 facing: 1, wind: 8, gravity: 9.8,
                                 targets: [], shooter: 0, record: false)
        XCTAssertEqual(calm.kind, .ground)
        XCTAssertEqual(windy.kind, .ground)
        XCTAssertGreaterThan(windy.impact.x - calm.impact.x, 2.0,
                             "quadratic wind drift must shift the landing")
    }

    func testCarveRemovesCells() {
        let rng = Lcg(5)
        let city = CityGen.generate(rng: rng, gravity: 9.8)
        let removed = city.carveWorld(Vec2(city.worldWidth() * 0.5, 8), 3.5)
        XCTAssertGreaterThan(removed, 0)
    }

    func testAiFindsAPlan() {
        let rng = Lcg(5)
        let city = CityGen.generate(rng: rng, gravity: 9.8)
        let start = city.gorillaSpots[0] + Vec2(0, 2.5)
        let targets = [
            Target(pos: city.gorillaSpots[0] + Vec2(0, 2), radius: 2.2, player: 0),
            Target(pos: city.gorillaSpots[1] + Vec2(0, 2), radius: 2.2, player: 1),
        ]
        let plan = AiBrain.plan(city: city, shooterPos: start, facing: 1,
                                targets: targets, shooter: 0, wind: 2,
                                gravity: 9.8, rng: Lcg(9), attempt: 3)
        XCTAssertGreaterThanOrEqual(plan.angle, 5)
        XCTAssertLessThanOrEqual(plan.power, 100)
        // Low-error attempt against a solvable city should actually hit.
        let res = Sim.simulate(city: city, start: start, angleDeg: plan.angle,
                               power: plan.power, facing: 1, wind: 2,
                               gravity: 9.8, targets: targets, shooter: 0,
                               record: false)
        XCTAssertEqual(res.kind, .gorilla)
        XCTAssertEqual(res.player, 1)
    }

    func testWeatherTableComplete() {
        XCTAssertEqual(Weather.conditions.count, 9)
        XCTAssertEqual(Weather.conditions[4].name, "SUNSET")
        XCTAssertEqual(Weather.conditions.filter { $0.lightning }.count, 1)
    }
}
