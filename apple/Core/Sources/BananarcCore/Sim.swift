// The engine-independent deterministic simulation core, ported line-for-line
// from the Godot reference implementation (game/src/sim/). Pure Swift, no
// Foundation — identical behavior on Linux CI and every Apple platform.

// MARK: - Deterministic PRNG

public final class Lcg {
    public private(set) var state: Int

    public init(_ seed: Int) {
        state = seed & 0x7FFF_FFFF
        if state == 0 { state = 305_419_896 }
    }

    @discardableResult
    public func next() -> Int {
        state = (state &* 1_103_515_245 &+ 12345) & 0x7FFF_FFFF
        return state
    }

    public func randf() -> Double {
        Double(next() % 1_000_000) / 1_000_000.0
    }

    public func randiRange(_ a: Int, _ b: Int) -> Int {
        b <= a ? a : a + next() % (b - a + 1)
    }

    /// Classic GORILLA.BAS FnRan(x) = INT(x * RND) + 1
    public func fnRan(_ x: Int) -> Int {
        Int(randf() * Double(x)) + 1
    }
}

// MARK: - Small math

public struct Vec2: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public func distance(to o: Vec2) -> Double {
        let dx = x - o.x, dy = y - o.y
        return (dx * dx + dy * dy).squareRoot()
    }

    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
}

public struct RGB: Sendable {
    public let r: Double
    public let g: Double
    public let b: Double

    public init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// From 24-bit hex, e.g. 0x5C3A2E.
    public init(hex: Int) {
        r = Double((hex >> 16) & 0xFF) / 255.0
        g = Double((hex >> 8) & 0xFF) / 255.0
        b = Double(hex & 0xFF) / 255.0
    }
}

// MARK: - City occupancy grid

public struct Building: Sendable {
    public let x0: Int
    public let w: Int
    public let h: Int
    public let color: RGB
}

/// Occupancy grid for the throw plane. One cell = one world unit; gameplay
/// collision reads this grid, never engine physics (PRD section 12).
public final class CityData {
    public static let cell = 1.0
    public static let skyCells = 50

    public private(set) var widthCells = 0
    public private(set) var grid: [UInt8] = []
    public var buildings: [Building] = []
    /// Two rooftop stand positions in world units (x = building center, y = roof).
    public var gorillaSpots: [Vec2] = []
    public var profileName = ""

    public init() {}

    public func setup(_ w: Int) {
        widthCells = w
        grid = [UInt8](repeating: 0, count: w * Self.skyCells)
    }

    public func setCell(_ cx: Int, _ cy: Int, _ v: UInt8) {
        guard cx >= 0, cx < widthCells, cy >= 0, cy < Self.skyCells else { return }
        grid[cy * widthCells + cx] = v
    }

    public func cellAt(_ cx: Int, _ cy: Int) -> UInt8 {
        guard cx >= 0, cx < widthCells, cy >= 0, cy < Self.skyCells else { return 0 }
        return grid[cy * widthCells + cx]
    }

    public func solidAtWorld(_ p: Vec2) -> Bool {
        if p.y < 0 { return false }
        return cellAt(Int((p.x / Self.cell).rounded(.down)),
                      Int((p.y / Self.cell).rounded(.down))) != 0
    }

    public func worldWidth() -> Double {
        Double(widthCells) * Self.cell
    }

    /// Remove all cells within radius r of world point p. Returns removed count.
    @discardableResult
    public func carveWorld(_ p: Vec2, _ r: Double) -> Int {
        var removed = 0
        let cx0 = Int(((p.x - r) / Self.cell).rounded(.down))
        let cx1 = Int(((p.x + r) / Self.cell).rounded(.down))
        let cy0 = Int((max(p.y - r, 0) / Self.cell).rounded(.down))
        let cy1 = Int(((p.y + r) / Self.cell).rounded(.down))
        for cy in cy0...max(cy0, cy1) where cy >= 0 {
            for cx in cx0...max(cx0, cx1) {
                guard cellAt(cx, cy) != 0 else { continue }
                let center = Vec2((Double(cx) + 0.5) * Self.cell,
                                  (Double(cy) + 0.5) * Self.cell)
                if center.distance(to: p) <= r {
                    setCell(cx, cy, 0)
                    removed += 1
                }
            }
        }
        return removed
    }

    /// Column height profile distance vs another city (distinctness check).
    public func profileDistance(_ other: CityData) -> Double {
        let n = min(widthCells, other.widthCells)
        guard n > 0 else { return 1e9 }
        var acc = 0.0
        for cx in 0..<n {
            acc += abs(colHeight(cx) - other.colHeight(cx))
        }
        return acc / Double(n)
    }

