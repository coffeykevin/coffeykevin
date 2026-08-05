// AI opponent (PRD 6.3), ported from the Godot reference. Plans with the
// same deterministic integrator the player plays against, then blurs the
// solution by a per-attempt error — converging like a human.

public enum AiBrain {
    /// Silverback tier: converges over 2-4 throws. (angleErr, powerErr)
    public static let errByAttempt: [(Double, Double)] = [
        (9.0, 14.0), (5.0, 8.0), (2.0, 3.5), (0.8, 1.5),
    ]

    public static func plan(city: CityData, shooterPos: Vec2, facing: Int,
                            targets: [Target], shooter: Int, wind: Double,
                            gravity: Double, rng: Lcg,
                            attempt: Int) -> (angle: Double, power: Double) {
        var candidates: [(Double, Double)] = []
        var best = (45.0, 60.0)
        var bestMiss = 1e9
        var targetPos = Vec2(0, 0)
        for tg in targets where tg.player != shooter {
            targetPos = tg.pos
        }
        for a in stride(from: 22, through: 72, by: 2) {
            for p in stride(from: 28, through: 100, by: 3) {
                let res = Sim.simulate(city: city, start: shooterPos,
                                       angleDeg: Double(a), power: Double(p),
                                       facing: facing, wind: wind,
                                       gravity: gravity, targets: targets,
                                       shooter: shooter, record: false)
                if res.kind == .gorilla && res.player != shooter {
                    candidates.append((Double(a), Double(p)))
                } else {
                    let miss = res.impact.distance(to: targetPos)
                    if miss < bestMiss {
                        bestMiss = miss
                        best = (Double(a), Double(p))
                    }
                }
            }
        }
        var pick = best
        if !candidates.isEmpty {
            pick = candidates[rng.randiRange(0, candidates.count - 1)]
        }
        let err = errByAttempt[min(max(attempt, 0), errByAttempt.count - 1)]
        let angle = min(max(pick.0 + (rng.randf() * 2 - 1) * err.0, 5), 88)
        let power = min(max(pick.1 + (rng.randf() * 2 - 1) * err.1, 10), 100)
        return (angle, power)
    }
}
