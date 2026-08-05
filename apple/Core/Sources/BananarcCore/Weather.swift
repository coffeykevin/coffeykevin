// The nine-sky weather & lighting data (PRD section 9). Pure data here;
// the app layer turns it into SceneKit lights, fog, and particles.
// Presentation-first: nothing in this file touches the simulation.

public enum Precip: String, Sendable {
    case none, rain, snow
}

public struct WeatherCondition: Sendable {
    public let name: String
    public let time: String
    public let sunElevationDeg: Double
    public let sunAzimuthDeg: Double
    public let sunEnergy: Double
    public let sunColor: RGB
    public let skyTop: RGB
    public let skyHorizon: RGB
    public let fogDensity: Double
    public let precip: Precip
    public let lightning: Bool
    public let litWindowFraction: Double
    public let ambient: Double
}

public enum Weather {
    public static let conditions: [WeatherCondition] = [
        .init(name: "CLEAR DAY", time: "2:00 PM", sunElevationDeg: 55, sunAzimuthDeg: -25,
              sunEnergy: 1.3, sunColor: RGB(hex: 0xFFF4E0), skyTop: RGB(hex: 0x3D7FC4),
              skyHorizon: RGB(hex: 0xA8CCE8), fogDensity: 0, precip: .none,
              lightning: false, litWindowFraction: 0.06, ambient: 1.0),
        .init(name: "CLOUDY", time: "3:15 PM", sunElevationDeg: 45, sunAzimuthDeg: -25,
              sunEnergy: 0.5, sunColor: RGB(hex: 0xCFD4D8), skyTop: RGB(hex: 0x79838C),
              skyHorizon: RGB(hex: 0xA8AEB4), fogDensity: 0.002, precip: .none,
              lightning: false, litWindowFraction: 0.15, ambient: 1.1),
        .init(name: "RAIN", time: "4:50 PM", sunElevationDeg: 30, sunAzimuthDeg: -25,
              sunEnergy: 0.35, sunColor: RGB(hex: 0xC2C8CE), skyTop: RGB(hex: 0x525C66),
              skyHorizon: RGB(hex: 0x7E8890), fogDensity: 0.008, precip: .rain,
              lightning: false, litWindowFraction: 0.3, ambient: 0.9),
        .init(name: "STORM", time: "5:30 PM", sunElevationDeg: 20, sunAzimuthDeg: -25,
              sunEnergy: 0.22, sunColor: RGB(hex: 0xAAB4C8), skyTop: RGB(hex: 0x171C28),
              skyHorizon: RGB(hex: 0x3A4254), fogDensity: 0.01, precip: .rain,
              lightning: true, litWindowFraction: 0.45, ambient: 0.7),
        .init(name: "SUNSET", time: "7:45 PM", sunElevationDeg: 8, sunAzimuthDeg: -35,
              sunEnergy: 1.1, sunColor: RGB(hex: 0xFFB36B), skyTop: RGB(hex: 0x5C3A66),
              skyHorizon: RGB(hex: 0xF2913F), fogDensity: 0.002, precip: .none,
              lightning: false, litWindowFraction: 0.5, ambient: 0.8),
        .init(name: "CLEAR NIGHT", time: "11:30 PM", sunElevationDeg: 35, sunAzimuthDeg: 20,
              sunEnergy: 0.25, sunColor: RGB(hex: 0xBFD4F2), skyTop: RGB(hex: 0x060B22),
              skyHorizon: RGB(hex: 0x1A2E5C), fogDensity: 0, precip: .none,
              lightning: false, litWindowFraction: 0.85, ambient: 0.5),
        .init(name: "MORNING", time: "6:30 AM", sunElevationDeg: 6, sunAzimuthDeg: 30,
              sunEnergy: 1.0, sunColor: RGB(hex: 0xFFD9A0), skyTop: RGB(hex: 0x8FA0B8),
              skyHorizon: RGB(hex: 0xF2D6A4), fogDensity: 0.004, precip: .none,
              lightning: false, litWindowFraction: 0.35, ambient: 0.9),
        .init(name: "FOGGY", time: "8:10 AM", sunElevationDeg: 25, sunAzimuthDeg: -25,
              sunEnergy: 0.4, sunColor: RGB(hex: 0xD8DCE0), skyTop: RGB(hex: 0xAEB4B8),
              skyHorizon: RGB(hex: 0xC6CCD0), fogDensity: 0.014, precip: .none,
              lightning: false, litWindowFraction: 0.25, ambient: 1.2),
        .init(name: "SNOW", time: "9:20 AM", sunElevationDeg: 30, sunAzimuthDeg: -25,
              sunEnergy: 0.6, sunColor: RGB(hex: 0xE8EEF4), skyTop: RGB(hex: 0x6E7C8C),
              skyHorizon: RGB(hex: 0xB4C0CB), fogDensity: 0.006, precip: .snow,
              lightning: false, litWindowFraction: 0.3, ambient: 1.1),
    ]
}