    public func colHeight(_ cx: Int) -> Double {
        var cy = Self.skyCells - 1
        while cy >= 0 {
            if cellAt(cx, cy) != 0 { return Double(cy + 1) }
            cy -= 1
        }
        return 0
    }
}

// MARK: - Trajectory integrator

public struct Target: Sendable {
    public let pos: Vec2
    public let radius: Double
    public let player: Int

    public init(pos: Vec2, radius: Double, player: Int) {
        self.pos = pos
        self.radius = radius
        self.player = player
    }
}

public enum ImpactKind: String, Sendable {
    case gorilla, building, ground, oob
}

public struct SimResult: Sendable {
    public let kind: ImpactKind
    public let impact: Vec2
    public let player: Int
    public let time: Double
    public let apex: Double
    public let points: [Vec2]
}

/// The exact GORILLA.BAS model (PRD section 2), evaluated in closed form per
/// fixed timestep:
///   x(t) = x0 + v*cos(a)*t + 0.5*(W/5)*t^2      (wind drift is quadratic)
///   y(t) = y0 + v*sin(a)*t - 0.5*g*t^2
/// Power 0-100 maps linearly onto the classic velocity range (PRD 6.1).
public enum Sim {
    public static let dt = 1.0 / 120.0
    public static let velScale = 0.5
    public static let windAccel = 0.1
    public static let maxT = 30.0
    public static let selfIgnoreT = 0.6
    public static let otherIgnoreT = 0.05

    public static func simulate(city: CityData, start: Vec2, angleDeg: Double,
                                power: Double, facing: Int, wind: Double,
                                gravity: Double, targets: [Target],
                                shooter: Int, record: Bool = true) -> SimResult {
        let v = power * velScale
        let a = min(max(angleDeg, 0), 90) * Double.pi / 180.0
        let vx = _cos(a) * v * Double(facing)
        let vy = _sin(a) * v
        let ax = wind * windAccel
        var pts: [Vec2] = []
        var apex = start.y
        var t = 0.0
        var p = start
        while t < maxT {
            t += dt
            p = Vec2(start.x + vx * t + 0.5 * ax * t * t,
                     start.y + vy * t - 0.5 * gravity * t * t)
            if record { pts.append(p) }
            if p.y > apex { apex = p.y }
            for tg in targets {
                let ignore = tg.player == shooter ? selfIgnoreT : otherIgnoreT
                if t > ignore && p.distance(to: tg.pos) <= tg.radius {
                    return SimResult(kind: .gorilla, impact: p, player: tg.player,
                                     time: t, apex: apex, points: pts)
                }
            }
            if city.solidAtWorld(p) {
                return SimResult(kind: .building, impact: p, player: -1,
                                 time: t, apex: apex, points: pts)
            }
            if p.y <= 0 {
                return SimResult(kind: .ground, impact: p, player: -1,
                                 time: t, apex: apex, points: pts)
            }
            if p.x < -30 || p.x > city.worldWidth() + 30 {
                return SimResult(kind: .oob, impact: p, player: -1,
                                 time: t, apex: apex, points: pts)
            }
        }
        return SimResult(kind: .oob, impact: p, player: -1,
                         time: t, apex: apex, points: pts)
    }

    /// Classic wind roll: W = rand(10) - 5, with gust amplification chance.
    public static func rollWind(_ rng: Lcg) -> Double {
        var w = rng.randf() * 10.0 - 5.0
        if rng.randf() > 0.5 {
            w += (w < 0 ? -1.0 : 1.0) * rng.randf() * 5.0
        }
        return min(max(w, -10), 10)
    }

    public static func windMph(_ w: Double) -> Int {
        Int((abs(w) * 2.3).rounded())
    }

    // Foundation-free trig (Taylor via Darwin/Glibc intrinsics is fine — the
    // builtin is available through the Swift runtime on all platforms).
    @inline(__always) static func _sin(_ x: Double) -> Double { __sin(x) }
    @inline(__always) static func _cos(_ x: Double) -> Double { __cos(x) }
}

#if canImport(Darwin)
import Darwin
@inline(__always) func __sin(_ x: Double) -> Double { Darwin.sin(x) }
@inline(__always) func __cos(_ x: Double) -> Double { Darwin.cos(x) }
#elseif canImport(Glibc)
import Glibc
@inline(__always) func __sin(_ x: Double) -> Double { Glibc.sin(x) }
@inline(__always) func __cos(_ x: Double) -> Double { Glibc.cos(x) }
#endif
