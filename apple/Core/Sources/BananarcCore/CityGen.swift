// Procedural throw-plane skyline (PRD section 9), ported from the Godot
// reference: fresh seed every round, guaranteed interceptor, solver-backed
// solvability, distinctness vs the previous round.

public enum CityGen {
    public static let gorillaRadius = 2.2
    public static let profiles = ["upward", "downward", "valley", "mountain"]

    public static let palette: [RGB] = [
        RGB(hex: 0x5C3A2E),  // brownstone
        RGB(hex: 0x6E5843),  // sandstone
        RGB(hex: 0x57616F),  // concrete
        RGB(hex: 0x7A4A3E),  // brick
        RGB(hex: 0x4A5568),  // slate
        RGB(hex: 0x8A7358),  // limestone-tenement
    ]

    public static func generate(rng: Lcg, gravity: Double,
                                prev: CityData? = nil) -> CityData {
        for attempt in 0..<24 {
            let city = rollCity(rng)
            if !solvable(city, gravity: gravity) { continue }
            if let prev, city.profileDistance(prev) < 3.0, attempt < 12 {
                continue  // too similar to last round (distinctness check)
            }
            return city
        }
        return rollCity(rng)  // never block the game on a pathological seed
    }

    static func rollCity(_ rng: Lcg) -> CityData {
        let city = CityData()
        let n = 8 + rng.randiRange(0, 2)
        let profile = profiles[rng.randiRange(0, profiles.count - 1)]
        city.profileName = profile

        var widths: [Int] = []
        var total = 0
        for _ in 0..<n {
            let w = 9 + rng.randiRange(0, 5)
            widths.append(w)
            total += w
        }
        city.setup(total)

        var heights: [Int] = []
        var h = 14 + rng.randiRange(0, 10)
        for i in 0..<n {
            heights.append(min(max(h, 8), 42))
            let step = 3 + rng.randiRange(0, 5)
            switch profile {
            case "upward": h += step
            case "downward": h -= step
            case "valley": h += i < n / 2 ? -step : step
            default: h += i < n / 2 ? step : -step  // mountain
            }
            h += rng.randiRange(-3, 3)
        }

        let gLeft = 1
        let gRight = n - 2
        // Cap the gorilla rooftops so an interceptor can always rise above
        // them within the height clamp.
        heights[gLeft] = min(max(heights[gLeft], 8), 34)
        heights[gRight] = min(max(heights[gRight], 8), 34)

        // Interceptor guarantee: some mid building must out-reach both rooftops.
        let roofMax = max(heights[gLeft], heights[gRight])
        var tallestMid = 0
        for i in (gLeft + 1)...(gRight - 1) {
            tallestMid = max(tallestMid, heights[i])
        }
        if tallestMid < roofMax + 5 {
            let pick = rng.randiRange(gLeft + 1, gRight - 1)
            heights[pick] = min(max(roofMax + 5 + rng.randiRange(0, 4), 8), 44)
        }

        var x0 = 0
        for i in 0..<n {
            let col = palette[rng.randiRange(0, palette.count - 1)]
            city.buildings.append(
                Building(x0: x0, w: widths[i], h: heights[i], color: col))
            for cx in x0..<(x0 + widths[i]) {
                for cy in 0..<heights[i] {
                    city.setCell(cx, cy, 1)
                }
            }
            x0 += widths[i]
        }

        for gi in [gLeft, gRight] {
            let b = city.buildings[gi]
            city.gorillaSpots.append(Vec2(
                (Double(b.x0) + Double(b.w) * 0.5) * CityData.cell,
                Double(b.h) * CityData.cell))
        }
        return city
    }

    /// Both players must retain multiple viable throw families in calm wind
    /// before a layout is accepted (PRD solvability guarantee).
    static func solvable(_ city: CityData, gravity: Double) -> Bool {
        for shooter in 0..<2 {
            let start = city.gorillaSpots[shooter] + Vec2(0, 2.5)
            let facing = shooter == 0 ? 1 : -1
            let target = Target(pos: city.gorillaSpots[1 - shooter] + Vec2(0, 2.0),
                                radius: gorillaRadius, player: 1 - shooter)
            var hits = 0
            outer: for a in stride(from: 25, through: 70, by: 5) {
                for p in stride(from: 30, through: 95, by: 5) {
                    let res = Sim.simulate(city: city, start: start,
                                           angleDeg: Double(a), power: Double(p),
                                           facing: facing, wind: 0,
                                           gravity: gravity, targets: [target],
                                           shooter: shooter, record: false)
                    if res.kind == .gorilla {
                        hits += 1
                        break  // one power per angle is enough evidence
                    }
                }
                if hits >= 3 { break outer }
            }
            if hits < 3 { return false }
        }
        return true
    }
}
